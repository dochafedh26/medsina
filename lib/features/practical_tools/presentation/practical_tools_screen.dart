import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/lab_value_model.dart';

class PracticalToolsScreen extends StatefulWidget {
  const PracticalToolsScreen({super.key});

  @override
  State<PracticalToolsScreen> createState() => _PracticalToolsScreenState();
}

class _PracticalToolsScreenState extends State<PracticalToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _labSearch = '';
  String _mementoSearch = '';
  bool _isLoading = false;

  List<LabValue> _allLabs = PracticalToolsRepository.getLabValues();
  List<OnCallMemento> _allMementos = PracticalToolsRepository.getOnCallMementos();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isLoading = true);
    }
    try {
      final labs = await PracticalToolsRepository.getLabValuesAsync(refresh: refresh);
      final mementos = await PracticalToolsRepository.getOnCallMementosAsync(refresh: refresh);
      if (mounted) {
        setState(() {
          _allLabs = labs;
          _allMementos = mementos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryTeal,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.primaryTeal,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: [
              Tab(
                icon: const Icon(Icons.biotech_rounded),
                text: 'Normes Biologiques (${_allLabs.length})',
              ),
              Tab(
                icon: const Icon(Icons.nightlight_round),
                text: 'Mémento de Garde (${_allMementos.length})',
              ),
            ],
          ),
        ),
        if (_isLoading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            color: AppTheme.primaryTeal,
            minHeight: 2,
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLabValuesTab(),
              _buildOnCallTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabValuesTab() {
    final filtered = _allLabs.where((lab) {
      final q = _labSearch.trim().toLowerCase();
      if (q.isEmpty) return true;
      return lab.name.toLowerCase().contains(q) ||
          lab.category.toLowerCase().contains(q) ||
          lab.highInterpretation.toLowerCase().contains(q) ||
          lab.lowInterpretation.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      color: AppTheme.primaryTeal,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un examen biologique (ex: potassium, sodium, CRP)...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _labSearch.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _labSearch = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _labSearch = val),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun résultat pour « $_labSearch »',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final lab = filtered[index];
                      return _LabValueCard(lab: lab);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallTab() {
    final filtered = _allMementos.where((m) {
      final q = _mementoSearch.trim().toLowerCase();
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) ||
          m.category.toLowerCase().contains(q) ||
          m.points.any((p) => p.toLowerCase().contains(q)) ||
          (m.scientificReferences?.toLowerCase().contains(q) ?? false);
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      color: AppTheme.primaryTeal,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un réflexe de garde (ex: hypo, coma, brûlure, antidote)...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _mementoSearch.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _mementoSearch = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _mementoSearch = val),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune fiche trouvée pour « $_mementoSearch »',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final m = filtered[index];
                      return _OnCallMementoCard(memento: m);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OnCallMementoCard extends StatefulWidget {
  final OnCallMemento memento;
  const _OnCallMementoCard({required this.memento});

  @override
  State<_OnCallMementoCard> createState() => _OnCallMementoCardState();
}

class _OnCallMementoCardState extends State<_OnCallMementoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.memento;
    final color = m.color;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(m.icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        if (m.category.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            m.category,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${m.points.length} réflexes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...m.points.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                          Expanded(
                            child: Text(p, style: const TextStyle(fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    )),
                if (m.scientificReferences != null && m.scientificReferences!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Divider(),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m.scientificReferences!,
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LabValueCard extends StatefulWidget {
  final LabValue lab;
  const _LabValueCard({required this.lab});

  @override
  State<_LabValueCard> createState() => _LabValueCardState();
}

class _LabValueCardState extends State<_LabValueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lab.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lab.category,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${lab.normalRange} ${lab.unit}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: AppTheme.primaryDarkTeal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // High interpretation
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🔺 Si Élevé : ${lab.highInterpretation}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), height: 1.35),
                ),
              ),

              // Low interpretation
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🔻 Si Bas : ${lab.lowInterpretation}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.35),
                ),
              ),

              if (lab.clinicalNotes.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...lab.clinicalNotes.map((n) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('💡 $n', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
