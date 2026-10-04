**Facultad de Ingeniería**
**Base de Datos Aplicada**
**Justo Solana Allende 2508165**
**Salvador Solana Allende 2304664**
**Agustin Rodriguez Richard 2522521**

---

# Paso 4 — Integración de datos · Ventas de vehículos

**Punto de partida:** el modelo lógico de `entrega_modelo_logico.sql` (Paso 3), creado y vacío en la base `ventas_vehiculos_dw`, y las reglas de la sección "Consistencia de los valores" del Paso 2.

---

## Proceso general

La carga se hizo con seis scripts SQL, numerados en el orden en que se ejecutan. Todo ocurre dentro de la base `ventas_vehiculos_dw`: las tablas `stg_` son el área de trabajo, donde se revisa y limpia el archivo; las tablas `dim_` y `fact_` son el modelo estrella del Paso 3.

```text
 Inicio               01 Staging         02 Calidad              03 Dimensiones       04 Hechos           05 Verificación
 CSV (Paso 2)  --->   stg_ventas   --->  medir -> limpiar  --->  4 dim_         --->  fact_ventas   --->  conteos +
 + modelo (Paso 3)    LOAD DATA          stg_limpia              19 / 514 /           JOIN +              conciliación +
                      290.990 filas      290.933 se cargan       38 / 6.808           GROUP BY            trazabilidad
                                         57 descartadas                               107.172 filas

 06 Actualización: 01 -> 02 -> 06 con el archivo nuevo (dimensiones incrementales, hechos del período reemplazados)
```

| # | Script | Qué hace |
|---|---|---|
| — | `entrega 3/entrega_modelo_logico.sql` | Crea la base con las 4 dimensiones y la tabla de hechos, vacías. |
| 01 | `01_staging.sql` | Crea `stg_ventas` con las 16 columnas del CSV como VARCHAR y carga el archivo completo con `LOAD DATA`. |
| 02 | `02_calidad.sql` | Parte A: mide cada problema de calidad. Parte B: crea `stg_limpia` con los datos corregidos y un `motivo_descarte` por fila. |
| 03 | `03_dimensiones.sql` | Puebla las 4 dimensiones con los valores únicos de `stg_limpia`; `dim_tiempo` se genera como calendario. |
| 04 | `04_hechos.sql` | Puebla `fact_ventas`: resuelve las claves con JOIN y agrega al grano del Paso 2 con GROUP BY. |
| 05 | `05_verificacion.sql` | Conteos por tabla, conciliación archivo vs DW, hechos sin dimensión y trazabilidad de una fila. |
| 06 | `06_actualizacion.sql` | Proceso de actualización periódica (ver sección b). |

Para correr todo desde cero: `entrega_modelo_logico.sql` → 01 → 02 → 03 → 04 → 05.

---

## a) Carga inicial

### 01 · Staging

El archivo se carga **tal cual viene**, sin interpretar nada, en la tabla `stg_ventas`:

- **Todas las columnas son VARCHAR.** Si alguna fuera numérica, las 26 filas corridas (que traen texto donde va un número) harían fallar la carga o MySQL las convertiría en silencio. Recién en el paso 02 se decide qué hacer con cada problema.
- **`id_fila`** (AUTO_INCREMENT) numera cada fila del CSV. No viene en el archivo: se agrega para poder rastrear cualquier fila descartada o cualquier número del DW hasta su línea de origen.
- **`LINES TERMINATED BY '\r\n'`:** el archivo tiene fin de línea de Windows. Con `'\n'` solo, a cada fecha le quedaría un `\r` invisible al final y no se podría convertir.
- **`IGNORE 1 LINES`** saltea el encabezado.

| Verificación | Resultado |
|---|---|
| Líneas del CSV | 290.991 (1 encabezado + 290.990 filas de datos) |
| Filas cargadas en `stg_ventas` | **290.990** |
| Filas salteadas o con error en el `LOAD DATA` | 0 |

### 02 · Calidad de datos

**Parte A — medir antes de tocar.** Cada chequeo sale de la sección "Consistencia de los valores" del Paso 2 o de "Cambios respecto del Paso 1" del Paso 3. Primero se contó cuánto había de cada problema con SQL sobre `stg_ventas`, sin modificar nada.

