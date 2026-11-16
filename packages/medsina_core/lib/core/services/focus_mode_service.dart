import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusPreset {
  final String label;
  final String subtitle;
  final List<String> keywords;
  final String iconKey;

  const FocusPreset({
    required this.label,
    required this.subtitle,
    required this.keywords,
    this.iconKey = 'medical',
  });
}

/// Manages Specialty / Module Rotation Focus Mode across Dashboard,
/// Résidanat, Externat, and Clinical Protocols (CAT).
class FocusModeService extends ChangeNotifier {
  static final FocusModeService instance = FocusModeService._();
  FocusModeService._();

  static const String _keyEnabled = 'medsina_focus_enabled';
  static const String _keyLabel = 'medsina_focus_label';
  static const String _keyType = 'medsina_focus_type'; // 'specialty' | 'module'
  static const String _keyKeywords = 'medsina_focus_keywords';

  bool _initialized = false;
  bool _isEnabled = false;
  String? _focusLabel;
  String _focusType = 'specialty';
  List<String> _keywords = [];

  bool get isEnabled => _isEnabled && (_focusLabel?.isNotEmpty ?? false);
  String? get focusLabel => _focusLabel;
  String get focusType => _focusType;
  List<String> get keywords => List.unmodifiable(_keywords);
  bool get isSpecialtyMode => _focusType == 'specialty';

