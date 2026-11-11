# Publish this folder as a GitHub repo using only the REST API (no git, no gh).
#
#   $env:GITHUB_TOKEN = "ghp_xxx"          # classic PAT with `repo` scope
#   powershell -ExecutionPolicy Bypass -File .\publish-github.ps1
#   powershell ... -File .\publish-github.ps1 -Owner someuser -Repo dsh-dingdingbx -Private
#
# Behavior: creates the repo if missing (409 = already exists, reused), then
# uploads every file under the repo root via the Contents API, skipping
# .git / node_modules.

param(
    [string]$Owner = "",
    [string]$Repo = "dsh-dingdingbx",
    [string]$Description = "DingTalk reimbursement form auto-fill skill for DeepSeek Harness (Computer Use). 钉钉日常报销自动填写 Skill。",
    [switch]$Private
)

$ErrorActionPreference = "Stop"
$token = $env:GITHUB_TOKEN
if (-not $token) { throw "Set GITHUB_TOKEN first (classic PAT with repo scope)." }

# api.github.com is reachable directly; a stale system proxy (e.g. a closed
# 127.0.0.1:7890) makes Invoke-RestMethod fail with "cannot connect to proxy".
try { [System.Net.WebRequest]::DefaultWebProxy = $null } catch { }

$api = "https://api.github.com"
$headers = @{
    Authorization          = "Bearer $token"
    Accept                 = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent"           = "dsh-dingdingbx-publisher"
}

function Invoke-GH {
    param([string]$Method, [string]$Path, $Body)
    $uri = "$api$Path"
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 6
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($json)) -ContentType "application/json"
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

if (-not $Owner) {
    $me = Invoke-GH -Method GET -Path "/user"
    $Owner = $me.login
    Write-Host "Authenticated as $Owner"
}

# 1. create repo (idempotent)
try {
    $repoInfo = Invoke-GH -Method POST -Path "/user/repos" -Body @{
        name        = $Repo
        description = $Description
        private     = [bool]$Private
        has_issues  = $true
        has_wiki    = $false
    }
    Write-Host "Created repo: $($repoInfo.html_url)"
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code -eq 422) {
        $repoInfo = Invoke-GH -Method GET -Path "/repos/$Owner/$Repo"
        Write-Host "Repo already exists: $($repoInfo.html_url)"
    } else {
        throw
    }
}

$topics = @("dsh", "deepseek-harness", "dingtalk", "skill", "reimbursement", "computer-use", "invoice")
try {
    Invoke-GH -Method PUT -Path "/repos/$Owner/$Repo/topics" -Body @{ names = $topics } | Out-Null
    Write-Host "Topics set"
} catch {
    Write-Host "Topics skipped: $($_.Exception.Message)"
}

# 2. upload files
$root = $PSScriptRoot
$skipDirs = @(".git", "node_modules", "tmp", ".vscode")
$skipFiles = @("publish-github.ps1")

$files = Get-ChildItem -Path $root -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($root.Length).TrimStart("\")
    $parts = $rel -split "\\"
    -not ($parts | Where-Object { $skipDirs -contains $_ }) -and
    -not ($skipFiles -contains $_.Name)
}

foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length).TrimStart("\").Replace("\", "/")
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.FullName))
    $existingSha = $null
    try {
        $cur = Invoke-GH -Method GET -Path "/repos/$Owner/$Repo/contents/$rel"
        $existingSha = $cur.sha
    } catch { }

    $body = @{
        message = "add $rel"
        content = $b64
    }
    if ($existingSha) {
        $body.sha = $existingSha
        $body.message = "update $rel"
    }
    try {
        Invoke-GH -Method PUT -Path "/repos/$Owner/$Repo/contents/$rel" -Body $body | Out-Null
        Write-Host "  ok  $rel"
    } catch {
        Write-Host "  FAIL $rel -> $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Done: $($repoInfo.html_url)"
