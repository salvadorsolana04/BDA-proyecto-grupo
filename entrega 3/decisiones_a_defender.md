# Paso 3 — Decisiones a defender

Documento de estudio del grupo, no se entrega. Para cada punto: qué decidimos, por qué, y cómo responder si el profe pregunta.

---

## Cambios respecto del Paso 1

**¿Por qué cambiaron las preguntas 2 y 6?**
Porque el recorte del archivo fue por `year` (año/modelo del vehículo), no por fecha de venta. Las ventas van de enero 2014 a julio 2015, y 2014 es casi solo diciembre (19.631 ventas contra 271.321 de 2015). Comparar por año de venta no dice nada útil, así que pasamos a mes, que ya era el nivel mínimo del Paso 2. Los indicadores y las perspectivas no cambian.

**¿Por qué el año sigue en dim_tiempo si ninguna pregunta lo usa?**
Porque sin año no se distingue enero 2014 de enero 2015. Es parte de la jerarquía mes → trimestre → año.

**¿Qué pasó con las 26 filas mal formadas?**
Son todas VW Jetta con una coma dentro del `trim`, que corrió todos los valores una columna. En `state` quedó el VIN y en `saledate` el precio, así que no se pueden ubicar ni en Tiempo ni en Ubicación. Se descartan en el Paso 4. Filas útiles: 290.952.

**¿Por qué "estado/provincia"?**
Porque de los 38 valores reales, 4 son provincias de Canadá (on, qc, ab, ns) y uno es Puerto Rico. No agregamos país porque ninguna pregunta lo pide, y la regla es que si no está en el modelo conceptual no aparece en el lógico.

---

## a) Tipo de esquema: estrella

**¿Por qué no es constelación?**
Porque hay un solo proceso de negocio (la venta) y cada fila del CSV trae a la vez las 4 perspectivas y los datos de los 4 indicadores. Todas las preguntas son combinaciones de los mismos indicadores sobre las mismas perspectivas (Caso 3), así que se unifican en una sola tabla de hechos.

**Trampa: "La pregunta 1 (cantidad por marca) y la 4 (importe por estado), ¿no son Caso 2?"**
No, porque los dos indicadores salen del mismo evento y del mismo grano, que es una venta. Que ninguna pregunta cruce el importe con la marca es porque no nos interesó, no porque no se pueda. Sería constelación si un indicador viniera de otro proceso o de otro grano, por ejemplo metas mensuales por vendedor o stock por concesionaria. En ese caso habría dos tablas de hechos que comparten Tiempo y Vendedor.

**¿Por qué no es copo de nieve?**
La única jerarquía con algo de tamaño es Vehículo (43 marcas, 418 modelos). Además, la carrocería no cuelga del modelo, porque un mismo modelo puede tener varias. Normalizar significaría 3 o 4 tablas y más JOIN (por ejemplo, para la pregunta 3), solo para no repetir 43 nombres de marca en unas 488 filas. El copo de nieve se justifica con dimensiones de muchas tuplas, y este no es el caso.

---

## b) Dimensiones

**¿Por qué 4 dimensiones?**
Por la regla de oro: cada perspectiva del modelo conceptual es una tabla de dimensión, siempre.

**¿Por qué una clave nueva y no la del archivo?**
La clave subrogada (AUTO_INCREMENT) ocupa menos, no depende de cómo el archivo codifique las cosas, y si el archivo cambia un código el DW lo toma como elemento nuevo. La clave natural del archivo no se tira: queda como campo con UNIQUE para rastrear el origen y para que el Paso 4 no duplique filas.

**¿Por qué la clave de Tiempo es AUTO_INCREMENT y no `yyyymm`?**
Las dos son válidas. Elegimos subrogada más UNIQUE(anio, mes) para usar el mismo criterio en las 4 dimensiones. `yyyymm` (por ejemplo 201501) es la variante de la filmina 8 para grano mes y también se puede defender.

