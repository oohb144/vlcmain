import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 状态圆点：在线(绿，带辉光) / 离线(灰) / 报警(红，闪烁)。
class StatusDot extends StatelessWidget {
  final StatusDotState state;
  final double size;

  const StatusDot({super.key, required this.state, this.size = 8});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case StatusDotState.online:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.6), blurRadius: 6)],
          ),
        );
      case StatusDotState.alarm:
        return _BlinkDot(color: AppColors.red, size: size);
      case StatusDotState.offline:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.textMuted,
            shape: BoxShape.circle,
          ),
        );
    }
  }
}

enum StatusDotState { online, offline, alarm }

class _BlinkDot extends StatefulWidget {
  final Color color;
  final double size;
  const _BlinkDot({required this.color, required this.size});

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _a = Tween(begin: 1.0, end: 0.4).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
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
        animation: _a,
        builder: (_, child) => Opacity(opacity: _a.value, child: child),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}
