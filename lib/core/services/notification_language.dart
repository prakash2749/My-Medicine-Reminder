import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

Future<String> notificationLanguage() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final value = preferences.getString('app.language') ?? 'device';
  if (value == 'en' || value == 'hi') return value;
  return PlatformDispatcher.instance.locale.languageCode == 'hi' ? 'hi' : 'en';
}
