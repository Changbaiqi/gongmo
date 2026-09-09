import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

/// 应用锁：图案密码（加盐 SHA-256 存于安全存储）+ 生物识别解锁
class LockController extends GetxController {
  static const _kPattern = 'app_lock_pattern';
  static const _kSalt = 'app_lock_salt';
  static const _kEnabled = 'app_lock_enabled';
  static const _kBiometric = 'app_lock_biometric';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final LocalAuthentication _auth = LocalAuthentication();

  /// 是否启用应用锁
  final enabled = false.obs;

  /// 是否允许指纹/生物识别解锁
  final biometricEnabled = false.obs;

  /// 是否已设置图案
  final hasPattern = false.obs;

  /// 设备是否支持生物识别
  final biometricAvailable = false.obs;

  DateTime? _lastUnlockAt;

  Future<void> init() async {
    enabled.value = await _secure.read(key: _kEnabled) == '1';
    biometricEnabled.value = await _secure.read(key: _kBiometric) == '1';
    hasPattern.value =
        ((await _secure.read(key: _kPattern)) ?? '').isNotEmpty;
    if (!hasPattern.value) {
      // 没有图案时不能保持开启状态
      enabled.value = false;
      biometricEnabled.value = false;
    }
    try {
      biometricAvailable.value =
          await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      biometricAvailable.value = false;
    }
  }

  String _hash(String raw, String salt) =>
      sha256.convert(utf8.encode('$salt|$raw')).toString();

  String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// 保存新图案（覆盖旧图案）
  Future<void> savePattern(List<int> pattern) async {
    final salt = _newSalt();
    await _secure.write(key: _kSalt, value: salt);
    await _secure.write(
        key: _kPattern, value: _hash(pattern.join('-'), salt));
    hasPattern.value = true;
  }

  Future<bool> verifyPattern(List<int> pattern) async {
    final salt = await _secure.read(key: _kSalt) ?? '';
    final stored = await _secure.read(key: _kPattern) ?? '';
    if (stored.isEmpty || salt.isEmpty) return false;
    return _hash(pattern.join('-'), salt) == stored;
  }

  /// 触发系统生物识别验证
  Future<bool> authenticateBiometric() async {
    if (!biometricAvailable.value) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: '验证身份以解锁工墨',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) markUnlocked();
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool v) async {
    if (v && !hasPattern.value) return;
    enabled.value = v;
    await _secure.write(key: _kEnabled, value: v ? '1' : '0');
    if (!v) {
      biometricEnabled.value = false;
      await _secure.write(key: _kBiometric, value: '0');
    }
  }

  Future<void> setBiometricEnabled(bool v) async {
    biometricEnabled.value = v;
    await _secure.write(key: _kBiometric, value: v ? '1' : '0');
  }

  Future<void> clearPattern() async {
    await _secure.delete(key: _kPattern);
    await _secure.delete(key: _kSalt);
    hasPattern.value = false;
    await setEnabled(false);
  }

  /// 记录一次成功解锁（用于后台返回的宽限期）
  void markUnlocked() => _lastUnlockAt = DateTime.now();

  /// 回到前台时是否需要重新解锁
  bool get needsRelock {
    if (!enabled.value || !hasPattern.value) return false;
    final t = _lastUnlockAt;
    if (t == null) return true;
    return DateTime.now().difference(t) > const Duration(seconds: 20);
  }
}
