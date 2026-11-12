import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/theme/medsina_colors.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../models/flashcard_fsrs_model.dart';

class AudioRevisionTrack {
  final String id;
  final String title;
  final String category;
  final String spokenText;

  const AudioRevisionTrack({
    required this.id,
    required this.title,
    required this.category,
    required this.spokenText,
  });
}

class AudioRevisionScreen extends StatefulWidget {
  const AudioRevisionScreen({super.key});

  @override
  State<AudioRevisionScreen> createState() => _AudioRevisionScreenState();
}

class _AudioRevisionScreenState extends State<AudioRevisionScreen> {
  final FlutterTts _tts = FlutterTts();
  List<AudioRevisionTrack> _tracks = [];
  bool _loading = true;
  bool _isPlaying = false;
  int _currentIndex = 0;
  double _speechRate = 1.0;

  static const List<double> _speedOptions = [0.8, 1.0, 1.25, 1.5];

  static const List<AudioRevisionTrack> _defaultPearls = [
    AudioRevisionTrack(
      id: 'pearl_sca',
      title: 'SCA ST+ : Délai d\'angioplastie',
      category: 'Perle Clinique • Cardiologie',
      spokenText:
          'Perle clinique de cardiologie. Devant un syndrome coronarien aigu avec sus-décalage du segment ST, l\'angioplastie primaire est le traitement de référence si le délai entre le diagnostic ECG et le passage du guide est inférieur à 120 minutes.',
    ),
    AudioRevisionTrack(
      id: 'pearl_bav',
      title: 'BAV complet et syncope d\'Adams-Stokes',
      category: 'Perle Clinique • Cardiologie',
      spokenText:
          'Perle clinique. Un bloc auriculo-ventriculaire du troisième degré se caractérise par une dissociation complète entre les ondes P et les complexes QRS, imposant l\'implantation d\'un stimulateur cardiaque après élimination d\'une cause réversible.',
    ),
    AudioRevisionTrack(
      id: 'pearl_meningite',
      title: 'Purpura fulminans : réflexe immédiat',
      category: 'Perle Clinique • Infectieux',
      spokenText:
          'Perle d\'infectiologie. Tout purpura fébrile comportant au moins un élément nécrotique ou ecchymotique de diamètre supérieur ou égal à 3 millimètres impose une antibiothérapie probabiliste par ceftriaxone en urgence absolue avant la ponction lombaire.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadTracks();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(_mapRate(_speechRate));
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        if (_currentIndex + 1 < _tracks.length) {
          setState(() => _currentIndex++);
          _speakCurrent();
        } else {
          setState(() => _isPlaying = false);
        }
      });
    } catch (_) {}
  }

  /// Maps user-facing 0.8x..1.5x label to flutter_tts platform rate (~0.4..0.75).
  double _mapRate(double multiplier) => (multiplier * 0.5).clamp(0.25, 1.0);

  Future<void> _loadTracks() async {
    setState(() => _loading = true);
    await FlashcardFsrsService.instance.ensureInitialized();
    final cards = FlashcardFsrsService.instance.cards;
    final fsrsTracks = cards.take(20).map((c) {
      return AudioRevisionTrack(
        id: c.id,
        title: c.courseName.isNotEmpty ? c.courseName : 'Flashcard FSRS',
        category: 'Flashcard FSRS v4.5',
        spokenText: 'Question : ${c.front}. Réponse : ${c.back}',
      );
    }).toList();

    if (!mounted) return;
    setState(() {
      _tracks = [..._defaultPearls, ...fsrsTracks];
      _loading = false;
    });
  }

  Future<void> _speakCurrent() async {
    if (_tracks.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setSpeechRate(_mapRate(_speechRate));
      setState(() => _isPlaying = true);
      await _tts.speak(_tracks[_currentIndex].spokenText);
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _pause() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Révision Audio Mains Libres'),
      ),
      body: _loading
          ? const SkeletonCardList(itemCount: 4, itemHeight: 88)
          : _tracks.isEmpty
              ? const EmptyStateView(
                  icon: Icons.headphones_rounded,
                  title: 'Aucune piste audio disponible',
                  subtitle: 'Ajoutez des flashcards FSRS pour les écouter.',
                )
              : Column(
                  children: [
                    // Player Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: mc.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: mc.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _tracks[_currentIndex].category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: mc.accent,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _tracks[_currentIndex].title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: mc.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 32,
                                onPressed: _currentIndex > 0
                                    ? () {
                                        setState(() => _currentIndex--);
                                        if (_isPlaying) _speakCurrent();
                                      }
                                    : null,
                                icon: const Icon(Icons.skip_previous_rounded),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed:
                                    _isPlaying ? _pause : _speakCurrent,
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                                label: Text(_isPlaying ? 'Pause' : 'Écouter'),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                iconSize: 32,
                                onPressed: _currentIndex + 1 < _tracks.length
                                    ? () {
                                        setState(() => _currentIndex++);
                                        if (_isPlaying) _speakCurrent();
                                      }
                                    : null,
                                icon: const Icon(Icons.skip_next_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: _speedOptions.map((r) {
                              return ChoiceChip(
                                label: Text('${r}x'),
                                selected: _speechRate == r,
                                onSelected: (_) {
                                  setState(() => _speechRate = r);
                                  if (_isPlaying) _speakCurrent();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: _tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final t = _tracks[index];
                          final active = index == _currentIndex;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: active ? mc.accent : mc.border,
                              ),
                            ),
                            tileColor: active ? mc.accentSoft : mc.surface,
                            leading: Icon(
                              active && _isPlaying
                                  ? Icons.graphic_eq_rounded
                                  : Icons.headphones_rounded,
                              color: active ? mc.accent : mc.textSecondary,
                            ),
                            title: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: mc.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              t.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: mc.textSecondary,
                              ),
                            ),
                            onTap: () {
                              setState(() => _currentIndex = index);
                              _speakCurrent();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
