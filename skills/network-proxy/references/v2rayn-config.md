# v2rayN 配置参考

## 关于 v2rayN

[v2rayN](https://github.com/2dust/v2rayN) 是一款跨平台（Windows/Linux/macOS）GUI 代理客户端，支持 Xray、sing-box 等多种核心引擎。

## 下载与安装

从 GitHub Releases 下载：
- **SelfContained 版本**（推荐）：无需安装 .NET Runtime
- **普通版本**：需安装 [.NET 8.0 Desktop Runtime](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)

## 代理端口

v2rayN 默认在本地启动入站代理：

| 类型 | 默认地址 | 默认端口 |
|------|----------|----------|
| SOCKS5 | 127.0.0.1 | 10808 |
| HTTP | 127.0.0.1 | 10809 |

> **注意**：端口号可在 v2rayN 设置中修改。请根据实际配置调整 `proxy-config.json`。

## 配置文件位置

| 文件 | 路径 | 说明 |
|------|------|------|
| GUI 配置 | `guiConfigs/guiNConfig.json` | v2rayN 主配置 |
| 核心配置 | `binConfigs/config.json` | Xray/sing-box 核心配置 |

## 系统代理设置

v2rayN 可通过系统托盘图标右键 → "自动配置系统代理" 来启用/禁用系统级代理。

高级设置中可配置：
- **代理协议**：`http=http://{ip}:{http_port};https=http://{ip}:{http_port}`
- **例外地址**：`localhost;127.*;10.*;172.16.*;...;192.168.*`

## 服务器配置

v2rayN 支持多种协议导入服务器：
- **VMess / VLESS / Trojan / Shadowsocks** 等
- 支持订阅链接自动更新节点
- 支持二维码导入

具体服务器配置请参考你的 VPN 服务提供商的文档。

## 环境变量参考

设置后 CLI 工具（curl、wget、git、pip、npm、cargo 等）自动走代理：

```powershell
# SOCKS5 代理（推荐，通用性最好）
$env:ALL_PROXY = "socks5://127.0.0.1:10808"

# HTTP 代理
$env:HTTP_PROXY  = "http://127.0.0.1:10808"
$env:HTTPS_PROXY = "http://127.0.0.1:10808"

# 不走代理的地址
$env:NO_PROXY = "localhost,127.0.0.1,*.cn,*.local"
```

> `ALL_PROXY` 对 git/curl 等工具有效。`HTTP_PROXY`/`HTTPS_PROXY` 对 pip/npm 等工具有效。

## 进程管理

```powershell
# 启动（最小化到系统托盘）
Start-Process "path\to\v2rayN.exe" -WindowStyle Hidden

# 停止
Get-Process -Name "v2rayN" | Stop-Process -Force
Get-Process -Name "xray" -ErrorAction SilentlyContinue | Stop-Process -Force
```

## 常见问题

1. **端口不通** → 等待 5-15 秒让核心启动，或检查 v2rayN 内服务器是否已激活
2. **代理通但外网不通** → 检查节点是否过期，尝试切换服务器
3. **启动闪退** → 以管理员身份运行，或检查 .NET Runtime（SelfContained 版本不需要）
4. **端口冲突** → 在 v2rayN 设置中修改入站端口
5. **AutoRun 不生效** → 在 guiNConfig.json 中确认 `GuiItem.AutoRun = true`
