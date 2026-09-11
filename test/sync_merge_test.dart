// ============================================================
// SyncMerge 多设备合并算法单元测试
// 覆盖：并集合并、最新修改优先、时间相同保留本地、删除墓碑、
//       删除后重编辑保留、墓碑取较晚时间、createdAt 回退
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:gongmo/data/services/sync_merge.dart';

Map<String, dynamic> rec(String id, String updatedAt, {String name = ''}) => {
      'id': id,
      'updatedAt': updatedAt,
      'name': name,
    };

void main() {
  test('两台设备各自新增的记录合并后都保留', () {
    final merged = SyncMerge.mergeRecords(
      local: [rec('a', '2026-01-01T10:00:00.000Z', name: '本机')],
      remote: [rec('b', '2026-01-01T09:00:00.000Z', name: '另一台')],
      tombstones: {},
      kind: 'finance',
    );
    expect(merged.map((e) => e['id']).toSet(), {'a', 'b'});
  });

  test('本机较旧的数据不会覆盖远端较新的记录', () {
    final merged = SyncMerge.mergeRecords(
      local: [rec('a', '2026-01-01T08:00:00.000Z', name: '本机旧')],
      remote: [rec('a', '2026-01-01T12:00:00.000Z', name: '另一台新')],
      tombstones: {},
      kind: 'finance',
    );
    expect(merged.single['name'], '另一台新');
  });

  test('本机较新的记录会保留', () {
    final merged = SyncMerge.mergeRecords(
      local: [rec('a', '2026-01-02T08:00:00.000Z', name: '本机新')],
      remote: [rec('a', '2026-01-01T12:00:00.000Z', name: '远端旧')],
      tombstones: {},
      kind: 'finance',
    );
    expect(merged.single['name'], '本机新');
  });

  test('时间相同保留本地', () {
    final merged = SyncMerge.mergeRecords(
      local: [rec('a', '2026-01-01T10:00:00.000Z', name: '本地')],
      remote: [rec('a', '2026-01-01T10:00:00.000Z', name: '远端')],
      tombstones: {},
      kind: 'finance',
    );
    expect(merged.single['name'], '本地');
  });

  test('删除墓碑阻止已删除记录被远端恢复', () {
    final merged = SyncMerge.mergeRecords(
      local: const [],
      remote: [rec('a', '2026-01-01T10:00:00.000Z')],
      tombstones: {
        'finance:a':
            DateTime.parse('2026-01-01T11:00:00.000Z').millisecondsSinceEpoch,
      },
      kind: 'finance',
    );
    expect(merged, isEmpty);
  });

  test('删除后被重新编辑的记录应保留', () {
    final merged = SyncMerge.mergeRecords(
      local: [rec('a', '2026-01-02T10:00:00.000Z')],
      remote: const [],
      tombstones: {
        'finance:a':
            DateTime.parse('2026-01-01T11:00:00.000Z').millisecondsSinceEpoch,
      },
      kind: 'finance',
    );
    expect(merged.length, 1);
  });

  test('墓碑合并取较晚时间', () {
    final merged = SyncMerge.mergeTombstones(
      {'finance:a': 100},
      {'finance:a': 200, 'work:b': 50},
    );
    expect(merged['finance:a'], 200);
    expect(merged['work:b'], 50);
  });

  test('缺少 updatedAt 时回退 createdAt', () {
    final merged = SyncMerge.mergeRecords(
      local: const [],
      remote: [
        {'id': 'a', 'createdAt': '2026-01-01T10:00:00.000Z'},
      ],
      tombstones: {},
      kind: 'work',
    );
    expect(merged.length, 1);
    expect(SyncMerge.timestampOf(merged.single),
        DateTime.parse('2026-01-01T10:00:00.000Z').millisecondsSinceEpoch);
  });
}
