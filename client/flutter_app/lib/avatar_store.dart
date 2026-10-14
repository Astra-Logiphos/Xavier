import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_library.dart';
import 'theme_config.dart';

/// Only a managed basename is persisted. Original paths are never retained.
class AvatarStore {
  final Directory root;
  final bool companion;
  String? path;
  AvatarStore({Directory? installRoot, this.companion = false})
      : root = installRoot ?? File(Platform.resolvedExecutable).parent;
  static const preferenceKey = 'managed_user_avatar';
  static const companionPreferenceKey = 'managed_companion_avatar';
  String get key => companion ? companionPreferenceKey : preferenceKey;
  Directory get directory => Directory('${root.path}/config/avatars');
  bool managed(String name) => (companion
          ? RegExp(r'^companion-avatar-\d+\.jpg$')
          : RegExp(r'^avatar-\d+\.jpg$'))
      .hasMatch(name);
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(key);
    path = name != null &&
            managed(name) &&
            await File('${directory.path}/$name').exists()
        ? '${directory.path}/$name'
        : null;
  }

  Future<void> importFile(File original) async {
    final extension = original.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png'].contains(extension)) {
      throw const FormatException('请选择 JPG 或 PNG 图片。');
    }
    if (await original.length() >
        ThemeConfig.number('performance', 'avatarMaxBytes')) {
      throw const FormatException('头像超过大小限制，请选择较小的图片。');
    }
    final encoded = await compute(prepareBackgroundPreview, {
      'bytes': await original.readAsBytes(),
      'maxSide': ThemeConfig.number('performance', 'avatarMaxSide').round(),
      'quality': ThemeConfig.number('performance', 'avatarQuality').round()
    });
    await directory.create(recursive: true);
    final name =
        '${companion ? 'companion-avatar' : 'avatar'}-${DateTime.now().microsecondsSinceEpoch}.jpg';
    final target = File('${directory.path}/$name');
    final previous = path;
    try {
      await target.writeAsBytes(encoded['bytes'] as Uint8List, flush: true);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, name)) {
        throw const FileSystemException('头像设置保存失败');
      }
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
    path = target.path;
    await _removeManaged(previous);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(key)) {
      throw const FileSystemException('头像设置清除失败');
    }
    final previous = path;
    path = null;
    await _removeManaged(previous);
  }

  Future<void> _removeManaged(String? previous) async {
    if (previous == null || !await directory.exists()) return;
    final file = File(previous);
    if (managed(file.uri.pathSegments.last) &&
        await file.exists() &&
        await file.parent.resolveSymbolicLinks() ==
            await directory.resolveSymbolicLinks()) {
      await file.delete();
    }
  }
}
