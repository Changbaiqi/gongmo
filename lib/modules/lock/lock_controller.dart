import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show PlatformException;
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

  /// 最近一次生物识别失败原因（供界面提示）
  final biometricError = ''.obs;

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
    // 部分机型（如 MIUI）canCheckBiometrics 会误报 false，
    // 用 isDeviceSupported 兜底判断是否有生物识别硬件
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      biometricAvailable.value = canCheck || supported;
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
    biometricError.value = '';
    if (!biometricAvailable.value) {
      biometricError.value = '当前设备不支持指纹/生物识别';
      return false;
    }
    try {
      final ok = await _auth.authenticate(
        localizedReason: '验证身份以解锁工墨',
        options: const AuthenticationOptions(
          // 不用 biometricOnly：部分机型（MIUI 等）会静默失败，
          // 允许回退到锁屏密码更可靠
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) markUnlocked();
      return ok;
    } on PlatformException catch (e) {
      biometricError.value = _authErrorMessage(e.code);
      return false;
    } catch (_) {
      biometricError.value = '指纹验证失败，请重试';
      return false;
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'NotAvailable':
        return '当前设备不支持生物识别';
      case 'NotEnrolled':
        return '请先在系统设置中录入指纹';
      case 'PasscodeNotSet':
        return '请先在系统设置中设置锁屏密码';
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return '指纹已被系统锁定，请用图案解锁';
      case 'no_fragment_activity':
        return '设备配置异常，请用图案解锁';
      default:
        return '指纹验证失败（$code）';
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
