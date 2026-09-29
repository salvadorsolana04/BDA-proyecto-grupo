-- =====================================================================
-- Base de Datos Aplicada - TP #2 Data Warehouse (HEFESTO)
-- Paso 4 - Integración de datos
-- Script 02: calidad de datos - PARTE A: medir antes de tocar
--
-- Cada chequeo sale de la sección "Consistencia de los valores" del
-- Paso 2 (o de "Cambios respecto del Paso 1" del Paso 3). Acá solo se
-- CUENTA cuánto hay de cada problema, sobre stg_ventas, sin modificar nada.
-- Esos números van a la tabla de calidad de entrega_informe.md.
--
-- En staging todo es VARCHAR y los faltantes vienen como '' (cadena vacía).
-- CHAR_LENGTH(state) = 2 separa las filas bien formadas de las 26 corridas.
--
-- PARTE B (stg_limpia con motivo_descarte): pendiente.
-- =====================================================================

USE ventas_vehiculos_dw;

-- ---------------------------------------------------------------------
-- Resumen: un chequeo por fila, en una sola grilla (para el informe)
-- ---------------------------------------------------------------------

SELECT 'C01 filas corridas (VIN en state)'              AS chequeo, COUNT(*) AS encontrado
FROM stg_ventas WHERE CHAR_LENGTH(state) > 2
UNION ALL
SELECT 'C02 saledate vacía', COUNT(*)
FROM stg_ventas WHERE saledate = ''
UNION ALL
SELECT 'C02b saledate y sellingprice vacíos a la vez', COUNT(*)
FROM stg_ventas WHERE saledate = '' AND sellingprice = ''
UNION ALL
SELECT 'C03 saledate con formato no reconocible', COUNT(*)
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2 AND saledate <> ''
  AND STR_TO_DATE(SUBSTRING(saledate, 5, 11), '%b %d %Y') IS NULL
UNION ALL
SELECT 'C04 make vacío', COUNT(*)  FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(make)  = ''
UNION ALL
SELECT 'C04 model vacío', COUNT(*) FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(model) = ''
UNION ALL
SELECT 'C04 body vacío', COUNT(*)  FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(body)  = ''
UNION ALL
SELECT 'C05 make: escrituras (BINARY, sin vacío)', COUNT(DISTINCT BINARY make)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(make) <> ''
UNION ALL
SELECT 'C05 make: valores en minúsculas', COUNT(DISTINCT LOWER(TRIM(make)))
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(make) <> ''
UNION ALL
SELECT 'C05 make: filas vw / mercedes', COUNT(*)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND LOWER(TRIM(make)) IN ('vw', 'mercedes')
UNION ALL
SELECT 'C06 model: escrituras (BINARY, sin vacío)', COUNT(DISTINCT BINARY model)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(model) <> ''
UNION ALL
SELECT 'C06 model: valores en minúsculas', COUNT(DISTINCT LOWER(TRIM(model)))
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(model) <> ''
UNION ALL
SELECT 'C07 body: escrituras (BINARY, sin vacío)', COUNT(DISTINCT BINARY body)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(body) <> ''
UNION ALL
SELECT 'C07 body: valores en minúsculas', COUNT(DISTINCT LOWER(TRIM(body)))
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(body) <> ''
UNION ALL
SELECT 'C07 body: filas "regular-cab"', COUNT(*)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND LOWER(TRIM(body)) = 'regular-cab'
UNION ALL
SELECT 'C08 seller: escrituras (BINARY)', COUNT(DISTINCT BINARY seller)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2
UNION ALL
SELECT 'C08 seller: normalizado (minúsc. + espacios)', COUNT(DISTINCT LOWER(TRIM(REGEXP_REPLACE(seller, ' +', ' '))))
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2
UNION ALL
SELECT 'C09 state: códigos distintos válidos', COUNT(DISTINCT state)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2
UNION ALL
SELECT 'C10 sellingprice < 100', COUNT(*)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND sellingprice <> ''
  AND CAST(sellingprice AS DECIMAL(12,2)) < 100
