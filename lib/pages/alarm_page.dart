import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/alarm_banner.dart';

/// 报警记录页：报警横幅 + 筛选栏 + 表格。静态 mock 数据。
///
/// 当前协议不直接上报报警历史，数据为本地示例，与 HTML 参考一致。
class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  String _type = '全部类型';
  String _status = '全部';

  static const _types = ['全部类型', '陌生人报警', '密码错误', '未授权 NFC', '设备离线'];
  static const _statuses = ['全部', '未处理', '已处理', '已忽略'];

  static const _rows = [
    _AlarmRow('14:32:05', '陌生人', '检测到未注册人脸', '置信度 87%', '未处理', AppColors.red),
    _AlarmRow('11:52:17', '密码错误', '连续 5 次密码错误', '键盘已锁定 3 分钟', '已处理', AppColors.yellow),
    _AlarmRow('09:15:33', '陌生人', '检测到未注册人脸', '置信度 83%', '已处理', AppColors.red),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _rows.where((r) {
      final typeOk = _type == '全部类型' || r.typeLabel == _type.replaceFirst('报警', '');
      final statusOk = _status == '全部' || r.status == _status;
      return typeOk && statusOk;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AlarmBanner(
              message: '当前有 1 条未处理报警：陌生人检测 (14:32)',
              time: '5 分钟前',
              onView: () {},
            ),
            // 筛选栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  _filterLabel('时间'),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: '2026-06-25',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                    ),
                  ),
                  _filterLabel('类型'),
                  _dropdown(_types, _type, (v) => setState(() => _type = v)),
                  _filterLabel('状态'),
                  _dropdown(_statuses, _status, (v) => setState(() => _status = v)),
                  _MiniBtn.primary('查询', () {}),
                ],
              ),
            ),
            // 表格
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  headingRowHeight: 36,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 40,
                  headingTextStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  dataTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  columns: const [
                    DataColumn(label: Text('时间')),
                    DataColumn(label: Text('类型')),
                    DataColumn(label: Text('描述')),
                    DataColumn(label: Text('详情')),
                    DataColumn(label: Text('状态')),
                    DataColumn(label: Text('操作')),
                  ],
                  rows: filtered
                      .map((r) => DataRow(cells: [
                            DataCell(Text(r.time,
                                style: const TextStyle(fontFamily: 'Consolas', color: AppColors.textSecondary))),
                            DataCell(_Tag(r.typeLabel, r.toneDim, r.tone)),
                            DataCell(Text(r.desc)),
                            DataCell(Text(r.detail)),
                            DataCell(_Tag(r.status,
                                r.status == '未处理' ? AppColors.redDim : AppColors.greenDim,
                                r.status == '未处理' ? AppColors.red : AppColors.green)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (r.status == '未处理') ...[
                                  _MiniBtn('处理', () {}),
                                  const SizedBox(width: 6),
                                  _MiniBtn('忽略', () {}),
                                ] else
                                  _MiniBtn('详情', () {}),
                              ],
                            )),
                          ]))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterLabel(String text) => Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12));

  Widget _dropdown(List<String> items, String value, ValueChanged<String> onChanged) {
    return DropdownButton<String>(
      value: value,
      underline: const SizedBox(),
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      dropdownColor: AppColors.bgCard,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}

class _AlarmRow {
  final String time;
  final String typeLabel;
  final String desc;
  final String detail;
  final String status;
  final Color tone;
  const _AlarmRow(this.time, this.typeLabel, this.desc, this.detail, this.status, this.tone);

  Color get toneDim {
    if (tone == AppColors.red) return AppColors.redDim;
    if (tone == AppColors.yellow) return AppColors.yellowDim;
    return AppColors.bgHover;
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _MiniBtn(this.label, this.onTap, {this.primary = false});

  factory _MiniBtn.primary(String label, VoidCallback onTap) => _MiniBtn(label, onTap, primary: true);

  @override
  Widget build(BuildContext context) {
    final fg = primary ? AppColors.accent : AppColors.textPrimary;
    final bg = primary ? AppColors.accentDim : AppColors.bgHover;
    final border = primary ? AppColors.accent : AppColors.border;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Text(label, style: TextStyle(color: fg, fontSize: 11)),
        ),
      ),
    );
  }
}
