# Práctica 4.1 Uso de Funciones de Tiempo 

<br/>

## Objetivos

Al completar esta práctica, serás capaz de:

- Manipular fechas y timestamps usando `DATE_TRUNC()`, `EXTRACT()` e `INTERVAL` para agrupar ventas por diferentes granularidades temporales.
- Construir comparaciones Year-over-Year (YoY) y Month-over-Month (MoM) combinando CTEs y la función de ventana `LAG()`
- Generar series de fechas continuas con `generate_series()` para detectar días sin ventas (gaps temporales).
- Calcular métricas de retención y cohortes basadas en la fecha de primera compra de cada cliente.
- Explorar los conceptos básicos de TimescaleDB: instalación de la extensión, creación de una hypertable y consulta con `time_bucket()`.

<br/>

## Prerrequisitos

### Conocimientos Requeridos

- Las prácticas 3.1, 3.2 y 3.3 completados exitosamente.
- Dataset de ventas (`sales`, `customers`, `products`, `order_items`) disponible en la base de datos `ventas_db`.
- Comprensión básica de CTEs (`WITH`) y funciones de ventana (`OVER`, `PARTITION BY`, `ORDER BY`).
- Familiaridad con `JOIN`, `GROUP BY` y funciones de agregación estándar.
- Conocimiento básico de tipos de datos `DATE`, `TIMESTAMP` y `TIMESTAMPTZ` en PostgreSQL.

<br/>

### Acceso Requerido

