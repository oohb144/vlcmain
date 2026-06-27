import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/face_record_event.dart';
import '../shell/app_services.dart';
import '../shell/cmd_constants.dart';
import '../shell/nav_destinations.dart';
import '../theme/app_colors.dart';
import '../widgets/event_stream.dart';
import '../widgets/face_dashboard.dart';
import '../widgets/stat_card.dart';
import '../widgets/video_stage.dart';

/// 实时监控页：视频区 + 事件流 + 统计 + 主操作指令。
///
/// 事件由 [StatusPollService.status] 的变化推导（识别态切换 / 新人脸标签 /
/// 陌生人 / 录制），保留最近 50 条；今日开门/报警计数会话级累计。
class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  AppServices? _svc;
  final List<EventItem> _events = [];
  String? _lastState;
  List<String> _lastLabels = const [];
  int _openCount = 0;
  int _alarmCount = 0;
  bool _lastAutoRec = false;

  static const _maxEvents = 50;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = AppServices.of(context);
    if (!identical(svc, _svc)) {
      _svc?.statusPoll.status.removeListener(_onStatus);
      _svc?.faceRecord.recording.removeListener(_onAutoRec);
      _svc = svc;
      svc.statusPoll.status.addListener(_onStatus);
      svc.faceRecord.recording.addListener(_onAutoRec);
      // 首次绑定立即用当前值推一次
      _onStatus();
      _lastAutoRec = svc.faceRecord.recording.value;
    }
  }

  @override
  void dispose() {
    _svc?.statusPoll.status.removeListener(_onStatus);
    _svc?.faceRecord.recording.removeListener(_onAutoRec);
    super.dispose();
  }

  void _onStatus() {
    final s = _svc?.statusPoll.status.value;
    if (s == null) return;
    final state = s.state ?? '';
    final labels = s.faceLabels;

    // 识别态切换
    final recognizing = state.contains('识别');
    if (recognizing && !(_lastState?.contains('识别') ?? false)) {
      _push(EventKind.info, '开始识别', state);
    }
    // 录制态切换
    if ((s.recording == true) && !(_lastState?.contains('录制') ?? false)) {
      _push(EventKind.info, '开始录制', '自动/手动录制');
    }
    // 新出现的已知人脸标签 → 开门
    for (final label in labels) {
      if (!_lastLabels.contains(label)) {
        _push(EventKind.face, '$label 人脸验证通过', '已开门');
        _openCount++;
      }
    }
    // 陌生人
    if ((s.unknownFaceCount ?? 0) > 0) {
      _push(EventKind.alarm, '陌生人检测报警', '置信度未知 | 已联动音频报警');
      _alarmCount++;
    }
    // 录入态切换
    if (state.contains('录入') && !(_lastState?.contains('录入') ?? false)) {
      _push(EventKind.info, '进入人脸录入', state);
    }

    _lastState = state;
    _lastLabels = List.unmodifiable(labels);
    if (mounted) setState(() {});
  }

  /// 自动录像状态翻转 → 推一条事件到「实时事件」。
  void _onAutoRec() {
    final v = _svc?.faceRecord.recording.value ?? false;
    if (v && !_lastAutoRec) {
      _push(EventKind.info, '开始自动录像', '识别到人脸');
    } else if (!v && _lastAutoRec) {
      final log = _svc?.faceRecord.log.value ?? const <FaceRecordEvent>[];
      final dur = log.isNotEmpty ? log.first.durationSec : 0;
      _push(EventKind.info, '已停止自动录像', '时长 ${dur}s');
    }
    _lastAutoRec = v;
    if (mounted) setState(() {});
  }

  void _push(EventKind kind, String title, String? meta) {
    _events.insert(0, EventItem(kind: kind, title: title, meta: meta, time: DateTime.now()));
    if (_events.length > _maxEvents) _events.removeRange(_maxEvents, _events.length);
  }

  Future<void> _send(Map<String, dynamic> payload, String label) async {
    final res = await _svc!.command.send(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: ${res.message}'),
        backgroundColor: res.ok ? AppColors.green : AppColors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirm(String action, VoidCallback doIt) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('确认$action？'),
        content: Text('该操作不可撤销，确定要$action吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () { Navigator.pop(ctx); doIt(); },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = _svc!;
    final status = svc.statusPoll.status.value;
    final k230Online = svc.k230Online;

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= kBreakpoint;

        // 右栏：事件流 + 识别录像日志 + 主操作
        final rightColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(
              title: '实时事件',
              icon: Icons.bolt,
              trailing: _Tag('今日 ${_events.length} 条', AppColors.accentDim, AppColors.accent),
              child: EventStream(items: _events),
            ),
            const SizedBox(height: 12),
            _FaceRecordLogCard(svc: svc),
            const SizedBox(height: 12),
            _Card(
              title: '主操作',
              icon: Icons.play_circle_outline,
              child: _MainOps(onSend: _send),
            ),
            const SizedBox(height: 12),
            _Card(
              title: '危险操作',
              icon: Icons.warning_amber,
              tone: AppColors.red,
              child: _DangerOps(onConfirm: _confirm, onSend: _send),
            ),
          ],
        );

        // 左栏：视频 + 统计
        final leftColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const VideoStage(),
            const SizedBox(height: 16),
            // 统计卡：宽屏 4 列，窄屏 2 列
            wide
                ? GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: _statCards(status, k230Online),
                  )
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: _statCards(status, k230Online),
                  ),
          ],
        );

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: leftColumn),
                          const SizedBox(width: 16),
                          SizedBox(width: 340, child: rightColumn),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          leftColumn,
                          const SizedBox(height: 16),
                          rightColumn,
                        ],
                      ),
                    ),
            ),
            // 悬浮控制仪表盘按钮
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.accentDim,
                foregroundColor: AppColors.accent,
                icon: const Icon(Icons.dashboard, size: 20),
                label: const Text('控制台', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                elevation: 2,
                onPressed: () => showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: '控制台',
                  barrierColor: Colors.black54,
                  transitionDuration: const Duration(milliseconds: 220),
                  transitionBuilder: (context, animation, secondary, child) {
                    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                    return FadeTransition(
                      opacity: curved,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.85, end: 1.0).animate(curved),
                        alignment: Alignment.bottomRight,
                        child: child,
                      ),
                    );
                  },
                  pageBuilder: (_, _, _) => FaceDashboard(
                    command: svc.command,
                    statusPoll: svc.statusPoll,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _statCards(dynamic status, bool k230Online) {
    return [
      StatCard(
        label: '设备状态',
        value: k230Online ? '在线' : '离线',
        sub: 'K230 / STM32 / 外设',
        valueSize: 16,
        tone: k230Online ? StatTone.green : StatTone.red,
        icon: k230Online ? Icons.cloud_done : Icons.cloud_off,
      ),
      StatCard(
        label: '今日开门',
        value: '$_openCount',
        sub: '人脸/指纹/NFC/密码',
        tone: StatTone.accent,
        icon: Icons.lock_open,
      ),
      StatCard(
        label: '今日报警',
        value: '$_alarmCount',
        sub: '陌生人 / 密码错误',
        tone: StatTone.red,
        icon: Icons.warning_amber,
      ),
      StatCard(
        label: '画面人数',
        value: '${status?.faceCount ?? 0}',
        sub: '已知 ${status?.knownFaceCount ?? 0} / 未知 ${status?.unknownFaceCount ?? 0}',
        tone: StatTone.yellow,
        valueSize: 16,
        icon: Icons.people_outline,
      ),
    ];
  }
}

