# 🧩 Genies Skills

OpenClaw AI 助手的可复用技能模块集合。

## 📦 技能列表

### 🌐 [network-proxy](skills/network-proxy/)

网络代理管理技能，基于 v2rayN 解决国内网络环境下访问 Google、GitHub、HuggingFace 等境外网站的连通性问题。

**功能：**
- 自动检测/启动/停止 v2rayN 代理
- 一键配置 CLI 工具代理环境变量
- 测试境外网站连通性
- 支持 SO​​CKS5 代理

**触发场景：** 网络请求超时、访问 GitHub/HuggingFace 等境外网站、git clone/pip install 等操作失败

---

## 🚀 安装

将技能目录复制到 OpenClaw 的 skills 目录：

```bash
# 克隆仓库
git clone https://github.com/chengtaoo/genies-skills.git

# 复制所需技能到 workspace skills 目录
# Windows (PowerShell)
Copy-Item -Recurse genies-skills/skills/network-proxy $env:USERPROFILE\.openclaw\workspace\skills\network-proxy

# macOS/Linux
cp -r genies-skills/skills/network-proxy ~/.openclaw/workspace/skills/network-proxy
```

安装后需进行首次配置，告诉技能你的 v2rayN 安装位置：

```powershell
# 方式一：创建配置文件
cd $env:USERPROFILE\.openclaw\workspace\skills\network-proxy\scripts
@{"v2rayN_exe"="D:\path\to\v2rayN.exe"; "proxy_port"=10808} | ConvertTo-Json | Out-File proxy-config.json -Encoding UTF8

# 方式二：设置环境变量
$env:V2RAYN_EXE = "D:\path\to\v2rayN.exe"
```

配置完成后重启 OpenClaw Gateway 即可生效。

## 📁 目录结构

```
genies-skills/
├── skills/                    # 技能集合
│   └── network-proxy/         # 网络代理技能
│       ├── SKILL.md           # 技能定义与指令
│       ├── scripts/           # 可执行脚本
│       │   └── proxy.ps1      # 代理管理脚本
│       └── references/        # 参考文档
│           └── v2rayn-config.md
└── README.md
```

## 🤝 贡献

欢迎提交新的技能或改进现有技能！请确保技能符合 OpenClaw Skill 规范。
