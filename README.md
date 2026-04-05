# Lookbusy VPS 保活管理脚本 (Oracle Cloud)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

这是一个专为保护 **甲骨文云 (Oracle Cloud)** “始终免费”实例而设计的 Shell 脚本。通过 `lookbusy` 工具模拟系统负载，防止因 CPU 或内存长期空闲（低于 10%）而导致实例被回收。

## 📖 教程背景

根据甲骨文最新的服务手册，免费实例若满足以下任意条件，可能会被回收：

- 95% 时间的 CPU 使用率小于 10%
- 网络利用率不足 10%
- 内存利用率不足 10% (仅适用于 ARM 实例)

本脚本基于 **jcnf / 荒岛** 的教程简化而成，旨在实现保活操作的自动化与一键化管理。

## ✨ 核心功能

- **自动化部署**：自动安装编译环境（curl, gcc等），并从源码编译安装 `lookbusy-1.4`。
- **动态负载调节**：支持手动或默认配置 CPU 占用率和内存占用量。
- **系统服务化**：自动创建并管理 `systemd` 服务，支持开机自启、奔溃重启。
- **实时监控**：集成 `top` 视图，方便直接观察系统负载是否达标。
- **完全卸载**：提供一键清理功能，不残留冗余文件。

## 🚀 快速上手

### 1. 一键安装并交互式配置 (推荐)

如果您想快速安装并手动根据系统资源进行设置，请执行：

```bash
wget -O lookbusy_manager.sh https://raw.githubusercontent.com/hxzlplp7/linuxbusy-manger/main/lookbusy_manager.sh && chmod +x lookbusy_manager.sh && sudo ./lookbusy_manager.sh install && sudo ./lookbusy_manager.sh start
```

*(注：运行 `start` 后，脚本会实时显示您的 CPU 核心数和剩余可用内存，并引导您输入合适的占用值，防止系统崩溃。)*

### 2. 手动运行脚本

如果您已下载脚本，可以直接运行进入交互菜单：

```bash
# 赋予执行权限
chmod +x lookbusy_manager.sh

# 以 root 权限运行
sudo ./lookbusy_manager.sh
```

### 3. 命令行参数 (非交互模式)

脚本支持带参数直接运行，适合脚本自动化调用：

- **安装**：`sudo ./lookbusy_manager.sh install`
- **启动/更新负载**：`sudo ./lookbusy_manager.sh start [CPU%] [内存大小]`
  - 例如：`sudo ./lookbusy_manager.sh start 15 2G`
- **停止**：`sudo ./lookbusy_manager.sh stop`
- **卸载**：`sudo ./lookbusy_manager.sh uninstall`

### 4. 操作建议

- **CPU 占用**：建议设置在 `15% - 25%` 之间。
- **内存占用**：ARM 机器建议至少占用 `10% - 15%`。
- **验证负载**：在脚本主菜单选择选项 `4`，在弹出的 `top` 界面确认 CPU 占用率（%CPU）已达到预期。

---

## 🛠️ 交互菜单预览

```text
========================================
      Lookbusy VPS 管理菜单 (V1.0)    
========================================
1) 安装 lookbusy (仅需运行一次)
2) 启动/更新 负载配置 (设置 CPU/内存)
3) 停止 负载服务
4) 查看状态 & 实时监控
5) 彻底卸载
0) 退出
========================================
```

## ⚠️ 注意事项

- **风险提示**：生成负载会消耗一定的系统资源，请合理配置参数，避免过度占用导致机器响应极慢。
- **权限说明**：涉及系统服务管理，必须使用 `root` 或 `sudo` 运行。

## 🤝 鸣谢

- 参考教程：[jcnf的导航站](https://iproyal.cn/)
- 原始方案：[荒岛大佬](https://hostalk.com/)
- 工具作者：[Devin Carraway (lookbusy)](http://www.devin.com/lookbusy/)

---