- Contenedor Docker de PostgreSQL 16 ejecutándose (configurado en práctica 1.1)
- Acceso a pgAdmin 4 (http://localhost:8080) o cliente `psql`
- Permisos de superusuario en la base de datos `ventas_db` (usuario `postgres`)
- Conexión a internet para descargar la imagen Docker de TimescaleDB (o imagen pre-descargada disponible)

<br/>
<br/>

## Entorno

### Configuración Inicial

Antes de comenzar, verifica que tu entorno esté operativo:

```bash
# Verificar que Docker está ejecutándose
docker --version
docker ps

# Verificar que el contenedor de PostgreSQL está activo
docker ps --filter "name=curso_postgres" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

```bash
# Conectarse a la base de datos y verificar el dataset
docker exec -it curso_postgres psql -U postgres -d ventas_db -c "\dt"
```

```bash
# Variable de entorno

set DOCKER_CLI_HINTS=false

# Verificar cantidad de registros disponibles
docker exec -it curso_postgres psql -U postgres -d ventas_db -c "SELECT 'ventas' AS tabla, COUNT(*) AS registros FROM ventas UNION ALL SELECT 'clientes', COUNT(*) FROM clientes UNION ALL SELECT 'detalle_ordenes', COUNT(*) FROM detalle_ordenes;"
```

<br/>

> **Nota sobre TimescaleDB:** La sección final de esta práctica (Paso 7) requiere un contenedor Docker diferente al PostgreSQL estándar. Se utilizará la imagen `timescale/timescaledb-ha:pg16`. Puedes tener ambos contenedores ejecutándose simultáneamente en puertos diferentes. El contenedor TimescaleDB usará el puerto `5433`.


<br/>
<br/>

## Instrucciones

### Paso 1: Preparación y Enriquecimiento del Dataset Temporal

1. Abre pgAdmin 4 en tu navegador (http://localhost:8080) y conéctate al servidor PostgreSQL. Selecciona la base de datos `ventas_db` y abre el Query Tool.

<br/>

2. Verifica la estructura temporal actual del dataset:

```sql
-- Verificar estructura de la tabla sales
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'sales'
  AND table_schema = 'public'
ORDER BY ordinal_position;
```
<br/>

3. Analiza el rango temporal de los datos existentes:

```sql
-- Rango temporal y distribución básica
SELECT 
    MIN(sale_date)                          AS fecha_minima,
    MAX(sale_date)                          AS fecha_maxima,
    MAX(sale_date) - MIN(sale_date)         AS rango_total,
    COUNT(*)                                AS total_ventas,
    COUNT(DISTINCT DATE_TRUNC('month', sale_date)) AS meses_con_ventas
FROM sales;
```

<br/>

4. Si la columna `sale_date` es de tipo `DATE` y no `TIMESTAMP`, ejecuta la siguiente actualización para agregar precisión horaria (necesaria para análisis intradiario):

```sql
-- Agregar columna de timestamp si no existe
ALTER TABLE sales 
ADD COLUMN IF NOT EXISTS sale_timestamp TIMESTAMPTZ;

-- Poblar con timestamps simulados (hora aleatoria dentro del día de venta)
UPDATE sales
SET sale_timestamp = sale_date::TIMESTAMPTZ 
    + (FLOOR(RANDOM() * 8 + 8) || ' hours')::INTERVAL
    + (FLOOR(RANDOM() * 60) || ' minutes')::INTERVAL
WHERE sale_timestamp IS NULL;

-- Verificar la actualización
SELECT 
    sale_id,
    sale_date,
    sale_timestamp,
    EXTRACT(HOUR FROM sale_timestamp) AS hora_venta
FROM sales
LIMIT 10;
```

<br/>

5. Crea un índice para optimizar las consultas temporales que ejecutaremos:

```sql
-- Índice en sale_date para consultas de rango temporal
CREATE INDEX IF NOT EXISTS idx_sales_sale_date 
ON sales (sale_date);

-- Índice en sale_timestamp para análisis intradiario
CREATE INDEX IF NOT EXISTS idx_sales_sale_timestamp 
ON sales (sale_timestamp);

-- Verificar índices creados
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'sales' 
  AND indexname LIKE 'idx_sales%';
```

**Salida Esperada:**

```
         indexname          |                    indexdef
----------------------------+------------------------------------------------
 idx_sales_sale_date        | CREATE INDEX idx_sales_sale_date ON public.sales USING btree (sale_date)
 idx_sales_sale_timestamp   | CREATE INDEX idx_sales_sale_timestamp ON public.sales USING btree (sale_timestamp)
```

<br/>

**Verificación:**

- Confirma que `sale_date` existe y tiene tipo `DATE` o `TIMESTAMP`
- Confirma que `sale_timestamp` fue creado y poblado correctamente
- Verifica que los dos índices aparecen en el resultado final

<br/>
<br/>

### Paso 2: Agrupaciones Temporales con DATE_TRUNC()

1. Comprende la sintaxis y comportamiento de `DATE_TRUNC()`:

```sql
-- Demostración de DATE_TRUNC con diferentes precisiones
SELECT 
    NOW()                                    AS timestamp_actual,
    DATE_TRUNC('year',   NOW())              AS inicio_anio,
    DATE_TRUNC('quarter',NOW())              AS inicio_trimestre,
    DATE_TRUNC('month',  NOW())              AS inicio_mes,
    DATE_TRUNC('week',   NOW())              AS inicio_semana,
    DATE_TRUNC('day',    NOW())              AS inicio_dia,
    DATE_TRUNC('hour',   NOW())              AS inicio_hora;
```

<br/>

2. Agrega ventas totales por mes:

```sql
-- Ventas mensuales: total de ingresos y número de transacciones
SELECT 
    DATE_TRUNC('month', sale_date)::DATE    AS mes,
    COUNT(*)                                AS num_transacciones,
    SUM(total_amount)                       AS ingresos_totales,
    ROUND(AVG(total_amount), 2)             AS ticket_promedio,
    COUNT(DISTINCT customer_id)             AS clientes_unicos
FROM sales
GROUP BY DATE_TRUNC('month', sale_date)
ORDER BY mes;
```

<br/>

3. Agrega ventas por trimestre y compara con el año anterior:

```sql
-- Ventas trimestrales con etiqueta legible
SELECT 
    DATE_TRUNC('quarter', sale_date)::DATE  AS inicio_trimestre,
    EXTRACT(YEAR FROM sale_date)            AS anio,
    'Q' || EXTRACT(QUARTER FROM sale_date)  AS trimestre,
    COUNT(*)                                AS transacciones,
    ROUND(SUM(total_amount), 2)             AS ingresos
FROM sales
GROUP BY 
    DATE_TRUNC('quarter', sale_date),
    EXTRACT(YEAR FROM sale_date),
    EXTRACT(QUARTER FROM sale_date)
ORDER BY inicio_trimestre;
```

<br/>

4. Analiza la distribución de ventas por día de la semana (análisis estacional semanal):

```sql
-- Ventas por día de la semana (0=Domingo, 6=Sábado en PostgreSQL)
SELECT 
    EXTRACT(DOW FROM sale_date)             AS num_dia_semana,
    TO_CHAR(sale_date, 'Day')               AS nombre_dia,
    COUNT(*)                                AS num_ventas,
    ROUND(SUM(total_amount), 2)             AS ingresos_totales,
    ROUND(AVG(total_amount), 2)             AS ingreso_promedio
FROM sales
GROUP BY 
    EXTRACT(DOW FROM sale_date),
    TO_CHAR(sale_date, 'Day')
ORDER BY num_dia_semana;
```

<br/>

5. Analiza la distribución de ventas por hora del día:

```sql
-- Distribución de ventas por hora del día
SELECT 
    EXTRACT(HOUR FROM sale_timestamp)       AS hora_del_dia,
    COUNT(*)                                AS num_ventas,
    ROUND(SUM(total_amount), 2)             AS ingresos,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_del_total
FROM sales
WHERE sale_timestamp IS NOT NULL
GROUP BY EXTRACT(HOUR FROM sale_timestamp)
ORDER BY hora_del_dia;
```

<br/>

**Salida Esperada (ejemplo para ventas por mes):**

```
    mes     | num_transacciones | ingresos_totales | ticket_promedio | clientes_unicos
------------+-------------------+------------------+-----------------+-----------------
 2022-01-01 |              1842 |        184320.50 |          100.06 |             412
 2022-02-01 |              1654 |        165240.75 |           99.90 |             389
 2022-03-01 |              1923 |        192300.00 |          100.00 |             445
 ...
```

<br/>

**Verificación:**

- La consulta de ventas mensuales debe retornar una fila por cada mes con datos
- La distribución por día de semana debe mostrar 7 filas (0 al 6)
- La distribución horaria debe mostrar las horas del rango 8-17 (según los timestamps generados)

<br/>
<br/>

### Paso 3: Extracción de Componentes con EXTRACT() y Análisis Estacional

1. Explora los principales campos disponibles con `EXTRACT()`:

```sql
-- Demostración de campos EXTRACT disponibles
SELECT 
    sale_date,
    EXTRACT(YEAR    FROM sale_date)  AS anio,
    EXTRACT(QUARTER FROM sale_date)  AS trimestre,
    EXTRACT(MONTH   FROM sale_date)  AS mes_num,
    TO_CHAR(sale_date, 'Month')      AS mes_nombre,
    EXTRACT(WEEK    FROM sale_date)  AS semana_iso,
    EXTRACT(DOY     FROM sale_date)  AS dia_del_anio,
    EXTRACT(DOW     FROM sale_date)  AS dia_semana,
    EXTRACT(EPOCH   FROM sale_date)  AS epoch_segundos
FROM sales
LIMIT 5;
```

<br/>

2. Construye una tabla pivot de ventas por mes y año (análisis de estacionalidad):

```sql
-- Pivot: ventas por mes (filas) y año (columnas)
SELECT 
    EXTRACT(MONTH FROM sale_date)::INT          AS mes_num,
    TO_CHAR(DATE_TRUNC('month', sale_date), 'Mon') AS mes,
    SUM(CASE WHEN EXTRACT(YEAR FROM sale_date) = 2022 
             THEN total_amount ELSE 0 END)      AS ventas_2022,
    SUM(CASE WHEN EXTRACT(YEAR FROM sale_date) = 2023 
             THEN total_amount ELSE 0 END)      AS ventas_2023,
    SUM(CASE WHEN EXTRACT(YEAR FROM sale_date) = 2024 
             THEN total_amount ELSE 0 END)      AS ventas_2024
FROM sales
GROUP BY 
    EXTRACT(MONTH FROM sale_date),
    TO_CHAR(DATE_TRUNC('month', sale_date), 'Mon')
ORDER BY mes_num;
```

<br/>

3. Identifica los días festivos o de mayor venta usando percentiles:

```sql
-- Top 10 días con mayores ventas y su posición en el año
SELECT 
    sale_date,
    TO_CHAR(sale_date, 'Day DD Mon YYYY')       AS fecha_legible,
    EXTRACT(DOY FROM sale_date)                 AS dia_del_anio,
    EXTRACT(WEEK FROM sale_date)                AS semana,
    COUNT(*)                                    AS num_transacciones,
    ROUND(SUM(total_amount), 2)                 AS ingresos_del_dia
FROM sales
GROUP BY sale_date
ORDER BY ingresos_del_dia DESC
LIMIT 10;
```

<br/>

4. Calcula el tiempo transcurrido desde la primera venta usando `AGE()` e `INTERVAL`:

```sql
-- Antigüedad de ventas y cálculos con INTERVAL
SELECT 
    sale_date,
    total_amount,
    AGE(CURRENT_DATE, sale_date)                AS tiempo_transcurrido,
    CURRENT_DATE - sale_date                    AS dias_transcurridos,
    sale_date + INTERVAL '30 days'              AS fecha_30_dias_despues,
    sale_date + INTERVAL '1 year'               AS mismo_dia_anio_siguiente,
    DATE_TRUNC('month', sale_date) 
        + INTERVAL '1 month' - INTERVAL '1 day' AS ultimo_dia_del_mes
FROM sales
ORDER BY sale_date DESC
LIMIT 10;
```

<br/>

5. Filtra ventas usando rangos con `INTERVAL` y `BETWEEN`:

```sql
-- Ventas de los últimos 90 días (relativo al máximo del dataset)
WITH fecha_referencia AS (
    SELECT MAX(sale_date) AS fecha_max FROM sales
)
SELECT 
    DATE_TRUNC('week', s.sale_date)::DATE       AS semana_inicio,
    COUNT(*)                                    AS ventas_semana,
    ROUND(SUM(s.total_amount), 2)               AS ingresos_semana
FROM sales s
CROSS JOIN fecha_referencia fr
WHERE s.sale_date BETWEEN fr.fecha_max - INTERVAL '90 days' 
                      AND fr.fecha_max
GROUP BY DATE_TRUNC('week', s.sale_date)
ORDER BY semana_inicio;
```

<br/>

**Salida Esperada (ejemplo pivot):**

```
 mes_num | mes | ventas_2022  | ventas_2023  | ventas_2024
---------+-----+--------------+--------------+-------------
       1 | Jan | 184320.50    | 201540.75    | 215320.00
       2 | Feb | 165240.75    | 178920.50    | 189450.25
       3 | Mar | 192300.00    | 209870.00    | 221340.50
      ...
```

<br/>

**Verificación:**

- El pivot debe mostrar 12 filas (una por mes) con columnas por año
- Los cálculos con `AGE()` deben retornar intervalos en formato `X years X mons X days`
- La consulta de últimos 90 días debe retornar aproximadamente 13 semanas

<br/>
<br/>

### Paso 4: Comparaciones Year-over-Year (YoY) y Month-over-Month (MoM) con LAG()


1. Construye la comparación Month-over-Month (MoM) con `LAG()`:

```sql
-- Comparación Month-over-Month (MoM)
WITH ventas_mensuales AS (
    SELECT 
        DATE_TRUNC('month', sale_date)::DATE    AS mes,
        COUNT(*)                                AS num_ventas,
        ROUND(SUM(total_amount), 2)             AS ingresos
    FROM sales
    GROUP BY DATE_TRUNC('month', sale_date)
)
SELECT 
    mes,
    num_ventas,
    ingresos,
    LAG(ingresos) OVER (ORDER BY mes)           AS ingresos_mes_anterior,
    ROUND(
        ingresos - LAG(ingresos) OVER (ORDER BY mes), 
        2
    )                                           AS diferencia_mom,
    ROUND(
        100.0 * (ingresos - LAG(ingresos) OVER (ORDER BY mes)) 
             / NULLIF(LAG(ingresos) OVER (ORDER BY mes), 0),
        2
    )                                           AS pct_cambio_mom
FROM ventas_mensuales
ORDER BY mes;
```

<br/>

2. Construye la comparación Year-over-Year (YoY) usando `DATE_TRUNC` con desplazamiento de 12 meses:

```sql
-- Comparación Year-over-Year (YoY) por mes
WITH ventas_mensuales AS (
    SELECT 
        DATE_TRUNC('month', sale_date)::DATE    AS mes,
        EXTRACT(YEAR FROM sale_date)::INT        AS anio,
        EXTRACT(MONTH FROM sale_date)::INT       AS mes_num,
        ROUND(SUM(total_amount), 2)             AS ingresos
    FROM sales
    GROUP BY 
        DATE_TRUNC('month', sale_date),
        EXTRACT(YEAR FROM sale_date),
        EXTRACT(MONTH FROM sale_date)
),
ventas_con_lag AS (
    SELECT 
        mes,
        anio,
        mes_num,
        ingresos,
        LAG(ingresos, 12) OVER (ORDER BY mes)   AS ingresos_mismo_mes_anio_anterior
    FROM ventas_mensuales
)
SELECT 
    mes,
    anio,
    mes_num,
    ingresos                                    AS ingresos_actual,
    ingresos_mismo_mes_anio_anterior,
    ROUND(
        ingresos - ingresos_mismo_mes_anio_anterior,
        2
    )                                           AS diferencia_yoy,
    ROUND(
        100.0 * (ingresos - ingresos_mismo_mes_anio_anterior)
             / NULLIF(ingresos_mismo_mes_anio_anterior, 0),
        2
    )                                           AS pct_cambio_yoy
FROM ventas_con_lag
WHERE ingresos_mismo_mes_anio_anterior IS NOT NULL
ORDER BY mes;
```

<br/>

3. Calcula el acumulado del año (Year-to-Date, YTD) con suma acumulativa:

```sql
-- Year-to-Date (YTD): acumulado de ventas en el año en curso
WITH ventas_diarias AS (
    SELECT 
        sale_date,
        EXTRACT(YEAR FROM sale_date)::INT        AS anio,
        EXTRACT(DOY FROM sale_date)::INT         AS dia_del_anio,
        ROUND(SUM(total_amount), 2)             AS ingresos_dia
    FROM sales
    GROUP BY sale_date, EXTRACT(YEAR FROM sale_date), EXTRACT(DOY FROM sale_date)
)
SELECT 
    sale_date,
    anio,
    dia_del_anio,
    ingresos_dia,
    SUM(ingresos_dia) OVER (
        PARTITION BY anio 
        ORDER BY sale_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                           AS ytd_acumulado,
    ROUND(AVG(ingresos_dia) OVER (
        PARTITION BY anio 
        ORDER BY sale_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2)                                       AS promedio_movil_7dias
FROM ventas_diarias
ORDER BY sale_date DESC
LIMIT 30;
```

<br/>

4. Crea una vista materializada para reutilizar las métricas YoY:

```sql
-- Vista para métricas temporales reutilizables
CREATE OR REPLACE VIEW v_metricas_temporales AS
WITH ventas_mensuales AS (
    SELECT 
        DATE_TRUNC('month', sale_date)::DATE    AS mes,
        EXTRACT(YEAR FROM sale_date)::INT        AS anio,
        EXTRACT(MONTH FROM sale_date)::INT       AS mes_num,
        COUNT(*)                                AS num_ventas,
        ROUND(SUM(total_amount), 2)             AS ingresos,
        COUNT(DISTINCT customer_id)             AS clientes_activos
    FROM sales
    GROUP BY 
        DATE_TRUNC('month', sale_date),
        EXTRACT(YEAR FROM sale_date),
        EXTRACT(MONTH FROM sale_date)
)
SELECT 
    mes,
    anio,
    mes_num,
    num_ventas,
    ingresos,
    clientes_activos,
    LAG(ingresos)     OVER (ORDER BY mes)       AS ingresos_mes_anterior,
    LAG(ingresos, 12) OVER (ORDER BY mes)       AS ingresos_mismo_mes_anio_ant,
    ROUND(100.0 * (ingresos - LAG(ingresos) OVER (ORDER BY mes))
         / NULLIF(LAG(ingresos) OVER (ORDER BY mes), 0), 2) AS pct_mom,
    ROUND(100.0 * (ingresos - LAG(ingresos, 12) OVER (ORDER BY mes))
         / NULLIF(LAG(ingresos, 12) OVER (ORDER BY mes), 0), 2) AS pct_yoy
FROM ventas_mensuales;

-- Verificar la vista
SELECT * FROM v_metricas_temporales ORDER BY mes DESC LIMIT 6;
```
<br/>

**Salida Esperada:**

```
    mes     | anio | mes_num | num_ventas | ingresos  | pct_mom | pct_yoy
------------+------+---------+------------+-----------+---------+---------
 2024-03-01 | 2024 |       3 |       1923 | 192300.00 |    4.52 |    6.78
 2024-02-01 | 2024 |       2 |       1654 | 183940.75 |   -4.85 |    5.12
 2024-01-01 | 2024 |       1 |       1842 | 193420.50 |    2.34 |    7.23
 ...
```

<br/>

**Verificación:**

- La comparación MoM debe mostrar `NULL` en el primer mes del dataset (no hay mes anterior)
- La comparación YoY debe mostrar `NULL` en los primeros 12 meses del dataset
- El YTD acumulado debe reiniciarse a 0 al inicio de cada año
- La vista `v_metricas_temporales` debe ser consultable sin errores

<br/>
<br/>

### Paso 5: Detección de Gaps con generate_series()

1. Comprende el funcionamiento de `generate_series()` con fechas:

```sql
-- generate_series básico con fechas
SELECT 
    generate_series::DATE                       AS fecha,
    TO_CHAR(generate_series, 'Day')             AS dia_semana,
    EXTRACT(DOW FROM generate_series)           AS num_dia
FROM generate_series(
    '2024-01-01'::DATE,
    '2024-01-15'::DATE,
    '1 day'::INTERVAL
);
```

<br/>

2. Genera el calendario completo del período del dataset:

```sql
-- Calendario completo del período del dataset
WITH rango_fechas AS (
    SELECT 
        MIN(sale_date) AS fecha_inicio,
        MAX(sale_date) AS fecha_fin
    FROM sales
),
calendario AS (
    SELECT generate_series::DATE AS fecha_calendario
    FROM rango_fechas,
         generate_series(fecha_inicio, fecha_fin, '1 day'::INTERVAL)
)
SELECT 
    c.fecha_calendario,
    TO_CHAR(c.fecha_calendario, 'Day')          AS dia_semana,
    EXTRACT(DOW FROM c.fecha_calendario)        AS num_dia,
    COALESCE(v.num_ventas, 0)                   AS num_ventas,
    COALESCE(v.ingresos, 0)                     AS ingresos,
    CASE WHEN v.num_ventas IS NULL THEN 'SIN VENTAS' 
         ELSE 'CON VENTAS' END                  AS estado
FROM calendario c
LEFT JOIN (
    SELECT 
        sale_date,
        COUNT(*)                                AS num_ventas,
        ROUND(SUM(total_amount), 2)             AS ingresos
    FROM sales
    GROUP BY sale_date
) v ON c.fecha_calendario = v.sale_date
ORDER BY c.fecha_calendario;
```

<br/>

3. Identifica y cuenta los días sin ventas por mes:

```sql
-- Resumen de gaps por mes
WITH rango_fechas AS (
    SELECT MIN(sale_date) AS fecha_inicio, MAX(sale_date) AS fecha_fin
    FROM sales
),
calendario AS (
    SELECT generate_series::DATE AS fecha
    FROM rango_fechas,
         generate_series(fecha_inicio, fecha_fin, '1 day'::INTERVAL)
),
ventas_diarias AS (
    SELECT sale_date, COUNT(*) AS num_ventas
    FROM sales
    GROUP BY sale_date
)
SELECT 
    DATE_TRUNC('month', c.fecha)::DATE          AS mes,
    COUNT(*)                                    AS dias_en_mes,
    COUNT(v.sale_date)                          AS dias_con_ventas,
    COUNT(*) - COUNT(v.sale_date)               AS dias_sin_ventas,
    ROUND(
        100.0 * COUNT(v.sale_date) / COUNT(*), 
        1
    )                                           AS pct_cobertura
FROM calendario c
LEFT JOIN ventas_diarias v ON c.fecha = v.sale_date
GROUP BY DATE_TRUNC('month', c.fecha)
ORDER BY mes;
```

<br/>

4. Detecta gaps consecutivos (rachas de días sin ventas):

```sql
-- Detectar rachas de días consecutivos sin ventas
WITH rango_fechas AS (
    SELECT MIN(sale_date) AS fecha_inicio, MAX(sale_date) AS fecha_fin
    FROM sales
),
calendario AS (
    SELECT generate_series::DATE AS fecha
    FROM rango_fechas,
         generate_series(fecha_inicio, fecha_fin, '1 day'::INTERVAL)
),
dias_sin_ventas AS (
    SELECT c.fecha
    FROM calendario c
    LEFT JOIN sales s ON c.fecha = s.sale_date
    WHERE s.sale_id IS NULL
),
grupos AS (
    SELECT 
        fecha,
        fecha - ROW_NUMBER() OVER (ORDER BY fecha) * INTERVAL '1 day' AS grupo_id
    FROM dias_sin_ventas
)
SELECT 
    MIN(fecha)                                  AS inicio_gap,
    MAX(fecha)                                  AS fin_gap,
    COUNT(*)                                    AS dias_consecutivos
FROM grupos
GROUP BY grupo_id
HAVING COUNT(*) >= 2
ORDER BY dias_consecutivos DESC
LIMIT 10;
```

<br/>

5. Genera una serie horaria para análisis intradiario de un día específico:

```sql
-- Serie horaria: completar horas sin ventas en un día específico
WITH dia_analisis AS (
    SELECT MAX(sale_date) - INTERVAL '1 day' AS dia_objetivo
    FROM sales
),
horas_del_dia AS (
    SELECT 
        (d.dia_objetivo + (h || ' hours')::INTERVAL)::TIMESTAMPTZ AS hora_inicio
    FROM dia_analisis d,
         generate_series(0, 23, 1) AS h
),
ventas_por_hora AS (
    SELECT 
        DATE_TRUNC('hour', sale_timestamp)      AS hora,
        COUNT(*)                                AS ventas,
        ROUND(SUM(total_amount), 2)             AS ingresos
    FROM sales, dia_analisis
    WHERE DATE_TRUNC('day', sale_timestamp) = dia_analisis.dia_objetivo
    GROUP BY DATE_TRUNC('hour', sale_timestamp)
)
SELECT 
    h.hora_inicio,
    EXTRACT(HOUR FROM h.hora_inicio)            AS hora,
    COALESCE(v.ventas, 0)                       AS ventas,
    COALESCE(v.ingresos, 0.00)                  AS ingresos
FROM horas_del_dia h
LEFT JOIN ventas_por_hora v ON h.hora_inicio = v.hora
ORDER BY h.hora_inicio;
```

<br/>

**Salida Esperada (resumen de gaps por mes):**

```
    mes     | dias_en_mes | dias_con_ventas | dias_sin_ventas | pct_cobertura
------------+-------------+-----------------+-----------------+---------------
 2022-01-01 |          31 |              28 |               3 |          90.3
 2022-02-01 |          28 |              26 |               2 |          92.9
 ...
```

<br/>

**Verificación:**

- El calendario completo debe cubrir exactamente el rango `MIN(sale_date)` a `MAX(sale_date)`
- La suma de `dias_con_ventas + dias_sin_ventas` debe igualar `dias_en_mes` para cada mes
- Los gaps consecutivos deben corresponder típicamente a fines de semana o días festivos

<br/>
<br/>

### Paso 6: Análisis de Cohortes de Clientes

1. Identifica la fecha de primera compra de cada cliente (definición de cohorte):

```sql
-- Primera compra por cliente (definición de cohorte)
SELECT 
    customer_id,
    MIN(sale_date)                              AS primera_compra,
    DATE_TRUNC('month', MIN(sale_date))::DATE   AS mes_cohorte,
    COUNT(*)                                    AS total_compras,
    MAX(sale_date)                              AS ultima_compra,
    MAX(sale_date) - MIN(sale_date)             AS vida_cliente_dias
FROM sales
GROUP BY customer_id
ORDER BY primera_compra
LIMIT 20;
```

<br/>

2. Construye la tabla base de cohortes con meses de actividad:

```sql
-- Tabla base de cohortes
WITH primera_compra AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(sale_date))::DATE AS mes_cohorte
    FROM sales
    GROUP BY customer_id
),
actividad_mensual AS (
    SELECT 
        s.customer_id,
        DATE_TRUNC('month', s.sale_date)::DATE  AS mes_actividad
    FROM sales s
    GROUP BY s.customer_id, DATE_TRUNC('month', s.sale_date)
)
SELECT 
    p.mes_cohorte,
    a.mes_actividad,
    -- Número de meses desde la primera compra (período de retención)
    EXTRACT(YEAR FROM AGE(a.mes_actividad, p.mes_cohorte)) * 12
    + EXTRACT(MONTH FROM AGE(a.mes_actividad, p.mes_cohorte)) AS periodo_retencion,
    COUNT(DISTINCT a.customer_id)               AS clientes_activos
FROM primera_compra p
JOIN actividad_mensual a USING (customer_id)
GROUP BY p.mes_cohorte, a.mes_actividad
ORDER BY p.mes_cohorte, a.mes_actividad
LIMIT 30;
```

<br/>

3. Construye la matriz de retención completa:

```sql
-- Matriz de retención de cohortes
WITH primera_compra AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(sale_date))::DATE AS mes_cohorte
    FROM sales
    GROUP BY customer_id
),
actividad_mensual AS (
    SELECT 
        s.customer_id,
        DATE_TRUNC('month', s.sale_date)::DATE  AS mes_actividad
    FROM sales s
    GROUP BY s.customer_id, DATE_TRUNC('month', s.sale_date)
),
cohorte_base AS (
    SELECT 
        p.mes_cohorte,
        EXTRACT(YEAR FROM AGE(a.mes_actividad, p.mes_cohorte)) * 12
        + EXTRACT(MONTH FROM AGE(a.mes_actividad, p.mes_cohorte)) AS periodo,
        COUNT(DISTINCT a.customer_id)           AS clientes_periodo
    FROM primera_compra p
    JOIN actividad_mensual a USING (customer_id)
    GROUP BY p.mes_cohorte, periodo
),
tamano_cohorte AS (
    SELECT mes_cohorte, clientes_periodo AS total_cohorte
    FROM cohorte_base
    WHERE periodo = 0
)
SELECT 
    cb.mes_cohorte,
    tc.total_cohorte,
    cb.periodo                                  AS mes_retencion,
    cb.clientes_periodo,
    ROUND(
        100.0 * cb.clientes_periodo / tc.total_cohorte, 
        1
    )                                           AS tasa_retencion_pct
