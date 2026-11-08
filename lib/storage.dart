import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class Storage {
  static const _key = 'app_data';

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
}
