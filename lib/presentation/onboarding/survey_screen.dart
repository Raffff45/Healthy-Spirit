import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/activity_level.dart';
import '../../data/models/gender.dart';
import '../../data/models/goal.dart';
import '../../widgets/avatar_widgets.dart';
import '../../widgets/number_stepper.dart';
import 'onboarding_provider.dart';

class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(onboardingProvider).name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(onboardingProvider);
    final n = ref.read(onboardingProvider.notifier);
    final needsTarget = s.goal != null && s.goal != Goal.maintain;
    final canContinue = s.isTargetValid && s.isNameValid;

    return Scaffold(
      appBar: AppBar(title: const Text('Расскажи о себе')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Аватарка и имя
                          Center(
                            child: AvatarCircle(avatarId: s.avatar, size: 84),
                          ),
                          const SizedBox(height: 16),
                          AvatarPicker(
                            selected: s.avatar,
                            onChanged: n.setAvatar,
                          ),
                          const SizedBox(height: 20),
                          const _Label('Как тебя зовут?'),
                          TextField(
                            controller: _name,
                            maxLength: 24,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Имя',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              counterText: '',
                            ),
                            onChanged: n.setName,
                          ),
                          const SizedBox(height: 20),

                          const _Label('Пол'),
                          Row(
                            children: [
                              Expanded(
                                child: _GenderChip(
                                  text: 'Мужской',
                                  icon: Icons.male_rounded,
                                  selected: s.gender == Gender.male,
                                  onTap: () => n.setGender(Gender.male),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _GenderChip(
                                  text: 'Женский',
                                  icon: Icons.female_rounded,
                                  selected: s.gender == Gender.female,
                                  onTap: () => n.setGender(Gender.female),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          NumberStepper(
                            label: 'Возраст',
                            unit: 'лет',
                            value: s.age,
                            min: 14,
                            max: 90,
                            onChanged: n.setAge,
                          ),
                          NumberStepper(
                            label: 'Рост',
                            unit: 'см',
                            value: s.height,
                            min: 120,
                            max: 220,
                            onChanged: n.setHeight,
                          ),
                          NumberStepper(
                            label: 'Вес',
                            unit: 'кг',
                            value: s.weight,
                            min: 30,
                            max: 250,
                            onChanged: n.setWeight,
                          ),
                          if (needsTarget)
                            NumberStepper(
                              label: 'Желаемый вес',
                              unit: 'кг',
                              value: s.targetWeight,
                              min: 30,
                              max: 250,
                              onChanged: n.setTargetWeight,
                            ),
                          if (needsTarget && !s.isTargetValid)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                s.goal == Goal.lose
                                    ? 'Желаемый вес должен быть меньше текущего'
                                    : 'Желаемый вес должен быть больше текущего',
                                style: const TextStyle(
                                  color: AppColors.accentOrange,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          const _Label('Уровень активности'),
                          DropdownButtonFormField<ActivityLevel>(
                            initialValue: s.activity,
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            items: [
                              for (final a in ActivityLevel.values)
                                DropdownMenuItem(
                                  value: a,
                                  child: Text(
                                    a.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) n.setActivity(v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!s.isNameValid)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Введи своё имя, чтобы продолжить',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: canContinue ? () => context.push('/result') : null,
                    child: const Text('Далее'),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.text,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}