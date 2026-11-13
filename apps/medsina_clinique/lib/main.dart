import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medsina_clinical_pkg/features/atlas/presentation/clinical_atlas_screen.dart';
import 'package:medsina_clinical_pkg/features/clinical/bloc/clinical_bloc.dart';
import 'package:medsina_clinical_pkg/features/clinical/presentation/clinical_screen.dart';
import 'package:medsina_clinical_pkg/features/prescription/presentation/prescription_analysis_screen.dart';
import 'package:medsina_core/core/constants/app_constants.dart';
import 'package:medsina_core/core/interfaces/feature_contracts.dart';
import 'package:medsina_core/core/widgets/medsina_app_shell.dart';
import 'package:medsina_practical_tools/features/practical_tools/presentation/practical_tools_screen.dart';

Future<void> main() async {
  await initializeMedsinaCore(
    appId: 'medsina_clinique',
    appDisplayName: 'Medsina Clinique',
    iconAsset: 'assets/app_icon.png',
  );

  final registry = MedsinaFeatureRegistry.instance;
  registry.registerRouteHandler('activity:clinicalProtocol', (context, data) async {
    final protocolId = data['protocolId'] as String? ?? 'cat_sca_st_plus';
    if (!context.mounted) return false;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClinicalScreen(initialTabIndex: 0, targetProtocolId: protocolId),
      ),
    );
    return true;
  });
  registry.registerRouteHandler('activity:prescriptionVidal', (context, _) async {
    if (!context.mounted) return false;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrescriptionAnalysisScreen()),
    );
    return true;
  });

  runApp(const MedsinaCliniqueApp());
}

class MedsinaCliniqueApp extends StatelessWidget {
  const MedsinaCliniqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MedsinaModularApp(
      title: 'Medsina Clinique',
      subtitle: 'Urgences CAT • Vidal Algérie • Mémento de Garde',
      extraBlocProviders: [
        BlocProvider<ClinicalBloc>(create: (_) => ClinicalBloc()),
      ],
      hasAppAccess: (user) =>
          user.tier == SubscriptionTier.free || user.tier.canAccessClinical(),
      tabsBuilder: (_, __) => const [
        AppTabDefinition(
          label: 'Urgences',
          title: 'Pratique Clinique & CAT',
          icon: Icons.medical_services_outlined,
          selectedIcon: Icons.medical_services_rounded,
          page: ClinicalScreen(),
        ),
        AppTabDefinition(
          label: 'Vidal DZ',
          title: 'Analyse d\'Ordonnance (Vidal)',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
          page: PrescriptionAnalysisScreen(),
        ),
        AppTabDefinition(
          label: 'Atlas',
          title: 'Atlas Clinique & Imagerie',
          icon: Icons.collections_bookmark_outlined,
          selectedIcon: Icons.collections_bookmark_rounded,
          page: ClinicalAtlasScreen(),
        ),
        AppTabDefinition(
          label: 'Mémento',
          title: 'Mémento de Garde & Labo',
          icon: Icons.handyman_outlined,
          selectedIcon: Icons.handyman_rounded,
          page: PracticalToolsScreen(),
        ),
      ],
    );
  }
}
