import 'package:flutter/material.dart';

import 'dialogs.dart';
import 'models.dart';

class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key, required this.data, required this.onChanged});

  final AppData data;
  final VoidCallback onChanged;

  void _open(BuildContext context, Routine routine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineEditPage(
          data: data,
          routine: routine,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final name =
        await showTextInput(context, title: '루틴 만들기', hint: '예: 등+가슴');
    if (name == null || name.trim().isEmpty) return;
    final routine = Routine(id: newId(), name: name.trim());
    data.routines.add(routine);
    onChanged();
    if (context.mounted) _open(context, routine);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: data.routines.isEmpty
              ? const Center(child: Text('아래 버튼으로 루틴을 만드세요'))
              : ListView.separated(
                  itemCount: data.routines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final routine = data.routines[i];
                    return ListTile(
                      title: Text(routine.name),
                      subtitle: Text('${routine.exerciseIds.length}종목'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(context, routine),
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
              label: const Text('루틴 만들기'),
            ),
          ),
        ),
      ],
    );
  }
}

class RoutineEditPage extends StatefulWidget {
  const RoutineEditPage({
    super.key,
    required this.data,
    required this.routine,
    required this.onChanged,
  });

  final AppData data;
  final Routine routine;
  final VoidCallback onChanged;

  @override
  State<RoutineEditPage> createState() => _RoutineEditPageState();
}

class _RoutineEditPageState extends State<RoutineEditPage> {
  late final _name = TextEditingController(text: widget.routine.name);

  List<String> get _ids => widget.routine.exerciseIds;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  String _exerciseName(String id) {
    for (final e in widget.data.exercises) {
      if (e.id == id) return e.name;
    }
    return '삭제된 종목';
  }

  void _reorder(int oldIndex, int newIndex) {
    _ids.insert(newIndex, _ids.removeAt(oldIndex));
    _changed();
  }

  Future<void> _pickExercises() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final exercises = widget.data.exercises;
          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (exercises.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '종목 탭에서 종목을 먼저 추가하세요',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in exercises)
                          CheckboxListTile(
                            title: Text(e.name),
                            value: _ids.contains(e.id),
                            onChanged: (checked) {
                              if (checked == true) {
                                _ids.add(e.id);
                              } else {
                                _ids.remove(e.id);
                              }
                              setSheetState(() {});
                              _changed();
                            },
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('완료'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showConfirm(
      context,
      title: "'${widget.routine.name}' 삭제",
      message: '루틴만 지워지고 지난 운동 기록은 남습니다. 삭제할까요?',
      okLabel: '삭제',
      destructive: true,
    );
    if (!ok) return;
    widget.data.routines.remove(widget.routine);
    widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('루틴 편집')),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '루틴 이름'),
                onChanged: (value) {
                  if (value.trim().isEmpty) return;
                  widget.routine.name = value.trim();
                  widget.onChanged();
                },
              ),
            ),
            Expanded(
              child: _ids.isEmpty
                  ? const Center(child: Text('아래 버튼으로 종목을 넣으세요'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: _ids.length,
                      onReorderItem: _reorder,
                      itemBuilder: (context, i) {
                        final id = _ids[i];
                        return ListTile(
                          key: ValueKey(id),
                          contentPadding:
                              const EdgeInsets.only(left: 4, right: 8),
                          leading: ReorderableDragStartListener(
                            index: i,
                            child: const SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(Icons.drag_handle, size: 30),
                            ),
                          ),
                          title: Text('${i + 1}. ${_exerciseName(id)}'),
                          trailing: IconButton(
                            tooltip: '루틴에서 빼기',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _ids.removeAt(i);
                              _changed();
                            },
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                onPressed: _pickExercises,
                icon: const Icon(Icons.add),
                label: const Text('종목 넣기'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _delete,
                child: const Text('루틴 삭제'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
