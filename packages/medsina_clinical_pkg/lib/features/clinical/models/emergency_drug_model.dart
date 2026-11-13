import 'package:equatable/equatable.dart';

/// Represents a critical emergency drug available in Algerian hospital settings (UMC, PCH, Saidal, IPA).
class EmergencyDrugModel extends Equatable {
  final String id;
  final String dci;
  final String brand;
  final String category;
  final String route;
  final String indication;
  final String dose;
  final String alert;
  final String? algerianAvailability;

  const EmergencyDrugModel({
    required this.id,
    required this.dci,
    required this.brand,
    required this.category,
    required this.route,
    required this.indication,
    required this.dose,
    required this.alert,
    this.algerianAvailability,
  });

  factory EmergencyDrugModel.fromJson(Map<String, dynamic> json) {
    return EmergencyDrugModel(
      id: json['id']?.toString() ?? '',
      dci: json['dci']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Général',
      route: json['route']?.toString() ?? '',
      indication: json['indication']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      alert: json['alert']?.toString() ?? '',
      algerianAvailability: json['algerian_availability']?.toString() ??
          json['algerianAvailability']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dci': dci,
      'brand': brand,
      'category': category,
      'route': route,
      'indication': indication,
      'dose': dose,
      'alert': alert,
      'algerian_availability': algerianAvailability,
    };
  }

  EmergencyDrugModel copyWith({
    String? id,
    String? dci,
    String? brand,
    String? category,
    String? route,
    String? indication,
    String? dose,
    String? alert,
    String? algerianAvailability,
  }) {
    return EmergencyDrugModel(
      id: id ?? this.id,
      dci: dci ?? this.dci,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      route: route ?? this.route,
      indication: indication ?? this.indication,
      dose: dose ?? this.dose,
      alert: alert ?? this.alert,
      algerianAvailability: algerianAvailability ?? this.algerianAvailability,
    );
  }

  @override
  List<Object?> get props => [
        id,
        dci,
        brand,
        category,
        route,
        indication,
        dose,
        alert,
        algerianAvailability,
      ];
}

