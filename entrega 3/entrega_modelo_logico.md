**Facultad de Ingeniería**
**Base de Datos Aplicada**
**Justo Solana Allende 2508165**
**Salvador Solana Allende 2304664**
**Agustin Rodriguez Richard 2522521**

---

# Paso 3 — Modelo Lógico del DW · Ventas de vehículos

**Punto de partida:** el modelo conceptual ampliado del Paso 2, con los cambios que se documentan a continuación.

---

## Cambios respecto del Paso 1

### 1. Corrección del recorte y de la perspectiva Tiempo

En el Paso 1 escribimos que el recorte se hizo sobre las ventas entre 2012 y 2015. Al perfilar el archivo vimos que el filtro en realidad se aplicó sobre `year`, que es el año/modelo del vehículo: el archivo tiene vehículos modelo 2012 a 2015. Las fechas de venta (`saledate`) van del 01/01/2014 al 14/07/2015:

| Año de venta | Ventas | Meses con datos |
|---|---|---|
| 2014 | 19.631 | enero (148), febrero (1), diciembre (19.482) |
| 2015 | 271.321 | enero a julio |
| Sin fecha válida | 38 | 12 nulos + 26 filas mal formadas (ver punto 3) |

Consecuencia: la perspectiva Tiempo cubre 10 meses, no 4 años.

**Cambio en las preguntas 2 y 6.** Comparar "por año de venta" es comparar casi solamente diciembre de 2014 contra siete meses de 2015, así que no da una lectura útil. Las reformulamos a nivel mes, que además es el nivel mínimo definido en el Paso 2:

- 2. ¿Cuál fue el precio promedio de venta por modelo y por mes?
- 6. ¿Cuál fue el kilometraje promedio de los vehículos vendidos por marca y por mes?

Los indicadores y las perspectivas no cambian. El año se mantiene en la jerarquía de Tiempo porque hace falta para distinguir enero 2014 de enero 2015.

### 2. Vehículo: una fila = una combinación marca + modelo + carrocería

`make` → `model` es una jerarquía limpia: ningún modelo aparece en más de una marca. Pero `body` no depende del modelo: 63 de los 406 pares marca+modelo aparecen con más de una carrocería (por ejemplo, BMW 3 Series con 4). Por eso la perspectiva Vehículo se identifica por la combinación de los tres campos y no por el modelo solo.

Al unificar mayúsculas/minúsculas (Paso 4): make 56 → 43, model 430 → 418, body 74 → 39, y quedan unas 488 combinaciones. Los valores nulos se representan como "Sin dato".

### 3. Ubicación: estado o provincia; las 26 filas mal formadas se descartan

`state` tiene 64 valores distintos: 38 reales y 26 que son códigos VIN.

- Los 38 reales son 33 estados de EE.UU., 4 provincias de Canadá (on, qc, ab, ns: 3.118 ventas) y Puerto Rico (pr: 1.219 ventas). Por eso la perspectiva pasa a describirse como "estado/provincia". No agregamos país porque ninguna pregunta lo pide.
- Los 26 VIN son exactamente las 26 filas mal formadas del Paso 2. Todas son VW Jetta cuyo `trim` trae una coma ("SE PZEV w/Connectivity, Navitgation"), lo que corrió todos los valores una columna a la derecha. En esas filas no se puede recuperar con certeza el estado ni la fecha de venta (en `saledate` quedó el precio), así que no se pueden ubicar ni en Tiempo ni en Ubicación. Se descartan en el Paso 4.

Filas utilizables: 290.990 − 26 mal formadas − 12 sin fecha = **290.952**.

### 4. Vendedor: el nombre es la clave natural

El archivo no trae un código de vendedor, así que la clave natural es el nombre normalizado (sin espacios al inicio o al final, en minúsculas y con los espacios dobles colapsados). Así, los 6.813 nombres distintos pasan a 6.811. Si además se quitan los signos de puntuación quedan 6.797: esos casos se revisan en el Paso 4 antes de unificarlos, para no fusionar vendedores distintos.

### Modelo conceptual ampliado (actualizado)

```text
[Tiempo] -------------------┐
 mes (nivel mínimo)         │
 trimestre                  │
 año        <- saledate     │
                            │
[Vehículo] -----------------┤
 marca      <- make         │
 modelo     <- model        │
 carrocería <- body         │
 (combinación de los 3)     │
                            │
[Ubicación] ----------------┼---- (Venta) ----> [Cantidad de vehículos vendidos]
 estado/provincia <- state  │                     COUNT(*)
                            │
[Vendedor] -----------------┤              ----> [Importe total de ventas]
 vendedor   <- seller       │                     SUM(sellingprice)
                            │
                            ├---------------> [Precio promedio de venta]
                            │                     AVG(sellingprice)
                            │
                            └---------------> [Kilometraje promedio]
                                                  AVG(odometer)
```

---

## a) Tipo de modelo lógico

**Esquema elegido:** estrella.

**Justificación:**

