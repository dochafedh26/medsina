
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:medsina_core/core/network/supabase_service.dart';
import '../models/algerian_drug_model.dart';
import 'therapeutic_classes.dart';

enum DrugSearchMode {
  all,
  brand,
  dci,
  laboratory,
  code,
}

class DrugSearchFilter {
  final String query;
  final DrugSearchMode mode;
  final String? therapeuticClassPrefix;
  final String? laboratory;
  final String? formCategory; // e.g. 'COMPRIME', 'GELULE', 'SIROP', 'INJECTABLE', 'COLLYRE', 'POMMADE', 'SUPPOSITOIRE'
  final String? liste;        // e.g. 'LISTE I', 'LISTE II', 'STUPEFIANT'
  final String? drugType;     // 'RE' (Princeps), 'GE' (Générique), 'BIO' (Biologique)
  final String? originStatus; // 'F' (Fabriqué DZ), 'I' (Importé)

  const DrugSearchFilter({
    this.query = '',
    this.mode = DrugSearchMode.all,
    this.therapeuticClassPrefix,
    this.laboratory,
    this.formCategory,
    this.liste,
    this.drugType,
    this.originStatus,
  });

  bool get hasActiveFacets =>
      (therapeuticClassPrefix != null && therapeuticClassPrefix!.isNotEmpty) ||
      (laboratory != null && laboratory!.isNotEmpty) ||
      (formCategory != null && formCategory!.isNotEmpty) ||
      (liste != null && liste!.isNotEmpty) ||
      (drugType != null && drugType!.isNotEmpty) ||
      (originStatus != null && originStatus!.isNotEmpty);
}

class DciSummary {
  final String dci;
  final int totalSpecialties;
  final int princepsCount;
  final int genericCount;
  final String? classPrefix;
  final List<String> sampleBrands;

  const DciSummary({
    required this.dci,
    required this.totalSpecialties,
    required this.princepsCount,
    required this.genericCount,
    this.classPrefix,
    required this.sampleBrands,
  });
}

class LaboratorySummary {
  final String name;
  final String country;
  final int productCount;

