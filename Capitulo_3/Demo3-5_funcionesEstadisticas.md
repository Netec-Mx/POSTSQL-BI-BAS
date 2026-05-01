# Demo/POC. Funciones estadísticas en PostgreSQL

<br/><br/>

## 1. Crear tabla temporal

```sql
CREATE TEMP TABLE ventas_stats (
    id SERIAL,
    vendedor TEXT,
    region TEXT,
    mes TEXT,
    ventas NUMERIC,
    clientes INT,
    horas_trabajadas NUMERIC
);
```

<br/><br/>

## 2. Insertar datos de prueba

```sql
INSERT INTO ventas_stats
(vendedor, region, mes, ventas, clientes, horas_trabajadas)
VALUES
('Hugo',   'Norte', 'Enero',   1000, 10, 20),
('Hugo',   'Norte', 'Febrero', 1200, 12, 22),
('Hugo',   'Norte', 'Marzo',   1500, 15, 25),

('Paco',   'Sur',   'Enero',    800,  8, 18),
('Paco',   'Sur',   'Febrero',  900,  9, 19),
('Paco',   'Sur',   'Marzo',   1100, 11, 21),

('Luis',   'Norte', 'Enero',   2000, 20, 35),
('Luis',   'Norte', 'Febrero', 2200, 22, 37),
('Luis',   'Norte', 'Marzo',   2500, 25, 40),

('Miguel', 'Sur',   'Enero',    500,  5, 15),
('Miguel', 'Sur',   'Febrero',  700,  7, 17),
('Miguel', 'Sur',   'Marzo',    900,  9, 19);
```

<br/><br/>

## 3. Promedio con `avg`

```sql
SELECT
    AVG(ventas) AS promedio_ventas,
    AVG(clientes) AS promedio_clientes,
    AVG(horas_trabajadas) AS promedio_horas
FROM ventas_stats;
```

<br/>

`AVG()` calcula el promedio de un conjunto de valores.

<br/><br/>

## 4. Varianza con `variance`, `var_pop` y `var_samp`

```sql
SELECT
    VARIANCE(ventas) AS variance_ventas,
    VAR_POP(ventas)  AS varianza_poblacional,
    VAR_SAMP(ventas) AS varianza_muestral
FROM ventas_stats;
```

<br/>

Explicación:

La varianza mide qué tanto se dispersan los datos respecto al promedio.

```text
VARIANCE() = VAR_SAMP()
VAR_POP()  = varianza poblacional
VAR_SAMP() = varianza muestral
```

<br/>


<br/><br/>

## 5. Desviación estándar con `stddev`, `stddev_pop` y `stddev_samp`

```sql
SELECT
    STDDEV(ventas)      AS stddev_ventas,
    STDDEV_POP(ventas)  AS desviacion_poblacional,
    STDDEV_SAMP(ventas) AS desviacion_muestral
FROM ventas_stats;
```

<br/>

Explicación:

La desviación estándar también mide dispersión, pero en la misma unidad de los datos originales.

```text
STDDEV() = STDDEV_SAMP()
STDDEV_POP()  = desviación estándar poblacional
STDDEV_SAMP() = desviación estándar muestral
```

<br/><br/>

## 6. Estadísticas por región

```sql
SELECT
    region,
    AVG(ventas)        AS promedio_ventas,
    VARIANCE(ventas)   AS varianza_ventas,
    STDDEV(ventas)     AS desviacion_ventas,
    VAR_POP(ventas)    AS var_pop_ventas,
    STDDEV_POP(ventas) AS stddev_pop_ventas
FROM ventas_stats
GROUP BY region
ORDER BY region;
```

<br/>

Aquí se comparan las estadísticas por grupo usando `GROUP BY`.

<br/><br/>

## 7. Correlación con `corr`

```sql
SELECT
    CORR(clientes, ventas) AS correlacion_clientes_ventas
FROM ventas_stats;
```

<br/>

`CORR(y, x)` mide qué tan relacionadas están dos variables.

<br/>

Interpretación rápida:

```text
Cerca de  1  -> relación positiva fuerte
Cerca de  0  -> poca o nula relación lineal
Cerca de -1  -> relación negativa fuerte
```

<br/><br/>

## 8. Correlación entre horas trabajadas y ventas

```sql
SELECT
    CORR(horas_trabajadas, ventas) AS correlacion_horas_ventas
FROM ventas_stats;
```

