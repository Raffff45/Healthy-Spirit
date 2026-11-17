import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/db/app_database.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/achievements/streak_calculator.dart';
import '../../widgets/phone_width.dart';
import '../diary/diary_providers.dart';
import 'statistics_providers.dart';

const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

const _axisStyle = TextStyle(fontSize: 11, color: AppColors.textSecondary);

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  bool _allTime = false;

  Future<void> _addWeight(double current) async {
    final controller = TextEditingController(text: fmtNum(current));

    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Записать вес'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            suffixText: 'кг',
            helperText: 'Норма калорий пересчитается автоматически',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              if (v != null && v >= 30 && v <= 250) {
                Navigator.of(ctx).pop(v);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (value == null || !mounted) return;
    await ref.read(profileRepositoryProvider).updateWeight(value);
    // Вес и норма изменились: обновляем профиль
    ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final weights = ref.watch(weightHistoryProvider).value;
    final totals = ref.watch(dailyTotalsProvider).value;

    if (profile == null || weights == null || totals == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Статистика')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final goal = Goal.values.byName(profile.goal);

    // Вес: либо за 30 дней, либо за всё время
    final now = DateTime.now();
    var shown = _allTime
        ? weights
        : weights
            .where((w) => w.date.isAfter(now.subtract(const Duration(days: 30))))
            .toList();
    if (shown.isEmpty && weights.isNotEmpty) shown = [weights.last];

    final currentWeight =
        weights.isEmpty ? profile.weightKg : weights.last.weightKg;
    final delta = weights.length < 2
        ? 0.0
        : weights.last.weightKg - weights.first.weightKg;

    // Калории за последние 7 дней
    final today = DateTime(now.year, now.month, now.day);
    final week = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final kcals = [for (final d in week) totals[d]?.kcal ?? 0.0];
    final filled = kcals.where((k) => k > 0).toList();
    final avg = filled.isEmpty
        ? 0.0
        : filled.fold(0.0, (a, b) => a + b) / filled.length;
    final closedCount = kcals
        .where((k) => StreakCalculator.isDayClosed(k, profile.targetKcal))
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: SafeArea(
        child: PhoneWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // ---------- Вес ----------
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Вес',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fmtNum(currentWeight)} кг'
                                '${weights.length >= 2 ? '  ·  ${delta > 0 ? '+' : ''}${fmtNum(delta)} кг с начала' : ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _addWeight(currentWeight),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Записать'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('30 дней')),
                        ButtonSegment(value: true, label: Text('Всё время')),
                      ],
                      selected: {_allTime},
                      onSelectionChanged: (s) =>
                          setState(() => _allTime = s.first),
                    ),
                    const SizedBox(height: 18),
                    if (shown.isEmpty)
                      const SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            'Нет данных о весе',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else ...[
                      SizedBox(
                        height: 220,
                        child: _WeightChart(
                          entries: shown,
                          targetWeight:
                              goal == Goal.maintain ? null : profile.targetWeightKg,
                        ),
                      ),
                      if (shown.length < 2)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Записывай вес, чтобы увидеть динамику',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (goal != Goal.maintain)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 2,
                                color: AppColors.accentOrange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Цель: ${fmtNum(profile.targetWeightKg)} кг',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------- Калории за неделю ----------
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Калории за неделю',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Норма: ${profile.targetKcal} ккал в день',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: _CaloriesChart(
                        days: week,
                        kcals: kcals,
                        target: profile.targetKcal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _LegendDot(AppColors.primary, 'Цель выполнена'),
                        _LegendDot(AppColors.accentOrange, 'Перебор'),
                        _LegendDot(Color(0x806CD25C), 'Недобор'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _MiniStat(
                          filled.isEmpty ? '—' : '${avg.round()} ккал',
                          'В среднем за день',
                        ),
                        const SizedBox(width: 10),
                        _MiniStat('$closedCount из 7', 'Дней закрыто'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendDot(this.color, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: _axisStyle),
          ],
        ),
      ),
    );
  }
}

/// Линейный график веса
class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final double? targetWeight;

  const _WeightChart({required this.entries, required this.targetWeight});

  @override
  Widget build(BuildContext context) {
    final first = entries.first.date;
    double xOf(DateTime d) => d.difference(first).inMinutes / 1440.0;

    final spots = [for (final e in entries) FlSpot(xOf(e.date), e.weightKg)];
    final span = max(1.0, spots.last.x);

    var minW = entries.map((e) => e.weightKg).reduce(min);
    var maxW = entries.map((e) => e.weightKg).reduce(max);
    if (targetWeight != null) {
      minW = min(minW, targetWeight!);
      maxW = max(maxW, targetWeight!);
    }
    final minY = (minW - 1).floorToDouble();
    final maxY = (maxW + 1).ceilToDouble();
    final yInterval = max(1.0, ((maxY - minY) / 4).ceilToDouble());
    final xInterval = max(1.0, (span / 3).ceilToDouble());

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: span,
        minY: minY,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (v) =>
              const FlLine(color: AppColors.surfaceLight, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: yInterval,
              getTitlesWidget: (value, meta) =>
                  Text(value.toStringAsFixed(0), style: _axisStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final date =
                    first.add(Duration(minutes: (value * 1440).round()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_dm(date), style: _axisStyle),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (targetWeight != null)
              HorizontalLine(
                y: targetWeight!,
                color: AppColors.accentOrange.withValues(alpha: 0.8),
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Столбчатый график калорий за 7 дней
class _CaloriesChart extends StatelessWidget {
  final List<DateTime> days;
  final List<double> kcals;
  final int target;

  const _CaloriesChart({
    required this.days,
    required this.kcals,
    required this.target,
  });

  Color _color(double kcal) {
    if (StreakCalculator.isDayClosed(kcal, target)) return AppColors.primary;
    if (kcal > target) return AppColors.accentOrange;
    return AppColors.primary.withValues(alpha: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final maxKcal = kcals.reduce(max);
    final rawMax = max(target * 1.3, maxKcal * 1.1);
    final yInterval = ((rawMax / 4) / 100).ceil() * 100.0;
    // Верх оси кратен шагу, чтобы подписи были круглыми
    final maxY = (rawMax / yInterval).ceil() * yInterval;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (v) =>
              const FlLine(color: AppColors.surfaceLight, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (value, meta) =>
                  Text(value.toInt().toString(), style: _axisStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _weekdays[days[i].weekday - 1],
                    style: _axisStyle,
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: target.toDouble(),
              color: AppColors.textSecondary,
              strokeWidth: 1.5,
              dashArray: [6, 4],
            ),
          ],
        ),
        barGroups: [
          for (var i = 0; i < kcals.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: kcals[i],
                  width: 22,
                  color: _color(kcals[i]),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}