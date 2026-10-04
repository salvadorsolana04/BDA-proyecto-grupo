USE ventas_vehiculos_dw;

-- ---------------------------------------------------------------------
-- V1. Conteo de filas por tabla
-- ---------------------------------------------------------------------
SELECT 'stg_ventas (archivo)'    AS tabla, COUNT(*) AS filas FROM stg_ventas
UNION ALL SELECT 'stg_limpia: se cargan',   COUNT(*) FROM stg_limpia WHERE motivo_descarte IS NULL
UNION ALL SELECT 'stg_limpia: descartadas', COUNT(*) FROM stg_limpia WHERE motivo_descarte IS NOT NULL
UNION ALL SELECT 'dim_tiempo',    COUNT(*) FROM dim_tiempo
UNION ALL SELECT 'dim_vehiculo',  COUNT(*) FROM dim_vehiculo
UNION ALL SELECT 'dim_ubicacion', COUNT(*) FROM dim_ubicacion
UNION ALL SELECT 'dim_vendedor',  COUNT(*) FROM dim_vendedor
UNION ALL SELECT 'fact_ventas',   COUNT(*) FROM fact_ventas;

-- ---------------------------------------------------------------------
-- V2. Conciliación: el mismo número calculado por dos caminos
-- ---------------------------------------------------------------------
SELECT 'archivo limpio (stg_limpia)' AS origen,
       COUNT(*)                         AS ventas,
       SUM(precio)                      AS importe,
       ROUND(SUM(precio) / COUNT(*), 2) AS precio_prom,
       ROUND(AVG(km), 2)                AS km_prom
FROM stg_limpia
WHERE motivo_descarte IS NULL
UNION ALL
SELECT 'DW (fact_ventas)',
       SUM(cantidad_vendidos),
       SUM(importe_total),
       ROUND(SUM(importe_total) / SUM(cantidad_vendidos), 2),
       ROUND(SUM(km_promedio * cantidad_vendidos) / SUM(cantidad_vendidos), 2)
FROM fact_ventas;

-- V2b. Contra el archivo ORIGINAL: importe del archivo - importe descartado = importe del DW
SELECT (SELECT SUM(CAST(sellingprice AS DECIMAL(12,2))) FROM stg_ventas
        WHERE CHAR_LENGTH(state) = 2 AND sellingprice <> '')                   AS importe_archivo,
       (SELECT SUM(precio) FROM stg_limpia WHERE motivo_descarte IS NOT NULL)   AS importe_descartado,
       (SELECT SUM(importe_total) FROM fact_ventas)                             AS importe_dw;

-- V2c. El error a evitar: promediar el promedio
SELECT ROUND(AVG(precio_promedio), 2) AS promedio_de_promedios_MAL
FROM fact_ventas;

-- ---------------------------------------------------------------------
-- V3. Ninguna fila de hechos sin dimensión (tiene que dar 0)
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS hechos_sin_dimension
FROM fact_ventas f
LEFT JOIN dim_tiempo    t  ON t.id_tiempo     = f.id_tiempo
LEFT JOIN dim_vehiculo  v  ON v.id_vehiculo   = f.id_vehiculo
LEFT JOIN dim_ubicacion u  ON u.id_ubicacion  = f.id_ubicacion
LEFT JOIN dim_vendedor  ve ON ve.id_vendedor  = f.id_vendedor
WHERE t.id_tiempo IS NULL OR v.id_vehiculo IS NULL
   OR u.id_ubicacion IS NULL OR ve.id_vendedor IS NULL;

-- ---------------------------------------------------------------------
-- V4. Trazabilidad: la fila de hechos más grande, bajada hasta el archivo
-- ---------------------------------------------------------------------
-- (a) La fila en el DW, "traducida" con sus dimensiones
SELECT t.nombre_mes, t.anio, v.marca, v.modelo, v.carroceria, u.estado,
       ve.nombre_vendedor, f.cantidad_vendidos, f.importe_total, f.precio_promedio
FROM fact_ventas f
JOIN dim_tiempo    t  ON t.id_tiempo    = f.id_tiempo
JOIN dim_vehiculo  v  ON v.id_vehiculo  = f.id_vehiculo
JOIN dim_ubicacion u  ON u.id_ubicacion = f.id_ubicacion
JOIN dim_vendedor  ve ON ve.id_vendedor = f.id_vendedor
ORDER BY f.cantidad_vendidos DESC
LIMIT 1;

-- (b) Las ventas de stg_limpia que forman esa fila (se buscan por clave natural)
SELECT COUNT(*) AS ventas, SUM(precio) AS importe
FROM stg_limpia
WHERE motivo_descarte IS NULL
  AND marca = 'nissan' AND modelo = 'altima' AND carroceria = 'sedan'
  AND estado = 'fl' AND vendedor = 'nissan-infiniti lt'
  AND fecha BETWEEN '2015-02-01' AND '2015-02-28';

-- (c) Las mismas filas, tal cual vinieron en el CSV (por id_fila)
SELECT id_fila, year, make, model, body, state, seller, sellingprice, saledate
FROM stg_ventas
WHERE id_fila IN (SELECT id_fila FROM stg_limpia
                  WHERE motivo_descarte IS NULL
                    AND marca = 'nissan' AND modelo = 'altima' AND carroceria = 'sedan'
                    AND estado = 'fl' AND vendedor = 'nissan-infiniti lt'
                    AND fecha BETWEEN '2015-02-01' AND '2015-02-28')
LIMIT 5;