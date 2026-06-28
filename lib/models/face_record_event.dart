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

  /// 录像期间识别到的**不同熟人数**（= [faceLabels] 去重后的数量）。
  final int knownCount;

  /// 录像期间出现的**陌生人数**（取单次轮询里 unknown_face_count 的峰值；
  /// 陌生人无身份标识，无法跨轮去重，故用同时峰值近似）。
  final int unknownCount;

  /// 录像期间出现的**总人数** = [knownCount] + [unknownCount]。
  final int totalCount;

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
    required this.knownCount,
    required this.unknownCount,
    required this.totalCount,
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
    int? knownCount,
    int? unknownCount,
    int? totalCount,
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
      knownCount: knownCount ?? this.knownCount,
      unknownCount: unknownCount ?? this.unknownCount,
      totalCount: totalCount ?? this.totalCount,
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
        'knownCount': knownCount,
        'unknownCount': unknownCount,
        'totalCount': totalCount,
        'hasStranger': hasStranger,
        'state': state,
      };

  factory FaceRecordEvent.fromJson(Map<String, dynamic> json) {
    List<String> toStrList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    int toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

    // 兼容旧日志字段名（maxKnownCount / maxUnknownCount / maxFaceCount）
    final labels = toStrList(json['faceLabels']);
    final known = toInt(json['knownCount']);
    final knownFallback = toInt(json['maxKnownCount']);
    final unknown = toInt(json['unknownCount']);
    final unknownFallback = toInt(json['maxUnknownCount']);
    final total = toInt(json['totalCount']);
    final totalFallback = toInt(json['maxFaceCount']);

    // 旧日志无 knownCount 时，用标签去重数补；total 无则用 face_count 峰值
    final knownFinal = known > 0
        ? known
        : (knownFallback > 0 ? knownFallback : labels.length);
    final unknownFinal = unknown > 0 ? unknown : unknownFallback;
    final totalFinal = total > 0
        ? total
        : (totalFallback > 0 ? totalFallback : knownFinal + unknownFinal);

    return FaceRecordEvent(
      id: toInt(json['id']),
      startIso: json['startIso'] as String? ?? '',
      endIso: json['endIso'] as String?,
      durationSec: toInt(json['durationSec']),
      videoPath: json['videoPath'] as String? ?? '',
      faceLabels: labels,
      knownCount: knownFinal,
      unknownCount: unknownFinal,
      totalCount: totalFinal,
      hasStranger: json['hasStranger'] is bool ? json['hasStranger'] as bool : false,
      state: json['state'] as String?,
    );
  }
}
