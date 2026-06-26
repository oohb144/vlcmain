import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 事件类型：决定图标色块颜色。
enum EventKind { face, fingerprint, nfc, keypad, alarm, info }

extension EventKindExt on EventKind {
  Color get bg => switch (this) {
        EventKind.face => AppColors.greenDim,
        EventKind.fingerprint => AppColors.accentDim,
        EventKind.nfc => AppColors.purpleDim,
        EventKind.keypad => AppColors.yellowDim,
        EventKind.alarm => AppColors.redDim,
        EventKind.info => AppColors.bgHover,
      };

  IconData get icon => switch (this) {
        EventKind.face => Icons.face,
        EventKind.fingerprint => Icons.fingerprint,
        EventKind.nfc => Icons.nfc,
        EventKind.keypad => Icons.dialpad,
        EventKind.alarm => Icons.warning_amber,
        EventKind.info => Icons.info_outline,
      };

  Color get fg => switch (this) {
        EventKind.face => AppColors.green,
        EventKind.fingerprint => AppColors.accent,
        EventKind.nfc => AppColors.purple,
        EventKind.keypad => AppColors.yellow,
        EventKind.alarm => AppColors.red,
        EventKind.info => AppColors.textSecondary,
      };
}

/// 事件流条目：图标色块 + 标题 + meta + 时间。对齐 HTML .event-item。
class EventItem {
  final EventKind kind;
  final String title;
  final String? meta;
  final DateTime time;
  const EventItem({
    required this.kind,
    required this.title,
    this.meta,
    required this.time,
  });
}

class EventTile extends StatelessWidget {
  final EventItem item;
  const EventTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isAlarm = item.kind == EventKind.alarm;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              color: item.kind.bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(item.kind.icon, size: 14, color: item.kind.fg),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: isAlarm ? AppColors.red : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.meta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.meta!,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _hhmm(item.time),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'Consolas'),
          ),
        ],
      ),
    );
  }

  String _hhmm(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}

/// 事件流容器：固定最大高度可滚动，列表项间用细分隔。
class EventStream extends StatelessWidget {
  final List<EventItem> items;
  final double maxHeight;
  const EventStream({super.key, required this.items, this.maxHeight = 360});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: maxHeight,
        child: const Center(
          child: Text('暂无事件', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      );
    }
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) => EventTile(item: items[i]),
      ),
    );
  }
}
