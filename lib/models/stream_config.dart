/// 上位机配置模型：RTSP 地址、状态接口、下发接口、录像目录、状态轮询间隔。
class StreamConfig {
  /// K230 / MaixCAM 的 RTSP 推流地址，例如 `rtsp://192.168.1.100:8554/stream`
  final String rtspUrl;

  /// K230 状态查询接口 URL（HTTP GET），返回 JSON 状态信息
  final String statusUrl;

  /// K230 指令下发接口 URL（HTTP POST）
  final String commandUrl;

  /// 本地录像保存目录（绝对路径）
  final String recordDir;

  /// ffmpeg.exe 路径；为空则用系统 PATH 中的 ffmpeg
  final String ffmpegPath;

  /// 状态轮询间隔（毫秒）
  final int pollIntervalMs;

  /// 是否启用「识别到人脸自动录像」（本机侧，基于 /status 的 face_count）
  final bool autoFaceRecord;

  const StreamConfig({
    this.rtspUrl = 'rtsp://192.168.1.100:8554/stream',
    this.statusUrl = 'http://192.168.1.100/status',
    this.commandUrl = 'http://192.168.1.100/command',
    this.recordDir = '',
    this.ffmpegPath = 'ffmpeg',
    this.pollIntervalMs = 1000,
    this.autoFaceRecord = true,
  });

  StreamConfig copyWith({
    String? rtspUrl,
    String? statusUrl,
    String? commandUrl,
    String? recordDir,
    String? ffmpegPath,
    int? pollIntervalMs,
    bool? autoFaceRecord,
  }) {
    return StreamConfig(
      rtspUrl: rtspUrl ?? this.rtspUrl,
      statusUrl: statusUrl ?? this.statusUrl,
      commandUrl: commandUrl ?? this.commandUrl,
      recordDir: recordDir ?? this.recordDir,
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      pollIntervalMs: pollIntervalMs ?? this.pollIntervalMs,
      autoFaceRecord: autoFaceRecord ?? this.autoFaceRecord,
    );
  }

  Map<String, dynamic> toJson() => {
        'rtspUrl': rtspUrl,
        'statusUrl': statusUrl,
        'commandUrl': commandUrl,
        'recordDir': recordDir,
        'ffmpegPath': ffmpegPath,
        'pollIntervalMs': pollIntervalMs,
        'autoFaceRecord': autoFaceRecord,
      };

  factory StreamConfig.fromJson(Map<String, dynamic> json) => StreamConfig(
        rtspUrl: json['rtspUrl'] as String? ?? const StreamConfig().rtspUrl,
        statusUrl: json['statusUrl'] as String? ??
            const StreamConfig().statusUrl,
        commandUrl: json['commandUrl'] as String? ??
            const StreamConfig().commandUrl,
        recordDir: json['recordDir'] as String? ??
            const StreamConfig().recordDir,
        ffmpegPath: json['ffmpegPath'] as String? ??
            const StreamConfig().ffmpegPath,
        pollIntervalMs:
            json['pollIntervalMs'] as int? ?? const StreamConfig().pollIntervalMs,
        autoFaceRecord: json['autoFaceRecord'] is bool
            ? json['autoFaceRecord'] as bool
            : const StreamConfig().autoFaceRecord,
      );
}