import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../models/stream_config.dart';
import '../services/command_service.dart';
import '../services/face_record_service.dart';
import '../services/recorder_service.dart';
import '../services/rtsp_service.dart';
import '../services/status_poll_service.dart';

/// 全应用共享的服务集合，随 Shell 生命周期存活。
///
/// 把原本由 PlayerPage 持有的 RTSP/录像/轮询/下发服务上提到这里，
/// 监控页与设备页经 [AppServices.of] 取同一组实例，切页不会重建播放器。
class AppServices {
  final RtspService rtsp;
  final RecorderService recorder;
  final StatusPollService statusPoll;
  final CommandService command;
  final FaceRecordService faceRecord;
  final StreamConfig config;

  AppServices({
    required this.rtsp,
    required this.recorder,
    required this.statusPoll,
    required this.command,
    required this.faceRecord,
    required this.config,
  });

  /// K230 在线判定：状态接口无错误且拿到过 status。
  bool get k230Online => statusPoll.error.value == null && statusPoll.status.value != null;

  /// 最新状态（可能为 null）。
  DeviceStatus? get status => statusPoll.status.value;

  static AppServices of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AppServicesScope>();
    assert(w != null, 'AppServices 不在上下文中，请确保在 AppShell 之下使用');
    return w!.data;
  }
}

/// [InheritedWidget] 容器，把 [AppServices] 暴露给子树。
class AppServicesScope extends InheritedWidget {
  final AppServices data;
  const AppServicesScope({super.key, required this.data, required super.child});

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) {
    // 配置变更后整个 AppServices 会被替换；引用变化即通知。
    return !identical(data, oldWidget.data);
  }
}
