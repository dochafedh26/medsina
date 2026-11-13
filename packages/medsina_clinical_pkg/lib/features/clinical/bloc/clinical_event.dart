import 'package:equatable/equatable.dart';

abstract class ClinicalEvent extends Equatable {
  const ClinicalEvent();

  @override
  List<Object?> get props => [];
}

class LoadClinicalDataEvent extends ClinicalEvent {
  final bool forceRefresh;
  const LoadClinicalDataEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class SearchProtocolsEvent extends ClinicalEvent {
  final String query;

  const SearchProtocolsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterSpecialtyEvent extends ClinicalEvent {
  final String specialty; // 'Tous' or specific specialty

  const FilterSpecialtyEvent(this.specialty);

  @override
  List<Object?> get props => [specialty];
}

class SearchEmergencyDrugsEvent extends ClinicalEvent {
  final String query;

  const SearchEmergencyDrugsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterDrugCategoryEvent extends ClinicalEvent {
  final String category; // 'Tous' or specific category

  const FilterDrugCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}
