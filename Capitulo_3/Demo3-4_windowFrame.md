
# Demo / POC – Window Frame (ROWS vs RANGE)

<br/><br/>

### 1. Crear tabla de prueba

```sql
CREATE TEMP TABLE ventas_demo (
    id SERIAL,
    vendedor TEXT,
    fecha DATE,
    monto NUMERIC
);
````

<br/><br/>

### 2. Insertar datos con empates

```sql
INSERT INTO ventas_demo (vendedor, fecha, monto) VALUES
('Hugo', '2024-01-01', 100),
('Hugo', '2024-01-02', 200),
('Hugo', '2024-01-03', 200), -- empate
('Hugo', '2024-01-04', 300),

('Luis', '2024-01-01', 150),
('Luis', '2024-01-02', 150), -- empate
('Luis', '2024-01-03', 400);
```

<br/><br/>

### 3. DEFAULT

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY monto
    ) AS acumulado_default
FROM ventas_demo;
```

<br/>

> PostgreSQL usa por defecto: `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`
> Con `RANGE`, los valores iguales (empates) se agrupan
> No suma fila por fila… suma por "valor lógico"

<br/><br/>

### 4. ROWS vs RANGE

#### ROWS - filas físicas

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY monto
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS acumulado_rows
FROM ventas_demo;
```

<br/>

> Suma fila por fila
> Cada fila avanza el acumulado

<br/><br/>

#### RANGE (valor lógico)

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY monto
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS acumulado_range
FROM ventas_demo;
```

<br/>

> Las filas con mismo `monto` se consideran juntas
> El acumulado “salta”

<br/><br/>

### 5. N PRECEDING

#### Últimas 2 filas (ROWS)

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS suma_ultimas_3_filas
FROM ventas_demo;
```

<br/>

> Ventana móvil tipo BI
> Muy usado en promedios móviles

<br/><br/>

#### RANGE con PRECEDING

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY monto
        RANGE BETWEEN 100 PRECEDING AND CURRENT ROW
    ) AS rango_por_valor
FROM ventas_demo;
```

<br/>

> No son filas
> Es un rango de valores (monto)

<br/><br/>

### 6. CURRENT ROW

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN CURRENT ROW AND CURRENT ROW
    ) AS solo_fila_actual
FROM ventas_demo;
```

<br/>

Equivale prácticamente a usar solo `monto`

<br/><br/>

### 7. N FOLLOWING

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING
    ) AS suma_con_siguiente
FROM ventas_demo;
```

<br/>

Incluye: fila actual y siguiente fila

<br/><br/>

### 8. UNBOUNDED FOLLOWING

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
    ) AS suma_hacia_el_futuro
FROM ventas_demo;
```

<br/>

* Acumula desde la fila actual hasta el final

<br/><br/>

### 9. COMBINACIÓN COMPLETA

```sql
SELECT
    vendedor,
    fecha,
    monto,

    -- acumulado clásico
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS acumulado,

    -- ventana móvil
    AVG(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS promedio_movil,

    -- hacia adelante
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
    ) AS restante

FROM ventas_demo;
```

<br/><br/>

## Conclusión

* Sí, se puede usar con ambos:
* `ROWS` → físico (filas)
* `RANGE` → lógico (valores)

| Caso                                | Usar  |
| ----------------------------------- | ----- |
| BI clásico (acumulados, moving avg) | ROWS  |
| Análisis por rangos de valor        | RANGE |
| Evitar sorpresas con empates        | ROWS  |

<br/><br/>

## Combinaciones interesantes

### 1. Ventana centrada

```sql
SELECT
    vendedor,
    fecha,
    monto,
    AVG(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS promedio_centrado
FROM ventas_demo;
```

<br/>

* Incluye fila anterior, actual y siguiente
* Ideal para smoothing y KPIs estables

<br/><br/>

### 2. Todo menos el actual

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS acumulado_sin_actual
FROM ventas_demo;
```

<br/>

* ¿Cuánto llevaba antes de esta venta?

<br/><br/>

### 3. Comparación contra futuro

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
    ) AS ventas_futuras
FROM ventas_demo;
```

<br/>

* ¿Qué viene después de esta fila?

<br/><br/>

### 4. Diferencia contra promedio del grupo completo

```sql
SELECT
    vendedor,
    fecha,
    monto,
    AVG(monto) OVER (PARTITION BY vendedor) AS promedio_vendedor,
    monto - AVG(monto) OVER (PARTITION BY vendedor) AS desviacion
FROM ventas_demo;
```

<br/>

* Se usa toda la partición
* `baseline` vs desviación

<br/><br/>

### 5. RANGE con fechas

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        RANGE BETWEEN INTERVAL '2 days' PRECEDING AND CURRENT ROW
    ) AS suma_ultimos_2_dias
FROM ventas_demo;
```

<br/>

* No son filas
* Es tiempo real

<br/><br/>

### 6. NTILE + frame

```sql
SELECT
    vendedor,
    monto,
    NTILE(3) OVER (ORDER BY monto) AS grupo,
    SUM(monto) OVER (
        ORDER BY monto
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS acumulado_global
FROM ventas_demo;
```

<br/>

* Combina segmentación y acumulado

<br/><br/>

### 7. Frame invertido

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS acumulado_inverso
FROM ventas_demo;
```

<br/>

* Acumula del futuro al pasado

<br/><br/>

### 8. Ventana asimétrica

```sql
SELECT
    vendedor,
    fecha,
    monto,
    AVG(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN 3 PRECEDING AND 1 FOLLOWING
    ) AS ventana_asimetrica
FROM ventas_demo;
```

<br/>

* Incluye más pasado que futuro

<br/><br/>

### 9. Frame dinámico

```sql
SELECT
    vendedor,
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY vendedor
        ORDER BY fecha
        ROWS BETWEEN 
            CASE WHEN monto > 200 THEN 2 ELSE 1 END PRECEDING
        AND CURRENT ROW
    ) AS ventana_dinamica
FROM ventas_demo;
```

<br/>

* El tamaño del frame cambia según el dato

<br/><br/>

### Observaciones

* Las combinaciones interesantes están en cómo interpretas el negocio

### Traducción a negocio

| Patrón      | Significado       |
| ----------- |------------------ |
| PRECEDING   | historial         |
| FOLLOWING   | proyección        |
| CURRENT ROW | presente          |
| UNBOUNDED   | todo              |
| RANGE       | lógica de negocio |
| ROWS        | física            |

<br/><br/>

* Un window frame no es técnico es una pregunta de negocio disfrazada.

