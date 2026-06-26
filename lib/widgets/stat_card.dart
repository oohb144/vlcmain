import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 统计卡片：上方小标签 + 大数值 + 下方副文。对齐 HTML 的 .stat-card。
///
/// [tone] 控制数值颜色：accent / green / red / yellow / default。
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final double? valueSize;
  final StatTone tone;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueSize,
    this.tone = StatTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
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
              color: _valueColor,
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
    );
  }

  Color get _valueColor => switch (tone) {
        StatTone.accent => AppColors.accent,
        StatTone.green => AppColors.green,
        StatTone.red => AppColors.red,
        StatTone.yellow => AppColors.yellow,
        StatTone.neutral => AppColors.textPrimary,
      };
}

enum StatTone { neutral, accent, green, red, yellow }
