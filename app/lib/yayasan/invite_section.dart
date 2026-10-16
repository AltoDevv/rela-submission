import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tautan yang dibuka JoinScreen (main.dart menangani skema `temansenja://join`).
String inviteLink(String code) => 'temansenja://join?code=$code';

/// F1a: kode undangan yayasan dan tombol salin tautan untuk dibagikan ke grup WhatsApp.
class InviteSection extends StatefulWidget {
  /// `code` diisi saat test; di aplikasi kode dibaca dari `foundations` milik pengurus yang login.
  const InviteSection({super.key, this.code});

  final String? code;

  @override
  State<InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends State<InviteSection> {
  // Dibuat sekali: future di build() mengambil ulang kode setiap kali beranda dibangun ulang.
  late final Future<String> _code = _load();

  Future<String> _load() async {
    if (widget.code != null) return widget.code!;
    final db = Supabase.instance.client;
    final me = await db.from('profiles').select('foundation_id').eq('id', db.auth.currentUser!.id).single();
    final f = await db.from('foundations').select('invite_code').eq('id', me['foundation_id']).single();
    return f['invite_code'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<String>(
          future: _code,
          builder: (context, snap) {
            if (snap.hasError) return const Text('Gagal memuat kode undangan');
            if (!snap.hasData) return const LinearProgressIndicator();
            final link = inviteLink(snap.data!);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Undangan relawan', style: Theme.of(context).textTheme.titleMedium),
                const Text('Kode undangan:'),
                SelectableText(snap.data!, style: Theme.of(context).textTheme.headlineMedium),
                Text(link, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin tautan'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: link));
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Tautan undangan disalin. Tempel di grup WhatsApp.')),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
