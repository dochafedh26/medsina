import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/models/app_release_model.dart';
import '../../../core/services/ota_update_service.dart';
import '../../../core/theme/app_theme.dart';

class OtaUpdateDialog extends StatefulWidget {
  final AppReleaseModel release;
  final String currentVersion;
  final bool isMandatory;

  const OtaUpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
    this.isMandatory = false,
  });

  static Future<void> show(
    BuildContext context, {
    required AppReleaseModel release,
    required String currentVersion,
    bool isMandatory = false,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (_) => PopScope(
        canPop: !isMandatory,
        child: OtaUpdateDialog(
          release: release,
          currentVersion: currentVersion,
          isMandatory: isMandatory,
        ),
      ),
    );
  }

  @override
  State<OtaUpdateDialog> createState() => _OtaUpdateDialogState();
}

class _OtaUpdateDialogState extends State<OtaUpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';

  Future<void> _handleUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Connexion au serveur de mise à jour...';
    });

    final success = await OtaUpdateService.startUpdateProcess(
      widget.release,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _statusMessage = 'Téléchargement: ${(progress * 100).toStringAsFixed(0)}%';
          });
        }
      },
      onStatusChange: (status) {
        if (mounted) {
          setState(() => _statusMessage = status);
        }
      },
    );

    if (mounted) {
      setState(() => _isDownloading = false);
      if (!success && !widget.isMandatory) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'installer la mise à jour automatiquement.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rel = widget.release;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isMandatory
                        ? Colors.red.shade50
                        : AppTheme.primaryTeal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isMandatory
                        ? Icons.security_update_warning_rounded
                        : Icons.system_update_rounded,
                    color: widget.isMandatory ? Colors.red.shade700 : AppTheme.primaryTeal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isMandatory
                            ? 'Mise à jour requise 🚨'
                            : 'Nouvelle version disponible 🚀',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${widget.currentVersion}  ➔  v${rel.versionName}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Changelog / Release Notes
            Text(
              'Journal des modifications :',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: rel.releaseNotes.isNotEmpty
                      ? rel.releaseNotes
                      : 'Améliorations de stabilité, nouveaux résumés de cours et corrections de bugs.',
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF334155)),
                    h3: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Download Progress Bar
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Actions Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!widget.isMandatory && !_isDownloading) ...[
                  TextButton(
                    onPressed: () {
                      OtaUpdateService.dismissBuild(rel.buildNumber);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Plus tard',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isMandatory ? Colors.red.shade700 : AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(
                    _isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isDownloading
                        ? 'Téléchargement...'
                        : (widget.isMandatory ? 'Mettre à jour maintenant' : 'Installer la mise à jour'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _isDownloading ? null : _handleUpdate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
