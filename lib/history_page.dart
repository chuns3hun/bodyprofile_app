import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

String formatWeight(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toString();

String formatSets(List<SetRecord> sets) =>
    sets.map((s) => '${formatWeight(s.weight)}×${s.reps}').join(', ');

String shortDate(String date, {bool weekday = false}) {
  final d = DateTime.parse(date);
  var text = d.year == DateTime.now().year
      ? '${d.month}/${d.day}'
      : '${d.year}/${d.month}/${d.day}';
  if (weekday) text += ' (${'월화수목금토일'[d.weekday - 1]})';
  return text;
}

Exercise? findExercise(AppData data, String id) {
  for (final e in data.exercises) {
    if (e.id == id) return e;
  }
  return null;
}

class Session {
  Session(this.date, this.sets);
  final String date;
  final List<SetRecord> sets;
}

/// 종목을 한 날의 세트 묶음, 최신순. [before]를 주면 그 날짜 전 기록만.
List<Session> exerciseSessions(
  AppData data,
  String exerciseId, {
  String? before,
}) {
  final logs = <(int, WorkoutLog)>[];
  for (var i = 0; i < data.workouts.length; i++) {
    final w = data.workouts[i];
    if (before != null && w.date.compareTo(before) >= 0) continue;
    if (w.sets.any((s) => s.exerciseId == exerciseId)) logs.add((i, w));
  }
  logs.sort((a, b) {
    final byDate = b.$2.date.compareTo(a.$2.date);
    return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
  });
  return [
    for (final (_, w) in logs)
      Session(w.date, w.sets.where((s) => s.exerciseId == exerciseId).toList()),
  ];
}

/// 가장 무거운 세트(같으면 횟수 많은 것). 어시스트는 가장 가벼운 세트.
({String date, SetRecord set})? bestSet(
  List<Session> sessions,
  bool lowerIsHarder,
) {
  ({String date, SetRecord set})? best;
  for (final session in sessions) {
    for (final s in session.sets) {
      final b = best?.set;
      final better =
          b == null ||
          (lowerIsHarder ? s.weight < b.weight : s.weight > b.weight) ||
          (s.weight == b.weight && s.reps > b.reps);
      if (better) best = (date: session.date, set: s);
    }
  }
  return best;
}

String bestText(({String date, SetRecord set})? best, bool lowerIsHarder) {
  if (best == null) return '';
  final label = lowerIsHarder ? '최고(가장 적은 보조)' : '최고';
  return '$label ${formatWeight(best.set.weight)}×${best.set.reps}'
      ' (${shortDate(best.date)})';
}

void openExerciseHistory(BuildContext context, AppData data, String id) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ExerciseHistoryPage(data: data, exerciseId: id),
    ),
  );
}

class ExerciseHistoryPage extends StatelessWidget {
  const ExerciseHistoryPage({
    super.key,
    required this.data,
    required this.exerciseId,
  });

