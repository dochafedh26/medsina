import 'package:equatable/equatable.dart';

abstract class ClinicalEvent extends Equatable {
  const ClinicalEvent();

  @override
  List<Object?> get props => [];
}

class LoadClinicalDataEvent extends ClinicalEvent {}

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
