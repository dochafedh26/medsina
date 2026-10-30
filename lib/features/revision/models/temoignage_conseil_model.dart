import 'package:equatable/equatable.dart';

class TemoignageConseilItem extends Equatable {
  final String id;
  final String name;
  final String rankBadge;
  final int rankNumber;
  final String year;
  final String faculty;
  final bool isRecent2026;
  final String documentType; // 'pdf_local', 'gdrive_url', 'gdrive_folder'
  final String? targetUrl;
  final String? pdfFile;
  final String? extraPdfFile;
  final String summary;
  final List<String> keyAdvices;
  final String recommendedSources;

  const TemoignageConseilItem({
    required this.id,
    required this.name,
    required this.rankBadge,
    required this.rankNumber,
    required this.year,
    required this.faculty,
    required this.isRecent2026,
    required this.documentType,
    this.targetUrl,
    this.pdfFile,
    this.extraPdfFile,
    required this.summary,
    required this.keyAdvices,
    required this.recommendedSources,
  });

  String? get assetPdfPath =>
      pdfFile != null ? 'assets/data/temoignages/$pdfFile' : null;

  String? get extraAssetPdfPath =>
      extraPdfFile != null ? 'assets/data/temoignages/$extraPdfFile' : null;

  factory TemoignageConseilItem.fromJson(Map<String, dynamic> json) {
    return TemoignageConseilItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rankBadge: json['rank_badge'] as String? ?? 'TOP CLASSÉ',
      rankNumber: (json['rank_number'] as num?)?.toInt() ?? 99,
      year: json['year'] as String? ?? '2026',
      faculty: json['faculty'] as String? ?? 'Faculté de Médecine',
      isRecent2026: json['is_recent_2026'] as bool? ?? false,
      documentType: json['document_type'] as String? ?? 'pdf_local',
      targetUrl: json['target_url'] as String?,
      pdfFile: json['pdf_file'] as String?,
      extraPdfFile: json['extra_pdf_file'] as String?,
      summary: json['summary'] as String? ?? '',
      keyAdvices: (json['key_advices'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendedSources: json['recommended_sources'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rank_badge': rankBadge,
        'rank_number': rankNumber,
        'year': year,
        'faculty': faculty,
        'is_recent_2026': isRecent2026,
        'document_type': documentType,
        'target_url': targetUrl,
        'pdf_file': pdfFile,
        'extra_pdf_file': extraPdfFile,
        'summary': summary,
        'key_advices': keyAdvices,
        'recommended_sources': recommendedSources,
      };

  @override
  List<Object?> get props => [id, name, rankNumber, year, documentType];
}
