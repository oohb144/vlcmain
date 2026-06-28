import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 封装 media_kit 的 Player + VideoController，提供 RTSP/本地文件播放能力。
///
/// RTSP 优化策略：
/// - `rtsp-transport=tcp`：优先 TCP，局域网更稳，避免 UDP 丢包花屏
/// - `profile=low-latency`：低延迟
/// - `hwdec=auto`：硬件解码
class RtspService {
  Player? _player;
  VideoController? _controller;

  Player get player {
    final p = _player;
    if (p == null) {
      throw StateError('RtspService 尚未初始化，请先调用 ensurePlayer()');
    }
    return p;
  }

  VideoController? get controller => _controller;

  /// mpv 日志流（错误/信息），用于排查录像等问题。
  Stream<PlayerLog> get logStream {
    ensurePlayer();
    return _player!.stream.log;
  }

  /// 创建（或复用）Player 与 VideoController。
  void ensurePlayer() {
    if (_player != null) return;
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 16 * 1024 * 1024,
        logLevel: MPVLogLevel.info,
      ),
    );
    _controller = VideoController(_player!);
  }

  /// 应用 RTSP 优化参数。可在 open 前调用。
  ///
  /// 注意：[applyRtspPrefs] 设了 `profile=low-latency`，该 profile 会禁用
  /// demuxer-seekable-cache，导致 mpv 的 `stream-record` 录像不可用
  ///（报 "disabling recording" / "cannot create file cache"）。
  /// 因此录像时必须改用 [applyRecordablePrefs] 启用 seekable cache。
  Future<void> applyRtspPrefs() async {
    ensurePlayer();
    await _setProperty('rtsp-transport', 'tcp');
    await _setProperty('profile', 'low-latency');
    await _setProperty('hwdec', 'auto');
  }

  /// 录像专用参数：仅用内存缓存，不设 `demuxer-seekable-cache`。
  ///
  /// 关键：**不要**设 `demuxer-seekable-cache=yes`。该选项会让 mpv 创建一个
  /// **文件缓存**（落到系统临时目录），Android 上临时目录不可写，mpv 报
  /// `cannot create file cache` 并级联 `disabling recording`，录像完全不落盘。
  /// `stream-record` 只是把原始包顺序写进目标文件，不需要可寻址文件缓存，
  /// 内存缓存（`cache=yes`）即可。此处仍覆盖 low-latency profile 设的 `cache=no`。
  Future<void> applyRecordablePrefs() async {
    ensurePlayer();
    await _setProperty('rtsp-transport', 'tcp');
    await _setProperty('hwdec', 'auto');
    // 内存缓存：覆盖 low-latency 的 cache=no；不设 demuxer-seekable-cache
    await _setProperty('cache', 'yes');
    await _setProperty('cache-secs', '2');
  }

  /// 通过底层 mpv 平台句柄设置任意 mpv 属性。
  Future<void> _setProperty(String key, String value) async {
    final plat = _player?.platform;
    if (plat == null) return;
    // NativePlayer.setProperty；用 dynamic 规避平台类型导入耦合
    await (plat as dynamic).setProperty(key, value);
  }

  /// 暴露 setProperty 能力给录像服务等使用。
  Future<void> setProperty(String key, String value) =>
      _setProperty(key, value);

  /// 打开并播放 RTSP 地址或本地文件路径。
  /// [recordPath] 非空时，会在 open 前通过 mpv 的 `stream-record` 属性注入，
  /// 从而边播边把原始流复制到本地文件（不二次编码）。
  /// 注意：stream-record 只对网络/直播流生效，播放本地文件时无效。
  Future<void> open(String uri, {String? recordPath}) async {
    ensurePlayer();
    // 关键：必须在 open 之前设置 stream-record，开播后再设不生效
    if (recordPath != null && recordPath.isNotEmpty) {
      await _setProperty('stream-record', recordPath);
    } else {
      // 没传录像路径，确保清掉之前的录制目标
      await _setProperty('stream-record', '');
    }
    await player.open(Media(uri));
  }

  Future<void> play() async => player.play();

  Future<void> pause() async => player.pause();

  Future<void> stop() async => player.stop();

  Future<void> setVolume(double v) async => player.setVolume(v);

  /// 释放资源。
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _controller = null;
  }
}