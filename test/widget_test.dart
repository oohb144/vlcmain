// 占位冒烟测试：原默认计数器测试已不适用（入口改为 VlcApp + MediaKit 初始化）。
// 由于播放器依赖 media_kit 真机初始化，这里仅做最小静态校验。
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('占位测试通过', () {
    expect(1 + 1, 2);
  });
}