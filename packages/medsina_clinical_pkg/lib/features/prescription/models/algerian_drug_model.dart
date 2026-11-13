class AlgerianDrugModel {
  final int num;
  final String regNum;
  final String code;
  final String dci;
  final String brand;
  final String form;
  final String dosage;
  final String packaging;
  final String liste;
  final String lab;
  final String pays;
  final String type;
  final String status;

  const AlgerianDrugModel({
    required this.num,
    required this.regNum,
    required this.code,
    required this.dci,
    required this.brand,
    required this.form,
    required this.dosage,
    required this.packaging,
    required this.liste,
    required this.lab,
    required this.pays,
    required this.type,
    required this.status,
  });

  factory AlgerianDrugModel.fromJson(Map<String, dynamic> json) {
    return AlgerianDrugModel(
      num: json['num'] is int ? json['num'] : int.tryParse(json['num']?.toString() ?? '0') ?? 0,
      regNum: (json['reg_num'] ?? json['regNum'])?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      dci: json['dci']?.toString() ?? '',
      brand: (json['brand_name'] ?? json['brand'])?.toString() ?? '',
      form: json['form']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      packaging: json['packaging']?.toString() ?? '',
      liste: json['liste']?.toString() ?? '',
      lab: (json['laboratory'] ?? json['lab'])?.toString() ?? '',
      pays: (json['country'] ?? json['pays'])?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'num': num,
      'regNum': regNum,
      'code': code,
      'dci': dci,
      'brand': brand,
      'form': form,
      'dosage': dosage,
      'packaging': packaging,
      'liste': liste,
      'lab': lab,
      'pays': pays,
      'type': type,
      'status': status,
    };
  }

  String get displayName {
    if (brand.isNotEmpty && dci.isNotEmpty && brand != dci) {
      return '$brand ($dci)';
    }
    return brand.isNotEmpty ? brand : dci;
  }

  String get fullPresentation {
    final parts = <String>[];
    if (displayName.isNotEmpty) parts.add(displayName);
    if (dosage.isNotEmpty) parts.add(dosage);
    if (form.isNotEmpty) parts.add(form);
    return parts.join(' • ');
  }
}

