import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 报警横幅：红色脉冲边框 + 文案 + 时间 + 可选动作按钮。对齐 HTML .alarm-banner。
class AlarmBanner extends StatelessWidget {
  final String message;
  final String? time;
  final VoidCallback? onView;
  const AlarmBanner({super.key, required this.message, this.time, this.onView});

  @override
  Widget build(BuildContext context) {
    return _PulseBox(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.redDim,
          border: Border.all(color: AppColors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            if (time != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(time!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ),
            if (onView != null) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 28),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: onView,
                child: const Text('查看'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 边框颜色周期性淡入淡出，模拟 HTML 的 alarm-pulse 动画。
class _PulseBox extends StatefulWidget {
  final Widget child;
  const _PulseBox({required this.child});

  @override
  State<_PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<_PulseBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          // 只做透明度脉冲；child 自带红边，整体观感即 HTML 的边框脉冲
          return Opacity(opacity: 0.65 + 0.35 * _c.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
