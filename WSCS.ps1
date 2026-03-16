#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Cleanup Utility - Limpia archivos temporales y cachés del sistema.
.DESCRIPTION
    Menú interactivo con checkboxes. Usa las flechas arriba/abajo para moverte,
    ESPACIO para marcar/desmarcar, A para seleccionar todo, N para
    deseleccionar todo y ENTER para confirmar.
.NOTES
    Debe ejecutarse como Administrador.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# ============================================
#   CONFIGURACIÓN DEL LOG
# ============================================
$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$scriptDir = if ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
}
$logFile   = Join-Path $scriptDir "cleanup_log_$timestamp.txt"

$script:deletedFiles   = 0
$script:skippedFiles   = 0
$script:deletedFolders = 0

function Write-Log {
    param([string]$Message)
    $entry = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    Add-Content -Path $logFile -Value $entry -Encoding UTF8
}

function Write-Header {
    param([string]$Text)
    Write-Host "`n  $Text" -ForegroundColor Cyan
    Write-Log "--- $Text ---"
}

function Write-OK   { Write-Host "  OK." -ForegroundColor Green }
function Write-Info { param([string]$m) Write-Host "  $m" -ForegroundColor Gray }

# ============================================
#   MENU INTERACTIVO DE CHECKBOXES
# ============================================
function Show-CheckboxMenu {
    param(
        [string]$Title,
        [string[]]$Options
    )

    # Array tipado para evitar problemas de coercion
    $checked  = [bool[]]( 1..$Options.Count | ForEach-Object { $true } )
    $cursor   = 0
    $done     = $false
    $helpLine = "  [ESPACIO] Marcar/Desmarcar   [A] Todo   [N] Ninguno   [ENTER] Confirmar"

    # Vaciar buffer de teclado antes de empezar
    while ($Host.UI.RawUI.KeyAvailable) {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    # Reservar espacio en consola para el menu
    $totalLines = $Options.Count + 8
    for ($i = 0; $i -lt $totalLines; $i++) { Write-Host "" }
    $startTop = $Host.UI.RawUI.CursorPosition.Y - $totalLines

    function Render-Menu {
        $pos   = $Host.UI.RawUI.CursorPosition
        $pos.X = 0
        $pos.Y = $startTop
        $Host.UI.RawUI.CursorPosition = $pos

        Write-Host ""
        Write-Host "  $Title" -ForegroundColor Yellow
        Write-Host ("  " + ([string][char]0x2500) * 78) -ForegroundColor DarkGray
        Write-Host ""

        for ($i = 0; $i -lt $Options.Count; $i++) {
            $isCurrent = ($i -eq $cursor)
            $isChecked = $checked[$i]
            $checkbox  = if ($isChecked) { "[x]" } else { "[ ]" }
            $arrow     = if ($isCurrent) { " > " } else { "   " }
            $line      = "$arrow$checkbox  $($Options[$i])"

            if     ($isCurrent -and $isChecked) { Write-Host $line -ForegroundColor Green    }
            elseif ($isCurrent)                 { Write-Host $line -ForegroundColor White    }
            elseif ($isChecked)                 { Write-Host $line -ForegroundColor DarkGreen }
            else                                { Write-Host $line -ForegroundColor DarkGray  }
        }

        Write-Host ""
        Write-Host ("  " + ([string][char]0x2500) * 78) -ForegroundColor DarkGray
        Write-Host $helpLine -ForegroundColor DarkCyan
        Write-Host ""
    }

    [Console]::CursorVisible = $false

    try {
        while (-not $done) {
            Render-Menu

            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            switch ($key.VirtualKeyCode) {
                38 { # Flecha arriba
                    if ($cursor -gt 0) { $cursor-- } else { $cursor = $Options.Count - 1 }
                }
                40 { # Flecha abajo
                    if ($cursor -lt $Options.Count - 1) { $cursor++ } else { $cursor = 0 }
                }
                32 { # Espacio - toggle
                    $checked[$cursor] = -not $checked[$cursor]
                }
                65 { # A - seleccionar todo
                    for ($i = 0; $i -lt $checked.Count; $i++) { $checked[$i] = $true }
                }
                78 { # N - deseleccionar todo
                    for ($i = 0; $i -lt $checked.Count; $i++) { $checked[$i] = $false }
                }
                13 { # Enter - salir del bucle
                    $done = $true
                }
            }
        }
    } finally {
        [Console]::CursorVisible = $true
    }

    # Return fuera del try/finally para garantizar que el valor se propaga
    return ,$checked
}

# ============================================
#   FUNCIONES DE LIMPIEZA
# ============================================
function Remove-FolderContents {
    param([string]$FolderPath)
    if (-not (Test-Path $FolderPath)) { return }
    Write-Log "  Processing: $FolderPath"

    Get-ChildItem -Path $FolderPath -Recurse -Force -File |
        ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                $script:deletedFiles++
                Write-Log "  DELETED: $($_.FullName)"
            } catch {
                $script:skippedFiles++
                Write-Log "  SKIPPED (en uso): $($_.FullName)"
            }
        }

    Get-ChildItem -Path $FolderPath -Recurse -Force -Directory |
        Sort-Object FullName -Descending |
        ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -Recurse -ErrorAction Stop
                $script:deletedFolders++
                Write-Log "  REMOVED DIR: $($_.FullName)"
            } catch {
                Write-Log "  SKIPPED DIR (en uso): $($_.FullName)"
            }
        }
}

