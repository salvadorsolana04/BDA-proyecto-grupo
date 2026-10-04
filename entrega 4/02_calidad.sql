USE ventas_vehiculos_dw;

-- C01 ¿Cuántas filas están corridas de columna?
SELECT COUNT(*) AS filas_corridas
FROM stg_ventas
WHERE CHAR_LENGTH(state) > 2;

-- Para VER el problema: mirá en qué columna quedó cada valor
SELECT id_fila, model, trim, body, transmission, vin, state, saledate
FROM stg_ventas
WHERE CHAR_LENGTH(state) > 2
LIMIT 5;

-- C02 ¿Cuántas ventas no tienen fecha? ¿Y cuántas no tienen ni fecha ni precio?
SELECT COUNT(*) AS sin_fecha FROM stg_ventas WHERE saledate = '';
SELECT COUNT(*) AS sin_fecha_ni_precio FROM stg_ventas WHERE saledate = '' AND sellingprice = '';

-- C03 De las fechas que sí están, ¿hay alguna que no se pueda convertir a fecha?
SELECT COUNT(*) AS fechas_invalidas
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2
  AND saledate <> ''
  AND STR_TO_DATE(SUBSTRING(saledate, 5, 11), '%b %d %Y') IS NULL;
  
  
-- C04 ¿Cuántas filas buenas tienen marca, modelo o carrocería vacía?
SELECT
  SUM(TRIM(make)  = '') AS make_vacio,
  SUM(TRIM(model) = '') AS model_vacio,
  SUM(TRIM(body)  = '') AS body_vacio
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2;

-- C05 ¿Cuántas escrituras distintas de marca hay, y cuántas marcas reales?
SELECT
  COUNT(DISTINCT BINARY make)       AS escrituras,
  COUNT(DISTINCT LOWER(TRIM(make))) AS en_minusculas
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2 AND TRIM(make) <> '';

-- C05b / C07b Variantes que no se arreglan con minúsculas (NUEVO, no estaba en el Paso 2)
SELECT LOWER(TRIM(make)) AS valor, COUNT(*) AS filas
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2 AND LOWER(TRIM(make)) IN ('vw', 'mercedes')
GROUP BY LOWER(TRIM(make));

SELECT COUNT(*) AS filas_regular_guion
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2 AND LOWER(TRIM(body)) = 'regular-cab';



-- C08 ¿Cuántos vendedores se unifican al limpiar espacios?
SELECT
  COUNT(DISTINCT BINARY seller) AS escrituras,
  COUNT(DISTINCT LOWER(TRIM(REGEXP_REPLACE(seller, ' +', ' ')))) AS normalizados
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2;

-- C10 Ventas con precio menor a USD 1.000: comparalas con su precio de referencia (mmr)
SELECT id_fila, year, make, model, `condition`, odometer, mmr, sellingprice
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2
  AND sellingprice <> ''
  AND CAST(sellingprice AS DECIMAL(12,2)) < 1000
ORDER BY CAST(sellingprice AS DECIMAL(12,2));

-- C10 Precio imposible (< 100): se descarta
SELECT COUNT(*) AS precio_invalido
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2 AND sellingprice <> ''
  AND CAST(sellingprice AS DECIMAL(12,2)) < 100;
  

-- C11 Kilometrajes vacíos o sospechosamente altos
SELECT
  SUM(odometer = '') AS odo_vacio,
  SUM(odometer <> '' AND CAST(odometer AS DECIMAL(12,1)) >= 999999) AS odo_999999,
  SUM(odometer <> '' AND CAST(odometer AS DECIMAL(12,1)) <= 1) AS odo_menor_igual_1
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2;

-- Para ver los más altos
SELECT id_fila, year, make, model, odometer, sellingprice
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2 AND odometer <> ''
  AND CAST(odometer AS DECIMAL(12,1)) > 500000
ORDER BY CAST(odometer AS DECIMAL(12,1)) DESC;


-- C12 ¿Cuántas filas tienen un VIN que se repite?
SELECT COUNT(*) AS filas_vin_repetido, COUNT(DISTINCT vin) AS vins
FROM stg_ventas
WHERE CHAR_LENGTH(state) = 2
  AND vin IN (SELECT vin FROM stg_ventas
              WHERE CHAR_LENGTH(state) = 2
              GROUP BY vin HAVING COUNT(*) > 1);