- **Una sola tabla de hechos (no constelación).** Hay un único proceso de negocio, la venta de un vehículo, y cada fila del archivo trae a la vez los datos de las 4 perspectivas (fecha, vehículo, estado, vendedor) y los datos de los 4 indicadores (`sellingprice`, `odometer`, y la fila misma para el conteo). Por eso cualquier indicador se puede analizar por cualquier perspectiva: las 6 preguntas son combinaciones de los mismos indicadores sobre las mismas perspectivas (Caso 3), y se unifican en una sola tabla de hechos.
- **Sin normalizar dimensiones (no copo de nieve).** Tiempo (mes → trimestre → año) tiene unos 10 valores, y Ubicación y Vendedor no tienen jerarquía. La única jerarquía es la de Vehículo (marca → modelo), que es chica: 43 marcas y 418 modelos. Además, la carrocería no depende del modelo. Normalizarla obligaría a crear 3 o 4 tablas y a sumar JOIN en consultas como la pregunta 3, solo para no repetir 43 nombres de marca en unas 488 filas.
- **Ventajas que pesan para este caso:** consultas con un solo JOIN por dimensión, diseño simple de modificar y mejores tiempos de respuesta para el análisis.

---

## b) Tablas de dimensiones

Una tabla por perspectiva del modelo conceptual ampliado: 4 perspectivas, 4 dimensiones. Todas usan una clave subrogada nueva (AUTO_INCREMENT). La clave natural del archivo se guarda como campo con UNIQUE para poder rastrear el origen y para que la carga del Paso 4 no duplique filas.

### dim_tiempo (perspectiva: Tiempo)

Nivel mínimo: mes. Una fila = un mes (unas 10 filas).

| Campo | Tipo | Origen (columna del archivo / cálculo) | Nivel |
|---|---|---|---|
| id_tiempo | SMALLINT PK | AUTO_INCREMENT (clave nueva) | — |
| mes | TINYINT | MONTH(saledate) | mes |
| nombre_mes | VARCHAR(10) | nombre del mes de saledate, en castellano | mes |
| trimestre | TINYINT | QUARTER(saledate) | trimestre |
| anio | SMALLINT | YEAR(saledate) | año |

Clave natural: UNIQUE (anio, mes).

### dim_vehiculo (perspectiva: Vehículo)

Una fila = una combinación marca + modelo + carrocería (unas 488 filas), porque la carrocería no depende del modelo.

| Campo | Tipo | Origen (columna del archivo / cálculo) |
|---|---|---|
| id_vehiculo | INT PK | AUTO_INCREMENT (clave nueva) |
| marca | VARCHAR(20) | make normalizado (minúsculas, sin espacios extra) |
| modelo | VARCHAR(40) | model normalizado |
| carroceria | VARCHAR(30) | body normalizado |

Clave natural: UNIQUE (marca, modelo, carroceria). Los nulos se cargan como "Sin dato".

### dim_ubicacion (perspectiva: Ubicación)

Una fila = un estado de EE.UU. o una provincia de Canadá (38 filas).

| Campo | Tipo | Origen (columna del archivo / cálculo) |
|---|---|---|
| id_ubicacion | TINYINT PK | AUTO_INCREMENT (clave nueva) |
| estado | CHAR(2) | state (código de 2 letras: ca, fl, on, pr...) |

Clave natural: UNIQUE (estado).

### dim_vendedor (perspectiva: Vendedor)

Una fila = un vendedor (unas 6.811 filas).

| Campo | Tipo | Origen (columna del archivo / cálculo) |
|---|---|---|
| id_vendedor | INT PK | AUTO_INCREMENT (clave nueva) |
| nombre_vendedor | VARCHAR(80) | seller normalizado (minúsculas, espacios dobles colapsados) |

Clave natural: UNIQUE (nombre_vendedor).

### Campos renombrados

| Archivo | Modelo lógico |
|---|---|
| saledate | mes, nombre_mes, trimestre, anio |
| make / model / body | marca / modelo / carroceria |
| state | estado |
| seller | nombre_vendedor |

No entran al modelo, porque el Paso 2 los descartó: vin, trim, transmission, color, interior, condition, mmr, year (año/modelo) y la hora de saledate.

---

## c) Tabla de hechos

### fact_ventas

Representa el proceso de venta de vehículos, que es la relación central del modelo conceptual.

**Grano:** una fila por cada combinación de mes + vehículo + ubicación + vendedor. Surge del Paso 2: Tiempo tiene como nivel mínimo el mes, así que las ventas de un mismo vehículo, en el mismo estado, por el mismo vendedor y en el mismo mes se agregan en una sola fila. Las 290.952 ventas válidas quedan en 106.486 filas.

| Campo | Tipo | Rol | Indicador de origen / cálculo |
|---|---|---|---|
| id_tiempo | SMALLINT | PK, FK → dim_tiempo | mes de saledate |
| id_vehiculo | INT | PK, FK → dim_vehiculo | make + model + body |
| id_ubicacion | TINYINT | PK, FK → dim_ubicacion | state |
| id_vendedor | INT | PK, FK → dim_vendedor | seller |
| cantidad_vendidos | INT | hecho básico | Cantidad de vehículos vendidos = COUNT(*) |
| importe_total | DECIMAL(12,2) | hecho básico | Importe total de ventas = SUM(sellingprice) |
| precio_promedio | DECIMAL(10,2) | hecho derivado | Precio promedio de venta = AVG(sellingprice) = importe_total / cantidad_vendidos |
| km_promedio | DECIMAL(10,2) | hecho derivado | Kilometraje promedio = AVG(odometer) |

