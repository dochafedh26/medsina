enum SearchResultType {
  course,
  courseSummary,
  catProtocol,
  memento,
  qcm,
  emergencyDrug,
  labValue,
  clinicalScore,
  userGuide,
}

class SearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final String snippet;
  final SearchResultType type;
  final int relevanceScore;
  final List<String> tags;
  final dynamic payload;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.snippet,
    required this.type,
    required this.relevanceScore,
    this.tags = const [],
    this.payload,
  });

  String get typeLabel {
    switch (type) {
      case SearchResultType.course:
        return 'Cours & PDF';
      case SearchResultType.courseSummary:
        return 'Fiche Synthèse';
      case SearchResultType.catProtocol:
        return 'CAT Urgence';
      case SearchResultType.memento:
        return 'Mémento Garde';
      case SearchResultType.qcm:
        return 'QCM Concours';
      case SearchResultType.emergencyDrug:
        return 'Médicament';
      case SearchResultType.labValue:
        return 'Norme Bio';
      case SearchResultType.clinicalScore:
        return 'Score Clinique';
      case SearchResultType.userGuide:
        return 'Guide Medsina';
    }
  }

  String get actionLabel {
    switch (type) {
      case SearchResultType.course:
        return 'Ouvrir le cours PDF';
      case SearchResultType.courseSummary:
        return 'Lire la synthèse';
      case SearchResultType.catProtocol:
        return 'Voir le protocole CAT';
      case SearchResultType.memento:
        return 'Consulter la fiche';
      case SearchResultType.qcm:
        return 'S\'entraîner sur ce QCM';
      case SearchResultType.emergencyDrug:
        return 'Posologie & DCI';
      case SearchResultType.labValue:
        return 'Interprétation Bio';
      case SearchResultType.clinicalScore:
        return 'Calculer le score';
      case SearchResultType.userGuide:
        return 'Consulter le guide';
    }
  }
}
