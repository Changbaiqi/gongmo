import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/finance_entry.dart';
import 'settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController ctrl = Get.put(SettingsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('GitHub 连接'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('仓库地址'),
                  subtitle: Obx(() => Text(
                        ctrl.githubRepoUrl.value.isEmpty
                            ? '未绑定'
                            : ctrl.githubRepoUrl.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showGithubConfig(ctrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_sync),
                  title: const Text('同步设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.toNamed('/sync'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('分类管理'),
          Card(
            child: Column(
              children: ctrl.categories
                  .map((cat) => ListTile(
                        leading: Icon(
                          cat.type == FinanceType.income
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: cat.type == FinanceType.income
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text(cat.name),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('关于'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('版本'),
                  trailing: Text('v1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('开源协议'),
                  trailing: const Text('MIT'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  void _showGithubConfig(SettingsController ctrl) {
    final urlCtrl = TextEditingController(text: ctrl.githubRepoUrl.value);
    final tokenCtrl = TextEditingController(text: ctrl.githubToken.value);

    Get.dialog(
      AlertDialog(
        title: const Text('GitHub 配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: '仓库 URL',
                hintText: 'https://github.com/user/repo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token',
                hintText: 'ghp_xxxx',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ctrl.disconnectGithub();
                  Get.back();
                },
                child: const Text('断开连接', style: TextStyle(color: Colors.red)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  ctrl.setGithubRepo(urlCtrl.text);
                  ctrl.setGithubToken(tokenCtrl.text);
                  Get.back();
                  Get.snackbar('已保存', 'GitHub 配置已更新');
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
