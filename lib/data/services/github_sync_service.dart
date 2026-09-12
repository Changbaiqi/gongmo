// ============================================================
// GitHub 云备份服务（data/services）
// 职责：通过 GitHub Contents API 把本地数据按年份分片备份到
//       仓库 gongmo_backup/ 目录；上传前先拉取远端并合并，避免覆盖
// 关联：StorageService（导入导出/合并）、SyncController（触发备份/恢复）、
//       flutter_secure_storage（Token 加密存储）
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import 'attachment_service.dart';
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
/// 通过 GitHub Contents API 将本地数据按【年份分片】备份到仓库的
/// gongmo_backup/ 目录：gongmo_backup/index.json（索引 + 分类等全局数据）
/// 以及 gongmo_backup/2026.json 等年度数据文件。
/// 每个文件只含一年数据，远低于 GitHub 单文件 100MB 的上限。
/// Token 使用 flutter_secure_storage 加密存储，
/// 仓库地址与上次同步时间存于 config.json。
class GithubSyncService {
  GithubSyncService._();
  static final GithubSyncService instance = GithubSyncService._();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'github_token';
  static const _backupDir = 'gongmo_backup';

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

  /// 清洗 Token：去除所有空白、零宽字符与 BOM（手机粘贴常见污染源）
  static String sanitizeToken(String token) =>
      token.replaceAll(RegExp(r'[\s\uFEFF\u200B\u200C\u200D\u2060]'), '');

  /// 校验 Token 是否合法（本地格式校验）
  static bool isValidTokenFormat(String token) {
    if (token.isEmpty) return false;
    // 经典 Token: ghp_/gho_/ghu_/ghs_/ghr_ 前缀；细粒度: github_pat_
    return RegExp(r'^(ghp_|gho_|ghu_|ghs_|ghr_|github_pat_)').hasMatch(token);
  }

  Future<String> getRepoUrl() async =>
      (_storage.getConfig('github_repo') as String?) ?? '';

  Future<void> saveRepoUrl(String repo) =>
      _storage.setConfig('github_repo', repo);

  Future<String> getToken() async =>
      sanitizeToken(await _secure.read(key: _tokenKey) ?? '');

  Future<void> saveToken(String token) async {
    final clean = sanitizeToken(token);
    if (clean.isEmpty) {
      await _secure.delete(key: _tokenKey);
    } else {
      await _secure.write(key: _tokenKey, value: clean);
    }
  }

  /// 清除仓库地址与 Token（不影响远端数据）
  Future<void> clearConfig() async {
    await saveRepoUrl('');
    await saveToken('');
    await _storage.setConfig('last_sync', '');
  }

  /// 上次成功同步时间（config.json 的 last_sync）
  DateTime? getLastSync() {
    final v = _storage.getConfig('last_sync');
    return v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
  }

  Future<void> setLastSync(DateTime t) =>
      _storage.setConfig('last_sync', t.toIso8601String());

  /// 读取轻量配置（供自动记账等模块使用）
  dynamic readConfig(String key) => _storage.getConfig(key);

  /// 写入轻量配置
  Future<void> writeConfig(String key, dynamic value) =>
      _storage.setConfig(key, value);

