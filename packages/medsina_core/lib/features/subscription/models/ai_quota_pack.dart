class AiQuotaPack {
  final String id;
  final String name;
  final int credits;
  final double priceDzd;
  final String description;
  final bool isPopular;
  final String? discountBadge;

  const AiQuotaPack({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceDzd,
    required this.description,
    this.isPopular = false,
    this.discountBadge,
  });

  static const List<AiQuotaPack> availablePacks = [
    AiQuotaPack(
      id: 'pack_50',
      name: 'Pack Éco IA',
      credits: 60,
      priceDzd: 400,
      description: 'Idéal pour terminer une session intensive de révision ou une garde.',
    ),
    AiQuotaPack(
      id: 'pack_150',
      name: 'Pack Pro IA',
      credits: 200,
      priceDzd: 950,
      description: 'Recommandé pour les révisions complètes de dossiers cliniques et QCMs.',
      isPopular: true,
      discountBadge: 'Le plus populaire',
    ),
    AiQuotaPack(
      id: 'pack_500',
      name: 'Pack Max IA',
      credits: 600,
      priceDzd: 2200,
      description: 'Tranquillité absolue pour les révisions de concours sans jamais être freiné.',
      discountBadge: '-45% Économie',
    ),
  ];
}

