# WSCS — Windows Simple Cleanup Script

> Utilidad interactiva para limpiar archivos temporales, cachés y datos innecesarios en Windows.

---

## Características

- Menú interactivo con checkboxes navegable desde el teclado
- Selección granular: elige exactamente qué limpiar
- Cálculo del espacio a liberar **antes** de borrar nada
- Log automático con timestamp de cada ejecución
- Informe final con archivos eliminados, omitidos y carpetas borradas
- Compatible con múltiples perfiles de usuario en el mismo equipo

---

## Opciones de limpieza

| # | Descripción | Ruta / Acción |
|---|-------------|---------------|
| 1 | Carpetas TEMP de usuario | `C:\Users\*\AppData\Local\Temp` |
| 2 | Carpeta TEMP de Windows | `C:\Windows\Temp` |
| 3 | Volcados de memoria | `CrashDumps` de cada usuario |
| 4 | Informes de errores Windows | Colas WER (usuario y sistema) |
| 5 | Caché de Windows Update | `SoftwareDistribution\Download` |
| 6 | Component Store | `DISM /Cleanup-Image /StartComponentCleanup` |
| 7 | Papelera de reciclaje | Todas las unidades |
| 8 | Cachés de navegadores | Chrome, Edge y Firefox |
| 9 | Elementos recientes | Recent Items y Jump Lists |
| 10 | Caché de miniaturas | `thumbcache_*` del Explorador |
| 11 | Caché Prefetch | `C:\Windows\Prefetch` |

> **Nota:** La limpieza del Prefetch puede ralentizar levemente el primer arranque de aplicaciones tras la ejecución.

---

## Requisitos

- Windows 10 / 11
- PowerShell 5.1 o superior
- Permisos de **Administrador** (obligatorio)

---

## Uso

### Opción A — Ejecutable compilado (recomendado)

Descarga `WSCS.exe` y ejecútalo como Administrador. No requiere PowerShell visible ni ninguna dependencia adicional.

```
Clic derecho → Ejecutar como administrador
```

### Opción B — Script PowerShell directamente

```powershell
# Desde una consola PowerShell elevada:
.\WSCS.ps1
```

Si la política de ejecución lo impide:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\WSCS.ps1
```

---

## Compilar desde el código fuente

Requiere [ps2exe](https://github.com/MScholtes/PS2EXE):

```powershell
# Instalar ps2exe (solo la primera vez)
Install-Module ps2exe -Scope CurrentUser

# Compilar
Invoke-ps2exe `
  -inputFile  'WSCS.ps1' `
  -outputFile 'WSCS.exe' `
  -requireAdmin `
  -supportOS `
  -title       'Windows Cleanup Utility' `
  -description 'Limpia archivos temporales, caches y mas' `
  -product     'Windows Cleanup Utility' `
  -version     '1.0.0.0'
```

---

## Controles del menú

| Tecla | Acción |
|-------|--------|
| `↑` / `↓` | Mover el cursor |
| `Espacio` | Marcar / desmarcar opción |
| `A` | Seleccionar todas las opciones |
| `N` | Deseleccionar todas las opciones |
| `Enter` | Confirmar selección |

---

## Log

Cada ejecución genera automáticamente un archivo de log en el mismo directorio que el script o el ejecutable:

```
cleanup_log_2025-06-15_143022.txt
```

El log registra cada archivo eliminado, cada archivo omitido (en uso o protegido) y cada carpeta borrada, con su timestamp exacto.

---

## Advertencias

- **Navegadores:** cierra Chrome, Edge y Firefox antes de limpiar sus cachés. El script avisará antes de proceder, pero no cierra aplicaciones automáticamente.
- **Windows Update:** el script detiene y reinicia los servicios `wuauserv` y `bits` automáticamente durante la limpieza de la caché de actualización.
- **DISM:** la limpieza del Component Store puede tardar varios minutos dependiendo del tamaño del store y del hardware.
- Los archivos en uso se omiten sin interrumpir la ejecución; quedan registrados en el log.

---

## Licencia

MIT — libre para uso personal y comercial.
