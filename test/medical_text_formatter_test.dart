import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/core/utils/medical_text_formatter.dart';

void main() {
  group('MedicalTextFormatter', () {
    test('cleans raw LaTeX from user screenshot', () {
      const input = r'$\ge 1 \text{ mm}$ ($0,1 \text{ mV}$) dans au moins 2 dérivations contiguës (sauf V2-V3).';
      final output = MedicalTextFormatter.clean(input);
      expect(output, '≥ 1 mm (0,1 mV) dans au moins 2 dérivations contiguës (sauf V2-V3).');
    });

    test('cleans complex V2-V3 sentence from screenshot', () {
      const input = r'En V2-V3 : $\ge 2,5 \text{ mm}$ chez l\x27homme < 40 ans ; $\ge 2 \text{ mm}$ chez l\x27homme $\ge 40$ ans ; $\ge 1,5 \text{ mm}$ chez la femme.';
      final output = MedicalTextFormatter.clean(input);
      expect(output.contains(r'$'), isFalse);
      expect(output.contains(r'\ge'), isFalse);
      expect(output.contains(r'\text'), isFalse);
      expect(output.contains('≥ 2,5 mm'), isTrue);
    });

    test('cleans fractions and units', () {
      const input = r'$\frac{1}{2}$ dose de $500 \text{ mg}$ $\pm 50$ et $\le 10 \mu g$';
      final output = MedicalTextFormatter.clean(input);
      expect(output, '1/2 dose de 500 mg ± 50 et ≤ 10 µg');
    });
  });
}
