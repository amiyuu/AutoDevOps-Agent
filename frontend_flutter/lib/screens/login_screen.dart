import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(authNotifierProvider.notifier);
      await notifier.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message;
        switch (e.code) {
          case 'user-not-found':
            message = 'このメールアドレスのアカウントが見つかりません。';
            break;
          case 'wrong-password':
          case 'invalid-credential':
            message = 'メールアドレスまたはパスワードが正しくありません。';
            break;
          case 'too-many-requests':
            message = 'ログイン試行が多すぎます。しばらく後に再試行してください。';
            break;
          default:
            message = '認証エラー: ${e.message ?? e.code}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFFFF3366),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFFFF3366),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            colors: [
              Color(0x0A00F0FF),
              Color(0xFF0D0E12),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- ロゴ & タイトル ----
                    _buildHeader(),
                    const SizedBox(height: 48),

                    // ---- ログインカード ----
                    _buildLoginCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // シアンのグロウ付きアイコン
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF161822),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withOpacity(0.25),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.terminal_rounded,
            color: Color(0xFF00F0FF),
            size: 38,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .custom(
              duration: 2400.ms,
              builder: (ctx, val, child) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color.lerp(
                        const Color(0xFF00F0FF).withOpacity(0.15),
                        const Color(0xFF00F0FF).withOpacity(0.45),
                        val,
                      )!,
                      blurRadius: 36,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
        const SizedBox(height: 24),
        Text(
          'AUTO DEVOPS COCKPIT',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00F0FF),
            letterSpacing: 3,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 100.ms),
        const SizedBox(height: 6),
        Text(
          '管理者アカウントでサインイン',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00F0FF).withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withOpacity(0.06),
            blurRadius: 32,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // メールフィールド
            _buildLabel('EMAIL ADDRESS'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
              decoration: _inputDecoration(
                hintText: 'admin@example.com',
                prefixIcon: Icons.alternate_email_rounded,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'メールアドレスを入力してください';
                if (!v.contains('@')) return '有効なメールアドレスを入力してください';
                return null;
              },
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 300.ms)
                .slideX(begin: -0.04, end: 0.0),
            const SizedBox(height: 20),

            // パスワードフィールド
            _buildLabel('PASSWORD'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
              decoration: _inputDecoration(
                hintText: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'パスワードを入力してください';
                if (v.length < 6) return 'パスワードは6文字以上必要です';
                return null;
              },
              onFieldSubmitted: (_) => _signIn(),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 400.ms)
                .slideX(begin: -0.04, end: 0.0),
            const SizedBox(height: 32),

            // サインインボタン
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  disabledBackgroundColor: const Color(0xFF00F0FF).withOpacity(0.4),
                  elevation: 12,
                  shadowColor: const Color(0xFF00F0FF).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'SIGN IN',
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 500.ms)
                .slideY(begin: 0.1, end: 0.0),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.06, end: 0.0);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500,
        letterSpacing: 1.5,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade600, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF0D0E12),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: Colors.grey.shade800, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            BorderSide(color: Colors.grey.shade800, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFFFF3366), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFFFF3366), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF3366)),
    );
  }
}
