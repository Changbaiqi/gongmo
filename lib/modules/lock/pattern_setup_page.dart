// ============================================================
// pattern_setup_page.dart（锁屏模块 · 图案设置页）
// 职责：设置/修改解锁图案的三步流程——验证旧图案 → 绘制新图案 → 再次确认，
//       确认一致后写入 LockController。
// 关联：LockController（verifyPattern/savePattern）；由设置页“应用锁/修改
//       解锁图案”入口或开启应用锁时进入，成功后返回 true。
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/pattern_lock.dart';
import 'lock_controller.dart';

/// 图案设置流程的三个状态：验证旧图案 → 绘制新图案 → 二次确认
enum _SetupStep { verify, draw, confirm }

/// 设置/修改解锁图案：先验证旧图案（若已设置），再绘制并确认新图案。
///
/// 首次设置时跳过 verify 直接从 draw 开始；修改时三步齐全。
/// 两次绘制必须完全一致（listEquals 比较点顺序）才会保存。
class PatternSetupPage extends StatefulWidget {
  const PatternSetupPage({super.key});

  @override
  State<PatternSetupPage> createState() => _PatternSetupPageState();
}

class _PatternSetupPageState extends State<PatternSetupPage> {
  final LockController _ctrl = Get.find<LockController>();

  late _SetupStep _step =
      _ctrl.hasPattern.value ? _SetupStep.verify : _SetupStep.draw;
  List<int>? _first;
  bool _error = false;
  String _message = '';

  String get _title => switch (_step) {
        _SetupStep.verify => '验证当前图案',
        _SetupStep.draw => '绘制新图案',
        _SetupStep.confirm => '再次绘制确认',
      };

  String get _hint => switch (_step) {
        _SetupStep.verify => '请先绘制当前使用的解锁图案',
        _SetupStep.draw => '请连接至少 4 个点',
        _SetupStep.confirm => '请再次绘制刚才的图案',
      };

  /// 每次绘制完成的回调，按当前步骤分发：
  /// - verify：校验旧图案，通过才进入 draw；
  /// - draw：至少 4 点则暂存为 `_first`，进入 confirm；
  /// - confirm：与 `_first` 完全一致才保存并返回 true，否则退回 draw 重画。
  Future<void> _onCompleted(List<int> pattern) async {
    switch (_step) {
      case _SetupStep.verify:
        final ok = await _ctrl.verifyPattern(pattern);
        if (!mounted) return;
        if (ok) {
          setState(() {
            _step = _SetupStep.draw;
            _error = false;
            _message = '';
          });
        } else {
          setState(() {
            _error = true;
            _message = '当前图案不正确';
          });
        }
        break;
      case _SetupStep.draw:
        if (pattern.length < 4) {
          setState(() {
            _error = true;
            _message = '请至少连接 4 个点';
          });
          return;
        }
        setState(() {
          _first = pattern;
          _step = _SetupStep.confirm;
          _error = false;
          _message = '';
        });
        break;
      case _SetupStep.confirm:
        if (_first != null && listEquals(pattern, _first)) {
          await _ctrl.savePattern(pattern);
          if (!mounted) return;
          Get.back(result: true);
          Get.snackbar('设置成功', '解锁图案已更新');
        } else {
          setState(() {
            _first = null;
            _step = _SetupStep.draw;
            _error = true;
            _message = '两次绘制不一致，请重新绘制';
          });
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('解锁图案'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(_hint,
                    style: TextStyle(
                        fontSize: 12.5,
                        color:
                            cs.onSurfaceVariant.withValues(alpha: 0.8))),
                const SizedBox(height: 26),
                PatternLock(
                  size: 260,
                  error: _error,
                  onChanged: (p) {
                    if (_error && p.isNotEmpty) {
                      setState(() {
                        _error = false;
                        _message = '';
                      });
                    }
                  },
                  onCompleted: _onCompleted,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 22,
                  child: AnimatedOpacity(
                    opacity: _message.isEmpty ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Text(_message,
                        style:
                            TextStyle(fontSize: 12.5, color: cs.error)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
