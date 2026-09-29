-- =====================================================================
-- Base de Datos Aplicada - TP #2 Data Warehouse (HEFESTO)
-- Paso 4 - Integración de datos
-- Script 01: tabla de staging (volcado del CSV sin transformar)
--
-- Orden de ejecución del Paso 4:
--   (antes) entrega 3/entrega_modelo_logico.sql  -> crea el DW vacío
--   01_staging.sql                               -> este script
--
-- Requisitos (ver README de la entrega 4):
--   * local_infile habilitado en el servidor y en la conexión de Workbench.
--   * Ajustar la ruta del CSV en el LOAD DATA a la de cada integrante.
-- =====================================================================

USE ventas_vehiculos_dw;

-- ---------------------------------------------------------------------
-- 1. Tabla de staging: una columna por columna del CSV, TODAS VARCHAR.
--    Se carga el archivo tal cual viene, sin convertir tipos ni limpiar,
--    para poder revisarlo con SQL antes de pasar a las tablas del modelo.
--    Los tamaños salen del máximo real de cada columna, con margen.
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS stg_ventas;

CREATE TABLE stg_ventas (
  id_fila       INT          NOT NULL AUTO_INCREMENT,  -- nro. de fila del CSV, para rastrear
  year          VARCHAR(10),    -- máx. real  4
  make          VARCHAR(30),    -- máx. real 13
  model         VARCHAR(50),    -- máx. real 29
  trim          VARCHAR(80),    -- máx. real 46
  body          VARCHAR(40),    -- máx. real 23
  transmission  VARCHAR(20),    -- máx. real  9
  vin           VARCHAR(30),    -- máx. real 17
  state         VARCHAR(30),    -- máx. real 17 (¡las 26 filas corridas traen un VIN!)
  `condition`   VARCHAR(10),    -- máx. real  4 (CONDITION es palabra reservada: va entre ``)
  odometer      VARCHAR(15),    -- máx. real  8
  color         VARCHAR(20),    -- máx. real  9
  interior      VARCHAR(20),    -- máx. real  9
  seller        VARCHAR(80),    -- máx. real 50
  mmr           VARCHAR(15),    -- máx. real  8
  sellingprice  VARCHAR(15),    -- máx. real  8
  saledate      VARCHAR(60),    -- máx. real 39 ("Tue Dec 16 2014 12:30:00 GMT-0800 (PST)")
  PRIMARY KEY (id_fila)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. Carga del archivo completo.
--    * El CSV tiene fin de línea de Windows (\r\n): si se pone solo '\n',
--      el \r queda pegado al final de saledate en todas las filas.
--    * IGNORE 1 LINES saltea el encabezado.
--    * id_fila no está en la lista de columnas: lo numera AUTO_INCREMENT.
-- ---------------------------------------------------------------------

LOAD DATA LOCAL INFILE '/Users/salvadorsolana/Desktop/BDA/TP de GRUPO/BDA-proyecto-grupo/entrega 2/car_prices_reducido.csv'
INTO TABLE stg_ventas
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(year, make, model, trim, body, transmission, vin, state, `condition`,
 odometer, color, interior, seller, mmr, sellingprice, saledate);

-- ---------------------------------------------------------------------
-- 3. Verificación de la carga
-- ---------------------------------------------------------------------

-- 3.1 Filas cargadas: tiene que dar 290.990 (el CSV tiene 290.991 líneas con el encabezado).
SELECT COUNT(*) AS filas_cargadas FROM stg_ventas;

-- 3.2 Primeras filas, para ver a ojo que cada valor cayó en su columna.
SELECT * FROM stg_ventas ORDER BY id_fila LIMIT 5;

-- 3.3 Que no haya quedado un \r pegado al final de saledate: tiene que dar 0.
SELECT COUNT(*) AS filas_con_retorno
FROM stg_ventas
WHERE saledate LIKE CONCAT('%', CHAR(13));

-- 3.4 Las 26 filas mal formadas del Paso 2 (VIN en la columna state): tiene que dar 26.
SELECT COUNT(*) AS filas_corridas
FROM stg_ventas
WHERE CHAR_LENGTH(state) > 2;
