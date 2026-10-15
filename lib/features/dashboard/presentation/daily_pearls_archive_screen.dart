import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';

class DailyPearlsArchiveScreen extends StatefulWidget {
  const DailyPearlsArchiveScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DailyPearlsArchiveScreen()),
    );
  }

  @override
  State<DailyPearlsArchiveScreen> createState() => _DailyPearlsArchiveScreenState();
}

class _DailyPearlsArchiveScreenState extends State<DailyPearlsArchiveScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allPearls = [];
  bool _isLoading = true;
  String _selectedSpecialty = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadPearls();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPearls() async {
    setState(() => _isLoading = true);
    final pearls = await SupabaseService.fetchAllDailyPearls();
    if (mounted) {
      setState(() {
        _allPearls = pearls;
        _isLoading = false;
      });
    }
  }

  List<String> _getSpecialties() {
    final set = <String>{'Tous'};
    for (final p in _allPearls) {
      final mod = p['module_name'] as String?;
      if (mod != null && mod.isNotEmpty) {
        set.add(mod);
      }
    }
    return set.toList();
  }

  List<Map<String, dynamic>> _getFilteredPearls() {
    final query = _searchController.text.trim().toLowerCase();
    return _allPearls.where((p) {
      final module = (p['module_name'] ?? '').toString().toLowerCase();
      final title = (p['title'] ?? '').toString().toLowerCase();
      final course = (p['course_name'] ?? '').toString().toLowerCase();
      final text = (p['pearl_text'] ?? '').toString().toLowerCase();
      final vital = (p['vital_rule'] ?? '').toString().toLowerCase();
      final trap = (p['exam_trap'] ?? '').toString().toLowerCase();

      // Specialty filter
      if (_selectedSpecialty != 'Tous') {
        if (!module.contains(_selectedSpecialty.toLowerCase())) {
          return false;
        }
      }

      // Query filter
      if (query.isNotEmpty) {
        final matches = module.contains(query) ||
            title.contains(query) ||
            course.contains(query) ||
            text.contains(query) ||
            vital.contains(query) ||
            trap.contains(query);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  void _copyPearl(Map<String, dynamic> pearl) {
    final title = pearl['title'] ?? 'Perle Clinique';
    final course = pearl['course_name'] ?? '';
    final text = pearl['pearl_text'] ?? '';
    final vital = pearl['vital_rule'] ?? '';
    final trap = pearl['exam_trap'] ?? '';
    final source = pearl['scientific_sources'] ?? '';

    final buffer = StringBuffer();
    buffer.writeln('💡 $title');
    if (course.isNotEmpty) buffer.writeln('📖 Cours : $course');
    buffer.writeln('\n$text');
    if (vital.isNotEmpty) buffer.writeln('\n⚡ Règle Vitale UMC :\n$vital');
    if (trap.isNotEmpty) buffer.writeln('\n🎯 Piège Concours Résidanat :\n$trap');
    if (source.isNotEmpty) buffer.writeln('\n📚 Sources : $source');
    buffer.writeln('\n— Medsina Platform 2027');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Perle copiée dans le presse-papiers !', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthBloc>().state.user;
    final tier = user?.tier ?? SubscriptionTier.free;
    final isSubscriptionActive = user?.isSubscriptionActive ?? false;
    final hasResidentAccess =
        (tier == SubscriptionTier.residentElite || tier == SubscriptionTier.allAccess) && isSubscriptionActive;

    final filtered = _getFilteredPearls();
    final specialties = _getSpecialties();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perles Cliniques & Pièges du Concours',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              'Archive & Banque de perles de révision quotidienne',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPearls,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Search and Filter Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                  ),
                  child: Column(
                    children: [
                      // Search TextField
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher une perle, cours, piège QCM, kaliémie, ECG...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primaryTeal),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Specialty Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: specialties.map((spec) {
                            final isSelected = _selectedSpecialty == spec;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(spec),
                                selected: isSelected,
                                onSelected: (val) {
                                  setState(() => _selectedSpecialty = spec);
                                },
                                labelStyle: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                selectedColor: AppTheme.primaryTeal,
                                backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Results Counter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} perle${filtered.length > 1 ? 's' : ''} trouvée${filtered.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium_rounded, size: 14, color: AppTheme.accentCyan),
                            SizedBox(width: 4),
                            Text(
                              'Banque Officielle Medsina',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Pearls List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Aucune perle clinique ne correspond à votre recherche.',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final pearl = filtered[index];
                            return _PearlCard(
                              pearl: pearl,
                              index: index + 1,
                              total: filtered.length,
                              hasResidentAccess: hasResidentAccess,
                              onCopy: () => _copyPearl(pearl),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _PearlCard extends StatelessWidget {
  final Map<String, dynamic> pearl;
  final int index;
  final int total;
  final bool hasResidentAccess;
  final VoidCallback onCopy;

  const _PearlCard({
    required this.pearl,
    required this.index,
    required this.total,
    required this.hasResidentAccess,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = pearl['title'] ?? 'Perle Clinique';
    final moduleName = pearl['module_name'] as String?;
    final courseName = pearl['course_name'] as String?;
    final pearlText = pearl['pearl_text'] ?? '';
    final vitalRule = pearl['vital_rule'] as String?;
    final examTrap = pearl['exam_trap'] as String?;
    final sources = pearl['scientific_sources'] as String?;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Module Badge + Number + Copy Button
            Row(
              children: [
                if (moduleName != null && moduleName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      moduleName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$index/$total',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copier la perle',
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                  onPressed: onCopy,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.accentCyan),
            ),

            // Course Name
            if (courseName != null && courseName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      courseName,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),

            // Pearl Text
            Text(
              pearlText,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),

            // Vital Rule Box
            if (vitalRule != null && vitalRule.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚡ RÈGLE VITALE DE PRATIQUE UMC :',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            vitalRule,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB45309),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Exam Trap Box
            if (examTrap != null && examTrap.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (hasResidentAccess)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.school_rounded, size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🎯 PIÈGE DE CONCOURS RÉSIDANAT :',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB91C1C),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              examTrap,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB91C1C),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF9333EA).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, size: 18, color: Color(0xFF9333EA)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎯 Piège Concours Résidanat Masqué',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF9333EA)),
                            ),
                            Text(
                              'Réservé aux abonnés Pass Résident Élite & All-Access',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF9333EA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Débloquer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
            ],

            // Scientific Sources Footer
            if (sources != null && sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bookmark_added_rounded, size: 13, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Source : $sources',
                      style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
