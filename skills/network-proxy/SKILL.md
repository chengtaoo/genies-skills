---
name: network-proxy
description: >
  网络代理管理，基于 v2rayN 解决国内网络环境下访问 Google、GitHub、HuggingFace
  等境外网站的连通性问题。当 web_fetch、web_search、exec(curl/git/pip/npm)
  等工具操作遇到超时、连接拒绝、DNS 解析失败等网络错误时自动调用此技能。
  也适用于提前为需要访问外网的操作设置代理环境。
  触发场景：(1) 网络请求超时或被拒绝，(2) 需要访问 github/huggingface/google
  等境外网站，(3) git clone/pip install 等操作失败提示网络错误，
  (4) 用户明确要求使用代理。
---

# 网络代理技能

## 概述

此技能用于管理 Windows 上的 v2rayN 代理，让 AI 助手在遇到网络连通性问题时能够自主解决。v2rayN 通过 Xray 核心提供 SOCKS5 代理（端口 10808），所有流量经 VMess 协议加密转发。

> **配置详情**: 参见 [references/v2rayn-config.md](references/v2rayn-config.md)

## 决策流程

```
网络请求失败（超时/拒绝/DNS 错误）
        │
        ▼
   ┌─ 是否目标为境外网站？── 否 ──→ 报告真实网络错误
   │   (google.com, github.com,
   │    huggingface.co, etc.)
   │
   是
   │
   ▼
   ┌─ 检查代理状态 ────────────→ 已运行 ──→ 配置环境变量后重试
   │   (端口 10808 是否监听?)
   │
   未运行
   │
   ▼
   ┌─ 启动 v2rayN
   │   等待端口 10808 可用
   │       │
   │   成功 ──→ 配置环境变量 ──→ 重试网络请求
   │
   失败 ──→ 通知用户：v2rayN 启动失败，需手动检查
```

## 操作步骤

### 步骤 1: 检测代理状态

```powershell
# 方式 A: 使用技能脚本
& "C:\Users\cheng\.openclaw\workspace\skills\network-proxy\scripts\proxy.ps1" -Action status

# 方式 B: 直接检测端口
Test-NetConnection -ComputerName 127.0.0.1 -Port 10808 -InformationLevel Quiet
```

- 端口 10808 可连通 → 代理已在运行，跳到步骤 3
- 端口不通 → 继续步骤 2

### 步骤 2: 启动代理

```powershell
# 一键启动（推荐）
& "C:\Users\cheng\.openclaw\workspace\skills\network-proxy\scripts\proxy.ps1" -Action start
```

此命令会：
1. 检测 v2rayN 是否已运行
2. 如未运行则启动 v2rayN.exe（最小化到系统托盘）
3. 等待端口 10808 变为可用（默认等待 30 秒）
4. 自动设置环境变量
5. 测试 Google/GitHub/HuggingFace 连通性

**手动启动方式**（脚本失败时使用）：
```powershell
Start-Process "D:\soft\v2rayN-windows-64-SelfContained\v2rayN.exe" -WindowStyle Hidden
# 等 5-15 秒让核心启动
Start-Sleep -Seconds 10
```

### 步骤 3: 为当前会话设置代理环境变量

```powershell
# 设置后，当前 PowerShell 会话中的 curl、git、pip、npm 等工具都会走代理
$env:HTTP_PROXY  = "http://127.0.0.1:10808"
$env:HTTPS_PROXY = "http://127.0.0.1:10808"
$env:ALL_PROXY   = "socks5://127.0.0.1:10808"
$env:NO_PROXY    = "localhost,127.0.0.1,*.cn,*.local"
```

> **重要**: 环境变量只在当前 exec 调用中生效。每次新的 exec 调用需要重新设置。

### 步骤 4: 通过代理重试网络操作

设置环境变量后，大部分 CLI 工具自动使用代理：

```powershell
# curl - 自动读取 HTTP_PROXY
curl -s https://www.google.com

# 或显式指定 SOCKS5（绕过环境变量）
curl --socks5-hostname 127.0.0.1:10808 https://github.com

# git clone
git clone https://github.com/user/repo.git

# pip install
pip install torch

# npm install
npm install
```

### 步骤 5（可选）: 停止代理

```powershell
& "C:\Users\cheng\.openclaw\workspace\skills\network-proxy\scripts\proxy.ps1" -Action stop
```

## 常见场景速查

### 场景 A: web_fetch 超时

`web_fetch` 工具不支持 SOCKS5 代理。改用 `exec` + `curl` 实现：

```powershell
$env:ALL_PROXY = "socks5://127.0.0.1:10808"
curl -sL <URL>
```

如果数据量大，可将 curl 输出重定向到文件后读取。

### 场景 B: git clone 失败

```powershell
$env:ALL_PROXY = "socks5://127.0.0.1:10808"
git clone https://github.com/xxx/yyy.git
```

### 场景 C: pip/npm/cargo 安装包超时

```powershell
$env:HTTP_PROXY  = "http://127.0.0.1:10808"
$env:HTTPS_PROXY = "http://127.0.0.1:10808"
pip install <package>
```

### 场景 D: 需要访问 HuggingFace

```powershell
$env:ALL_PROXY = "socks5://127.0.0.1:10808"
curl -sL https://huggingface.co/api/models
# 或使用 huggingface_hub
$env:HF_ENDPOINT = "https://huggingface.co"
pip install huggingface_hub
```

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| 启动后端口仍不通 | 核心启动需要时间 | 等待 10-15 秒后重试 |
| 代理通但外网不通 | 代理服务器可能故障 | 通知用户检查 v2rayN 中服务器状态 |
| v2rayN 闪退/无法启动 | .NET 环境问题 | 以管理员身份运行 |
| 端口 10808 被占用 | 其他程序占用 | `netstat -ano \| findstr 10808` 查占用进程 |
| curl 不走代理 | 环境变量未设置或格式不对 | 确认 ALL_PROXY 格式为 `socks5://127.0.0.1:10808` |

## 脚本工具

`scripts/proxy.ps1` - 代理管理一体化脚本：

```powershell
# 操作
-Action start     # 启动代理并测试
-Action stop      # 停止所有代理进程
-Action status    # 查看运行状态
-Action test      # 测试境外网站连通性
-Action env       # 设置环境变量
-Action restart   # 重启代理
-Action wait      # 等待代理可用（不启动）

# 参数
-TimeoutSeconds 30   # 等待超时（默认30秒）
-TestUrl "..."       # 自定义测试URL
```
