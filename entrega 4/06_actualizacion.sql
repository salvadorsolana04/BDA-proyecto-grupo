-- =====================================================================
-- 06: Actualización periódica. Se corre DESPUÉS de 01 y 02 con el archivo nuevo.
-- Reemplaza a 03 y 04 en las cargas siguientes a la inicial.
-- =====================================================================
USE ventas_vehiculos_dw;

-- Período que trae el archivo nuevo (Fecha_Desde / Fecha_Hasta)
SELECT CAST(DATE_FORMAT(MIN(fecha), '%Y-%m-01') AS DATE), MAX(fecha)
INTO @desde, @hasta
FROM stg_limpia
WHERE motivo_descarte IS NULL;

-- dim_tiempo: INCREMENTAL (solo meses nuevos; los existentes los frena el UNIQUE)
INSERT IGNORE INTO dim_tiempo (mes, nombre_mes, trimestre, anio)
WITH RECURSIVE meses AS (
  SELECT @desde AS primer_dia
  UNION ALL
  SELECT primer_dia + INTERVAL 1 MONTH FROM meses
  WHERE primer_dia + INTERVAL 1 MONTH <= @hasta
)
SELECT MONTH(primer_dia),
       ELT(MONTH(primer_dia), 'enero','febrero','marzo','abril','mayo','junio',
           'julio','agosto','septiembre','octubre','noviembre','diciembre'),
       QUARTER(primer_dia), YEAR(primer_dia)
FROM meses;

-- Dimensiones del archivo: INCREMENTAL (solo valores nuevos, nunca se borra)
INSERT IGNORE INTO dim_vehiculo (marca, modelo, carroceria)
SELECT DISTINCT marca, modelo, carroceria FROM stg_limpia WHERE motivo_descarte IS NULL;

INSERT IGNORE INTO dim_ubicacion (estado)
SELECT DISTINCT estado FROM stg_limpia WHERE motivo_descarte IS NULL;

INSERT IGNORE INTO dim_vendedor (nombre_vendedor)
SELECT DISTINCT vendedor FROM stg_limpia WHERE motivo_descarte IS NULL;

-- fact_ventas: REEMPLAZO DEL PERÍODO (se borran los meses del archivo...)
DELETE f
FROM fact_ventas f
JOIN dim_tiempo t ON t.id_tiempo = f.id_tiempo
WHERE t.anio * 100 + t.mes BETWEEN YEAR(@desde) * 100 + MONTH(@desde)
                               AND YEAR(@hasta) * 100 + MONTH(@hasta);

-- (...y se vuelven a cargar, con la misma consulta del 04)
INSERT INTO fact_ventas (id_tiempo, id_vehiculo, id_ubicacion, id_vendedor,
                         cantidad_vendidos, importe_total, precio_promedio, km_promedio)
SELECT t.id_tiempo, v.id_vehiculo, u.id_ubicacion, ve.id_vendedor,
       COUNT(*), SUM(s.precio), ROUND(AVG(s.precio), 2), ROUND(AVG(s.km), 2)
FROM stg_limpia s
JOIN dim_tiempo    t  ON t.anio = YEAR(s.fecha) AND t.mes = MONTH(s.fecha)
JOIN dim_vehiculo  v  ON v.marca = s.marca AND v.modelo = s.modelo AND v.carroceria = s.carroceria
JOIN dim_ubicacion u  ON u.estado = s.estado
JOIN dim_vendedor  ve ON ve.nombre_vendedor = s.vendedor
WHERE s.motivo_descarte IS NULL
GROUP BY t.id_tiempo, v.id_vehiculo, u.id_ubicacion, ve.id_vendedor;

-- Comprobación: corrido con el mismo archivo, nada se duplica
SELECT (SELECT COUNT(*) FROM dim_tiempo)    AS dim_tiempo,
       (SELECT COUNT(*) FROM dim_vehiculo)  AS dim_vehiculo,
       (SELECT COUNT(*) FROM dim_ubicacion) AS dim_ubicacion,
       (SELECT COUNT(*) FROM dim_vendedor)  AS dim_vendedor,
       (SELECT COUNT(*) FROM fact_ventas)   AS fact_ventas,
       (SELECT SUM(cantidad_vendidos) FROM fact_ventas) AS ventas;