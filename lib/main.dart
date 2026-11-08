import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dialogs.dart';
import 'exercises_page.dart';
import 'models.dart';
import 'routines_page.dart';
import 'storage.dart';
import 'workout_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bigText = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    const bigButton = Size(64, 56);

    return MaterialApp(
      title: '운동 기록',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        // 아이폰에서 누르기 쉽게 버튼과 글자를 키운다.
        textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 18)),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: bigButton, textStyle: bigText),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: bigButton, textStyle: bigText),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
            textStyle: const TextStyle(fontSize: 17),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
              minimumSize: const Size(48, 48), iconSize: 26),
        ),
        listTileTheme: const ListTileThemeData(minTileHeight: 64),
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
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
  static const _titles = ['오늘 운동', '루틴', '종목'];

  AppData? _data;
  String? _error;
  int _tab = 0;

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

  void _changed() {
    setState(() {});
    Storage.save(_data!);
  }

  Future<void> _copyBackup() async {
    await Clipboard.setData(ClipboardData(text: Storage.encode(_data!)));
    if (!mounted) return;
    showMessage(context, '백업 내용을 복사했습니다. 메모 앱 등에 붙여넣어 보관하세요.');
  }

  Future<void> _restoreBackup() async {
    final text = await showTextInput(
      context,
      title: '백업 불러오기',
      hint: '복사해 둔 백업 내용을 붙여넣으세요',
      multiline: true,
    );
    if (text == null || text.trim().isEmpty) return;

    AppData restored;
    try {
      restored = Storage.decode(text.trim());
    } catch (_) {
      if (!mounted) return;
      showMessage(context, '백업 형식이 올바르지 않습니다.');
      return;
    }

    if (!mounted) return;
    final ok = await showConfirm(
      context,
      title: '백업 불러오기',
      message: '지금 기록이 백업 내용으로 바뀝니다. 계속할까요?',
      okLabel: '불러오기',
    );
    if (!ok) return;

    setState(() => _data = restored);
    await Storage.save(restored);
    if (!mounted) return;
    showMessage(context, '백업을 불러왔습니다.');
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
    } else {
      body = IndexedStack(
        index: _tab,
        children: [
          WorkoutPage(
            data: data,
            onChanged: _changed,
            keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
          ),
          RoutinesPage(data: data, onChanged: _changed),
          ExercisesPage(data: data, onChanged: _changed),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
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
      bottomNavigationBar: data == null
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) {
                FocusScope.of(context).unfocus();
                setState(() => _tab = i);
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.fitness_center), label: '오늘 운동'),
                NavigationDestination(
                    icon: Icon(Icons.playlist_add_check), label: '루틴'),
                NavigationDestination(
                    icon: Icon(Icons.format_list_bulleted), label: '종목'),
              ],
            ),
    );
  }
}
