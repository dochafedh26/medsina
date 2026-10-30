    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        return Card(
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: isNarrow ? 17 : 18,
                      backgroundColor: AppTheme.primaryTeal,
                      child: Text(
                        u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : 'M',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            u.email,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                            maxLines: isNarrow ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (u.isAdmin || u.isBanned || u.rejectedPaymentsCount > 0) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (u.isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ADMIN',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                    ),
                                  ),
                                if (u.isBanned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFDC2626)),
                                    ),
                                    child: const Text(
                                      'SUSPENDU (3 rejets) ⛔',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                    ),
                                  )
                                else if (u.rejectedPaymentsCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${u.rejectedPaymentsCount}/3 Rejets ⚠️',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (u.isBanned && u.banReason != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Motif : ${u.banReason}',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFFDC2626), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        tierLabel,
                        style: TextStyle(fontSize: isNarrow ? 9.5 : 10.5, fontWeight: FontWeight.w800, color: tierColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.school_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${u.medicalRole} • ${u.faculty}',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      u.expiresAt != null
                          ? 'Expire le : ${u.expiresAt!.day}/${u.expiresAt!.month}/${u.expiresAt!.year}'
                          : 'Durée illimitée',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (u.isBanned)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: const Icon(Icons.lock_open_rounded, size: 14),
                            label: const Text('Débannir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            onPressed: () => _confirmUnbanUser(context, u),
                          ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppTheme.primaryTeal,
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('Gérer Abonnement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _showUpgradeUserModal(context, u),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.forum_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Chasseur Promo Telegram & Assistant Réponses Facebook',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scanne en temps réel les questions d étudiants (résidanat, QCMs, cours) et poste des réponses ciblées avec les liens Medsina (sans MBset).',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 2,
                                ),
                                icon: _triggeringAgentId == 'telegram_promo_hunter'
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.radar_rounded, size: 18),
                                label: Text(
                                  _triggeringAgentId == 'telegram_promo_hunter' ? 'Recherche en cours...' : 'Lancer le Chasseur 🎯',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: _triggeringAgentId != null ? null : () => _showPromoHunterDialog(),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.forum_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Chasseur Promo Telegram & Assistant Réponses Facebook',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Scanne en temps réel les questions d étudiants (résidanat, QCMs, cours) et poste des réponses ciblées avec les liens Medsina (sans MBset).',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                              icon: _triggeringAgentId == 'telegram_promo_hunter'
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.radar_rounded, size: 18),
                              label: Text(
                                _triggeringAgentId == 'telegram_promo_hunter' ? 'Recherche en cours...' : 'Lancer le Chasseur 🎯',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: _triggeringAgentId != null ? null : () => _showPromoHunterDialog(),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
