import 'package:flutter/material.dart';
import '../../../core/theme/medsina_colors.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../services/focus_timer_service.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  final FocusTimerService _timer = FocusTimerService.instance;

  @override
  void initState() {
    super.initState();
    _timer.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Focus / Pomodoro'),
      ),
      body: AnimatedBuilder(
        animation: _timer,
        builder: (context, _) {
          final isFocus = _timer.phase == FocusPhase.focus;
          final phaseColor = isFocus ? mc.accent : mc.success;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Preset Selector
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: FocusPreset.values.map((p) {
                  return ChoiceChip(
                    label: Text(p.label),
                    selected: _timer.preset == p,
                    onSelected: (_) {
                      HapticFeedbackHelper.onTap();
                      _timer.selectPreset(p);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _timer.preset.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: mc.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 28),

              // Circular Timer
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 228,
                        height: 228,
                        child: CircularProgressIndicator(
                          value: _timer.progress,
                          strokeWidth: 12,
                          backgroundColor: mc.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: phaseColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isFocus ? 'CONCENTRATION' : 'PAUSE ACTIVE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: phaseColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _timer.formattedRemaining,
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: mc.textPrimary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedbackHelper.onTap();
                      _timer.reset();
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Reset'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedbackHelper.onMilestone();
                      if (_timer.isRunning) {
                        _timer.pause();
                      } else {
                        _timer.start();
                      }
                    },
                    icon: Icon(
                      _timer.isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(_timer.isRunning ? 'Pause' : 'Démarrer'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Passer à la phase suivante',
                    onPressed: () => _timer.skipPhase(),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Today's Stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: mc.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: mc.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${_timer.minutesToday} min',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: mc.accent,
                                ),
                          ),
                          Text(
                            'Focus aujourd\'hui',
                            style: TextStyle(
                              fontSize: 12,
                              color: mc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: mc.border),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${_timer.completedSessionsTotal}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: mc.success,
                                ),
                          ),
                          Text(
                            'Sessions terminées',
                            style: TextStyle(
                              fontSize: 12,
                              color: mc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
