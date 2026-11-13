import 'package:flutter/material.dart';

enum ClinicalModality {
  ecg('ECG', Icons.monitor_heart_rounded, Color(0xFFEF4444)),
  radiologie('Radiologie', Icons.medical_information_rounded, Color(0xFF0284C7)),
  tdmIrm('TDM / IRM', Icons.view_in_ar_rounded, Color(0xFF8B5CF6)),
  dermatologie('Dermatologie', Icons.healing_rounded, Color(0xFFF59E0B)),
  ophtalmologie('Fond d\'œil', Icons.visibility_rounded, Color(0xFF10B981)),
  anatomopathologie('Anapath / Frottis', Icons.biotech_rounded, Color(0xFFEC4899));

  final String label;
  final IconData icon;
  final Color color;

  const ClinicalModality(this.label, this.icon, this.color);

  static ClinicalModality fromString(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('ecg')) return ClinicalModality.ecg;
    if (lower.contains('tdm') || lower.contains('irm') || lower.contains('scanner')) {
      return ClinicalModality.tdmIrm;
    }
    if (lower.contains('dermato')) return ClinicalModality.dermatologie;
    if (lower.contains('ophtalmo') || lower.contains('fond')) {
      return ClinicalModality.ophtalmologie;
    }
    if (lower.contains('anapath') || lower.contains('frottis') || lower.contains('biopsie')) {
      return ClinicalModality.anatomopathologie;
    }
    return ClinicalModality.radiologie;
  }
}

class ClinicalAtlasCase {
  final String id;
  final String title;
  final String specialty;
  final ClinicalModality modality;
  final String? imageUrl;
  final String clinicalContext;
  final List<String> keyFindings;
  final String diagnosis;
  final List<String> differentialDiagnosis;
  final String highYieldPearl;
  final List<String> tags;

  const ClinicalAtlasCase({
    required this.id,
    required this.title,
    required this.specialty,
    required this.modality,
    this.imageUrl,
    required this.clinicalContext,
    required this.keyFindings,
    required this.diagnosis,
    this.differentialDiagnosis = const [],
    required this.highYieldPearl,
    this.tags = const [],
  });

  factory ClinicalAtlasCase.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return ClinicalAtlasCase(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      specialty: json['specialty']?.toString() ?? 'Médecine',
      modality: ClinicalModality.fromString(json['modality']?.toString() ?? ''),
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      clinicalContext: json['clinical_context']?.toString() ??
          json['clinicalContext']?.toString() ??
          '',
      keyFindings: strList(json['key_findings'] ?? json['keyFindings']),
      diagnosis: json['diagnosis']?.toString() ?? '',
      differentialDiagnosis: strList(
        json['differential_diagnosis'] ?? json['differentialDiagnosis'],
      ),
      highYieldPearl: json['high_yield_pearl']?.toString() ??
          json['highYieldPearl']?.toString() ??
          '',
      tags: strList(json['tags']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'specialty': specialty,
        'modality': modality.label,
        'image_url': imageUrl,
        'clinical_context': clinicalContext,
        'key_findings': keyFindings,
        'diagnosis': diagnosis,
        'differential_diagnosis': differentialDiagnosis,
        'high_yield_pearl': highYieldPearl,
        'tags': tags,
      };
}
