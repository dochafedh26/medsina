import 'whiteboard_model.dart';

enum WhiteboardTemplateType {
  blank,
  mindmap,
  physiopathologie,
  decisionTree,
}

class WhiteboardTemplateInfo {
  final WhiteboardTemplateType type;
  final String title;
  final String description;

  const WhiteboardTemplateInfo({
    required this.type,
    required this.title,
    required this.description,
  });
}

class WhiteboardTemplates {
  static const List<WhiteboardTemplateInfo> all = [
    WhiteboardTemplateInfo(
      type: WhiteboardTemplateType.blank,
      title: 'Tableau Vierge',
      description: 'Canvas libre pour dessiner, écrire et relier vos idées.',
    ),
    WhiteboardTemplateInfo(
      type: WhiteboardTemplateType.mindmap,
      title: 'Carte Mentale (Mindmap)',
      description: 'Sujet central relié à 4 branches clés de révision.',
    ),
    WhiteboardTemplateInfo(
      type: WhiteboardTemplateType.physiopathologie,
      title: 'Schéma Physiopathologie',
      description: 'Étiologie → Mécanisme → Clinique → Paraclinique → PEC.',
    ),
    WhiteboardTemplateInfo(
      type: WhiteboardTemplateType.decisionTree,
      title: 'Arbre Décisionnel / CAT',
      description: 'Conduite à tenir diagnostique et thérapeutique.',
    ),
  ];

