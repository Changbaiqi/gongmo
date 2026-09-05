import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import 'storage_service.dart';

/// 同步过程中的业务异常，message 可直接展示给用户
class GithubSyncException implements Exception {
  final String message;
  GithubSyncException(this.message);
  @override
  String toString() => message;
}

/// GitHub 备份同步服务
///
/// 通过 GitHub Contents API 将本地数据以 JSON 备份的形式
/// 保存到指定仓库（gongmo_backup.json），并支持拉取恢复。
/// Token 使用 flutter_secure_storage 加密存储，
/// 仓库地址与上次同步时间存于 config.json。
class GithubSyncService {
  GithubSyncService._();
  static final GithubSyncService instance = GithubSyncService._();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'github_token';
  static const _backupPath = 'gongmo_backup.json';

  final StorageService _storage = StorageService();

  // ---------- 配置 ----------

  /// 支持完整 URL（https://github.com/user/repo）或 owner/repo 两种写法
  static String? normalizeRepo(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.replaceFirst(RegExp(r'^www\.'), '');
    s = s.replaceFirst('github.com', '');
    s = s.split('?').first.split('#').first.replaceAll('.git', '');
    final parts = s.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return null;
    return '${parts[0]}/${parts[1]}';
  }

  Future<String> getRepoUrl() async =>
      (_storage.getConfig('github_repo') as String?) ?? '';

  Future<void> saveRepoUrl(String repo) =>
      _storage.setConfig('github_repo', repo);

  Future<String> getToken() async => await _secure.read(key: _tokenKey) ?? '';

  Future<void> saveToken(String token) async {
    if (token.isEmpty) {
      await _secure.delete(key: _tokenKey);
    } else {
      await _secure.write(key: _tokenKey, value: token);
    }
  }

  Future<void> clearConfig() async {
    await saveRepoUrl('');
    await saveToken('');
    await _storage.setConfig('last_sync', '');
  }

  DateTime? getLastSync() {
    final v = _storage.getConfig('last_sync');
    return v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
  }

  Future<void> setLastSync(DateTime t) =>
      _storage.setConfig('last_sync', t.toIso8601String());

  // ---------- 同步 ----------

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'User-Agent': 'GongMo-App',
      };

  /// 备份当前全部数据到 GitHub（存在则更新，不存在则创建）
  Future<void> pushBackup() async {
    final repo = await getRepoUrl();
    final token = await getToken();
    if (repo.isEmpty || token.isEmpty) {
      throw GithubSyncException('请先在设置中绑定仓库并填写 Token');
    }

    final payload = json.encode({
      'app': 'gongmo',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': _storage.exportAllData(),
    });

    final uri =
        Uri.parse('${AppConstants.githubApiBase}/repos/$repo/contents/$_backupPath');
    final headers = _headers(token);

    // 先获取已有文件的 sha（更新时必填），不存在则为首次创建
    String? sha;
    final getRes =
        await _send(() => http.get(uri, headers: headers));
    if (getRes.statusCode == 200) {
      final body = json.decode(getRes.body);
      if (body is Map<String, dynamic>) {
        sha = body['sha'] as String?;
      }
    } else if (getRes.statusCode != 404) {
      throw _errorFor(getRes.statusCode);
    }

    final putRes = await _send(
      () => http.put(
        uri,
        headers: headers,
        body: json.encode({
          'message':
              'GongMo backup ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          'content': base64Encode(utf8.encode(payload)),
          if (sha != null) 'sha': sha,
        }),
      ),
    );
    if (putRes.statusCode != 200 && putRes.statusCode != 201) {
      throw _errorFor(putRes.statusCode);
    }
  }

  /// 从 GitHub 拉取备份数据，返回 data 字段（模型 Map 列表）
  Future<Map<String, dynamic>> pullBackup() async {
    final repo = await getRepoUrl();
    final token = await getToken();
    if (repo.isEmpty || token.isEmpty) {
      throw GithubSyncException('请先在设置中绑定仓库并填写 Token');
    }

    final uri =
        Uri.parse('${AppConstants.githubApiBase}/repos/$repo/contents/$_backupPath');
    final getRes = await _send(() => http.get(uri, headers: _headers(token)));

    if (getRes.statusCode == 404) {
      throw GithubSyncException('云端还没有备份文件');
    }
    if (getRes.statusCode != 200) {
      throw _errorFor(getRes.statusCode);
    }

    final body = json.decode(getRes.body);
    if (body is! Map<String, dynamic> || body['content'] == null) {
      throw GithubSyncException('云端备份文件格式异常');
    }
    final decoded = utf8.decode(
      base64Decode((body['content'] as String).replaceAll('\n', '')),
    );
    final doc = json.decode(decoded);
    if (doc is! Map<String, dynamic> || doc['data'] is! Map<String, dynamic>) {
      throw GithubSyncException('云端备份内容异常，无法恢复');
    }
    return doc['data'] as Map<String, dynamic>;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 30));
    } on SocketException {
      throw GithubSyncException('网络连接失败，请检查网络后重试');
    } on TimeoutException {
      throw GithubSyncException('请求超时，请重试');
    }
  }

  GithubSyncException _errorFor(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return GithubSyncException('Token 无效或权限不足（需要 Contents 读写权限）');
      case 404:
        return GithubSyncException('仓库不存在或无权访问，请检查仓库地址');
      case 301:
        return GithubSyncException('仓库已迁移，请更新仓库地址');
      default:
        return GithubSyncException('GitHub 请求失败（HTTP $statusCode）');
    }
  }
}
