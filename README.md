# Windows Simple Cleanup Script

A batch script to selectively free up disk space on Windows 10/11.

## What it can clean

| # | Target | Path |
|---|--------|------|
| 1 | User TEMP folders | `C:\Users\*\AppData\Local\Temp` |
| 2 | Windows TEMP folder | `C:\Windows\Temp` |
| 3 | User Crash Dumps | `C:\Users\*\AppData\Local\CrashDumps` |
| 4 | Windows Error Reporting | WER report queues |
| 5 | Windows Update cache | `SoftwareDistribution\Download` |
| 6 | Component Store (DISM) | WinSxS cleanup |
| 7 | Recycle Bin | All drives |
| 8 | Browser caches | Chrome, Edge, Firefox |
| 9 | Recent Items + Jump Lists | Explorer history |
| 10 | Thumbnail cache | Explorer thumbcache |
| 11 | Windows Prefetch | `C:\Windows\Prefetch` *(optional)* |

## Requirements

- Windows 10 / 11
- Administrator privileges

## Usage

1. Right-click `cleanup.bat` → **Run as administrator**
2. Answer **Y/N** for each category you want to clean
3. If browser caches are selected, close your browsers before continuing
4. Wait for the process to complete

A timestamped log file is saved automatically in the same folder as the script.

## Notes

- Files in use by the system are skipped automatically and reported in the log.
- DISM (option 6) can take several minutes — it compacts the Windows Component Store.
- Prefetch (option 11) is safe to delete but may slow down the first launch of apps afterwards.
- The script never force-closes any running application.
