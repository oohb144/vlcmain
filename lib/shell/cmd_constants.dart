/// 下发指令常量（与 K230 端 HTTP POST /command 协议对齐）。
///
/// 从原 status_panel 的 `_Cmd` 提取为公开常量，供监控页 / 设备页复用。
/// 字段定义见根目录《K230 下发协议文档.md》。
class Cmd {
  const Cmd._();

  // 主操作
  static const startRecognize = {'cmd': 'start_recognize'};
  static const stopRecognize = {'cmd': 'stop_recognize'};
  static const startEnroll = {'cmd': 'start_enroll'};
  static const stopEnroll = {'cmd': 'stop_enroll'};
  static const startRecord = {'cmd': 'start_record'};
  static const stopRecord = {'cmd': 'stop_record'};
  static const enrollFace = {'cmd': 'enroll_face'};
  static const goHome = {'cmd': 'go_home'};

  // 页面跳转
  static const goSettings = {'cmd': 'go_settings'};
  static const goEnrollPage = {'cmd': 'go_enroll_page'};
  static const fusionPage = {'cmd': 'fusion_page'};
  static const recordingsPage = {'cmd': 'recordings_page'};

  // 设备开关（value=true 开 / false 关）
  static const streamOn = {'cmd': 'http_stream', 'value': true};
  static const streamOff = {'cmd': 'http_stream', 'value': false};
  static const rtspOn = {'cmd': 'rtsp', 'value': true};
  static const rtspOff = {'cmd': 'rtsp', 'value': false};
  static const audioOn = {'cmd': 'audio', 'value': true};
  static const audioOff = {'cmd': 'audio', 'value': false};
  static const ledOn = {'cmd': 'led', 'value': true};
  static const ledOff = {'cmd': 'led', 'value': false};
  static const voiceOn = {'cmd': 'voice', 'value': true};
  static const voiceOff = {'cmd': 'voice', 'value': false};
  static const autoRecordOn = {'cmd': 'auto_record', 'value': true};
  static const autoRecordOff = {'cmd': 'auto_record', 'value': false};

  // 危险操作
  static const clearFaces = {'cmd': 'clear_faces'};
  static const clearRecordings = {'cmd': 'clear_recordings'};
  static const exitApp = {'cmd': 'exit_app'};

  // 阈值
  static Map<String, dynamic> confThreshold(double v) =>
      {'cmd': 'set_threshold', 'key': 'conf_threshold', 'value': v};
  static Map<String, dynamic> recognizeThreshold(double v) =>
      {'cmd': 'set_threshold', 'key': 'recognize_threshold', 'value': v};
}
