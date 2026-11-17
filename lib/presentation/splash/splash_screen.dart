import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../../core/theme/app_colors.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/sync/sync_service.dart';
import '../diary/diary_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;

    // Заставка показывается минимум 3 секунды, синхронизация идёт параллельно
    await Future.wait<void>([
      loggedIn
          ? ref.read(syncServiceProvider).start()
          : Future<void>.value(),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
    if (!mounted) return;

    if (!loggedIn) {
      context.go('/login');
      return;
    }

    ref.invalidate(profileProvider);
    final profile = await ref.read(profileRepositoryProvider).getProfile();
    if (!mounted) return;
    context.go(profile == null ? '/goal' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            const Icon(Icons.eco_rounded, size: 110, color: AppColors.primary)
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 20),
            const Text(
              'Healthy Spirit',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 800.ms).slideY(begin: 0.3),
            const SizedBox(height: 12),
            const Text(
              'Питайся осознанно.\nДостигай целей.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ).animate().fadeIn(delay: 900.ms, duration: 800.ms),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 3),
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceLight,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}