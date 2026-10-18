import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine_state.dart';

/// 演奏页当前显示的音色组（0 = A，1 = B …）——纯 UI 状态。
class BankController extends Notifier<int> {
  @override
  int build() {
    // 加载新 Kit 时翻回 A（APK：KitLoaded → A）
    ref.listen(
      engineViewProvider.select((v) => v.kit?.id),
      (_, _) => state = 0,
    );
    return 0;
  }

  void set(int bank) => state = bank;
}

final bankProvider = NotifierProvider<BankController, int>(BankController.new);
