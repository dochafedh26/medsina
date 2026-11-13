import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../models/ai_quota_pack.dart';

class AiPackPurchaseModal extends StatefulWidget {
  const AiPackPurchaseModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiPackPurchaseModal(),
    );
  }

  @override
  State<AiPackPurchaseModal> createState() => _AiPackPurchaseModalState();
}

class _AiPackPurchaseModalState extends State<AiPackPurchaseModal> {
  AiQuotaPack _selectedPack = AiQuotaPack.availablePacks[1]; // Pack Pro (+150) by default
  String _paymentMethod = 'baridimob'; // 'baridimob' or 'ccp'

  static const String _baridimobRip = '007999990009171614 93';
  static const String _ccpAccount = '9171614';
  static const String _ccpKey = '19';
  static const String _accountHolder = 'CHIKH TOUHAMI HAFED';

  final TextEditingController _refController = TextEditingController();
  PlatformFile? _pickedFile;
  Uint8List? _receiptBytes;
  String? _receiptFileName;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFile = file;
        _receiptBytes = bytes;
        _receiptFileName = file.name;
      });
    }
  }

  Future<void> _submitPurchase() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour commander une recharge.')),
      );
      return;
    }

    final ref = _refController.text.trim();

    if (ref.isEmpty && _receiptBytes == null && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez joindre le reçu de paiement (PDF/Image) ou saisir la référence.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? uploadedUrl;

      // 1. Upload receipt to Supabase Storage if file attached
      if (_receiptBytes != null && _receiptFileName != null) {
        try {
          uploadedUrl = await SupabaseService.uploadPaymentReceipt(
            userId: user.id,
            fileName: _receiptFileName!,
            bytes: _receiptBytes!,
          );
        } catch (_) {}

        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          final mime = _receiptFileName!.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
          final b64 = base64Encode(_receiptBytes!);
          uploadedUrl = 'data:$mime;base64,$b64';
        }
      }

      // 2. Submit payment to Supabase
      final success = await SupabaseService.submitPaymentRequest(
        userId: user.id,
        userEmail: user.email,
        userName: user.fullName.isNotEmpty ? user.fullName : user.email,
        tier: _selectedPack.id,
        durationDays: 365,
        amount: _selectedPack.priceDzd,
        paymentMethod: _paymentMethod,
        receiptReference: ref.isNotEmpty ? ref : 'Reçu téléversé',
        receiptUrl: uploadedUrl,
        receiptFileName: _receiptFileName,
        paymentType: 'quota_topup',
        bonusCredits: _selectedPack.credits,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
                SizedBox(width: 10),
                Text('Demande Transmise', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Votre commande de recharge de +${_selectedPack.credits} requêtes IA a été envoyée à l\'administration avec votre reçu.\n\nVos requêtes bonus seront disponibles immédiatement après validation !',
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compris'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de soumettre la demande. Veuillez vérifier votre connexion.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recharge & Boosters IA',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Requêtes bonus permanentes (sans limite journalière)',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Pack Cards Selection
            ...AiQuotaPack.availablePacks.map((pack) {
              final isSelected = _selectedPack.id == pack.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedPack = pack),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryTeal.withValues(alpha: isDark ? 0.2 : 0.08)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryTeal : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? AppTheme.primaryTeal : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pack.name,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppTheme.primaryTeal : null,
                                  ),
                                ),
                                if (pack.discountBadge != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      pack.discountBadge!,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${pack.credits} requêtes • ${pack.description}',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${pack.priceDzd.toStringAsFixed(0)} DZD',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppTheme.primaryTeal : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Payment Instructions Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mode de Paiement :',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('BaridiMob', style: TextStyle(fontSize: 11)),
                            selected: _paymentMethod == 'baridimob',
                            onSelected: (val) => setState(() => _paymentMethod = 'baridimob'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('CCP', style: TextStyle(fontSize: 11)),
                            selected: _paymentMethod == 'ccp',
                            onSelected: (val) => setState(() => _paymentMethod = 'ccp'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_paymentMethod == 'baridimob') ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'RIP : $_baridimobRip',
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: _baridimobRip));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('RIP BaridiMob copié !')),
                            );
                          },
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'CCP : $_ccpAccount Clé $_ccpKey',
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: '$_ccpAccount $_ccpKey'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coordonnées CCP copiées !')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                    'Titulaire : $_accountHolder',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Receipt Attachment & Reference
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(
                      _receiptFileName != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                      size: 16,
                      color: _receiptFileName != null ? const Color(0xFF16A34A) : null,
                    ),
                    label: Text(
                      _receiptFileName ?? 'Joindre Reçu (Photo / PDF)',
                      style: const TextStyle(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _pickReceipt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _refController,
              decoration: InputDecoration(
                hintText: 'N° de transaction ou remarque (optionnel)',
                hintStyle: const TextStyle(fontSize: 11.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
            ),

            const SizedBox(height: 18),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmitting
                      ? 'Transmission en cours...'
                      : 'Commander ${_selectedPack.name} (${_selectedPack.priceDzd.toStringAsFixed(0)} DZD)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: _isSubmitting ? null : _submitPurchase,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
