import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/models/user_model.dart';
import '../models/app_review_model.dart';

class FeedbackReviewsScreen extends StatefulWidget {
  final bool openFormInitially;

  const FeedbackReviewsScreen({
    super.key,
    this.openFormInitially = false,
  });

  @override
  State<FeedbackReviewsScreen> createState() => _FeedbackReviewsScreenState();
}

class _FeedbackReviewsScreenState extends State<FeedbackReviewsScreen> {
  static const String _helpfulVotedKey = 'medsina_helpful_voted_review_ids';

  List<AppReviewModel> _reviews = [];
  Set<String> _votedReviewIds = {};
  bool _isLoading = true;
  ReviewCategory? _selectedCategoryFilter; // null = Tous
  String _sortBy = 'featured'; // 'featured', 'recent', 'helpful'

  @override
  void initState() {
    super.initState();
    _loadReviewsAndVotes();
  }

  Future<void> _loadReviewsAndVotes() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthBloc>().state.user;
    final isAdmin = user?.isAdmin == true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final voted = prefs.getStringList(_helpfulVotedKey) ?? [];
      _votedReviewIds = voted.toSet();
    } catch (_) {}

    final loaded = await SupabaseService.fetchAppReviews(
      includeUnapprovedForAdmin: isAdmin,
    );

    if (!mounted) return;
    setState(() {
      _reviews = loaded;
      _isLoading = false;
    });

    if (widget.openFormInitially && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openReviewFormModal(existingReview: _findCurrentUserReview(user));
        }
      });
    }
  }

  AppReviewModel? _findCurrentUserReview(UserModel? user) {
    if (user == null || user.id.isEmpty) return null;
    for (final r in _reviews) {
      if (r.userId == user.id) return r;
    }
    return null;
  }

  List<AppReviewModel> get _filteredReviews {
    var list = _reviews.where((r) {
      if (_selectedCategoryFilter != null && r.category != _selectedCategoryFilter) {
        return false;
      }
      return true;
    }).toList();

    if (_sortBy == 'recent') {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortBy == 'helpful') {
      list.sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
    } else {
      // 'featured'
      list.sort((a, b) {
        if (a.isFeatured != b.isFeatured) {
          return a.isFeatured ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    }
    return list;
  }

  Future<void> _handleVoteHelpful(AppReviewModel review) async {
    if (_votedReviewIds.contains(review.id)) return;

    setState(() {
      _votedReviewIds.add(review.id);
      _reviews = _reviews.map((r) {
        if (r.id == review.id) {
          return r.copyWith(helpfulCount: r.helpfulCount + 1);
        }
        return r;
      }).toList();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_helpfulVotedKey, _votedReviewIds.toList());
    } catch (_) {}

    await SupabaseService.markReviewHelpful(review.id, review.helpfulCount);
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    return '$d/$m/$y';
  }

  SubscriptionTier _parseTier(String tierStr) {
    switch (tierStr) {
      case 'etudiant':
        return SubscriptionTier.etudiant;
      case 'clinical_pro':
        return SubscriptionTier.clinicalPro;
      case 'resident_elite':
        return SubscriptionTier.residentElite;
      case 'all_access':
        return SubscriptionTier.allAccess;
      default:
        return SubscriptionTier.free;
    }
  }

  String _ratingSentimentLabel(int stars) {
    switch (stars) {
      case 1:
        return '1★ — Insuffisant, j\'ai rencontré un problème ⚠️';
      case 2:
        return '2★ — Moyen, quelques points à améliorer 🔧';
      case 3:
        return '3★ — Satisfaisant, bonne base 👌';
      case 4:
        return '4★ — Très bien ! Très utile au quotidien 👍';
      case 5:
      default:
        return '5★ — Exceptionnel ! Outil médical indispensable 🌟';
    }
  }

  void _openReviewFormModal({AppReviewModel? existingReview}) {
    final user = context.read<AuthBloc>().state.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int selectedRating = existingReview?.rating ?? 5;
    ReviewCategory selectedCategory = existingReview?.category ?? ReviewCategory.general;
    final Set<String> selectedTags = {...(existingReview?.quickTags ?? ['Explications QCM claires'])};
    final titleController = TextEditingController(text: existingReview?.title ?? '');
    final commentController = TextEditingController(text: existingReview?.comment ?? '');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9,
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                existingReview != null
                                    ? 'Modifier votre avis sur Medsina'
                                    : 'Votre avis compte pour la communauté',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Partagez votre expérience avec vos confrères et étudiants',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Star Rating Selector
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Quelle note attribuez-vous à Medsina ?',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starValue = index + 1;
                              final isSelected = starValue <= selectedRating;
                              return GestureDetector(
                                onTap: () => setModalState(() => selectedRating = starValue),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: AnimatedScale(
                                    scale: starValue == selectedRating ? 1.18 : 1.0,
                                    duration: const Duration(milliseconds: 150),
                                    child: Icon(
                                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 38,
                                      color: isSelected ? Colors.amber : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _ratingSentimentLabel(selectedRating),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selectedRating >= 4
                                  ? AppTheme.primaryTeal
                                  : (selectedRating == 3 ? Colors.amber.shade800 : Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Category Selector
                    const Text(
                      'Catégorie concernée',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ReviewCategory.values.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.icon,
                                size: 15,
                                color: isSelected ? Colors.white : cat.color,
                              ),
                              const SizedBox(width: 6),
                              Text(cat.shortLabel),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: cat.color,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          onSelected: (_) => setModalState(() => selectedCategory = cat),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Quick Appreciation Tags
                    const Text(
                      'Points forts appréciés (optionnel)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ReviewCategory.availableQuickTags.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.18),
                          checkmarkColor: AppTheme.primaryTeal,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryTeal
                                : (isDark ? Colors.white70 : Colors.grey.shade700),
                          ),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Title field
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Titre de votre avis (optionnel)',
                        hintText: 'Ex: Indispensable pour le Résidanat et les gardes !',
                        prefixIcon: const Icon(Icons.title_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Comment field
                    TextField(
                      controller: commentController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Votre commentaire détaillé *',
                        hintText:
                            'Partagez ce qui vous plaît le plus sur Medsina ou vos suggestions d\'amélioration...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          existingReview != null ? 'Mettre à jour mon avis' : 'Publier mon avis ⭐',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final comment = commentController.text.trim();
                                if (comment.length < 5) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Color(0xFFDC2626),
                                      content: Text('Veuillez rédiger un commentaire d\'au moins quelques mots.'),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final saved = await SupabaseService.submitAppReview(
                                  existingReviewId: existingReview?.id,
                                  userId: user?.id,
                                  userName: user?.fullName ?? 'Médecin Medsina',
                                  userRole: user?.medicalRole ?? 'Candidat Résidanat',
                                  userFaculty: user?.faculty ?? 'Faculté de Médecine de Blida',
                                  userTier: user?.tier.name == 'clinicalPro'
                                      ? 'clinical_pro'
                                      : (user?.tier.name == 'residentElite'
                                          ? 'resident_elite'
                                          : (user?.tier.name == 'allAccess'
                                              ? 'all_access'
                                              : (user?.tier.name ?? 'free'))),
                                  rating: selectedRating,
                                  category: selectedCategory,
                                  quickTags: selectedTags.toList(),
                                  title: titleController.text.trim(),
                                  comment: comment,
                                  appVersion: AppConstants.appVersion,
                                );

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);

                                if (saved != null && mounted) {
                                  setState(() {
                                    final idx = _reviews.indexWhere((r) => r.id == saved.id);
                                    if (idx >= 0) {
                                      _reviews[idx] = saved;
                                    } else {
                                      _reviews.insert(0, saved);
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Color(0xFF16A34A),
                                      content: Text(
                                        'Merci pour votre avis ! Il a été publié sur le mur de la communauté ⭐',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAdminReplyDialog(AppReviewModel review) {
    final replyController = TextEditingController(text: review.adminReply ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppTheme.primaryTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Répondre à ${review.userName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: replyController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Réponse officielle de l\'équipe Medsina',
            hintText: 'Rédigez votre réponse publique...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final text = replyController.text.trim();
              Navigator.pop(ctx);
              final ok = await SupabaseService.adminUpdateReview(
                reviewId: review.id,
                adminReply: text,
              );
              if (ok && mounted) {
                setState(() {
                  _reviews = _reviews.map((r) {
                    if (r.id == review.id) {
                      return r.copyWith(
                        adminReply: text.isEmpty ? null : text,
                        adminRepliedAt: DateTime.now(),
                      );
                    }
                    return r;
                  }).toList();
                });
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 520;
    final user = context.watch<AuthBloc>().state.user;
    final isAdmin = user?.isAdmin == true;
    final myReview = _findCurrentUserReview(user);
    final stats = ReviewStatsSummary.fromReviews(_reviews);
    final filtered = _filteredReviews;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0.5,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isCompact ? 'Avis & Notes Medsina' : 'Avis & Retours de la Communauté Medsina',
                    style: TextStyle(
                      fontSize: isCompact ? 14.5 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              'Évaluations vérifiées des médecins, internes et étudiants',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser les avis',
            onPressed: _loadReviewsAndVotes,
          ),
          if (!isCompact)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.rate_review_rounded, size: 16),
                label: Text(
                  myReview != null ? 'Modifier mon avis' : 'Donner mon avis ⭐',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openReviewFormModal(existingReview: myReview),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.rate_review_rounded, size: 18),
              label: Text(
                myReview != null ? 'Modifier mon avis' : 'Donner mon avis ⭐',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              onPressed: () => _openReviewFormModal(existingReview: myReview),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReviewsAndVotes,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // 1. Summary & Rating Distribution Card
                  _buildRatingSummaryBanner(stats, myReview, isDark, isCompact),
                  const SizedBox(height: 18),

                  // 2. Category Filters & Sort Row
                  _buildFilterAndSortSection(isDark),
                  const SizedBox(height: 14),

                  // 3. Reviews List
                  if (filtered.isEmpty)
                    _buildEmptyState(isDark)
                  else
                    ...filtered.map(
                      (review) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildReviewCard(
                          review: review,
                          isDark: isDark,
                          isAdmin: isAdmin,
                          isMyReview: user != null && review.userId == user.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildRatingSummaryBanner(
    ReviewStatsSummary stats,
    AppReviewModel? myReview,
    bool isDark,
    bool isCompact,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryTeal.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left column: Big average score
              Column(
                children: [
                  Text(
                    stats.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (idx) {
                      return const Icon(Icons.star_rounded, color: Colors.amber, size: 18);
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats.totalReviews} avis vérifiés',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),

              // Right column: 5★ to 1★ progress bars
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((star) {
                    final ratio = stats.ratioForStar(star);
                    final count = stats.starCounts[star] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$star ★',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 7,
                                backgroundColor:
                                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  star >= 4
                                      ? Colors.amber
                                      : (star == 3 ? Colors.orange : Colors.redAccent),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, size: 18, color: AppTheme.primaryTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  myReview != null
                      ? 'Vous avez attribué ${myReview.rating} ★ à Medsina. Merci pour votre contribution !'
                      : 'Vous utilisez Medsina pour vos révisions ou en garde ? Partagez votre note !',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryTeal,
                  side: const BorderSide(color: AppTheme.primaryTeal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: Icon(
                  myReview != null ? Icons.edit_rounded : Icons.add_comment_rounded,
                  size: 15,
                ),
                label: Text(
                  myReview != null ? 'Modifier' : 'Noter ★',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openReviewFormModal(existingReview: myReview),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSortSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Tous les avis'),
                  selected: _selectedCategoryFilter == null,
                  selectedColor: AppTheme.primaryTeal,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _selectedCategoryFilter == null
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                  onSelected: (_) => setState(() => _selectedCategoryFilter = null),
                ),
              ),
              ...ReviewCategory.values.map((cat) {
                final isSelected = _selectedCategoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat.icon,
                          size: 14,
                          color: isSelected ? Colors.white : cat.color,
                        ),
                        const SizedBox(width: 5),
                        Text(cat.shortLabel),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: cat.color,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                    onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_filteredReviews.length} avis affichés',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: const [
                  DropdownMenuItem(value: 'featured', child: Text('Trier : Mis en avant 📌')),
                  DropdownMenuItem(value: 'recent', child: Text('Trier : Plus récents 🕒')),
                  DropdownMenuItem(value: 'helpful', child: Text('Trier : Plus utiles 👍')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Aucun avis dans cette catégorie pour le moment',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Soyez le premier à partager votre retour d\'expérience sur cette fonctionnalité !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required AppReviewModel review,
    required bool isDark,
    required bool isAdmin,
    required bool isMyReview,
  }) {
    final tier = _parseTier(review.userTier);
    final hasVoted = _votedReviewIds.contains(review.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: review.isFeatured
              ? Colors.amber.withValues(alpha: 0.55)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: review.isFeatured ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Author info + stars + date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: review.category.color.withValues(alpha: 0.15),
                child: Text(
                  review.userName.isNotEmpty ? review.userName[0].toUpperCase() : 'M',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: review.category.color,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          review.userName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tier.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tier.badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: tier.color,
                            ),
                          ),
                        ),
                        if (review.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '📌 Mis en avant',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        if (!review.isApproved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Masqué',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${review.userRole} • ${review.userFaculty}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (idx) {
                      return Icon(
                        idx < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(review.createdAt),
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Category + Quick Tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: review.category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(review.category.icon, size: 12, color: review.category.color),
                    const SizedBox(width: 4),
                    Text(
                      review.category.shortLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: review.category.color,
                      ),
                    ),
                  ],
                ),
              ),
              ...review.quickTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✓ $tag',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),

          // Optional Title
          if (review.title != null && review.title!.trim().isNotEmpty) ...[
            Text(
              review.title!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
          ],

          // Review Comment
          Text(
            review.comment,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
            ),
          ),

          // Official Admin Reply Box
          if (review.adminReply != null && review.adminReply!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_rounded, size: 15, color: AppTheme.primaryTeal),
                      SizedBox(width: 6),
                      Text(
                        'Réponse officielle de l\'équipe Medsina',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.adminReply!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Bottom Actions Row: Helpful vote + Edit/Admin controls
          Row(
            children: [
              InkWell(
                onTap: hasVoted ? null : () => _handleVoteHelpful(review),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: hasVoted
                        ? AppTheme.primaryTeal.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasVoted
                          ? AppTheme.primaryTeal
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasVoted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                        size: 14,
                        color: hasVoted ? AppTheme.primaryTeal : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Utile (${review.helpfulCount})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: hasVoted
                              ? AppTheme.primaryTeal
                              : (isDark ? Colors.white70 : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (isMyReview)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryTeal,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                  onPressed: () => _openReviewFormModal(existingReview: review),
                ),
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xFFDC2626)),
                  tooltip: 'Modération Admin',
                  onSelected: (action) async {
                    if (action == 'reply') {
                      _openAdminReplyDialog(review);
                    } else if (action == 'feature') {
                      final nextVal = !review.isFeatured;
                      final ok = await SupabaseService.adminUpdateReview(
                        reviewId: review.id,
                        isFeatured: nextVal,
                      );
                      if (ok && mounted) {
                        setState(() {
                          _reviews = _reviews.map((r) {
                            return r.id == review.id ? r.copyWith(isFeatured: nextVal) : r;
                          }).toList();
                        });
                      }
                    } else if (action == 'approve') {
                      final nextVal = !review.isApproved;
                      final ok = await SupabaseService.adminUpdateReview(
                        reviewId: review.id,
                        isApproved: nextVal,
                      );
                      if (ok && mounted) {
                        setState(() {
                          _reviews = _reviews.map((r) {
                            return r.id == review.id ? r.copyWith(isApproved: nextVal) : r;
                          }).toList();
                        });
                      }
                    } else if (action == 'delete') {
                      final ok = await SupabaseService.adminDeleteReview(review.id);
                      if (ok && mounted) {
                        setState(() {
                          _reviews.removeWhere((r) => r.id == review.id);
                        });
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'reply',
                      child: Row(
                        children: [
                          Icon(Icons.reply_rounded, size: 18, color: AppTheme.primaryTeal),
                          SizedBox(width: 10),
                          Text('Répondre officiellement', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'feature',
                      child: Row(
                        children: [
                          const Icon(Icons.push_pin_rounded, size: 18, color: Colors.amber),
                          const SizedBox(width: 10),
                          Text(
                            review.isFeatured ? 'Retirer la mise en avant' : 'Mettre en avant 📌',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'approve',
                      child: Row(
                        children: [
                          Icon(
                            review.isApproved ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            review.isApproved ? 'Masquer l\'avis' : 'Approuver l\'avis',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Supprimer l\'avis', style: TextStyle(fontSize: 13, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