  static WhiteboardCanvasData build(
    WhiteboardTemplateType type, {
    String? topicTitle,
  }) {
    final centralTitle =
        (topicTitle != null && topicTitle.trim().isNotEmpty)
            ? topicTitle.trim()
            : 'Sujet Principal';

    switch (type) {
      case WhiteboardTemplateType.blank:
        return const WhiteboardCanvasData();

      case WhiteboardTemplateType.mindmap:
        return WhiteboardCanvasData(
          nodes: [
            WhiteboardNode(
              id: 'n_center',
              x: 1100,
              y: 1100,
              width: 210,
              height: 86,
              title: centralTitle,
              subtitle: 'Idée centrale',
              colorValue: 0xFF0F172A,
              shape: WhiteboardNodeShape.pill,
            ),
            const WhiteboardNode(
              id: 'n_b1',
              x: 800,
              y: 930,
              width: 185,
              height: 76,
              title: '1. Définition & Étiologies',
              subtitle: 'Points clés...',
              colorValue: 0xFF0D9488,
            ),
            const WhiteboardNode(
              id: 'n_b2',
              x: 1410,
              y: 930,
              width: 185,
              height: 76,
              title: '2. Signes Cliniques',
              subtitle: 'Triade / Syndrome...',
              colorValue: 0xFF2563EB,
            ),
            const WhiteboardNode(
              id: 'n_b3',
              x: 800,
              y: 1270,
              width: 185,
              height: 76,
              title: '3. Examens Compl.',
              subtitle: 'Gold standard...',
              colorValue: 0xFF7C3AED,
            ),
            const WhiteboardNode(
              id: 'n_b4',
              x: 1410,
              y: 1270,
              width: 185,
              height: 76,
              title: '4. Traitement / CAT',
              subtitle: '1ère intention...',
              colorValue: 0xFFDC2626,
            ),
          ],
          connectors: const [
            WhiteboardConnector(
              id: 'c_1',
              fromNodeId: 'n_center',
              toNodeId: 'n_b1',
              startX: 1100,
              startY: 1143,
              endX: 985,
              endY: 968,
              colorValue: 0xFF0D9488,
            ),
            WhiteboardConnector(
              id: 'c_2',
              fromNodeId: 'n_center',
              toNodeId: 'n_b2',
              startX: 1310,
              startY: 1143,
              endX: 1410,
              endY: 968,
              colorValue: 0xFF2563EB,
            ),
            WhiteboardConnector(
              id: 'c_3',
              fromNodeId: 'n_center',
              toNodeId: 'n_b3',
              startX: 1100,
              startY: 1143,
              endX: 985,
              endY: 1308,
              colorValue: 0xFF7C3AED,
            ),
            WhiteboardConnector(
              id: 'c_4',
              fromNodeId: 'n_center',
              toNodeId: 'n_b4',
              startX: 1310,
              startY: 1143,
              endX: 1410,
              endY: 1308,
              colorValue: 0xFFDC2626,
            ),
          ],
        );

      case WhiteboardTemplateType.physiopathologie:
        return WhiteboardCanvasData(
          nodes: [
            WhiteboardNode(
              id: 'p_1',
              x: 780,
              y: 1100,
              width: 175,
              height: 78,
              title: 'Étiologie',
              subtitle: centralTitle,
              colorValue: 0xFF0F172A,
            ),
            const WhiteboardNode(
              id: 'p_2',
              x: 1010,
              y: 1100,
              width: 185,
              height: 78,
              title: 'Mécanisme',
              subtitle: 'Cascade lésionnelle',
              colorValue: 0xFF0D9488,
            ),
            const WhiteboardNode(
              id: 'p_3',
              x: 1250,
              y: 1010,
              width: 185,
              height: 78,
              title: 'Clinique',
              subtitle: 'Signes fonctionnels',
              colorValue: 0xFF2563EB,
            ),
            const WhiteboardNode(
              id: 'p_4',
              x: 1250,
              y: 1190,
              width: 185,
              height: 78,
              title: 'Complications',
              subtitle: 'Signes de gravité',
              colorValue: 0xFFDC2626,
            ),
            const WhiteboardNode(
              id: 'p_5',
              x: 1495,
              y: 1100,
              width: 185,
              height: 78,
              title: 'Traitement',
              subtitle: 'Cible thérapeutique',
              colorValue: 0xFF059669,
            ),
          ],
          connectors: const [
            WhiteboardConnector(
              id: 'pc_1',
              fromNodeId: 'p_1',
              toNodeId: 'p_2',
              startX: 955,
              startY: 1139,
              endX: 1010,
              endY: 1139,
              colorValue: 0xFF0F172A,
            ),
            WhiteboardConnector(
              id: 'pc_2',
              fromNodeId: 'p_2',
              toNodeId: 'p_3',
              startX: 1195,
              startY: 1139,
              endX: 1250,
              endY: 1049,
              colorValue: 0xFF2563EB,
            ),
            WhiteboardConnector(
              id: 'pc_3',
              fromNodeId: 'p_2',
              toNodeId: 'p_4',
              startX: 1195,
              startY: 1139,
              endX: 1250,
              endY: 1229,
              colorValue: 0xFFDC2626,
            ),
            WhiteboardConnector(
              id: 'pc_4',
              fromNodeId: 'p_3',
              toNodeId: 'p_5',
              startX: 1435,
              startY: 1049,
              endX: 1495,
              endY: 1139,
              colorValue: 0xFF059669,
            ),
          ],
        );

      case WhiteboardTemplateType.decisionTree:
        return WhiteboardCanvasData(
          nodes: [
            WhiteboardNode(
              id: 'd_1',
              x: 1100,
              y: 920,
              width: 210,
              height: 78,
              title: centralTitle,
              subtitle: 'Motif / Suspicion',
              colorValue: 0xFF0F172A,
              shape: WhiteboardNodeShape.pill,
            ),
            const WhiteboardNode(
              id: 'd_2',
              x: 1110,
              y: 1065,
              width: 190,
              height: 82,
              title: 'Signes de gravité ?',
              subtitle: 'Critères d\'urgence',
              colorValue: 0xFFD97706,
              shape: WhiteboardNodeShape.diamond,
            ),
            const WhiteboardNode(
              id: 'd_3',
              x: 860,
              y: 1230,
              width: 190,
              height: 78,
              title: 'OUI → Urgence',
              subtitle: 'Hospitalisation / Réa',
              colorValue: 0xFFDC2626,
            ),
            const WhiteboardNode(
              id: 'd_4',
              x: 1340,
              y: 1230,
              width: 190,
              height: 78,
              title: 'NON → Bilan ciblé',
              subtitle: 'PEC ambulatoire',
              colorValue: 0xFF059669,
            ),
          ],
          connectors: const [
            WhiteboardConnector(
              id: 'dc_1',
              fromNodeId: 'd_1',
              toNodeId: 'd_2',
              startX: 1205,
              startY: 998,
              endX: 1205,
              endY: 1065,
              colorValue: 0xFF0F172A,
            ),
            WhiteboardConnector(
              id: 'dc_2',
              fromNodeId: 'd_2',
              toNodeId: 'd_3',
              startX: 1110,
              startY: 1106,
              endX: 955,
              endY: 1230,
              label: 'Oui',
              colorValue: 0xFFDC2626,
            ),
            WhiteboardConnector(
              id: 'dc_3',
              fromNodeId: 'd_2',
              toNodeId: 'd_4',
              startX: 1300,
              startY: 1106,
              endX: 1435,
              endY: 1230,
              label: 'Non',
              colorValue: 0xFF059669,
            ),
          ],
        );
    }
  }
}
