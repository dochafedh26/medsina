import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/services/medsina_notification_dispatcher.dart';
import '../models/admin_models.dart';
import 'admin_event.dart';
import 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc() : super(const AdminState()) {
    on<LoadAdminDataEvent>(_onLoadAdminData);
    on<SearchUsersEvent>(_onSearchUsers);
    on<GenerateLicenseKeyEvent>(_onGenerateLicenseKey);
    on<UpgradeUserSubscriptionEvent>(_onUpgradeUserSubscription);
    on<ClearAdminMessageEvent>(_onClearAdminMessage);
    on<UpdatePlanPriceEvent>(_onUpdatePlanPrice);
    on<ApprovePaymentEvent>(_onApprovePayment);
    on<RejectPaymentEvent>(_onRejectPayment);
    on<RecordManualPaymentEvent>(_onRecordManualPayment);
    on<FilterPaymentsEvent>(_onFilterPayments);
    on<CreateAnnouncementEvent>(_onCreateAnnouncement);
    on<ToggleAnnouncementEvent>(_onToggleAnnouncement);
    on<DeleteAnnouncementEvent>(_onDeleteAnnouncement);
    on<UnbanUserEvent>(_onUnbanUser);
    on<ArchiveEligibleReceiptsEvent>(_onArchiveEligibleReceipts);
    on<RevokeLicenseKeyEvent>(_onRevokeLicenseKey);
    on<UnrevokeLicenseKeyEvent>(_onUnrevokeLicenseKey);
  }

  void _onClearAdminMessage(ClearAdminMessageEvent event, Emitter<AdminState> emit) {
    emit(state.copyWith(clearMessages: true));
  }

  Future<void> _onLoadAdminData(LoadAdminDataEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final metricsData = await SupabaseService.fetchAdminMetrics();
      final usersData = await SupabaseService.fetchAdminUsers();
      final licensesData = await SupabaseService.fetchAdminLicenseKeys();
      final plansData = await SupabaseService.fetchSubscriptionPlans();
      final paymentsData = await SupabaseService.fetchPayments();
      final announcementsData = await SupabaseService.fetchAnnouncements();

      final metrics = AdminMetrics.fromJson(metricsData);
      final users = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
      final licenses = licensesData.map((l) => AdminLicenseItem.fromJson(l)).toList();
      final plans = plansData.map((p) => SubscriptionPlanItem.fromJson(p)).toList();
      final payments = paymentsData.map((p) => PaymentItem.fromJson(p)).toList();
      final financialMetrics = FinancialMetrics.fromPayments(payments);
      final announcements = announcementsData.map((a) => AnnouncementItem.fromJson(a)).toList();

      emit(state.copyWith(
        status: AdminStatus.loaded,
        metrics: metrics,
        users: users,
        filteredUsers: users,
        licenses: licenses,
        plans: plans,
        payments: payments,
        filteredPayments: payments,
        financialMetrics: financialMetrics,
        announcements: announcements,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: 'Erreur lors du chargement des données administrateur: $e',
      ));
    }
  }

  void _onSearchUsers(SearchUsersEvent event, Emitter<AdminState> emit) {
    final query = event.query.trim().toLowerCase();
    if (query.isEmpty) {
      emit(state.copyWith(searchQuery: query, filteredUsers: state.users));
      return;
    }

    final filtered = state.users.where((u) {
      return u.fullName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.faculty.toLowerCase().contains(query) ||
          u.medicalRole.toLowerCase().contains(query);
    }).toList();

    emit(state.copyWith(searchQuery: query, filteredUsers: filtered));
  }

  void _onFilterPayments(FilterPaymentsEvent event, Emitter<AdminState> emit) {
    final filter = event.status;
    if (filter == 'all') {
      emit(state.copyWith(paymentStatusFilter: 'all', filteredPayments: state.payments));
      return;
    }

    final filtered = state.payments.where((p) => p.status == filter).toList();
    emit(state.copyWith(paymentStatusFilter: filter, filteredPayments: filtered));
  }

  Future<void> _onUpdatePlanPrice(UpdatePlanPriceEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final success = await SupabaseService.updateSubscriptionPlan(
        planId: event.planId,
        priceYearly: event.priceYearly,
        priceMonthly: event.priceMonthly,
        discountPercent: event.discountPercent,
        badge: event.badge,
        isActive: event.isActive,
      );

      final plansData = await SupabaseService.fetchSubscriptionPlans();
      final updatedPlans = plansData.map((p) => SubscriptionPlanItem.fromJson(p)).toList();

      emit(state.copyWith(
        status: AdminStatus.loaded,
        plans: updatedPlans,
        successMessage: success ? 'Tarifs de la formule mis à jour avec succès !' : 'Tarifs mis à jour en local.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de la mise à jour des tarifs: $e',
      ));
    }
  }

  Future<void> _onApprovePayment(ApprovePaymentEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final success = await SupabaseService.approvePayment(
        paymentId: event.paymentId,
        userId: event.userId,
        tier: event.tier,
        durationDays: event.durationDays,
        adminNotes: event.adminNotes,
      );

      final paymentsData = await SupabaseService.fetchPayments();
      final usersData = await SupabaseService.fetchAdminUsers();
      final metricsData = await SupabaseService.fetchAdminMetrics();

      final updatedPayments = paymentsData.map((p) => PaymentItem.fromJson(p)).toList();
      final updatedUsers = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
      final updatedMetrics = AdminMetrics.fromJson(metricsData);
      final financialMetrics = FinancialMetrics.fromPayments(updatedPayments);

      emit(state.copyWith(
        status: AdminStatus.loaded,
        payments: updatedPayments,
        filteredPayments: updatedPayments,
        users: updatedUsers,
        filteredUsers: updatedUsers,
        metrics: updatedMetrics,
        financialMetrics: financialMetrics,
        successMessage: success
            ? 'Paiement validé avec succès ! L\'abonnement du médecin a été activé.'
            : 'Paiement validé.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de la validation du paiement: $e',
      ));
    }
  }

  Future<void> _onRejectPayment(RejectPaymentEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final res = await SupabaseService.rejectPaymentWithFraudCheck(
        paymentId: event.paymentId,
        adminNotes: event.adminNotes,
      );
      final isBanned = res['is_banned'] == true;
      final rejectedCount = res['rejected_count'] ?? 1;

      final paymentsData = await SupabaseService.fetchPayments();
      final usersData = await SupabaseService.fetchAdminUsers();
      final metricsData = await SupabaseService.fetchAdminMetrics();

      final updatedPayments = paymentsData.map((p) => PaymentItem.fromJson(p)).toList();
      final updatedUsers = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
      final financialMetrics = FinancialMetrics.fromPayments(updatedPayments);
      final updatedMetrics = AdminMetrics.fromJson(metricsData);

      final msg = isBanned
          ? 'Paiement rejeté. L\'utilisateur a atteint 3 rejets et a été AUTOMATIQUEMENT BANNI.'
          : 'Paiement rejeté (Avertissement $rejectedCount/3 envoyé au candidat). Reçu archivé sur Drive.';

      emit(state.copyWith(
        status: AdminStatus.loaded,
        payments: updatedPayments,
        filteredPayments: updatedPayments,
        users: updatedUsers,
        filteredUsers: updatedUsers,
        metrics: updatedMetrics,
        financialMetrics: financialMetrics,
        successMessage: msg,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors du rejet du paiement: $e',
      ));
    }
  }

  Future<void> _onRecordManualPayment(RecordManualPaymentEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final success = await SupabaseService.recordManualPayment(
        userId: event.userId,
        userEmail: event.userEmail,
        userName: event.userName,
        tier: event.tier,
        durationDays: event.durationDays,
        amount: event.amount,
        paymentMethod: event.paymentMethod,
        receiptReference: event.receiptReference,
        adminNotes: event.adminNotes,
      );

      final paymentsData = await SupabaseService.fetchPayments();
      final usersData = await SupabaseService.fetchAdminUsers();
      final metricsData = await SupabaseService.fetchAdminMetrics();

      final updatedPayments = paymentsData.map((p) => PaymentItem.fromJson(p)).toList();
      final updatedUsers = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
      final updatedMetrics = AdminMetrics.fromJson(metricsData);
      final financialMetrics = FinancialMetrics.fromPayments(updatedPayments);

      emit(state.copyWith(
        status: AdminStatus.loaded,
        payments: updatedPayments,
        filteredPayments: updatedPayments,
        users: updatedUsers,
        filteredUsers: updatedUsers,
        metrics: updatedMetrics,
        financialMetrics: financialMetrics,
        successMessage: success ? 'Paiement manuel enregistré et abonnement activé !' : 'Paiement enregistré.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de l\'enregistrement manuel: $e',
      ));
    }
  }

  Future<void> _onCreateAnnouncement(CreateAnnouncementEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      await SupabaseService.createAnnouncement(
        title: event.title,
        message: event.message,
        type: event.type,
      );

      final announcementsData = await SupabaseService.fetchAnnouncements();
      final updatedAnnouncements = announcementsData.map((a) => AnnouncementItem.fromJson(a)).toList();

      emit(state.copyWith(
        status: AdminStatus.loaded,
        announcements: updatedAnnouncements,
        successMessage: 'Annonce publiée avec succès !',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de la publication de l\'annonce: $e',
      ));
    }
  }

  Future<void> _onToggleAnnouncement(ToggleAnnouncementEvent event, Emitter<AdminState> emit) async {
    try {
      await SupabaseService.toggleAnnouncement(event.id, event.isActive);
      final announcementsData = await SupabaseService.fetchAnnouncements();
      final updatedAnnouncements = announcementsData.map((a) => AnnouncementItem.fromJson(a)).toList();

      emit(state.copyWith(announcements: updatedAnnouncements));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Erreur mise à jour statut annonce: $e'));
    }
  }

  Future<void> _onDeleteAnnouncement(DeleteAnnouncementEvent event, Emitter<AdminState> emit) async {
    try {
      await SupabaseService.deleteAnnouncement(event.id);
      final announcementsData = await SupabaseService.fetchAnnouncements();
      final updatedAnnouncements = announcementsData.map((a) => AnnouncementItem.fromJson(a)).toList();

      emit(state.copyWith(
        announcements: updatedAnnouncements,
        successMessage: 'Annonce supprimée.',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Erreur suppression annonce: $e'));
    }
  }

  Future<void> _onGenerateLicenseKey(GenerateLicenseKeyEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final result = await SupabaseService.generateLicenseKey(
        keyCode: event.keyCode,
        tier: event.tier,
        durationDays: event.durationDays,
      );

      if (result['success'] == true) {
        final licensesData = await SupabaseService.fetchAdminLicenseKeys();
        final metricsData = await SupabaseService.fetchAdminMetrics();

        final licenses = licensesData.map((l) => AdminLicenseItem.fromJson(l)).toList();
        final metrics = AdminMetrics.fromJson(metricsData);

        emit(state.copyWith(
          status: AdminStatus.loaded,
          licenses: licenses,
          metrics: metrics,
          successMessage: result['message'] ?? 'Clé générée avec succès !',
        ));
      } else {
        emit(state.copyWith(
          status: AdminStatus.loaded,
          errorMessage: result['message'] ?? 'Échec de génération de la clé.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de la création de la clé : $e',
      ));
    }
  }

  Future<void> _onUpgradeUserSubscription(UpgradeUserSubscriptionEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final result = await SupabaseService.updateUserSubscription(
        userId: event.userId,
        tier: event.tier,
        durationDays: event.durationDays,
      );

      if (result['success'] == true) {
        final usersData = await SupabaseService.fetchAdminUsers();
        final metricsData = await SupabaseService.fetchAdminMetrics();

        final users = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
        final metrics = AdminMetrics.fromJson(metricsData);

        emit(state.copyWith(
          status: AdminStatus.loaded,
          users: users,
          filteredUsers: users,
          metrics: metrics,
          successMessage: 'Abonnement utilisateur mis à niveau avec succès !',
        ));
      } else {
        emit(state.copyWith(
          status: AdminStatus.loaded,
          errorMessage: result['message'] ?? 'Échec de mise à jour.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de la mise à jour : $e',
      ));
    }
  }

  Future<void> _onUnbanUser(UnbanUserEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final success = await SupabaseService.unbanUser(
        userId: event.userId,
        adminNotes: event.adminNotes,
      );

      final usersData = await SupabaseService.fetchAdminUsers();
      final metricsData = await SupabaseService.fetchAdminMetrics();
      final updatedUsers = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
      final updatedMetrics = AdminMetrics.fromJson(metricsData);

      emit(state.copyWith(
        status: AdminStatus.loaded,
        users: updatedUsers,
        filteredUsers: updatedUsers,
        metrics: updatedMetrics,
        successMessage: success
            ? 'Utilisateur débanni avec succès ! Le compteur de rejets a été réinitialisé.'
            : 'Échec du déblocage de l\'utilisateur.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors du déblocage : $e',
      ));
    }
  }

  Future<void> _onArchiveEligibleReceipts(ArchiveEligibleReceiptsEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final count = await MedsinaNotificationDispatcher.archiveApprovedReceiptsOlderThanDays(
        retentionDays: event.retentionDays,
      );

      final paymentsData = await SupabaseService.fetchPayments();
      final updatedPayments = paymentsData.map((p) => PaymentItem.fromJson(p)).toList();

      emit(state.copyWith(
        status: AdminStatus.loaded,
        payments: updatedPayments,
        filteredPayments: updatedPayments,
        successMessage: count > 0
            ? '$count reçu(s) validé(s) de plus de ${event.retentionDays} jours ont été archivés sur Google Drive et nettoyés du stockage Supabase !'
            : 'Aucun reçu validé de plus de ${event.retentionDays} jours à archiver.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de l\'archivage sur Google Drive : $e',
      ));
    }
  }

  Future<void> _onRevokeLicenseKey(RevokeLicenseKeyEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final result = await SupabaseService.revokeLicenseKey(
        keyCode: event.keyCode,
        reason: event.reason,
      );

      if (result['success'] == true) {
        final licensesData = await SupabaseService.fetchAdminLicenseKeys();
        final usersData = await SupabaseService.fetchAdminUsers();
        final metricsData = await SupabaseService.fetchAdminMetrics();

        final licenses = licensesData.map((l) => AdminLicenseItem.fromJson(l)).toList();
        final users = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
        final metrics = AdminMetrics.fromJson(metricsData);

        emit(state.copyWith(
          status: AdminStatus.loaded,
          licenses: licenses,
          users: users,
          filteredUsers: users,
          metrics: metrics,
          successMessage: result['message'] ?? 'Clé ${event.keyCode} révoquée avec succès !',
        ));
      } else {
        emit(state.copyWith(
          status: AdminStatus.loaded,
          errorMessage: result['message'] ?? 'Échec de la révocation de la clé.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors de la révocation : $e',
      ));
    }
  }

  Future<void> _onUnrevokeLicenseKey(UnrevokeLicenseKeyEvent event, Emitter<AdminState> emit) async {
    emit(state.copyWith(status: AdminStatus.loading, clearMessages: true));
    try {
      final result = await SupabaseService.unrevokeLicenseKey(
        keyCode: event.keyCode,
      );

      if (result['success'] == true) {
        final licensesData = await SupabaseService.fetchAdminLicenseKeys();
        final usersData = await SupabaseService.fetchAdminUsers();
        final metricsData = await SupabaseService.fetchAdminMetrics();

        final licenses = licensesData.map((l) => AdminLicenseItem.fromJson(l)).toList();
        final users = usersData.map((u) => AdminUserItem.fromJson(u)).toList();
        final metrics = AdminMetrics.fromJson(metricsData);

        emit(state.copyWith(
          status: AdminStatus.loaded,
          licenses: licenses,
          users: users,
          filteredUsers: users,
          metrics: metrics,
          successMessage: result['message'] ?? 'Clé ${event.keyCode} rétablie avec succès !',
        ));
      } else {
        emit(state.copyWith(
          status: AdminStatus.loaded,
          errorMessage: result['message'] ?? 'Échec du rétablissement de la clé.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.loaded,
        errorMessage: 'Erreur lors du rétablissement : $e',
      ));
    }
  }
}


