import 'dart:convert';
import 'dart:io';

class LocalVoicePack {
  static Process? playing;
  static Future<bool> play(String scene, {Directory? installRoot}) async {
    if (!Platform.isWindows) return false;
    final root = installRoot ?? File(Platform.resolvedExecutable).parent;
    final directory = Directory('${root.path}/assets/voices');
    final manifest = File('${directory.path}/manifest.json');
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(scene)) return false;
    dynamic entries;
    if (await manifest.exists()) {
      final data =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      entries = data[scene];
    }
    if (entries is! List || entries.isEmpty) {
      final folder = Directory('${directory.path}/$scene');
      if (await folder.exists()) {
        final files = await folder
            .list()
            .where((item) =>
                item is File && item.path.toLowerCase().endsWith('.wav'))
            .toList();
        files.sort((a, b) => a.path.compareTo(b.path));
        entries = files
            .map((file) => '$scene/${file.uri.pathSegments.last}')
            .toList();
      }
    }
    if (entries is! List || entries.isEmpty || entries.first is! String) {
      return false;
    }
    final path = entries.first as String;
    if (path.startsWith('/') ||
        path.contains(':') ||
        path.contains('\\') ||
        path.split('/').contains('..') ||
        !path.toLowerCase().endsWith('.wav')) {
      return false;
    }
    final file = File('${directory.path}/$path');
    if (!await file.exists()) return false;
    final resolvedRoot = await directory.resolveSymbolicLinks();
    final resolvedFile = await file.resolveSymbolicLinks();
    if (!resolvedFile
        .toLowerCase()
        .startsWith('${resolvedRoot.toLowerCase()}${Platform.pathSeparator}')) {
      return false;
    }
    playing?.kill();
    playing = await Process.start('powershell.exe', [
      '-NoProfile',
      '-Command',
      r'$sound=New-Object System.Media.SoundPlayer($env:XINGHUI_VOICE_FILE); $sound.Load(); $sound.PlaySync()'
    ], environment: {
      'XINGHUI_VOICE_FILE': resolvedFile
    });
    playing!.stdout.drain<void>();
    playing!.stderr.drain<void>();
    return true;
  }

  static void stop() {
    playing?.kill();
    playing = null;
  }
}
