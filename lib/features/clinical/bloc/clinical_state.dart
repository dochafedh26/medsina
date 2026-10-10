import 'package:equatable/equatable.dart';
import '../models/cat_protocol_model.dart';

enum ClinicalStatus { initial, loading, loaded, error }

class ClinicalState extends Equatable {
  final ClinicalStatus status;
  final List<ClinicalProtocol> allProtocols;
  final List<ClinicalProtocol> filteredProtocols;
  final String selectedSpecialty;
  final String searchQuery;
  final String? errorMessage;

  const ClinicalState({
    this.status = ClinicalStatus.initial,
    this.allProtocols = const [],
    this.filteredProtocols = const [],
    this.selectedSpecialty = 'Tous',
    this.searchQuery = '',
    this.errorMessage,
  });

  List<String> get availableSpecialties {
    final list = allProtocols.map((p) => p.specialty).toSet().toList();
    list.sort();
    return ['Tous', ...list];
  }

  ClinicalState copyWith({
    ClinicalStatus? status,
    List<ClinicalProtocol>? allProtocols,
    List<ClinicalProtocol>? filteredProtocols,
    String? selectedSpecialty,
    String? searchQuery,
    String? errorMessage,
  }) {
    return ClinicalState(
      status: status ?? this.status,
      allProtocols: allProtocols ?? this.allProtocols,
      filteredProtocols: filteredProtocols ?? this.filteredProtocols,
      selectedSpecialty: selectedSpecialty ?? this.selectedSpecialty,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
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
      ];
}