  final AppData data;
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = findExercise(data, exerciseId);
    final lowerIsHarder = exercise?.lowerIsHarder ?? false;
    final sessions = exerciseSessions(data, exerciseId);
    final best = bestSet(sessions, lowerIsHarder);
    final subStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text(exercise?.name ?? '삭제된 종목')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (exercise != null && exercise.detail.isNotEmpty)
              Text(exercise.detail, style: subStyle),
            if (exercise != null && exercise.memo.isNotEmpty)
              Text('메모: ${exercise.memo}', style: subStyle),
            if (best != null) ...[
              const SizedBox(height: 8),
              Text(
                bestText(best, lowerIsHarder),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (sessions.isNotEmpty)
              ProgressChart(sessions: sessions, lowerIsHarder: lowerIsHarder),
            const SizedBox(height: 12),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('아직 기록이 없습니다', textAlign: TextAlign.center),
              ),
            for (final s in sessions)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    shortDate(s.date, weekday: true),
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  subtitle: Text(
                    formatSets(s.sets),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF4F4F5),
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

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.data});

  final AppData data;

  String _routineName(String? id) {
    for (final r in data.routines) {
      if (r.id == id) return r.name;
    }
    return id == null ? '' : '삭제된 루틴';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs =
        [for (var i = 0; i < data.workouts.length; i++) (i, data.workouts[i])]
          ..sort((a, b) {
            final byDate = b.$2.date.compareTo(a.$2.date);
            return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
          });

    if (logs.isEmpty) {
      return const Center(child: Text('저장된 운동 기록이 없습니다'));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final (_, log) in logs)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    [
                      shortDate(log.date, weekday: true),
                      _routineName(log.routineId),
                    ].where((t) => t.isNotEmpty).join(' · '),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                for (final id in {for (final s in log.sets) s.exerciseId})
                  ListTile(
                    title: Text(findExercise(data, id)?.name ?? '삭제된 종목'),
                    subtitle: Text(
                      formatSets(
                        log.sets.where((s) => s.exerciseId == id).toList(),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openExerciseHistory(context, data, id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 날짜별 최고 무게 또는 총 볼륨 그래프 (오래된 날 → 최근)
class ProgressChart extends StatefulWidget {
  const ProgressChart({
    super.key,
    required this.sessions,
    required this.lowerIsHarder,
  });

  final List<Session> sessions;
  final bool lowerIsHarder;

  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart> {
  bool _volume = false;

  // 같은 날 기록은 하나로 합친다.
  List<(String, double)> get _points {
    final byDate = <String, List<SetRecord>>{};
    for (final s in widget.sessions) {
      byDate.putIfAbsent(s.date, () => []).addAll(s.sets);
    }
    final dates = byDate.keys.toList()..sort();
    return [
      for (final d in dates)
        (
          d,
          _volume
              ? byDate[d]!.fold(0.0, (sum, s) => sum + s.weight * s.reps)
              : byDate[d]!
                    .map((s) => s.weight)
                    .reduce(widget.lowerIsHarder ? math.min : math.max),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = _points;
    final caption = _volume
        ? '날짜별 총 볼륨 (무게×횟수 합, kg)'
        : widget.lowerIsHarder
        ? '날짜별 가장 적은 보조 무게 (kg, 낮을수록 좋음)'
        : '날짜별 최고 무게 (kg)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('최고 무게')),
                ButtonSegment(value: true, label: Text('총 볼륨')),
              ],
              selected: {_volume},
              onSelectionChanged: (v) => setState(() => _volume = v.first),
            ),
            const SizedBox(height: 8),
            Text(caption, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (points.length < 2)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '기록이 2번 이상 쌓이면 그래프가 나옵니다',
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: _ChartPainter(
                    points: points,
                    line: theme.colorScheme.primary,
                    grid: theme.colorScheme.outlineVariant,
                    text: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.line,
    required this.grid,
    required this.text,
  });

  final List<(String, double)> points;
  final Color line;
  final Color grid;
  final TextStyle text;

  TextPainter _label(String s) => TextPainter(
    text: TextSpan(text: s, style: text),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.$2);
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (hi == lo) {
      hi += 1;
      lo = math.max(0, lo - 1);
    }

    const left = 44.0, bottom = 22.0, top = 8.0;
    final w = size.width - left - 8;
    final h = size.height - bottom - top;
    double x(int i) => left + w * i / (points.length - 1);
    double y(double v) => top + h * (1 - (v - lo) / (hi - lo));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [lo, (lo + hi) / 2, hi]) {
      canvas.drawLine(
        Offset(left, y(v)),
        Offset(size.width - 8, y(v)),
        gridPaint,
      );
      final l = _label(formatWeight(double.parse(v.toStringAsFixed(1))));
      l.paint(canvas, Offset(left - l.width - 6, y(v) - l.height / 2));
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(i), y(points[i].$2));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    final area = Path.from(path)
      ..lineTo(x(points.length - 1), top + h)
      ..lineTo(x(0), top + h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(x(i), y(points[i].$2)), 4, dot);
    }

    // 날짜는 처음, 중간, 마지막만
    final idx = {0, (points.length - 1) ~/ 2, points.length - 1};
    for (final i in idx) {
      final l = _label(shortDate(points[i].$1));
      final dx = (x(i) - l.width / 2).clamp(0.0, size.width - l.width);
      l.paint(canvas, Offset(dx, size.height - bottom + 6));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.line != line;
}
