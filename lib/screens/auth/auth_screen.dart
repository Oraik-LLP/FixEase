import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/supabase_config.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neuomorphic.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  String? _error;
  bool _obscure = true;

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    String? err;
    if (_isSignUp) {
      err = await AuthService.instance.signUp(
        email: email,
        password: pass,
        displayName: _name.text.trim().isNotEmpty ? _name.text.trim() : null,
      );
    } else {
      err = await AuthService.instance.signIn(email: email, password: pass);
    }

    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          'assets/logo/fixease_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.build_rounded,
                            size: 36,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isSignUp ? 'Create Account' : 'Welcome Back',
                    style: tt.headlineLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp
                        ? 'Sign up to start diagnosing'
                        : 'Sign in to continue',
                    style: tt.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  if (!SupabaseConfig.isConfigured) ...[
                    NeuPane(
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.accent, size: 28),
                          const SizedBox(height: 10),
                          Text(
                            'Supabase not configured yet.\n'
                            'You can continue as a guest — all data stays on-device.',
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    NeuPrimaryButton(
                      label: 'Continue as Guest',
                      onPressed: widget.onComplete,
                    ),
                  ] else ...[
                    if (_isSignUp) ...[
                      NeuTextField(
                        hint: 'Display name',
                        icon: Icons.person_outline_rounded,
                        controller: _name,
                      ),
                      const SizedBox(height: 14),
                    ],
                    NeuTextField(
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    NeuTextField(
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      controller: _password,
                      obscure: _obscure,
                      trailing: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFFF5252),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24),
                    ListenableBuilder(
                      listenable: AuthService.instance,
                      builder: (_, __) {
                        return NeuPrimaryButton(
                          label: AuthService.instance.loading
                              ? 'Please wait...'
                              : (_isSignUp ? 'Sign Up' : 'Sign In'),
                          onPressed:
                              AuthService.instance.loading ? null : _submit,
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                        });
                      },
                      child: Text.rich(
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account? '
                              : 'Don\'t have an account? ',
                          style: tt.bodyMedium,
                          children: [
                            TextSpan(
                              text: _isSignUp ? 'Sign In' : 'Sign Up',
                              style: tt.bodyMedium?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onComplete();
                      },
                      child: Text(
                        'Skip for now',
                        style: tt.bodySmall?.copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
