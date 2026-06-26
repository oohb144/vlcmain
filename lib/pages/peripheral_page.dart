import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/collapse_panel.dart';
import '../widgets/stat_card.dart';

/// 外围设备页（门禁管理）：纯静态界面 + 模拟数据。
///
/// 外设物理上接在 STM32，当前协议无对应 cmd，故仅展示。布局对齐 HTML
/// 的 page-access：4 个开门方式统计卡 + 指纹/NFC/键盘/互锁/显示屏折叠面板。
class PeripheralPage extends StatefulWidget {
  const PeripheralPage({super.key});

  @override
  State<PeripheralPage> createState() => _PeripheralPageState();
}

class _PeripheralPageState extends State<PeripheralPage> {
  // 本地 mock 态（交互在本地生效，不下发）
  double _fingerThreshold = 80;
  double _screenBrightness = 70;
  String _fingerOnMiss = '报警 + 记录';
  String _nfcOnMiss = '报警 + 记录';
  String _password = '123456';
  int _pwdErrorLimit = 5;
  int _pwdLockMin = 3;
  String _standbyText = '欢迎回家';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // 开门方式状态卡
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: wide ? 4 : 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: const [
                  StatCard(label: '人脸开门', value: '已启用', sub: '今日 8 次', valueSize: 18, tone: StatTone.green),
                  StatCard(label: '指纹开门', value: '已启用', sub: '今日 4 次', valueSize: 18, tone: StatTone.green),
                  StatCard(label: 'NFC 刷卡', value: '已启用', sub: '今日 3 次', valueSize: 18, tone: StatTone.green),
                  StatCard(label: '密码开门', value: '已启用', sub: '今日 2 次', valueSize: 18, tone: StatTone.green),
                ],
              ),
              const SizedBox(height: 16),
              // 折叠面板
              _buildFingerprint(),
              _buildNfc(),
              _buildKeypad(),
              _buildInterlockRules(),
              _buildScreen(),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _onlineTag() => _Tag('在线', AppColors.greenDim, AppColors.green);

  Widget _buildFingerprint() {
    return CollapsePanel(
      header: const Row(children: [
        Icon(Icons.fingerprint, size: 18, color: AppColors.accent),
        SizedBox(width: 8),
        Text('指纹模块'),
      ]),
      trailing: _onlineTag(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formRow('已录入指纹', const Text('5 枚')),
          _formRow(
            '比对阈值',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  child: Slider(
                    min: 50,
                    max: 100,
                    divisions: 50,
                    value: _fingerThreshold,
                    label: '${_fingerThreshold.toInt()}%',
                    onChanged: (v) => setState(() => _fingerThreshold = v),
                  ),
                ),
                Text('${_fingerThreshold.toInt()}%',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ],
            ),
          ),
          _formRow(
            '未匹配时',
            DropdownButton<String>(
              value: _fingerOnMiss,
              underline: const SizedBox(),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              dropdownColor: AppColors.bgCard,
              items: const ['报警 + 记录', '仅记录', '忽略'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _fingerOnMiss = v ?? _fingerOnMiss),
            ),
          ),
          _formRow(
            '操作',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniBtn.primary('录入指纹', () {}),
                const SizedBox(width: 8),
                _MiniBtn('管理列表', () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNfc() {
    return CollapsePanel(
      header: const Row(children: [
        Icon(Icons.nfc, size: 18, color: AppColors.purple),
        SizedBox(width: 8),
        Text('NFC 射频读卡'),
      ]),
      trailing: _onlineTag(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formRow('已注册卡片', const Text('3 张')),
          _formRow('卡类型', const Text('Mifare Classic / ISO14443A')),
          _formRow(
            '未授权卡',
            DropdownButton<String>(
              value: _nfcOnMiss,
              underline: const SizedBox(),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              dropdownColor: AppColors.bgCard,
              items: const ['报警 + 记录', '仅记录', '忽略'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _nfcOnMiss = v ?? _nfcOnMiss),
            ),
          ),
          _formRow(
            '已注册卡号',
            const Text('A3:F2:01 (张三) | B7:C4:09 (李四) | D1:E8:22 (王五)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Consolas')),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return CollapsePanel(
      header: const Row(children: [
        Icon(Icons.dialpad, size: 18, color: AppColors.yellow),
        SizedBox(width: 8),
        Text('矩阵键盘'),
      ]),
      trailing: _onlineTag(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formRow('键盘类型', const Text('4x4 矩阵键盘')),
          _formRow(
            '当前密码',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: _password,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                    onChanged: (v) => _password = v,
                  ),
                ),
                const SizedBox(width: 8),
                _MiniBtn('修改', () {}),
              ],
            ),
          ),
          _formRow(
            '错误锁定',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('连续'),
                SizedBox(
                  width: 36,
                  child: TextFormField(
                    initialValue: _pwdErrorLimit.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                    onChanged: (v) => _pwdErrorLimit = int.tryParse(v) ?? _pwdErrorLimit,
                  ),
                ),
                const Text('次锁定'),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  child: TextFormField(
                    initialValue: _pwdLockMin.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                    onChanged: (v) => _pwdLockMin = int.tryParse(v) ?? _pwdLockMin,
                  ),
                ),
                const Text('分钟'),
              ],
            ),
          ),
          _formRow('键盘状态', _Tag('正常', AppColors.greenDim, AppColors.green)),
        ],
      ),
    );
  }

  Widget _buildInterlockRules() {
    return CollapsePanel(
      header: const Row(children: [
        Icon(Icons.account_tree_outlined, size: 18, color: AppColors.accent),
        SizedBox(width: 8),
        Text('互锁逻辑规则'),
      ]),
      trailing: _Tag('3 条规则', AppColors.accentDim, AppColors.accent),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rulesTable(),
          const SizedBox(height: 10),
          _MiniBtn.primary('+ 添加规则', () {}),
        ],
      ),
    );
  }

  Widget _rulesTable() {
    final rows = [
      ('1', '人脸验证通过', '单一认证', '开门', '启用', AppColors.green),
      ('2', 'NFC 刷卡成功', '单一认证', '开门', '启用', AppColors.green),
      ('3', '陌生人人脸', '异常', '报警+录像+音频', '启用', AppColors.green),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingTextStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        dataTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('条件')),
          DataColumn(label: Text('类型')),
          DataColumn(label: Text('动作')),
          DataColumn(label: Text('状态')),
          DataColumn(label: Text('操作')),
        ],
        rows: rows
            .map((r) => DataRow(cells: [
                  DataCell(Text(r.$1)),
                  DataCell(Text(r.$2)),
                  DataCell(_Tag(r.$3, r.$3 == '异常' ? AppColors.redDim : AppColors.bgHover, r.$3 == '异常' ? AppColors.red : AppColors.textMuted)),
                  DataCell(Text(r.$4)),
                  DataCell(_Tag(r.$5, AppColors.greenDim, AppColors.green)),
                  DataCell(_MiniBtn('编辑', () {})),
                ]))
            .toList(),
      ),
    );
  }

  Widget _buildScreen() {
    return CollapsePanel(
      header: const Row(children: [
        Icon(Icons.screen_share_outlined, size: 18, color: AppColors.green),
        SizedBox(width: 8),
        Text('门口显示屏'),
      ]),
      trailing: _onlineTag(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formRow(
            '待机显示文字',
            SizedBox(
              width: 140,
              child: TextFormField(
                initialValue: _standbyText,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                onChanged: (v) => _standbyText = v,
              ),
            ),
          ),
          _formRow(
            '亮度',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  child: Slider(
                    min: 0,
                    max: 100,
                    divisions: 100,
                    value: _screenBrightness,
                    label: '${_screenBrightness.toInt()}%',
                    onChanged: (v) => setState(() => _screenBrightness = v),
                  ),
                ),
                Text('${_screenBrightness.toInt()}%',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ],
            ),
          ),
          _formRow('测试', _MiniBtn.primary('发送文字到屏幕', () {})),
        ],
      ),
    );
  }

  Widget _formRow(String label, Widget value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          value,
        ],
      ),
    );
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
