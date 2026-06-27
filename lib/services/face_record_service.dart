import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/device_status.dart';
import '../models/face_record_event.dart';
import '../models/stream_config.dart';
import 'recorder_service.dart';
import 'status_poll_service.dart';

/// 人脸识别自动录像服务。
///
/// 依据 [StatusPollService] 上报的 [DeviceStatus.faceCount] 自动控制录像：
/// - `face_count > 0`（且非陈旧）→ 自动开始录像（复用 [RecorderService]）；
/// - `face_count == 0` 持续 [stopDelay]（默认 3s）→ 停止录像；
/// - 状态陈旧（轮询停掉/断网超过 [staleThreshold]）→ 也视为无人脸，触发停止。
///
/// 每次录像生成一条带索引的 [FaceRecordEvent]，持久化到
/// `<recordDir>/face_record_log.json`，供日志页查看与点击回放。
///
/// 与手动录像共用同一个 [RecorderService]：自动开始前若检测到
/// `recorder.isRecording`（手动在录）则跳过，避免冲突。
class FaceRecordService {
  final RecorderService recorder;
  final StatusPollService statusPoll;
  final StreamConfig config;

  /// 无人脸后多久停止录像。
  final Duration stopDelay;

  /// 状态多久没更新视为陈旧（控制通道关闭/断网）。
  final Duration staleThreshold;

  FaceRecordService({
    required this.recorder,
    required this.statusPoll,
    required this.config,
    this.stopDelay = const Duration(seconds: 3),
    this.staleThreshold = const Duration(seconds: 3),
  });

  /// 是否启用自动录像（来自 [StreamConfig.autoFaceRecord]）。
  bool get enabled => config.autoFaceRecord;

  /// 当前是否正在自动录像。
  final ValueNotifier<bool> recording = ValueNotifier<bool>(false);

  /// 当前进行中的录像事件（停止后置 null）。
  final ValueNotifier<FaceRecordEvent?> current =
      ValueNotifier<FaceRecordEvent?>(null);

  /// 已完成的录像日志（最新在前）。
  final ValueNotifier<List<FaceRecordEvent>> log =
      ValueNotifier<List<FaceRecordEvent>>(const []);

  Timer? _timer;
  int _nextId = 1;
  final List<FaceRecordEvent> _events = []; // 最新在前

  // 进行中事件的累积状态
  DateTime? _startAt;
  String? _videoPath;
  final Set<String> _accLabels = {};
  int _accMax = 0;
  bool _accStranger = false;
  String? _accState;
  int _lastUpdateMs = 0;
  DateTime? _noFaceSince; // 无人脸起始时刻；非空表示正在等待停止
  bool _starting = false; // _begin 异步进行中，防心跳重入
  bool _stopping = false; // _finalize 异步进行中，防心跳重入

  static const _logFileName = 'face_record_log.json';
  static const _maxEvents = 500;

