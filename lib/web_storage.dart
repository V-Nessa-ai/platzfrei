// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:gotrue/gotrue.dart';

class WebLocalStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async {
    return html.window.localStorage[key];
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    html.window.localStorage[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    html.window.localStorage.remove(key);
  }
}
