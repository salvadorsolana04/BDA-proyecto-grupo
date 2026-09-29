# Entrega 4 — Integración de datos (Paso 4 HEFESTO)

## Orden de ejecución

| # | Script | Qué hace |
|---|---|---|
| 0 | `entrega 3/entrega_modelo_logico.sql` | Crea la base `ventas_vehiculos_dw` con las 4 dimensiones y la tabla de hechos, vacías. |
| 1 | `01_staging.sql` | Crea `stg_ventas` (todo VARCHAR) y carga el CSV completo con `LOAD DATA`. |
| 2 | `02_calidad.sql` | Parte A: mide cada problema de calidad sobre `stg_ventas` (no modifica nada). Los números van a `entrega_informe.md`. |

> Si se vuelve a correr el script 0, el `DROP DATABASE` borra también `stg_ventas`: después hay que correr de nuevo el 01.

## Antes de correr `01_staging.sql` (una sola vez)

`LOAD DATA LOCAL INFILE` viene deshabilitado por seguridad en MySQL 8. Hay que habilitarlo **en los dos lados**:

1. **Servidor:** en una pestaña de Workbench, ejecutar:
   ```sql
   SET GLOBAL local_infile = 1;
   ```
2. **Cliente (la conexión de Workbench):** *Database → Manage Connections…* → elegir la conexión → pestaña **Advanced** → en el cuadro **Others** agregar una línea:
   ```
   OPT_LOCAL_INFILE=1
   ```
   Cerrar y volver a abrir la conexión.
3. **Ruta del CSV:** en el `LOAD DATA` del script, poner la ruta completa al archivo en la compu de cada uno.

## Errores comunes

| Error | Causa | Solución |
|---|---|---|
| `Error 3948: Loading local data is disabled` | Falta el paso 1 (servidor). | `SET GLOBAL local_infile = 1;` |
| `Error 2068: LOAD DATA LOCAL INFILE file request rejected` | Falta el paso 2 (conexión). | Agregar `OPT_LOCAL_INFILE=1` y reconectar. |
| `Error 2: File ... not found` / `Errcode: 1 Operation not permitted` | Ruta mal escrita o macOS no deja a Workbench leer el Escritorio. | Revisar la ruta; en *Ajustes del Sistema → Privacidad → Archivos y carpetas*, permitir a MySQLWorkbench el acceso al Escritorio. |
| `Error 1046: No database selected` | No existe la base del Paso 3. | Correr primero el script 0. |

## Resultado esperado de `01_staging.sql`

| Verificación | Valor esperado |
|---|---|
| `filas_cargadas` | 290990 |
| `filas_con_retorno` (un `\r` pegado al final de saledate) | 0 |
| `filas_corridas` (VIN en la columna state) | 26 |
