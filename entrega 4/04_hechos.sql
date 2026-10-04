USE ventas_vehiculos_dw;

-- ---------------------------------------------------------------------
-- Control previo: el JOIN sin GROUP BY tiene que dar las 290.933 ventas limpias.
-- Si da menos, algún JOIN está perdiendo filas.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS filas_que_resuelven
FROM stg_limpia s
JOIN dim_tiempo    t  ON t.anio = YEAR(s.fecha) AND t.mes = MONTH(s.fecha)
JOIN dim_vehiculo  v  ON v.marca = s.marca AND v.modelo = s.modelo AND v.carroceria = s.carroceria
JOIN dim_ubicacion u  ON u.estado = s.estado
JOIN dim_vendedor  ve ON ve.nombre_vendedor = s.vendedor
WHERE s.motivo_descarte IS NULL;

-- ---------------------------------------------------------------------
-- Carga: JOIN para resolver claves + GROUP BY al grano del Paso 2
-- ---------------------------------------------------------------------
INSERT INTO fact_ventas (id_tiempo, id_vehiculo, id_ubicacion, id_vendedor,
                         cantidad_vendidos, importe_total, precio_promedio, km_promedio)
SELECT t.id_tiempo, v.id_vehiculo, u.id_ubicacion, ve.id_vendedor,
       COUNT(*)                 AS cantidad_vendidos,  -- Cantidad de vehículos vendidos
       SUM(s.precio)            AS importe_total,      -- Importe total de ventas
       ROUND(AVG(s.precio), 2)  AS precio_promedio,    -- Precio promedio de venta
       ROUND(AVG(s.km), 2)      AS km_promedio         -- Kilometraje promedio
FROM stg_limpia s
JOIN dim_tiempo    t  ON t.anio = YEAR(s.fecha) AND t.mes = MONTH(s.fecha)
JOIN dim_vehiculo  v  ON v.marca = s.marca AND v.modelo = s.modelo AND v.carroceria = s.carroceria
JOIN dim_ubicacion u  ON u.estado = s.estado
JOIN dim_vendedor  ve ON ve.nombre_vendedor = s.vendedor
WHERE s.motivo_descarte IS NULL
GROUP BY t.id_tiempo, v.id_vehiculo, u.id_ubicacion, ve.id_vendedor;

-- Verificación rápida
SELECT COUNT(*) AS filas_hechos, SUM(cantidad_vendidos) AS ventas
FROM fact_ventas;