Dos aclaraciones sobre cómo se midió:
- En staging los faltantes vienen como cadena vacía (`''`), no como `NULL`, porque así los carga `LOAD DATA`.
- Las filas bien formadas se identifican con `CHAR_LENGTH(state) = 2`: un estado siempre tiene 2 letras, y en las filas corridas ahí hay un VIN de 17 caracteres.
- Para contar escrituras distintas se usó `COUNT(DISTINCT BINARY ...)`: la collation de la base no distingue mayúsculas (`'Ford' = 'ford'`), así que sin `BINARY` las variantes quedarían escondidas.

Los problemas que el Paso 2 no había detectado están marcados como **nuevo**.

| # | Chequeo (SQL sobre stg_ventas) | Encontrado | Regla | Acción en 02 | Filas |
|---|---|---|---|---|---|
| C01 | Filas corridas: VIN en `state` | 26 | Paso 3: un `trim` con coma corrió todos los valores una columna; no se puede recuperar el estado ni la fecha → descartar | `motivo_descarte = 'fila corrida'` | 26 descartadas |
| C02 | `saledate` vacía | 12 (las mismas 12 tienen `sellingprice` vacío) | Paso 2: validar fechas → sin fecha ni precio no hay venta analizable → descartar | `motivo_descarte = 'sin fecha ni precio'` | 12 descartadas |
| C03 | `saledate` con formato no reconocible | 0 | Paso 2: validar fechas | ninguna; fecha = `STR_TO_DATE(SUBSTRING(saledate,5,11), '%b %d %Y')` | 0 |
| C04 | `make` / `model` / `body` vacíos | 1.699 / 1.797 / 1.952 | Paso 3: faltantes → "Sin dato" | `CASE WHEN TRIM(x) = '' THEN 'Sin dato'` | se cargan |
| C05 | `make`: escrituras distintas | 56 escrituras → 43 en minúsculas → **41 marcas** | Paso 2: unificar escritura (`Ford`/`ford`). **Nuevo:** `vw` (13 filas) es Volkswagen y `mercedes` (1 fila) es Mercedes-Benz; minúsculas no alcanza, hace falta un mapeo manual | `LOWER(TRIM(make))` + `CASE 'vw' → 'volkswagen'`, `'mercedes' → 'mercedes-benz'` | 14 corregidas |
| C06 | `model`: escrituras distintas | 430 → **418** | Paso 2: unificar escritura | `LOWER(TRIM(model))` | se cargan |
| C07 | `body`: escrituras distintas | 73 → 38 en minúsculas → **37 carrocerías** | Paso 2: unificar escritura (`Sedan`/`sedan`). **Nuevo:** `regular-cab` (15 filas) es `regular cab` | `LOWER(TRIM(body))` + `CASE 'regular-cab' → 'regular cab'` | 15 corregidas |
| C08 | `seller`: variantes por espacios dobles | 6.811 → **6.809** | Paso 3: normalizar el nombre (es la clave natural) | `LOWER(TRIM(REGEXP_REPLACE(seller, ' +', ' ')))` | se cargan |
| C09 | `state`: códigos válidos | 38 (33 de EE.UU., 4 provincias de Canadá y Puerto Rico) | Paso 3: perspectiva estado/provincia | ninguna (C01 ya excluye los VIN) | 0 |
| C10 | `sellingprice` < 100 | 1: un Ford E-Series vendido a USD 1, con precio de referencia (MMR) de USD 20.800 y condición 41 (buen estado) | Paso 2: "revisar valores muy bajos" → precio imposible → descartar | `motivo_descarte = 'precio invalido'` | 1 descartada |
| C10b | `sellingprice` entre 100 y 999 | 18 | Paso 2: revisados uno por uno; 12 tienen condición 1 a 4 (muy mal estado), así que son precios reales de subasta. 3 de las 18 igual salen por C11 | ninguna, se mantienen | 0 |
| C11 | `odometer` vacío o = 999.999 | 6 + 12 = 18 | Paso 2: 999.999 es el máximo de 6 dígitos, un valor de relleno para "desconocido" en autos de 1 a 3 años; una sola fila así multiplica el promedio de su grupo → descartar | `motivo_descarte = 'km invalido'` | 18 descartadas |
| C11b | `odometer` ≤ 1 | 114 | **Nuevo**, sin regla del Paso 2: puede ser un odómetro sin lectura, pero no hay forma de distinguirlo de un 0 km | ninguna, se mantienen y se documentan como limitación del km promedio | 0 |
| C12 | VIN repetidos | 3.384 VIN en 6.826 filas; 0 filas idénticas en las 16 columnas | Paso 2: "revisar si representan ventas diferentes" → cada aparición difiere en fecha, precio, km o vendedor: son reventas del mismo auto | ninguna, se mantienen | 0 |
| C13 | `transmission` vacía | 35.604 | Paso 2: la columna no entra al modelo (igual que `trim`, `color`, `interior`, `condition`, `mmr`) | ninguna | 0 |