UNION ALL
SELECT 'C10b sellingprice entre 100 y 999', COUNT(*)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND sellingprice <> ''
  AND CAST(sellingprice AS DECIMAL(12,2)) BETWEEN 100 AND 999.99
UNION ALL
SELECT 'C11 odometer vacío', COUNT(*)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND odometer = ''
UNION ALL
SELECT 'C11 odometer = 999999', COUNT(*)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND odometer <> ''
  AND CAST(odometer AS DECIMAL(12,1)) >= 999999
UNION ALL
SELECT 'C11b odometer <= 1', COUNT(*)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND odometer <> ''
  AND CAST(odometer AS DECIMAL(12,1)) <= 1
UNION ALL
SELECT 'C12 filas con VIN repetido', COUNT(*)
FROM stg_ventas s
JOIN (SELECT vin FROM stg_ventas WHERE vin <> '' AND CHAR_LENGTH(state) = 2
      GROUP BY vin HAVING COUNT(*) > 1) d USING (vin)
UNION ALL
SELECT 'C12b filas idénticas en las 16 columnas (de más)', COALESCE(SUM(c - 1), 0)
FROM (SELECT COUNT(*) AS c FROM stg_ventas
      GROUP BY year, make, model, trim, body, transmission, vin, state, `condition`,
               odometer, color, interior, seller, mmr, sellingprice, saledate
      HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'C12c grupos mismo VIN + misma fecha', COUNT(*)
FROM (SELECT vin, saledate FROM stg_ventas WHERE vin <> '' AND CHAR_LENGTH(state) = 2
      GROUP BY vin, saledate HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'C13 transmission vacía (columna no usada)', COUNT(*)
FROM stg_ventas WHERE CHAR_LENGTH(state) = 2 AND TRIM(transmission) = '';

-- ---------------------------------------------------------------------
-- Detalles para respaldar las decisiones
-- ---------------------------------------------------------------------

-- D1 (C05) Marcas con más de una escritura
SELECT LOWER(TRIM(make)) AS marca,
       GROUP_CONCAT(DISTINCT BINARY make SEPARATOR ' / ') AS variantes,
       COUNT(*) AS filas
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2 AND TRIM(make) <> ''
GROUP BY LOWER(TRIM(make))
HAVING COUNT(DISTINCT BINARY make) > 1 OR marca IN ('vw', 'mercedes')
ORDER BY marca;

-- D2 (C10) Ventas con precio menor a USD 1.000, contra su precio de referencia (mmr)
SELECT id_fila, year, make, model, `condition`, odometer, mmr, sellingprice
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2 AND sellingprice <> ''
  AND CAST(sellingprice AS DECIMAL(12,2)) < 1000
ORDER BY CAST(sellingprice AS DECIMAL(12,2));

-- D3 (C12c) Mismo VIN y misma fecha: ¿son la misma venta repetida?
SELECT s.id_fila, s.vin, s.state, s.odometer, s.sellingprice, LEFT(s.seller, 30) AS seller
FROM stg_ventas s
JOIN (SELECT vin, saledate FROM stg_ventas WHERE vin <> '' AND CHAR_LENGTH(state) = 2
      GROUP BY vin, saledate HAVING COUNT(*) > 1) d USING (vin, saledate)
ORDER BY s.vin, s.id_fila;

-- D4 Resultado de aplicar las reglas de descarte (cada fila con su primer motivo)
SELECT COALESCE(motivo, '(se carga)') AS motivo, COUNT(*) AS filas
FROM (SELECT CASE
               WHEN CHAR_LENGTH(state) > 2 THEN 'fila corrida'
               WHEN saledate = '' THEN 'sin fecha ni precio'
               WHEN CAST(sellingprice AS DECIMAL(12,2)) < 100 THEN 'precio inválido'
               WHEN odometer = '' OR CAST(odometer AS DECIMAL(12,1)) >= 999999 THEN 'km inválido'
             END AS motivo
      FROM stg_ventas) x
GROUP BY motivo
ORDER BY filas DESC;
