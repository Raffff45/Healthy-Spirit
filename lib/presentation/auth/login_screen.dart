import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, Supabase;
import '../../core/theme/app_colors.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/sync/sync_service.dart';
import '../diary/diary_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _translate(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login')) return 'Неверная почта или пароль';
    if (m.contains('already registered') || m.contains('already been')) {
      return 'Такой аккаунт уже существует. Нажми «Войти»';
    }
    if (m.contains('password') && m.contains('characters')) {
      return 'Пароль слишком короткий (минимум 6 символов)';
    }
    if (m.contains('rate limit')) {
      return 'Слишком много попыток. Подожди немного';
    }
    if (m.contains('email') && m.contains('invalid')) {
      return 'Некорректная почта';
    }
    return 'Ошибка: $message';
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Введи корректную почту');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Пароль: минимум 6 символов');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        final res = await auth.signUp(email: email, password: password);
        if (res.session == null) {
          setState(() => _error =
              'Подтверди почту по ссылке из письма, потом нажми «Войти»');
          return;
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }

      // Загружаем данные аккаунта (или отправляем локальные, если облако пусто)
      await ref.read(syncServiceProvider).start();
      ref.invalidate(profileProvider);
      final profile = await ref.read(profileRepositoryProvider).getProfile();
      if (!mounted) return;
      context.go(profile == null ? '/goal' : '/home');
    } on AuthException catch (e) {
      setState(() => _error = _translate(e.message));
    } catch (_) {
      setState(() => _error = 'Не удалось подключиться. Проверь интернет');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.eco_rounded,
                    size: 72,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Healthy Spirit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _register
                        ? 'Создай аккаунт, чтобы прогресс не терялся'
                        : 'Войди, чтобы вернуть свой прогресс',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      hintText: 'Почта',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _hidePassword,
                    onSubmitted: (_) => _loading ? null : _submit(),
                    decoration: InputDecoration(
                      hintText: 'Пароль',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.accentOrange,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_register ? 'Зарегистрироваться' : 'Войти'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _register = !_register;
                              _error = null;
                            }),
                    child: Text(
                      _register
                          ? 'Уже есть аккаунт? Войти'
                          : 'Нет аккаунта? Зарегистрироваться',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}