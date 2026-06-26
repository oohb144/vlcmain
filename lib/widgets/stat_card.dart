import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 统计卡片：上方小标签 + 大数值 + 下方副文 + 可选图标 + 左侧色条。
///
/// 美化：按 [tone] 取色的顶部微渐变 + 左侧 3px 色条 + 右上图标色块，
/// 对齐现代深色仪表盘风格。
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final double? valueSize;
  final StatTone tone;
  final IconData? icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueSize,
    this.tone = StatTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = _toneColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.withValues(alpha: 0.10), AppColors.bgCard],
        ),
      ),
      child: Row(
        children: [
          // 左侧色条
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: c,
                    fontSize: valueSize ?? 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Consolas',
                  ),
                ),
                if (sub != null)
                  Text(sub!,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (icon != null)
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: c),
            ),
        ],
      ),
    );
  }

  Color get _toneColor => switch (tone) {
        StatTone.accent => AppColors.accent,
        StatTone.green => AppColors.green,
        StatTone.red => AppColors.red,
        StatTone.yellow => AppColors.yellow,
        StatTone.neutral => AppColors.textPrimary,
      };
}

enum StatTone { neutral, accent, green, red, yellow }