function Remove-FolderIfExists {
    param([string]$FolderPath)
    if (-not (Test-Path $FolderPath)) { return }
    try {
        Remove-Item $FolderPath -Recurse -Force -ErrorAction Stop
        $script:deletedFolders++
        Write-Log "  REMOVED DIR: $FolderPath"
    } catch {
        $script:skippedFiles++
        Write-Log "  SKIPPED DIR (en uso): $FolderPath"
    }
}

# ============================================
#   ENCABEZADO
# ============================================
Clear-Host
Write-Host ""
Write-Host "  +----------------------------------+" -ForegroundColor Yellow
Write-Host "  |          WINDOWS SIMPLE          |" -ForegroundColor Yellow
Write-Host "  |          CLEANUP UTILITY         |" -ForegroundColor Yellow
Write-Host "  +----------------------------------+" -ForegroundColor Yellow

Write-Log "============================================"
Write-Log "   Windows Cleanup Utility"
Write-Log "   Fecha: $(Get-Date)"
Write-Log "============================================"

# ============================================
#   DEFINICION DE OPCIONES
# ============================================
$menuOptions = @(
    "[1]  Carpetas TEMP de usuario        C:\Users\*\AppData\Local\Temp"
    "[2]  Carpeta TEMP de Windows         C:\Windows\Temp"
    "[3]  Volcados de memoria             CrashDumps de usuario"
    "[4]  Informes de errores Windows     WER report queues"
    "[5]  Cache de Windows Update         SoftwareDistribution\Download"
    "[6]  Limpieza Component Store        DISM (puede tardar varios minutos)"
    "[7]  Papelera de reciclaje"
    "[8]  Caches de navegadores           Chrome, Edge, Firefox"
    "[9]  Elementos recientes             Recent Items y Jump Lists"
    "[10] Cache de miniaturas             Thumbnail cache"
    "[11] Cache Prefetch                  (puede ralentizar el primer inicio)"
)

# Mostrar menu y capturar seleccion
$selected = Show-CheckboxMenu -Title "Selecciona que limpiar:" -Options $menuOptions

# Mapear indices a nombres
$opt = @{
    Temp     = $selected[0]
    WinTemp  = $selected[1]
    Dumps    = $selected[2]
    WER      = $selected[3]
    WUCache  = $selected[4]
    DISM     = $selected[5]
    Recycle  = $selected[6]
    Browsers = $selected[7]
    Recent   = $selected[8]
    Thumbs   = $selected[9]
    Prefetch = $selected[10]
}

# Verificar que se eligio al menos una opcion
$anySelected = $false
foreach ($s in $selected) { if ($s -eq $true) { $anySelected = $true; break } }
if (-not $anySelected) {
    Write-Host "`n  No has seleccionado ninguna opcion. Saliendo." -ForegroundColor Red
    Write-Log "Limpieza cancelada: ninguna opcion seleccionada."
    Read-Host "`n  Pulsa ENTER para salir"
    exit 0
}

# ============================================
#   RESUMEN DE LO SELECCIONADO
# ============================================
Clear-Host
Write-Host ""
Write-Host "  +---------------------------------------+" -ForegroundColor Yellow
Write-Host "  |          RESUMEN DE LIMPIEZA          |" -ForegroundColor Yellow
Write-Host "  +---------------------------------------+" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Se limpiaran los siguientes elementos:" -ForegroundColor White
Write-Host ""
for ($i = 0; $i -lt $menuOptions.Count; $i++) {
    if ($selected[$i]) {
        Write-Host "   [OK] $($menuOptions[$i])" -ForegroundColor Green
    }
}

# Aviso navegadores
if ($opt.Browsers) {
    Write-Host ""
    Write-Host "  +----------------------------------------------------------+" -ForegroundColor Red
    Write-Host "  | [!] Cierra Chrome, Edge y Firefox antes de continuar.    |" -ForegroundColor Red
    Write-Host "  |     El script NO cerrara ninguna app automaticamente.    |" -ForegroundColor Red
    Write-Host "  +----------------------------------------------------------+" -ForegroundColor Red
    Read-Host "`n  Pulsa ENTER cuando hayas cerrado los navegadores"
}

