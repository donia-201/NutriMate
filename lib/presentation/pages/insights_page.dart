import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../core/utils/app_colors.dart';
import '../widgets/bottom_nav.dart';

enum InsightPeriod { today, week, month, custom }

class InsightsPage extends StatefulWidget {
  final ValueChanged<int>? onBottomNavTap;

  /// True when the page is a tab inside the home shell. The shell already
  /// has the bottom navigation bar, so the page must not add a second one.
  final bool embedded;

  /// Called by the back arrow. As a tab there is nothing to pop, so the
  /// home shell passes an action that returns to the Home tab.
  final VoidCallback? onBack;

  const InsightsPage({
    super.key,
    this.onBottomNavTap,
    this.embedded = false,
    this.onBack,
  });

  @override
  State<InsightsPage> createState() => InsightsPageState();
}

class InsightsPageState extends State<InsightsPage> {
  final LocalDatabaseService _database = LocalDatabaseService.instance;
  InsightPeriod _period = InsightPeriod.today;
  DateTime _anchorDate = _dateOnly(DateTime.now());
  DateTimeRange? _customRange;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;
  String? _uid;
  StreamSubscription<User?>? _authSubscription;

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime get _startDate {
    switch (_period) {
      case InsightPeriod.today:
        return _dateOnly(_anchorDate);
      case InsightPeriod.week:
        return _dateOnly(
          _anchorDate,
        ).subtract(Duration(days: _anchorDate.weekday - DateTime.monday));
      case InsightPeriod.month:
        return DateTime(_anchorDate.year, _anchorDate.month);
      case InsightPeriod.custom:
        return _dateOnly(_customRange?.start ?? _anchorDate);
    }
  }

