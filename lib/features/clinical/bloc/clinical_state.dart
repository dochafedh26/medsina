import 'package:equatable/equatable.dart';
import '../models/cat_protocol_model.dart';
import '../models/emergency_drug_model.dart';

enum ClinicalStatus { initial, loading, loaded, error }

class ClinicalState extends Equatable {
  final ClinicalStatus status;
  final List<ClinicalProtocol> allProtocols;
  final List<ClinicalProtocol> filteredProtocols;
  final String selectedSpecialty;
  final String searchQuery;
  final String? errorMessage;

  // Emergency Drugs State
  final List<EmergencyDrugModel> allDrugs;
  final List<EmergencyDrugModel> filteredDrugs;
  final String selectedDrugCategory;
  final String drugSearchQuery;

  const ClinicalState({
    this.status = ClinicalStatus.initial,
    this.allProtocols = const [],
    this.filteredProtocols = const [],
    this.selectedSpecialty = 'Tous',
    this.searchQuery = '',
    this.errorMessage,
    this.allDrugs = const [],
    this.filteredDrugs = const [],
    this.selectedDrugCategory = 'Tous',
    this.drugSearchQuery = '',
  });

  List<String> get availableSpecialties {
    final list = allProtocols.map((p) => p.specialty).toSet().toList();
    list.sort();
    return ['Tous', ...list];
  }

  List<String> get availableDrugCategories {
    const defaultCategories = [
      'Tous',
      'Cardio / ACR / Choc',
      'Respiratoire',
      'Neurologie / Sédation',
      'Infectiologie',
      'Antidotes & Sérums',
      'Antalgiques',
      'Hémostase & Anticoagulants',
      'Métabolisme & Endocrinologie',
      'Gastro-entérologie',
    ];
    final fromData = allDrugs.map((d) => d.category).toSet();
    final combined = <String>{...defaultCategories, ...fromData};
    return combined.toList();
  }

  ClinicalState copyWith({
    ClinicalStatus? status,
    List<ClinicalProtocol>? allProtocols,
    List<ClinicalProtocol>? filteredProtocols,
    String? selectedSpecialty,
    String? searchQuery,
    String? errorMessage,
    List<EmergencyDrugModel>? allDrugs,
    List<EmergencyDrugModel>? filteredDrugs,
    String? selectedDrugCategory,
    String? drugSearchQuery,
  }) {
    return ClinicalState(
      status: status ?? this.status,
      allProtocols: allProtocols ?? this.allProtocols,
      filteredProtocols: filteredProtocols ?? this.filteredProtocols,
      selectedSpecialty: selectedSpecialty ?? this.selectedSpecialty,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
      allDrugs: allDrugs ?? this.allDrugs,
      filteredDrugs: filteredDrugs ?? this.filteredDrugs,
      selectedDrugCategory: selectedDrugCategory ?? this.selectedDrugCategory,
      drugSearchQuery: drugSearchQuery ?? this.drugSearchQuery,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allProtocols,
        filteredProtocols,
        selectedSpecialty,
        searchQuery,
        errorMessage,
        allDrugs,
        filteredDrugs,
        selectedDrugCategory,
        drugSearchQuery,
      ];
}
