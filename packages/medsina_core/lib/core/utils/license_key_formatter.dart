import 'dart:math';
import 'package:flutter/services.dart';

/// Professional Windows/Office style License Key Formatter & Generator
/// Standard Format: MSN27-XXXXX-XXXXX-XXXXX-XXXXX (5 blocks of 5 alphanumeric chars)
class LicenseKeyFormatter {
  // Safe alphanumeric character set without visually ambiguous chars (no 0/O, 1/I)
  static const String _charset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static final Random _random = Random.secure();

  /// Generate a professional activation key
  /// Example: MSN27-8K3FD-92XPQ-LM71Z-T5Y9B
  static String generateKey({String prefix = 'MSN27'}) {
    final segments = <String>[prefix];
    for (int i = 0; i < 4; i++) {
      final buffer = StringBuffer();
      for (int j = 0; j < 5; j++) {
        buffer.write(_charset[_random.nextInt(_charset.length)]);
      }
      segments.add(buffer.toString());
    }
    return segments.join('-');
  }

  /// Format raw input string into XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
  static String format(String raw) {
    final rawUpper = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final limited = rawUpper.length > 25 ? rawUpper.substring(0, 25) : rawUpper;

    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i > 0 && i % 5 == 0) {
        buffer.write('-');
      }
      buffer.write(limited[i]);
    }
    return buffer.toString();
  }

  /// Check if key matches professional pattern (5 segments separated by hyphens)
  static bool isValidStructure(String key) {
    final clean = key.trim().toUpperCase();
    final parts = clean.split('-');
    if (parts.length != 5) return false;
    for (final p in parts) {
      if (p.length != 5) return false;
    }
    return true;
  }
}

/// Formats text into uppercase and automatically inserts hyphens:
/// XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
class LicenseKeyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formattedText = LicenseKeyFormatter.format(newValue.text);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

