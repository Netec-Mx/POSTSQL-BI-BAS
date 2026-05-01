

# Demo / POC: Funciones de Ventana - Propósito General

<br/><br/>

## Objetivo

Probar y entender el comportamiento de:

* Ranking
* Distribución
* Navegación (lag/lead)
* Acceso por posición (first/last/nth)


<br/><br>

## Tablas de ayuda 

### Funiones de Ventana 


| Función          | ¿Para qué sirve?                                     | Ejemplo rápido                                                     |
| ---------------- | ---------------------------------------------------- | ------------------------------------------------------------------ |
| `row_number()`   | Numera cada fila de forma única dentro de la cohorte | `row_number() OVER (PARTITION BY categoria ORDER BY ventas DESC)`  |
| `rank()`         | Ranking con huecos cuando hay empates                | `rank() OVER (ORDER BY ventas DESC)`                               |
| `dense_rank()`   | Ranking sin huecos                                   | `dense_rank() OVER (ORDER BY ventas DESC)`                         |
| `percent_rank()` | Posición relativa (0 a 1) dentro del grupo           | `percent_rank() OVER (ORDER BY ventas)`                            |
| `cume_dist()`    | % acumulado de filas hasta la actual                 | `cume_dist() OVER (ORDER BY ventas)`                               |
| `ntile(n)`       | Divide filas en *n* grupos (ej. cuartiles)           | `ntile(4) OVER (ORDER BY ventas)`                                  |
| `lag()`          | Valor anterior (comparaciones temporales)            | `lag(ventas) OVER (ORDER BY fecha)`                                |
| `lead()`         | Valor siguiente                                      | `lead(ventas) OVER (ORDER BY fecha)`                               |
| `first_value()`  | Primer valor de la cohorte                           | `first_value(ventas) OVER (PARTITION BY categoria ORDER BY fecha)` |
| `last_value()`   | Último valor (depende del frame)                     | `last_value(ventas) OVER (...)`                                    |
| `nth_value()`    | Valor en posición específica                         | `nth_value(ventas, 2) OVER (...)`                                  |



### Funciones agregadas como ventana  

| Función   | ¿Para qué sirve?                    | Ejemplo                                     |
| --------- | ----------------------------------- | ------------------------------------------- |
| `avg()`   | Promedio sin agrupar filas          | `avg(ventas) OVER (PARTITION BY categoria)` |
| `sum()`   | Acumulados o totales por cohorte    | `sum(ventas) OVER (ORDER BY fecha)`         |
| `count()` | Conteo por cohorte                  | `count(*) OVER (PARTITION BY categoria)`    |
| `max()`   | Máximo por grupo sin perder detalle | `max(ventas) OVER (PARTITION BY categoria)` |
| `min()`   | Mínimo por grupo                    | `min(ventas) OVER (PARTITION BY categoria)` |


## Conceptos clave 

### NO agrupan filas

* A diferencia de `GROUP BY`, aquí **no pierdes detalle**
* Cada fila conserva su contexto

### Cohortes 

```sql
OVER (PARTITION BY categoria)
```

Define el “grupo lógico” donde se calcula la función

### Orden 

```sql
OVER (ORDER BY fecha)
```

Define la secuencia (ej. mes, año, etc)

### Window Frame

Ejemplo:

```sql
SUM(ventas) OVER (
    ORDER BY fecha
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```

Esto define **acumulados**


<br/><br>

##  Errores comunes 

* `last_value()` no funciona como esperan necesita frame
* Olvidar `ORDER BY` en `lag()` / `lead()`
* Confundir `rank()` vs `dense_rank()`
* Creer que es igual a `GROUP BY`


<br/><br>

### A nivel negocio

| Caso                    | Función          |
| ----------------------- | ---------------- |
| Top clientes            | `rank()`         |
| Crecimiento mes a mes   | `lag()`          |
| Segmentación (Top 25%)  | `ntile()`        |
| Participación acumulada | `cume_dist()`    |
| Posición relativa       | `percent_rank()` |


<br/><br/>

### 1. Crear tabla ventas_demo

```sql
CREATE TEMP TABLE ventas_demo (
    id SERIAL,
    vendedor TEXT,
    region TEXT,
    monto NUMERIC
);
```


<br/><br>

### 2. Insertar datos  