  const LaboratorySummary({
    required this.name,
    required this.country,
    required this.productCount,
  });
}

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
    return advancedSearch(DrugSearchFilter(query: query), limit: limit);
  }

  static List<AlgerianDrugModel> advancedSearch(DrugSearchFilter filter, {int limit = 60}) {
    final catalog = _cachedCatalog ?? [];
    final cleanQuery = normalize(filter.query);
    final normLab = filter.laboratory != null ? normalize(filter.laboratory!) : null;
    final normForm = filter.formCategory != null ? normalize(filter.formCategory!) : null;
    final normListe = filter.liste != null ? normalize(filter.liste!) : null;
    final normType = filter.drugType != null ? normalize(filter.drugType!) : null;
    final normOrigin = filter.originStatus != null ? normalize(filter.originStatus!) : null;
    final classPrefix = filter.therapeuticClassPrefix?.trim();

    final exactMatches = <AlgerianDrugModel>[];
    final prefixMatches = <AlgerianDrugModel>[];
    final containsMatches = <AlgerianDrugModel>[];
    final facetOnlyMatches = <AlgerianDrugModel>[];

    for (final drug in catalog) {
      // 1. Apply structured facets first
      if (classPrefix != null && classPrefix.isNotEmpty) {
        if (TherapeuticClasses.extractPrefix(drug.code) != classPrefix) continue;
      }
      if (normLab != null && normLab.isNotEmpty) {
        if (normalize(drug.lab) != normLab) continue;
      }
      if (normForm != null && normForm.isNotEmpty) {
        final f = normalize(drug.form);
        if (normForm == 'INJECTABLE') {
          if (!f.contains('INJECT') && !f.contains('PERFUSION') && !f.contains('SOL. INJ')) continue;
        } else if (normForm == 'SIROP / SUSP') {
          if (!f.contains('SIROP') && !f.contains('SUSP') && !f.contains('BUVABLE')) continue;
        } else if (normForm == 'CREME / POMMADE') {
          if (!f.contains('CREME') && !f.contains('POMMADE') && !f.contains('GEL') && !f.contains('DERMIQUE')) continue;
        } else if (!f.contains(normForm)) {
          continue;
        }
      }
      if (normListe != null && normListe.isNotEmpty) {
        if (normalize(drug.liste) != normListe) continue;
      }
      if (normType != null && normType.isNotEmpty) {
        if (normalize(drug.type) != normType) continue;
      }
      if (normOrigin != null && normOrigin.isNotEmpty) {
        if (normalize(drug.status) != normOrigin) continue;
      }

      // 2. If no text query, collect facet matches directly
      if (cleanQuery.isEmpty) {
        facetOnlyMatches.add(drug);
        if (facetOnlyMatches.length >= limit) break;
        continue;
      }

      // 3. Apply text matching according to search mode
      final b = normalize(drug.brand);
      final d = normalize(drug.dci);
      final l = normalize(drug.lab);
      final c = drug.code.toUpperCase();

      bool isExact = false;
      bool isPrefix = false;
      bool isContains = false;

      switch (filter.mode) {
        case DrugSearchMode.brand:
          isExact = b == cleanQuery;
          isPrefix = !isExact && b.startsWith(cleanQuery);
          isContains = !isExact && !isPrefix && b.contains(cleanQuery);
          break;
        case DrugSearchMode.dci:
          isExact = d == cleanQuery;
          isPrefix = !isExact && d.startsWith(cleanQuery);
          isContains = !isExact && !isPrefix && d.contains(cleanQuery);
          break;
        case DrugSearchMode.laboratory:
          isExact = l == cleanQuery;
          isPrefix = !isExact && l.startsWith(cleanQuery);
          isContains = !isExact && !isPrefix && l.contains(cleanQuery);
          break;
        case DrugSearchMode.code:
          isExact = c == cleanQuery;
          isPrefix = !isExact && c.startsWith(cleanQuery);
          isContains = !isExact && !isPrefix && c.contains(cleanQuery);
          break;
        case DrugSearchMode.all:
          isExact = b == cleanQuery || d == cleanQuery;
          isPrefix = !isExact && (b.startsWith(cleanQuery) || d.startsWith(cleanQuery));
          isContains = !isExact &&
              !isPrefix &&
              (b.contains(cleanQuery) || d.contains(cleanQuery) || c.contains(cleanQuery) || l.contains(cleanQuery));
          break;
      }

      if (isExact) {
        exactMatches.add(drug);
      } else if (isPrefix) {
        prefixMatches.add(drug);
      } else if (isContains) {
        containsMatches.add(drug);
      }

      if (exactMatches.length + prefixMatches.length + containsMatches.length >= limit * 2) {
        break;
      }
    }

    if (cleanQuery.isEmpty) {
      return facetOnlyMatches.take(limit).toList();
    }
    return [...exactMatches, ...prefixMatches, ...containsMatches].take(limit).toList();
  }

  /// Returns unique DCIs with specialty counts (Vidal "Substances actives" directory).
  static List<DciSummary> getUniqueDcis({
    String query = '',
    String? therapeuticClassPrefix,
    int limit = 100,
  }) {
    final catalog = _cachedCatalog ?? [];
    final cleanQuery = normalize(query);
    final grouped = <String, List<AlgerianDrugModel>>{};

    for (final drug in catalog) {
      if (drug.dci.trim().isEmpty) continue;
      if (therapeuticClassPrefix != null && therapeuticClassPrefix.isNotEmpty) {
        if (TherapeuticClasses.extractPrefix(drug.code) != therapeuticClassPrefix) continue;
      }
      final key = normalize(drug.dci);
      if (cleanQuery.isNotEmpty && !key.contains(cleanQuery)) continue;
      grouped.putIfAbsent(key, () => []).add(drug);
    }

    final summaries = grouped.entries.map((entry) {
      final items = entry.value;
      final princepsCount = items.where((d) => normalize(d.type) == 'RE').length;
      final genericCount = items.where((d) => normalize(d.type) == 'GE').length;
      final brands = items.map((d) => d.brand).where((b) => b.isNotEmpty).toSet().take(4).toList();
      final prefix = TherapeuticClasses.extractPrefix(items.first.code);
      return DciSummary(
        dci: items.first.dci,
        totalSpecialties: items.length,
        princepsCount: princepsCount,
        genericCount: genericCount,
        classPrefix: prefix.isNotEmpty ? prefix : null,
        sampleBrands: brands,
      );
    }).toList();

    summaries.sort((a, b) {
      if (cleanQuery.isNotEmpty) {
        final aStarts = normalize(a.dci).startsWith(cleanQuery);
        final bStarts = normalize(b.dci).startsWith(cleanQuery);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
      }
      return b.totalSpecialties.compareTo(a.totalSpecialties);
    });

    return summaries.take(limit).toList();
  }

  /// Returns unique laboratories with product counts (Vidal "Par laboratoire").
  static List<LaboratorySummary> getUniqueLaboratories({
    String query = '',
    int limit = 120,
  }) {
    final catalog = _cachedCatalog ?? [];
    final cleanQuery = normalize(query);
    final grouped = <String, List<AlgerianDrugModel>>{};

    for (final drug in catalog) {
      if (drug.lab.trim().isEmpty) continue;
      final key = normalize(drug.lab);
      if (cleanQuery.isNotEmpty && !key.contains(cleanQuery)) continue;
      grouped.putIfAbsent(key, () => []).add(drug);
    }

    final labs = grouped.entries.map((entry) {
      final items = entry.value;
      return LaboratorySummary(
        name: items.first.lab,
        country: items.first.pays,
        productCount: items.length,
      );
    }).toList();

    labs.sort((a, b) {
      if (cleanQuery.isNotEmpty) {
        final aStarts = normalize(a.name).startsWith(cleanQuery);
        final bStarts = normalize(b.name).startsWith(cleanQuery);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
      }
      return b.productCount.compareTo(a.productCount);
    });

    return labs.take(limit).toList();
  }

  /// Returns all Algerian specialties sharing the given DCI (Princeps RE first, then Generics GE).
  static List<AlgerianDrugModel> getEquivalentsForDci(String dci) {
    final catalog = _cachedCatalog ?? [];
    final clean = normalize(dci);
    if (clean.isEmpty) return [];

    final matches = catalog.where((d) {
      final itemDci = normalize(d.dci);
      return itemDci == clean || itemDci.contains(clean);
    }).toList();

    matches.sort((a, b) {
      int rank(AlgerianDrugModel d) {
        final t = normalize(d.type);
        if (t == 'RE') return 0;
        if (t == 'BIO') return 1;
        if (t == 'GE') return 2;
        return 3;
      }
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.brand.compareTo(b.brand);
    });

    return matches;
  }

  /// Counts how many products belong to each MSPRH therapeutic class prefix ('01'..'28').
  static Map<String, int> getTherapeuticClassCounts() {
    final catalog = _cachedCatalog ?? [];
    final counts = <String, int>{};
    for (final drug in catalog) {
      final prefix = TherapeuticClasses.extractPrefix(drug.code);
      if (prefix.isNotEmpty) {
        counts[prefix] = (counts[prefix] ?? 0) + 1;
      }
    }
    return counts;
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

