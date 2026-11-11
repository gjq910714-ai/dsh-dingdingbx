# dsh-dingdingbx

**钉钉「日常报销」自动填写 Skill for DeepSeek Harness (DSH).**

给它几个 PDF 发票，它用 Computer Use 打开钉钉、解票、填明细、按「添加发票 → 手工编辑」把你的数电票录进去，最后**停在提交按钮前**把屏幕交还给你。

> 名字里的 `bx` 就是报销（bào xiāo）。

## 它解决什么问题

企业钉钉的「发票识别」额度经常是 0 次，点「添加发票」只会得到一张 `¥0.00 / 未识别发票`。手工填又卡在必填的 `发票代码` 和 `发票校验码` 上——数电票（20 位号码）压根没有这两个字段。

这个 skill 把这条路走通了：识别额度 0 也能录票，缺的字段填 `无`，金额/号码/税号从 PDF 里逐字抄。

## 前置条件

| 条件 | 说明 |
|---|---|
| 钉钉桌面端已登录 | 「工作台 → OA审批 → 日常报销」这条审批必须存在 |
| DSH + Computer Use | 插件 `dsh-windows-mcp`（截图 / 点按 / 键盘） |
| Python 3 + PyMuPDF | 解 PDF 发票文本、渲染 200dpi PNG |
| 钉钉网络通畅 | 若上传报 `[HTTP55] ... 7890 Connection refused`，用仓库里的直连中继 |
| 人在场 | 终点是"提交前交还"，不是无人值守提交 |

## 安装

```powershell
# 1. 放进 DSH 用户级 skill 目录
git clone https://github.com/<you>/dsh-dingdingbx.git
Copy-Item -Recurse .\dsh-dingdingbx "$env:USERPROFILE\.dsh\skills\dsh-dingdingbx"

# 2. 依赖
python -m pip install pymupdf
```

也可以用 `install.ps1`（Windows 一键）：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

装完在 DSH 里问一句「帮我把这两张发票报销掉」，命中 skill 后会按流程走。

## 配套插件（可选，但在 DSH 里维护仓库要靠它）

本 skill 只要 `dsh-windows-mcp` 就能跑。**要在对话里直接建仓 / 改文件 / 开 PR**，装 GitHub MCP 插件：

```powershell
dsh plugin add dsh-github-mcp
```

- 把 GitHub 官方远程 MCP（`api.githubcopilot.com/mcp/`）接进 DSH，工具名 `mcp__github__*`（40+ 个：`search_repositories`、`push_files`、`create_pull_request`、`get_file_contents`…）。
- PAT 存在 DSH 凭据中心 `~/.dsh/.credentials.yaml` 的 `refs.GITHUB_TOKEN`，可用模型工具 `github_set_token` 写入。
- **改完 token 要重启 DSH**（MCP 客户端只在启动时读 token）。
- 没装插件也能发：仓库自带 `publish-github.ps1`，纯 REST API，不需要 git / gh：

```powershell
$env:GITHUB_TOKEN = "ghp_xxx"     # classic PAT，勾 repo
powershell -ExecutionPolicy Bypass -File .\publish-github.ps1
```

## 仓库结构

```
SKILL.md                      # skill 本体（DSH 读取的入口）
references/field-rules.md     # 字段级填写规则 + 发票类型对照
references/troubleshooting.md # 报错 → 根因 → 处置
scripts/extract_invoice.py    # PDF 文本 + 200dpi PNG
scripts/direct_proxy.py       # 占住 7890 的直连中继
scripts/winclick.ps1          # 激活窗口 + 定位 + 点击（单进程，抗抢焦点）
install.ps1                   # 安装到 ~/.dsh/skills
publish-github.ps1            # 纯 REST 发仓库（不需要 git / gh）
```

## 三个真实踩过的坑

1. **上传静默失败** —— 钉钉缓存了已关闭的 `127.0.0.1:7890` 代理，报 `[HTTP55] ... Connection refused`。仓库带一个直连中继，占住端口即可。
2. **点了没反应** —— DSH 宿主窗口会抢前台，鼠标落到 DSH 上。必须把"激活 + 点击"塞进同一个进程。
3. **点错格子** —— 截图是缩放图，硬算 `×1.124` 会偏一格。正确姿势是悬停看 tooltip 再点。

细节见 `references/troubleshooting.md`。

## 不做什么

- 不点「提交」
- 不伪造发票内容（所有字段来自 PDF 原文）
- 不绕过企业审批人配置

## License

MIT
