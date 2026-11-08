import 'package:flutter/material.dart';

import 'dialogs.dart';
import 'models.dart';

class ExercisesPage extends StatelessWidget {
  const ExercisesPage({super.key, required this.data, required this.onChanged});

  final AppData data;
  final VoidCallback onChanged;

  Future<void> _add(BuildContext context) async {
    final name =
        await showTextInput(context, title: '종목 추가', hint: '예: 벤치프레스');
    if (name == null || name.trim().isEmpty) return;
    data.exercises.add(Exercise(id: newId(), name: name.trim()));
    onChanged();
  }

  Future<void> _rename(BuildContext context, Exercise exercise) async {
    final name = await showTextInput(
      context,
      title: '이름 수정',
      hint: '종목 이름',
      initial: exercise.name,
    );
    if (name == null || name.trim().isEmpty) return;
    exercise.name = name.trim();
    onChanged();
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
    return Column(
      children: [
        Expanded(
          child: data.exercises.isEmpty
              ? const Center(child: Text('아래 버튼으로 종목을 추가하세요'))
              : ListView.separated(
                  itemCount: data.exercises.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final exercise = data.exercises[i];
                    return ListTile(
                      title: Text(exercise.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '이름 수정',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _rename(context, exercise),
                          ),
                          IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, exercise),
                          ),
                        ],
                      ),
                    );
                  },
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
}
