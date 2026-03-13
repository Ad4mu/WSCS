@echo off
setlocal enabledelayedexpansion
title Windows Cleanup Utility

:: ============================================
::   CHECK ADMINISTRATOR PRIVILEGES
:: ============================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script must be run as Administrator.
    echo Right-click the script and select "Run as administrator".
    pause
    exit /b 1
)

:: ============================================
::   SETUP LOG FILE
:: ============================================
set "logFile=%~dp0cleanup_log_%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%.txt"
set "logFile=%logFile: =0%"

call :log "============================================"
call :log "   Windows Cleanup Utility"
call :log "   Date: %date%   Time: %time%"
call :log "============================================"

:: ============================================
::   SELECTION MENU
:: ============================================
cls
echo ============================================================
echo   Windows Cleanup Utility
echo   Select what you want to clean (Y/N for each option)
echo ============================================================
echo.

call :ask "  [1] User TEMP folders              (C:\Users\*\AppData\Local\Temp)" OPT_TEMP
call :ask "  [2] Windows TEMP folder            (C:\Windows\Temp)" OPT_WINTEMP
call :ask "  [3] User Crash Dumps               (C:\Users\*\AppData\Local\CrashDumps)" OPT_DUMPS
call :ask "  [4] Windows Error Reporting        (WER report queues)" OPT_WER
call :ask "  [5] Windows Update cache           (SoftwareDistribution\Download)" OPT_WUCACHE
call :ask "  [6] Component Store cleanup        (DISM - may take several minutes)" OPT_DISM
call :ask "  [7] Recycle Bin" OPT_RECYCLE
call :ask "  [8] Browser caches                 (Chrome, Edge, Firefox)" OPT_BROWSERS
call :ask "  [9] Recent Items + Jump Lists" OPT_RECENT
call :ask "  [10] Thumbnail cache" OPT_THUMBS
call :ask "  [11] Windows Prefetch cache        (may slow first app launch)" OPT_PREFETCH

:: Warn about browsers if selected
if /I "!OPT_BROWSERS!"=="Y" (
    echo.
    echo   [!] Browser cache cleanup is selected.
    echo       Please close Chrome, Edge and Firefox manually before continuing.
    echo       The script will NOT force-close any application.
    echo.
    pause
)

:: Confirm before proceeding
echo.
echo ============================================================
set /p confirm=   Proceed with selected cleanup? (Y/N): 
if /I not "%confirm%"=="Y" (
    echo Cleanup aborted by user.
    call :log "Cleanup aborted by user."
    pause
    exit /b 0
)

:: ============================================
::   CALCULATE SIZE BEFORE DELETION
:: ============================================
echo.
echo Calculating space to be freed (this may take a moment)...
call :log "--- Size Calculation Phase ---"

set "psScript=%TEMP%\calc_size_cu.ps1"
(
    echo $size = 0
    echo $folders = @^(^)
    echo if^('%OPT_TEMP%' -eq 'Y'^)    { Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue ^| ForEach-Object { $folders += "$^($_.FullName^)\AppData\Local\Temp" } }
    echo if^('%OPT_WINTEMP%' -eq 'Y'^) { $folders += 'C:\Windows\Temp' }
    echo if^('%OPT_DUMPS%' -eq 'Y'^)   { Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue ^| ForEach-Object { $folders += "$^($_.FullName^)\AppData\Local\CrashDumps" } }
    echo if^('%OPT_WER%' -eq 'Y'^)     { $folders += "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue"; $folders += "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive"; $folders += "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"; $folders += "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" }
    echo if^('%OPT_WUCACHE%' -eq 'Y'^) { $folders += 'C:\Windows\SoftwareDistribution\Download' }
    echo if^('%OPT_PREFETCH%' -eq 'Y'^){ $folders += 'C:\Windows\Prefetch' }
    echo foreach ^($f in $folders^) {
    echo     if ^(Test-Path $f^) {
    echo         $s = ^(Get-ChildItem $f -Recurse -Force -ErrorAction SilentlyContinue ^| Measure-Object -Property Length -Sum^).Sum
    echo         if ^($s^) { $size += $s }
    echo     }
    echo }
    echo [math]::Round^($size / 1MB, 2^)
) > "%psScript%"

for /f "delims=" %%s in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%psScript%"') do set "totalMB=%%s"
del /q "%psScript%" >nul 2>&1
if not defined totalMB set "totalMB=0"