/// 主操作：三组开关 + 执行录入 + 页面跳转。
class _MainOps extends StatefulWidget {
  final void Function(Map<String, dynamic>, String) onSend;
  const _MainOps({required this.onSend});

  @override
  State<_MainOps> createState() => _MainOpsState();
}

class _MainOpsState extends State<_MainOps> {
  bool _recognizing = false;
  bool _enrolling = false;
  bool _recording = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppServices.of(context).statusPoll.status.value;
    if (s != null && s.state != null) {
      _recognizing = s.state!.contains('识别');
      _enrolling = s.state!.contains('录入');
      _recording = s.state!.contains('录制') || (s.recording == true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _ActionChip(
          label: _recognizing ? '停止识别' : '开始识别',
          on: _recognizing,
          onTap: () {
            widget.onSend(_recognizing ? Cmd.stopRecognize : Cmd.startRecognize,
                _recognizing ? '停止识别' : '开始识别');
            setState(() => _recognizing = !_recognizing);
          },
        ),
        _ActionChip(
          label: _enrolling ? '停止录入' : '开始录入',
          on: _enrolling,
          onTap: () {
            widget.onSend(_enrolling ? Cmd.stopEnroll : Cmd.startEnroll,
                _enrolling ? '停止录入' : '开始录入');
            setState(() => _enrolling = !_enrolling);
          },
        ),
        _ActionChip(
          label: _recording ? '停止录制' : '开始录制',
          on: _recording,
          onTap: () {
            widget.onSend(_recording ? Cmd.stopRecord : Cmd.startRecord,
                _recording ? '停止录制' : '开始录制');
            setState(() => _recording = !_recording);
          },
        ),
        _ActionChip(
          label: '执行人脸录入',
          onTap: () => widget.onSend(Cmd.enrollFace, '执行人脸录入'),
        ),
        _ActionChip(
          label: '回主页',
          onTap: () => widget.onSend(Cmd.goHome, '回主页'),
        ),
        const Divider(height: 16),
        _ActionChip(label: '设置页', onTap: () => widget.onSend(Cmd.goSettings, '去设置页')),
        _ActionChip(label: '录入页', onTap: () => widget.onSend(Cmd.goEnrollPage, '去录入页')),
        _ActionChip(label: '融合播放', onTap: () => widget.onSend(Cmd.fusionPage, '融合播放页')),
        _ActionChip(label: '录像列表', onTap: () => widget.onSend(Cmd.recordingsPage, '录像列表页')),
      ],
    );
  }
}