  static const List<FocusPreset> presets = [
    FocusPreset(
      label: 'Cardiologie',
      subtitle: 'SCA, HTA, IC, Valvulopathies, ECG & Urgences',
      keywords: ['cardio', 'hta', 'coronar', 'ecg', 'valvul'],
      iconKey: 'heart',
    ),
    FocusPreset(
      label: 'Pneumologie',
      subtitle: 'Asthme, BPCO, Pneumonies, Embolie & Phtisiologie',
      keywords: ['pneumo', 'phtisio', 'respir', 'asthme', 'bpco'],
      iconKey: 'lungs',
    ),
    FocusPreset(
      label: 'Neurologie',
      subtitle: 'AVC, Épilepsie, Méningites, Céphalées & Neuro-UMC',
      keywords: ['neuro', 'avc', 'epilep'],
      iconKey: 'brain',
    ),
    FocusPreset(
      label: 'Pédiatrie',
      subtitle: 'Néonatologie, Pédiatrie Générale & Urgences Pédiatriques',
      keywords: ['pediat', 'neonat', 'nourrisson'],
      iconKey: 'child',
    ),
    FocusPreset(
      label: 'Gynécologie-Obstétrique',
      subtitle: 'Grossesse, HTA gravidique, Accouchement & Gynéco',
      keywords: ['gynec', 'obstetr', 'gravid'],
      iconKey: 'pregnant',
    ),
    FocusPreset(
      label: 'Endocrinologie',
      subtitle: 'Diabète, CAD, Thyroïde, Surrénales & Métabolisme',
      keywords: ['endocrin', 'diabet', 'thyroid', 'metabol'],
      iconKey: 'endocrino',
    ),
    FocusPreset(
      label: 'Néphrologie',
      subtitle: 'IRA, IRC, Troubles hydro-électrolytiques & Dialyse',
      keywords: ['nephro', 'renal', 'electrolyt'],
      iconKey: 'kidney',
    ),
    FocusPreset(
      label: 'Gastro-Hépatologie',
      subtitle: 'Hémorragies digestives, Cirrhose, MICI & Pancréas',
      keywords: ['gastro', 'hepat', 'digest', 'cirrhose'],
      iconKey: 'stomach',
    ),
    FocusPreset(
      label: 'Infectiologie',
      subtitle: 'Sepsis, Antibiothérapie, Méningites & Maladies Infectieuses',
      keywords: ['infect', 'sepsis', 'antibio', 'microbio'],
      iconKey: 'virus',
    ),
    FocusPreset(
      label: 'Réanimation & Urgences',
      subtitle: 'UMC, États de choc, Toxicologie & Détresses vitales',
      keywords: ['reanim', 'urgence', 'umc', 'toxico', 'choc', 'allergo'],
      iconKey: 'emergency',
    ),
    FocusPreset(
      label: 'Chirurgie Générale',
      subtitle: 'Urgences abdominales, Viscéral & Péri-opératoire',
      keywords: ['chirurg', 'viscer', 'abdom'],
      iconKey: 'scalpel',
    ),
    FocusPreset(
      label: 'Orthopédie & Traumatologie',
      subtitle: 'Fractures, Polytraumatisme & Appareil locomoteur',
      keywords: ['orthop', 'traumat'],
      iconKey: 'bone',
    ),
    FocusPreset(
      label: 'Hématologie',
      subtitle: 'Anémies, Leucémies, Hémostase & Transfusion',
      keywords: ['hemato', 'anem', 'hemostas'],
      iconKey: 'blood',
    ),
    FocusPreset(
      label: 'Rhumatologie',
      subtitle: 'Arthrites, Connectivites, Lombalgies & Os',
      keywords: ['rhumato', 'arthrit'],
      iconKey: 'joint',
    ),
    FocusPreset(
      label: 'Psychiatrie',
      subtitle: 'Urgences psychiatriques, Troubles de l\'humeur & Psychoses',
      keywords: ['psychiat', 'psych'],
      iconKey: 'mind',
    ),
    FocusPreset(
      label: 'Dermatologie',
      subtitle: 'Dermatoses inflammatoires, Infectieuses & Bulleuses',
      keywords: ['dermat'],
      iconKey: 'skin',
    ),
    FocusPreset(
      label: 'Ophtalmologie',
      subtitle: 'Œil rouge, Glaucome, BAV & Traumatismes oculaires',
      keywords: ['ophtalm'],
      iconKey: 'eye',
    ),
    FocusPreset(
      label: 'ORL',
      subtitle: 'Vertiges, Angines, Dyspnées laryngées & Otites',
      keywords: ['orl', 'oto', 'laryng'],
      iconKey: 'ear',
    ),
    FocusPreset(
      label: 'Urologie',
      subtitle: 'Colique néphrétique, RAU, Infections & Tumeurs urologiques',
      keywords: ['urol'],
      iconKey: 'uro',
    ),
    FocusPreset(
      label: 'Médecine Interne',
      subtitle: 'Maladies systémiques, Vascularites & Fièvres prolongées',
      keywords: ['medecine interne', 'systemiq', 'interne'],
      iconKey: 'internal',
    ),
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_keyEnabled) ?? false;
      _focusLabel = prefs.getString(_keyLabel);
      _focusType = prefs.getString(_keyType) ?? 'specialty';
      _keywords = prefs.getStringList(_keyKeywords) ?? [];
      if (_isEnabled && (_focusLabel == null || _focusLabel!.isEmpty)) {
        _isEnabled = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('FocusModeService init notice: $e');
    }
  }

  Future<void> enableFocus({
    required String label,
    String type = 'specialty',
    List<String>? keywords,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;

    final resolvedKeywords = (keywords != null && keywords.isNotEmpty)
        ? keywords.map(_normalize).where((k) => k.isNotEmpty).toList()
        : _deriveKeywords(trimmed);

    _isEnabled = true;
    _focusLabel = trimmed;
    _focusType = type;
    _keywords = resolvedKeywords;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, true);
      await prefs.setString(_keyLabel, trimmed);
      await prefs.setString(_keyType, type);
      await prefs.setStringList(_keyKeywords, resolvedKeywords);
    } catch (e) {
      debugPrint('FocusModeService save error: $e');
    }
  }

  Future<void> disableFocus() async {
    _isEnabled = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, false);
    } catch (e) {
      debugPrint('FocusModeService disable error: $e');
    }
  }

  /// Checks whether [text] (module name, protocol specialty, etc.) belongs to the active focus.
  bool matchesText(String text) {
    if (!isEnabled) return true;
    final normText = _normalize(text);
    if (normText.isEmpty) return false;

    final normLabel = _normalize(_focusLabel ?? '');
    if (normLabel.isNotEmpty &&
        (normText.contains(normLabel) || normLabel.contains(normText))) {
      return true;
    }

    for (final kw in _keywords) {
      if (kw.isNotEmpty && normText.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  static List<String> _deriveKeywords(String label) {
    final norm = _normalize(label);
    for (final preset in presets) {
      final pNorm = _normalize(preset.label);
      if (pNorm == norm || norm.contains(pNorm) || pNorm.contains(norm)) {
        return preset.keywords.map(_normalize).toList();
      }
    }
    final tokens = norm
        .split(RegExp(r'[\s\-&/,]+'))
        .where((t) => t.length >= 4)
        .toList();
    return tokens.isNotEmpty ? tokens : [norm];
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll('œ', 'oe')
        .trim();
  }
}
