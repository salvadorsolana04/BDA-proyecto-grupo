**Facultad de Ingenieria**  
**Base de Datos Aplicada**  
**Justo Solana Allende 2508165**  
**Salvador Solana Allende 2304664**  
**Agustin Rodriguez Richard 2522521**

---

**Entrega 1 - Analisis de Requerimientos**

**1\. Tema y fuente de datos**

Tema: Análisis de ventas de vehículos.

Proceso de negocio: Venta de vehículos. Cada fila del archivo representa una operación de venta de un vehículo.

Fuente: Kaggle, dataset Vehicle Sales Data, publicado por Syed Anwar.

URL: [https://www.kaggle.com/datasets/syedanwarafridi/vehicle-sales-data](https://www.kaggle.com/datasets/syedanwarafridi/vehicle-sales-data)

Fecha de descarga: 08/09/2026

Recorte hecho por nosotros: Se seleccionaron las ventas realizadas entre el 01/01/2012 y el 31/12/2015, inclusive. Hicimos esto para reducir el volumen de datos y facilitar su análisis.

Qué información trae: La base contiene información sobre los vehículos vendidos, como marca, modelo, año de fabricación, características, estado, kilometraje, precio de venta, vendedor y fecha de la operación. El objetivo es analizar cómo evolucionaron las ventas y los precios a lo largo del tiempo.

**2\. a) Preguntas de negocio**

1. Cuantos vehiculos se vendieron por marca y por mes?
2. Cual fue el precio promedio de venta por modelo y por año de venta?
3. Cuantos vehiculos se vendieron por tipo de carroceria y por trimestre?
4. Cual fue el importe total de ventas por estado y por mes?
5. Cuantos vehiculos vendio cada vendedor por trimestre?
6. Cual fue el kilometraje promedio de los vehiculos vendidos por marca y por año de venta?

**3\. b) Indicadores y perspectivas**

Indicadores:   
- Cantidad de vehículos vendidos.   
- Importe total de ventas.   
- Precio promedio de venta.   
- Kilometraje promedio de los vehículos vendidos. 

Perspectivas:   
- Tiempo.   
- Vehículo.   
- Ubicación.   
- Vendedor.

| Pregunta | Indicador | Perspectivas |
|---|---|---|
| 1 | Cantidad de vehiculos vendidos | Vehiculo: marca, Tiempo: mes |
| 2 | Precio promedio de venta | Vehiculo: modelo, Tiempo: año |
| 3 | Cantidad de vehiculos vendidos | Vehiculo: tipo de carrocería, Tiempo: trimestre |
| 4 | Importe total de ventas| Ubicacion: estado, Tiempo: mes |
| 5 | Cantidad de vehiculos vendidos | Vendedor, Tiempo: trimestre |
| 6 | Kilometraje promedio | Vehiculo: marca, Tiempo: año |

   
**4\. c) Modelo Conceptual**  
```text
[Tiempo] ---------┐
[Vehiculo] -------┤
[Ubicacion] ------┼--- (Venta) ---> [Cantidad de vehiculos vendidos]
[Vendedor] -------┤                ---> [Importe total de ventas]
                  │                ---> [Precio promedio de venta]
                  └----------------> [Kilometraje promedio]
```
