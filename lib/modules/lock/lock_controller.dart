// ============================================================
// lock_controller.dart（锁屏模块 · 业务控制器）
// 职责：应用锁的核心逻辑——图案的设置/校验（随机盐 + SHA-256）、生物识别
//       解锁、开关持久化，以及“回到前台多久需要重锁”的判断。
// 关联：图案哈希等敏感数据只存 flutter_secure_storage；被 SplashPage、
//       LockPage、PatternSetupPage、SettingsPage 共同使用；App 启动时 init。
// ============================================================
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

/// 应用锁：图案密码（加盐 SHA-256 存于安全存储）+ 生物识别解锁。
///
/// 明文图案绝不落盘：保存时生成随机盐，仅存 `SHA-256(salt|pattern)`；
/// 校验时用同一盐重算比对。生命周期为 App 级单例，由启动流程调用 [init]
/// 恢复开关状态，之后各页面通过 `Get.find` 复用。
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

  /// 从安全存储恢复开关状态；无图案时强制关闭锁与生物识别，避免“锁死”。
  /// 生物识别可用性做双通道判断：canCheckBiometrics 部分 ROM 误报 false，
  /// 再用 isDeviceSupported 兜底。
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

  /// 图案哈希：`SHA-256(盐 | 点序号串)`。加盐使相同图案在不同设备的哈希不同，
  /// 防止彩虹表反推；点序号用 '-' 连接避免 [1,23] 与 [12,3] 混淆。
  String _hash(String raw, String salt) =>
      sha256.convert(utf8.encode('$salt|$raw')).toString();

  /// 生成 16 字节密码学安全随机盐（base64url 编码）
  String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// 保存新图案（覆盖旧图案）：每次重新生成盐，旧哈希自然失效
  Future<void> savePattern(List<int> pattern) async {
    final salt = _newSalt();
    await _secure.write(key: _kSalt, value: salt);
    await _secure.write(
        key: _kPattern, value: _hash(pattern.join('-'), salt));
    hasPattern.value = true;
  }

  /// 校验图案：读出存储的盐与哈希，重算比对。
  /// 任一缺失（未设置或存储被清）都返回 false，交由上层引导重新设置。
  Future<bool> verifyPattern(List<int> pattern) async {
    final salt = await _secure.read(key: _kSalt) ?? '';
    final stored = await _secure.read(key: _kPattern) ?? '';
    if (stored.isEmpty || salt.isEmpty) return false;
    return _hash(pattern.join('-'), salt) == stored;
  }

  /// 调起系统生物识别（指纹/面容）。成功会顺带 [markUnlocked] 记录时间；
  /// 失败原因写入 [biometricError] 供界面展示，平台错误码由
  /// [_authErrorMessage] 映射为可读文案。
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

  /// 把 local_auth 的平台错误码翻译成用户能看懂的中文提示
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

  /// 开关应用锁；没有图案时拒绝开启（否则用户会被永久锁在门外）。
  /// 关闭时连带关闭生物识别，保证“锁已关”状态一致。
  Future<void> setEnabled(bool v) async {
    if (v && !hasPattern.value) return;
    enabled.value = v;
    await _secure.write(key: _kEnabled, value: v ? '1' : '0');
    if (!v) {
      biometricEnabled.value = false;
      await _secure.write(key: _kBiometric, value: '0');
    }
  }

  /// 开关指纹/生物识别解锁（仅在已启用应用锁时有意义）
  Future<void> setBiometricEnabled(bool v) async {
    biometricEnabled.value = v;
    await _secure.write(key: _kBiometric, value: v ? '1' : '0');
  }

  /// 清除图案：同时删除哈希与盐，并关闭应用锁
  Future<void> clearPattern() async {
    await _secure.delete(key: _kPattern);
    await _secure.delete(key: _kSalt);
    hasPattern.value = false;
    await setEnabled(false);
  }

  /// 记录一次成功解锁（用于后台返回的宽限期）
  void markUnlocked() => _lastUnlockAt = DateTime.now();

  /// 回到前台时是否需要重新解锁。
  ///
  /// 未启用锁或未设置图案时恒为 false；从未解锁过（冷启动）为 true；
  /// 距上次解锁超过 20 秒才重新锁定，短时间切后台（如拍照、复制验证码）
  /// 回来无需再次验证。
  bool get needsRelock {
    if (!enabled.value || !hasPattern.value) return false;
    final t = _lastUnlockAt;
    if (t == null) return true;
    return DateTime.now().difference(t) > const Duration(seconds: 20);
  }
}
