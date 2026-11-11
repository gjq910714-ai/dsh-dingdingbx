# 排错手册

## 1. 上传永远失败 / 附件卡片不出现

**症状**：选完文件、点「确定」，附件区什么都没出现；或弹窗里红字转半天。

**原文报错**：

```
错误信息: [HTTP55]space.dingtalk.com...Failed to connect to 127.0.0.1 port 7890
after 2027 ms: Connection refused
```

**根因**：钉钉启动时缓存了当时的系统代理（典型 Clash `127.0.0.1:7890`）。代理关掉后，钉钉仍然往那个端口发请求。

**判定**：先确认网络本身没问题——

```powershell
curl.exe --noproxy "*" -s -o NUL -m 8 -w "%{http_code}`n" https://api.dingtalk.com
# 200 = 网络正常，问题在钉钉自己的代理配置
```

**处置**（代价从低到高）：

1. 占住端口起直连中继 —— **首选**，不动钉钉、不丢表单
   ```powershell
   python scripts/direct_proxy.py            # 默认 127.0.0.1:7890
   ```
   验证：`curl -x http://127.0.0.1:7890 -s -o NUL -w "%{http_code}" https://api.dingtalk.com` → 200
2. 关掉钉钉代理设置（新「千问办公」外壳可能没有这个开关）
3. 重启钉钉 —— 会丢未保存表单，最后手段
4. 提交一次「保存草稿」，重启后从草稿箱续填

## 2. 点了完全没反应

**根因**：DSH 宿主窗口在工具调用后抢回前台，鼠标落在 DSH 上。

**判定**：截图里看到的是 DSH 界面而不是钉钉 → 就是这个问题。

**处置**：用 `scripts/winclick.ps1`，它把 `SetForegroundWindow + SetCursorPos + mouse_event` 放在一个进程里连续做完：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\winclick.ps1 -X 583 -Y 678 -Hwnd <钉钉hwnd>
```

找 hwnd：`(Get-Process DingTalk).MainWindowHandle`

## 3. 点日期点到隔壁一天

**根因**：截图是缩放预览（例如 1920×1080 显示成 1708×961），直接 `预览坐标 × 1.124` 会偏一格，日期差一天，而且看不出问题。

**处置**：不要算比例。**先 Move 到目标，截图看 tooltip（`2026-11-11`）或高亮行，确认后对同一坐标 Click**。

典型偏移：日历格子约 27px 一格，x 方向 1 格误差很常见。

## 4. 「添加发票」进去是 ¥0.00 / 未识别发票

**根因**：企业「发票识别查验」额度为 0 次，提示「剩余识别查验 0 次」。

**处置**：点卡片右侧**铅笔**图标手工编辑（⚠️ 铅笔右边紧邻删除图标，别点错）。填完点「确定」，再点「确认添加」。卡片会带「查验失败」章 —— 正常现象。

## 5. 必填的「发票代码 / 校验码」填不进去

数电票没有这两个字段。填汉字 `无` 可通过（校验只判非空）。

## 6. 表单填一半被自己弄丢

- 没有点过「保存草稿」→ 数据随页面刷新丢失，只能重填。
- 已点过 → 「OA审批 → 我发起的」里会出现一张 **已撤销/草稿** 的单，重新发起更稳（改草稿容易残值）。
- 教训：表单填到一半**不要离开页面**（设置、其他审批、刷新都可能丢）。

## 7. pip 装不上 PyMuPDF

```
ProxyError('Cannot connect to proxy.')  /  WinError 10061
```

系统代理已死但 pip 仍读注册表代理。绕法：

```powershell
curl.exe --noproxy "*" -L -o "$env:TEMP\fitz.whl" "<wheel 直链>"
python -m pip install --no-index --no-deps "$env:TEMP\fitz.whl"
```

（阿里云镜像 /packages/ 路径可直接下 wheel；`/simple/` 页面用 WebClient 拉可能 403。）