  /// 启动心跳；并异步从磁盘加载历史日志。
  void start() {
    if (_timer != null) return;
    _load();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  /// 手动切换启用开关（不落盘；落盘由配置保存触发 AppShell 重建）。
  void setEnabled(bool v) {
    if (enabled == v) return;
    // StreamConfig 不可变，运行时覆盖；保存配置后 AppShell 会重建服务覆盖此值
    _runtimeEnabled = v;
    if (!v && recording.value && !_stopping) {
      _stopping = true;
      unawaited(_finalize(overrideReason: '已关闭自动录像'));
    }
  }

  bool? _runtimeEnabled;
  bool get _effectiveEnabled => _runtimeEnabled ?? config.autoFaceRecord;

  void _tick() {
    final status = statusPoll.status.value;
    final now = DateTime.now();
    if (status != null) {
      _lastUpdateMs = status.updatedAtMs;
    }
    final stale = _lastUpdateMs == 0 ||
        now.millisecondsSinceEpoch - _lastUpdateMs > staleThreshold.inMilliseconds;

    final faceCount = status?.faceCount ?? 0;
    final faceDetected = _effectiveEnabled &&
        !stale &&
        faceCount > 0 &&
        config.rtspUrl.isNotEmpty &&
        config.recordDir.isNotEmpty;

    if (recording.value) {
      if (faceDetected) {
        // 人脸仍在 → 取消停止倒计时，累积识别情况
        _noFaceSince = null;
        _accumulate(status!);
        _publishCurrent(now);
      } else {
        // 无人脸 → 启动/保持停止倒计时
        _noFaceSince ??= now;
        final elapsed = now.difference(_noFaceSince!);
        _publishCurrent(now);
        if (elapsed >= stopDelay && !_stopping) {
          _stopping = true;
          unawaited(_finalize());
        }
      }
      return;
    }

    // idle：检测到人脸且未被手动占用 → 开始录像
    if (faceDetected && !recorder.isRecording && !_starting) {
      _begin(status!);
    }
  }

  Future<void> _begin(DeviceStatus status) async {
    _starting = true;
    _startAt = DateTime.now();
    _videoPath = null;
    _accLabels
      ..clear()
      ..addAll(status.faceLabels);
    _accMax = status.faceCount ?? 0;
    _accStranger = (status.unknownFaceCount ?? 0) > 0;
    _accState = status.state;
    _noFaceSince = null;

    try {
      final path = await recorder.start(
        rtspUrl: config.rtspUrl,
        dir: config.recordDir,
        ffmpegPath: config.ffmpegPath,
      );
      _videoPath = path;
      final ev = FaceRecordEvent(
        id: _nextId,
        startIso: _startAt!.toIso8601String(),
        durationSec: 0,
        videoPath: path,
        faceLabels: _accLabels.toList(),
        maxFaceCount: _accMax,
        hasStranger: _accStranger,
        state: _accState,
      );
      _nextId++;
      recording.value = true;
      current.value = ev;
      // 立即写一条「进行中」记录，便于崩溃后留痕
      _events.insert(0, ev);
      if (_events.length > _maxEvents) {
        _events.removeRange(_maxEvents, _events.length);
      }
      log.value = List.unmodifiable(_events);
      unawaited(_persist());
    } catch (e) {
      debugPrint('[face_record] 开始录像失败: $e');
      _reset();
    } finally {
      _starting = false;
    }
  }

  void _accumulate(DeviceStatus status) {
    _accLabels.addAll(status.faceLabels);
    final fc = status.faceCount ?? 0;
    if (fc > _accMax) _accMax = fc;
    if ((status.unknownFaceCount ?? 0) > 0) _accStranger = true;
    _accState = status.state;
  }

  void _publishCurrent(DateTime now) {
    final start = _startAt;
    if (start == null) return;
    final dur = now.difference(start).inSeconds;
    final cur = current.value;
    if (cur == null) return;
    current.value = cur.copyWith(
      durationSec: dur,
      faceLabels: _accLabels.toList(),
      maxFaceCount: _accMax,
      hasStranger: _accStranger,
      state: _accState,
    );
  }

  Future<void> _finalize({String? overrideReason}) async {
    final start = _startAt;
    if (start == null) {
      _stopping = false;
      _reset();
      return;
    }
    try {
      await recorder.stop();
    } catch (e) {
      debugPrint('[face_record] 停止录像异常: $e');
    }
    final end = DateTime.now();
    final dur = end.difference(start).inSeconds;
    final path = _videoPath ?? '';
    // 替换 _events 顶部那条「进行中」为最终版
    final finalized = FaceRecordEvent(
      id: _nextId - 1,
      startIso: start.toIso8601String(),
      endIso: end.toIso8601String(),
      durationSec: dur,
      videoPath: path,
      faceLabels: _accLabels.toList(),
      maxFaceCount: _accMax,
      hasStranger: _accStranger,
      state: overrideReason ?? _accState,
    );
    if (_events.isNotEmpty && _events.first.id == finalized.id) {
      _events[0] = finalized;
    } else {
      _events.insert(0, finalized);
      if (_events.length > _maxEvents) {
        _events.removeRange(_maxEvents, _events.length);
      }
    }
    log.value = List.unmodifiable(_events);
    current.value = null;
    recording.value = false;
    _reset();
    _stopping = false;
    unawaited(_persist());
  }

  void _reset() {
    _startAt = null;
    _videoPath = null;
    _accLabels.clear();
    _accMax = 0;
    _accStranger = false;
    _accState = null;
    _noFaceSince = null;
  }

  String get _logFilePath => p.join(config.recordDir, _logFileName);

  Future<void> _persist() async {
    if (config.recordDir.isEmpty) return;
    try {
      final f = File(_logFilePath);
      try {
        await f.parent.create(recursive: true);
      } catch (_) {}
      final payload = jsonEncode({
        'nextId': _nextId,
        'events': _events.map((e) => e.toJson()).toList(),
      });
      await f.writeAsString(payload);
    } catch (e) {
      debugPrint('[face_record] 写日志失败: $e');
    }
  }

  Future<void> _load() async {
    if (config.recordDir.isEmpty) return;
    try {
      final f = File(_logFilePath);
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _nextId = (json['nextId'] as num?)?.toInt() ?? 1;
      final list = json['events'];
      if (list is List) {
        _events
          ..clear()
          ..addAll(list
              .map((e) => FaceRecordEvent.fromJson(e as Map<String, dynamic>))
              .where((e) => e.endIso != null));
        // 最新在前：磁盘里已是最新的在前，这里保证一下
        _events.sort((a, b) => b.id.compareTo(a.id));
        log.value = List.unmodifiable(_events);
      }
    } catch (e) {
      debugPrint('[face_record] 读日志失败: $e');
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    if (recording.value) {
      _stopping = true;
      await _finalize(overrideReason: '退出');
    }
    recording.dispose();
    current.dispose();
    log.dispose();
  }
}