# ============================================
#   CONFIRMACION FINAL
# ============================================
Write-Host ""
$confirm = Read-Host "  Proceder con la limpieza? (S/N)"
if ($confirm -notmatch '^[Ss]$') {
    Write-Host "`n  Limpieza cancelada por el usuario." -ForegroundColor Red
    Write-Log "Limpieza cancelada por el usuario."
    Read-Host "`n  Pulsa ENTER para salir"
    exit 0
}

# ============================================
#   CALCULAR ESPACIO ANTES DE BORRAR
# ============================================
Write-Host "`n  Calculando espacio a liberar..." -ForegroundColor Gray

$foldersToMeasure = [System.Collections.Generic.List[string]]::new()

if ($opt.Temp)    { Get-ChildItem 'C:\Users' -Directory | ForEach-Object { $foldersToMeasure.Add("$($_.FullName)\AppData\Local\Temp") } }
if ($opt.WinTemp) { $foldersToMeasure.Add('C:\Windows\Temp') }
if ($opt.Dumps)   { Get-ChildItem 'C:\Users' -Directory | ForEach-Object { $foldersToMeasure.Add("$($_.FullName)\AppData\Local\CrashDumps") } }
if ($opt.WER)     {
    $foldersToMeasure.Add("$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue")
    $foldersToMeasure.Add("$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive")
    $foldersToMeasure.Add("$env:ProgramData\Microsoft\Windows\WER\ReportQueue")
    $foldersToMeasure.Add("$env:ProgramData\Microsoft\Windows\WER\ReportArchive")
}
if ($opt.WUCache) { $foldersToMeasure.Add('C:\Windows\SoftwareDistribution\Download') }
if ($opt.Prefetch){ $foldersToMeasure.Add('C:\Windows\Prefetch') }

$totalBytes = 0
foreach ($folder in $foldersToMeasure) {
    if (Test-Path $folder) {
        $size = (Get-ChildItem $folder -Recurse -Force -File | Measure-Object -Property Length -Sum).Sum
        if ($size) { $totalBytes += $size }
    }
}
$totalMB = [math]::Round($totalBytes / 1MB, 2)

Write-Host "  Espacio estimado a liberar: ~$totalMB MB`n" -ForegroundColor White
Write-Log "Espacio estimado a liberar: ~$totalMB MB"

# ============================================
#   [1] TEMP DE USUARIO
# ============================================
if ($opt.Temp) {
    Write-Header "[1/11] Limpiando carpetas TEMP de usuario..."
    Get-ChildItem 'C:\Users' -Directory | ForEach-Object {
        $path = "$($_.FullName)\AppData\Local\Temp"
        if (Test-Path $path) { Remove-FolderContents $path }
    }
    Write-OK
}

# ============================================
#   [2] TEMP DE WINDOWS
# ============================================
if ($opt.WinTemp) {
    Write-Header "[2/11] Limpiando carpeta TEMP de Windows..."
    Remove-FolderContents 'C:\Windows\Temp'
    Write-OK
}

# ============================================
#   [3] VOLCADOS DE MEMORIA
# ============================================
if ($opt.Dumps) {
    Write-Header "[3/11] Limpiando volcados de memoria de usuario..."
    Get-ChildItem 'C:\Users' -Directory | ForEach-Object {
        $path = "$($_.FullName)\AppData\Local\CrashDumps"
        if (Test-Path $path) { Remove-FolderContents $path }
    }
    Write-OK
}

# ============================================
#   [4] WINDOWS ERROR REPORTING
# ============================================
if ($opt.WER) {
    Write-Header "[4/11] Limpiando informes de errores de Windows..."
    Remove-FolderContents "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue"
    Remove-FolderContents "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive"
    Remove-FolderContents "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
    Remove-FolderContents "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
    Write-OK
}

# ============================================
#   [5] CACHE DE WINDOWS UPDATE
# ============================================
if ($opt.WUCache) {
    Write-Header "[5/11] Limpiando cache de Windows Update..."
    Write-Info "Deteniendo servicios wuauserv y bits..."
    Stop-Service -Name wuauserv, bits -Force
    Write-Log "  Servicios detenidos: wuauserv, bits"
    Remove-FolderContents "$env:SystemRoot\SoftwareDistribution\Download"
    Write-Info "Reiniciando servicios wuauserv y bits..."
    Start-Service -Name wuauserv, bits
    Write-Log "  Servicios reiniciados: wuauserv, bits"
    Write-OK
}

