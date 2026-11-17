import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../data/residency_repository.dart';
import '../models/module_model.dart';
import '../models/qcm_duel_model.dart';
import '../models/qcm_model.dart';
import '../services/qcm_duel_service.dart';

class QcmDuelScreen extends StatefulWidget {
  const QcmDuelScreen({super.key});

  @override
  State<QcmDuelScreen> createState() => _QcmDuelScreenState();
}

class _QcmDuelScreenState extends State<QcmDuelScreen> {
  List<MedicalModuleModel> _modules = [];
  String? _selectedModuleId;
  int _questionCount = 5;
  DuelAiDifficulty _aiDifficulty = DuelAiDifficulty.resident;
  final _joinCodeCtrl = TextEditingController();
  List<QcmDuelMatch> _history = [];

  // Active Match State
  bool _inMatch = false;
  bool _matchFinished = false;
  bool _isJoiningRemote = false;
  QcmDuelMatch? _remoteTargetMatch;
  String _activeCode = '';
  List<QcmQuestion> _questions = [];
  int _qIndex = 0;
  int _myScore = 0;
  int _opponentScore = 0;
  int _elapsedSec = 0;
  int _questionSecondsLeft = 30;
  Timer? _timer;
  final Set<String> _selectedKeys = {};
  bool _answeredCurrent = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final mods = await ResidencyRepository.loadModulesAsync();
    final hist = await QcmDuelService.loadHistory();
    if (mounted) {
      setState(() {
        _modules = mods;
        _history = hist;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startNewDuel({bool vsAi = true, String? joinCode}) async {
    final code = joinCode?.trim().toUpperCase() ?? QcmDuelService.generateChallengeCode();
    QcmDuelMatch? remote;
    if (joinCode != null && joinCode.trim().isNotEmpty) {
      remote = await QcmDuelService.fetchMatchByCode(code);
    }

    final qs = await QcmDuelService.pickQuestionsForDuel(
      challengeCode: code,
      moduleId: _selectedModuleId,
      count: _questionCount,
    );

    if (!mounted) return;
    setState(() {
      _activeCode = code;
      _remoteTargetMatch = remote;
      _isJoiningRemote = joinCode != null && joinCode.isNotEmpty;
      _questions = qs;
      _qIndex = 0;
      _myScore = 0;
      _opponentScore = remote != null
          ? remote.creatorScore
          : (vsAi
              ? QcmDuelService.simulateAiOpponentScore(
                  totalQuestions: qs.length,
                  difficulty: _aiDifficulty,
                  seed: DateTime.now().millisecond,
                )
              : 0);
      _elapsedSec = 0;
      _questionSecondsLeft = 30;
      _selectedKeys.clear();
      _answeredCurrent = false;
      _inMatch = true;
      _matchFinished = false;
    });

    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_inMatch || _matchFinished) {
        t.cancel();
        return;
      }
      setState(() {
        _elapsedSec++;
        if (!_answeredCurrent) {
          if (_questionSecondsLeft > 0) {
            _questionSecondsLeft--;
          } else {
            _validateAnswer();
          }
        }
      });
    });
  }

  void _validateAnswer() {
    if (_answeredCurrent) return;
    final q = _questions[_qIndex];
    final isCorrect = _selectedKeys.length == q.correctAnswers.length &&
        _selectedKeys.every((k) => q.correctAnswers.contains(k));
    setState(() {
      _answeredCurrent = true;
      if (isCorrect) {
        _myScore += 100 + (_questionSecondsLeft * 2);
      }
    });
  }

