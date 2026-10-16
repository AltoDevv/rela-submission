import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/theme.dart';
import 'visit_confirm_screen.dart';

/// 7 pertanyaan terbuka (PRD F3): (judul, penjelas). Key = kolom `visits.answers`, sama dengan `Answers` di extract.ts.
const storyQuestions = {
  'makan': ('Makan', 'Bagaimana nafsu makan dan berapa banyak yang dimakan?'),
  'obat': ('Obat', 'Apakah obat diminum teratur? Bagaimana persediaannya?'),
  'gerak': ('Mobilitas', 'Kemampuan berjalan, bantuan, dan kejadian jatuh.'),
  'harian': ('Aktivitas harian', 'Mandi, berpakaian, dan menggunakan toilet.'),
  'ingatan': ('Ingatan dan obrolan', 'Ingatan, percakapan, dan kebingungan.'),
  'hati': ('Suasana hati', 'Kondisi emosional dan interaksi sosial.'),
  'lain': ('Kondisi umum', 'Keluhan lain dan kegiatan selama kunjungan.'),
};

/// Menambahkan hasil dikte ke akhir teks yang sudah ada (tidak menimpa), dipisah satu spasi.
String appendDictation(String current, String dictated) =>
    [current.trim(), dictated.trim()].where((s) => s.isNotEmpty).join(' ');

/// F3: relawan bercerita tentang kunjungan, dengan mengetik atau dikte (STT bawaan HP, T-022).
class VisitStoryScreen extends StatefulWidget {
  const VisitStoryScreen({super.key, required this.elderId, this.elderName});

  final String elderId;
  final String? elderName;

  @override
  State<VisitStoryScreen> createState() => _VisitStoryScreenState();
}

class _VisitStoryScreenState extends State<VisitStoryScreen> {
  final _form = GlobalKey<FormState>();
  final _answers = {for (final k in storyQuestions.keys) k: TextEditingController()};
  String? _visitId; // disimpan supaya "Coba lagi" tidak membuat kunjungan dobel
  bool _busy = false;

  final _stt = SpeechToText();
  bool _sttReady = false; // false = izin mikrofon ditolak atau STT tidak ada → tombol mikrofon disembunyikan
  String? _listeningKey; // pertanyaan yang sedang direkam

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  /// Sekaligus meminta izin mikrofon. Gagal dalam bentuk apa pun berarti tetap mode ketik.
  Future<void> _initStt() async {
    var ok = false;
    try {
      ok = await _stt.initialize(
        onStatus: (s) {
          if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) _stopped();
        },
        onError: (_) => _stopped(),
      );
    } catch (_) {
      ok = false; // plugin tidak tersedia (mis. saat test) atau error platform
    }
    if (mounted) setState(() => _sttReady = ok);
  }

  void _stopped() {
    if (mounted && _listeningKey != null) setState(() => _listeningKey = null);
  }

  Future<void> _toggleMic(String key) async {
    final wasListening = _listeningKey;
    if (wasListening != null) await _stt.stop();
    if (wasListening == key) return _stopped();

    setState(() => _listeningKey = key);
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        if (!r.finalResult) return;
        final c = _answers[key]!;
        c.text = appendDictation(c.text, r.recognizedWords);
        c.selection = TextSelection.collapsed(offset: c.text.length);
      },
      listenOptions: SpeechListenOptions(
        localeId: 'id_ID',
        partialResults: false,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _stt.cancel();
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_answers.values.every((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Isi minimal satu cerita dulu')));
      return;
    }
    setState(() => _busy = true);
    final db = Supabase.instance.client;
    try {
      _visitId ??= (await db
          .from('visits')
          .insert({
            'elder_id': widget.elderId,
            'volunteer_id': db.auth.currentUser!.id,
            'answers': {for (final e in _answers.entries) e.key: e.value.text.trim()},
          })
          .select('id')
          .single())['id'] as String;

      final res = await db.functions.invoke('visit', body: {'action': 'extract', 'visit_id': _visitId});
      final ai = ((res.data as Map)['ai_result'] as Map).cast<String, dynamic>();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VisitConfirmScreen(
            visitId: _visitId!,
            aiResult: ai,
            answers: {for (final e in _answers.entries) e.key: e.value.text.trim()},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_visitId == null
            ? (e is PostgrestException ? e.message : 'Gagal menyimpan cerita: $e') // mis. sudah ada kunjungan hari ini
            : 'Gagal membaca cerita, coba lagi'),
        action: SnackBarAction(label: 'Coba lagi', onPressed: _submit),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: RelaColors.muted);
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Kunjungan'), centerTitle: true),
      body: _busy
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 8)),
                  SizedBox(height: 32),
                  Text('Sedang menganalisis cerita kunjungan Anda…',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  SizedBox(height: 16),
                  Text('Sistem membaca tujuh bagian cerita dan menyiapkan kategori untuk Anda periksa.',
                      textAlign: TextAlign.center, style: muted),
                ]),
              ),
            )
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                if (widget.elderName != null) ...[
                  Text('Kunjungan untuk ${widget.elderName}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
                const Text('Ceritakan kunjungan hari ini dengan kata-kata sendiri. '
                    'Bagian yang tidak ada ceritanya boleh dikosongkan.', style: muted),
                for (final (i, e) in storyQuestions.entries.indexed) ...[
                  const SizedBox(height: 16),
                  Text('${i + 1}. ${e.value.$1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(e.value.$2, style: muted),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _answers[e.key],
                    decoration: InputDecoration(
                      suffixIcon: !_sttReady
                          ? null
                          : IconButton(
                              tooltip: _listeningKey == e.key ? 'Berhenti merekam' : 'Rekam suara',
                              icon: Icon(_listeningKey == e.key ? Icons.stop_circle : Icons.mic),
                              color: _listeningKey == e.key ? Colors.red : null,
                              onPressed: () => _toggleMic(e.key),
                            ),
                      helperText: _listeningKey == e.key ? 'Mendengarkan… bicara dalam bahasa Indonesia' : null,
                    ),
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 1000,
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(style: bigOutlined, onPressed: _submit, child: const Text('Kirim Rekap')),
              ]),
            ),
    );
  }
}
