import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/clinical_case_simulation_model.dart';

class CaseSimulatorScreen extends StatefulWidget {
  const CaseSimulatorScreen({super.key});

  @override
  State<CaseSimulatorScreen> createState() => _CaseSimulatorScreenState();
}

class _CaseSimulatorScreenState extends State<CaseSimulatorScreen> {
  final List<ClinicalReasoningCase> _cases =
      ClinicalCaseSimulatorRepository.sampleCases;
  int _currentCaseIndex = 0;
  int? _selectedAnswerIndex;
  bool _showFeedback = false;

  ClinicalReasoningCase get _currentCase => _cases[_currentCaseIndex];

  bool get _isCorrectAnswer =>
      _selectedAnswerIndex == _currentCase.correctIndex;

  void _handleAnswer(int index) {
    if (_showFeedback) return;
    setState(() {
      _selectedAnswerIndex = index;
      _showFeedback = true;
    });
  }

  void _nextCase() {
    setState(() {
      final nextIndex = _currentCaseIndex + 1;
      if (nextIndex < _cases.length) {
        _currentCaseIndex = nextIndex;
      } else {
        _currentCaseIndex = 0;
      }
      _selectedAnswerIndex = null;
      _showFeedback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulateur de cas cliniques'),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medical_information_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cas ${_currentCaseIndex + 1}/${_cases.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentCase.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Présentation du patient',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  _currentCase.patientSummary,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Points clés',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentCase.keyFindings
                    .map(
                      (finding) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          finding,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              Text(
                'Étapes de raisonnement',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ..._currentCase.reasoningSteps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF111827)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppTheme.primaryTeal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ciblée',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentCase.question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._currentCase.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final isSelected = _selectedAnswerIndex == index;
                      final isCorrect = index == _currentCase.correctIndex;

                      Color backgroundColor = isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF8FAFC);
                      Color borderColor = Colors.grey.withValues(alpha: 0.18);
                      Color textColor = isDark
                          ? Colors.white
                          : const Color(0xFF0F172A);

                      if (_showFeedback) {
                        if (isCorrect) {
                          backgroundColor = const Color(0xFFDCFCE7);
                          borderColor = const Color(0xFF16A34A);
                          textColor = const Color(0xFF14532D);
                        } else if (isSelected && !isCorrect) {
                          backgroundColor = const Color(0xFFFEE2E2);
                          borderColor = const Color(0xFFDC2626);
                          textColor = const Color(0xFF7F1D1D);
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _handleAnswer(index),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _showFeedback && isCorrect
                                        ? const Color(0xFF16A34A)
                                        : (_showFeedback &&
                                                  isSelected &&
                                                  !isCorrect
                                              ? const Color(0xFFDC2626)
                                              : Colors.grey.withValues(
                                                  alpha: 0.15,
                                                )),
                                  ),
                                  child: Text(
                                    String.fromCharCode(65 + index),
                                    style: TextStyle(
                                      color:
                                          _showFeedback &&
                                              (isCorrect ||
                                                  (isSelected && !isCorrect))
                                          ? Colors.white
                                          : textColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_showFeedback) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isCorrectAnswer
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _isCorrectAnswer
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_amber_rounded,
                              color: _isCorrectAnswer
                                  ? const Color(0xFF166534)
                                  : const Color(0xFFB91C1C),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _currentCase.explanation,
                                style: TextStyle(
                                  color: _isCorrectAnswer
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF7F1D1D),
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showFeedback ? _nextCase : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: Text(
                    _currentCaseIndex == _cases.length - 1
                        ? 'Recommencer'
                        : 'Cas suivant',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
