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

  /// 创建（或复用）Player 与 VideoController。
  void ensurePlayer() {
    if (_player != null) return;
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 16 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player!);
  }

  /// 应用 RTSP 优化参数。可在 open 前调用。
  Future<void> applyRtspPrefs() async {
    ensurePlayer();
    await _setProperty('rtsp-transport', 'tcp');
    await _setProperty('profile', 'low-latency');
    await _setProperty('hwdec', 'auto');
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
  Future<void> open(String uri) async {
    ensurePlayer();
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