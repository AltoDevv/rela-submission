import 'package:flutter/material.dart';

import '../shared/models.dart';
import '../shared/theme.dart';
import 'ui.dart';

/// Akses umum memilih pasangan bila lebih dari satu. Beranda mengirim [current] agar langsung merekap kartu aktif.
/// Tetap lewat startStory sehingga persetujuan kunjungan pertama tidak dilewati.
Future<void> startVisitEntry(
  BuildContext context, {
  required List<Elder> elders,
  Elder? current,
  Future<void> Function(Elder)? onStart,
}) async {
  if (elders.isEmpty) return;
  var chosen = current == null
      ? null
      : elders.where((e) => e.id == current.id).firstOrNull;
  if (current != null && chosen == null) return;
  chosen ??= elders.length == 1
      ? elders.first
      : await showModalBottomSheet<Elder>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Rekap kunjungan untuk siapa?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pilih lansia yang sedang Anda kunjungi.',
                      style: TextStyle(color: RelaColors.muted),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final e in elders)
                            Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: const Icon(Icons.person_outline),
                                title: Text(e.fullName),
                                subtitle: Text(
                                  e.verifyState == 'terverifikasi' ? e.address : 'Menunggu verifikasi keluarga oleh yayasan',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                enabled: e.verifyState == 'terverifikasi',
                                onTap: e.verifyState == 'terverifikasi'
                                    ? () => Navigator.pop(context, e)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  if (chosen == null || !context.mounted) return;
  if (chosen.verifyState != 'terverifikasi') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tunggu verifikasi keluarga oleh yayasan sebelum mencatat kunjungan.',
        ),
      ),
    );
    return;
  }
  await (onStart ?? (elder) => startStory(context, elder))(chosen);
}
