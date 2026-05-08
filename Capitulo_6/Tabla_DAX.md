
# Tabla de Ayuda – Fórmulas DAX más usadas en Power BI

<br/><br/>

## ¿Qué es DAX?

Data Analysis Expressions

Es el lenguaje de fórmulas utilizado en:

- Power BI
    Plataforma de Business Intelligence (BI) de Microsoft.

- Microsoft Analysis Services -  SSAS (SQL Server Analysis Services)
    Tecnología de Microsoft para análisis multidimensional. 

- Power Pivot para Excel
    Extensión avanzada de Excel para análisis de grandes volúmenes de datos.


<br/>

DAX se utiliza para:

- Crear métricas y KPIs
- Realizar cálculos avanzados
- Crear columnas calculadas
- Analizar datos en el tiempo
- Generar agregaciones dinámicas
- Construir dashboards interactivos

<br/>
<br/>

## Tablas de Ayuda


| Categoría                | Fórmula                | Descripción                            | Ejemplo                                                                               |
| ------------------------ | ---------------------- | -------------------------------------- | ------------------------------------------------------------------------------------- |
| Suma                     | `SUM()`                | Suma valores numéricos de una columna  | `Ventas Totales = SUM(Ventas[monto_total])`                                           |
| Promedio                 | `AVERAGE()`            | Calcula el promedio                    | `Ticket Promedio = AVERAGE(Ventas[monto_total])`                                      |
| Conteo                   | `COUNT()`              | Cuenta registros numéricos             | `Num Ventas = COUNT(Ventas[id_venta])`                                                |
| Conteo no vacíos         | `COUNTA()`             | Cuenta registros no vacíos             | `Clientes = COUNTA(Clientes[nombre])`                                                 |
| Conteo único             | `DISTINCTCOUNT()`      | Cuenta valores únicos                  | `Clientes Únicos = DISTINCTCOUNT(Ventas[id_cliente])`                                 |
| Máximo                   | `MAX()`                | Obtiene el valor máximo                | `Venta Máxima = MAX(Ventas[monto_total])`                                             |
| Mínimo                   | `MIN()`                | Obtiene el valor mínimo                | `Venta Mínima = MIN(Ventas[monto_total])`                                             |
| División segura          | `DIVIDE()`             | Divide evitando errores por cero       | `Margen % = DIVIDE([Utilidad],[Ventas Totales],0)`                                    |
| Condición                | `IF()`                 | Evalúa una condición                   | `Nivel = IF([Ventas Totales]>100000,"Alta","Baja")`                                   |
| Condición múltiple       | `SWITCH()`             | Reemplaza múltiples IF                 | `Estado = SWITCH([Score],1,"Malo",2,"Regular","Bueno")`                               |
| Filtrar cálculo          | `CALCULATE()`          | Modifica el contexto del cálculo       | `Ventas Activas = CALCULATE([Ventas Totales],Ventas[estado]="ACTIVO")`                |
| Filtro personalizado     | `FILTER()`             | Aplica filtros avanzados               | `FILTER(Ventas, Ventas[monto_total] > 1000)`                                          |
| Relación temporal        | `DATEADD()`            | Desplaza fechas                        | `Ventas Año Pasado = CALCULATE([Ventas Totales], DATEADD(Calendario[Fecha],-1,YEAR))` |
| Total acumulado          | `TOTALYTD()`           | Acumulado anual                        | `Ventas YTD = TOTALYTD([Ventas Totales], Calendario[Fecha])`                          |
| Mes anterior             | `PREVIOUSMONTH()`      | Obtiene datos del mes previo           | `Ventas Mes Ant = CALCULATE([Ventas Totales], PREVIOUSMONTH(Calendario[Fecha]))`      |
| Año anterior             | `SAMEPERIODLASTYEAR()` | Compara contra el año pasado           | `Ventas LY = CALCULATE([Ventas Totales], SAMEPERIODLASTYEAR(Calendario[Fecha]))`      |
| Ranking                  | `RANKX()`              | Genera rankings                        | `Ranking Producto = RANKX(ALL(Productos[nombre]), [Ventas Totales])`                  |
| Texto concatenado        | `CONCATENATE()`        | Une textos                             | `Nombre Completo = CONCATENATE(Clientes[nombre]," ",Clientes[apellido])`              |
| Texto moderno            | `&`                    | Concatenación recomendada              | `Nombre = Clientes[nombre] & " " & Clientes[apellido]`                                |
| Valores seleccionados    | `SELECTEDVALUE()`      | Obtiene valor seleccionado en slicer   | `Año Seleccionado = SELECTEDVALUE(Calendario[Año])`                                   |
| Valores relacionados     | `RELATED()`            | Trae valores de otra tabla relacionada | `Categoría = RELATED(Productos[categoria])`                                           |
| Tabla relacionada        | `RELATEDTABLE()`       | Devuelve filas relacionadas            | `COUNTROWS(RELATEDTABLE(Ventas))`                                                     |
| Total de filas           | `COUNTROWS()`          | Cuenta filas de tabla                  | `Total Filas = COUNTROWS(Ventas)`                                                     |
| Valores únicos           | `VALUES()`             | Devuelve valores únicos                | `VALUES(Productos[categoria])`                                                        |
| Eliminar filtros         | `ALL()`                | Ignora filtros del contexto            | `Ventas Globales = CALCULATE([Ventas Totales], ALL(Productos))`                       |
| Mantener filtros         | `KEEPFILTERS()`        | Conserva filtros existentes            | `CALCULATE([Ventas Totales], KEEPFILTERS(Productos[categoria]="Electrónica"))`        |
| Top N                    | `TOPN()`               | Obtiene Top registros                  | `TOPN(5, Productos, [Ventas Totales], DESC)`                                          |
| Fecha actual             | `TODAY()`              | Devuelve fecha actual                  | `TODAY()`                                                                             |
| Fecha y hora actual      | `NOW()`                | Devuelve fecha y hora                  | `NOW()`                                                                               |
| Diferencia fechas        | `DATEDIFF()`           | Calcula diferencia entre fechas        | `DATEDIFF(Clientes[fecha_registro], TODAY(), DAY)`                                    |
| Crear columna calendario | `CALENDAR()`           | Genera tabla calendario                | `Calendario = CALENDAR(DATE(2020,1,1), DATE(2030,12,31))`                             |



