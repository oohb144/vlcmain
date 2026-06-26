import 'package:flutter/material.dart';

/// 导航项定义：四页核心 + 图标 + 标签。
class NavDest {
  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const NavDest({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

const kNavDestinations = <NavDest>[
  NavDest(key: 'monitor', label: '实时监控', icon: Icons.visibility_outlined, selectedIcon: Icons.visibility),
  NavDest(key: 'peripheral', label: '外围设备', icon: Icons.lock_outline, selectedIcon: Icons.lock_open),
  NavDest(key: 'device', label: '设备管理', icon: Icons.router_outlined, selectedIcon: Icons.router),
  NavDest(key: 'alarm', label: '报警记录', icon: Icons.notifications_none_outlined, selectedIcon: Icons.notifications_active),
];

const kBreakpoint = 900.0;
