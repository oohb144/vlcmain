import 'dart:io';
import 'package:path/path.dart' as p;

/// 录像文件信息。
class Recording {
  final String path;
  final int sizeBytes;
  final DateTime modified;

  Recording({
    required this.path,
    required this.sizeBytes,
    required this.modified,
  });

  String get name => p.basename(path);

  String get sizeStr {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}

/// 回放服务：扫描录像目录下的 `.ts` 文件，按修改时间倒序返回。
class PlaybackService {
  Future<List<Recording>> listRecordings(String dir) async {
    if (dir.isEmpty) return [];
    final d = Directory(dir);
    if (!await d.exists()) return [];
    final files = <Recording>[];
    await for (final ent in d.list()) {
      if (ent is File && ent.path.toLowerCase().endsWith('.ts')) {
        final stat = await ent.stat();
        files.add(Recording(
          path: ent.path,
          sizeBytes: stat.size,
          modified: stat.modified,
        ));
      }
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }
}