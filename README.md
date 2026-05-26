# 工墨 (GongMo)

工时记录与记账一体化的 Flutter 应用。

## 特性

- **工时记录**：正计时/手动录入，自动计算时长与收入
- **记账管理**：收入、支出、转账，预置常用分类
- **工时记账联动**：结束计时自动生成收入账目
- **GitHub 云端备份**：数据同步至 GitHub 仓库（计划中）
- **通知识别记录**：自动识别支付扣款通知（计划中）

## 技术栈

- Flutter 3.x + Dart
- GetX（状态管理、路由、依赖注入）
- JSON 本地文件存储
- Material Design 3

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行
flutter run

# 构建 APK
flutter build apk --release
```

## 项目结构

```
lib/
├── main.dart                     # 应用入口
├── app/
│   ├── routes/                   # 路由定义
│   └── theme/                    # 主题配置
├── modules/
│   ├── dashboard/                # 首页仪表盘
│   ├── work/                     # 工时记录模块
│   ├── finance/                  # 账目模块
│   ├── sync/                     # GitHub 同步模块
│   └── settings/                 # 设置模块
├── data/
│   ├── models/                   # 数据模型
│   ├── repositories/             # 数据仓库
│   └── services/                 # 数据服务
└── core/
    ├── constants/                # 常量
    ├── utils/                    # 工具类
    └── widgets/                  # 公共组件
```

## 设计文档

详见 [docs/软件设计文档.md](docs/软件设计文档.md)
