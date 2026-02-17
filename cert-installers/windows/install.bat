@echo off
REM AgenticGRC Root CA 证书安装脚本 - Windows
REM 需要管理员权限运行

echo 正在安装 AgenticGRC Root CA 证书...
echo.

for %%f in (*.crt) do (
    certutil -addstore -f "ROOT" "%%f"
    if errorlevel 1 (
        echo 错误: 证书安装失败
        echo 请确保以管理员身份运行此脚本
        pause
        exit /b 1
    )
)

echo.
echo 证书安装完成
echo.
pause