**Parte B — `stg_limpia`, nada se borra.** Las reglas se aplicaron creando una tabla nueva, `stg_limpia`, con una fila por cada fila de `stg_ventas`:

- Textos normalizados (minúsculas, mapeos manuales, "Sin dato").
- `saledate` convertida a `DATE`; precio y km convertidos a `DECIMAL`.
- Una columna `motivo_descarte`: `NULL` si la fila se carga, o el motivo si se excluye. Se asigna la **primera** regla que se cumple, así cada fila tiene un solo motivo y los conteos suman exacto.

Las filas descartadas **no se eliminan**: quedan en `stg_limpia` con su motivo, y se excluyen con `WHERE motivo_descarte IS NULL` al cargar el modelo. Así cualquier fila excluida se puede explicar con una consulta.

| Motivo | Filas |
|---|---|
| (se carga) | **290.933** |
| fila corrida | 26 |
| km invalido | 18 |
| sin fecha ni precio | 12 |
| precio invalido | 1 |
| **Total** | **290.990** |

Se descarta el **0,02 %** del archivo. Las ventas limpias van del 01/01/2014 al 14/07/2015.

### 03 · Carga de dimensiones

Las dimensiones se cargaron **antes** que los hechos, porque las FK de `fact_ventas` tienen que apuntar a claves que ya existan. Cada una se llenó con `INSERT INTO ... SELECT DISTINCT` sobre las filas limpias de `stg_limpia`, y MySQL generó la clave nueva con `AUTO_INCREMENT`. La clave natural (`UNIQUE`) impide que un mismo valor entre dos veces.

| Dimensión | De dónde sale | Filas | Comentario |
|---|---|---|---|
| `dim_tiempo` | **Generada**: todos los meses entre la primera y la última venta (`WITH RECURSIVE`) | **19** | Hay ventas en 10 meses, pero el calendario tiene 19. Si la dimensión saliera del archivo, los meses sin ventas (marzo a noviembre de 2014) no existirían y un gráfico mensual saltaría de febrero a diciembre como si fueran meses seguidos. |
| `dim_vehiculo` | `DISTINCT marca, modelo, carroceria` | **514** | Combinaciones de los tres campos, porque la carrocería no depende del modelo (Paso 3). Son más que las ~488 estimadas en el Paso 3 porque ahora se incluyen las combinaciones con "Sin dato". |
| `dim_ubicacion` | `DISTINCT estado` | **38** | 33 estados de EE.UU., 4 provincias de Canadá y Puerto Rico. |
| `dim_vendedor` | `DISTINCT vendedor` | **6.808** | Nombres ya normalizados en 02. Son 6.809 en el archivo, pero un vendedor aparece solo en filas descartadas y no entra al catálogo. |

### 04 · Carga de hechos

Para cada venta de `stg_limpia` se hicieron dos cosas en una sola consulta:

1. **Resolver las claves con JOIN:** cada venta se busca en cada dimensión por su clave natural (marca + modelo + carrocería, estado, vendedor, y año + mes de la fecha), y se trae la clave subrogada.
2. **Agregar al grano con GROUP BY:** se agrupa por las 4 claves, que son la PK de `fact_ventas` y el grano definido en el Paso 2 (mes + vehículo + ubicación + vendedor). Sobre cada grupo se calculan los 4 indicadores.

