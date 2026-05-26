# 工墨 (GongMo)

工时记录与记账一体化的 Flutter 应用。

## 特性

- **记账与计时一体**：底部双页切换（记账 | 时钟），支持左右滑动
- **计时模式**：可自定义标签（工作⭐/学习/休息/运动/阅读），工作标签自动计算收入
- **打卡模式**：上下班打卡，自动统计每日工时（不计算薪资）
- **月历视图**：有记录的日子显示橙色圆点
- **快速记账**：右下角 + 按钮弹出表单，选择收支/分类/金额
- **JSON 本地存储**：数据自动持久化，支持导出

## 技术栈

- Flutter 3.x + Dart
- GetX（路由、状态管理、依赖注入）
- JSON 文件本地存储（path_provider）
- Material Design 3（亮暗双主题）
- flutter_secure_storage（Token 加密）

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行
flutter run

# 构建 APK（release）
flutter build apk --release
```

## 项目结构

```
lib/
├── main.dart                         # 应用入口
├── app/
│   ├── routes/                       # 路由定义
│   └── theme/                        # 主题配置
├── core/
│   ├── constants/                    # 应用常量
│   └── utils/                        # 日期工具类
├── data/
│   ├── models/                       # 数据模型（WorkEntry, FinanceEntry, TimerTag 等）
│   ├── repositories/                 # 数据仓库层
│   └── services/                     # StorageService（JSON 持久化单例）
├── modules/
│   ├── home/                         # 主页面（PageView + 底部导航）
│   ├── work/                         # 时钟页（计时模式 + 打卡模式）
│   ├── finance/                      # 记账页
│   ├── dashboard/                    # 仪表盘控制器 + 月历组件
│   ├── sync/                         # GitHub 同步页
│   └── settings/                     # 设置页
```

## 设计文档

详见 [docs/软件设计文档.md](docs/软件设计文档.md)
