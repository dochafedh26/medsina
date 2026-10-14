import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/network/supabase_service.dart';
import 'vidal_interaction_repository.dart';

class TerrainContraindicationRule {
  final String terrain;
  final String terrainNormalized;
  final String drugClass;
  final List<String> drugPatterns;
  final InteractionSeverity severity;
  final int severityLevel;
  final String title;
  final String warning;
  final String recommendation;
  final String source;

  const TerrainContraindicationRule({
    required this.terrain,
    required this.terrainNormalized,
    required this.drugClass,
    required this.drugPatterns,
    required this.severity,
    required this.severityLevel,
    required this.title,
    required this.warning,
    required this.recommendation,
    this.source = 'Vidal / ANSM / MSPRH',
  });

  factory TerrainContraindicationRule.fromJson(Map<String, dynamic> json) {
    InteractionSeverity sev;
    switch (json['severity']?.toString().toLowerCase()) {
      case 'contraindicated':
        sev = InteractionSeverity.contraindicated;
        break;
      case 'disadvised':
        sev = InteractionSeverity.disadvised;
        break;
      case 'precaution':
        sev = InteractionSeverity.precaution;
        break;
      default:
        sev = InteractionSeverity.info;
        break;
    }

    final rawPatterns = json['drug_patterns'] ?? json['drugPatterns'] ?? [];
    final patterns = (rawPatterns as List<dynamic>)
        .map((e) => VidalInteractionRepository.normalize(e.toString()))
        .toList();

    return TerrainContraindicationRule(
      terrain: json['terrain']?.toString() ?? '',
      terrainNormalized: json['terrain_normalized']?.toString() ??
          VidalInteractionRepository.normalize(json['terrain']?.toString() ?? ''),
      drugClass: json['drug_class']?.toString() ?? json['drugClass']?.toString() ?? '',
      drugPatterns: patterns,
      severity: sev,
      severityLevel: json['severity_level'] is int
          ? json['severity_level']
          : (json['severityLevel'] is int ? json['severityLevel'] : 3),
      title: json['title']?.toString() ?? '',
      warning: json['warning']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Vidal / ANSM / MSPRH',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'terrain': terrain,
      'terrain_normalized': terrainNormalized,
      'drug_class': drugClass,
      'drug_patterns': drugPatterns,
      'severity': severity.name,
      'severity_level': severityLevel,
      'title': title,
      'warning': warning,
      'recommendation': recommendation,
      'source': source,
    };
  }
}

class TerrainContraindicationRepository {
  static List<TerrainContraindicationRule>? _cachedRules;

  static Future<List<TerrainContraindicationRule>> loadRules() async {
    if (_cachedRules != null && _cachedRules!.isNotEmpty) {
      return _cachedRules!;
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/data/vidal_terrain_contraindications.json');
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
      _cachedRules = list
          .map((item) => TerrainContraindicationRule.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cachedRules = [];
    }

    // Try fetching from Supabase table if available
    try {
      final cloudData = await SupabaseService.fetchVidalTerrainContraindications();
      if (cloudData.isNotEmpty) {
        final cloudRules = cloudData
            .map((item) => TerrainContraindicationRule.fromJson(item))
            .toList();
        
        final existingTitles = _cachedRules!.map((r) => r.title.toLowerCase()).toSet();
        for (final cr in cloudRules) {
          if (!existingTitles.contains(cr.title.toLowerCase())) {
            _cachedRules!.add(cr);
            existingTitles.add(cr.title.toLowerCase());
          }
        }
      }
    } catch (_) {}

    return _cachedRules ?? [];
  }

  /// Records a new rule into local cache & Cloud
  static Future<void> recordNewRule(TerrainContraindicationRule newRule) async {
    _cachedRules ??= [];
    final alreadyExists = _cachedRules!.any((r) => r.title.toLowerCase() == newRule.title.toLowerCase());
    if (!alreadyExists) {
      _cachedRules!.add(newRule);
    }
    try {
      await SupabaseService.insertVidalTerrainContraindication(newRule.toJson());
    } catch (_) {}
  }

  static bool _matchesTerrain(String ruleTerrain, String selectedTerrain) {
    final r = VidalInteractionRepository.normalize(ruleTerrain);
    final s = VidalInteractionRepository.normalize(selectedTerrain);
    if (r == s) return true;
    if (r.contains(s) || s.contains(r)) return true;

    // Token overlap comparison (words length >= 4)
    final rTokens = r.replaceAll(RegExp(r'[^A-Z0-9]'), ' ').split(' ').where((w) => w.length >= 4).toSet();
    final sTokens = s.replaceAll(RegExp(r'[^A-Z0-9]'), ' ').split(' ').where((w) => w.length >= 4).toSet();
    if (rTokens.isNotEmpty && sTokens.isNotEmpty && rTokens.intersection(sTokens).isNotEmpty) {
      return true;
    }
    return false;
  }

  static List<TerrainContraindicationRule> findContraindications(
    List<PrescribedTarget> prescribedDrugs,
    Set<String> selectedTerrains,
    List<TerrainContraindicationRule> rules,
  ) {
    final results = <TerrainContraindicationRule>[];
    final seen = <String>{};

    for (final terrain in selectedTerrains) {
      for (final drug in prescribedDrugs) {
        final dName = VidalInteractionRepository.normalize(drug.name);
        final dDci = VidalInteractionRepository.normalize(drug.activeDci ?? '');

        for (final rule in rules) {
          if (!_matchesTerrain(rule.terrain, terrain)) continue;

          bool matches = false;
          for (final pattern in rule.drugPatterns) {
            final p = VidalInteractionRepository.normalize(pattern);
            if (p.isEmpty) continue;
            if (dName == p || dDci == p || dName.contains(p) || dDci.contains(p) || p.contains(dName)) {
              matches = true;
              break;
            }
          }

          if (matches) {
            final key = '${rule.terrain}_${rule.drugClass}_${rule.title}';
            if (!seen.contains(key)) {
              results.add(rule);
              seen.add(key);
            }
          }
        }
      }
    }

    // Sort descending by severity level
    results.sort((a, b) => b.severityLevel.compareTo(a.severityLevel));
    return results;
  }
}
