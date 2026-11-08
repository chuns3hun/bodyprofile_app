import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dialogs.dart';
import 'models.dart';
import 'storage.dart';

String formatWeight(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toString();

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

  WorkoutLog? _previousLog(String exerciseId) {
    WorkoutLog? best;
    for (final w in widget.data.workouts) {
      if (w.date.compareTo(_today) >= 0) continue;
      if (!w.sets.any((s) => s.exerciseId == exerciseId)) continue;
      if (best == null || w.date.compareTo(best.date) >= 0) best = w;
    }
    return best;
  }

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
      _routineId = picked;
      _dirty = false;
      for (final s in _todayLog(picked)?.sets ?? <SetRecord>[]) {
        _rows
            .putIfAbsent(s.exerciseId, () => [])
            .add(_SetRow(weight: formatWeight(s.weight), reps: '${s.reps}'));
      }
    });
    _saveDraft();
  }

  void _addSet(String exerciseId) {
    final rows = _rows.putIfAbsent(exerciseId, () => []);
    var weight = '';
    var reps = '';
    if (rows.isNotEmpty) {
      weight = rows.last.weight.text;
      reps = rows.last.reps.text;
    } else {
      final prev = _previousLog(exerciseId)?.sets
          .where((s) => s.exerciseId == exerciseId)
          .firstOrNull;
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
    for (final id in routine.exerciseIds) {
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

  String _exerciseName(String id) {
    for (final e in widget.data.exercises) {
      if (e.id == id) return e.name;
    }
    return '삭제된 종목';
  }

  String _previousText(String exerciseId) {
    final log = _previousLog(exerciseId);
    if (log == null) return '직전 기록 없음';
    final parts = log.date.split('-');
    final sets = log.sets
        .where((s) => s.exerciseId == exerciseId)
        .map((s) => '${formatWeight(s.weight)}×${s.reps}')
        .join(', ');
    return '직전(${int.parse(parts[1])}/${int.parse(parts[2])}): $sets';
  }

  @override
  Widget build(BuildContext context) {
    final routine = _routine;
    final theme = Theme.of(context);

    Widget content;
    if (routine == null) {
      content = const Center(child: Text('위에서 오늘 할 루틴을 고르세요'));
    } else if (routine.exerciseIds.isEmpty) {
      content = const Center(child: Text('루틴 탭에서 이 루틴에 종목을 넣으세요'));
    } else {
      content = ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          for (final id in routine.exerciseIds) _exerciseCard(id, theme),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton(
            onPressed: _chooseRoutine,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    routine == null ? '루틴 선택' : '루틴: ${routine.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 30),
              ],
            ),
          ),
        ),
        Expanded(child: content),
        // 키보드가 떠 있을 때는 입력 칸이 보이도록 저장 버튼을 숨긴다.
        if (routine != null && !widget.keyboardOpen)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(onPressed: _save, child: const Text('저장')),
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

  Widget _exerciseCard(String id, ThemeData theme) {
    final rows = _rows[id] ?? [];
    final collapsed = _collapsed.contains(id);
    final subStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final header = InkWell(
      onTap: () => _toggle(id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_exerciseName(id), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    collapsed ? _summary(rows) : _previousText(id),
                    style: subStyle,
                  ),
                ],
              ),
            ),
            Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 32),
          ],
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, if (!collapsed) _setInputs(id, rows)],
      ),
    );
  }

  Widget _setInputs(String id, List<_SetRow> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 52, child: Text('${i + 1}세트')),
                  Expanded(
                    child: _numberField(
                      rows[i].weight,
                      suffix: 'kg',
                      decimal: true,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('×'),
                  ),
                  Expanded(child: _numberField(rows[i].reps, suffix: '회')),
                  IconButton(
                    tooltip: '세트 삭제',
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeSet(id, i),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: OutlinedButton.icon(
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
      style: const TextStyle(fontSize: 20),
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
