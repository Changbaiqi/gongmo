import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../data/models/invoice_profile.dart';
import '../../data/services/storage_service.dart';

/// 发票助手：管理常用开票抬头，一键复制填开信息
class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  List<InvoiceProfile> get _profiles => StorageService().invoiceProfiles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('发票助手'),
        centerTitle: true,
      ),
      body: _profiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_rounded,
                      size: 56, color: cs.outlineVariant),
                  const SizedBox(height: 12),
                  Text('暂无发票抬头，点击 + 添加',
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              cs.onSurfaceVariant.withValues(alpha: 0.7))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: _profiles.length,
              itemBuilder: (context, index) =>
                  _buildProfileCard(context, _profiles[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProfileDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加抬头'),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, InvoiceProfile p) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.title.isEmpty ? p.name : p.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: '复制全部信息',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: cs.primary,
                  onPressed: () => _copyProfile(p),
                ),
                IconButton(
                  tooltip: '编辑',
                  icon: Icon(Icons.edit_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  onPressed: () => _showProfileDialog(existing: p),
                ),
                IconButton(
                  tooltip: '删除',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  onPressed: () => _confirmDelete(p),
                ),
              ],
            ),
            const SizedBox(height: 2),
            _infoLine('抬头名称', p.name),
            if (p.taxId.isNotEmpty) _infoLine('纳税人识别号', p.taxId),
            if (p.address.isNotEmpty) _infoLine('地址', p.address),
            if (p.phone.isNotEmpty) _infoLine('电话', p.phone),
            if (p.bankName.isNotEmpty) _infoLine('开户银行', p.bankName),
            if (p.bankAccount.isNotEmpty) _infoLine('银行账号', p.bankAccount),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _profileText(InvoiceProfile p) {
    final lines = <String>[
      '发票抬头：${p.name}',
      if (p.taxId.isNotEmpty) '纳税人识别号：${p.taxId}',
      if (p.address.isNotEmpty) '地址：${p.address}',
      if (p.phone.isNotEmpty) '电话：${p.phone}',
      if (p.bankName.isNotEmpty) '开户银行：${p.bankName}',
      if (p.bankAccount.isNotEmpty) '银行账号：${p.bankAccount}',
    ];
    return lines.join('\n');
  }

  Future<void> _copyProfile(InvoiceProfile p) async {
    await Clipboard.setData(ClipboardData(text: _profileText(p)));
    Get.snackbar('已复制', '开票信息已复制到剪贴板');
  }

  void _confirmDelete(InvoiceProfile p) {
    Get.dialog(AlertDialog(
      title: const Text('删除抬头'),
      content: Text('确定删除「${p.title.isEmpty ? p.name : p.title}」吗？'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        TextButton(
          onPressed: () {
            setState(() => StorageService().removeInvoiceProfile(p.id));
            Get.back();
          },
          child: const Text('删除', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  Future<void> _showProfileDialog({InvoiceProfile? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final taxIdCtrl = TextEditingController(text: existing?.taxId ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final bankCtrl = TextEditingController(text: existing?.bankName ?? '');
    final accountCtrl =
        TextEditingController(text: existing?.bankAccount ?? '');

    Widget field(String label, TextEditingController ctrl,
            {TextInputType? keyboardType}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            decoration: InputDecoration(labelText: label),
            style: const TextStyle(fontSize: 13.5),
          ),
        );

    await Get.dialog(
      AlertDialog(
        title: Text(existing == null ? '添加发票抬头' : '编辑发票抬头'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field('显示名（如：公司抬头 / 个人）', titleCtrl),
              field('抬头名称（企业全称或个人姓名）', nameCtrl),
              field('纳税人识别号 / 身份证号', taxIdCtrl),
              field('注册地址（选填）', addressCtrl),
              field('电话（选填）', phoneCtrl,
                  keyboardType: TextInputType.phone),
              field('开户银行（选填）', bankCtrl),
              field('银行账号（选填）', accountCtrl,
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                Get.snackbar('提示', '请填写抬头名称');
                return;
              }
              final profile = InvoiceProfile(
                id: existing?.id ?? '',
                title: titleCtrl.text.trim(),
                name: name,
                taxId: taxIdCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                bankName: bankCtrl.text.trim(),
                bankAccount: accountCtrl.text.trim(),
              );
              if (existing == null) {
                profile.id = DateTime.now()
                        .millisecondsSinceEpoch
                        .toRadixString(36) +
                    name.length.toString();
                StorageService().addInvoiceProfile(profile);
              } else {
                profile.id = existing.id;
                StorageService().updateInvoiceProfile(profile);
              }
              setState(() {});
              Get.back();
              Get.snackbar('已保存', '发票抬头「${profile.title.isEmpty ? name : profile.title}」已更新');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
