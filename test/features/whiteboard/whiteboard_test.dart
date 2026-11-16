import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/whiteboard/controllers/whiteboard_controller.dart';
import 'package:medsina/features/whiteboard/models/whiteboard_model.dart';
import 'package:medsina/features/whiteboard/models/whiteboard_templates.dart';
import 'package:medsina/features/whiteboard/services/whiteboard_pdf_exporter.dart';
import 'package:medsina/features/whiteboard/services/whiteboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WhiteboardModel & Templates', () {
    test('JSON round-trip preserves nodes, connectors, strokes, and shapes', () {
      final now = DateTime(2026, 11, 16, 10, 0);
      final board = WhiteboardModel(
        id: 'wb_1',
        title: 'Cardiologie HTA',
        courseId: 'c_cardio_hta',
        moduleName: 'Cardiologie',
        createdAt: now,
        updatedAt: now,
        data: const WhiteboardCanvasData(
          nodes: [
            WhiteboardNode(
              id: 'n1',
              x: 100,
              y: 200,
              title: 'HTA',
              subtitle: 'PAS >= 140',
            ),
          ],
          connectors: [
            WhiteboardConnector(
              id: 'c1',
              fromNodeId: 'n1',
              startX: 100,
              startY: 200,
              endX: 300,
              endY: 300,
              label: 'Traitement',
            ),
          ],
          strokes: [
            WhiteboardStroke(
              id: 's1',
              points: [Offset(10, 10), Offset(25, 30)],
              strokeWidth: 4.0,
            ),
          ],
          shapes: [
            WhiteboardShape(
              id: 'sh1',
              type: WhiteboardShapeType.rect,
              x: 50,
              y: 50,
              width: 120,
              height: 80,
            ),
          ],
          backgroundStyle: WhiteboardBackgroundStyle.grid,
        ),
      );

      final decoded = WhiteboardModel.fromJson(
        jsonDecode(jsonEncode(board.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.id, 'wb_1');
      expect(decoded.title, 'Cardiologie HTA');
      expect(decoded.courseId, 'c_cardio_hta');
      expect(decoded.data.nodes.length, 1);
      expect(decoded.data.nodes.first.title, 'HTA');
      expect(decoded.data.connectors.length, 1);
      expect(decoded.data.connectors.first.label, 'Traitement');
      expect(decoded.data.strokes.length, 1);
      expect(decoded.data.strokes.first.points.length, 2);
      expect(decoded.data.shapes.length, 1);
      expect(decoded.data.backgroundStyle, WhiteboardBackgroundStyle.grid);
    });

    test('Templates build expected structures', () {
      expect(
        WhiteboardTemplates.build(WhiteboardTemplateType.blank).isEmpty,
        isTrue,
      );
      final mindmap = WhiteboardTemplates.build(
        WhiteboardTemplateType.mindmap,
        topicTitle: 'Asthme',
      );
      expect(mindmap.nodes.length, 5);
      expect(mindmap.connectors.length, 4);
      expect(mindmap.nodes.first.title, 'Asthme');

      final physio = WhiteboardTemplates.build(
        WhiteboardTemplateType.physiopathologie,
      );
      expect(physio.nodes.length, 5);

      final decision = WhiteboardTemplates.build(
        WhiteboardTemplateType.decisionTree,
      );
      expect(decision.nodes.length, 4);
      expect(decision.connectors.length, 3);
    });
  });

  group('WhiteboardController', () {
    test('supports addNode, undo, redo, and cascade delete', () {
      final controller = WhiteboardController(
        initialData: WhiteboardTemplates.build(WhiteboardTemplateType.mindmap),
      );
      expect(controller.data.nodes.length, 5);
      expect(controller.data.connectors.length, 4);

      final added = controller.addNode(
        position: const Offset(500, 500),
        title: 'Test Node',
      );
      expect(controller.data.nodes.length, 6);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.data.nodes.length, 5);
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.data.nodes.length, 6);

      // Select center node and delete it -> should cascade delete 4 connectors
      controller.selectNode('n_center');
      controller.deleteSelected();
      expect(controller.data.nodes.any((n) => n.id == 'n_center'), isFalse);
      expect(controller.data.connectors, isEmpty);
      expect(added.title, 'Test Node');
    });
  });

  group('WhiteboardRepository (local fallback)', () {
    test('saves, fetches, filters by courseId, and deletes boards', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();

      final b1 = WhiteboardModel(
        id: 'wb_a',
        title: 'Board A',
        courseId: 'course_1',
        data: const WhiteboardCanvasData(),
        createdAt: now,
        updatedAt: now,
      );
      final b2 = WhiteboardModel(
        id: 'wb_b',
        title: 'Board B',
        courseId: 'course_2',
        data: const WhiteboardCanvasData(),
        createdAt: now,
        updatedAt: now,
      );

      await WhiteboardRepository.saveBoard(b1);
      await WhiteboardRepository.saveBoard(b2);

      final all = await WhiteboardRepository.fetchBoards(syncCloud: false);
      expect(all.length, 2);

      final filtered = await WhiteboardRepository.fetchBoards(
        courseId: 'course_1',
        syncCloud: false,
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, 'wb_a');

      await WhiteboardRepository.deleteBoard('wb_a');
      final afterDelete =
          await WhiteboardRepository.fetchBoards(syncCloud: false);
      expect(afterDelete.length, 1);
      expect(afterDelete.first.id, 'wb_b');
    });
  });

  group('WhiteboardPdfExporter', () {
    test('generates valid PDF bytes from a 1x1 PNG image', () async {
      // Minimal valid 1x1 transparent PNG
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      final pdfBytes = await WhiteboardPdfExporter.buildPdfFromPng(
        pngBytes: pngBytes,
        imageWidth: 800,
        imageHeight: 600,
        title: 'Test Mindmap',
        moduleName: 'Pneumologie',
      );

      expect(pdfBytes.length, greaterThan(100));
      // PDF files start with %PDF-
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
    });
  });
}
