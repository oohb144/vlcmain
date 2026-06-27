/// 一次「人脸识别自动录像」事件的记录，作为日志的一条。
///
/// 由 [FaceRecordService] 在自动录像开始时创建、停止时补全，并持久化到
/// `<recordDir>/face_record_log.json`。日志页据此展示索引列表，
/// 点击可跳转回放页播放对应的 [videoPath] 录像。
class FaceRecordEvent {
  /// 索引号，从 1 递增（日志「索引」列）。
  final int id;

  /// 开始时间（ISO8601 字符串，本机时区）。
  final String startIso;

  /// 结束时间；录像进行中为 null。
  final String? endIso;

  /// 录像时长（秒）。进行中为当前已录时长。
  final int durationSec;

  /// 录像文件绝对路径。
  final String videoPath;

  /// 录像期间出现过的已知人脸标签（并集，去重）。
  final List<String> faceLabels;

  /// 录像期间画面出现的最大人脸数。
  final int maxFaceCount;

  /// 录像期间是否出现过陌生人（unknown_face_count > 0）。
  final bool hasStranger;

  /// 录像期间最后一次的状态文案（如「识别中」「空闲」）。
  final String? state;

  FaceRecordEvent({
    required this.id,
    required this.startIso,
    this.endIso,
    required this.durationSec,
    required this.videoPath,
    required this.faceLabels,
    required this.maxFaceCount,
    required this.hasStranger,
    this.state,
  });

  /// 文件名（展示用）。
  String get videoName {
    final p = videoPath;
    final i = p.lastIndexOf(RegExp(r'[/\\]'));
    return i >= 0 ? p.substring(i + 1) : p;
  }

  FaceRecordEvent copyWith({
    int? id,
    String? startIso,
    String? endIso,
    int? durationSec,
    String? videoPath,
    List<String>? faceLabels,
    int? maxFaceCount,
    bool? hasStranger,
    String? state,
  }) {
    return FaceRecordEvent(
      id: id ?? this.id,
      startIso: startIso ?? this.startIso,
      endIso: endIso ?? this.endIso,
      durationSec: durationSec ?? this.durationSec,
      videoPath: videoPath ?? this.videoPath,
      faceLabels: faceLabels ?? this.faceLabels,
      maxFaceCount: maxFaceCount ?? this.maxFaceCount,
      hasStranger: hasStranger ?? this.hasStranger,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startIso': startIso,
        'endIso': endIso,
        'durationSec': durationSec,
        'videoPath': videoPath,
        'faceLabels': faceLabels,
        'maxFaceCount': maxFaceCount,
        'hasStranger': hasStranger,
        'state': state,
      };

  factory FaceRecordEvent.fromJson(Map<String, dynamic> json) {
    List<String> toStrList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return FaceRecordEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      startIso: json['startIso'] as String? ?? '',
      endIso: json['endIso'] as String?,
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      videoPath: json['videoPath'] as String? ?? '',
      faceLabels: toStrList(json['faceLabels']),
      maxFaceCount: (json['maxFaceCount'] as num?)?.toInt() ?? 0,
      hasStranger: json['hasStranger'] is bool ? json['hasStranger'] as bool : false,
      state: json['state'] as String?,
    );
  }
}
