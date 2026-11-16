import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'whiteboard_pdf_saver_stub.dart'
    if (dart.library.io) 'whiteboard_pdf_saver_io.dart'
    if (dart.library.js_interop) 'whiteboard_pdf_saver_web.dart';

class WhiteboardPdfExporter {
  /// Captures a RepaintBoundary and builds a crisp A4 Landscape PDF document,
  /// then saves/opens it on Mobile/Desktop or triggers download on Web.
  static Future<String?> exportCanvasToPdf({
    required GlobalKey repaintBoundaryKey,
    required String title,
    String? moduleName,
    double pixelRatio = 2.5,
  }) async {
    final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Canvas not ready for export.');
    }

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode whiteboard image.');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final Uint8List pdfBytes = await buildPdfFromPng(
      pngBytes: pngBytes,
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
      title: title,
      moduleName: moduleName,
    );

    return saveAndOpenPdfBytes(
      bytes: pdfBytes,
      fileName: title.isEmpty ? 'medsina_mindmap' : title,
    );
  }

  /// Builds a PDF byte buffer from a PNG image of the whiteboard.
  static Future<Uint8List> buildPdfFromPng({
    required Uint8List pngBytes,
    required double imageWidth,
    required double imageHeight,
    required String title,
    String? moduleName,
  }) async {
    final PdfDocument document = PdfDocument();
    document.pageSettings.orientation = imageWidth >= imageHeight
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait;
    document.pageSettings.margins.all = 24;

    final PdfPage page = document.pages.add();
    final Size clientSize = page.getClientSize();

    final PdfFont titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      15,
      style: PdfFontStyle.bold,
    );
    final PdfFont metaFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      9.5,
    );

    final String dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final String subtitle = moduleName != null && moduleName.isNotEmpty
        ? 'Medsina Whiteboard • $moduleName • $dateStr'
        : 'Medsina Whiteboard • $dateStr';

    page.graphics.drawString(
      title,
      titleFont,
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
      bounds: Rect.fromLTWH(0, 0, clientSize.width, 22),
    );
    page.graphics.drawString(
      subtitle,
      metaFont,
      brush: PdfSolidBrush(PdfColor(100, 116, 139)),
      bounds: Rect.fromLTWH(0, 22, clientSize.width, 16),
    );

    const double headerHeight = 44;
    final double availW = clientSize.width;
    final double availH = clientSize.height - headerHeight;

    final double scale = (imageWidth / availW > imageHeight / availH)
        ? (availW / imageWidth)
        : (availH / imageHeight);

    final double drawW = imageWidth * scale;
    final double drawH = imageHeight * scale;
    final double offsetX = (availW - drawW) / 2;
    final double offsetY = headerHeight + (availH - drawH) / 2;

    final PdfBitmap bitmap = PdfBitmap(pngBytes);
    page.graphics.drawImage(
      bitmap,
      Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
    );

    final List<int> saved = await document.save();
    document.dispose();
    return Uint8List.fromList(saved);
  }
}