  Future<void> _nextQuestion() async {
    if (_qIndex + 1 < _questions.length) {
      setState(() {
        _qIndex++;
        _selectedKeys.clear();
        _answeredCurrent = false;
        _questionSecondsLeft = 30;
      });
    } else {
      _timer?.cancel();
      final user = context.read<AuthBloc>().state.user;
      final myName = user?.fullName ?? 'Docteur';
      final moduleName = _selectedModuleId == null
          ? 'Multi-Modules'
          : (_modules.where((m) => m.id == _selectedModuleId).firstOrNull?.name ?? 'Module');

      final match = QcmDuelMatch(
        id: 'duel_${DateTime.now().millisecondsSinceEpoch}',
        challengeCode: _activeCode,
        moduleName: moduleName,
        creatorName: _remoteTargetMatch?.creatorName ?? myName,
        creatorScore: _remoteTargetMatch?.creatorScore ?? _myScore,
        creatorTimeSeconds: _remoteTargetMatch?.creatorTimeSeconds ?? _elapsedSec,
        opponentName: _isJoiningRemote ? myName : 'IA (${_aiDifficulty.name})',
        opponentScore: _isJoiningRemote ? _myScore : _opponentScore,
        opponentTimeSeconds: _elapsedSec,
        questionIds: _questions.map((e) => e.id).toList(),
        totalQuestions: _questions.length,
        status: 'completed',
        createdAt: DateTime.now(),
      );
      await QcmDuelService.saveDuelMatch(match, isJoining: _isJoiningRemote);
      final hist = await QcmDuelService.loadHistory();
      if (mounted) {
        setState(() {
          _matchFinished = true;
          _history = hist;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duel QCM 1v1 & Défis Rapides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Affrontez un confrère par code ou un Adversaire Calibré', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          if (_inMatch)
            TextButton(
              onPressed: () {
                _timer?.cancel();
                setState(() => _inMatch = false);
              },
              child: const Text('Quitter'),
            ),
        ],
      ),
      body: _inMatch ? (_matchFinished ? _buildPodium() : _buildArena()) : _buildLobby(),
    );
  }

  Widget _buildLobby() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.heroNavyDecoration(radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CRÉER UN DUEL CHRONOMÉTRÉ',
                style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lancez une série de 5 ou 10 QCMs (30s/question) et partagez votre code de défi avec un confrère.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _selectedModuleId,
                dropdownColor: AppTheme.clinicalNavy,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Module cible',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Tous les Modules (Aléatoire)')),
                  ..._modules.take(20).map((m) => DropdownMenuItem<String?>(value: m.id, child: Text(m.name))),
                ],
                onChanged: (v) => setState(() => _selectedModuleId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<DuelAiDifficulty>(
                initialValue: _aiDifficulty,
                dropdownColor: AppTheme.clinicalNavy,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Niveau Adversaire Sparring',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                ),
                items: DuelAiDifficulty.values
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                    .toList(),
                onChanged: (v) => setState(() => _aiDifficulty = v ?? DuelAiDifficulty.resident),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('5 QCMs'),
                    selected: _questionCount == 5,
                    onSelected: (_) => setState(() => _questionCount = 5),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('10 QCMs'),
                    selected: _questionCount == 10,
                    onSelected: (_) => setState(() => _questionCount = 10),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Lancer le Duel', style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                    onPressed: () => _startNewDuel(vsAi: true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.bentoCardDecoration(context, radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rejoindre le Défi d\'un Confrère', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _joinCodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Code défi (ex: DZ-4829)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (_joinCodeCtrl.text.trim().isNotEmpty) {
                        _startNewDuel(vsAi: false, joinCode: _joinCodeCtrl.text.trim());
                      }
                    },
                    child: const Text('Rejoindre'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('HISTORIQUE DES DUELS RÉCENTS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal)),
          const SizedBox(height: 8),
          ..._history.take(8).map((m) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.sports_mma_rounded, color: AppTheme.primaryTeal),
                  title: Text('${m.challengeCode} • ${m.moduleName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  subtitle: Text('${m.creatorName} (${m.creatorScore} pts) vs ${m.opponentName ?? "En attente"} (${m.opponentScore ?? 0} pts)', style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copier le code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: m.challengeCode));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code ${m.challengeCode} copié')));
                    },
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildArena() {
    final q = _questions[_qIndex];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Chip(label: Text('Question ${_qIndex + 1}/${_questions.length}', style: const TextStyle(fontWeight: FontWeight.w800))),
            Chip(
              avatar: const Icon(Icons.timer_rounded, size: 16, color: Color(0xFFDC2626)),
              label: Text('${_questionSecondsLeft}s', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
            ),
            Chip(label: Text('Score : $_myScore', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryTeal))),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.bentoCardDecoration(context, radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.courseName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal)),
              const SizedBox(height: 6),
              Text(q.questionText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...q.options.map((opt) {
          final isSel = _selectedKeys.contains(opt.key);
          final isRight = q.correctAnswers.contains(opt.key);
          Color? bg;
          if (_answeredCurrent) {
            if (isRight) {
              bg = const Color(0xFF10B981).withValues(alpha: 0.16);
            } else if (isSel) {
              bg = const Color(0xFFEF4444).withValues(alpha: 0.16);
            }
          } else if (isSel) {
            bg = AppTheme.primaryTeal.withValues(alpha: 0.14);
          }

          return Card(
            color: bg,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: isSel ? AppTheme.primaryTeal : Colors.grey.withValues(alpha: 0.2),
                child: Text(opt.key, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isSel ? Colors.white : null)),
              ),
              title: Text(opt.text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              onTap: _answeredCurrent
                  ? null
                  : () {
                      setState(() {
                        if (q.type == QuestionType.qcs) {
                          _selectedKeys
                            ..clear()
                            ..add(opt.key);
                        } else {
                          if (isSel) {
                            _selectedKeys.remove(opt.key);
                          } else {
                            _selectedKeys.add(opt.key);
                          }
                        }
                      });
                    },
            ),
          );
        }),
        const SizedBox(height: 12),
        if (!_answeredCurrent)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _selectedKeys.isEmpty ? null : _validateAnswer,
            child: const Text('Valider ma réponse', style: TextStyle(fontWeight: FontWeight.w900)),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.bentoCardDecoration(context, radius: 14),
            child: Text('💡 ${q.explanation}', style: const TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.clinicalNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _nextQuestion,
            child: Text(_qIndex + 1 < _questions.length ? 'Question Suivante ➔' : 'Voir le Podium 🏆', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ],
    );
  }

  Widget _buildPodium() {
    final won = _myScore >= _opponentScore;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.heroNavyDecoration(radius: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(won ? Icons.emoji_events_rounded : Icons.military_tech_rounded, color: Colors.amber, size: 56),
              const SizedBox(height: 12),
              Text(
                won ? 'VICTOIRE EN DUEL !' : 'BEAU COMBAT !',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('Code du défi à partager : $_activeCode', style: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('VOUS', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text('$_myScore pts', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const Text('VS', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900)),
                  Column(
                    children: [
                      Text(_isJoiningRemote ? (_remoteTargetMatch?.creatorName ?? 'Confrère') : 'ADVERSAIRE', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      Text('$_opponentScore pts', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, color: Colors.white),
                      label: const Text('Copier Code', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _activeCode));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code $_activeCode copié !')));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                      onPressed: () => setState(() => _inMatch = false),
                      child: const Text('Retour Lobby'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
