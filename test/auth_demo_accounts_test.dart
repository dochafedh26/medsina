import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/auth/models/demo_accounts.dart';

void main() {
  group('DemoAccounts findByEmail Tests', () {
    test('Real doctor emails containing demo substrings must NOT match demo accounts', () {
      // The bug that caused doc.hafedh14@gmail.com to become Dr. Hafedh Admin
      expect(DemoAccounts.findByEmail('doc.hafedh14@gmail.com'), isNull);
      expect(DemoAccounts.findByEmail('hafedh.belkacem@gmail.com'), isNull);
      expect(DemoAccounts.findByEmail('dr.amine.resident@gmail.com'), isNull);
      expect(DemoAccounts.findByEmail('sarah.amrani@hotmail.com'), isNull);
      expect(DemoAccounts.findByEmail('karim.med@yahoo.fr'), isNull);
      expect(DemoAccounts.findByEmail('allaccess@gmail.com'), isNull);
      expect(DemoAccounts.findByEmail('vip.doctor@medsina.dz'), isNull);
    });

    test('Exact demo accounts still match correctly', () {
      expect(DemoAccounts.findByEmail('doc.hafedh26@medsina.com'), isNotNull);
      expect(DemoAccounts.findByEmail('doc.hafedh26@medsina.com')!.user.fullName, 'Dr. Hafedh (Blida 2027)');
      expect(DemoAccounts.findByEmail('resident.elite@medsina.com'), isNotNull);
      expect(DemoAccounts.findByEmail('clinique.pro@medsina.com'), isNotNull);
      expect(DemoAccounts.findByEmail('decouverte.free@medsina.com'), isNotNull);
      expect(DemoAccounts.findByEmail('expire.demo@medsina.com'), isNotNull);
    });
  });
}