| Hecho | Cálculo |
|---|---|
| `cantidad_vendidos` | `COUNT(*)` |
| `importe_total` | `SUM(precio)` |
| `precio_promedio` | `ROUND(AVG(precio), 2)` |
| `km_promedio` | `ROUND(AVG(km), 2)` |

**Control previo del JOIN:** un INNER JOIN descarta en silencio las filas que no encuentran su dimensión. Antes de insertar, se contó el JOIN sin GROUP BY: dio **290.933**, exactamente las ventas limpias, así que ningún JOIN perdió ni duplicó filas.

**Resultado:** las 290.933 ventas quedaron en **107.172 filas** de hechos (2,7 ventas por fila en promedio). Son más que las ~106.486 estimadas en el Paso 3 porque las ventas con marca, modelo o carrocería vacíos ahora entran como "Sin dato" en lugar de quedar afuera.

### 05 · Verificación

**V1 · Conteo de filas por tabla**

| Tabla | Filas |
|---|---|
| `stg_ventas` (archivo) | 290.990 |
| `stg_limpia` · se cargan | 290.933 |
| `stg_limpia` · descartadas | 57 |
| `dim_tiempo` | 19 |
| `dim_vehiculo` | 514 |
| `dim_ubicacion` | 38 |
| `dim_vendedor` | 6.808 |
| `fact_ventas` | 107.172 |

**V2 · Conciliación: el mismo número por dos caminos**

Se calcularon los mismos totales desde las ventas sueltas de `stg_limpia` y desde las filas agregadas de `fact_ventas`. Del lado del DW, los promedios se **recalculan** desde los totales (promedio ponderado), nunca promediando la columna de promedios.

| Origen | Ventas | Importe total (USD) | Precio promedio | Km promedio |
|---|---|---|---|---|
| Archivo limpio (`stg_limpia`) | 290.933 | 5.292.283.858,00 | 18.190,73 | 33.636,18 |
| DW (`fact_ventas`) | 290.933 | 5.292.283.858,00 | 18.190,73 | 33.636,18 |

Fórmulas del lado del DW: precio promedio = `SUM(importe_total) / SUM(cantidad_vendidos)`; km promedio = `SUM(km_promedio × cantidad_vendidos) / SUM(cantidad_vendidos)`.

**Las cuatro columnas coinciden:** no se perdieron ni se duplicaron ventas.

**V2b · Contra el archivo original**

| Importe en el archivo (filas bien formadas) | − Importe de las filas descartadas | = Importe en el DW |
|---|---|---|
| 5.292.436.895,00 | 153.037,00 | **5.292.283.858,00** ✔ |

**V2c · El error que se evita.** Si se promedia directamente la columna `precio_promedio` de `fact_ventas`, se obtiene **USD 19.042,40** en lugar de 18.190,73: unos USD 850 de error. El promedio de promedios le da el mismo peso a una fila con 1 venta que a una con 690. Las filas chicas suelen ser autos caros (de lujo, que se venden de a uno) y las grandes, autos masivos y baratos, así que el resultado se infla. Por eso en el dashboard los promedios se recalculan como total / cantidad.

**V3 · Ninguna fila de hechos sin dimensión.** Con `LEFT JOIN` de `fact_ventas` a las 4 dimensiones, la cantidad de filas con alguna dimensión en `NULL` es **0**. Las FK ya lo garantizan; la consulta lo deja demostrado.

**V4 · Trazabilidad: de una fila del DW al archivo**

Se tomó la fila de hechos con más ventas y se la bajó capa por capa:

| Capa | Consulta | Resultado |
|---|---|---|
| `fact_ventas` | La fila con mayor `cantidad_vendidos`, unida a sus dimensiones | Febrero 2015 · nissan altima sedan · fl · nissan-infiniti lt → **690 ventas, USD 9.013.300**, precio promedio USD 13.062,75 |
| `stg_limpia` | Filas limpias con esas mismas claves naturales y fecha en febrero de 2015 | **690 filas, USD 9.013.300** (`id_fila` entre 15.597 y 171.088) |
| `stg_ventas` / CSV | Esas mismas filas por `id_fila`, con el texto original | Ej.: fila 15.597 → `Nissan, Altima, Sedan, fl, nissan-infiniti lt, 12600.0, Tue Feb 03 2015 01:30:00 GMT-0800 (PST)` |

