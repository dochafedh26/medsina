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

    test('cleans HTML spans, details, styles and entities from QCM explanation screenshot', () {
      const input =
          '### Groupe musculaire médial de la cuisse (adducteurs)\n\n'
          'Le <span style="color:#0B7285; font-weight:bold;">groupe médial de la cuisse</span> '
          'correspond au groupe des **adducteurs** : il s\'insère globalement sur le '
          '<span style="color:#D9480F;">pubis / ischion</span> et se termine sur la '
          '<span style="color:#D9480F;">ligne âpre du fémur</span> ou la patte d\'oie. '
          'Il comprend <span style="color:#5C940D; font-weight:bold;">5 muscles</span> : '
          '**pectiné**, **long adducteur**, **court adducteur**.\n\n'
          '| Élément | <span style="color:#0B7285;">Groupe médial (adducteurs)</span> |\n'
          '|---|---|\n'
          '| Muscles clés | Pectiné, Long adducteur |';

      final output = MedicalTextFormatter.clean(input);

      expect(output.contains('<span'), isFalse);
      expect(output.contains('</span>'), isFalse);
      expect(output.contains('style='), isFalse);
      expect(output.contains('**groupe médial de la cuisse**'), isTrue);
      expect(output.contains('**5 muscles**'), isTrue);
      expect(output.contains('pubis / ischion'), isTrue);
      expect(output.contains('| Élément | Groupe médial (adducteurs) |'), isTrue);
    });
  });
}