<br/><br/>

## Medidas DAX comunes para Dashboards BI

### Total de Ventas

```DAX
Total Ventas = SUM(Ventas[monto_total])
```

<br/>

### Total de Costos

```DAX
Total Costos = SUM(Ventas[costo_total])
```

<br/>

### Margen Bruto

```DAX
Margen Bruto = [Total Ventas] - [Total Costos]
```

<br/>

### Margen %

```DAX
Margen % = DIVIDE([Margen Bruto], [Total Ventas], 0) * 100
```

<br/>

### Ticket Promedio

```DAX
Ticket Promedio = AVERAGE(Ventas[monto_total])
```

<br/>

### Ventas Año Anterior

```DAX
Ventas Año Anterior =
CALCULATE(
    [Total Ventas],
    SAMEPERIODLASTYEAR(Calendario[Fecha])
)
```

<br/>

### Variación %

```DAX
Variación % =
DIVIDE(
    [Total Ventas] - [Ventas Año Anterior],
    [Ventas Año Anterior],
    0
)
```

<br/>

### Top 5 Productos

```DAX
Top Productos =
TOPN(
    5,
    Productos,
    [Total Ventas],
    DESC
)
```

<br/><br>

# Tabla de Operadores DAX

| Operador | Significado            | Ejemplo                                       |
| -------- | ---------------------- | --------------------------------------------- |
| `+`      | Suma                   | `[Ventas] + [Impuestos]`                      |
| `-`      | Resta                  | `[Ventas] - [Costos]`                         |
| `*`      | Multiplicación         | `[Cantidad] * [Precio]`                       |
| `/`      | División               | `[Ventas] / [Clientes]`                       |
| `^`      | Potencia               | `[Valor] ^ 2`                                 |
| `=`      | Igual                  | `Ventas[estado] = "ACTIVO"`                   |
| `<>`     | Diferente              | `Ventas[estado] <> "CANCELADO"`               |
| `>`      | Mayor que              | `[Ventas] > 1000`                             |
| `<`      | Menor que              | `[Ventas] < 500`                              |
| `>=`     | Mayor o igual          | `[Ventas] >= 10000`                           |
| `<=`     | Menor o igual          | `[Ventas] <= 2500`                            |
| `&&`     | AND lógico             | `[Ventas] > 1000 && [Estado] = "OK"`          |
| `\|\|`   | OR lógico              | `[Region] = "Norte" \|\| [Region] = "Sur"`    |
| `NOT`    | Negación lógica        | `NOT([Activo])`                               |
| `&`      | Concatenación de texto | `Clientes[nombre] & " " & Clientes[apellido]` |
| `IN`     | Buscar dentro de lista | `Productos[categoria] IN {"A","B","C"}`       |


<br/><br/>

## Operador AND (`&&`)

```DAX id="1r8kfa"
Ventas Altas =
IF(
    [Ventas] > 10000 && [Margen %] > 0.25,
    "Excelente",
    "Normal"
)
```

<br/>

## Operador OR (`||`)

```DAX id="7x3mvd"
Region Valida =
IF(
    Ventas[region] = "Norte" || Ventas[region] = "Sur",
    "Prioritaria",
    "Secundaria"
)
```

<br/>

## Concatenación (`&`)

```DAX id="4cp2zn"
Nombre Completo =
Clientes[nombre] & " " & Clientes[apellido]
```

<br/>

## Operador IN

```DAX id="8lt6wr"
Categoria Especial =
IF(
    Productos[categoria] IN {"Tecnología","Gaming","Audio"},
    "SI",
    "NO"
)
```

<br/><br/>

