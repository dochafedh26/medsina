import 'package:flutter/material.dart';
import '../data/residency_repository.dart';
import '../services/offline_course_manager.dart';
import 'course_pdf_viewer_screen.dart';

class OfflineStorageScreen extends StatefulWidget {
  const OfflineStorageScreen({super.key});

  @override
  State<OfflineStorageScreen> createState() => _OfflineStorageScreenState();
}

class _OfflineStorageScreenState extends State<OfflineStorageScreen> {
  final OfflineCourseManager _manager = OfflineCourseManager.instance;
  bool _isLoading = true;
  int _totalBytes = 0;
  String _formattedTotalSize = '0 Ko';
  List<DownloadedCourseInfo> _downloadedCourses = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerUpdated);
    _loadData();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdated);
    super.dispose();
  }

  void _onManagerUpdated() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final modules = await ResidencyRepository.loadModulesAsync();
    final downloaded = await _manager.getDownloadedCoursesInfo(modules);
    final totalBytes = await _manager.getTotalOfflineBytes();
    final formatted = await _manager.getTotalOfflineFormatted();

    if (mounted) {
      setState(() {
        _downloadedCourses = downloaded;
        _totalBytes = totalBytes;
        _formattedTotalSize = formatted;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Vider tout le cache ?'),
          ],
        ),
        content: const Text(
          'Tous les cours téléchargés en local seront supprimés de cet appareil pour libérer de l\'espace.\n\nVous pourrez les retélécharger à tout moment lorsque vous serez connecté.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _manager.clearAllStorage();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le cache hors-ligne a été vidé avec succès.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteCourse(DownloadedCourseInfo info) async {
    await _manager.deleteCourse(info.course.id);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cours "${info.course.name}" supprimé du stockage local.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteModule(String moduleId, String moduleName) async {
    final toDelete = _downloadedCourses.where((d) => d.module.id == moduleId).toList();
    for (final item in toDelete) {
      await _manager.deleteCourse(item.course.id);
    }
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tous les cours de "$moduleName" ont été supprimés.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _downloadedCourses
        : _downloadedCourses
            .where((d) =>
                d.course.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                d.module.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // Group by Module
    final Map<String, List<DownloadedCourseInfo>> grouped = {};
    for (final item in filtered) {
      grouped.putIfAbsent(item.module.id, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stockage & Mode Hors-Ligne',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Gérez vos supports de cours disponibles sans connexion',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Storage Header Metric Card
                _buildStorageHeaderCard(),
                const SizedBox(height: 16),

                // 2. Wi-Fi Preferences
                _buildPreferencesCard(),
                const SizedBox(height: 20),

                // 3. Search and Content Section Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cours Disponibles Hors-Ligne (${_downloadedCourses.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (_downloadedCourses.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const Text('Tout vider', style: TextStyle(fontSize: 12)),
                        onPressed: _confirmClearAll,
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search field
                if (_downloadedCourses.isNotEmpty) ...[
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un cours ou module téléchargé...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Downloaded Courses List or Empty State
                if (_downloadedCourses.isEmpty)
                  _buildEmptyState()
                else if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Aucun cours téléchargé ne correspond à "$_searchQuery".',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...grouped.entries.map((entry) {
                    final moduleCourses = entry.value;
                    final mod = moduleCourses.first.module;
                    final totalModBytes =
                        moduleCourses.fold<int>(0, (acc, item) => acc + item.fileSizeBytes);
                    final formattedModSize = _manager.formatBytes(totalModBytes);

                    return Card(
                      elevation: 0.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.teal.shade100, width: 1),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade50,
                            child: const Icon(Icons.folder_special_rounded, color: Colors.teal),
                          ),
                          title: Text(
                            mod.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            '${moduleCourses.length} cours téléchargés • $formattedModSize',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Actions du module',
                            icon: const Icon(Icons.more_vert_rounded),
                            onSelected: (val) {
                              if (val == 'delete_module') {
                                _deleteModule(mod.id, mod.name);
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'delete_module',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 18, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Text('Supprimer ce module',
                                        style: TextStyle(
                                            color: Colors.red.shade700, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          children: moduleCourses.map((item) {
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade100),
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.offline_pin_rounded,
                                      color: Colors.green, size: 20),
                                ),
                                title: Text(
                                  item.course.name,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.formattedSize,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Disponible hors-ligne',
                                        style: TextStyle(fontSize: 11, color: Colors.green)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.menu_book_rounded, size: 14),
                                      label: const Text('Lire', style: TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CoursePdfViewerScreen(
                                              course: item.course,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      tooltip: 'Supprimer ce cours',
                                      icon: Icon(Icons.delete_outline_rounded,
                                          color: Colors.red.shade400, size: 20),
                                      onPressed: () => _deleteCourse(item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _buildStorageHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Espace Utilisé en Cache Local',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formattedTotalSize,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.offline_bolt_rounded, color: Colors.amberAccent, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      '${_downloadedCourses.length} cours',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              // Arbitrary reference of 1 GB max local quota for visual gauge
              value: (_totalBytes / (1024 * 1024 * 1024)).clamp(0.02, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accès 100% Hors-Ligne (Sans 4G ni Wi-Fi)',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                'Lecture ultra-rapide 0s',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        activeThumbColor: Colors.teal,
        secondary: const Icon(Icons.wifi_rounded, color: Colors.teal),
        title: const Text(
          'Télécharger uniquement en Wi-Fi',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: const Text(
          'Évite la consommation de votre forfait données mobiles (4G/5G)',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        value: _manager.isWifiOnly,
        onChanged: (val) async {
          await _manager.setWifiOnly(val);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_download_outlined, size: 64, color: Colors.teal.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucun cours téléchargé en local',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vous pouvez télécharger vos modules ou cours individuels depuis le catalogue pour pouvoir les réviser partout, même sans connexion internet (à l\'hôpital, dans les transports, etc.).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.school_rounded, size: 18),
              label: const Text('Explorer le Catalogue de Cours'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