  // ---------- 同步 ----------

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'User-Agent': 'GongMo-App',
      };

  Uri _dirUri(String repo) => Uri.parse(
      '${AppConstants.githubApiBase}/repos/$repo/contents/$_backupDir');

  Uri _fileUri(String repo, String name) => Uri.parse(
      '${AppConstants.githubApiBase}/repos/$repo/contents/$_backupDir/$name');

  /// 列出远端备份目录：文件名 -> sha（目录不存在返回空 Map）
  Future<Map<String, String>> _remoteShas(String repo, String token) async {
    final res =
        await _send(() => http.get(_dirUri(repo), headers: _headers(token)));
    if (res.statusCode == 404) return {};
    if (res.statusCode != 200) throw _errorFor(res.statusCode);
    final body = json.decode(res.body);
    if (body is! List) return {};
    final shas = <String, String>{};
    for (final item in body.whereType<Map>()) {
      final name = item['name'] as String?;
      final sha = item['sha'] as String?;
      if (name != null && sha != null) shas[name] = sha;
    }
    return shas;
  }

  /// 写入/更新远端单个文件（带 sha 即更新，否则新建），返回新 sha
  Future<String?> _putFile(String repo, String token, String name,
      String content, Map<String, String> shas, String commitMsg) async {
    final res = await _send(() => http.put(
          _fileUri(repo, name),
          headers: _headers(token),
          body: json.encode({
            'message': commitMsg,
            'content': base64Encode(utf8.encode(content)),
            if (shas[name] != null) 'sha': shas[name],
          }),
        ));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw _errorFor(res.statusCode, res.body);
    }
    try {
      final body = json.decode(res.body);
      if (body is Map && body['content'] is Map) {
        return (body['content'] as Map)['sha'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// 读取远端单个文件内容（base64 解码为 UTF-8），不存在返回 null
  Future<String?> _getFile(String repo, String token, String name) async {
    final res = await _send(
        () => http.get(_fileUri(repo, name), headers: _headers(token)));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw _errorFor(res.statusCode);
    final body = json.decode(res.body);
    if (body is! Map<String, dynamic> || body['content'] == null) return null;
    return utf8
        .decode(base64Decode((body['content'] as String).replaceAll('\n', '')));
  }

  /// 分片备份到 GitHub：
  /// gongmo_backup/index.json（索引 + 分类/账户/标签等全局数据）
  /// gongmo_backup/{年份}.json（该年份的计时 + 账目数据）
  /// 每个文件只含一年数据，远低于 GitHub 单文件 100MB 上限
  ///
  /// 关键：上传前若发现云端已被其它设备更新，会先拉取并**合并**到本地，
  /// 再上传合并后的结果，避免本机较旧的数据整包覆盖云端较新的数据。
  Future<void> pushBackup() async {
    final repo = await getRepoUrl();
    final token = await getToken();
    if (repo.isEmpty || token.isEmpty) {
      throw GithubSyncException('请先在设置中绑定仓库并填写 Token');
    }

    final shas = await _remoteShas(repo, token);
    final remoteIndexSha = shas['index.json'];
    final knownSha = _storage.getConfig('last_remote_sha');

    // 云端有本机未知的更新时，先合并（首次同步也会合并）
    if (remoteIndexSha != null && remoteIndexSha != knownSha) {
      final remote = await _pullRaw(repo, token);
      if (remote != null) {
        await _storage.mergeRemoteData(remote);
      }
    }

    final yearData = _storage.exportDataByYear();
    final years = yearData.keys.toList()..sort();
    // 预算配置统一用「预算/总预算」中较晚的修改时间参与合并比较
    final budgetsAt =
        (_storage.getConfig('budgets_updated_at') as num?)?.toInt() ?? 0;
    final totalAt =
        (_storage.getConfig('total_budget_updated_at') as num?)?.toInt() ?? 0;
    final budgetsUpdatedAt = budgetsAt > totalAt ? budgetsAt : totalAt;
    final indexContent = json.encode({
      'app': 'gongmo',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'years': years,
      'counts': {
        'workEntries': _storage.workEntries.length,
        'financeEntries': _storage.financeEntries.length,
      },
      'global': {
        'categories': _storage.categories.map((e) => e.toJson()).toList(),
        'accounts': _storage.accounts.map((e) => e.toJson()).toList(),
        'timerTags': _storage.timerTags.map((e) => e.toJson()).toList(),
        'invoiceProfiles':
            _storage.invoiceProfiles.map((e) => e.toJson()).toList(),
        'budgets': _storage.getConfig('budgets') ?? {},
        'totalBudget': _storage.getConfig('total_budget') ?? 0,
        'budgetsUpdatedAt': budgetsUpdatedAt,
        'tombstones': _storage.tombstones,
      },
    });

    final commitMsg =
        'GongMo backup ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
    for (final y in years) {
      final content = json.encode({
        'app': 'gongmo',
        'year': y,
        'data': yearData[y],
      });
      await _putFile(repo, token, '$y.json', content, shas, commitMsg);
    }
    final newIndexSha =
        await _putFile(repo, token, 'index.json', indexContent, shas, commitMsg);
    if (newIndexSha != null) {
      await _storage.setConfig('last_remote_sha', newIndexSha);
    }
    // 附件（图片/PDF 等）随数据一起备份
    await _pushAttachments(repo, token);
  }

  /// 拉取并合并所有年份分片，返回与 restoreAllData 对应的数据结构
  Future<Map<String, dynamic>> pullBackup() async {
    final repo = await getRepoUrl();
    final token = await getToken();
    if (repo.isEmpty || token.isEmpty) {
      throw GithubSyncException('请先在设置中绑定仓库并填写 Token');
    }
    final data = await _pullRaw(repo, token);
    if (data == null) {
      throw GithubSyncException('云端还没有备份文件');
    }
    return data;
  }

  /// 读取远端备份（不存在返回 null）
  Future<Map<String, dynamic>?> _pullRaw(String repo, String token) async {
    final indexContent = await _getFile(repo, token, 'index.json');
    if (indexContent == null) return null;
    final index = json.decode(indexContent);
    if (index is! Map<String, dynamic>) {
      throw GithubSyncException('云端备份索引异常，无法恢复');
    }
    final years = (index['years'] as List?)?.whereType<int>() ?? const <int>[];
    final global = index['global'] is Map<String, dynamic>
        ? index['global'] as Map<String, dynamic>
        : <String, dynamic>{};

    final work = <Map<String, dynamic>>[];
    final finance = <Map<String, dynamic>>[];
    for (final y in years) {
      final content = await _getFile(repo, token, '$y.json');
      if (content == null) continue;
      final doc = json.decode(content);
      if (doc is! Map<String, dynamic> ||
          doc['data'] is! Map<String, dynamic>) {
        continue;
      }
      final data = doc['data'] as Map<String, dynamic>;
      if (data['workEntries'] is List) {
        work.addAll((data['workEntries'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)));
      }
      if (data['financeEntries'] is List) {
        finance.addAll((data['financeEntries'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)));
      }
    }

    // 附件：先把本地缺失的云端附件拉下来，保证合并后引用有效
    await _pullAttachments(repo, token);

    return {
      'workEntries': work,
      'financeEntries': finance,
      'categories': global['categories'] ?? [],
      'accounts': global['accounts'] ?? [],
      'timerTags': global['timerTags'] ?? [],
      'invoiceProfiles': global['invoiceProfiles'] ?? [],
      'budgets': global['budgets'] ?? {},
      'totalBudget': global['totalBudget'] ?? 0,
      'budgetsUpdatedAt': global['budgetsUpdatedAt'] ?? 0,
      'tombstones': global['tombstones'] ?? {},
    };
  }

  /// 清空云端备份目录下的全部文件（危险操作），返回删除的文件数
  Future<int> clearRemoteBackups() async {
    final repo = await getRepoUrl();
    final token = await getToken();
    if (repo.isEmpty || token.isEmpty) {
      throw GithubSyncException('请先在设置中绑定仓库并填写 Token');
    }
    final shas = await _remoteShas(repo, token);
    if (shas.isEmpty) {
      throw GithubSyncException('云端还没有备份文件');
    }
    var deleted = 0;
    for (final entry in shas.entries) {
      try {
        final res = await _send(() => http.delete(
              _fileUri(repo, entry.key),
              headers: _headers(token),
              body: json.encode({
                'message': 'GongMo clear backups',
                'sha': entry.value,
              }),
            ));
        if (res.statusCode == 200) deleted++;
      } on GithubSyncException {
        rethrow;
      } catch (_) {
        // 单个文件删除失败时继续处理其余文件
      }
    }
    return deleted;
  }

  /// 统一发送请求：30 秒超时，网络错误转为可展示的中文业务异常
  // ---------- 附件（图片 / PDF 等）备份与恢复 ----------

  static const _attachmentManifest = 'attachments.json';

  /// 上传本地附件（增量：大小+mtime 未变则跳过），并清理云端无引用的文件
  Future<void> _pushAttachments(String repo, String token) async {
    final svc = AttachmentService.instance;
    // 本地引用到的附件：相对路径 -> 文件
    final local = <String, File>{};
    for (final e in _storage.financeEntries) {
      for (final rel in e.attachmentPaths) {
        if (local.containsKey(rel)) continue;
        final f = File(svc.absolutePathSync(rel));
        if (await f.exists()) local[rel] = f;
      }
    }

    final manifest = await _loadAttachmentManifest(repo, token);
    var changed = false;

    for (final entry in local.entries) {
      final rel = entry.key;
      final f = entry.value;
      try {
        final size = await f.length();
        final mtime = (await f.lastModified()).millisecondsSinceEpoch;
        final prev = manifest[rel];
        if (prev != null &&
            prev['size'] == size &&
            prev['mtime'] == mtime &&
            prev['sha'] is String) {
          continue; // 未变化
        }
        final bytes = await f.readAsBytes();
        final prevSha = prev?['sha'];
        final sha = await _putBytes(
          repo,
          token,
          'attachments/$rel',
          bytes,
          {
            if (prevSha is String) 'attachments/$rel': prevSha,
          },
          'GongMo attachment ${svc.displayName(rel)}',
        );
        manifest[rel] = {'sha': sha, 'size': size, 'mtime': mtime};
        changed = true;
      } catch (_) {
        // 单个附件上传失败（如过大/网络）不影响整体同步，下次重试
      }
    }

    // 云端已不再被引用的附件：删除
    for (final rel in manifest.keys.toList()) {
      if (local.containsKey(rel)) continue;
      final sha = manifest[rel]?['sha'];
      await _deleteFile(
          repo, token, 'attachments/$rel', sha is String ? sha : null);
      manifest.remove(rel);
      changed = true;
    }

    if (changed) {
      // 注意：更新已存在的清单文件必须带上其 sha，否则 GitHub 会拒绝写入
      final shas = await _remoteShas(repo, token);
      final manifestSha = shas[_attachmentManifest];
      await _putFile(
        repo,
        token,
        _attachmentManifest,
        json.encode({'files': manifest}),
        {if (manifestSha != null) _attachmentManifest: manifestSha},
        'GongMo attachments manifest',
      );
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadAttachmentManifest(
      String repo, String token) async {
    final raw = await _getFile(repo, token, _attachmentManifest);
    if (raw == null) return {};
    try {
      final data = json.decode(raw);
      final files = data is Map ? data['files'] : null;
      if (files is Map) {
        return {
          for (final e in files.entries)
            if (e.value is Map)
              '${e.key}': Map<String, dynamic>.from(e.value as Map),
        };
      }
    } catch (_) {}
    return {};
  }

  /// 下载云端附件到本地（仅下载本地缺失的文件）
  Future<void> _pullAttachments(String repo, String token) async {
    final manifest = await _loadAttachmentManifest(repo, token);
    if (manifest.isEmpty) return;
    final svc = AttachmentService.instance;
    for (final rel in manifest.keys) {
      try {
        final f = File(svc.absolutePathSync(rel));
        if (await f.exists()) continue;
        final bytes = await _getFileBytes(repo, token, 'attachments/$rel');
        if (bytes == null) continue;
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes);
      } catch (_) {
        // 单个附件下载失败不影响其它文件
      }
    }
  }

  /// 下载单个附件（打开失败时兜底重试）
  Future<bool> downloadAttachment(String relative) async {
    try {
      final repo = await getRepoUrl();
      final token = await getToken();
      if (repo.isEmpty || token.isEmpty) return false;
      final bytes = await _getFileBytes(repo, token, 'attachments/$relative');
      if (bytes == null) return false;
      final f = File(AttachmentService.instance.absolutePathSync(relative));
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 上传二进制文件（base64 直传，不做二次编码）
  Future<String?> _putBytes(String repo, String token, String name,
      List<int> bytes, Map<String, String> shas, String commitMsg) async {
    final res = await _send(() => http.put(
          _fileUri(repo, name),
          headers: _headers(token),
          body: json.encode({
            'message': commitMsg,
            'content': base64Encode(bytes),
            if (shas[name] != null) 'sha': shas[name],
          }),
        ));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw _errorFor(res.statusCode, res.body);
    }
    try {
      final body = json.decode(res.body);
      if (body is Map && body['content'] is Map) {
        return (body['content'] as Map)['sha'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// 读取二进制文件内容：内容 API 对 >1MB 文件不返回 content，需用 download_url
  Future<List<int>?> _getFileBytes(
      String repo, String token, String name) async {
    final res = await _send(
        () => http.get(_fileUri(repo, name), headers: _headers(token)));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw _errorFor(res.statusCode, res.body);
    final body = json.decode(res.body);
    if (body is! Map<String, dynamic>) return null;
    final content = body['content'];
    if (content is String && content.isNotEmpty) {
      return base64Decode(content.replaceAll('\n', ''));
    }
    final url = body['download_url'];
    if (url is String && url.isNotEmpty) {
      final raw =
          await _send(() => http.get(Uri.parse(url), headers: _headers(token)));
      if (raw.statusCode == 200) return raw.bodyBytes;
    }
    return null;
  }

  Future<void> _deleteFile(
      String repo, String token, String name, String? sha) async {
    if (sha == null) return;
    try {
      await _send(() => http.delete(
            _fileUri(repo, name),
            headers: _headers(token),
            body: json.encode({
              'message': 'GongMo delete attachment',
              'sha': sha,
            }),
          ));
    } catch (_) {}
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {    try {
      return await request().timeout(const Duration(seconds: 30));
    } on SocketException {
      throw GithubSyncException('网络连接失败，请检查网络后重试');
    } on TimeoutException {
      throw GithubSyncException('请求超时，请重试');
    }
  }

  /// 验证仓库地址与 Token 是否可用（保存配置时调用）
  Future<void> testConnection() async {
    final repo = await getRepoUrl();
    final token = await getToken();
    if (repo.isEmpty || token.isEmpty) {
      throw GithubSyncException('请先填写仓库地址和 Token');
    }
    final res = await _send(() => http.get(
          Uri.parse('${AppConstants.githubApiBase}/repos/$repo'),
          headers: _headers(token),
        ));
    if (res.statusCode != 200) {
      throw _errorFor(res.statusCode, res.body);
    }
  }

  /// 把 GitHub HTTP 状态码翻译为用户可理解的中文异常
  GithubSyncException _errorFor(int statusCode, [String? body]) {
    String? detail;
    if (body != null && body.isNotEmpty) {
      try {
        final b = json.decode(body);
        if (b is Map<String, dynamic> && b['message'] is String) {
          detail = b['message'] as String;
        }
      } catch (_) {}
    }
    switch (statusCode) {
      case 401:
        return GithubSyncException(
            'Token 无效或已过期${detail != null ? '（GitHub: $detail）' : ''}，请重新生成并填写');
      case 403:
        final rateLimited =
            detail != null && detail.toLowerCase().contains('rate limit');
        return GithubSyncException(rateLimited
            ? 'GitHub API 请求频率超限，请稍后再试'
            : 'Token 权限不足（需要 Contents 读写权限）${detail != null ? '（GitHub: $detail）' : ''}');
      case 404:
        return GithubSyncException('仓库不存在或 Token 无权访问该仓库，请检查地址与 Token 的仓库授权');
      case 409:
        return GithubSyncException('云端数据刚被其它设备更新，本次已跳过，稍后会重新合并同步');
      case 301:
        return GithubSyncException('仓库已迁移，请更新仓库地址');
      default:
        return GithubSyncException(
            'GitHub 请求失败（HTTP $statusCode）${detail != null ? '：$detail' : ''}');
    }
  }
}
