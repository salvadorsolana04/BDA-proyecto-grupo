USE ventas_vehiculos_dw;

DROP TABLE IF EXISTS stg_ventas;

CREATE TABLE stg_ventas (
  id_fila       INT NOT NULL AUTO_INCREMENT,
  year          VARCHAR(10),
  make          VARCHAR(30),
  model         VARCHAR(50),
  trim          VARCHAR(80),
  body          VARCHAR(40),
  transmission  VARCHAR(20),
  vin           VARCHAR(30),
  state         VARCHAR(30),
  `condition`   VARCHAR(10),
  odometer      VARCHAR(15),
  color         VARCHAR(20),
  interior      VARCHAR(20),
  seller        VARCHAR(80),
  mmr           VARCHAR(15),
  sellingprice  VARCHAR(15),
  saledate      VARCHAR(60),
  PRIMARY KEY (id_fila)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/Users/salvadorsolana/Desktop/BDA/TP de GRUPO/BDA-proyecto-grupo/entrega 2/car_prices_reducido.csv'
INTO TABLE stg_ventas
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(year, make, model, trim, body, transmission, vin, state, `condition`,
 odometer, color, interior, seller, mmr, sellingprice, saledate);


SELECT COUNT(*) AS filas_cargadas FROM stg_ventas;
SELECT * FROM stg_ventas LIMIT 5;