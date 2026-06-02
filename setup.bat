@echo off
:: ============================================================
:: Helpdesk2 Hands-on Setup Script
:: Claude Code memory files を正しい場所にコピーします
:: ============================================================

echo.
echo ====================================
echo  Helpdesk2 Hands-on Setup
echo ====================================
echo.

:: メモリの保存先（Claude Codeがプロジェクトパスから自動計算するパス）
set MEMORY_DIR=%USERPROFILE%\.claude\projects\c--dev-MxCLI-Handson-Helpdesk2\memory

:: フォルダ作成
if not exist "%MEMORY_DIR%" (
    mkdir "%MEMORY_DIR%"
    echo [OK] Memory directory created: %MEMORY_DIR%
) else (
    echo [OK] Memory directory exists: %MEMORY_DIR%
)

:: メモリファイルをコピー
echo.
echo Copying memory files...
xcopy /Y handson\memory\MEMORY.md "%MEMORY_DIR%\" >nul
xcopy /Y handson\memory\feedback.md "%MEMORY_DIR%\" >nul
xcopy /Y handson\memory\playwright-knowledge.md "%MEMORY_DIR%\" >nul
echo [OK] Memory files copied.

echo.
echo ====================================
echo  Setup complete!
echo.
echo  Next steps:
echo   1. Open Studio Pro: Helpdesk2.mpr
echo   2. Start Claude Code: claude
echo ====================================
echo.
pause
