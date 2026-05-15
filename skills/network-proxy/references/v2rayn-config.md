# v2rayN 配置参考

## 安装信息

| 项目 | 值 |
|------|-----|
| 安装路径 | `D:\soft\v2rayN-windows-64-SelfContained\` |
| 主程序 | `v2rayN.exe` |
| 核心引擎 | Xray (`bin\xray.exe`) |
| 配置文件 | `guiConfigs\guiNConfig.json` |
| 核心配置 | `binConfigs\config.json` |

## 代理端口

| 类型 | 地址 | 端口 |
|------|------|------|
| SOCKS5 | 127.0.0.1 | 10808 |

v2rayN 当前只配置了 SOCKS5 入站。通过 Xray 核心的 sniffing 功能，SOCKS5 入站也能处理 HTTP/HTTPS 流量，因此 CLI 工具的 `HTTP_PROXY` 可以指向 `http://127.0.0.1:10808`（大多数工具会将此当做 HTTP 代理地址连通）。

## 当前活跃服务器

- 协议: VMess
- 地址: `14.116.247.18:28988`
- 传输: TCP
- UUID: `5016404a-58f6-4efa-bbd0-c1a33c391945`

## 路由规则

- 私有 IP → 直连
- 私有域名 → 直连
- UDP 443 → 阻止
- 其余所有流量 → 代理

## 系统代理配置

从 guiNConfig.json 提取：

```json
"SystemProxyItem": {
    "SysProxyType": 1,
    "SystemProxyExceptions": "localhost;127.*;10.*;172.16.*;...;192.168.*",
    "NotProxyLocalAddress": true,
    "SystemProxyAdvancedProtocol": "http=http://{ip}:{http_port};https=http://{ip}:{http_port}"
}
```

`AutoRun` 已启用，意味着 v2rayN 启动后会自动连接服务器并开启系统代理。

## v2rayN 进程管理

### 启动
```powershell
Start-Process "D:\soft\v2rayN-windows-64-SelfContained\v2rayN.exe" -WindowStyle Hidden
```
v2rayN 启动后会最小化到系统托盘，自动连接当前活跃服务器。

### 停止
```powershell
# 停止 v2rayN GUI
Get-Process -Name "v2rayN" | Stop-Process -Force
# 停止核心进程
Get-Process -Name "xray", "sing-box" -ErrorAction SilentlyContinue | Stop-Process -Force
```

### 检测运行状态
```powershell
# 检查端口是否在监听
Test-NetConnection -ComputerName 127.0.0.1 -Port 10808 -InformationLevel Quiet
```

## 环境变量

设置后 CLI 工具（curl、wget、git、pip、npm、cargo 等）自动走代理：

```powershell
$env:HTTP_PROXY  = "http://127.0.0.1:10808"
$env:HTTPS_PROXY = "http://127.0.0.1:10808"
$env:ALL_PROXY   = "socks5://127.0.0.1:10808"
$env:NO_PROXY    = "localhost,127.0.0.1,*.cn,*.local"
```

## 故障排查

1. **端口 10808 不监听** → v2rayN 核心未启动，检查 guiNConfig.json 中 `RunningCoreType` 是否为 2 (Xray)
2. **代理连通但无法访问外网** → 检查服务器是否在线，节点是否过期
3. **v2rayN 启动后闪退** → 检查 .NET Runtime 是否安装，尝试以管理员权限运行
4. **端口被占用** → 检查是否有其他程序占用 10808 端口
