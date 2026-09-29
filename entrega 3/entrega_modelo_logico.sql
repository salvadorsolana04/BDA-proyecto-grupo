-- =====================================================================
-- Base de Datos Aplicada - TP #2 Data Warehouse (HEFESTO)
-- Paso 3 - Modelo Lógico del DW: Ventas de vehículos
-- Justo Solana Allende (2508165) - Salvador Solana Allende (2304664)
-- Agustin Rodriguez Richard (2522521)
--
-- Esquema: estrella. 4 dimensiones + 1 tabla de hechos.
-- Orden de creación: primero las dimensiones, al final la tabla de hechos
-- (una FOREIGN KEY solo puede apuntar a una tabla que ya existe).
-- Las tablas quedan vacías: la carga de datos es el Paso 4.
-- =====================================================================

DROP DATABASE IF EXISTS ventas_vehiculos_dw;
CREATE DATABASE ventas_vehiculos_dw
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ventas_vehiculos_dw;

-- ---------------------------------------------------------------------
-- b) Tablas de dimensiones
-- ---------------------------------------------------------------------

-- Perspectiva Tiempo. Nivel mínimo: mes. Una fila = un mes.
CREATE TABLE dim_tiempo (
  id_tiempo    SMALLINT    NOT NULL AUTO_INCREMENT,  -- clave nueva
  mes          TINYINT     NOT NULL,                 -- MONTH(saledate)
  nombre_mes   VARCHAR(10) NOT NULL,                 -- nombre del mes en castellano
  trimestre    TINYINT     NOT NULL,                 -- QUARTER(saledate)
  anio         SMALLINT    NOT NULL,                 -- YEAR(saledate)
  PRIMARY KEY (id_tiempo),
  UNIQUE KEY uq_tiempo (anio, mes)
) ENGINE=InnoDB;

-- Perspectiva Vehículo. Una fila = una combinación marca + modelo + carrocería.
CREATE TABLE dim_vehiculo (
  id_vehiculo  INT         NOT NULL AUTO_INCREMENT,  -- clave nueva
  marca        VARCHAR(20) NOT NULL,                 -- make normalizado
  modelo       VARCHAR(40) NOT NULL,                 -- model normalizado
  carroceria   VARCHAR(30) NOT NULL,                 -- body normalizado
  PRIMARY KEY (id_vehiculo),
  UNIQUE KEY uq_vehiculo (marca, modelo, carroceria)
) ENGINE=InnoDB;

-- Perspectiva Ubicación. Una fila = un estado de EE.UU. / provincia de Canadá.
CREATE TABLE dim_ubicacion (
  id_ubicacion TINYINT     NOT NULL AUTO_INCREMENT,  -- clave nueva
  estado       CHAR(2)     NOT NULL,                 -- state (código de 2 letras)
  PRIMARY KEY (id_ubicacion),
  UNIQUE KEY uq_ubicacion (estado)
) ENGINE=InnoDB;

-- Perspectiva Vendedor. Una fila = un vendedor.
CREATE TABLE dim_vendedor (
  id_vendedor     INT         NOT NULL AUTO_INCREMENT,  -- clave nueva
  nombre_vendedor VARCHAR(80) NOT NULL,                 -- seller normalizado
  PRIMARY KEY (id_vendedor),
  UNIQUE KEY uq_vendedor (nombre_vendedor)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- c) Tabla de hechos + d) Uniones
-- Grano: una fila por mes + vehículo + ubicación + vendedor.
-- ---------------------------------------------------------------------

CREATE TABLE fact_ventas (
  id_tiempo          SMALLINT      NOT NULL,
  id_vehiculo        INT           NOT NULL,
  id_ubicacion       TINYINT       NOT NULL,
  id_vendedor        INT           NOT NULL,
  cantidad_vendidos  INT           NOT NULL,  -- COUNT(*)
  importe_total      DECIMAL(12,2) NOT NULL,  -- SUM(sellingprice)
  precio_promedio    DECIMAL(10,2) NOT NULL,  -- AVG(sellingprice) = importe_total / cantidad_vendidos
  km_promedio        DECIMAL(10,2) NOT NULL,  -- AVG(odometer)
  PRIMARY KEY (id_tiempo, id_vehiculo, id_ubicacion, id_vendedor),
  -- d) Uniones: una FOREIGN KEY por dimensión
  CONSTRAINT fk_ventas_tiempo    FOREIGN KEY (id_tiempo)
      REFERENCES dim_tiempo (id_tiempo),
  CONSTRAINT fk_ventas_vehiculo  FOREIGN KEY (id_vehiculo)
      REFERENCES dim_vehiculo (id_vehiculo),
  CONSTRAINT fk_ventas_ubicacion FOREIGN KEY (id_ubicacion)
      REFERENCES dim_ubicacion (id_ubicacion),
  CONSTRAINT fk_ventas_vendedor  FOREIGN KEY (id_vendedor)
      REFERENCES dim_vendedor (id_vendedor)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Evidencia de ejecución
-- ---------------------------------------------------------------------

SHOW TABLES;

SELECT constraint_name, column_name, referenced_table_name
FROM information_schema.key_column_usage
WHERE table_schema = 'ventas_vehiculos_dw'
  AND referenced_table_name IS NOT NULL
ORDER BY constraint_name;

-- Prueba opcional de que la unión protege (ejecutar aparte, a mano).
-- Como las dimensiones están vacías, cualquier INSERT en fact_ventas
-- debe fallar con ERROR 1452 (foreign key constraint fails):
-- INSERT INTO fact_ventas VALUES (1, 1, 1, 1, 1, 10000.00, 10000.00, 5000.00);
