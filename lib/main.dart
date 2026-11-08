import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '운동 기록',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Storage.load();
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = '저장된 데이터를 읽지 못했습니다.\n$e');
    }
  }

  Future<void> _save() => Storage.save(_data!);

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addExercise() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          const _TextInputDialog(title: '종목 추가', hint: '예: 벤치프레스'),
    );
    if (name == null || name.trim().isEmpty) return;

    setState(() {
      _data!.exercises.add(Exercise(id: newId(), name: name.trim()));
    });
    await _save();
  }

  Future<void> _copyBackup() async {
    await Clipboard.setData(ClipboardData(text: Storage.encode(_data!)));
    if (!mounted) return;
    _showMessage('백업 내용을 복사했습니다. 메모 앱 등에 붙여넣어 보관하세요.');
  }

  Future<void> _restoreBackup() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _TextInputDialog(
        title: '백업 불러오기',
        hint: '복사해 둔 백업 내용을 붙여넣으세요',
        multiline: true,
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    AppData restored;
    try {
      restored = Storage.decode(text.trim());
    } catch (_) {
      if (!mounted) return;
      _showMessage('백업 형식이 올바르지 않습니다.');
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('백업 불러오기'),
        content: const Text('지금 기록이 백업 내용으로 바뀝니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('불러오기'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _data = restored);
    await _save();
    if (!mounted) return;
    _showMessage('백업을 불러왔습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    Widget body;
    if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    } else if (data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (data.exercises.isEmpty) {
      body = const Center(child: Text('+ 버튼으로 종목을 추가하세요'));
    } else {
      body = ListView.builder(
        itemCount: data.exercises.length,
        itemBuilder: (context, i) =>
            ListTile(title: Text(data.exercises[i].name)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('종목'),
        actions: [
          PopupMenuButton<String>(
            enabled: data != null,
            onSelected: (value) =>
                value == 'export' ? _copyBackup() : _restoreBackup(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('백업 복사')),
              PopupMenuItem(value: 'import', child: Text('백업 불러오기')),
            ],
          ),
        ],
      ),
      body: body,
      floatingActionButton: data == null
          ? null
          : FloatingActionButton(
              onPressed: _addExercise,
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    this.multiline = false,
  });

  final String title;
  final String hint;
  final bool multiline;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: widget.multiline ? 4 : 1,
        maxLines: widget.multiline ? 8 : 1,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
