import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/core/constants/app_constants.dart';
import 'package:medsina/features/auth/models/user_model.dart';

UserModel _user({
  String? teacherRank,
  bool teacherVerified = false,
  bool isAdmin = false,
  String medicalRole = 'Candidat Résidanat',
}) {
  return UserModel(
    id: 'u1',
    fullName: 'Dr. Test',
    email: 'test@medsina.dz',
    medicalRole: medicalRole,
    faculty: 'Blida',
    tier: SubscriptionTier.free,
    subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
    token: 'token',
    isAdmin: isAdmin,
    teacherRank: teacherRank,
    teacherVerified: teacherVerified,
  );
}

void main() {
  group('Espace Prof — autorisation de publication', () {
    test(
      'un compte non vérifié ne peut pas publier, même avec un grade déclaré',
      () {
        final user = _user(teacherRank: 'professeur', teacherVerified: false);
        expect(user.isVerifiedTeacher, isFalse);
        expect(user.canPublishTeacherContent, isFalse);
      },
    );

    test('un rôle médical auto-déclaré ne suffit pas', () {
      final user = _user(medicalRole: 'Professeur (Pr.)');
      expect(user.canPublishTeacherContent, isFalse);
    });

    test('tous les grades vérifiés habilités peuvent publier', () {
      for (final rank in UserModel.publishableTeacherRanks) {
        final user = _user(teacherRank: rank, teacherVerified: true);
        expect(user.isVerifiedTeacher, isTrue, reason: rank);
        expect(user.canPublishTeacherContent, isTrue, reason: rank);
      }
    });

    test('les grades vérifiés hors liste restent bloqués', () {
      final user = _user(teacherRank: 'etudiant', teacherVerified: true);
      expect(user.canPublishTeacherContent, isFalse);
    });

    test('un administrateur conserve l\'accès pour la modération', () {
      final user = _user(isAdmin: true);
      expect(user.canPublishTeacherContent, isTrue);
    });

    test('le grade vérifié survit à une sérialisation JSON', () {
      final user = _user(teacherRank: 'maitreAssistant', teacherVerified: true);
      final restored = UserModel.fromJson(user.toJson());
      expect(restored.teacherRank, 'maitreAssistant');
      expect(restored.teacherVerified, isTrue);
      expect(restored.canPublishTeacherContent, isTrue);
    });

    test('le grade vérifié survit à copyWith', () {
      final user = _user(teacherRank: 'assistant', teacherVerified: true);
      final updated = user.copyWith(faculty: 'Alger');
      expect(updated.teacherRank, 'assistant');
      expect(updated.teacherVerified, isTrue);
    });
  });
}