Cada clave subrogada se abre en su clave natural, y la clave natural está en el archivo. El `id_fila` es el hilo que une el DW con cada línea del CSV.

### Problemas encontrados durante la carga

| Problema | Causa | Solución |
|---|---|---|
| `Error 3948 / 2068` al cargar con `LOAD DATA LOCAL` | MySQL 8+ trae deshabilitada la carga de archivos locales | `SET GLOBAL local_infile = 1` en el servidor y `OPT_LOCAL_INFILE=1` en la conexión de Workbench |
| `Error 1411: Incorrect datetime value` al crear `stg_limpia` | En modo estricto, `STR_TO_DATE` sobre un valor inválido (fechas vacías y filas corridas) corta la carga en lugar de devolver `NULL` | La fecha, el precio y el km se convierten solo si la fila es buena y tiene el dato (`CASE WHEN CHAR_LENGTH(state) = 2 AND ... THEN ...`) |
| `Error 1267: Illegal mix of collations` en el JOIN del paso 04 | `stg_ventas` se creó sin `COLLATE` y tomó la collation por defecto del servidor (`utf8mb4_0900_ai_ci`), distinta de la del modelo (`utf8mb4_unicode_ci`); MySQL no compara textos con reglas distintas | `COLLATE=utf8mb4_unicode_ci` en `stg_ventas` y `ALTER TABLE stg_limpia CONVERT TO ... COLLATE utf8mb4_unicode_ci` |

---

## b) Actualización

Aunque para el TP la carga fue única, si el archivo de ventas se recibiera periódicamente la política sería la siguiente:

| Tabla | Estrategia | Frecuencia | Por qué |
|---|---|---|---|
| — | Proceso completo: 01 → 02 → 06 | **Mensual**, al recibir el archivo de ventas del mes | El nivel mínimo de la perspectiva Tiempo es el mes; actualizar más seguido no agrega información. |
| `stg_ventas`, `stg_limpia` | **Recarga total**: se vacían y se cargan con el archivo nuevo | Cada corrida | Son área de trabajo, no guardan historia. |
| `dim_tiempo` | **Incremental**: se agregan solo los meses nuevos | Cada corrida | El calendario solo crece. |
| `dim_vehiculo`, `dim_ubicacion`, `dim_vendedor` | **Incremental**: se agregan solo los valores nuevos; nunca se borra | Cada corrida | Los hechos de meses anteriores apuntan a esas claves; borrar una dejaría hechos huérfanos. |
| `fact_ventas` | **Reemplazo del período**: se borran las filas de los meses que trae el archivo y se vuelven a cargar | Cada corrida | Si el archivo de un mes llega corregido, se reemplaza entero sin duplicar ventas; los meses anteriores no se tocan. |

**Qué hace `06_actualizacion.sql`:**

1. Toma el período del archivo nuevo en las variables `@desde` y `@hasta` (primera y última fecha de `stg_limpia`).
2. **`dim_tiempo`:** genera los meses de ese período con `INSERT IGNORE`; los que ya existen los frena el `UNIQUE (anio, mes)`.
3. **Dimensiones del archivo:** `INSERT IGNORE ... SELECT DISTINCT`; entran solo los valores que no estaban, gracias al `UNIQUE` de cada clave natural.
4. **`fact_ventas`:** `DELETE` de las filas cuyo mes está entre `@desde` y `@hasta`, y nuevo `INSERT` con la misma consulta del paso 04.

**Corrido (real):** se ejecutó `06_actualizacion.sql` dos veces seguidas con el mismo archivo. Los conteos quedaron idénticos (19 / 514 / 38 / 6.808 / 107.172 filas de hechos / 290.933 ventas): las dimensiones no se duplican y los hechos del período se reemplazan sin acumularse. El proceso se puede volver a correr sin romper nada.
