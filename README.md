# Magisk Brick Guardian (自动防砖守护)

[![GitHub release](https://img.shields.io/github/release/kirklin/magisk-brick-guardian.svg)](https://github.com/kirklin/magisk-brick-guardian/releases)
[![GitHub license](https://img.shields.io/github/license/kirklin/magisk-brick-guardian.svg)](https://github.com/kirklin/magisk-brick-guardian/blob/main/LICENSE)

一个Magisk 模块，用于防止您的设备因 Magisk 模块导致的启动问题而变砖。

## 特性

- 🛡️ 自动检测并防止模块导致的系统无法启动
- 📝 支持智能白名单机制
- 🔄 OTA升级保护
- ⚡ 快速恢复：当检测到启动异常时，系统将自动进行修复
- 💪 稳定可靠：经过严格测试，确保您的设备安全

## 安装要求

- Android 10.0+
- Magisk 20.4+

## 安装方法

1. 在 Magisk Manager 中下载并安装此模块
2. 重启设备
3. 首次启动后请等待90秒，以确认模块正常运行

## 使用说明

- 模块安装后会自动运行，无需额外配置
- 如需自定义白名单，请编辑 `/data/adb/modules/magisk-brick-guardian/白名单.conf` 文件
- 如遇到无法开机的情况，系统将自动进行修复

## 注意事项

- ⚠️ 安全警告：请仅从本项目的 [GitHub Releases](https://github.com/kirklin/magisk-brick-guardian/releases) 页面下载模块，以防止下载到被恶意篡改的版本
- 首次安装后请耐心等待90秒，让模块完成初始化
- 建议在安装其他模块前先安装本模块，以获得最佳保护
- 如果您修改了白名单配置，请重启设备以使更改生效

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 作者

[Kirk Lin](https://github.com/kirklin)

## 致谢

感谢所有为此项目做出贡献的开发者！ 