**Clave primaria:** compuesta por (id_tiempo, id_vehiculo, id_ubicacion, id_vendedor). Cuatro dimensiones dan cuatro claves en la PK. Cuatro indicadores dan cuatro hechos.

**Una fila, leída en castellano:** "En febrero de 2015, el vendedor nissan-infiniti lt vendió en Florida 690 Nissan Altima sedán, por un total de USD 9.013.300, con un precio promedio de USD 13.062,75 y un kilometraje promedio de 29.492 millas."

**Promedios al re-agregar:** a este grano los promedios de cada fila son correctos. Al agrupar a otro nivel (por ejemplo, por año o por marca) no se promedian los promedios:

- precio promedio = SUM(importe_total) / SUM(cantidad_vendidos)
- km promedio = SUM(km_promedio × cantidad_vendidos) / SUM(cantidad_vendidos)

---

## d) Uniones

Cada dimensión se une a la tabla de hechos con una FOREIGN KEY. La dimensión está del lado 1 y fact_ventas del lado n: un mes, un vehículo, una ubicación o un vendedor aparece en muchas filas de hechos, y cada fila de hechos apunta a uno solo de cada uno.

```text
[dim_tiempo]                              [dim_vehiculo]
 PK id_tiempo                              PK id_vehiculo
 mes, nombre_mes                           marca
 trimestre, anio                           modelo
       1 |                                 carroceria
         |                                     | 1
         |          ( fact_ventas )            |
         |       n  ----------------------  n  |
         +-------> PK,FK id_tiempo             |
                   PK,FK id_vehiculo  <--------+
         +-------> PK,FK id_ubicacion
         |      n  PK,FK id_vendedor  <--------+
         |         ----------------------  n   |
         |         cantidad_vendidos           |
         |         importe_total               |
         |         precio_promedio             |
         |         km_promedio                 |
       1 |                                     | 1
[dim_ubicacion]                           [dim_vendedor]
 PK id_ubicacion                           PK id_vendedor
 estado                                    nombre_vendedor
```

| FK en fact_ventas | Constraint | Referencia | Tipo (igual en ambos lados) | Cardinalidad |
|---|---|---|---|---|
| id_tiempo | fk_ventas_tiempo | dim_tiempo (id_tiempo) | SMALLINT | 1 : n |
| id_vehiculo | fk_ventas_vehiculo | dim_vehiculo (id_vehiculo) | INT | 1 : n |
| id_ubicacion | fk_ventas_ubicacion | dim_ubicacion (id_ubicacion) | TINYINT | 1 : n |
| id_vendedor | fk_ventas_vendedor | dim_vendedor (id_vendedor) | INT | 1 : n |

4 perspectivas → 4 dimensiones → 4 FK, y las 4 FK juntas forman la PK de fact_ventas. 4 indicadores → 4 hechos.

---

## Evidencia de ejecución del DDL

`entrega_modelo_logico.sql` se ejecutó completo en MySQL 8.0, dos veces seguidas (el `DROP DATABASE IF EXISTS` permite volver a correrlo), sin errores.

```text
mysql> SHOW TABLES;
+-------------------------------+
| Tables_in_ventas_vehiculos_dw |
+-------------------------------+
| dim_tiempo                    |
| dim_ubicacion                 |
| dim_vehiculo                  |
| dim_vendedor                  |
| fact_ventas                   |
+-------------------------------+

mysql> SELECT constraint_name, column_name, referenced_table_name
    -> FROM information_schema.key_column_usage
    -> WHERE table_schema = 'ventas_vehiculos_dw'
    ->   AND referenced_table_name IS NOT NULL
    -> ORDER BY constraint_name;
+---------------------+--------------+-----------------------+
| CONSTRAINT_NAME     | COLUMN_NAME  | REFERENCED_TABLE_NAME |
+---------------------+--------------+-----------------------+
| fk_ventas_tiempo    | id_tiempo    | dim_tiempo            |
| fk_ventas_ubicacion | id_ubicacion | dim_ubicacion         |
| fk_ventas_vehiculo  | id_vehiculo  | dim_vehiculo          |
| fk_ventas_vendedor  | id_vendedor  | dim_vendedor          |
+---------------------+--------------+-----------------------+
```

Prueba de que la unión protege: con las dimensiones vacías, insertar una fila de hechos falla.

```text
mysql> INSERT INTO fact_ventas VALUES (1, 1, 1, 1, 1, 10000.00, 10000.00, 5000.00);
ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails
(`ventas_vehiculos_dw`.`fact_ventas`, CONSTRAINT `fk_ventas_tiempo` FOREIGN KEY (`id_tiempo`)
REFERENCES `dim_tiempo` (`id_tiempo`))
```

Las 5 tablas quedaron creadas con motor InnoDB, que es el que hace valer las FOREIGN KEY.
