/// 多设备同步合并算法（纯函数，便于单元测试）
///
/// 设计目标：两台手机各自记录数据后再同步时，取**并集**，不互相覆盖。
/// 规则：
/// - 按 `id` 合并；同一 id 取 `updatedAt` 较新的一条（缺失时回退 createdAt）
/// - 时间戳相同时保留**本地**（本地通常是当前正在编辑的设备）
/// - 删除墓碑优先：删除时间 >= 记录更新时间时，该记录在合并结果中被丢弃
class SyncMerge {
  SyncMerge._();

  /// 记录时间戳（毫秒）：优先 updatedAt，其次 createdAt，都没有则为 0
  static int timestampOf(Map<String, dynamic> json) {
    for (final key in const ['updatedAt', 'createdAt']) {
      final v = json[key];
      if (v is String) {
        final t = DateTime.tryParse(v);
        if (t != null) return t.millisecondsSinceEpoch;
      }
    }
    return 0;
  }

  /// 合并同类型记录：并集 + 最新修改优先 + 应用删除墓碑
  static List<Map<String, dynamic>> mergeRecords({
    required List<dynamic> local,
    required List<dynamic> remote,
    required Map<String, int> tombstones,
    required String kind,
  }) {
    final byId = <String, Map<String, dynamic>>{};

    void put(Map<String, dynamic> m, {required bool preferred}) {
      final id = '${m['id'] ?? ''}';
      if (id.isEmpty) return;
      final cur = byId[id];
      if (cur == null) {
        byId[id] = m;
        return;
      }
      final a = timestampOf(m);
      final b = timestampOf(cur);
      if (a > b || (a == b && preferred)) byId[id] = m;
    }

    for (final e in remote) {
      if (e is Map) put(Map<String, dynamic>.from(e), preferred: false);
    }
    for (final e in local) {
      if (e is Map) put(Map<String, dynamic>.from(e), preferred: true);
    }

    final result = <Map<String, dynamic>>[];
    byId.forEach((id, m) {
      final deletedAt = tombstones['$kind:$id'];
      if (deletedAt != null && deletedAt >= timestampOf(m)) return;
      result.add(m);
    });
    return result;
  }

  /// 合并删除墓碑：同 key 取较晚的删除时间
  static Map<String, int> mergeTombstones(
      Map<String, int> local, Map<String, int> remote) {
    final out = Map<String, int>.from(local);
    remote.forEach((k, v) {
      final cur = out[k];
      if (cur == null || v > cur) out[k] = v;
    });
    return out;
  }

  /// 把 JSON 中的 map 解析为 String -> int（兼容字符串数字）
  static Map<String, int> parseIntMap(dynamic raw) {
    final out = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final i = v is int ? v : int.tryParse('$v');
        if (i != null) out['$k'] = i;
      });
    }
    return out;
  }

  /// 清理过期墓碑（默认保留 180 天）
  static Map<String, int> prune(Map<String, int> tombstones,
      {Duration keep = const Duration(days: 180)}) {
    final cutoff =
        DateTime.now().subtract(keep).millisecondsSinceEpoch;
    tombstones.removeWhere((_, v) => v < cutoff);
    return tombstones;
  }
}
