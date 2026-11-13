import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medsina_core/core/constants/app_constants.dart';
import 'package:medsina_core/core/interfaces/feature_contracts.dart';
import 'package:medsina_core/core/widgets/medsina_app_shell.dart';
import 'package:medsina_externat_pkg/features/externat/presentation/externat_catalog_screen.dart';
import 'package:medsina_practical_tools/features/practical_tools/presentation/practical_tools_screen.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_bloc.dart';
import 'package:medsina_study_engine/study_engine_bootstrap.dart';

Future<void> main() async {
  await initializeMedsinaCore(
    appId: 'medsina_externat',
    appDisplayName: 'Medsina Étudiant',
    iconAsset: 'assets/app_icon.png',
  );
  registerStudyEngineContracts();

  runApp(const MedsinaExternatApp());
}

class MedsinaExternatApp extends StatelessWidget {
  const MedsinaExternatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MedsinaModularApp(
      title: 'Medsina Étudiant',
      subtitle: 'Cursus Médical & Externat (1ère - 6ème Année)',
      extraBlocProviders: [
        BlocProvider<RevisionBloc>(create: (_) => RevisionBloc()),
      ],
      hasAppAccess: (user) =>
          user.tier == SubscriptionTier.free || user.tier.canAccessEtudiant(),
      tabsBuilder: (_, __) => const [
        AppTabDefinition(
          label: 'Externat',
          title: 'Cursus Médical & EMDs',
          icon: Icons.school_outlined,
          selectedIcon: Icons.school_rounded,
          page: ExternatCatalogScreen(),
        ),
        AppTabDefinition(
          label: 'Outils',
          title: 'Normes Biologiques & Calculateurs',
          icon: Icons.calculate_outlined,
          selectedIcon: Icons.calculate_rounded,
          page: PracticalToolsScreen(),
        ),
      ],
    );
  }
}