echo Estimated space to be freed: ~%totalMB% MB
call :log "Estimated space to be freed: ~%totalMB% MB"
echo.
pause

:: ============================================
::   INITIALIZE COUNTERS
:: ============================================
set deletedFiles=0
set skippedFiles=0
set deletedFolders=0

:: ============================================
::   [1] USER TEMP FOLDERS
:: ============================================
if /I "%OPT_TEMP%"=="Y" (
    echo.
    echo [1/11] Cleaning User TEMP folders...
    call :log "--- [1] User TEMP Folders ---"
    for /d %%i in ("C:\Users\*") do (
        if exist "%%i\AppData\Local\Temp" (
            call :log "  Processing: %%i\AppData\Local\Temp"
            call :deleteContents "%%i\AppData\Local\Temp"
        )
    )
    echo OK.
)

:: ============================================
::   [2] WINDOWS TEMP
:: ============================================
if /I "%OPT_WINTEMP%"=="Y" (
    echo.
    echo [2/11] Cleaning Windows TEMP folder...
    call :log "--- [2] Windows TEMP ---"
    call :deleteContents "C:\Windows\Temp"
    echo OK.
)

:: ============================================
::   [3] USER CRASH DUMPS
:: ============================================
if /I "%OPT_DUMPS%"=="Y" (
    echo.
    echo [3/11] Cleaning User Crash Dumps...
    call :log "--- [3] User Crash Dumps ---"
    for /d %%i in ("C:\Users\*") do (
        if exist "%%i\AppData\Local\CrashDumps" (
            call :log "  Processing: %%i\AppData\Local\CrashDumps"
            call :deleteContents "%%i\AppData\Local\CrashDumps"
        )
    )
    echo OK.
)

:: ============================================
::   [4] WINDOWS ERROR REPORTING
:: ============================================
if /I "%OPT_WER%"=="Y" (
    echo.
    echo [4/11] Cleaning Windows Error Reporting...
    call :log "--- [4] Windows Error Reporting ---"
    call :deleteContents "%LOCALAPPDATA%\Microsoft\Windows\WER\ReportQueue"
    call :deleteContents "%LOCALAPPDATA%\Microsoft\Windows\WER\ReportArchive"
    call :deleteContents "%PROGRAMDATA%\Microsoft\Windows\WER\ReportQueue"
    call :deleteContents "%PROGRAMDATA%\Microsoft\Windows\WER\ReportArchive"
    echo OK.
)

:: ============================================
::   [5] WINDOWS UPDATE CACHE
:: ============================================
if /I "%OPT_WUCACHE%"=="Y" (
    echo.
    echo [5/11] Cleaning Windows Update cache...
    call :log "--- [5] Windows Update Cache ---"
    echo   Stopping Windows Update services...
    net stop wuauserv >nul 2>&1
    net stop bits >nul 2>&1
    call :log "  Services stopped: wuauserv, bits"
    call :deleteContents "%SystemRoot%\SoftwareDistribution\Download"
    echo   Restarting Windows Update services...
    net start wuauserv >nul 2>&1
    net start bits >nul 2>&1
    call :log "  Services restarted: wuauserv, bits"
    echo OK.
)

:: ============================================
::   [6] DISM COMPONENT STORE
:: ============================================
if /I "%OPT_DISM%"=="Y" (
    echo.
    echo [6/11] Running DISM Component Store cleanup...
    echo   This may take several minutes, please wait...
    call :log "--- [6] DISM Component Store ---"
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup >> "%logFile%" 2>&1
    echo OK.
)

:: ============================================
::   [7] RECYCLE BIN
:: ============================================
if /I "%OPT_RECYCLE%"=="Y" (
    echo.
    echo [7/11] Emptying Recycle Bin...
    call :log "--- [7] Recycle Bin ---"
    powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >> "%logFile%" 2>&1
    call :log "  Recycle Bin cleared."
    echo OK.
)

