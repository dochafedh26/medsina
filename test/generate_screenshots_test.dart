import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/core/constants/app_constants.dart';
import 'package:medsina/core/theme/app_theme.dart';
import 'package:medsina/features/auth/models/user_model.dart';
import 'package:medsina/features/prescription/presentation/prescription_analysis_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Generate high-definition real mobile & desktop screenshots', (tester) async {
    // 1. Mobile Prescription Screen
    final repaintKeyMobile = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(412, 892));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: RepaintBoundary(
          key: repaintKeyMobile,
          child: const Scaffold(
            body: PrescriptionAnalysisScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final boundary = repaintKeyMobile.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final file = File('assets/screenshots/mobile/prescription_mobile.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(byteData.buffer.asUint8List());
        // ignore: avoid_print
        print('Captured real assets/screenshots/mobile/prescription_mobile.png (${image.width}x${image.height})');
      }
    }
  });
}
