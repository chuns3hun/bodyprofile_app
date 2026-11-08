import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class Storage {
  static const _key = 'app_data';
  static const _draftKey = 'workout_draft';

  static Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppData();
    return decode(raw);
  }

  static Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encode(data));
  }

  static String encode(AppData data) => jsonEncode(data.toJson());

  static AppData decode(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> || json['version'] == null) {
      throw const FormatException('백업 형식이 아닙니다');
    }
    return AppData.fromJson(json);
  }

  // 저장 전 '오늘 운동' 입력 임시본. 백업에는 포함하지 않는다.
  static Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDraft(Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft));
  }
}