**¿Por qué dim_vehiculo tiene una fila por combinación marca + modelo + carrocería?**
Porque la carrocería no depende del modelo: 63 de 406 pares marca+modelo tienen más de una (BMW 3 Series tiene 4). Si la fila fuera "un modelo", no habría dónde guardar la carrocería de cada venta.

**¿Por qué las claves tienen tipos distintos (TINYINT, SMALLINT, INT)?**
Cada tipo está dimensionado según la cantidad de filas: TINYINT llega hasta 127 (hay 38 ubicaciones), SMALLINT hasta 32.767 (hay 10 meses), e INT se usa para vehículo y vendedor. La condición es que la FK en fact_ventas tenga exactamente el mismo tipo; si no, la FK falla (filmina 21).

**¿De dónde salen los tamaños de VARCHAR?**
De los máximos reales del archivo: marca 13 caracteres, modelo 29, carrocería 23 y vendedor 50. A cada uno le dimos margen.

**¿Qué hace la collation con el UNIQUE?**
`utf8mb4_unicode_ci` no distingue mayúsculas de minúsculas. Si en el Paso 4 no se normaliza "Sedan"/"sedan", el UNIQUE rechaza el duplicado en vez de crear dos filas.

**¿Para qué una dimensión de un solo campo (dim_ubicacion)?**
Porque "una perspectiva = una tabla, siempre". Si mañana se agrega el nombre completo del estado o el país, va ahí sin tocar la tabla de hechos.

---

## c) Tabla de hechos

**¿Una fila de fact_ventas es una venta?**
No. Es una combinación de mes + vehículo + ubicación + vendedor, porque ese es el grano del Paso 2 (Tiempo a nivel mes). Las 290.952 ventas quedan en 106.486 filas. Ejemplo: en febrero de 2015, "nissan-infiniti lt" vendió en Florida 690 Nissan Altima sedán, y eso es una sola fila con cantidad_vendidos = 690.

**¿Por qué no un `id_venta` AUTO_INCREMENT como PK?**
Porque entonces nada impediría dos filas para el mismo grano, que es el error típico "hechos sin PK compuesta". La PK es la combinación de las 4 claves de dimensión.

**¿Cuál es la diferencia entre hechos básicos y derivados?**
Los básicos son cantidad_vendidos (COUNT) e importe_total (SUM). Los derivados son precio_promedio (= importe_total / cantidad) y km_promedio (AVG). Los derivados se precalculan y también se guardan en la tabla de hechos.

**¿Cómo se calcula el promedio al agrupar por otro nivel?**
Nunca promediando promedios. Se calcula así:
- precio promedio = SUM(importe_total) / SUM(cantidad_vendidos)
- km promedio = SUM(km_promedio × cantidad_vendidos) / SUM(cantidad_vendidos)

**¿Por qué esos tipos?**
COUNT va en INT (el máximo real es 690). Los montos van en DECIMAL, nunca en FLOAT, porque FLOAT redondea. El importe máximo de una fila es 9.013.300, así que DECIMAL(12,2) alcanza hasta 9.999 millones.

**Punto débil a tener presente: el kilometraje.**
Hay 6 ventas con `odometer` nulo. AVG las ignora, así que en esas filas la fórmula ponderada por cantidad no da exacta. Además hay atípicos como 999.999. Las dos cosas se resuelven en el Paso 4.

---

## d) Uniones

**¿Qué representa cada línea del diagrama?**
Una FOREIGN KEY de fact_ventas (lado n) hacia la PK de una dimensión (lado 1). Son 4 perspectivas, 4 FK, y las 4 FK juntas forman la PK.

**¿Por qué InnoDB?**
Porque con MyISAM las FOREIGN KEY se ignoran en silencio. La prueba de que funcionan es insertar una fila de hechos con las dimensiones vacías, que da ERROR 1452.

**¿Por qué las dimensiones se crean primero?**
Porque una FK solo puede apuntar a una tabla que ya existe.

**¿Por qué los CONSTRAINT tienen nombre (fk_ventas_tiempo, ...)?**
Para que el error diga cuál unión falló y para poder consultarlas en information_schema.