-- C12b ¿Hay filas IDÉNTICAS en las 16 columnas? (eso sí sería un duplicado)
SELECT COUNT(*) AS grupos_identicos
FROM (SELECT COUNT(*) FROM stg_ventas
      GROUP BY year, make, model, trim, body, transmission, vin, state, `condition`,
               odometer, color, interior, seller, mmr, sellingprice, saledate
      HAVING COUNT(*) > 1) x;
    
    
    
    
-- =====================================================================
-- PARTE B: stg_limpia — se aplican las reglas, nada se borra
-- =====================================================================
DROP TABLE IF EXISTS stg_limpia;

CREATE TABLE stg_limpia AS
SELECT
  id_fila,

  -- Fecha: solo se convierte si la fila es buena y tiene fecha (C01, C02, C03)
  CASE WHEN CHAR_LENGTH(state) = 2 AND saledate <> ''
       THEN STR_TO_DATE(SUBSTRING(saledate, 5, 11), '%b %d %Y') END              AS fecha,

  -- Marca: vacía → Sin dato (C04); minúsculas (C05); mapeo manual vw/mercedes (C05, NUEVO)
  CASE WHEN TRIM(make) = ''                 THEN 'Sin dato'
       WHEN LOWER(TRIM(make)) = 'vw'        THEN 'volkswagen'
       WHEN LOWER(TRIM(make)) = 'mercedes'  THEN 'mercedes-benz'
       ELSE LOWER(TRIM(make)) END                                                AS marca,

  -- Modelo: vacío → Sin dato (C04); minúsculas (C06)
  CASE WHEN TRIM(model) = '' THEN 'Sin dato'
       ELSE LOWER(TRIM(model)) END                                               AS modelo,

  -- Carrocería: vacía → Sin dato (C04); minúsculas (C07); regular-cab (C07, NUEVO)
  CASE WHEN TRIM(body) = ''                     THEN 'Sin dato'
       WHEN LOWER(TRIM(body)) = 'regular-cab'   THEN 'regular cab'
       ELSE LOWER(TRIM(body)) END                                                AS carroceria,

  LOWER(TRIM(state))                                                             AS estado,

  -- Vendedor: espacios dobles → uno (C08)
  CAST(LOWER(TRIM(REGEXP_REPLACE(seller, ' +', ' '))) AS CHAR(80))              AS vendedor,

  -- Números: solo se convierten si la fila es buena y el dato existe
  CASE WHEN CHAR_LENGTH(state) = 2 AND sellingprice <> ''
       THEN CAST(sellingprice AS DECIMAL(12,2)) END                              AS precio,
  CASE WHEN CHAR_LENGTH(state) = 2 AND odometer <> ''
       THEN CAST(odometer AS DECIMAL(10,1)) END                                  AS km,

  -- Motivo de descarte: la PRIMERA regla que se cumpla (C01, C02, C10, C11)
  CASE WHEN CHAR_LENGTH(state) > 2                          THEN 'fila corrida'
       WHEN saledate = ''                                   THEN 'sin fecha ni precio'
       WHEN CAST(sellingprice AS DECIMAL(12,2)) < 100       THEN 'precio invalido'
       WHEN odometer = ''
         OR CAST(odometer AS DECIMAL(10,1)) >= 999999        THEN 'km invalido'
       ELSE NULL END                                                             AS motivo_descarte
FROM stg_ventas;

ALTER TABLE stg_limpia ADD PRIMARY KEY (id_fila);

-- Misma collation que el modelo, para que los JOIN del paso 04 puedan comparar textos
ALTER TABLE stg_limpia CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Verificación de la parte B
SELECT COALESCE(motivo_descarte, '(se carga)') AS motivo, COUNT(*) AS filas
FROM stg_limpia
GROUP BY motivo_descarte
ORDER BY filas DESC;

SELECT COUNT(DISTINCT marca) AS marcas, COUNT(DISTINCT modelo) AS modelos,
       COUNT(DISTINCT carroceria) AS carrocerias, COUNT(DISTINCT estado) AS estados,
       COUNT(DISTINCT vendedor) AS vendedores, MIN(fecha), MAX(fecha)
FROM stg_limpia
WHERE motivo_descarte IS NULL;




