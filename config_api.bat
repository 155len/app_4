@echo off
chcp 65001 >nul
echo ================================
echo   API 服务器地址配置工具
echo ================================
echo.

:menu
echo 请选择服务器地址：
echo.
echo 1. 公网地址 (160.202.231.11:54628) - 远程访问
echo 2. 本地模拟器 (10.0.2.2:54628) - Android 模拟器测试
echo 3. 局域网地址 - 真机测试（需要输入 IP）
echo 4. 查看当前配置
echo 5. 退出
echo.
set /p choice=请输入选项 (1-5):

if "%choice%"=="1" goto config_public
if "%choice%"=="2" goto config_emulator
if "%choice%"=="3" goto config_lan
if "%choice%"=="4" goto show_config
if "%choice%"=="5" goto end
goto menu

:config_public
echo.
echo 配置为公网地址...
call :update_config "http://160.202.231.11:54628"
echo 完成！
goto menu

:config_emulator
echo.
echo 配置为本地模拟器地址...
call :update_config "http://10.0.2.2:54628"
echo 完成！
goto menu

:config_lan
echo.
set /p lan_ip=请输入电脑的局域网 IP (例如 192.168.1.100):
call :update_config "http://%lan_ip%:54628"
echo 完成！
goto menu

:show_config
echo.
echo 当前配置：
findstr "baseUrl" lib\config\api_config.dart
echo.
goto menu

:end
exit /b

:update_config
set new_url=%1
echo 正在更新配置为：%new_url%
powershell -Command "(Get-Content 'lib\config\api_config.dart') -replace 'static const String baseUrl = ''http://.*:54628'';', \"static const String baseUrl = '%new_url%';\" | Set-Content 'lib\config\api_config.dart'"
exit /b
