USE ventas_vehiculos_dw;

-- ---------------------------------------------------------------------
-- dim_tiempo: se GENERA (todos los meses entre la primera y la última venta),
-- no se extrae del archivo
-- ---------------------------------------------------------------------
INSERT INTO dim_tiempo (mes, nombre_mes, trimestre, anio)
WITH RECURSIVE meses AS (
  SELECT CAST(DATE_FORMAT(MIN(fecha), '%Y-%m-01') AS DATE) AS primer_dia
  FROM stg_limpia WHERE motivo_descarte IS NULL
  UNION ALL
  SELECT primer_dia + INTERVAL 1 MONTH
  FROM meses
  WHERE primer_dia + INTERVAL 1 MONTH <= (SELECT MAX(fecha) FROM stg_limpia
                                          WHERE motivo_descarte IS NULL)
)
SELECT MONTH(primer_dia),
       ELT(MONTH(primer_dia), 'enero','febrero','marzo','abril','mayo','junio',
           'julio','agosto','septiembre','octubre','noviembre','diciembre'),
       QUARTER(primer_dia),
       YEAR(primer_dia)
FROM meses
ORDER BY primer_dia;

-- ---------------------------------------------------------------------
-- dim_vehiculo: combinaciones únicas marca + modelo + carrocería
-- ---------------------------------------------------------------------
INSERT INTO dim_vehiculo (marca, modelo, carroceria)
SELECT DISTINCT marca, modelo, carroceria
FROM stg_limpia
WHERE motivo_descarte IS NULL
ORDER BY marca, modelo, carroceria;

-- ---------------------------------------------------------------------
-- dim_ubicacion: estados/provincias únicos
-- ---------------------------------------------------------------------
INSERT INTO dim_ubicacion (estado)
SELECT DISTINCT estado
FROM stg_limpia
WHERE motivo_descarte IS NULL
ORDER BY estado;

-- ---------------------------------------------------------------------
-- dim_vendedor: vendedores únicos (ya normalizados en 02)
-- ---------------------------------------------------------------------
INSERT INTO dim_vendedor (nombre_vendedor)
SELECT DISTINCT vendedor
FROM stg_limpia
WHERE motivo_descarte IS NULL
ORDER BY vendedor;

-- Verificación
SELECT 'dim_tiempo' AS tabla, COUNT(*) AS filas FROM dim_tiempo
UNION ALL SELECT 'dim_vehiculo',  COUNT(*) FROM dim_vehiculo
UNION ALL SELECT 'dim_ubicacion', COUNT(*) FROM dim_ubicacion
UNION ALL SELECT 'dim_vendedor',  COUNT(*) FROM dim_vendedor;

SELECT * FROM dim_tiempo;


