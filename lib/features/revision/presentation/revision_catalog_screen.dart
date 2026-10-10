import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../bloc/revision_state.dart';
import '../models/module_model.dart';
import 'qcm_study_screen.dart';

class RevisionCatalogScreen extends StatefulWidget {
  const RevisionCatalogScreen({super.key});

  @override
  State<RevisionCatalogScreen> createState() => _RevisionCatalogScreenState();
}

class _RevisionCatalogScreenState extends State<RevisionCatalogScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  @override
  void initState() {
    super.initState();
    context.read<RevisionBloc>().add(LoadModulesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RevisionBloc, RevisionState>(
      builder: (context, state) {
        if (state.status == RevisionStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredModules = state.modules.where((m) {
          final matchesCat = _selectedCategory == 'Tous' || m.category == _selectedCategory;
          final matchesSearch = _searchQuery.isEmpty ||
              m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              m.courses.any((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()));
          return matchesCat && matchesSearch;
        }).toList();

        return Column(
          children: [
            // Search & Category Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher un module ou un cours (ex: HTA, Asthme, AVC)...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildFilterChip('Tous'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Médecine'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Chirurgie'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Biologie'),
                      const Spacer(),
                      Text(
                        '${state.modules.length} modules disponibles',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Modules List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredModules.length,
                itemBuilder: (context, index) {
                  final module = filteredModules[index];
                  return _ModuleCard(module: module);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String cat) {
    final isSelected = _selectedCategory == cat;
    return ChoiceChip(
      label: Text(cat),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryTeal : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedCategory = cat),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final MedicalModuleModel module;
  const _ModuleCard({required this.module});

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded, color: AppTheme.primaryTeal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${m.totalCourses} cours officiels • ${m.totalQuestions} questions révisables',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),

            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...m.courses.map((course) => _buildCourseRow(context, course)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourseRow(BuildContext context, CourseModel course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurfaceElevated
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${course.questionsCount} QCMs',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    if (course.hasPdf)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PDF Officiel', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
            label: const Text('PDF', style: TextStyle(fontSize: 11)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Support PDF pour "${course.name}" prêt pour consultation.')),
              );
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Réviser', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              context.read<RevisionBloc>().add(OpenCourseQuestionsEvent(course));
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
