import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/terms_screen.dart';
import '../shared/theme.dart';
import 'ui.dart';

String? validateEmail(String? v) =>
    v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
    ? null
    : 'Email tidak valid';

String? validatePassword(String? v) =>
    v != null && v.length >= 6 ? null : 'Minimal 6 karakter';

String? validateRequired(String? v) =>
    v != null && v.trim().isNotEmpty ? null : 'Wajib diisi';

/// Nomor HP Indonesia: 08xxxxxxxx atau +628xxxxxxxx (10–14 digit setelah awalan).
String? validatePhone(String? v) =>
    v != null &&
        RegExp(r'^(\+62|0)8\d{7,12}$')
            .hasMatch(v.replaceAll(RegExp(r'[\s-]'), ''))
    ? null
    : 'Nomor HP tidak valid (contoh 081234567890)';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'keluarga'; // akun yayasan hanya dibuat lewat seed (PRD F0)
  bool _busy = false;
  bool _terms = false;
  bool _hidden = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setujui Syarat & Persetujuan terlebih dahulu.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      // Peran, nama, dan HP dikirim lewat metadata; trigger handle_new_user (T-003) membuat baris profiles.
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'role': _role,
          'full_name': _name.text.trim(),
          'phone': _phone.text.replaceAll(RegExp(r'[\s-]'), ''),
          'terms_accepted': true, // waktunya dicatat trigger handle_new_user
        },
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendaftar. Periksa koneksi lalu coba lagi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Daftar akun',
      subtitle:
          'Buat akun untuk mulai mendampingi atau memantau orang tersayang.',
      back: true,
      footer: authFooter(
        'Sudah punya akun?',
        'Masuk',
        () => Navigator.of(context).pop(),
      ),
      form: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Saya mendaftar sebagai:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _roleChoice('keluarga', 'Keluarga')),
                const SizedBox(width: 8),
                Expanded(child: _roleChoice('relawan', 'Relawan')),
              ],
            ),
            const SizedBox(height: 18),
            AuthField(
              inputKey: const Key('nama'),
              label: 'Nama lengkap',
              hint: 'Nama lengkap',
              icon: Icons.person_outline,
              controller: _name,
              autofillHints: const [AutofillHints.name],
              validator: validateRequired,
            ),
            AuthField(
              inputKey: const Key('telepon'),
              label: 'Nomor HP',
              hint: '0812 3456 7890',
              icon: Icons.phone_outlined,
              controller: _phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              keyboardType: TextInputType.phone,
              validator: validatePhone,
            ),
            AuthField(
              inputKey: const Key('email'),
              label: 'Email',
              hint: 'nama@email.com',
              icon: Icons.mail_outline,
              controller: _email,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
            ),
            AuthField(
              inputKey: const Key('password'),
              label: 'Password',
              hint: 'Buat password',
              icon: Icons.lock_outline,
              controller: _password,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _hidden,
              validator: validatePassword,
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                tooltip: _hidden
                    ? 'Tampilkan password'
                    : 'Sembunyikan password',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            CheckboxListTile(
              key: const Key('setuju-syarat'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _terms,
              onChanged: (v) => setState(() => _terms = v ?? false),
              title: const Text(
                'Saya menyetujui Syarat & Persetujuan, termasuk pemrosesan data di luar Indonesia',
              ),
            ),
            Align(alignment: Alignment.centerLeft, child: termsLink(context)),
            const SizedBox(height: 16),
            FilledButton(
              style: bigFilled,
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Memproses…' : 'Daftar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChoice(String value, String label) {
    final selected = _role == value;
    return Semantics(
      key: Key('peran-$value'),
      selected: selected,
      child: OutlinedButton(
        onPressed: _busy ? null : () => setState(() => _role = value),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          foregroundColor: selected ? RelaColors.primary : RelaColors.ink,
          backgroundColor: selected ? const Color(0xFFE1EDF2) : Colors.white,
          side: BorderSide(
            color: selected ? RelaColors.primary : RelaColors.border,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
