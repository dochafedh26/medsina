import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/clinical/bloc/clinical_bloc.dart';
import 'features/navigation/presentation/main_scaffold.dart';
import 'features/revision/bloc/revision_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedsinaApp());
}

class MedsinaApp extends StatelessWidget {
  const MedsinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc()..add(AppStartedEvent()),
        ),
        BlocProvider<ClinicalBloc>(
          create: (_) => ClinicalBloc(),
        ),
        BlocProvider<RevisionBloc>(
          create: (_) => RevisionBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Medsina — Plateforme Médicale Globale',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const MainScaffold(),
      ),
    );
  }
}
