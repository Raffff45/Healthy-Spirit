import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthy_spirit/domain/calculators/nutrition_calculator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/db/app_database.dart';
import '../../data/models/activity_level.dart';
import '../../data/models/gender.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/profile_repository.dart';
import '../../widgets/avatar_widgets.dart';
import '../../widgets/number_stepper.dart';
import '../../widgets/phone_width.dart';
import '../diary/diary_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late String _avatar;
  late Gender _gender;
  late int _age;
  late int _height;
  late int _weight;
  late int _target;
  late ActivityLevel _activity;
  late Goal _goal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.name);
    _avatar = p.avatar;
    _gender = Gender.values.byName(p.gender);
    _age = p.age;
    _height = p.heightCm;
    _weight = p.weightKg.round();
    _target = p.targetWeightKg.round();
    _activity = ActivityLevel.values.byName(p.activity);
    _goal = Goal.values.byName(p.goal);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _targetValid {
    switch (_goal) {
      case Goal.lose:
        return _target < _weight;
      case Goal.gain:
        return _target > _weight;
      case Goal.maintain:
        return true;
    }
  }

  bool get _nameValid => _name.text.trim().isNotEmpty;

  NutritionResult _calculate() {
    return NutritionCalculator.calculate(
      gender: _gender,
      age: _age,
      heightCm: _height,
      weightKg: _weight.toDouble(),
      targetWeightKg: (_goal == Goal.maintain ? _weight : _target).toDouble(),
      activity: _activity,
      goal: _goal,
    );
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    setState(() => _saving = true);

    await ref.read(profileRepositoryProvider).saveProfile(
          name: _name.text.trim(),
          avatar: _avatar,
          gender: _gender,
          age: _age,
          heightCm: _height,
          weightKg: _weight.toDouble(),
          targetWeightKg:
              (_goal == Goal.maintain ? _weight : _target).toDouble(),
          activity: _activity,
          goal: _goal,
          result: _calculate(),
        );

    // Норма изменилась: обновляем профиль и серии достижений
    ref.invalidate(profileProvider);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = _calculate();
    final needsTarget = _goal != Goal.maintain;

    return Scaffold(
      appBar: AppBar(title: const Text('Редактирование профиля')),
      body: SafeArea(
        child: PhoneWidth(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  children: [
                    // Аватарка и имя
                    Center(child: AvatarCircle(avatarId: _avatar, size: 84)),
                    const SizedBox(height: 16),
                    AvatarPicker(
                      selected: _avatar,
                      onChanged: (id) => setState(() => _avatar = id),
                    ),
                    const SizedBox(height: 20),
                    const _Label('Имя'),
                    TextField(
                      controller: _name,
                      maxLength: 24,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Как тебя зовут?',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),

                    const _Label('Цель'),
                    SegmentedButton<Goal>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: Goal.lose, label: Text('Похудеть')),
                        ButtonSegment(value: Goal.maintain, label: Text('Держать')),
                        ButtonSegment(value: Goal.gain, label: Text('Набрать')),
                      ],
                      selected: {_goal},
                      onSelectionChanged: (s) => setState(() {
                        _goal = s.first;
                        // Подставляем разумный целевой вес, если он не подходит
                        if (!_targetValid) {
                          final shift = _goal == Goal.lose ? -5 : 5;
                          _target = (_weight + shift).clamp(30, 250).toInt();
                        }
                      }),
                    ),
                    const SizedBox(height: 20),
                    const _Label('Пол'),
                    SegmentedButton<Gender>(
                      showSelectedIcon: false,
                      segments: [
                        for (final g in Gender.values)
                          ButtonSegment(value: g, label: Text(g.label)),
                      ],
                      selected: {_gender},
                      onSelectionChanged: (s) =>
                          setState(() => _gender = s.first),
                    ),
                    const SizedBox(height: 20),
                    NumberStepper(
                      label: 'Возраст',
                      unit: 'лет',
                      value: _age,
                      min: 14,
                      max: 90,
                      onChanged: (v) => setState(() => _age = v),
                    ),
                    NumberStepper(
                      label: 'Рост',
                      unit: 'см',
                      value: _height,
                      min: 120,
                      max: 220,
                      onChanged: (v) => setState(() => _height = v),
                    ),
                    NumberStepper(
                      label: 'Текущий вес',
                      unit: 'кг',
                      value: _weight,
                      min: 30,
                      max: 250,
                      onChanged: (v) => setState(() => _weight = v),
                    ),
                    if (needsTarget)
                      NumberStepper(
                        label: 'Желаемый вес',
                        unit: 'кг',
                        value: _target,
                        min: 30,
                        max: 250,
                        onChanged: (v) => setState(() => _target = v),
                      ),
                    if (needsTarget && !_targetValid)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _goal == Goal.lose
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
                      initialValue: _activity,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      items: [
                        for (final a in ActivityLevel.values)
                          DropdownMenuItem(
                            value: a,
                            child: Text(a.label, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _activity = v);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Предпросмотр новой нормы
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Новая норма',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r.targetKcal} ккал в день',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Б ${r.protein} г · Ж ${r.fat} г · У ${r.carbs} г'
                            '${r.weeks != null && needsTarget ? '  ·  ≈ ${r.weeks} нед. до цели' : ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  onPressed:
                      (_targetValid && _nameValid && !_saving) ? _save : null,
                  child: const Text('Сохранить'),
                ),
              ),
            ],
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