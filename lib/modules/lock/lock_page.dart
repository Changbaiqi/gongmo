import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/widgets/pattern_lock.dart';
import 'lock_controller.dart';

/// 应用解锁页：图案密码或指纹验证
class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final LockController _ctrl = Get.find<LockController>();

  bool _error = false;
  String _message = '';
  bool _biometricBusy = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_unlocked || _biometricBusy) return;
    if (!_ctrl.biometricEnabled.value || !_ctrl.biometricAvailable.value) {
      return;
    }
    setState(() => _biometricBusy = true);
    final ok = await _ctrl.authenticateBiometric();
    if (!mounted) return;
    setState(() => _biometricBusy = false);
    if (ok) _unlock();
  }

  void _unlock() {
    if (_unlocked) return;
    _unlocked = true;
    _ctrl.markUnlocked();
    // 若是从后台返回时弹出的锁屏，直接返回原页面；冷启动则进入主页
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      Get.offAllNamed(AppRoutes.dashboard);
    }
  }

  Future<void> _onPattern(List<int> pattern) async {
    if (_unlocked) return;
    if (pattern.length < 4) {
      setState(() {
        _error = true;
        _message = '请至少连接 4 个点';
      });
      return;
    }
    final ok = await _ctrl.verifyPattern(pattern);
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      setState(() {
        _error = true;
        _message = '图案不正确，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 88,
                      height: 88,
                      cacheWidth: 176,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('工墨已锁定',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('绘制解锁图案以继续',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
                  const SizedBox(height: 28),
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
                    onCompleted: _onPattern,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 22,
                    child: AnimatedOpacity(
                      opacity: _message.isEmpty ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _message,
                        style: TextStyle(fontSize: 12.5, color: cs.error),
                      ),
                    ),
                  ),
                  if (_ctrl.biometricEnabled.value &&
                      _ctrl.biometricAvailable.value) ...[
                    const SizedBox(height: 18),
                    TextButton.icon(
                      onPressed: _biometricBusy ? null : _tryBiometric,
                      icon: _biometricBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint_rounded),
                      label: const Text('使用指纹解锁'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