FROM cohorte_base cb
JOIN tamano_cohorte tc USING (mes_cohorte)
WHERE cb.mes_cohorte >= (SELECT MIN(mes_cohorte) FROM tamano_cohorte)
ORDER BY cb.mes_cohorte, cb.periodo
LIMIT 50;
```

<br/>

4. Pivot de la matriz de retención (primeros 6 meses):

```sql
-- Pivot: tasa de retención por cohorte (meses 0 al 5)
WITH primera_compra AS (
    SELECT customer_id,
           DATE_TRUNC('month', MIN(sale_date))::DATE AS mes_cohorte
    FROM sales GROUP BY customer_id
),
actividad AS (
    SELECT customer_id,
           DATE_TRUNC('month', sale_date)::DATE AS mes_actividad
    FROM sales GROUP BY customer_id, DATE_TRUNC('month', sale_date)
),
cohorte AS (
    SELECT 
        p.mes_cohorte,
        EXTRACT(YEAR FROM AGE(a.mes_actividad, p.mes_cohorte)) * 12
        + EXTRACT(MONTH FROM AGE(a.mes_actividad, p.mes_cohorte)) AS periodo,
        COUNT(DISTINCT a.customer_id) AS cnt
    FROM primera_compra p JOIN actividad a USING (customer_id)
    GROUP BY p.mes_cohorte, periodo
),
base AS (
    SELECT mes_cohorte, cnt AS total FROM cohorte WHERE periodo = 0
)
SELECT 
    c.mes_cohorte,
    b.total                                     AS tamano_cohorte,
    ROUND(100.0 * MAX(CASE WHEN periodo = 0 THEN cnt END) / b.total, 1) AS "Mes_0",
    ROUND(100.0 * MAX(CASE WHEN periodo = 1 THEN cnt END) / b.total, 1) AS "Mes_1",
    ROUND(100.0 * MAX(CASE WHEN periodo = 2 THEN cnt END) / b.total, 1) AS "Mes_2",
    ROUND(100.0 * MAX(CASE WHEN periodo = 3 THEN cnt END) / b.total, 1) AS "Mes_3",
    ROUND(100.0 * MAX(CASE WHEN periodo = 4 THEN cnt END) / b.total, 1) AS "Mes_4",
    ROUND(100.0 * MAX(CASE WHEN periodo = 5 THEN cnt END) / b.total, 1) AS "Mes_5"
