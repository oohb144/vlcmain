/// K230 上报的状态信息模型。
///
/// 字段严格对齐 MaixCAM 端 status_server.py 的 GET /status 返回：
///   state / has_face / face_count / known_face_count / unknown_face_count /
///   face_labels / recording / record_duration
/// 额外保留 [raw] 用于兜底展示 K230 未来新增的字段。
class DeviceStatus {
  /// 当前状态中文文案，例如 "空闲"/"识别中"/"录制中"/"录入中"/"错误"
  final String? state;

  /// 是否检测到人脸
  final bool? hasFace;

  /// 当前画面中的人脸总数（即"人员数量"主字段）
  final int? faceCount;

  /// 已知人脸数
  final int? knownFaceCount;

  /// 未知人脸数
  final int? unknownFaceCount;

  /// 识别到的人脸标签列表（已录入的人名）
  final List<String> faceLabels;

  /// 是否正在录制
  final bool? recording;

  /// 当前录制已持续时长（秒）
  final int? recordDuration;

  /// 最后更新时间（本机时间戳，毫秒）
  final int updatedAtMs;

  /// 无法识别到具名字段的原始 JSON，兜底展示
  final Map<String, dynamic> raw;

  DeviceStatus({
    this.state,
    this.hasFace,
    this.faceCount,
    this.knownFaceCount,
    this.unknownFaceCount,
    required this.faceLabels,
    this.recording,
    this.recordDuration,
    required this.updatedAtMs,
    required this.raw,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json, int updatedAtMs) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    List<String> toStrList(dynamic v) {
      if (v == null) return const [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return DeviceStatus(
      state: json['state']?.toString(),
      hasFace: json['has_face'] is bool ? json['has_face'] as bool : null,
      faceCount: toInt(json['face_count']),
      knownFaceCount: toInt(json['known_face_count']),
      unknownFaceCount: toInt(json['unknown_face_count']),
      faceLabels: toStrList(json['face_labels']),
      recording: json['recording'] is bool ? json['recording'] as bool : null,
      recordDuration: toInt(json['record_duration']),
      updatedAtMs: updatedAtMs,
      raw: json,
    );
  }
}