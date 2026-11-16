import 'package:flutter/material.dart';
import '../services/focus_mode_service.dart';
import '../theme/app_theme.dart';

/// Reusable banner displayed at the top of filtered screens when Focus Mode is active.
class FocusModeActiveBanner extends StatelessWidget {
  final VoidCallback? onClear;
  final List<String> availableModuleNames;

  const FocusModeActiveBanner({
    super.key,
    this.onClear,
    this.availableModuleNames = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FocusModeService.instance,
      builder: (context, _) {
        final service = FocusModeService.instance;
        if (!service.isEnabled) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final typeLabel =
            service.isSpecialtyMode ? 'Spécialité' : 'Rotation Module';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF0F766E).withValues(alpha: 0.35),
                      const Color(0xFF1E293B),
                    ]
                  : [
                      const Color(0xFFCCFBF1),
                      const Color(0xFFF0FDFA),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primaryTeal.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.center_focus_strong_rounded,
                  size: 18,
                  color: AppTheme.primaryTeal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Focus • $typeLabel',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF5EEAD4)
                            : const Color(0xFF0F766E),
                      ),
                    ),
                    Text(
                      service.focusLabel ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.clinicalNavy,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => FocusModeSheet.show(
                  context,
                  availableModuleNames: availableModuleNames,
                ),
                child: const Text(
                  'Changer',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  await service.disableFocus();
                  onClear?.call();
                },
                child: const Text(
                  'Tout afficher',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Modal selector for Specialty Focus (Doctors/Interns) or Module Rotation Focus (Students).
class FocusModeSheet extends StatefulWidget {
  final List<String> availableModuleNames;

  const FocusModeSheet({
    super.key,
    this.availableModuleNames = const [],
  });

  static Future<void> show(
    BuildContext context, {
    List<String> availableModuleNames = const [],
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FocusModeSheet(
        availableModuleNames: availableModuleNames,
      ),
    );
  }

  @override
  State<FocusModeSheet> createState() => _FocusModeSheetState();
}

class _FocusModeSheetState extends State<FocusModeSheet> {
  late String _selectedType;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedType = FocusModeService.instance.focusType;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = FocusModeService.instance;
    final maxH = MediaQuery.of(context).size.height * 0.84;

    final presetLabelsLower =
        FocusModeService.presets.map((p) => p.label.toLowerCase()).toSet();

    final extraModules = widget.availableModuleNames
        .where((m) =>
            m.trim().isNotEmpty &&
            !presetLabelsLower.contains(m.trim().toLowerCase()))
        .toSet()
        .toList()
      ..sort();

    final q = _query.trim().toLowerCase();
    final filteredPresets = FocusModeService.presets.where((p) {
      if (q.isEmpty) return true;
      return p.label.toLowerCase().contains(q) ||
          p.subtitle.toLowerCase().contains(q);
    }).toList();

    final filteredExtra = extraModules.where((m) {
      if (q.isEmpty) return true;
      return m.toLowerCase().contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.center_focus_strong_rounded,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mode Focus Médical',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Concentrez Cours, QCMs, Externat & CATs sur votre service ou rotation.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Profile type toggle: Specialty (Doctor/Intern) vs Module Rotation (Student)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeChip(
                      label: 'Service / Spécialité',
                      subtitle: 'Médecins & Internes',
                      icon: Icons.medical_services_rounded,
                      selected: _selectedType == 'specialty',
                      onTap: () => setState(() => _selectedType = 'specialty'),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypeChip(
                      label: 'Rotation Module',
                      subtitle: 'Étudiants en stage',
                      icon: Icons.school_rounded,
                      selected: _selectedType == 'module',
                      onTap: () => setState(() => _selectedType = 'module'),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            if (service.isEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: BorderSide(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.layers_clear_rounded, size: 18),
                    label: Text(
                      'Désactiver le Focus (${service.focusLabel}) • Tout afficher',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      await service.disableFocus();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Rechercher une spécialité ou un module...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  ...filteredPresets.map((preset) {
                    final isCurrent = service.isEnabled &&
                        service.focusLabel?.toLowerCase() ==
                            preset.label.toLowerCase();
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isCurrent
                          ? AppTheme.primaryTeal.withValues(alpha: 0.14)
                          : (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isCurrent
                              ? AppTheme.primaryTeal
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryTeal.withValues(alpha: 0.14),
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            size: 18,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                        title: Text(
                          preset.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          preset.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: isCurrent
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.primaryTeal,
                              )
                            : const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14),
                        onTap: () async {
                          await service.enableFocus(
                            label: preset.label,
                            type: _selectedType,
                            keywords: preset.keywords,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    );
                  }),
                  if (filteredExtra.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Autres modules du programme',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...filteredExtra.map((modName) {
                      final isCurrent = service.isEnabled &&
                          service.focusLabel?.toLowerCase() ==
                              modName.toLowerCase();
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: const Icon(Icons.menu_book_rounded, size: 18),
                        title: Text(
                          modName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: isCurrent
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.primaryTeal,
                              )
                            : null,
                        onTap: () async {
                          await service.enableFocus(
                            label: modName,
                            type: _selectedType,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryTeal.withValues(alpha: 0.14)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primaryTeal
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppTheme.primaryTeal : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? AppTheme.primaryTeal : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
