import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dialogs.dart';
import 'exercises_page.dart';
import 'history_page.dart';
import 'models.dart';
import 'storage.dart';

class _SetRow {
  _SetRow({String weight = '', String reps = ''})
    : weight = TextEditingController(text: weight),
      reps = TextEditingController(text: reps);

  final TextEditingController weight;
  final TextEditingController reps;

  bool get isEmpty => weight.text.trim().isEmpty && reps.text.trim().isEmpty;

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({
    super.key,
    required this.data,
    required this.onChanged,
    required this.keyboardOpen,
  });

  final AppData data;
  final VoidCallback onChanged;
  final bool keyboardOpen;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  String? _routineId;
  final Map<String, List<_SetRow>> _rows = {};
  final Set<String> _collapsed = {};
  // 루틴에 없지만 오늘만 추가한 종목
  final List<String> _extraIds = [];
  bool _dirty = false;

  String get _today => dateKey(DateTime.now());

  Routine? get _routine {
    for (final r in widget.data.routines) {
      if (r.id == _routineId) return r;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void dispose() {
    _clearRows();
    super.dispose();
  }

  void _clearRows() {
    for (final rows in _rows.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    _rows.clear();
  }

  Future<void> _restoreDraft() async {
    final draft = await Storage.loadDraft();
    if (!mounted || draft == null || _routineId != null) return;
    if (draft['date'] != _today) return;
    setState(() {
      _routineId = draft['routineId'] as String?;
      _dirty = draft['dirty'] == true;
      _collapsed.addAll(List<String>.from(draft['collapsed'] as List? ?? []));
      _extraIds.addAll(List<String>.from(draft['extraIds'] as List? ?? []));
      for (final s in draft['sets'] as List? ?? []) {
        final m = s as Map<String, dynamic>;
        _rows
            .putIfAbsent(m['exerciseId'] as String, () => [])
            .add(
              _SetRow(weight: m['weight'] as String, reps: m['reps'] as String),
            );
      }
    });
  }

  void _saveDraft() {
    Storage.saveDraft({
      'date': _today,
      'routineId': _routineId,
      'dirty': _dirty,
      'collapsed': _collapsed.toList(),
      'extraIds': _extraIds,
      'sets': [
        for (final entry in _rows.entries)
          for (final row in entry.value)
            {
              'exerciseId': entry.key,
              'weight': row.weight.text,
              'reps': row.reps.text,
            },
      ],
    });
  }

  void _inputChanged() {
    _dirty = true;
    _saveDraft();
  }

  WorkoutLog? _todayLog(String routineId) {
    for (final w in widget.data.workouts) {
      if (w.date == _today && w.routineId == routineId) return w;
    }
    return null;
  }

  List<Session> _pastSessions(String exerciseId) =>
      exerciseSessions(widget.data, exerciseId, before: _today);

  Future<void> _chooseRoutine() async {
    final routines = widget.data.routines;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: routines.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('루틴 탭에서 루틴을 먼저 만드세요', textAlign: TextAlign.center),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final r in routines)
                    ListTile(
                      title: Text(r.name),
                      subtitle: Text('${r.exerciseIds.length}종목'),
                      selected: r.id == _routineId,
                      onTap: () => Navigator.pop(context, r.id),
                    ),
                ],
              ),
      ),
    );
    if (picked == null || picked == _routineId || !mounted) return;

    final hasInput = _rows.values.any((rows) => rows.any((r) => !r.isEmpty));
    if (_dirty && hasInput) {
      final ok = await showConfirm(
        context,
        title: '루틴 바꾸기',
        message: '저장하지 않은 입력이 사라집니다. 루틴을 바꿀까요?',
        okLabel: '바꾸기',
      );
      if (!ok) return;
    }

    setState(() {
      _clearRows();
      _collapsed.clear();
      _extraIds.clear();
      _routineId = picked;
      _dirty = false;
      final routineIds = _routine?.exerciseIds ?? [];
      for (final s in _todayLog(picked)?.sets ?? <SetRecord>[]) {
        if (!routineIds.contains(s.exerciseId) &&
            !_extraIds.contains(s.exerciseId)) {
          _extraIds.add(s.exerciseId);
        }
        _rows
            .putIfAbsent(s.exerciseId, () => [])
            .add(_SetRow(weight: formatWeight(s.weight), reps: '${s.reps}'));
      }
    });
    _saveDraft();
  }

  List<String> get _exerciseIds {
    final routineIds = _routine?.exerciseIds ?? [];
    return [
      ...routineIds,
      ..._extraIds.where((id) => !routineIds.contains(id)),
    ];
  }

  Future<void> _addExtra() async {
    final routine = _routine;
    if (routine == null) return;
    final current = _exerciseIds;
    var addToRoutine = false;

    // 고른 종목 id, 새로 만들기는 ''
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final groups = groupedExercises(
            widget.data.exercises.where((e) => !current.contains(e.id)),
          );
          return SafeArea(
            top: false,
            child: ListView(
              shrinkWrap: true,
              children: [
                SwitchListTile(
                  title: Text("'${routine.name}' 루틴에도 넣기"),
                  subtitle: const Text('끄면 오늘 기록에만 들어갑니다'),
                  value: addToRoutine,
                  onChanged: (v) => setSheetState(() => addToRoutine = v),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('새 종목 만들기'),
                  onTap: () => Navigator.pop(context, ''),
                ),
                for (final (label, exercises) in groups) ...[
                  partHeader(context, label),
                  for (final e in exercises)
                    ListTile(
                      title: Text(e.name),
                      subtitle: e.detail.isEmpty ? null : Text(e.detail),
                      onTap: () => Navigator.pop(context, e.id),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
    if (picked == null || !mounted) return;

    var id = picked;
    if (id.isEmpty) {
      final created = await createExercise(context, widget.data);
      if (created == null || !mounted) return;
      id = created.id;
    }

    setState(() {
      if (addToRoutine) {
        routine.exerciseIds.add(id);
      } else {
        _extraIds.add(id);
      }
      _collapsed.remove(id);
    });
    widget.onChanged();
    _saveDraft();
  }

  Future<void> _removeExtra(String id) async {
    final rows = _rows[id] ?? [];
    if (rows.any((r) => !r.isEmpty)) {
      final ok = await showConfirm(
        context,
        title: '오늘 목록에서 빼기',
        message: '${_exerciseName(id)}에 입력한 세트가 사라집니다. 뺄까요?',
        okLabel: '빼기',
      );
      if (!ok) return;
    }
    setState(() {
      _extraIds.remove(id);
      for (final r in _rows.remove(id) ?? <_SetRow>[]) {
        r.dispose();
      }
    });
    _inputChanged();
  }

  void _addSet(String exerciseId) {
    final rows = _rows.putIfAbsent(exerciseId, () => []);
    var weight = '';
    var reps = '';
    if (rows.isNotEmpty) {
      weight = rows.last.weight.text;
      reps = rows.last.reps.text;
    } else {
      final prev = _pastSessions(exerciseId).firstOrNull?.sets.first;
      if (prev != null) {
        weight = formatWeight(prev.weight);
        reps = '${prev.reps}';
      }
    }
    setState(() => rows.add(_SetRow(weight: weight, reps: reps)));
    _inputChanged();
  }

  void _removeSet(String exerciseId, int index) {
    setState(() => _rows[exerciseId]!.removeAt(index).dispose());
    _inputChanged();
  }

  Future<void> _save() async {
    final routine = _routine;
    if (routine == null) return;

    final records = <SetRecord>[];
    for (final id in _exerciseIds) {
      final rows = _rows[id] ?? [];
      for (var i = 0; i < rows.length; i++) {
        if (rows[i].isEmpty) continue;
        final weight = double.tryParse(
          rows[i].weight.text.trim().replaceAll(',', '.'),
        );
        final reps = int.tryParse(rows[i].reps.text.trim());
        if (weight == null || weight < 0 || reps == null || reps <= 0) {
          showMessage(
            context,
            '${_exerciseName(id)} ${i + 1}세트의 무게나 횟수를 확인하세요.',
          );
          return;
        }
        records.add(SetRecord(exerciseId: id, weight: weight, reps: reps));
      }
    }

    final existing = _todayLog(routine.id);
    if (records.isEmpty && existing == null) {
      showMessage(context, '입력한 세트가 없습니다.');
      return;
    }

    if (records.isEmpty) {
      final ok = await showConfirm(
        context,
        title: '오늘 기록 삭제',
        message: '입력한 세트가 없어서 오늘 저장한 ${routine.name} 기록이 지워집니다. 계속할까요?',
        okLabel: '삭제',
        destructive: true,
      );
      if (!ok || !mounted) return;
      widget.data.workouts.remove(existing);
    } else if (existing != null) {
      existing.sets = records;
    } else {
      widget.data.workouts.add(
        WorkoutLog(
          id: newId(),
          date: _today,
          routineId: routine.id,
          sets: records,
        ),
      );
    }
    widget.onChanged();
    _dirty = false;
    _saveDraft();
    FocusScope.of(context).unfocus();
    showMessage(context, records.isEmpty ? '오늘 기록을 지웠습니다.' : '저장했습니다.');
  }

  String _exerciseName(String id) =>
      findExercise(widget.data, id)?.name ?? '삭제된 종목';

  @override
  Widget build(BuildContext context) {
    final routine = _routine;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final dateText =
        '${now.month}월 ${now.day}일 ${'월화수목금토일'[now.weekday - 1]}요일';

    final ids = _exerciseIds;
    final doneCount = ids
        .where((id) => (_rows[id] ?? []).any((r) => !r.isEmpty))
        .length;
    final setCount = ids.fold(
      0,
      (sum, id) => sum + (_rows[id] ?? []).where((r) => !r.isEmpty).length,
    );

    Widget content;
    if (routine == null) {
      content = Center(
        child: Text(
          '위에서 오늘 할 루틴을 고르세요',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      content = ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (ids.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                '이 루틴에 종목이 없습니다',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (var i = 0; i < ids.length; i++) _exerciseCard(ids[i], i, theme),
          TextButton.icon(
            onPressed: _addExtra,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('오늘 종목 추가'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(dateText, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Material(
                color: scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _chooseRoutine,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '오늘의 루틴',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                routine?.name ?? '루틴 선택',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (routine != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '$doneCount/${ids.length} 종목 · $setCount세트',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.unfold_more,
                          color: scheme.onSurfaceVariant,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: content),
        // 키보드가 떠 있을 때는 입력 칸이 보이도록 저장 버튼을 숨긴다.
        if (routine != null && !widget.keyboardOpen)
          Container(
            decoration: BoxDecoration(
              color: theme.navigationBarTheme.backgroundColor,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('운동 저장'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _toggle(String id) {
    FocusScope.of(context).unfocus();
    setState(() {
      if (!_collapsed.remove(id)) _collapsed.add(id);
    });
    _saveDraft();
  }

  String _summary(List<_SetRow> rows) {
    final filled = rows.where((r) => !r.isEmpty).toList();
    if (filled.isEmpty) return '입력한 세트 없음';
    final sets = filled
        .map((r) => '${r.weight.text}×${r.reps.text}')
        .join(', ');
    return '${filled.length}세트 · $sets';
  }

  Widget _exerciseCard(String id, int index, ThemeData theme) {
    final scheme = theme.colorScheme;
    final rows = _rows[id] ?? [];
    final collapsed = _collapsed.contains(id);
    final done = rows.any((r) => !r.isEmpty);
    final detail = findExercise(widget.data, id)?.detail ?? '';
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);

    final header = InkWell(
      onTap: () => _toggle(id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Row(
          children: [
            // 세트를 하나라도 입력하면 체크 표시
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? scheme.primary : Colors.transparent,
                border: done ? null : Border.all(color: scheme.outline),
              ),
              child: done
                  ? const Icon(Icons.check, size: 18, color: Colors.black)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _exerciseName(id),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_extraIds.contains(id)) ...[
                        const SizedBox(width: 8),
                        _pill('오늘만', scheme),
                      ],
                    ],
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(detail, style: muted),
                  ],
                  if (collapsed) ...[
                    const SizedBox(height: 4),
                    Text(
                      _summary(rows),
                      style: muted.copyWith(
                        color: done ? scheme.onSurface : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_extraIds.contains(id))
              IconButton(
                tooltip: '오늘 목록에서 빼기',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeExtra(id),
              ),
            Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 28,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (!collapsed) _historyBox(id, theme),
          if (!collapsed) _setInputs(id, rows, theme),
        ],
      ),
    );
  }

  Widget _pill(String text, ColorScheme scheme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
    ),
  );

  // 메모, 최고 기록, 최근 3회 기록
  Widget _historyBox(String id, ThemeData theme) {
    final scheme = theme.colorScheme;
    final exercise = findExercise(widget.data, id);
    final lowerIsHarder = exercise?.lowerIsHarder ?? false;
    final sessions = _pastSessions(id);
    final best = bestSet(sessions, lowerIsHarder);
    final muted = TextStyle(fontSize: 14, color: scheme.onSurfaceVariant);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exercise != null && exercise.memo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(exercise.memo, style: muted)),
                ],
              ),
            ),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('첫 기록이에요', style: muted),
            )
          else ...[
            if (best != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${formatWeight(best.set.weight)}kg × ${best.set.reps}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lowerIsHarder
                          ? '최소 보조 · ${shortDate(best.date)}'
                          : '최고 · ${shortDate(best.date)}',
                      style: muted.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            for (final s in sessions.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(shortDate(s.date), style: muted),
                    ),
                    Expanded(
                      child: Text(
                        formatSets(s.sets),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => openExerciseHistory(context, widget.data, id),
                child: const Text('그래프·전체 기록 >'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _setInputs(String id, List<_SetRow> rows, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _numberField(
                      rows[i].weight,
                      suffix: 'kg',
                      decimal: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '×',
                      style: TextStyle(
                        fontSize: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: _numberField(rows[i].reps, suffix: '회')),
                  IconButton(
                    tooltip: '세트 삭제',
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    onPressed: () => _removeSet(id, i),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 50),
                foregroundColor: scheme.primary,
                backgroundColor: Colors.transparent,
                side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
              ),
              onPressed: () => _addSet(id),
              icon: const Icon(Icons.add),
              label: const Text('세트 추가'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller, {
    required String suffix,
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      // decimal이면 아이폰에서 소수점 키패드가 뜬다.
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
      ],
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      decoration: InputDecoration(
        suffixText: suffix,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      ),
      onChanged: (_) => _inputChanged(),
    );
  }
}
