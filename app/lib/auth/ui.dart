import 'package:flutter/material.dart';

import '../shared/theme.dart';

/// Latar dan panel formulir dari desain Masuk/Daftar. Tetap bisa digulir saat keyboard terbuka.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    this.back = false,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF57859A)),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                Container(
                  height: top + 140,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFD5CEB8), Color(0xFF57859A)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: top),
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: RelaColors.primary),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/rela-logo.png',
                                width: 68,
                                height: 68,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (back)
                        Positioned(
                          left: 16,
                          top: top + 16,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: RelaColors.ink,
                            ),
                            tooltip: 'Kembali',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      28,
                      24,
                      16 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 520,
                          minHeight:
                              (constraints.maxHeight -
                                      top -
                                      184 -
                                      MediaQuery.paddingOf(context).bottom)
                                  .clamp(0, double.infinity),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: RelaColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: RelaColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                form,
                                const SizedBox(height: 100),
                              ],
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: footer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.validator,
    this.inputKey,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final Key? inputKey;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: RelaColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: inputKey,
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          textInputAction: onSubmitted == null
              ? TextInputAction.next
              : TextInputAction.done,
          style: const TextStyle(fontSize: 17, color: RelaColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: RelaColors.muted),
            prefixIcon: Icon(icon, color: RelaColors.muted),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: RelaColors.border,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget authFooter(String prompt, String action, VoidCallback onTap) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Flexible(
      child: Text(prompt, style: const TextStyle(color: RelaColors.muted)),
    ),
    TextButton(
      onPressed: onTap,
      child: Text(
        action,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  ],
);
