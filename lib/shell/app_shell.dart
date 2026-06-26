import 'package:flutter/material.dart';

import '../pages/alarm_page.dart';
import '../pages/device_page.dart';
import '../pages/monitor_page.dart';
import '../pages/peripheral_page.dart';
import '../services/command_service.dart';
import '../services/config_service.dart';
import '../services/recorder_service.dart';
import '../services/rtsp_service.dart';
import '../services/status_poll_service.dart';
import '../theme/app_colors.dart';
import '../widgets/top_bar.dart';
import 'app_services.dart';
import 'nav_destinations.dart';

/// 响应式 Shell：宽屏左侧自定义侧栏，窄屏底部 Tab。
///
/// 持有全应用共享的 [AppServices]，经 [AppServicesScope] 暴露给子树。
/// 四页用 [IndexedStack] 切换以保留各页状态（RTSP 播放器、滚动位置等）。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final RtspService _rtsp = RtspService();
  late final RecorderService _recorder;
  late StatusPollService _statusPoll;
  late CommandService _command;
  late AppServices _svc;
  int _index = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _recorder = createRecorder(_rtsp);
    _initAsync();
  }

  Future<void> _initAsync() async {
    final c = await ConfigService.load();
    _statusPoll = StatusPollService(statusUrl: c.statusUrl, intervalMs: c.pollIntervalMs);
    _command = CommandService(c.commandUrl);
    _svc = AppServices(
      rtsp: _rtsp,
      recorder: _recorder,
      statusPoll: _statusPoll,
      command: _command,
      config: c,
    );
    if (mounted) setState(() => _ready = true);
  }

  /// 设置页返回后用最新配置重建 statusPoll/command（rtsp/recorder 保留）。
  Future<void> _reloadConfig() async {
    final c = await ConfigService.load();
    final wasRunning = _statusPoll.isRunning;
    _statusPoll.dispose();
    _statusPoll = StatusPollService(statusUrl: c.statusUrl, intervalMs: c.pollIntervalMs);
    _command = CommandService(c.commandUrl);
    if (wasRunning) _statusPoll.start();
    if (!mounted) return;
    setState(() {
      _svc = AppServices(
        rtsp: _rtsp,
        recorder: _recorder,
        statusPoll: _statusPoll,
        command: _command,
        config: c,
      );
    });
  }

  @override
  void dispose() {
    _statusPoll.dispose();
    _recorder.dispose();
    _rtsp.dispose();
    super.dispose();
  }

  String get _displayIp {
    final url = _svc.config.statusUrl;
    // 从 http://192.168.x.x:8001/status 提取 host:port
    final m = RegExp(r'://([^/]+)').firstMatch(url);
    return m?.group(1) ?? url;
  }

  void _openSettings() async {
    await Navigator.pushNamed(context, '/settings');
    if (!mounted) return;
    await _reloadConfig();
  }

  /// 按需构建非监控页（监控页由 Stack 常驻）。
  Widget _page(int i) {
    switch (i) {
      case 1:
        return const PeripheralPage();
      case 2:
        return const DevicePage();
      default:
        return const AlarmPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppServicesScope(
      data: _svc,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= kBreakpoint;
          final body = Column(
            children: [
              TopBar(
                breadcrumb: kNavDestinations[_index].label,
                status: _statusPoll.status,
                error: _statusPoll.error,
                ip: _displayIp,
                compact: !wide,
                currentIndex: _index,
                onNavigate: (i) => setState(() => _index = i),
                onSettings: _openSettings,
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                // 监控页常驻（Video 不 remount，避免纹理重建崩）；
                // 不可见时 Visibility 阻断 semantics 且 maintainSize 保持尺寸
                // （Video 不被缩到 size 0）。其他页按需叠在上层，启动时
                // in-tree 仅当前页，semetics 节点最少，规避 AXTree 崩溃。
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Visibility(
                        visible: _index == 0,
                        maintainState: true,
                        maintainSize: true,
                        maintainAnimation: true,
                        child: const MonitorPage(),
                      ),
                    ),
                    if (_index != 0)
                      Positioned.fill(child: _page(_index)),
                  ],
                ),
              ),
            ],
          );

          if (wide) {
            return Scaffold(
              backgroundColor: AppColors.bgPrimary,
              body: Row(
                children: [
                  _SideRail(
                    index: _index,
                    onChanged: (i) => setState(() => _index = i),
                    onSettings: _openSettings,
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(child: body),
                ],
              ),
            );
          }
          return Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: body,
            bottomNavigationBar: _BottomNav(
              index: _index,
              onChanged: (i) => setState(() => _index = i),
            ),
          );
        },
      ),
    );
  }
}

/// 宽屏左侧导航栏：logo + 导航项 + 底部版本/设置。仿 HTML .sidebar。
class _SideRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onSettings;
  const _SideRail({required this.index, required this.onChanged, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.bgSecondary,
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.accent, AppColors.purple],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: const Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('智能门禁管理',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Access Control System',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          // 导航项
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (int i = 0; i < kNavDestinations.length; i++)
                  _RailItem(
                    dest: kNavDestinations[i],
                    selected: i == index,
                    onTap: () => onChanged(i),
                  ),
                const Divider(color: AppColors.border, height: 16),
                _RailItem(
                  dest: const NavDest(
                    key: 'settings',
                    label: '系统设置',
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                  ),
                  selected: false,
                  onTap: onSettings,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: const Text('v1.0.0 | K230 + STM32',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final NavDest dest;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem({required this.dest, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentDim : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected ? dest.selectedIcon : dest.icon,
                size: 18,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                dest.label,
                style: TextStyle(
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: onChanged,
      items: [
        for (final d in kNavDestinations)
          BottomNavigationBarItem(icon: Icon(d.icon), activeIcon: Icon(d.selectedIcon), label: d.label),
      ],
    );
  }
}
