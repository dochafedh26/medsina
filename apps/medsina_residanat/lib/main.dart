import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medsina_core/core/constants/app_constants.dart';
import 'package:medsina_core/core/interfaces/feature_contracts.dart';
import 'package:medsina_core/core/widgets/medsina_app_shell.dart';
import 'package:medsina_practical_tools/features/practical_tools/presentation/practical_tools_screen.dart';
import 'package:medsina_residanat_pkg/features/revision/presentation/course_mindmap_screen.dart';
import 'package:medsina_residanat_pkg/features/revision/presentation/course_summary_screen.dart';
import 'package:medsina_residanat_pkg/features/revision/presentation/revision_catalog_screen.dart';
import 'package:medsina_residanat_pkg/features/revision/presentation/samedis_pedagogiques_screen.dart';
import 'package:medsina_residanat_pkg/features/revision/presentation/study_planner_screen.dart';
import 'package:medsina_residanat_pkg/features/national_exam/presentation/national_exams_list_screen.dart';
import 'package:medsina_study_engine/features/revision/bloc/revision_bloc.dart';
import 'package:medsina_study_engine/features/revision/models/module_model.dart';
import 'package:medsina_study_engine/study_engine_bootstrap.dart';

Future<void> main() async {
  await initializeMedsinaCore(
    appId: 'medsina_residanat',
    appDisplayName: 'Medsina Résidanat',
    iconAsset: 'assets/app_icon.png',
  );
  registerStudyEngineContracts();

  final registry = MedsinaFeatureRegistry.instance;
  registry.registerRouteHandler('course_summary', (context, args) async {
    final course = args['course'] as CourseModel?;
    if (course == null || !context.mounted) return false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseSummaryScreen(
          course: course,
          moduleName: args['moduleName'] as String?,
        ),
      ),
    );
    return true;
  });
  registry.registerRouteHandler('course_mindmap', (context, args) async {
    final course = args['course'] as CourseModel?;
    if (course == null || !context.mounted) return false;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseMindmapScreen(course: course)),
    );
    return true;
  });
  registry.registerRouteHandler('samedis_pedagogiques', (context, args) async {
    if (!context.mounted) return false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SamedisPedagogiquesScreen(
          initialSearchQuery: args['initialSearchQuery'] as String? ?? '',
        ),
      ),
    );
    return true;
  });

  runApp(const MedsinaResidanatApp());
}

class MedsinaResidanatApp extends StatelessWidget {
  const MedsinaResidanatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MedsinaModularApp(
      title: 'Medsina Résidanat',
      subtitle: 'Préparation Concours Résidanat • 47 Modules & 19k+ QCMs',
      extraBlocProviders: [
        BlocProvider<RevisionBloc>(create: (_) => RevisionBloc()),
      ],
      hasAppAccess: (user) =>
          user.tier == SubscriptionTier.free || user.tier.canAccessResident(),
      tabsBuilder: (_, __) => const [
        AppTabDefinition(
          label: 'Modules',
          title: 'Catalogue Résidanat 2027',
          icon: Icons.school_outlined,
          selectedIcon: Icons.school_rounded,
          page: RevisionCatalogScreen(),
        ),
        AppTabDefinition(
          label: 'Planner',
          title: 'Study Planner Matriciel',
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          page: StudyPlannerScreen(),
        ),
        AppTabDefinition(
          label: 'Concours',
          title: 'Examens Nationaux',
          icon: Icons.emoji_events_outlined,
          selectedIcon: Icons.emoji_events_rounded,
          page: NationalExamsListScreen(),
        ),
        AppTabDefinition(
          label: 'Mémento',
          title: 'Normes & Calculateurs',
          icon: Icons.handyman_outlined,
          selectedIcon: Icons.handyman_rounded,
          page: PracticalToolsScreen(),
        ),
      ],
    );
  }
}
