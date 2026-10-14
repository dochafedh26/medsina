
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/network/supabase_service.dart';
import '../models/algerian_drug_model.dart';

class AlgerianNomenclatureRepository {
  static List<AlgerianDrugModel>? _cachedCatalog;

  static Future<List<AlgerianDrugModel>> loadCatalog() async {
    if (_cachedCatalog != null && _cachedCatalog!.isNotEmpty) {
      return _cachedCatalog!;
    }
    try {
      final jsonStr = await rootBundle.loadString('assets/data/algerian_nomenclature.json');
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
      _cachedCatalog = list.map((item) => AlgerianDrugModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      _cachedCatalog = [];
    }

    // Cloud sync fallback if local bundle had issue or to supplement
    try {
      if (_cachedCatalog == null || _cachedCatalog!.isEmpty) {
        final cloudDrugs = await SupabaseService.fetchAlgerianNomenclature(limit: 500);
        if (cloudDrugs.isNotEmpty) {
          _cachedCatalog = cloudDrugs.map((item) => AlgerianDrugModel.fromJson(item)).toList();
        }
      }
    } catch (_) {}

    return _cachedCatalog ?? [];
  }

  static String normalize(String input) {
    var s = input.trim().toUpperCase();
    const accents = {
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
      'Ý': 'Y', 'Ÿ': 'Y',
      'Ç': 'C', 'Ñ': 'N',
      'Œ': 'OE', 'Æ': 'AE',
    };
    accents.forEach((key, value) {
      s = s.replaceAll(key, value);
    });
    return s;
  }

  static List<AlgerianDrugModel> search(String query, {int limit = 25}) {
    final catalog = _cachedCatalog ?? [];
    final clean = normalize(query);
    if (clean.isEmpty) {
      return catalog.take(limit).toList();
    }

    final exactMatches = <AlgerianDrugModel>[];
    final prefixMatches = <AlgerianDrugModel>[];
    final containsMatches = <AlgerianDrugModel>[];

    for (final drug in catalog) {
      final b = normalize(drug.brand);
      final d = normalize(drug.dci);
      if (b == clean || d == clean) {
        exactMatches.add(drug);
      } else if (b.startsWith(clean) || d.startsWith(clean)) {
        prefixMatches.add(drug);
      } else if (b.contains(clean) || d.contains(clean) || drug.code.toUpperCase().contains(clean)) {
        containsMatches.add(drug);
      }
      if (exactMatches.length + prefixMatches.length + containsMatches.length >= limit * 2) {
        break;
      }
    }

    final combined = [...exactMatches, ...prefixMatches, ...containsMatches];
    return combined.take(limit).toList();
  }

  static String resolveActiveDci(String drugName) {
    final clean = normalize(drugName);
    final catalog = _cachedCatalog ?? [];

    // Pass 1: Exact matches on brand or DCI
    for (final drug in catalog) {
      final b = normalize(drug.brand);
      final d = normalize(drug.dci);
      if (b == clean || d == clean) {
        return drug.dci;
      }
    }

    // Pass 2: Brand or DCI starts with query
    for (final drug in catalog) {
      final b = normalize(drug.brand);
      final d = normalize(drug.dci);
      if (b.startsWith(clean) || d.startsWith(clean)) {
        return drug.dci;
      }
    }

    // Pass 3: Brand or DCI contains query (e.g. "SINTROM 4MG" contains "SINTROM")
    for (final drug in catalog) {
      final b = normalize(drug.brand);
      final d = normalize(drug.dci);
      if (b.contains(clean) || d.contains(clean)) {
        return drug.dci;
      }
    }

    return clean;
  }
}

