import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 可折叠面板：对齐 HTML 的 .collapse-panel。
///
/// [header] 左侧内容（标题）；[trailing] 右侧附加（如状态标签）；
/// [body] 展开后内容。点击 header 切换展开。
class CollapsePanel extends StatefulWidget {
  final Widget header;
  final Widget? trailing;
  final Widget body;
  final bool initiallyOpen;
  final EdgeInsetsGeometry bodyPadding;

  const CollapsePanel({
    super.key,
    required this.header,
    this.trailing,
    required this.body,
    this.initiallyOpen = false,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  @override
  State<CollapsePanel> createState() => _CollapsePanelState();
}

class _CollapsePanelState extends State<CollapsePanel> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyOpen;
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _open ? 1 : 0,
    );
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      child: widget.header,
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    widget.trailing!,
                    const SizedBox(width: 8),
                  ],
                  RotationTransition(
                    turns: _a.drive(Tween(begin: 0, end: 0.25)),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _a,
            alignment: Alignment.topCenter,
            child: Padding(padding: widget.bodyPadding, child: widget.body),
          ),
        ],
      ),
    );
  }
}