FROM cohorte c
JOIN base b USING (mes_cohorte)
GROUP BY c.mes_cohorte, b.total
ORDER BY c.mes_cohorte
LIMIT 12;
```

<br/>

5. Guarda la vista de cohortes para uso posterior:

```sql
-- Vista de análisis de cohortes
CREATE OR REPLACE VIEW v_analisis_cohortes AS
WITH primera_compra AS (
    SELECT customer_id,
           DATE_TRUNC('month', MIN(sale_date))::DATE AS mes_cohorte
    FROM sales GROUP BY customer_id
),
actividad AS (
    SELECT customer_id,
           DATE_TRUNC('month', sale_date)::DATE AS mes_actividad
    FROM sales GROUP BY customer_id, DATE_TRUNC('month', sale_date)
),
cohorte AS (
    SELECT 
        p.mes_cohorte,
        EXTRACT(YEAR FROM AGE(a.mes_actividad, p.mes_cohorte)) * 12
        + EXTRACT(MONTH FROM AGE(a.mes_actividad, p.mes_cohorte)) AS periodo_meses,
        COUNT(DISTINCT a.customer_id) AS clientes_activos
    FROM primera_compra p JOIN actividad a USING (customer_id)
    GROUP BY p.mes_cohorte, periodo_meses
),
base AS (
    SELECT mes_cohorte, clientes_activos AS total_cohorte
    FROM cohorte WHERE periodo_meses = 0
)
SELECT 
    c.mes_cohorte,
    b.total_cohorte,
    c.periodo_meses,
    c.clientes_activos,
    ROUND(100.0 * c.clientes_activos / b.total_cohorte, 2) AS tasa_retencion
