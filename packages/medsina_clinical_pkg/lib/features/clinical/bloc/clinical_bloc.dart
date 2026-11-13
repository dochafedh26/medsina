import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/clinical_repository.dart';
import '../models/cat_protocol_model.dart';
import '../models/emergency_drug_model.dart';
import 'clinical_event.dart';
import 'clinical_state.dart';

class ClinicalBloc extends Bloc<ClinicalEvent, ClinicalState> {
  ClinicalBloc() : super(const ClinicalState()) {
    on<LoadClinicalDataEvent>(_onLoadClinicalData);
    on<SearchProtocolsEvent>(_onSearchProtocols);
    on<FilterSpecialtyEvent>(_onFilterSpecialty);
    on<SearchEmergencyDrugsEvent>(_onSearchEmergencyDrugs);
    on<FilterDrugCategoryEvent>(_onFilterDrugCategory);
  }

  Future<void> _onLoadClinicalData(
    LoadClinicalDataEvent event,
    Emitter<ClinicalState> emit,
  ) async {
    emit(state.copyWith(status: ClinicalStatus.loading));
    try {
      final results = await Future.wait([
        ClinicalRepository.fetchProtocols(),
        ClinicalRepository.fetchEmergencyDrugs(forceRefresh: event.forceRefresh),
      ]);

      final protocols = results[0] as List<ClinicalProtocol>;
      final drugs = results[1] as List<EmergencyDrugModel>;

      final filteredProtocols = _applyFilters(protocols, state.selectedSpecialty, state.searchQuery);
      final filteredDrugs = _applyDrugFilters(drugs, state.selectedDrugCategory, state.drugSearchQuery);

      emit(state.copyWith(
        status: ClinicalStatus.loaded,
        allProtocols: protocols,
        filteredProtocols: filteredProtocols,
        allDrugs: drugs,
        filteredDrugs: filteredDrugs,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ClinicalStatus.error,
        errorMessage: 'Erreur lors du chargement des données cliniques : $e',
      ));
    }
  }

  void _onSearchProtocols(SearchProtocolsEvent event, Emitter<ClinicalState> emit) {
    final query = event.query.toLowerCase().trim();
    final filtered = _applyFilters(state.allProtocols, state.selectedSpecialty, query);
    emit(state.copyWith(searchQuery: event.query, filteredProtocols: filtered));
  }

  void _onFilterSpecialty(FilterSpecialtyEvent event, Emitter<ClinicalState> emit) {
    final filtered = _applyFilters(state.allProtocols, event.specialty, state.searchQuery);
    emit(state.copyWith(selectedSpecialty: event.specialty, filteredProtocols: filtered));
  }

  void _onSearchEmergencyDrugs(SearchEmergencyDrugsEvent event, Emitter<ClinicalState> emit) {
    final query = event.query.toLowerCase().trim();
    final filtered = _applyDrugFilters(state.allDrugs, state.selectedDrugCategory, query);
    emit(state.copyWith(drugSearchQuery: event.query, filteredDrugs: filtered));
  }

  void _onFilterDrugCategory(FilterDrugCategoryEvent event, Emitter<ClinicalState> emit) {
    final filtered = _applyDrugFilters(state.allDrugs, event.category, state.drugSearchQuery);
    emit(state.copyWith(selectedDrugCategory: event.category, filteredDrugs: filtered));
  }

  List<ClinicalProtocol> _applyFilters(List<ClinicalProtocol> list, String specialty, String query) {
    return list.where((p) {
      final matchesSpecialty = specialty == 'Tous' || p.specialty.contains(specialty);
      final matchesQuery = query.isEmpty ||
          p.title.toLowerCase().contains(query) ||
          p.definition.toLowerCase().contains(query) ||
          p.specialty.toLowerCase().contains(query);
      return matchesSpecialty && matchesQuery;
    }).toList();
  }

  List<EmergencyDrugModel> _applyDrugFilters(
    List<EmergencyDrugModel> list,
    String category,
    String query,
  ) {
    return list.where((d) {
      final matchesCategory = category == 'Tous' || d.category == category;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return d.dci.toLowerCase().contains(query) ||
          d.brand.toLowerCase().contains(query) ||
          d.indication.toLowerCase().contains(query) ||
          d.route.toLowerCase().contains(query) ||
          d.alert.toLowerCase().contains(query);
    }).toList();
  }
}