  DateTime get _endDate {
    switch (_period) {
      case InsightPeriod.today:
        return _dateOnly(_anchorDate);
      case InsightPeriod.week:
        return _startDate.add(const Duration(days: 6));
      case InsightPeriod.month:
        return DateTime(_anchorDate.year, _anchorDate.month + 1, 0);
      case InsightPeriod.custom:
        return _dateOnly(_customRange?.end ?? _anchorDate);
    }
  }

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() => _uid = user?.uid);
      _loadLogs();
    });
    _database.mealLogsRevision.addListener(_onMealLogsChanged);
    _loadLogs();
  }
  // A meal was logged somewhere in the app: reload quietly, no spinner.
  void _onMealLogsChanged() {
    if (mounted) _loadLogs(silent: true);
  }


  @override
  void dispose() {
    _database.mealLogsRevision.removeListener(_onMealLogsChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> reload() => _loadLogs();

  Future<void> _loadLogs({bool silent = false}) async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _logs = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final logs = await _database.getMealLogs(
        uid,
        start: _startDate,
        end: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    if (_period == InsightPeriod.custom) {
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange:
            _customRange ?? DateTimeRange(start: _anchorDate, end: _anchorDate),
      );
      if (selected != null) {
        setState(() {
          _customRange = selected;
          _anchorDate = _dateOnly(selected.start);
        });
        await _loadLogs();
      }
      return;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      setState(() => _anchorDate = _dateOnly(selected));
      await _loadLogs();
    }
  }

  void _changePeriod(InsightPeriod period) {
    setState(() {
      _period = period;
      if (period == InsightPeriod.custom && _customRange == null) {
        _customRange = DateTimeRange(start: _anchorDate, end: _anchorDate);
      }
    });
    _loadLogs();
  }

  double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  double _sum(String key) =>
      _logs.fold(0, (sum, row) => sum + _number(row[key]));

  List<_DayTotal> get _dailyTotals {
    final map = <String, _DayTotal>{};
    for (final row in _logs) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        _number(row['loggedAt']).toInt(),
      );
      final day = _dateOnly(date);
      final key = DateFormat('yyyy-MM-dd').format(day);
      final current = map[key] ?? _DayTotal(day);
      current
        ..calories += _number(row['calories'])
        ..protein += _number(row['protein'])
        ..carbs += _number(row['carbohydrates'])
        ..fat += _number(row['fat']);
      map[key] = current;
    }

    final days = <_DayTotal>[];
    for (
      var date = _startDate;
      !date.isAfter(_endDate);
      date = date.add(const Duration(days: 1))
    ) {
      days.add(map[DateFormat('yyyy-MM-dd').format(date)] ?? _DayTotal(date));
    }
    return days;
  }

  double get _dailyAverageCalories {
    final days = _dailyTotals;
    if (days.isEmpty) return 0;
    return days.fold(0.0, (sum, day) => sum + day.calories) / days.length;
  }

  String get _rangeLabel {
    switch (_period) {
      case InsightPeriod.today:
        return DateFormat('EEEE, MMMM d, y').format(_anchorDate);
      case InsightPeriod.week:
        return '${DateFormat('MMM d').format(_startDate)}-${DateFormat('MMM d, y').format(_endDate)}';
      case InsightPeriod.month:
        return DateFormat('MMMM y').format(_anchorDate);
      case InsightPeriod.custom:
        return '${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _dailyTotals;
    final calories = _sum('calories');
    final protein = _sum('protein');
    final carbs = _sum('carbohydrates');
    final fat = _sum('fat');
    final isSingleDay =
        _period == InsightPeriod.today ||
        (_period == InsightPeriod.custom && _startDate == _endDate);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nutrition insights'),
            Text(
              'Based on consumed meals',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh insights',
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                _syncNotice(),
                const SizedBox(height: 14),
                _periodSelector(),
                const SizedBox(height: 12),
                Text(
                  _period == InsightPeriod.custom
                      ? 'Custom date range'
                      : 'Data range',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _dateSelector(),
                const SizedBox(height: 12),
                if (_logs.isEmpty) _emptyState(),
                if (_logs.isNotEmpty) ...[
                  if (isSingleDay)
                    _todaySummary(calories, protein, carbs, fat)
                  else
                    _periodSummary(days, calories, protein, carbs, fat),
                  const SizedBox(height: 12),
                  _nutritionBreakdown(
                    isSingleDay ? 'Daily nutrition' : 'Daily averages',
                    isSingleDay ? calories : _dailyAverageCalories,
                    isSingleDay ? protein : _average('protein'),
                    isSingleDay ? carbs : _average('carbohydrates'),
                    isSingleDay ? fat : _average('fat'),
                  ),
                ],
                const SizedBox(height: 12),
                _disclaimer(),
              ],
            ),
      bottomNavigationBar: widget.embedded
          ? null
          : BottomNavBar(
              currentIndex: 0,
              onTap:
                  widget.onBottomNavTap ??
                  (_) {
                    Navigator.maybePop(context);
                  },
            ),
    );
  }

  double _average(String key) {
    final days = _dailyTotals;
    if (days.isEmpty) return 0;
    final total = _sum(key);
    return total / days.length;
  }

  Widget _syncNotice() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primaryGreen.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        Icon(Icons.sync, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Text('Your insights update from meals logged as eaten.'),
        ),
      ],
    ),
  );

  Widget _periodSelector() {
    final labels = {
      InsightPeriod.today: 'Today',
      InsightPeriod.week: 'Week',
      InsightPeriod.month: 'Month',
      InsightPeriod.custom: 'Custom',
    };
    return Wrap(
      spacing: 8,
      children: InsightPeriod.values.map((period) {
        final selected = _period == period;
        return ChoiceChip(
          label: Text(labels[period]!),
          selected: selected,
          onSelected: (_) => _changePeriod(period),
          selectedColor: AppColors.accentHeart.withValues(alpha: 0.25),
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.38),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _dateSelector() => InkWell(
    onTap: _selectDate,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_rangeLabel)),
          const Icon(Icons.calendar_month_outlined),
        ],
      ),
    ),
  );

  Widget _todaySummary(
    double calories,
    double protein,
    double carbs,
    double fat,
  ) {
    final total = calories.round();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total kcal',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Consumed today - from logged meals'),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(132, 132),
                      painter: _MacroDonutPainter(
                        proteinCalories: protein * 4,
                        carbsCalories: carbs * 4,
                        fatCalories: fat * 9,
                        proteinColor: _macroColor('Protein'),
                        carbsColor: _macroColor('Carbs'),
                        fatColor: _macroColor('Fat'),
                        trackColor: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.18),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const Text('kcal', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legend('Protein', protein, 'g'),
                    _legend('Carbs', carbs, 'g'),
                    _legend('Fat', fat, 'g'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodSummary(
    List<_DayTotal> days,
    double calories,
    double protein,
    double carbs,
    double fat,
  ) {
    final average = _dailyAverageCalories;
    final title = '${average.round()} kcal / day';
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('${calories.round()} kcal total in selected period'),
          const SizedBox(height: 22),
          SizedBox(
            height: 160,
            child: (_period == InsightPeriod.month || days.length > 14)
                ? _MonthlyLineChart(days: days)
                : _DailyBarChart(days: days),
          ),
          const SizedBox(height: 8),
          Text(
            '${days.length} day(s) in range',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutritionBreakdown(
    String title,
    double calories,
    double protein,
    double carbs,
    double fat,
  ) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title - logged meals',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _metric('Calories', '${calories.round()} kcal'),
            _metric('Protein', '${protein.round()}g'),
            _metric('Carbs', '${carbs.round()}g'),
            _metric('Fat', '${fat.round()}g'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Macro targets are not set. Values are estimates when recipe nutrition is available.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _legend(String label, double value, String unit) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(Icons.circle, size: 9, color: _macroColor(label)),
        const SizedBox(width: 7),
        Expanded(child: Text(label)),
        Text(
          '${value.round()}$unit',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Color _macroColor(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (label) {
      case 'Protein':
        return isDark ? AppColors.darkMacroProtein : AppColors.macroProtein;
      case 'Carbs':
        return isDark ? AppColors.darkMacroCarbs : AppColors.macroCarbs;
      case 'Fat':
        return isDark ? AppColors.darkMacroFat : AppColors.macroFat;
      case 'Calories':
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  Widget _metric(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: _macroColor(label))),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _macroColor(label),
          ),
        ),
      ],
    ),
  );

  Widget _disclaimer() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primaryGreen.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Only meals marked "Log as eaten" are included. Favorites and planned meals are excluded. Missing nutrition values are not counted.',
          ),
        ),
      ],
    ),
  );

  Widget _emptyState() => _card(
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: 42,
            color: AppColors.primaryGreen,
          ),
          SizedBox(height: 12),
          Text(
            'No meals logged for this period',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          SizedBox(height: 6),
          Text(
            'Use "Log as eaten" on a recipe to see its nutrition here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load nutrition insights.'),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadLogs, child: const Text('Try again')),
        ],
      ),
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class _DayTotal {
  _DayTotal(this.date);
  final DateTime date;
  double calories = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
}