:: ============================================
::   [8] BROWSER CACHES
:: ============================================
if /I "%OPT_BROWSERS%"=="Y" (
    echo.
    echo [8/11] Cleaning browser caches...
    call :log "--- [8] Browser Caches ---"

    call :log "  Chrome:"
    for /d %%P in ("%LOCALAPPDATA%\Google\Chrome\User Data\*") do (
        call :deleteFolderIfExists "%%~fP\Cache"
        call :deleteFolderIfExists "%%~fP\Code Cache"
        call :deleteFolderIfExists "%%~fP\GPUCache"
        call :deleteFolderIfExists "%%~fP\Service Worker\CacheStorage"
    )

    call :log "  Edge:"
    for /d %%P in ("%LOCALAPPDATA%\Microsoft\Edge\User Data\*") do (
        call :deleteFolderIfExists "%%~fP\Cache"
        call :deleteFolderIfExists "%%~fP\Code Cache"
        call :deleteFolderIfExists "%%~fP\GPUCache"
        call :deleteFolderIfExists "%%~fP\Service Worker\CacheStorage"
    )

    call :log "  Firefox:"
    for /d %%P in ("%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*") do (
        call :deleteFolderIfExists "%%~fP\cache2"
    )
    for /d %%P in ("%APPDATA%\Mozilla\Firefox\Profiles\*") do (
        call :deleteFolderIfExists "%%~fP\cache2"
    )
    echo OK.
)

:: ============================================
::   [9] RECENT ITEMS
:: ============================================
if /I "%OPT_RECENT%"=="Y" (
    echo.
    echo [9/11] Cleaning Recent Items and Jump Lists...
    call :log "--- [9] Recent Items ---"
    del /f /q "%APPDATA%\Microsoft\Windows\Recent\*" >> "%logFile%" 2>&1
    call :deleteFolderIfExists "%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations"
    call :deleteFolderIfExists "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations"
    echo OK.
)

:: ============================================
::   [10] THUMBNAIL CACHE
:: ============================================
if /I "%OPT_THUMBS%"=="Y" (
    echo.
    echo [10/11] Cleaning Thumbnail cache...
    call :log "--- [10] Thumbnail Cache ---"
    del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*" >> "%logFile%" 2>&1
    call :log "  Thumbnail cache cleared."
    echo OK.
)

:: ============================================
::   [11] PREFETCH
:: ============================================
if /I "%OPT_PREFETCH%"=="Y" (
    echo.
    echo [11/11] Cleaning Prefetch cache...
    call :log "--- [11] Prefetch ---"
    call :deleteContents "C:\Windows\Prefetch"
    echo OK.
)

:: ============================================
::   FINAL REPORT
:: ============================================
echo.
echo ============================================================
echo   Cleanup Completed
echo ============================================================
echo   Space freed approx  : ~%totalMB% MB
echo   Files deleted       : %deletedFiles%
echo   Files skipped       : %skippedFiles%  (in use or protected)
echo   Folders removed     : %deletedFolders%
echo   Log saved to        : %logFile%
echo ============================================================
call :log "============================================"
call :log "Cleanup completed."
call :log "Files deleted  : %deletedFiles%"
call :log "Files skipped  : %skippedFiles%"
call :log "Folders removed: %deletedFolders%"
call :log "============================================"
echo.
pause
exit /b 0


:: ============================================
::   SUBROUTINE: Ask Y/N question
::   Usage: call :ask "Question text" VARNAME
:: ============================================
:ask
set /p "%~2=[?] %~1 (Y/N): "
if /I "!%~2!"=="Y" exit /b 0
if /I "!%~2!"=="N" exit /b 0
echo     Please enter Y or N.
goto :ask


:: ============================================
::   SUBROUTINE: Delete contents of a folder
::   Usage: call :deleteContents "path"
:: ============================================
:deleteContents
set "_dc=%~1"
if not exist "%_dc%" exit /b 0

for /r "%_dc%" %%f in (*) do (
    del /f /q "%%f" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a deletedFiles+=1
        call :log "  DELETED: %%f"
    ) else (
        set /a skippedFiles+=1
        call :log "  SKIPPED (in use): %%f"
    )
)
for /d /r "%_dc%" %%d in (*) do (
    rmdir /s /q "%%d" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a deletedFolders+=1
        call :log "  REMOVED DIR: %%d"
    )
)
exit /b 0


:: ============================================
::   SUBROUTINE: Delete a specific folder
::   Usage: call :deleteFolderIfExists "path"
:: ============================================
:deleteFolderIfExists
set "_df=%~1"
if not exist "%_df%" exit /b 0
rmdir /s /q "%_df%" >nul 2>&1
if !errorlevel! equ 0 (
    set /a deletedFolders+=1
    call :log "  REMOVED DIR: %_df%"
) else (
    set /a skippedFiles+=1
    call :log "  SKIPPED DIR (in use): %_df%"
)
exit /b 0


:: ============================================
::   SUBROUTINE: Write to log file
::   Usage: call :log "message"
:: ============================================
:log
echo [%time%] %~1 >> "%logFile%"
exit /b 0
