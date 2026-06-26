import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 设备拓扑图：K230摄像头 — 麦克风 — STM32主控 — 外设群。
///
/// 节点在线状态由 [nodes] 的 online 字段决定；横向线性布局。
class DeviceTopology extends StatelessWidget {
  final List<TopoNode> nodes;
  const DeviceTopology({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      children.add(_TopoNode(node: nodes[i]));
      if (i != nodes.length - 1) {
        children.add(_TopoLine(active: nodes[i].online && nodes[i + 1].online));
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 8,
        children: children,
      ),
    );
  }
}

class TopoNode {
  final IconData icon;
  final String name;
  final bool online;
  final bool isCenter;
  final bool compact; // 外设群的小节点

  const TopoNode({
    required this.icon,
    required this.name,
    this.online = true,
    this.isCenter = false,
    this.compact = false,
  });
}

class _TopoNode extends StatelessWidget {
  final TopoNode node;
  const _TopoNode({required this.node});

  @override
  Widget build(BuildContext context) {
    final accent = node.isCenter;
    final nodeColor = accent ? AppColors.accent : AppColors.textPrimary;
    return Container(
      padding: EdgeInsets.all(node.compact ? 10 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(node.compact ? 8 : 10),
        border: Border.all(
          color: accent ? AppColors.accent : AppColors.border,
          width: accent ? 1.5 : 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: accent
              ? [AppColors.accentDim, AppColors.bgCard]
              : [AppColors.bgCard, AppColors.bgSecondary],
        ),
        boxShadow: accent
            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 10, spreadRadius: 0)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: node.compact ? 26 : 36,
            height: node.compact ? 26 : 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: nodeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(node.compact ? 6 : 8),
            ),
            child: Icon(node.icon, size: node.compact ? 16 : 22, color: nodeColor),
          ),
          const SizedBox(height: 6),
          Text(
            node.name,
            style: TextStyle(
              color: nodeColor,
              fontSize: node.compact ? 10 : 11,
              fontWeight: accent ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: node.online ? AppColors.green : AppColors.textMuted,
                  shape: BoxShape.circle,
                  boxShadow: node.online
                      ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.6), blurRadius: 4)]
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                node.online ? '在线' : '离线',
                style: TextStyle(
                  color: node.online ? AppColors.green : AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopoLine extends StatelessWidget {
  final bool active;
  const _TopoLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: active
              ? [AppColors.green.withValues(alpha: 0.2), AppColors.green, AppColors.green.withValues(alpha: 0.2)]
              : [AppColors.border, AppColors.textMuted.withValues(alpha: 0.5), AppColors.border],
        ),
        boxShadow: active
            ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.4), blurRadius: 3)]
            : null,
      ),
    );
  }
}
