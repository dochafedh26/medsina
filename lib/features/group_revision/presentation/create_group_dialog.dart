import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../models/study_group_model.dart';
import '../services/group_revision_service.dart';

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  static Future<StudyGroupModel?> show(BuildContext context) {
    return showDialog<StudyGroupModel>(
      context: context,
      builder: (_) => const CreateGroupDialog(),
    );
  }

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _specialtyController = TextEditingController();
  bool _isLoading = false;

  final List<String> _colors = [
    '#00897B', // Teal
    '#1E88E5', // Blue
    '#7E57C2', // Deep Purple
    '#D81B60', // Pink
    '#FB8C00', // Amber/Orange
    '#43A047', // Green
  ];
  String _selectedColor = '#00897B';

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final group = await GroupRevisionService.instance.createGroup(
        userId: user.id,
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        targetSpecialty: _specialtyController.text.trim().isEmpty ? null : _specialtyController.text.trim(),
        avatarColor: _selectedColor,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (group != null) {
          Navigator.of(context).pop(group);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la création du groupe.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppTheme.primaryTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _parseColor(_selectedColor).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.group_add_rounded, color: _parseColor(_selectedColor), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Créer un Groupe de Révision',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nom du groupe *',
                    hintText: 'ex: Team Cardio Blida 2027',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Nom requis (min 3 caractères)' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specialtyController,
                  decoration: InputDecoration(
                    labelText: 'Spécialité / Faculté (optionnel)',
                    hintText: 'ex: Résidanat 2027, Faculté de Blida...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.school_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Objectifs ou description (optionnel)',
                    hintText: 'ex: Révision collective des annales et entraînements réguliers...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.description_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Couleur du groupe :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: _colors.map((hex) {
                    final color = _parseColor(hex);
                    final isSel = _selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = hex),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSel ? Border.all(color: Colors.black, width: 2.5) : null,
                        ),
                        child: isSel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _parseColor(_selectedColor),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Créer le Groupe'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

