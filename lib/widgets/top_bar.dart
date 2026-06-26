import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../shell/nav_destinations.dart';
import '../theme/app_colors.dart';
import 'status_dot.dart';

/// 顶栏：左侧面包屑 + 控制仪表盘按钮 + 右侧 K230/STM32 在线状态点 + IP + 时钟。
///
/// [status] / [error] 来自 [StatusPollService]，据此决定 K230 在线点颜色；
/// STM32 在线点用 [stm32Online] 独立传入（当前协议不直接上报 STM32，
/// 默认与 K230 一致或由上层给定）。
///
/// 控制仪表盘按钮点击弹出快捷菜单：四页切换 + 系统设置。
class TopBar extends StatefulWidget {
  final String breadcrumb;
  final ValueNotifier<dynamic> status; // DeviceStatus?
  final ValueNotifier<String?> error;
  final String ip;
  final bool stm32Online;
  final bool compact; // 手机模式：隐藏 IP，保留状态点+时钟
  final int currentIndex;
  final ValueChanged<int>? onNavigate; // 切页回调，null 时不显示控制台按钮
  final VoidCallback? onSettings;

  const TopBar({
    super.key,
    required this.breadcrumb,
    required this.status,
    required this.error,
    required this.ip,
    this.stm32Online = true,
    this.compact = false,
    this.currentIndex = 0,
    this.onNavigate,
    this.onSettings,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late final ValueNotifier<String> _clock;

  @override
  void initState() {
    super.initState();
    _clock = ValueNotifier(_now());
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      _clock.value = _now();
      return true;
    });
  }

  String _now() {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.breadcrumb,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onNavigate != null) _dashboardButton(),
          const SizedBox(width: 8),
          ValueListenableBuilder2(widget.status, widget.error, (status, err) {
            final k230Online = err == null && status != null;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Indicator(
                  dot: k230Online ? StatusDotState.online : StatusDotState.offline,
                  text: 'K230',
                ),
                const SizedBox(width: 14),
                _Indicator(
                  dot: widget.stm32Online ? StatusDotState.online : StatusDotState.offline,
                  text: 'STM32',
                ),
                if (!widget.compact) ...[
                  const SizedBox(width: 14),
                  Text(
                    widget.ip,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(width: 14),
                // 时钟每秒更新：ExcludeSemantics + RepaintBoundary 隔离，
                // 避免每秒触发整树 accessibility 更新（AXTree 崩溃诱因）。
                ExcludeSemantics(
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _clock,
                      builder: (_, v, _) => Text(
                        v,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontFamily: 'Consolas',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 控制仪表盘按钮：点击弹出快捷菜单（四页切换 + 系统设置）。
  Widget _dashboardButton() {
    return PopupMenuButton<int>(
      tooltip: '控制仪表盘',
      icon: const Icon(Icons.apps, color: AppColors.textPrimary, size: 20),
      position: PopupMenuPosition.under,
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (_) => [
        for (int i = 0; i < kNavDestinations.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(
                  widget.currentIndex == i
                      ? kNavDestinations[i].selectedIcon
                      : kNavDestinations[i].icon,
                  size: 18,
                  color: widget.currentIndex == i
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  kNavDestinations[i].label,
                  style: TextStyle(
                    color: widget.currentIndex == i
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<int>(
          value: -1,
          child: Row(
            children: [
              Icon(Icons.settings, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('系统设置',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            ],
          ),
        ),
      ],
      onSelected: (v) {
        if (v == -1) {
          widget.onSettings?.call();
        } else {
          widget.onNavigate?.call(v);
        }
      },
    );
  }
}

class _Indicator extends StatelessWidget {
  final StatusDotState dot;
  final String text;
  const _Indicator({required this.dot, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(state: dot),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

/// 同时监听两个 ValueNotifier 的小工具（避免嵌套 Builder）。
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> a;
  final ValueListenable<B> b;
  final Widget Function(A a, B b) builder;

  const ValueListenableBuilder2(this.a, this.b, this.builder, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: a,
      builder: (_, av, _) => ValueListenableBuilder<B>(
        valueListenable: b,
        builder: (_, bv, _) => builder(av, bv),
      ),
    );
  }
}
