**Facultad de Ingeniería**
**Base de Datos Aplicada**
**Justo Solana Allende 2508165**
**Salvador Solana Allende 2304664**
**Agustin Rodriguez Richard 2522521**

---

# Paso 4 — Integración de datos · Ventas de vehículos

## Proceso general

Seis scripts SQL, numerados en el orden en que corren, todos dentro de la base `ventas_vehiculos_dw`. Las tablas `stg_` son el área de trabajo; las `dim_` y `fact_` son el modelo del Paso 3.

```text
 Inicio                01 Staging          02 Calidad             03 Dimensiones      04 Hechos         05 Verificación
 CSV (Paso 2)   --->   stg_ventas    --->  medir -> limpiar  ---> (pendiente)   ---> (pendiente) ---> (pendiente)
 + modelo (Paso 3)     LOAD DATA           stg_limpia
                       290.990 filas       290.933 + 57 desc.
```

| Script | Estado | Qué hace |
|---|---|---|
| `01_staging.sql` | ✅ corrido | Crea `stg_ventas` (16 columnas VARCHAR + `id_fila`) y carga el CSV completo: 290.990 filas. |
| `02_calidad.sql` | ✅ parte A (medir) | Cuenta cada problema de calidad sobre `stg_ventas` (tabla de abajo). Parte B (`stg_limpia` con `motivo_descarte`): pendiente. |
| `03_dimensiones.sql` | pendiente | |
| `04_hechos.sql` | pendiente | |
| `05_verificacion.sql` | pendiente | |
| `06_actualizacion.sql` | pendiente | |

---

## a) Carga inicial

### Calidad de datos

Cada chequeo sale de la sección "Consistencia de los valores" del Paso 2 o de "Cambios respecto del Paso 1" del Paso 3. Los números salen de `02_calidad.sql` corrido sobre `stg_ventas`. Los problemas que el Paso 2 no había detectado están marcados como **nuevo**.

En staging los faltantes vienen como cadena vacía (`''`). Las filas bien formadas se identifican con `CHAR_LENGTH(state) = 2`.

| # | Chequeo (SQL sobre stg_ventas) | Encontrado | Regla | Acción en 02 | Filas |
|---|---|---|---|---|---|
| C01 | Filas corridas: VIN en `state` | 26 | Paso 3: sin estado ni fecha recuperables → descartar e informar | `motivo_descarte = 'fila corrida'` | 26 descartadas |
| C02 | `saledate` vacía | 12 (las mismas 12 tienen `sellingprice` vacío) | Paso 2: validar fechas → sin fecha ni precio no hay venta analizable → descartar | `motivo_descarte = 'sin fecha ni precio'` | 12 descartadas |
| C03 | `saledate` con formato no reconocible | 0 | Paso 2: validar fechas | ninguna; fecha = `STR_TO_DATE(SUBSTRING(saledate,5,11), '%b %d %Y')` | 0 |
| C04 | `make` / `model` / `body` vacíos | 1.699 / 1.797 / 1.952 | Paso 3: faltantes → "Sin dato" | `CASE WHEN TRIM(x) = '' THEN 'Sin dato'` | se cargan |
| C05 | `make`: escrituras distintas | 56 escrituras → 43 en minúsculas → **41 marcas** | Paso 2: unificar escritura (`Ford`/`ford`). **Nuevo:** `vw` (13 filas) y `mercedes` (1 fila) son Volkswagen y Mercedes-Benz | `LOWER(TRIM(make))` + `CASE 'vw' → 'volkswagen', 'mercedes' → 'mercedes-benz'` | 14 corregidas |
| C06 | `model`: escrituras distintas | 430 → **418** | Paso 2: unificar escritura | `LOWER(TRIM(model))` | se cargan |
| C07 | `body`: escrituras distintas | 73 → 38 en minúsculas → **37 carrocerías** | Paso 2: unificar escritura (`Sedan`/`sedan`). **Nuevo:** `regular-cab` (15 filas) es `regular cab` | `LOWER(TRIM(body))` + `REPLACE('regular-cab', 'regular cab')` | 15 corregidas |
| C08 | `seller`: variantes por espacios | 6.811 → **6.809** | Paso 3: normalizar nombre (clave natural) | `LOWER(TRIM(REGEXP_REPLACE(seller, ' +', ' ')))` | se cargan |
| C09 | `state`: códigos válidos | 38 (33 de EE.UU., 4 de Canadá, PR) | Paso 3: estado/provincia | ninguna (C01 ya excluye los VIN) | 0 |
| C10 | `sellingprice` < 100 | 1 (USD 1, con MMR de USD 20.800 y condición 41) | Paso 2: "revisar valores muy bajos" → precio imposible → descartar | `motivo_descarte = 'precio inválido'` | 1 descartada |
| C10b | `sellingprice` entre 100 y 999 | 18 | Paso 2: revisados uno por uno (detalle D2): 12 tienen condición 1 a 4 (muy mal estado), así que son precios reales de subasta. 3 de las 18 igual salen por C11 | ninguna, se mantienen | 0 |
| C11 | `odometer` vacío o = 999.999 | 6 + 12 = 18 | Paso 2: 999.999 es un valor de relleno ("desconocido"), no un kilometraje; distorsiona el promedio y `km_promedio` es NOT NULL | `motivo_descarte = 'km inválido'` | 18 descartadas |
| C11b | `odometer` ≤ 1 | 114 | **Nuevo**, sin regla del Paso 2: puede ser un odómetro sin lectura, pero no hay forma de distinguirlo de un 0 km | ninguna, se mantienen y se documentan como limitación del promedio | 0 |
| C12 | VIN repetidos | 3.384 VIN en 6.826 filas; 0 filas idénticas en las 16 columnas; 18 casos con mismo VIN y misma fecha pero distinto precio, km o vendedor | Paso 2: "revisar si representan ventas diferentes" → son ventas distintas (reventas del mismo auto) | ninguna, se mantienen | 0 |
| C13 | `transmission` vacía | 35.604 | Paso 2: la columna no entra al modelo (igual que `color`, `interior`, `trim`) | ninguna | 0 |

**Resultado:** de 290.990 filas, **290.933 se cargan** y **57 se descartan** (26 + 12 + 18 + 1), el 0,02 % del archivo. Las filas descartadas no se borran: quedan en `stg_limpia` con su `motivo_descarte` para poder rastrearlas.

### Carga de dimensiones

_Pendiente (03_dimensiones.sql)._

### Carga de hechos

_Pendiente (04_hechos.sql)._

### Verificación

_Pendiente (05_verificacion.sql): conteos por tabla · total archivo = total DW · trazabilidad de una fila._

---

## b) Actualización

_Pendiente: tabla por tabla, con estrategia (total / incremental / reemplazo), frecuencia y justificación._
