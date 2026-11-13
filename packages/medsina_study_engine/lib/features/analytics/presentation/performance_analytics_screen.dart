import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medsina_core/core/theme/medsina_colors.dart';
import 'package:medsina_core/core/widgets/empty_state_view.dart';
import 'package:medsina_core/core/widgets/skeleton_loader.dart';
import '../../revision/bloc/revision_bloc.dart';
import '../../revision/bloc/revision_event.dart';
import '../../revision/models/module_model.dart';
import '../../revision/presentation/qcm_study_screen.dart';
import '../services/performance_analytics_service.dart';

class PerformanceAnalyticsScreen extends StatefulWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  State<PerformanceAnalyticsScreen> createState() =>
      _PerformanceAnalyticsScreenState();
}

class _PerformanceAnalyticsScreenState
    extends State<PerformanceAnalyticsScreen> {
  PerformanceAnalyticsSnapshot? _snapshot;
  bool _loading = true;
  bool _show90Days = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snap = await PerformanceAnalyticsService.instance.loadLiveSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytique & Progression'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const SkeletonCardList(itemCount: 4, itemHeight: 150)
          : _snapshot == null
              ? EmptyStateView(
                  icon: Icons.bar_chart_rounded,
                  title: 'Aucune donnée disponible',
                  subtitle:
                      'Résolvez quelques QCMs pour débloquer vos graphiques de progression.',
                  actionLabel: 'Actualiser',
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildKpiRow(context, mc, _snapshot!),
                      const SizedBox(height: 16),
                      _buildRadarSection(context, mc, _snapshot!),
                      const SizedBox(height: 16),
                      _buildEvolutionSection(context, mc, _snapshot!),
                      const SizedBox(height: 16),
                      _buildHeatmapSection(context, mc, _snapshot!),
                      const SizedBox(height: 16),
                      _buildWeaknessesSection(context, mc, _snapshot!),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKpiRow(
    BuildContext context,
    MedsinaColors mc,
    PerformanceAnalyticsSnapshot snap,
  ) {
    Widget kpi(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: mc.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: mc.textPrimary,
                    ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: mc.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        kpi('QCM résolus', '${snap.totalSolved}', Icons.quiz_rounded, mc.accent),
        const SizedBox(width: 10),
        kpi(
          'Précision',
          '${snap.globalAccuracy.toStringAsFixed(1)}%',
          Icons.gps_fixed_rounded,
          mc.success,
        ),
        const SizedBox(width: 10),
        kpi(
          'Série',
          '${snap.currentStreak} j',
          Icons.local_fire_department_rounded,
          mc.warning,
        ),
      ],
    );
  }

  Widget _buildRadarSection(
    BuildContext context,
    MedsinaColors mc,
    PerformanceAnalyticsSnapshot snap,
  ) {
    final topDisc = snap.disciplines.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Radar de Compétences par Discipline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: mc.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          if (topDisc.length < 3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Entraînez-vous dans au moins 3 disciplines pour afficher le radar de compétences.',
                style: TextStyle(color: mc.textSecondary),
              ),
            )
          else
            SizedBox(
              height: 240,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  tickCount: 4,
                  ticksTextStyle:
                      TextStyle(fontSize: 10, color: mc.textSecondary),
                  gridBorderData: BorderSide(color: mc.border, width: 1),
                  tickBorderData: BorderSide(color: mc.border, width: 0.7),
                  radarBorderData: BorderSide(color: mc.border, width: 1),
                  titleTextStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mc.textPrimary,
                  ),
                  getTitle: (index, angle) => RadarChartTitle(
                    text: topDisc[index].name.length > 12
                        ? '${topDisc[index].name.substring(0, 11)}…'
                        : topDisc[index].name,
                  ),
                  dataSets: [
                    RadarDataSet(
                      fillColor: mc.accent.withValues(alpha: 0.25),
                      borderColor: mc.accent,
                      borderWidth: 2,
                      entryRadius: 3,
                      dataEntries: topDisc
                          .map((d) => RadarEntry(value: d.accuracyPercent))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEvolutionSection(
    BuildContext context,
    MedsinaColors mc,
    PerformanceAnalyticsSnapshot snap,
  ) {
    final series = _show90Days ? snap.evolution90d : snap.evolution30d;
    final spots = <FlSpot>[];
    for (int i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i].accuracyPercent));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Courbe d\'Évolution (${_show90Days ? '90j' : '30j'})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: mc.textPrimary,
                      ),
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('30j')),
                  ButtonSegment(value: true, label: Text('90j')),
                ],
                selected: {_show90Days},
                onSelectionChanged: (s) =>
                    setState(() => _show90Days = s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: mc.border, strokeWidth: 0.8),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style: TextStyle(fontSize: 10, color: mc.textSecondary),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: mc.accent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: mc.accent.withValues(alpha: 0.16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapSection(
    BuildContext context,
    MedsinaColors mc,
    PerformanceAnalyticsSnapshot snap,
  ) {
    final entries = snap.activityHeatmap53w.entries.toList();
    final weeks = <List<MapEntry<String, int>>>[];
    for (int i = 0; i < entries.length; i += 7) {
      weeks.add(entries.sublist(i, math.min(i + 7, entries.length)));
    }

    Color cellColor(int level) {
      if (level <= 0) return mc.surfaceElevated;
      if (level <= 2) return mc.accent.withValues(alpha: 0.45);
      return mc.accent;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Heatmap d\'Activité Annuelle (53 semaines)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: mc.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weeks.map((week) {
                return Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Column(
                    children: week.map((day) {
                      return Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: cellColor(day.value),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeaknessesSection(
    BuildContext context,
    MedsinaColors mc,
    PerformanceAnalyticsSnapshot snap,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 des Lacunes à Cibler',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: mc.textPrimary,
                ),
          ),
          const SizedBox(height: 10),
          if (snap.topWeaknesses.isEmpty)
            Text(
              'Aucune lacune détectée pour le moment. Continuez vos séries de QCM !',
              style: TextStyle(color: mc.textSecondary),
            )
          else
            ...snap.topWeaknesses.map((w) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.courseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: mc.textPrimary,
                            ),
                          ),
                          Text(
                            '${w.wrongCount} erreurs • Précision ${w.accuracyPercent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: mc.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final course = CourseModel(
                          id: w.courseId,
                          moduleId: w.moduleId,
                          name: w.courseName,
                          questionsCount: w.attemptsCount,
                          hasPdf: false,
                        );
                        context
                            .read<RevisionBloc>()
                            .add(OpenCourseQuestionsEvent(course));
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const QcmStudyScreen(),
                          ),
                        );
                      },
                      child: const Text('Cibler'),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