class _MacroDonutPainter extends CustomPainter {
  const _MacroDonutPainter({
    required this.proteinCalories,
    required this.carbsCalories,
    required this.fatCalories,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
    required this.trackColor,
  });

  final double proteinCalories;
  final double carbsCalories;
  final double fatCalories;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final total = proteinCalories + carbsCalories + fatCalories;
    if (total <= 0) return;

    final segments = <(double, Color)>[
      (proteinCalories, proteinColor),
      (carbsCalories, carbsColor),
      (fatCalories, fatColor),
    ];
    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      if (segment.$1 <= 0) continue;
      final sweepAngle = (segment.$1 / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) =>
      oldDelegate.proteinCalories != proteinCalories ||
      oldDelegate.carbsCalories != carbsCalories ||
      oldDelegate.fatCalories != fatCalories ||
      oldDelegate.proteinColor != proteinColor ||
      oldDelegate.carbsColor != carbsColor ||
      oldDelegate.fatColor != fatColor ||
      oldDelegate.trackColor != trackColor;
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.days});
  final List<_DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<double>(
      1,
      (m, d) => d.calories > m ? d.calories : m,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((day) {
        final height = 92 * day.calories / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height.clamp(4, 92),
                  decoration: BoxDecoration(
                    color: day.calories == 0
                        ? Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  DateFormat('E').format(day.date).substring(0, 1),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MonthlyLineChart extends StatelessWidget {
  const _MonthlyLineChart({required this.days});
  final List<_DayTotal> days;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LineChartPainter(days, Theme.of(context).colorScheme.primary),
    child: const SizedBox.expand(),
  );
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.days, this.color);
  final List<_DayTotal> days;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final maxValue = days.fold<double>(
      1,
      (m, d) => d.calories > m ? d.calories : m,
    );
    final path = Path();
    for (var i = 0; i < days.length; i++) {
      final x = days.length == 1
          ? size.width / 2
          : size.width * i / (days.length - 1);
      final y =
          size.height - (days[i].calories / maxValue) * (size.height - 18) - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.color != color;
}