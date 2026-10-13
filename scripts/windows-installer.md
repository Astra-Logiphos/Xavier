# Windows 安装包扩展点

当前只构建完整 runner Release 目录的便携 ZIP。未来用 Inno Setup / MSIX，配置 exe、DLL、data、安装卸载和版本，不能只复制单个 exe。
在 GitHub windows-latest 增加官方安装工具与签名 Secret。真实发布前需干净 Windows 实机验证、签名证书和依赖安装检查。不使用 self-hosted runner。此文档是扩展计划，不是假安装包构建成功。