FROM cohorte c
JOIN base b USING (mes_cohorte);

-- Verificar la vista
SELECT * FROM v_analisis_cohortes WHERE periodo_meses <= 3 ORDER BY mes_cohorte LIMIT 20;
```

<br/>

**Salida Esperada (pivot de retención):**

```
 mes_cohorte | tamano_cohorte | Mes_0 | Mes_1 | Mes_2 | Mes_3 | Mes_4 | Mes_5
-------------+----------------+-------+-------+-------+-------+-------+-------
 2022-01-01  |            145 | 100.0 |  42.1 |  28.3 |  21.4 |  18.6 |  15.2
 2022-02-01  |            132 | 100.0 |  38.6 |  25.0 |  19.7 |  16.7 |  13.6
 ...
```

<br/>

**Verificación:**

- El período 0 siempre debe mostrar 100.0% de retención (todos los clientes de la cohorte)
- La tasa de retención debe decrecer monotónicamente a lo largo de los períodos
- La vista `v_analisis_cohortes` debe ser consultable correctamente

<br/>
<br/>

### Paso 7: Introducción a TimescaleDB


1. Descarga y ejecuta el contenedor TimescaleDB en el puerto 5433 (paralelo al PostgreSQL existente):

```bash
# Descargar imagen TimescaleDB para PostgreSQL 16
docker pull timescale/timescaledb-ha:pg16

# Ejecutar contenedor TimescaleDB en puerto 5433
docker run -d \
  --name timescaledb_lab \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -e curso_postgres=tsdb \
  -p 5433:5432 \
  -v timescaledb_data:/home/postgres/pgdata/data \
  timescale/timescaledb-ha:pg16

# Verificar que el contenedor está ejecutándose
docker ps --filter "name=timescaledb_lab"
```

> **Nota para Windows:** Si usas PowerShell, reemplaza los `\` al final de cada línea por `` ` `` (backtick) para la continuación de línea. En CMD usa `^`.

<br/>

2. Conéctate al contenedor TimescaleDB y verifica la extensión disponible:

```bash
# Conectarse al contenedor TimescaleDB
docker exec -it timescaledb_lab psql -U postgres -d tsdb

# Verificar extensiones disponibles (dentro de psql)
\dx
```

```sql
-- Verificar que TimescaleDB está disponible
SELECT name, default_version, installed_version
FROM pg_available_extensions
WHERE name = 'timescaledb';

```

<br/>

3. Instala la extensión TimescaleDB y crea la estructura de datos:

```sql
-- Instalar extensión TimescaleDB
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Confirmar instalación
\dx timescaledb

-- Crear tabla de métricas de ventas para TimescaleDB
CREATE TABLE ventas_metricas (
    tiempo           TIMESTAMPTZ        NOT NULL,
    producto_id      INTEGER            NOT NULL,
    categoria        VARCHAR(100),
    region           VARCHAR(50),
    cantidad         INTEGER            NOT NULL DEFAULT 1,
    monto            NUMERIC(12, 2)     NOT NULL,
    costo            NUMERIC(12, 2),
    PRIMARY KEY (tiempo, producto_id)
);

-- Convertir a hypertable (particionada por tiempo automáticamente)
SELECT create_hypertable(
    'ventas_metricas',  -- nombre de la tabla
    'tiempo',           -- columna de tiempo
    chunk_time_interval => INTERVAL '1 month'  -- tamaño de cada chunk
);
```

<br/>

