# スキルをホームディレクトリに配置する (Windows)。
#
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1
#
# .claude/skills/ 直下のスキルをすべて ~/.claude/skills・~/.copilot/skills・~/.agents/skills に
# ディレクトリ単位のシンボリックリンクで張る。何度実行してもよい。
# シンボリックリンクには開発者モードか管理者権限が要る。
$ErrorActionPreference = "Stop"

$Src = Join-Path (Split-Path -Parent $PSScriptRoot) ".claude\skills"

foreach ($Dest in @("$HOME\.claude\skills", "$HOME\.copilot\skills", "$HOME\.agents\skills")) {
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null

  # このリポジトリを指したまま切れたリンク (削除・改名されたスキル) を外す
  Get-ChildItem -Force $Dest | Where-Object {
    $_.LinkType -eq "SymbolicLink" -and $_.Target -like "$Src\*" -and -not (Test-Path $_.Target)
  } | ForEach-Object {
    $_.Delete()
    Write-Output "- $($_.FullName) (切れたリンクを外した)"
  }

  Get-ChildItem -Directory $Src | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") } | ForEach-Object {
    $Target = Join-Path $Dest $_.Name
    $Existing = Get-Item -Force $Target -ErrorAction SilentlyContinue
    if ($Existing -and $Existing.LinkType -ne "SymbolicLink") {
      Write-Output "! $Target は実ディレクトリなので触らない (コピーで配置したなら消してから再実行する)"
      return
    }
    # Remove-Item だとリンク先の中身を子要素とみなして確認が出る (-Recurse は PowerShell 5.1 でリンク先まで消す)。
    # .Delete() はリンクだけを外す
    if ($Existing) { $Existing.Delete() }
    New-Item -ItemType SymbolicLink -Path $Target -Target $_.FullName | Out-Null
    Write-Output "✓ $Target"
  }
}
