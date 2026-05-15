import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _apiUrl =
    'https://api.github.com/repos/t-foerst/minca/releases/latest';

// Injected at build time via --dart-define=APP_VERSION=x.y.z.
// Falls back to 0.0.0 in dev so the banner never shows without a real build.
const _currentVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final int fileSize;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.fileSize,
  });
}

class UpdateService {
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final current = _currentVersion;

      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;

      if (!_isNewer(latest, current)) return null;

      final assetName =
          Platform.isWindows ? 'minca-windows.zip' : 'minca-linux.tar.gz';

      final assets = (data['assets'] as List<dynamic>?) ?? [];
      Map<String, dynamic>? asset;
      for (final a in assets) {
        final m = a as Map<String, dynamic>;
        if (m['name'] == assetName) {
          asset = m;
          break;
        }
      }
      if (asset == null) return null;

      return UpdateInfo(
        version: latest,
        downloadUrl: asset['browser_download_url'] as String,
        fileSize: (asset['size'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String latest, String current) {
    int part(String v, int i) {
      final p = v.split('.');
      return i < p.length ? (int.tryParse(p[i]) ?? 0) : 0;
    }

    for (int i = 0; i < 3; i++) {
      final l = part(latest, i);
      final c = part(current, i);
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static Future<void> downloadAndApply(
    UpdateInfo info,
    void Function(double) onProgress,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final assetName =
        Platform.isWindows ? 'minca-windows.zip' : 'minca-linux.tar.gz';
    final downloadPath =
        '${tempDir.path}${Platform.pathSeparator}$assetName';

    final request = http.Request('GET', Uri.parse(info.downloadUrl));
    final streamed = await http.Client().send(request);

    final sink = File(downloadPath).openWrite();
    int received = 0;
    final total = info.fileSize > 0 ? info.fileSize : 1;

    await for (final chunk in streamed.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress(received / total);
    }
    await sink.close();

    final installDir = File(Platform.resolvedExecutable).parent.path;

    if (Platform.isWindows) {
      _applyWindows(downloadPath, installDir);
    } else {
      await _applyLinux(downloadPath, installDir);
    }
  }

  static void _applyWindows(String zipPath, String installDir) {
    final exe = Platform.resolvedExecutable;
    final tempDir = File(zipPath).parent.path;
    final scriptPath = '$tempDir\\minca_update.bat';

    // Single-quote paths inside the PowerShell command.
    // Batch %~f0 self-deletes the script after running.
    final psCmd =
        "Expand-Archive -LiteralPath '$zipPath' -DestinationPath '$installDir' -Force";

    final script = '@echo off\r\n'
        'timeout /t 2 /nobreak > NUL\r\n'
        'powershell -Command "$psCmd"\r\n'
        'start "" "$exe"\r\n'
        '(goto) 2>nul & del "%~f0"\r\n';

    File(scriptPath).writeAsStringSync(script);
    Process.start('cmd', ['/c', scriptPath],
        mode: ProcessStartMode.detached);
    exit(0);
  }

  static Future<void> _applyLinux(
      String tarPath, String installDir) async {
    final exe = Platform.resolvedExecutable;
    final scriptPath = '${Directory.systemTemp.path}/minca_update.sh';
    final logPath = '${Directory.systemTemp.path}/minca_update.log';

    // Capture display env vars at script-write time so the detached process
    // can still open a window after the parent app exits.
    final display = Platform.environment['DISPLAY'] ?? '';
    final waylandDisplay = Platform.environment['WAYLAND_DISPLAY'] ?? '';
    final dbusAddress = Platform.environment['DBUS_SESSION_BUS_ADDRESS'] ?? '';
    final xdgRuntime = Platform.environment['XDG_RUNTIME_DIR'] ?? '';

    final script = '#!/bin/bash\n'
        'exec > "$logPath" 2>&1\n'
        'set -x\n'
        'sleep 1\n'
        'export DISPLAY="$display"\n'
        'export WAYLAND_DISPLAY="$waylandDisplay"\n'
        'export DBUS_SESSION_BUS_ADDRESS="$dbusAddress"\n'
        'export XDG_RUNTIME_DIR="$xdgRuntime"\n'
        "tar -xzf '$tarPath' -C '$installDir'\n"
        "chmod +x '$exe'\n"
        "nohup '$exe' > /dev/null 2>&1 &\n"
        'rm -- "\$0"\n';

    final f = File(scriptPath);
    f.writeAsStringSync(script);
    await Process.run('chmod', ['+x', scriptPath]);
    Process.start('bash', [scriptPath], mode: ProcessStartMode.detached);
    exit(0);
  }
}