<br/>

Sirve para analizar si al aumentar las horas trabajadas también aumentan las ventas.

<br/><br/>

## 9. Covarianza poblacional con `covar_pop`

```sql
SELECT
    COVAR_POP(clientes, ventas) AS covarianza_clientes_ventas
FROM ventas_stats;
```

<br/>

`COVAR_POP(y, x)` mide si dos variables tienden a moverse juntas.

<br/>

Interpretación rápida:

```text
Covarianza positiva -> ambas variables tienden a subir juntas
Covarianza negativa -> una sube mientras la otra baja
Covarianza cercana a 0 -> poca relación lineal
```

<br/><br/>

## 10. Todo junto

```sql
SELECT
    AVG(ventas)        AS avg_ventas,
    VARIANCE(ventas)   AS variance_ventas,
    STDDEV(ventas)     AS stddev_ventas,
    VAR_POP(ventas)    AS var_pop_ventas,
    STDDEV_POP(ventas) AS stddev_pop_ventas,
    STDDEV_SAMP(ventas) AS stddev_samp_ventas,
    CORR(clientes, ventas) AS corr_clientes_ventas,
    COVAR_POP(clientes, ventas) AS covar_pop_clientes_ventas
FROM ventas_stats;
```

<br/>

Esta consulta concentra las principales funciones estadísticas para analizar promedio, dispersión y relación entre variables.

<br/><br/>

# Tabla de ayuda — Funciones estadísticas en PostgreSQL

<br/>

| Función          | ¿Qué mide?                      | Interpretación de negocio               | Tipo (POP / SAMP) | Nota clave                                 |
| ---------------- | ------------------------------- | --------------------------------------- | ----------------- | ------------------------------------------ |
| `AVG()`          | Promedio                        | Valor típico de los datos               | N/A               | Centro de la distribución (curva de Gauss) |
| `VARIANCE()`     | Varianza                        | Qué tan dispersos están los datos       | SAMP              | Equivale a `VAR_SAMP()`                    |
| `VAR_POP()`      | Varianza poblacional            | Dispersión considerando todos los datos | POP               | Usa N (no N-1)                             |
| `VAR_SAMP()`     | Varianza muestral               | Dispersión estimada (más real en BI)    | SAMP              | Usa N-1                                    |
| `STDDEV()`       | Desviación estándar             | Dispersión en unidades reales           | SAMP              | Equivale a `STDDEV_SAMP()`                 |
| `STDDEV_POP()`   | Desviación estándar poblacional | Variación total del dataset             | POP               | Menos usada en analítica                   |
| `STDDEV_SAMP()`  | Desviación estándar muestral    | Variabilidad estimada                   | SAMP              | Más usada en BI                            |
| `CORR(x,y)`      | Correlación                     | Relación entre dos variables            | N/A               | Va de -1 a 1                               |
| `COVAR_POP(x,y)` | Covarianza poblacional          | Cómo se mueven juntas dos variables     | POP               | No está normalizada                        |

<br/><br/>

# Lectura 

<br/><br/>

| Concepto    | Traducción mental                    |
| ----------- | ------------------------------------ |
| Promedio    | Valor típico                       |
| Varianza    | Qué tan separados están (cuadrado) |
| Stddev      | Distancia real promedio al centro  |
| Correlación | Si dos variables se mueven juntas  |
| Covarianza  | Dirección del movimiento conjunto  |

<br/><br/>

# POP vs SAMP (clave de certificación)

<br/><br/>

| Tipo | Cuándo usar                                 |
| ---- | ------------------------------------------- |
| POP  | Cuando tienes TODOS los datos               |
| SAMP | Cuando trabajas con muestra (BI, analítica) |

<br/><br/>

```text
Regla práctica:
En BI casi siempre usas SAMP
```

<br/><br/>

# Interpretación de correlación

<br/><br/>

| Valor     | Significado                |
| --------- | -------------------------- |
| 1         | Relación perfecta positiva |
| 0.7 – 0.9 | Fuerte                     |
| 0.3 – 0.7 | Moderada                   |
| 0 – 0.3   | Débil                      |
| 0         | Sin relación               |
| Negativo  | Relación inversa           |

<br/><br/>

## Referencias

* [Documentación oficial](https://www.postgresql.org/docs/current/functions-aggregate.html)