class _DangerOps extends StatelessWidget {
  final void Function(String, VoidCallback) onConfirm;
  final void Function(Map<String, dynamic>, String) onSend;
  const _DangerOps({required this.onConfirm, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _ActionChip(
          label: '清空人脸库',
          danger: true,
          onTap: () => onConfirm('清空人脸库', () => onSend(Cmd.clearFaces, '清空人脸库')),
        ),
        _ActionChip(
          label: '清空录像',
          danger: true,
          onTap: () => onConfirm('清空录像', () => onSend(Cmd.clearRecordings, '清空录像')),
        ),
        _ActionChip(
          label: '退出下位程序',
          danger: true,
          onTap: () => onConfirm('退出下位程序', () => onSend(Cmd.exitApp, '退出下位程序')),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool on;
  final bool danger;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.onTap, this.on = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final fg = danger
        ? AppColors.red
        : on
            ? AppColors.accent
            : AppColors.textPrimary;
    final bg = danger
        ? AppColors.redDim
        : on
            ? AppColors.accentDim
            : AppColors.bgHover;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fg),
          ),
          child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

/// 卡片容器：标题 + 可选 trailing + body。对齐 HTML .card。
class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Widget child;
  final Color? tone;
  const _Card({required this.title, required this.icon, this.trailing, required this.child, this.tone});

  @override
  Widget build(BuildContext context) {
    final t = tone ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: t),
              const SizedBox(width: 8),
              Text(title,
                style: TextStyle(color: t, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

/// 识别录像日志卡片：列出 [FaceRecordService.log] 中的历史录像事件，
/// 带索引号；点击条目跳转回放页并自动播放对应录像。
class _FaceRecordLogCard extends StatelessWidget {
  final AppServices svc;
  const _FaceRecordLogCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: '识别录像日志',
      icon: Icons.video_library,
      trailing: ValueListenableBuilder<List<FaceRecordEvent>>(
        valueListenable: svc.faceRecord.log,
        builder: (_, list, _) =>
            _Tag('${list.length} 条', AppColors.greenDim, AppColors.green),
      ),
      child: ValueListenableBuilder<List<FaceRecordEvent>>(
        valueListenable: svc.faceRecord.log,
        builder: (_, list, _) {
          if (list.isEmpty) {
            return SizedBox(
              height: 56,
              child: const Center(
                child: Text('暂无识别录像',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            );
          }
          final shown = list.length > 50 ? list.sublist(0, 50) : list;
          return Container(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: shown.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _FaceLogTile(
                ev: shown[i],
                onTap: () => Navigator.pushNamed(
                  context,
                  '/playback',
                  arguments: shown[i].videoPath,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FaceLogTile extends StatelessWidget {
  final FaceRecordEvent ev;
  final VoidCallback onTap;
  const _FaceLogTile({required this.ev, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(ev.startIso);
    final timeStr = dt == null
        ? ev.startIso
        : DateFormat('MM-dd HH:mm:ss').format(dt.toLocal());
    final labels =
        ev.faceLabels.isEmpty ? '' : ' · ${ev.faceLabels.join(', ')}';
    final stranger = ev.hasStranger ? ' · 含陌生人' : '';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: SizedBox(
        width: 34,
        child: Text('#${ev.id}',
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Consolas')),
      ),
      title: Text('$timeStr  ·  ${ev.durationSec}s',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      subtitle: Text(
        '${ev.videoName} · 人数 ${ev.maxFaceCount}$stranger$labels',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: ev.hasStranger
          ? _Tag('陌生人', AppColors.redDim, AppColors.red)
          : const Icon(Icons.play_circle_outline, size: 20, color: AppColors.accent),
      onTap: onTap,
    );
  }
}
