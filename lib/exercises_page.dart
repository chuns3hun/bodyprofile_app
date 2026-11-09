import 'package:flutter/material.dart';

import 'dialogs.dart';
import 'history_page.dart';
import 'models.dart';

/// 부위별로 묶고, 부위 안에서는 이름순 (저장 순서는 그대로)
List<(String, List<Exercise>)> groupedExercises(Iterable<Exercise> exercises) {
  final sorted = [...exercises]
    ..sort((a, b) {
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.detail.compareTo(b.detail);
    });
  return [
    for (final part in [...bodyPartLabels.keys, null])
      (
        bodyPartLabels[part] ?? '부위 미지정',
        sorted.where((e) => e.bodyPart == part).toList(),
      ),
  ].where((g) => g.$2.isNotEmpty).toList();
}

Widget partHeader(BuildContext context, String label) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
  child: Text(
    label,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
    ),
  ),
);

Future<Exercise?> createExercise(
  BuildContext context,
  AppData data, {
  Exercise? copyFrom,
}) async {
  final exercise = Exercise(
    id: newId(),
    name: copyFrom?.name ?? '',
    bodyPart: copyFrom?.bodyPart,
    equipment: copyFrom?.equipment,
    brand: copyFrom?.brand ?? '',
  );
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => ExerciseEditPage(
        data: data,
        exercise: exercise,
        title: copyFrom == null ? '종목 추가' : '다른 기구로 추가',
      ),
    ),
  );
  if (ok != true) return null;
  data.exercises.add(exercise);
  return exercise;
}

class ExercisesPage extends StatelessWidget {
  const ExercisesPage({super.key, required this.data, required this.onChanged});

  final AppData data;
  final VoidCallback onChanged;

  Future<void> _add(BuildContext context, {Exercise? copyFrom}) async {
    final exercise = await createExercise(context, data, copyFrom: copyFrom);
    if (exercise != null) onChanged();
  }

  Future<void> _edit(BuildContext context, Exercise exercise) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExerciseEditPage(data: data, exercise: exercise, title: '종목 수정'),
      ),
    );
    if (ok == true) onChanged();
  }

  Future<void> _delete(BuildContext context, Exercise exercise) async {
    var setCount = 0;
    for (final w in data.workouts) {
      setCount += w.sets.where((s) => s.exerciseId == exercise.id).length;
    }
    final message = setCount > 0
        ? '이 종목에 세트 기록이 $setCount개 있습니다.\n'
              '종목을 지워도 지난 기록은 남고, 루틴에서는 빠집니다.\n삭제할까요?'
        : '루틴에서도 빠집니다. 삭제할까요?';
    final ok = await showConfirm(
      context,
      title: "'${exercise.name}' 삭제",
      message: message,
      okLabel: '삭제',
      destructive: true,
    );
    if (!ok) return;

    data.exercises.remove(exercise);
    for (final r in data.routines) {
      r.exerciseIds.remove(exercise.id);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupedExercises(data.exercises);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('아래 버튼으로 종목을 추가하세요'))
              : ListView(
                  children: [
                    for (final (label, exercises) in groups) ...[
                      partHeader(context, label),
                      for (final exercise in exercises)
                        _tile(context, exercise),
                    ],
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: const Text('종목 추가'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, Exercise exercise) {
    return ListTile(
      title: Text(exercise.name),
      subtitle: Text(exercise.detail.isEmpty ? '기구 미지정' : exercise.detail),
      onTap: () => _edit(context, exercise),
      trailing: PopupMenuButton<String>(
        iconSize: 28,
        onSelected: (value) {
          switch (value) {
            case 'history':
              openExerciseHistory(context, data, exercise.id);
            case 'copy':
              _add(context, copyFrom: exercise);
            case 'delete':
              _delete(context, exercise);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'history', child: Text('기록 보기')),
          PopupMenuItem(value: 'copy', child: Text('다른 기구로 복사')),
          PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    );
  }
}

/// [exercise]를 직접 고치고, 저장하면 true를 돌려준다.
class ExerciseEditPage extends StatefulWidget {
  const ExerciseEditPage({
    super.key,
    required this.data,
    required this.exercise,
    required this.title,
  });

  final AppData data;
  final Exercise exercise;
  final String title;

  @override
  State<ExerciseEditPage> createState() => _ExerciseEditPageState();
}

class _ExerciseEditPageState extends State<ExerciseEditPage> {
  late final _name = TextEditingController(text: widget.exercise.name);
  late final _brand = TextEditingController(text: widget.exercise.brand);
  late final _memo = TextEditingController(text: widget.exercise.memo);
  late String? _equipment = widget.exercise.equipment;
  late String? _bodyPart = widget.exercise.bodyPart;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _memo.dispose();
    super.dispose();
  }

  // 최근에 입력한 회사 이름, 중복 없이 최대 8개
  List<String> get _recentBrands {
    final brands = <String>[];
    for (final e in widget.data.exercises.reversed) {
      if (e.brand.isNotEmpty && !brands.contains(e.brand)) brands.add(e.brand);
    }
    return brands.take(8).toList();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, '종목 이름을 입력하세요.');
      return;
    }
    widget.exercise
      ..name = name
      ..bodyPart = _bodyPart
      ..equipment = _equipment
      ..brand = _brand.text.trim()
      ..memo = _memo.text.trim();
    Navigator.pop(context, true);
  }

  // 하나만 고르는 버튼 묶음. 선택된 것을 다시 누르면 해제.
  Widget _chips(
    Map<String, String> labels,
    String? value,
    void Function(String?) onChanged,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in labels.entries)
          ChoiceChip(
            label: Text(entry.value),
            labelStyle: TextStyle(
              fontSize: 16,
              fontWeight: value == entry.key ? FontWeight.w700 : null,
              color: value == entry.key ? Colors.black : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            selected: value == entry.key,
            onSelected: (_) => setState(
              () => onChanged(value == entry.key ? null : entry.key),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brands = _recentBrands;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: '종목 이름',
                      hintText: '예: 핵스쿼트',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('부위', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _chips(bodyPartLabels, _bodyPart, (v) => _bodyPart = v),
                  const SizedBox(height: 20),
                  Text('기구', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _chips(equipmentLabels, _equipment, (v) => _equipment = v),
                  if (_equipment == 'assist')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '어시스트는 보조 무게가 낮을수록 어려워서, '
                        '가장 낮은 무게를 최고 기록으로 보여 줍니다.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _brand,
                    decoration: const InputDecoration(
                      labelText: '회사 (선택)',
                      hintText: '예: 해머스트렝스',
                    ),
                  ),
                  if (brands.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final b in brands)
                          ActionChip(
                            label: Text(b),
                            onPressed: () => setState(() => _brand.text = b),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: _memo,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '메모 (선택)',
                      hintText: '예: 시트 3번, 등받이 2칸',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(onPressed: _save, child: const Text('저장')),
            ),
          ],
        ),
      ),
    );
  }
}
