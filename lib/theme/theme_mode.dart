import 'package:flutter/foundation.dart';

/// 全局主题模式：false=浅色（白底），true=深色（黑底）。
/// 由顶栏切换按钮控制，MaterialApp 监听重建。
final isDark = ValueNotifier<bool>(false);
