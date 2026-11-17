import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/activity_level.dart';
import '../../data/models/gender.dart';
import '../../data/models/goal.dart';

class OnboardingState {
  final Goal? goal;
  final String name;
  final String avatar;
  final Gender gender;
  final int age;
  final int height;
  final int weight;
  final int targetWeight;
  final ActivityLevel activity;

  const OnboardingState({
    this.goal,
    this.name = '',
    this.avatar = 'eco',
    this.gender = Gender.male,
    this.age = 25,
    this.height = 175,
    this.weight = 70,
    this.targetWeight = 65,
    this.activity = ActivityLevel.moderate,
  });

  /// Проверка: целевой вес должен соответствовать цели
  bool get isTargetValid {
    switch (goal) {
      case Goal.lose:
        return targetWeight < weight;
      case Goal.gain:
        return targetWeight > weight;
      default:
        return true;
    }
  }

  bool get isNameValid => name.trim().isNotEmpty;

  OnboardingState copyWith({
    Goal? goal,
    String? name,
    String? avatar,
    Gender? gender,
    int? age,
    int? height,
    int? weight,
    int? targetWeight,
    ActivityLevel? activity,
  }) {
    return OnboardingState(
      goal: goal ?? this.goal,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      targetWeight: targetWeight ?? this.targetWeight,
      activity: activity ?? this.activity,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setGoal(Goal v) => state = state.copyWith(goal: v);
  void setName(String v) => state = state.copyWith(name: v);
  void setAvatar(String v) => state = state.copyWith(avatar: v);
  void setGender(Gender v) => state = state.copyWith(gender: v);
  void setAge(int v) => state = state.copyWith(age: v);
  void setHeight(int v) => state = state.copyWith(height: v);
  void setWeight(int v) => state = state.copyWith(weight: v);
  void setTargetWeight(int v) => state = state.copyWith(targetWeight: v);
  void setActivity(ActivityLevel v) => state = state.copyWith(activity: v);
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);