4. Carga datos de prueba en la hypertable usando `generate_series()`:

```sql
-- Insertar datos de prueba en la hypertable
INSERT INTO ventas_metricas (tiempo, producto_id, categoria, region, cantidad, monto, costo)
SELECT 
    -- Serie de timestamps cada 15 minutos durante 6 meses
    ts                                          AS tiempo,
    (RANDOM() * 99 + 1)::INT                    AS producto_id,
    (ARRAY['Electrónica', 'Ropa', 'Alimentos', 'Hogar', 'Deportes'])
        [CEIL(RANDOM() * 5)::INT]               AS categoria,
    (ARRAY['Norte', 'Sur', 'Este', 'Oeste', 'Centro'])
        [CEIL(RANDOM() * 5)::INT]               AS region,
    (RANDOM() * 10 + 1)::INT                    AS cantidad,
    ROUND((RANDOM() * 500 + 10)::NUMERIC, 2)    AS monto,
    ROUND((RANDOM() * 200 + 5)::NUMERIC, 2)     AS costo
FROM generate_series(
    NOW() - INTERVAL '6 months',
    NOW(),
    INTERVAL '15 minutes'
) AS ts;

-- Verificar los datos insertados
SELECT 
    COUNT(*)                                    AS total_registros,
    MIN(tiempo)                                 AS primer_registro,
    MAX(tiempo)                                 AS ultimo_registro
FROM ventas_metricas;
```

<br/>

5. Ejecuta consultas usando `time_bucket()` (función característica de TimescaleDB):

```sql
-- time_bucket: agrupa timestamps en intervalos regulares (similar a DATE_TRUNC pero más flexible)
-- Ventas por hora
SELECT 
    time_bucket('1 hour', tiempo)               AS bucket_hora,
    COUNT(*)                                    AS num_transacciones,
    ROUND(SUM(monto), 2)                        AS ingresos,
    ROUND(AVG(monto), 2)                        AS monto_promedio
FROM ventas_metricas
WHERE tiempo >= NOW() - INTERVAL '7 days'
GROUP BY bucket_hora
ORDER BY bucket_hora DESC
LIMIT 24;
```
<br/>

```sql
-- Ventas por día con time_bucket (intervalo de 1 día)
SELECT 
    time_bucket('1 day', tiempo)::DATE          AS dia,
    categoria,
    COUNT(*)                                    AS ventas,
    ROUND(SUM(monto), 2)                        AS ingresos_totales
FROM ventas_metricas
WHERE tiempo >= NOW() - INTERVAL '30 days'
GROUP BY time_bucket('1 day', tiempo), categoria
ORDER BY dia DESC, ingresos_totales DESC
LIMIT 20;
```

<br/>

```sql
-- Ventas por semana con time_bucket (intervalo de 7 días)
SELECT 
    time_bucket('7 days', tiempo)               AS semana,
    region,
    SUM(cantidad)                               AS unidades_vendidas,
    ROUND(SUM(monto), 2)                        AS ingresos,
    ROUND(SUM(monto - costo), 2)                AS margen_bruto
FROM ventas_metricas
GROUP BY time_bucket('7 days', tiempo), region
ORDER BY semana DESC, ingresos DESC;
```

<br/>

6. Explora las características de la hypertable:

```sql
-- Ver los chunks creados por TimescaleDB
SELECT 
    chunk_name,
    range_start::DATE,
    range_end::DATE,
    pg_size_pretty(total_bytes) AS tamanio
FROM timescaledb_information.chunks
WHERE hypertable_name = 'ventas_metricas'
ORDER BY range_start;

-- Ver información de la hypertable
SELECT * FROM timescaledb_information.hypertables
WHERE hypertable_name = 'ventas_metricas';
```

<br/>

7. Compara `time_bucket()` vs `DATE_TRUNC()` para entender la diferencia:

```sql
-- Comparación: time_bucket permite intervalos no estándar
-- DATE_TRUNC solo soporta unidades estándar (hora, día, semana, mes, etc.)
-- time_bucket permite intervalos como '3 hours', '15 minutes', '2 weeks'

SELECT 
    time_bucket('3 hours', tiempo)              AS bucket_3h,
    time_bucket('15 minutes', tiempo)           AS bucket_15min,
    DATE_TRUNC('hour', tiempo)                  AS trunc_hora,
    COUNT(*)                                    AS registros
FROM ventas_metricas
WHERE tiempo >= NOW() - INTERVAL '1 day'
GROUP BY 
    time_bucket('3 hours', tiempo),
    time_bucket('15 minutes', tiempo),
    DATE_TRUNC('hour', tiempo)
ORDER BY bucket_3h
LIMIT 10;
```

**Salida Esperada:**

```
-- Chunks de la hypertable
     chunk_name      | range_start | range_end  | tamanio
---------------------+-------------+------------+---------
 _hyper_1_1_chunk    | 2024-07-01  | 2024-08-01 | 1024 kB
 _hyper_1_2_chunk    | 2024-08-01  | 2024-09-01 | 1024 kB
 _hyper_1_3_chunk    | 2024-09-01  | 2024-10-01 | 1024 kB
 ...
```

<br/>

**Verificación:**

- El contenedor `timescaledb_lab` debe estar en estado `Up` en `docker ps`
- La extensión TimescaleDB debe aparecer en `\dx` con estado instalado
- La hypertable debe tener al menos 6 chunks (uno por mes de datos)
- Las consultas con `time_bucket()` deben retornar resultados correctamente

<br/>
<br/>

## Validación y Pruebas

### Criterios de Éxito

- [ ] La tabla `sales` tiene columna `sale_timestamp` de tipo `TIMESTAMPTZ` correctamente poblada
- [ ] Los índices `idx_sales_sale_date` e `idx_sales_sale_timestamp` existen en la tabla `sales`
- [ ] La vista `v_metricas_temporales` retorna datos con columnas `pct_mom` y `pct_yoy`
- [ ] La consulta de gaps detecta correctamente los días sin ventas usando `generate_series()`
- [ ] La vista `v_analisis_cohortes` retorna 100.0% de retención en el período 0 para todas las cohortes
- [ ] El contenedor `timescaledb_lab` está ejecutándose en el puerto 5433
- [ ] La hypertable `ventas_metricas` tiene al menos 6 chunks creados automáticamente
- [ ] Las consultas con `time_bucket()` retornan resultados sin errores

<br/>

### Procedimiento de Pruebas

1. Verifica los objetos creados en `ventas_db`:

```sql
-- Ejecutar en ventas_db (puerto 5432)
SELECT 
    'sale_timestamp existe' AS prueba,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sales' AND column_name = 'sale_timestamp'
    ) THEN 'PASS' ELSE 'FAIL' END AS resultado
UNION ALL
SELECT 
    'índice sale_date existe',
    CASE WHEN EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'sales' AND indexname = 'idx_sales_sale_date'
    ) THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 
    'vista v_metricas_temporales existe',
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'v_metricas_temporales'
    ) THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT 
    'vista v_analisis_cohortes existe',
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'v_analisis_cohortes'
    ) THEN 'PASS' ELSE 'FAIL' END;
```

<br/>

**Resultado Esperado:**

```
               prueba                  | resultado
--------------------------------------+-----------
 sale_timestamp existe                 | PASS
 índice sale_date existe               | PASS
 vista v_metricas_temporales existe    | PASS
 vista v_analisis_cohortes existe      | PASS
```

<br/>

2. Verifica la integridad de la vista de métricas temporales:

```sql
-- Verificar que la vista retorna datos correctos
SELECT 
    COUNT(*) AS total_meses,
    COUNT(pct_mom) AS meses_con_mom,
    COUNT(pct_yoy) AS meses_con_yoy,
    MIN(mes) AS primer_mes,
    MAX(mes) AS ultimo_mes
FROM v_metricas_temporales;
```

