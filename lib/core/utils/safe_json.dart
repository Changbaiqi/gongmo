// ============================================================
// safe_json.dart（core/utils）
// 职责：容错的 JSON 取值工具，避免旧版本数据或个别脏字段
//       导致整条记录（乃至整份文件）解析失败。
// 关联：各数据模型 fromJson。
// ============================================================

/// 容错的时间解析：缺失或格式非法时返回兜底时间（默认 1970）。
///
/// 排序/合并都依赖 updatedAt，解析失败时给一个很早的时间，
/// 让数据在合并时输给正常记录，但绝不抛异常丢弃整条记录。
DateTime safeDate(dynamic value, {DateTime? fallback}) {
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// 容错的字符串取值
String safeString(dynamic value, {String fallback = ''}) =>
    value is String ? value : fallback;

/// 容错的数字取值
double safeDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// 容错的整数取值
int safeInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
