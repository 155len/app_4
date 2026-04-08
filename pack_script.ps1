# 项目打包脚本 - 排除大型文件和构建产物
$zipPath = "xuetang_dev.zip"
$exclude = @('build', '.dart_tool', '.idea', 'flutter_sdk', '.claude', 'server', '.git')

# 获取所有要打包的文件和文件夹
$items = Get-ChildItem -Path "." | Where-Object {
    $exclude -notcontains $_.Name
} | Where-Object {
    $_.Name -notlike "*.zip" -and $_.Name -notlike "*.log"
}

# 创建压缩包
Compress-Archive -Path $items.FullName -DestinationPath $zipPath -Force

Write-Host "已创建：$zipPath" -ForegroundColor Green

# 显示文件大小
$size = (Get-Item $zipPath).Length
Write-Host "文件大小：{0:N0} MB" -f ($size / 1MB) -ForegroundColor Green
