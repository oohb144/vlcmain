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
    return Container(
      padding: EdgeInsets.all(node.compact ? 10 : 16),
      decoration: BoxDecoration(
        color: accent ? AppColors.accentDim : AppColors.bgCard,
        border: Border.all(
          color: accent ? AppColors.accent : AppColors.border,
          width: accent ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(node.compact ? 8 : 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(node.icon, size: node.compact ? 20 : 28, color: accent ? AppColors.accent : AppColors.textPrimary),
          const SizedBox(height: 6),
          Text(
            node.name,
            style: TextStyle(
              color: accent ? AppColors.accent : AppColors.textPrimary,
              fontSize: node.compact ? 10 : 11,
              fontWeight: accent ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            node.online ? '● 在线' : '● 离线',
            style: TextStyle(
              color: node.online ? AppColors.green : AppColors.textMuted,
              fontSize: 10,
            ),
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
      color: active ? AppColors.green : AppColors.border,
    );
  }
}