```sql
INSERT INTO ventas_demo (vendedor, region, monto) VALUES
('Hugo',  'Norte', 100),
('Paco',  'Norte', 200),
('Luis',  'Norte', 200), -- empate
('Miguel','Norte', 300),

('Hugo',  'Sur',   150),
('Paco',  'Sur',   150), -- empate
('Luis',  'Sur',   250),
('Miguel','Sur',   400);
```


<br/><br>

### 3. Tabla base

```sql
SELECT * FROM ventas_demo ORDER BY region, monto;
```

<br/><br>

##  4. Ranking Functions

### 4.1 `row_number()`

```sql
SELECT
    vendedor,
    region,
    monto,
    ROW_NUMBER() OVER (PARTITION BY region ORDER BY monto DESC) AS row_num
FROM ventas_demo;
```

<br/><br>

### 4.2 `rank()`

```sql
RANK() OVER (PARTITION BY region ORDER BY monto DESC)
```

<br/><br>

### 4.3 `dense_rank()`

```sql
DENSE_RANK() OVER (PARTITION BY region ORDER BY monto DESC)
```

<br/><br>

## 5. Distribución

### 5.1 `percent_rank()`

```sql
SELECT
    vendedor,
    monto,
    PERCENT_RANK() OVER (PARTITION BY region ORDER BY monto) AS percent_rank
FROM ventas_demo;
```


### Interpretación

* Va de **0 a 1**
* Fórmula: (rank - 1) / (n - 1)

<br/><br>

### 5.2 `cume_dist()`

```sql
CUME_DIST() OVER (PARTITION BY region ORDER BY monto)
```

### Interpretación

* Acumulado
* Ejemplo: 0.75 = está en el 75% superior

<br/><br>

### 5.3 `ntile(3)`

```sql
NTILE(3) OVER (PARTITION BY region ORDER BY monto DESC) AS grupo
```

<br/><br>

##  6. Navegación

### 6.1 `lag()`

```sql
SELECT
    vendedor,
    monto,
    LAG(monto) OVER (PARTITION BY region ORDER BY monto) AS anterior
FROM ventas_demo;
```

<br/><br>

### 6.2 `lead()`

```sql
LEAD(monto) OVER (PARTITION BY region ORDER BY monto) AS siguiente
```

<br/><br>

## 7. Acceso por posición

### IMPORTANTE (clave pedagógica)

Estas funciones dependen del **window frame**, no solo del ORDER BY.

### 7.1 `first_value()`

```sql
FIRST_VALUE(monto) OVER (
    PARTITION BY region
    ORDER BY monto DESC
) AS mayor_venta
```


<br/><br>

### 7.2 `last_value()`  

```sql
LAST_VALUE(monto) OVER (
    PARTITION BY region
    ORDER BY monto DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) AS menor_venta
```

### Explicación

Sin ese `ROWS BETWEEN`, **NO funciona como esperas**

<br/><br>

### 7.3 `nth_value()`

```sql
NTH_VALUE(monto, 2) OVER (
    PARTITION BY region
    ORDER BY monto DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) AS segundo_mejor
```

<br/><br>

## Consulta final (TODO)

```sql
SELECT
    vendedor,
    region,
    monto,

    ROW_NUMBER() OVER (PARTITION BY region ORDER BY monto DESC) AS row_num,
    RANK()       OVER (PARTITION BY region ORDER BY monto DESC) AS rank,
    DENSE_RANK() OVER (PARTITION BY region ORDER BY monto DESC) AS dense_rank,

    PERCENT_RANK() OVER (PARTITION BY region ORDER BY monto) AS percent_rank,
    CUME_DIST()    OVER (PARTITION BY region ORDER BY monto) AS cume_dist,
    NTILE(3)       OVER (PARTITION BY region ORDER BY monto DESC) AS ntile,

    LAG(monto)  OVER (PARTITION BY region ORDER BY monto) AS anterior,
    LEAD(monto) OVER (PARTITION BY region ORDER BY monto) AS siguiente,

    FIRST_VALUE(monto) OVER (PARTITION BY region ORDER BY monto DESC) AS maximo,

    LAST_VALUE(monto) OVER (
        PARTITION BY region
        ORDER BY monto DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS minimo,

    NTH_VALUE(monto, 2) OVER (
        PARTITION BY region
        ORDER BY monto DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS segundo

FROM ventas_demo;
```

<br/><br>


## Resultado esperado


 