<br/>

**Resultado Esperado:**

```
 total_meses | meses_con_mom | meses_con_yoy | primer_mes | ultimo_mes
-------------+---------------+---------------+------------+------------
          36 |            35 |            24 | 2022-01-01 | 2024-12-01
```

<br/>

3. Verifica la integridad del análisis de cohortes:

```sql
-- Verificar que el período 0 siempre es 100%
SELECT 
    COUNT(*) AS cohortes_verificadas,
    MIN(tasa_retencion) AS min_retencion_periodo0,
    MAX(tasa_retencion) AS max_retencion_periodo0
FROM v_analisis_cohortes
WHERE periodo_meses = 0;
```

<br/>

**Resultado Esperado:**

```
 cohortes_verificadas | min_retencion_periodo0 | max_retencion_periodo0
----------------------+------------------------+------------------------
                   36 |                 100.00 |                 100.00
```

<br/>

4. Verifica TimescaleDB desde la línea de comandos:

```bash
# Verificar hypertable y chunks
docker exec -it timescaledb_lab psql -U postgres -d tsdb -c "
SELECT 
    hypertable_name,
    num_chunks,
    pg_size_pretty(total_bytes) AS tamanio_total
FROM timescaledb_information.hypertable_detailed_size('ventas_metricas');
"
```

<br/>

**Resultado Esperado:**

```
 hypertable_name | num_chunks | tamanio_total
-----------------+------------+---------------
 ventas_metricas |          7 | 8192 kB
```

<br/>
<br/>

## Solución de Problemas

### Problema 1: Error al agregar columna sale_timestamp - columna ya existe

**Síntomas:**
- Error: `ERROR: column "sale_timestamp" of relation "sales" already exists`
- El comando `ALTER TABLE` falla al intentar agregar la columna

<br/>

**Causa:**
La práctica fue ejecutada previamente o la columna fue creada manualmente. La cláusula `IF NOT EXISTS` en `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` debería prevenir esto, pero versiones antiguas de PostgreSQL pueden no soportarla.

<br/>

**Solución:**

```sql
-- Verificar si la columna existe antes de agregarla
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'sales' AND column_name = 'sale_timestamp';

-- Si existe pero está vacía, solo poblar los datos
UPDATE sales
SET sale_timestamp = sale_date::TIMESTAMPTZ 
    + (FLOOR(RANDOM() * 8 + 8) || ' hours')::INTERVAL
    + (FLOOR(RANDOM() * 60) || ' minutes')::INTERVAL
WHERE sale_timestamp IS NULL;

-- Si no existe, agregar sin IF NOT EXISTS
ALTER TABLE sales ADD COLUMN sale_timestamp TIMESTAMPTZ;
```

<br/>
<br/>

### Problema 2: La imagen Docker de TimescaleDB no se puede descargar

**Síntomas:**
- Error: `Unable to find image 'timescale/timescaledb-ha:pg16' locally`
- `docker pull` falla con error de conexión o timeout
- Error: `Error response from daemon: pull access denied`

<br/>

**Causa:**
Problemas de conectividad a Docker Hub, firewall corporativo bloqueando el acceso, o límite de rate de Docker Hub para usuarios no autenticados.

<br/>

**Solución:**

```bash
# Opción 1: Autenticarse en Docker Hub antes de descargar
docker login
docker pull timescale/timescaledb-ha:pg16

# Opción 2: Usar imagen alternativa más ligera (sin HA)
docker pull timescale/timescaledb:latest-pg16

# Ejecutar con imagen alternativa
docker run -d \
  --name timescaledb_lab \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -e curso_postgres=tsdb \
  -p 5433:5432 \
  timescale/timescaledb:latest-pg16

# Opción 3: Verificar si la imagen está disponible localmente (pre-descargada)
docker images | grep timescale
```

<br/>
<br/>

### Problema 3: El puerto 5433 ya está en uso

**Síntomas:**
- Error: `Bind for 0.0.0.0:5433 failed: port is already allocated`
- El contenedor TimescaleDB no inicia correctamente
- `docker ps` no muestra el contenedor `timescaledb_lab`

<br/>

**Causa:**
Otro proceso o contenedor está usando el puerto 5433 en el sistema host.

<br/>

**Solución:**

```bash
# Identificar qué proceso usa el puerto 5433
# En Linux/macOS:
sudo lsof -i :5433
sudo netstat -tlnp | grep 5433

# En Windows (PowerShell):
netstat -ano | findstr :5433
Get-Process -Id (Get-NetTCPConnection -LocalPort 5433).OwningProcess

# Usar un puerto alternativo (ej: 5434)
docker run -d \
  --name timescaledb_lab \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -e curso_postgres=tsdb \
  -p 5434:5432 \
  timescale/timescaledb-ha:pg16

# Conectarse usando el nuevo puerto
docker exec -it timescaledb_lab psql -U postgres -d tsdb
```

<br/>
<br/>

### Problema 4: Las comparaciones YoY retornan NULL en todos los registros

**Síntomas:**
- La columna `pct_yoy` muestra `NULL` en todas las filas de la vista `v_metricas_temporales`
- `LAG(ingresos, 12)` retorna `NULL` para todos los registros

<br/>

**Causa:**
El dataset de ventas no tiene suficiente rango temporal. Si los datos cubren menos de 13 meses, `LAG(..., 12)` no tiene un valor 12 posiciones atrás para calcular. También puede ocurrir si hay meses sin datos en el período intermedio.

<br/>

**Solución:**

```sql
-- Verificar el rango temporal del dataset
SELECT 
    MIN(sale_date) AS fecha_inicio,
    MAX(sale_date) AS fecha_fin,
    COUNT(DISTINCT DATE_TRUNC('month', sale_date)) AS meses_con_datos,
    MAX(sale_date) - MIN(sale_date) AS rango_dias
FROM sales;

-- Si el rango es menor a 13 meses, verificar si hay datos para al menos 2 años
-- En ese caso, usar LAG con el número correcto de meses disponibles

-- Alternativa: comparar con mismo mes del año anterior usando JOIN en lugar de LAG
WITH ventas_mensuales AS (
    SELECT 
        DATE_TRUNC('month', sale_date)::DATE AS mes,
        EXTRACT(YEAR FROM sale_date)::INT AS anio,
        EXTRACT(MONTH FROM sale_date)::INT AS mes_num,
        ROUND(SUM(total_amount), 2) AS ingresos
    FROM sales
    GROUP BY DATE_TRUNC('month', sale_date), 
             EXTRACT(YEAR FROM sale_date),
             EXTRACT(MONTH FROM sale_date)
)
SELECT 
    a.mes,
    a.ingresos AS ingresos_actual,
    b.ingresos AS ingresos_anio_anterior,
    ROUND(100.0 * (a.ingresos - b.ingresos) / NULLIF(b.ingresos, 0), 2) AS pct_yoy
FROM ventas_mensuales a
LEFT JOIN ventas_mensuales b 
    ON a.mes_num = b.mes_num 
   AND a.anio = b.anio + 1
ORDER BY a.mes;
```

<br/>
<br/>

### Problema 5: generate_series() retorna error de tipo en la CTE

**Síntomas:**
- Error: `ERROR: function generate_series(date, date, interval) does not exist`
- Error: `ERROR: operator does not exist: date + interval`
- Las consultas de gaps no ejecutan correctamente

<br/>

**Causa:**
PostgreSQL requiere que los argumentos de `generate_series()` con fechas sean del mismo tipo. Mezclar `DATE` con `TIMESTAMPTZ` o `INTERVAL` puede causar errores de tipo.

<br/>

**Solución:**

