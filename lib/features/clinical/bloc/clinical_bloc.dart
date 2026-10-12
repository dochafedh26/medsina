import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/clinical_repository.dart';
import '../models/cat_protocol_model.dart';
import 'clinical_event.dart';
import 'clinical_state.dart';

class ClinicalBloc extends Bloc<ClinicalEvent, ClinicalState> {
  ClinicalBloc() : super(const ClinicalState()) {
    on<LoadClinicalDataEvent>(_onLoadClinicalData);
    on<SearchProtocolsEvent>(_onSearchProtocols);
    on<FilterSpecialtyEvent>(_onFilterSpecialty);
  }

  Future<void> _onLoadClinicalData(LoadClinicalDataEvent event, Emitter<ClinicalState> emit) async {
    emit(state.copyWith(status: ClinicalStatus.loading));
    try {
      final protocols = await ClinicalRepository.fetchProtocols();
      emit(state.copyWith(
        status: ClinicalStatus.loaded,
        allProtocols: protocols,
        filteredProtocols: protocols,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ClinicalStatus.error,
        errorMessage: 'Erreur lors du chargement des protocoles : $e',
      ));
    }
  }

  void _onSearchProtocols(SearchProtocolsEvent event, Emitter<ClinicalState> emit) {
    final query = event.query.toLowerCase().trim();
    final filtered = _applyFilters(state.allProtocols, state.selectedSpecialty, query);
    emit(state.copyWith(searchQuery: event.query, filteredProtocols: filtered));
  }

  void _onFilterSpecialtyEvent(FilterSpecialtyEvent event, Emitter<ClinicalState> emit) {
    final filtered = _applyFilters(state.allProtocols, event.specialty, state.searchQuery);
    emit(state.copyWith(selectedSpecialty: event.specialty, filteredProtocols: filtered));
  }

  void _onFilterSpecialty(FilterSpecialtyEvent event, Emitter<ClinicalState> emit) {
    _onFilterSpecialtyEvent(event, emit);
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
}
