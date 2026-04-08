@echo off
chcp 65001 >nul
echo ========================================
echo   项目打包脚本 - 用于开发环境迁移
echo ========================================
echo.

echo 正在创建压缩包...
echo.

powershell -ExecutionPolicy Bypass -File pack_script.ps1

echo.
if exist xuetang_dev.zip (
    echo ========================================
    echo   打包完成!
    echo   文件：xuetang_dev.zip
    for %%A in (xuetang_dev.zip) do echo   大小：%%~zA 字节
    echo ========================================
) else (
    echo 打包失败
)

echo.
echo 在另一台电脑上:
echo 1. 解压 xuetang_dev.zip
echo 2. flutter pub get
echo 3. 运行项目
echo.

pause