```sql
-- Forma correcta: castear explícitamente a TIMESTAMPTZ
SELECT generate_series::DATE AS fecha
FROM generate_series(
    '2022-01-01'::TIMESTAMPTZ,
    '2024-12-31'::TIMESTAMPTZ,
    '1 day'::INTERVAL
);

-- Alternativa: usar DATE directamente (soportado desde PostgreSQL 14)
SELECT fecha::DATE
FROM generate_series(
    '2022-01-01'::DATE,
    '2024-12-31'::DATE,
    '1 day'
) AS fecha;

-- Verificar la versión de PostgreSQL
SELECT version();
-- Si es PostgreSQL 13 o anterior, siempre usar TIMESTAMPTZ en generate_series
```

<br/>
<br/>

## Limpieza

Al finalizar la práctica, puedes optar por mantener los objetos creados (son necesarios para prácticas posteriores) o limpiar el entorno de TimescaleDB si no lo necesitas inmediatamente.

```sql
-- OPCIONAL: Eliminar vistas creadas en esta práctica (NO recomendado si continuarás al Lab 04)
-- DROP VIEW IF EXISTS v_metricas_temporales;
-- DROP VIEW IF EXISTS v_analisis_cohortes;

-- OPCIONAL: Eliminar columna de timestamp si causa problemas de almacenamiento
-- ALTER TABLE sales DROP COLUMN IF EXISTS sale_timestamp;

-- VERIFICAR objetos que deben MANTENERSE para Lab 04-00-01:
SELECT 
    viewname,
    'MANTENER' AS accion
FROM pg_views
WHERE schemaname = 'public'
  AND viewname IN ('v_metricas_temporales', 'v_analisis_cohortes');
```

<br/>

```bash
# Detener el contenedor TimescaleDB (mantiene los datos en el volumen)
docker stop timescaledb_lab

# Si deseas eliminar completamente el contenedor TimescaleDB y sus datos:
# docker stop timescaledb_lab
# docker rm timescaledb_lab
# docker volume rm timescaledb_data

# El contenedor principal de PostgreSQL debe mantenerse activo
docker ps --filter "name=curso_postgres"
```

> **Advertencia:** NO elimines las vistas `v_metricas_temporales` y `v_analisis_cohortes` ni la columna `sale_timestamp` si planeas continuar con la práctica 4.1. Estos objetos son referenciados en los scripts de setup de la siguiente práctica. El contenedor `timescaledb_lab` puede detenerse sin problema y reiniciarse cuando sea necesario.

> **Nota de Seguridad:** Los contenedores de esta prática usan la contraseña `postgres` para facilitar el aprendizaje. Esta configuración es **exclusivamente para entornos de desarrollo local**. En ambientes de producción, utiliza contraseñas robustas, certificados SSL/TLS, y restricciones de red apropiadas.

<br/>
<br/>

## Resumen

### Lo que Lograste

- Enriqueciste el dataset de ventas con columnas de timestamp de alta precisión e índices optimizados para consultas temporales
- Dominaste `DATE_TRUNC()` para agregar datos a granularidades de día, semana, mes, trimestre y año, y `EXTRACT()` para análisis de estacionalidad por día de semana y hora del día
- Construiste comparaciones Month-over-Month (MoM) y Year-over-Year (YoY) usando CTEs anidadas y `LAG()` con desplazamiento de 1 y 12 períodos respectivamente
- Implementaste detección de gaps temporales usando `generate_series()` y `LEFT JOIN` para identificar días sin ventas en el dataset
- Desarrollaste un análisis de cohortes completo que calcula tasas de retención mensual desde la primera compra de cada cliente
- Exploraste TimescaleDB como extensión especializada para series de tiempo: instalación, creación de hypertables con particionado automático y consultas con `time_bucket()`

<br/>
<br/>

### Conceptos Clave Aprendidos

- **`DATE_TRUNC(precision, timestamp)`**: Trunca un timestamp a la precisión especificada, retornando el inicio del período (mes, semana, etc.). Es la base de cualquier agrupación temporal
- **`EXTRACT(field FROM timestamp)`**: Extrae un componente numérico específico (año, mes, día de semana, hora) para análisis de estacionalidad y filtros condicionales
- **`LAG(expr, offset)`**: Función de ventana que accede al valor de `offset` filas anteriores en la partición ordenada, fundamental para calcular variaciones porcentuales entre períodos
- **`generate_series(start, end, step)`**: Genera una secuencia de valores (fechas, números) que actúa como calendario completo para detectar gaps mediante `LEFT JOIN`
- **Análisis de Cohortes**: Técnica de segmentación que agrupa usuarios por su fecha de primera interacción y mide su comportamiento en períodos subsiguientes, revelando patrones de retención
- **TimescaleDB `time_bucket()`**: Equivalente flexible a `DATE_TRUNC()` que acepta intervalos arbitrarios (15 minutos, 3 horas, 2 semanas), optimizado para hypertables con particionado temporal automático


<br/>
<br/>

## Ejercicio de Reto (Evaluación Formativa)

> **Nivel de Dificultad:** Avanzado  
> **Tiempo estimado:** 15-20 minutos adicionales  
> **Instrucción:** Completa este reto antes de avanzar a la prática 4.1. No se provee solución; el instructor evaluará tu implementación.

<br/>

**Reto: Análisis de Reactivación de Clientes Dormidos**

Implementa una consulta SQL que identifique clientes "dormidos" (sin compras en los últimos 90 días del dataset) y calcule su potencial de reactivación basado en su historial de compras. La consulta debe:


1. Identificar la fecha de última compra de cada cliente usando funciones de ventana
2. Clasificar clientes como: `ACTIVO` (compra en últimos 30 días), `EN_RIESGO` (31-90 días), `DORMIDO` (91-180 días), `PERDIDO` (más de 180 días)
3. Para cada segmento, calcular: cantidad de clientes, promedio de compras históricas, valor total histórico y días promedio entre compras
4. Usar `generate_series()` para calcular la frecuencia de compra esperada de cada cliente dormido
5. Presentar los resultados ordenados por valor total histórico descendente

<br/>

**Criterios de Evaluación:**
- Uso correcto de `DATE_TRUNC()`, `EXTRACT()` y `AGE()` en la clasificación temporal
- Implementación limpia con CTEs nombradas descriptivamente
- Manejo correcto de `NULL` con `NULLIF()` o `COALESCE()` donde aplique
- Resultado final legible con columnas bien nombradas en español

<br/>
<br/>

## Recursos Adicionales

- [Documentación oficial PostgreSQL - Funciones de Fecha/Hora](https://www.postgresql.org/docs/16/functions-datetime.html) - Referencia completa de todas las funciones temporales disponibles en PostgreSQL 16
- [Documentación oficial PostgreSQL - generate_series](https://www.postgresql.org/docs/16/functions-srf.html) - Documentación de funciones de generación de conjuntos incluyendo `generate_series()`
- [TimescaleDB Documentation - time_bucket()](https://docs.timescale.com/api/latest/hyperfunctions/time_bucket/) - Referencia completa de `time_bucket()` con ejemplos de intervalos complejos
- [TimescaleDB Getting Started](https://docs.timescale.com/getting-started/latest/) - Guía oficial de inicio con TimescaleDB incluyendo hypertables y continuous aggregates
- [Cohort Analysis in SQL - Mode Analytics](https://mode.com/sql-tutorial/sql-cohort-analysis/) - Tutorial detallado de análisis de cohortes con ejemplos prácticos en SQL
- [PostgreSQL Wiki - Don't Do This (Date/Time)](https://wiki.postgresql.org/wiki/Don%27t_Do_This#Date.2FTime_storage) - Errores comunes a evitar en el manejo de fechas en PostgreSQL
- [pgAdmin 4 Query Tool Documentation](https://www.pgadmin.org/docs/pgadmin4/latest/query_tool.html) - Guía del Query Tool de pgAdmin 4 con funcionalidades de análisis de planes de ejecución