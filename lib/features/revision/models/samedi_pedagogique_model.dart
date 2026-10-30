import 'package:equatable/equatable.dart';

class SamediPedagogiqueItem extends Equatable {
  final String id;
  final String title;
  final String specialty;
  final String module;
  final String type; // 'cas_clinique', 'qcs', 'dossier_cours', 'fiche_reflexe', 'planning'
  final String typeLabel;
  final String pdfFile;
  final int pagesCount;
  final double sizeKb;
  final String description;
  final List<String> keywords;

  const SamediPedagogiqueItem({
    required this.id,
    required this.title,
    required this.specialty,
    required this.module,
    required this.type,
    required this.typeLabel,
    required this.pdfFile,
    required this.pagesCount,
    required this.sizeKb,
    required this.description,
    required this.keywords,
  });

  String get assetPath => 'assets/data/samedis_pedagogiques/$pdfFile';

  factory SamediPedagogiqueItem.fromJson(Map<String, dynamic> json) {
    return SamediPedagogiqueItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Sans titre',
      specialty: json['specialty'] as String? ?? 'Général',
      module: json['module'] as String? ?? 'Clinique',
      type: json['type'] as String? ?? 'dossier_cours',
      typeLabel: json['type_label'] as String? ?? 'Dossier Clinique',
      pdfFile: json['pdf_file'] as String? ?? '',
      pagesCount: (json['pages_count'] as num?)?.toInt() ?? 1,
      sizeKb: (json['size_kb'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'specialty': specialty,
        'module': module,
        'type': type,
        'type_label': typeLabel,
        'pdf_file': pdfFile,
        'pages_count': pagesCount,
        'size_kb': sizeKb,
        'description': description,
        'keywords': keywords,
      };

  @override
  List<Object?> get props => [id, title, specialty, module, type, pdfFile];
}