# ============================================
#   [6] DISM COMPONENT STORE
# ============================================
if ($opt.DISM) {
    Write-Header "[6/11] Ejecutando limpieza del Component Store (DISM)..."
    Write-Info "Esto puede tardar varios minutos, por favor espera..."
    $dismOutput = & Dism.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1
    $dismOutput | ForEach-Object { Write-Log "  DISM: $_" }
    Write-OK
}

# ============================================
#   [7] PAPELERA DE RECICLAJE
# ============================================
if ($opt.Recycle) {
    Write-Header "[7/11] Vaciando Papelera de reciclaje..."
    Clear-RecycleBin -Force
    Write-Log "  Papelera vaciada."
    Write-OK
}

# ============================================
#   [8] CACHES DE NAVEGADORES
# ============================================
if ($opt.Browsers) {
    Write-Header "[8/11] Limpiando caches de navegadores..."
    $browserCacheFolders = @('Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage')

    Write-Log "  Chrome:"
    if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data") {
        Get-ChildItem "$env:LOCALAPPDATA\Google\Chrome\User Data" -Directory |
            ForEach-Object { foreach ($sub in $browserCacheFolders) { Remove-FolderIfExists (Join-Path $_.FullName $sub) } }
    }

    Write-Log "  Edge:"
    if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data") {
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Edge\User Data" -Directory |
            ForEach-Object { foreach ($sub in $browserCacheFolders) { Remove-FolderIfExists (Join-Path $_.FullName $sub) } }
    }

    Write-Log "  Firefox:"
    @("$env:LOCALAPPDATA\Mozilla\Firefox\Profiles", "$env:APPDATA\Mozilla\Firefox\Profiles") |
        Where-Object { Test-Path $_ } |
        ForEach-Object {
            Get-ChildItem $_ -Directory |
                ForEach-Object { Remove-FolderIfExists (Join-Path $_.FullName 'cache2') }
        }

    Write-OK
}

# ============================================
#   [9] ELEMENTOS RECIENTES
# ============================================
if ($opt.Recent) {
    Write-Header "[9/11] Limpiando elementos recientes y Jump Lists..."
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    Get-ChildItem $recentPath -File -Force | ForEach-Object {
        try {
            Remove-Item $_.FullName -Force -ErrorAction Stop
            $script:deletedFiles++
            Write-Log "  DELETED: $($_.FullName)"
        } catch {
            $script:skippedFiles++
            Write-Log "  SKIPPED: $($_.FullName)"
        }
    }
    Remove-FolderIfExists "$recentPath\AutomaticDestinations"
    Remove-FolderIfExists "$recentPath\CustomDestinations"
    Write-OK
}

# ============================================
#   [10] CACHE DE MINIATURAS
# ============================================
if ($opt.Thumbs) {
    Write-Header "[10/11] Limpiando cache de miniaturas..."
    Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache_*' -File -Force |
        ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                $script:deletedFiles++
                Write-Log "  DELETED: $($_.FullName)"
            } catch {
                $script:skippedFiles++
                Write-Log "  SKIPPED: $($_.FullName)"
            }
        }
    Write-OK
}

# ============================================
#   [11] PREFETCH
# ============================================
if ($opt.Prefetch) {
    Write-Header "[11/11] Limpiando cache Prefetch..."
    Remove-FolderContents 'C:\Windows\Prefetch'
    Write-OK
}

# ============================================
#   INFORME FINAL
# ============================================
Write-Host ""
Write-Host "  +---------------------------------------------+" -ForegroundColor Yellow
Write-Host "  |          LIMPIEZA COMPLETADA  [OK]          |" -ForegroundColor Green
Write-Host "  +---------------------------------------------+" -ForegroundColor Yellow
Write-Host ""
Write-Host "   Espacio liberado aprox.  : ~$totalMB MB"                                       -ForegroundColor White
Write-Host "   Archivos eliminados      : $($script:deletedFiles)"                             -ForegroundColor White
Write-Host "   Archivos omitidos        : $($script:skippedFiles)  (en uso o protegidos)"      -ForegroundColor DarkGray
Write-Host "   Carpetas eliminadas      : $($script:deletedFolders)"                           -ForegroundColor White
Write-Host "   Log guardado en          : $logFile"                                            -ForegroundColor DarkCyan
Write-Host ""

Write-Log "============================================"
Write-Log "Limpieza completada."
Write-Log "Archivos eliminados : $($script:deletedFiles)"
Write-Log "Archivos omitidos   : $($script:skippedFiles)"
Write-Log "Carpetas eliminadas : $($script:deletedFolders)"
Write-Log "============================================"

Read-Host "  Pulsa ENTER para salir"
