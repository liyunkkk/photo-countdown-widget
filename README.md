# 照片倒计时桌面小组件

自用照片倒计时小组件（2×2 / 2×4），无 Xcode 开发：代码在 iPhone 的 Minis (iSH) 上编写，
GitHub Actions macOS runner 云端编译，TrollStore 安装（伪签，无需 Apple ID / 证书）。

## 结构

```
photo-widget/
├── project.yml                        # XcodeGen 工程定义
├── App/                               # 主 App（SwiftUI：选图 / 标题 / 目标时间）
│   ├── PhotoWidgetApp.swift
│   ├── ContentView.swift
│   └── Info.plist                     # xcodegen 生成
├── Widget/                            # WidgetKit 扩展（SwiftUI 渲染，Swift 专用）
│   ├── PhotoCountdownWidget.swift
│   └── Info.plist
├── Shared/
│   └── WidgetStore.swift              # App Group 数据共享（配置 + 照片文件）
└── .github/workflows/build.yml        # Actions 编译 → 上传 IPA artifact
```

## 开发流程（全在手机上）

1. 改代码（Minis iSH）
2. `git push` → Actions 自动编译（约 2~4 分钟）
3. 下载 artifact → ldid 伪签（App Group entitlements）→ TrollStore 导入安装

## 使用

装好后打开 App，为 2×2 和 2×4 各选照片、填标题、设目标时间 → 保存 →
桌面长按空白处 → 添加小组件 → 「照片倒计时」。倒计时每小时自动刷新（预计算 24 个时间点）。

## 数据

- 配置：App Group `group.com.qingxu.photowidget` 的 UserDefaults（item.small / item.medium）
- 照片：App Group 容器内 photo.small.img / photo.medium.img
