import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_screen.dart';
import 'ui.dart';
import '../shared/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _passwordHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Lupa password?'),
      content: const Text(
        'Untuk demo ReLa, hubungi pengelola aplikasi untuk bantuan mengatur ulang password akun Anda.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      // Setelah berhasil, AuthGate (main.dart) otomatis membuka beranda sesuai peran.
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal masuk. Periksa koneksi lalu coba lagi.'),
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
      title: 'Masuk',
      subtitle: 'Selamat datang kembali. Masuk untuk melanjutkan.',
      footer: authFooter(
        'Belum punya akun?',
        'Daftar',
        () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SignupScreen())),
      ),
      form: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              hint: 'Masukkan password',
              icon: Icons.lock_outline,
              controller: _password,
              autofillHints: const [AutofillHints.password],
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _passwordHelp,
                child: const Text('Lupa password?'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: bigFilled,
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Memproses…' : 'Masuk'),
            ),
          ],
        ),
      ),
    );
  }
}
