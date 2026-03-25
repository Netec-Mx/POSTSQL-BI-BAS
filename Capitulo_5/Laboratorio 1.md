# Laboratorio 1: Monitoreo y Optimización de Consultas

## Metadatos

| Propiedad | Valor |
|-----------|-------|
| **Duración** | 60 minutos |
| **Complejidad** | Avanzado |
| **Nivel Bloom** | Crear |
| **Módulo** | 5 – Indexación y Optimización de Rendimiento |
| **Laboratorio** | 05-00-01 |

---

## Descripción General

En este laboratorio aplicarás técnicas de indexación avanzada sobre el dataset de ventas construido en laboratorios anteriores para diagnosticar y eliminar cuellos de botella en consultas lentas. Partirás de un conjunto de consultas deliberadamente no optimizadas, analizarás sus planes de ejecución con `EXPLAIN` y `EXPLAIN ANALYZE`, crearás índices B-Tree, Hash, GIN y parciales estratégicamente, y medirás el impacto real en tiempos de respuesta antes y después de cada optimización. Este laboratorio refleja el flujo de trabajo real de un DBA o analista de datos que debe garantizar que los dashboards de Power BI respondan en tiempo aceptable sobre millones de registros.

---

## Objetivos de Aprendizaje

Al completar este laboratorio, serás capaz de:

- [ ] Crear índices B-Tree, Hash, GIN y parciales sobre el dataset de ventas y medir su impacto en tiempos de ejecución
- [ ] Interpretar el output de `EXPLAIN` y `EXPLAIN ANALYZE` identificando nodos de plan, costos estimados y tiempos reales
- [ ] Diferenciar entre Sequential Scan e Index Scan y explicar cuándo el planificador elige cada estrategia
- [ ] Identificar y eliminar cuellos de botella en consultas lentas usando planes de ejecución detallados con buffers
- [ ] Optimizar vistas materializadas con índices apropiados y verificar su uso mediante `pg_stat_user_indexes`

---

## Prerrequisitos

### Conocimiento Requerido

- Laboratorios del Módulo 4 completados (vistas, vistas materializadas, funciones PL/pgSQL)
- Comprensión de la estructura de las tablas `ventas`, `clientes`, `productos` y `regiones` del dataset del curso
- Familiaridad con la sintaxis básica de `SELECT`, `WHERE`, `JOIN` y `GROUP BY` en PostgreSQL
- Conocimiento conceptual de índices según la Lección 5.1

### Acceso Requerido

- Contenedor Docker con PostgreSQL 16 en ejecución (configurado en Lab 01-00-01)
- Acceso a pgAdmin 4 o DBeaver con conexión activa a la base de datos del curso
- Terminal con acceso al cliente `psql` dentro del contenedor Docker
- Dataset de ventas con mínimo 100,000 registros (generado en laboratorios anteriores)

---

## Entorno de Laboratorio

### Requisitos de Hardware

| Componente | Especificación |
|------------|----------------|
| RAM | Mínimo 8 GB (recomendado 16 GB) |
| Almacenamiento | Mínimo 5 GB libres para índices y datos |
| CPU | Intel Core i5 / AMD Ryzen 5 o superior |
| Sistema Operativo | Windows 10/11 (64-bit), macOS 12+, Ubuntu 20.04/22.04 LTS |

### Requisitos de Software

| Software | Versión | Propósito |
|----------|---------|-----------|
| Docker Desktop | 4.25.0 o superior | Ejecutar el contenedor PostgreSQL |
| PostgreSQL | 16.x (imagen Docker) | Motor de base de datos principal |
| psql (CLI) | 16.x | Ejecutar scripts SQL y comandos de diagnóstico |
| pgAdmin 4 | 7.x o superior | Visualizador gráfico de planes de ejecución |
| DBeaver Community | 23.x o superior | Alternativa para ejecución de consultas |

### Configuración Inicial

Verifica que el contenedor PostgreSQL esté en ejecución antes de comenzar:

```bash
# Verificar que el contenedor está corriendo
docker ps --filter "name=postgres" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Si el contenedor no está en ejecución, inícialo:

```bash
# Iniciar el contenedor (ajusta el nombre si es diferente en tu entorno)
docker start postgres_curso
```

Conéctate al contenedor para ejecutar comandos psql:

```bash
# Acceder al cliente psql dentro del contenedor
docker exec -it postgres_curso psql -U postgres -d ventas_db
```

Verifica que el dataset tiene el volumen mínimo requerido:

```sql
-- Verificar volumen de datos disponible
SELECT
    schemaname,
    tablename,
    n_live_tup AS filas_estimadas
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;
```

> ⚠️ **Nota Importante:** Si el conteo de filas en la tabla `ventas` es inferior a 100,000 registros, ejecuta el siguiente script generador antes de continuar. Los ejercicios de optimización requieren volumen suficiente para que el planificador elija estrategias de escaneo diferentes.

```sql
-- Script generador de datos adicionales si el dataset es insuficiente
-- Ejecutar solo si ventas tiene menos de 100,000 registros
INSERT INTO ventas (
    cliente_id,
    producto_id,
    region_id,
    fecha_venta,
    cantidad,
    precio_unitario,
    descuento,
    estado,
    metadata
)
SELECT
    (random() * 999 + 1)::int AS cliente_id,
    (random() * 499 + 1)::int AS producto_id,
    (random() * 9 + 1)::int AS region_id,
    CURRENT_DATE - (random() * 1095)::int AS fecha_venta,
    (random() * 20 + 1)::int AS cantidad,
    round((random() * 990 + 10)::numeric, 2) AS precio_unitario,
    round((random() * 0.3)::numeric, 2) AS descuento,
    CASE (random() * 3)::int
        WHEN 0 THEN 'completado'
        WHEN 1 THEN 'pendiente'
        WHEN 2 THEN 'cancelado'
        ELSE 'completado'
    END AS estado,
    jsonb_build_object(
        'canal', CASE (random() * 2)::int
            WHEN 0 THEN 'web'
            WHEN 1 THEN 'tienda'
            ELSE 'telefono'
        END,
        'prioridad', CASE (random() * 2)::int
            WHEN 0 THEN 'alta'
            WHEN 1 THEN 'media'
            ELSE 'baja'
        END
    ) AS metadata
FROM generate_series(1, 150000);

-- Actualizar estadísticas después de la inserción masiva
ANALYZE ventas;
```

---

## Instrucciones Paso a Paso

### Paso 1: Preparar el Entorno de Diagnóstico

**Objetivo:** Habilitar las extensiones necesarias para monitoreo de rendimiento y establecer una línea base de diagnóstico antes de crear ningún índice.

**Instrucciones:**

1. Conéctate a la base de datos del curso con psql:

   ```bash
   docker exec -it postgres_curso psql -U postgres -d ventas_db
   ```

2. Habilita la extensión `pg_stat_statements` para rastrear estadísticas de ejecución de consultas:

   ```sql
   -- Habilitar la extensión de estadísticas de consultas
   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
   ```

3. Verifica qué índices existen actualmente sobre las tablas del dataset:

   ```sql
   -- Listar todos los índices existentes en el esquema público
   SELECT
       t.relname AS tabla,
       i.relname AS indice,
       ix.indisunique AS es_unico,
       ix.indisprimary AS es_pk,
       array_to_string(
           array_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum)),
           ', '
       ) AS columnas
   FROM
       pg_class t
       JOIN pg_index ix ON t.oid = ix.indrelid
       JOIN pg_class i ON i.oid = ix.indexrelid
       JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
   WHERE
       t.relkind = 'r'
       AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
   GROUP BY
       t.relname, i.relname, ix.indisunique, ix.indisprimary
   ORDER BY
       t.relname, i.relname;
   ```

4. Guarda el estado inicial de estadísticas de uso de índices para comparar al final:

   ```sql
   -- Fotografía inicial del uso de índices (guardar mentalmente o copiar output)
   SELECT
       relname AS tabla,
       indexrelname AS indice,
       idx_scan AS veces_usado,
       idx_tup_read AS tuplas_leidas,
       idx_tup_fetch AS tuplas_obtenidas
   FROM pg_stat_user_indexes
   WHERE schemaname = 'public'
   ORDER BY relname, idx_scan DESC;
   ```

5. Desactiva temporalmente el JIT (Just-In-Time compilation) para obtener planes de ejecución más legibles durante el laboratorio:

   ```sql
   -- Deshabilitar JIT para este laboratorio (facilita lectura de planes)
   SET jit = off;
   ```

**Salida Esperada:**

```
-- Para la extensión pg_stat_statements:
CREATE EXTENSION

-- Para el listado de índices, verás al menos las claves primarias:
  tabla   |          indice           | es_unico | es_pk | columnas
----------+---------------------------+----------+-------+----------
 clientes | clientes_pkey             | t        | t     | id
 productos| productos_pkey            | t        | t     | id
 ventas   | ventas_pkey               | t        | t     | id
```

**Verificación:**

- Confirma que `pg_stat_statements` aparece en `SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';`
- Confirma que NO existen índices sobre `ventas.fecha_venta`, `ventas.cliente_id`, `ventas.producto_id` ni `ventas.estado` (solo debe existir la PK)

---

### Paso 2: Analizar Consultas Lentas con EXPLAIN (Plan Estimado)

**Objetivo:** Usar `EXPLAIN` sin ejecutar la consulta para obtener el plan estimado del planificador e identificar Sequential Scans costosos.

**Instrucciones:**

1. Analiza el plan de ejecución de una consulta de filtro por fecha sin índice:

   ```sql
   -- EXPLAIN muestra el plan estimado SIN ejecutar la consulta
   EXPLAIN
   SELECT
       v.id,
       v.fecha_venta,
       v.cantidad,
       v.precio_unitario,
       c.nombre AS cliente
   FROM ventas v
   JOIN clientes c ON v.cliente_id = c.id
   WHERE v.fecha_venta BETWEEN '2023-01-01' AND '2023-12-31'
   ORDER BY v.fecha_venta DESC;
   ```

2. Interpreta el output prestando atención a los siguientes elementos clave:

   ```sql
   -- Consulta de análisis de ventas por región sin índice
   EXPLAIN
   SELECT
       r.nombre AS region,
       COUNT(*) AS total_ventas,
       SUM(v.cantidad * v.precio_unitario) AS ingresos_totales,
       AVG(v.precio_unitario) AS precio_promedio
   FROM ventas v
   JOIN regiones r ON v.region_id = r.id
   WHERE v.fecha_venta >= '2024-01-01'
   GROUP BY r.nombre
   ORDER BY ingresos_totales DESC;
   ```

3. Visualiza el plan en formato JSON para análisis más detallado:

   ```sql
   -- Plan en formato JSON (útil para herramientas de visualización)
   EXPLAIN (FORMAT JSON)
   SELECT *
   FROM ventas
   WHERE cliente_id = 42
     AND estado = 'completado';
   ```

4. Examina una consulta con búsqueda de texto en metadata JSONB:

   ```sql
   -- Consulta sobre campo JSONB sin índice GIN
   EXPLAIN
   SELECT id, fecha_venta, metadata
   FROM ventas
   WHERE metadata @> '{"canal": "web"}'::jsonb;
   ```

**Salida Esperada:**

```
-- Para la consulta de filtro por fecha, deberías ver algo similar a:
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Sort  (cost=15234.56..15289.12 rows=21823 width=52)
   Sort Key: v.fecha_venta DESC
   ->  Hash Join  (cost=245.00..13456.78 rows=21823 width=52)
         Hash Cond: (v.cliente_id = c.id)
         ->  Seq Scan on ventas v  (cost=0.00..12890.00 rows=21823 width=40)
               Filter: ((fecha_venta >= '2023-01-01') AND (fecha_venta <= '2023-12-31'))
         ->  Hash  (cost=145.00..145.00 rows=8000 width=20)
               ->  Seq Scan on clientes c  (cost=0.00..145.00 rows=8000 width=20)
```

**Verificación:**

- Confirma que ves `Seq Scan on ventas` en el plan (escaneo secuencial, sin índice)
- Anota el costo estimado total (el número después de `cost=` en el nodo raíz)
- El costo estimado para `ventas` debería ser significativamente alto si hay 100,000+ registros

> 💡 **Cómo leer el output de EXPLAIN:**
> - `cost=X..Y`: X es el costo de inicio (antes de devolver la primera fila), Y es el costo total estimado
> - `rows=N`: número estimado de filas que devolverá el nodo
> - `width=N`: tamaño promedio estimado en bytes de cada fila
> - `Seq Scan`: escaneo secuencial (lee TODA la tabla)
> - `Index Scan`: usa un índice para localizar filas específicas

---

### Paso 3: Medir Tiempos Reales con EXPLAIN ANALYZE

**Objetivo:** Ejecutar las consultas realmente y medir tiempos de ejecución actuales como línea base antes de crear índices.

**Instrucciones:**

1. Mide el tiempo real de la consulta de filtro por fecha:

   ```sql
   -- EXPLAIN ANALYZE ejecuta la consulta Y muestra tiempos reales
   EXPLAIN ANALYZE
   SELECT
       v.id,
       v.fecha_venta,
       v.cantidad,
       v.precio_unitario,
       c.nombre AS cliente
   FROM ventas v
   JOIN clientes c ON v.cliente_id = c.id
   WHERE v.fecha_venta BETWEEN '2023-01-01' AND '2023-12-31'
   ORDER BY v.fecha_venta DESC;
   ```

2. Mide con información de buffers (caché de PostgreSQL) para análisis profundo:

   ```sql
   -- EXPLAIN con BUFFERS muestra hits/misses de caché
   EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
   SELECT
       v.id,
       v.fecha_venta,
       v.cantidad * v.precio_unitario AS total_venta,
       v.estado,
       p.nombre AS producto
   FROM ventas v
   JOIN productos p ON v.producto_id = p.id
   WHERE v.cliente_id = 100
   ORDER BY v.fecha_venta DESC
   LIMIT 50;
   ```

3. Registra los tiempos base en una tabla temporal para comparación posterior:

   ```sql
   -- Crear tabla temporal para registrar métricas de rendimiento
   CREATE TEMP TABLE metricas_rendimiento (
       consulta_id      SERIAL,
       descripcion      TEXT,
       fase             TEXT,  -- 'antes' o 'despues'
       tiempo_ms        NUMERIC,
       tipo_scan        TEXT,
       costo_estimado   NUMERIC,
       filas_reales     INTEGER,
       registrado_en    TIMESTAMP DEFAULT NOW()
   );

   -- Registrar métricas base manualmente después de ejecutar EXPLAIN ANALYZE
   -- (Insertar los valores que observaste en el output anterior)
   INSERT INTO metricas_rendimiento (descripcion, fase, tiempo_ms, tipo_scan, costo_estimado)
   VALUES
       ('Filtro por fecha_venta 2023', 'antes', 0, 'Seq Scan', 0),
       ('Filtro por cliente_id + estado', 'antes', 0, 'Seq Scan', 0),
       ('Búsqueda JSONB metadata canal', 'antes', 0, 'Seq Scan', 0);
   ```

   > ⚠️ **Instrucción:** Actualiza los valores `0` con los tiempos reales que observaste en el output de `EXPLAIN ANALYZE`. El tiempo aparece al final del output como `Execution Time: X.XXX ms`.

4. Ejecuta la consulta de búsqueda JSONB y registra su tiempo base:

   ```sql
   -- Medir consulta JSONB antes de índice GIN
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       id,
       fecha_venta,
       cantidad * precio_unitario AS total,
       metadata->>'canal' AS canal_venta,
       metadata->>'prioridad' AS prioridad
   FROM ventas
   WHERE metadata @> '{"canal": "web"}'::jsonb
     AND fecha_venta >= '2024-01-01';
   ```

**Salida Esperada:**

```
-- Output de EXPLAIN ANALYZE con tiempos reales (valores aproximados):
                                           QUERY PLAN
-------------------------------------------------------------------------------------------------
 Sort  (cost=15234.56..15289.12 rows=21823 width=52)
       (actual time=234.567..245.123 rows=18456 loops=1)
   Sort Key: v.fecha_venta DESC
   Sort Method: external merge  Disk: 2048kB
   ->  Hash Join  (cost=245.00..13456.78 rows=21823 width=52)
                  (actual time=12.345..198.456 rows=18456 loops=1)
         ->  Seq Scan on ventas v  (cost=0.00..12890.00 rows=21823 width=40)
                                   (actual time=0.012..156.789 rows=18456 loops=1)
               Filter: ((fecha_venta >= '2023-01-01') AND (fecha_venta <= '2023-12-31'))
               Rows Removed by Filter: 131544
 Planning Time: 1.234 ms
 Execution Time: 248.901 ms
```

**Verificación:**

- Confirma que ves `actual time=X..Y` en cada nodo del plan (indica ejecución real)
- Anota el `Execution Time` total al final del output
- Confirma que `Rows Removed by Filter` es alto (indica que el Seq Scan lee muchas filas innecesariamente)
- El tiempo debería ser de cientos de milisegundos en tablas de 100,000+ registros sin índices

---

### Paso 4: Crear Índices B-Tree y Medir el Impacto

**Objetivo:** Crear índices B-Tree sobre las columnas de filtro más frecuentes y verificar con `EXPLAIN ANALYZE` que el planificador los utiliza, documentando la mejora en tiempos.

**Instrucciones:**

1. Crea el índice B-Tree sobre `fecha_venta` (columna más consultada en análisis temporales):

   ```sql
   -- Crear índice B-Tree sobre fecha_venta
   -- CONCURRENT permite crear el índice sin bloquear escrituras (buena práctica en producción)
   CREATE INDEX CONCURRENTLY idx_ventas_fecha_venta
   ON ventas(fecha_venta);

   -- Verificar que el índice se creó correctamente
   SELECT
       indexname,
       indexdef
   FROM pg_indexes
   WHERE tablename = 'ventas'
     AND indexname = 'idx_ventas_fecha_venta';
   ```

2. Fuerza la actualización de estadísticas y ejecuta la misma consulta del Paso 3:

   ```sql
   -- Actualizar estadísticas para que el planificador use información fresca
   ANALYZE ventas;

   -- Ejecutar la misma consulta del Paso 3 para comparar
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       v.id,
       v.fecha_venta,
       v.cantidad,
       v.precio_unitario,
       c.nombre AS cliente
   FROM ventas v
   JOIN clientes c ON v.cliente_id = c.id
   WHERE v.fecha_venta BETWEEN '2023-01-01' AND '2023-12-31'
   ORDER BY v.fecha_venta DESC;
   ```

3. Crea índices B-Tree adicionales sobre columnas de JOIN frecuentes:

   ```sql
   -- Índice sobre cliente_id (columna de JOIN y filtro frecuente)
   CREATE INDEX CONCURRENTLY idx_ventas_cliente_id
   ON ventas(cliente_id);

   -- Índice sobre producto_id (columna de JOIN frecuente)
   CREATE INDEX CONCURRENTLY idx_ventas_producto_id
   ON ventas(producto_id);

   -- Índice sobre region_id (columna de agrupación en reportes)
   CREATE INDEX CONCURRENTLY idx_ventas_region_id
   ON ventas(region_id);

   -- Actualizar estadísticas después de crear todos los índices
   ANALYZE ventas;
   ```

4. Verifica el impacto del índice en la consulta de cliente específico:

   ```sql
   -- Comparar: consulta por cliente_id después del índice
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       v.id,
       v.fecha_venta,
       v.cantidad * v.precio_unitario AS total_venta,
       v.estado,
       p.nombre AS producto
   FROM ventas v
   JOIN productos p ON v.producto_id = p.id
   WHERE v.cliente_id = 100
   ORDER BY v.fecha_venta DESC
   LIMIT 50;
   ```

5. Crea un índice compuesto para consultas que filtran por múltiples columnas:

   ```sql
   -- Índice compuesto: región + fecha (patrón común en reportes de ventas)
   CREATE INDEX CONCURRENTLY idx_ventas_region_fecha
   ON ventas(region_id, fecha_venta DESC);

   -- Verificar que el planificador usa el índice compuesto
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       r.nombre AS region,
       v.fecha_venta,
       SUM(v.cantidad * v.precio_unitario) AS ingresos_diarios
   FROM ventas v
   JOIN regiones r ON v.region_id = r.id
   WHERE v.region_id = 3
     AND v.fecha_venta >= '2024-01-01'
   GROUP BY r.nombre, v.fecha_venta
   ORDER BY v.fecha_venta DESC;
   ```

**Salida Esperada:**

```
-- Después del índice, el plan debería mostrar Index Scan en lugar de Seq Scan:
                                           QUERY PLAN
-------------------------------------------------------------------------------------------------
 Sort  (cost=1234.56..1289.12 rows=18456 width=52)
       (actual time=45.678..52.345 rows=18456 loops=1)
   Sort Key: v.fecha_venta DESC
   ->  Hash Join  (cost=245.00..1123.45 rows=18456 width=52)
                  (actual time=12.345..38.456 rows=18456 loops=1)
         ->  Index Scan using idx_ventas_fecha_venta on ventas v
               (cost=0.43..890.12 rows=18456 width=40)
               (actual time=0.056..18.789 rows=18456 loops=1)
               Index Cond: ((fecha_venta >= '2023-01-01') AND (fecha_venta <= '2023-12-31'))
 Planning Time: 0.987 ms
 Execution Time: 54.123 ms
```

**Verificación:**

- Confirma que el plan ahora muestra `Index Scan using idx_ventas_fecha_venta` en lugar de `Seq Scan`
- Compara el `Execution Time` con el registrado en el Paso 3 (debe ser significativamente menor)
- Actualiza la tabla `metricas_rendimiento` con los nuevos tiempos:

   ```sql
   -- Registrar métricas después de índices B-Tree
   UPDATE metricas_rendimiento
   SET fase = 'despues', tiempo_ms = 54.123  -- Reemplaza con tu valor real
   WHERE descripcion = 'Filtro por fecha_venta 2023';
   ```

---

### Paso 5: Crear Índice Hash y Comparar con B-Tree

**Objetivo:** Crear un índice Hash para búsquedas exactas de alta frecuencia y entender cuándo es más eficiente que B-Tree.

**Instrucciones:**

1. Primero analiza la consulta de búsqueda exacta por estado sin índice especializado:

   ```sql
   -- Verificar el plan actual para búsqueda exacta por estado
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT COUNT(*), estado
   FROM ventas
   WHERE estado = 'completado'
   GROUP BY estado;
   ```

   > 💡 **Nota:** El campo `estado` tiene baja cardinalidad (pocos valores distintos: completado, pendiente, cancelado). Esto es importante para entender por qué el planificador puede preferir Seq Scan incluso con un índice.

2. Crea un índice Hash sobre una columna de alta cardinalidad para búsquedas exactas:

   ```sql
   -- Índice Hash: óptimo para búsquedas de igualdad exacta en columnas de alta cardinalidad
   -- Usamos cliente_id que tiene muchos valores distintos
   CREATE INDEX idx_ventas_cliente_hash
   ON ventas USING HASH(cliente_id);

   ANALYZE ventas;
   ```

3. Compara el rendimiento entre el índice B-Tree y el Hash para búsqueda exacta:

   ```sql
   -- Forzar uso de índice B-Tree (deshabilitar Hash temporalmente)
   SET enable_hashjoin = off;

   EXPLAIN (ANALYZE, BUFFERS)
   SELECT *
   FROM ventas
   WHERE cliente_id = 250
   LIMIT 100;

   -- Restaurar configuración normal
   SET enable_hashjoin = on;

   -- Ahora con ambos índices disponibles (el planificador elige)
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT *
   FROM ventas
   WHERE cliente_id = 250
   LIMIT 100;
   ```

4. Verifica qué índice eligió el planificador y por qué:

   ```sql
   -- Consulta para ver estadísticas de uso de ambos índices
   SELECT
       indexrelname AS indice,
       idx_scan AS veces_usado,
       idx_tup_read AS tuplas_leidas_del_indice,
       idx_tup_fetch AS tuplas_obtenidas_de_tabla
   FROM pg_stat_user_indexes
   WHERE relname = 'ventas'
     AND indexrelname IN ('idx_ventas_cliente_id', 'idx_ventas_cliente_hash')
   ORDER BY idx_scan DESC;
   ```

**Salida Esperada:**

```
-- El planificador debería elegir el índice Hash para búsqueda exacta:
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Limit  (cost=0.00..12.34 rows=100 width=89)
        (actual time=0.045..0.234 rows=100 loops=1)
   ->  Index Scan using idx_ventas_cliente_hash on ventas
         (cost=0.00..1234.56 rows=10000 width=89)
         (actual time=0.043..0.198 rows=100 loops=1)
         Index Cond: (cliente_id = 250)
 Planning Time: 0.456 ms
 Execution Time: 0.312 ms
```

**Verificación:**

- Confirma que el plan muestra `Index Scan using idx_ventas_cliente_hash` para la búsqueda exacta
- Anota que el índice Hash NO puede usarse para rangos (`BETWEEN`, `>`, `<`): solo funciona con `=`
- Ejecuta una consulta de rango para confirmar que el planificador usa B-Tree en ese caso:

   ```sql
   -- El planificador DEBE usar B-Tree aquí (Hash no soporta rangos)
   EXPLAIN
   SELECT COUNT(*)
   FROM ventas
   WHERE cliente_id BETWEEN 100 AND 200;
   ```

---

### Paso 6: Crear Índice GIN para Búsquedas JSONB

**Objetivo:** Crear un índice GIN sobre la columna `metadata` de tipo JSONB y verificar su impacto en búsquedas de contenido dentro de documentos JSON.

**Instrucciones:**

1. Mide el rendimiento actual de búsquedas JSONB sin índice GIN:

   ```sql
   -- Consulta JSONB sin índice: escaneo secuencial de toda la columna
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       id,
       fecha_venta,
       metadata->>'canal' AS canal,
       metadata->>'prioridad' AS prioridad,
       cantidad * precio_unitario AS total
   FROM ventas
   WHERE metadata @> '{"canal": "web"}'::jsonb;
   ```

2. Crea el índice GIN sobre la columna `metadata`:

   ```sql
   -- Índice GIN: optimizado para búsquedas dentro de estructuras JSONB
   CREATE INDEX CONCURRENTLY idx_ventas_metadata_gin
   ON ventas USING GIN(metadata);

   ANALYZE ventas;
   ```

3. Ejecuta la misma consulta y compara el plan:

   ```sql
   -- Misma consulta después del índice GIN
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       id,
       fecha_venta,
       metadata->>'canal' AS canal,
       metadata->>'prioridad' AS prioridad,
       cantidad * precio_unitario AS total
   FROM ventas
   WHERE metadata @> '{"canal": "web"}'::jsonb;
   ```

4. Prueba búsquedas más complejas sobre JSONB que aprovechan el índice GIN:

   ```sql
   -- Búsqueda con múltiples condiciones JSONB (usa el mismo índice GIN)
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       COUNT(*) AS total_ventas,
       SUM(cantidad * precio_unitario) AS ingresos
   FROM ventas
   WHERE metadata @> '{"canal": "web", "prioridad": "alta"}'::jsonb
     AND fecha_venta >= '2024-01-01';
   ```

5. Verifica el tamaño del índice GIN comparado con los índices B-Tree:

   ```sql
   -- Comparar tamaños de todos los índices en la tabla ventas
   SELECT
       i.relname AS indice,
       pg_size_pretty(pg_relation_size(i.oid)) AS tamano,
       ix.indisunique AS unico,
       am.amname AS tipo_indice,
       array_to_string(
           array_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum)),
           ', '
       ) AS columnas
   FROM
       pg_class t
       JOIN pg_index ix ON t.oid = ix.indrelid
       JOIN pg_class i ON i.oid = ix.indexrelid
       JOIN pg_am am ON i.relam = am.oid
       JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
   WHERE
       t.relname = 'ventas'
   GROUP BY
       i.relname, i.oid, ix.indisunique, am.amname
   ORDER BY
       pg_relation_size(i.oid) DESC;
   ```

**Salida Esperada:**

```
-- Después del índice GIN, el plan debería cambiar de Seq Scan a Bitmap Index Scan:
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Bitmap Heap Scan on ventas  (cost=234.56..1890.12 rows=33333 width=89)
                              (actual time=12.345..45.678 rows=33456 loops=1)
   Recheck Cond: (metadata @> '{"canal": "web"}'::jsonb)
   ->  Bitmap Index Scan on idx_ventas_metadata_gin
         (cost=0.00..226.23 rows=33333 width=0)
         (actual time=11.234..11.234 rows=33456 loops=1)
         Index Cond: (metadata @> '{"canal": "web"}'::jsonb)
 Planning Time: 0.567 ms
 Execution Time: 47.890 ms

-- Comparación de tamaños de índices:
         indice          | tamano  | unico | tipo_indice |    columnas
-------------------------+---------+-------+-------------+----------------
 idx_ventas_metadata_gin | 8192 kB | f     | gin         | metadata
 idx_ventas_fecha_venta  | 2208 kB | f     | btree       | fecha_venta
 idx_ventas_cliente_id   | 2208 kB | f     | btree       | cliente_id
```

**Verificación:**

- Confirma que el plan muestra `Bitmap Index Scan on idx_ventas_metadata_gin`
- Nota que GIN usa `Bitmap Index Scan` + `Bitmap Heap Scan` en lugar de `Index Scan` directo
- Verifica que el índice GIN es más grande que los B-Tree (es normal por su estructura interna)

---

### Paso 7: Crear Índices Parciales para Subconjuntos de Datos

**Objetivo:** Implementar índices parciales que cubren solo un subconjunto de filas relevantes, reduciendo el tamaño del índice y mejorando su eficiencia para consultas específicas.

**Instrucciones:**

1. Analiza el patrón de consultas sobre ventas del último año (caso de uso frecuente en dashboards):

   ```sql
   -- Consulta frecuente: ventas recientes pendientes de procesamiento
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       v.id,
       v.fecha_venta,
       v.cliente_id,
       v.cantidad * v.precio_unitario AS total,
       c.nombre AS cliente,
       c.email
   FROM ventas v
   JOIN clientes c ON v.cliente_id = c.id
   WHERE v.estado = 'pendiente'
     AND v.fecha_venta >= CURRENT_DATE - INTERVAL '365 days'
   ORDER BY v.fecha_venta DESC;
   ```

2. Crea un índice parcial solo para ventas pendientes (subconjunto pequeño):

   ```sql
   -- Índice parcial: solo indexa ventas con estado 'pendiente'
   -- Mucho más pequeño y eficiente que un índice completo sobre estado
   CREATE INDEX CONCURRENTLY idx_ventas_pendientes_fecha
   ON ventas(fecha_venta DESC)
   WHERE estado = 'pendiente';

   ANALYZE ventas;
   ```

3. Verifica que el índice parcial se usa correctamente:

   ```sql
   -- La consulta DEBE usar el índice parcial (condición WHERE coincide)
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       v.id,
       v.fecha_venta,
       v.cliente_id,
       v.cantidad * v.precio_unitario AS total,
       c.nombre AS cliente
   FROM ventas v
   JOIN clientes c ON v.cliente_id = c.id
   WHERE v.estado = 'pendiente'
     AND v.fecha_venta >= CURRENT_DATE - INTERVAL '365 days'
   ORDER BY v.fecha_venta DESC;

   -- Esta consulta NO usa el índice parcial (condición WHERE diferente)
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT COUNT(*)
   FROM ventas
   WHERE estado = 'cancelado'  -- Diferente estado, no coincide con la condición del índice parcial
     AND fecha_venta >= CURRENT_DATE - INTERVAL '365 days';
   ```

4. Crea un segundo índice parcial para ventas de alto valor (caso de uso analítico):

   ```sql
   -- Índice parcial para ventas de alto valor (precio > 500)
   -- Útil para reportes de ventas premium
   CREATE INDEX CONCURRENTLY idx_ventas_alto_valor
   ON ventas(cliente_id, fecha_venta)
   WHERE precio_unitario > 500;

   ANALYZE ventas;

   -- Verificar uso del índice parcial de alto valor
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       cliente_id,
       COUNT(*) AS compras_premium,
       SUM(cantidad * precio_unitario) AS total_premium
   FROM ventas
   WHERE precio_unitario > 500
     AND fecha_venta >= '2024-01-01'
   GROUP BY cliente_id
   ORDER BY total_premium DESC
   LIMIT 20;
   ```

5. Compara el tamaño del índice parcial versus un índice completo equivalente:

   ```sql
   -- Ver tamaños de índices parciales vs completos
   SELECT
       i.relname AS indice,
       pg_size_pretty(pg_relation_size(i.oid)) AS tamano,
       pg_get_expr(ix.indpred, ix.indrelid) AS condicion_parcial
   FROM
       pg_class t
       JOIN pg_index ix ON t.oid = ix.indrelid
       JOIN pg_class i ON i.oid = ix.indexrelid
   WHERE
       t.relname = 'ventas'
   ORDER BY
       pg_relation_size(i.oid) DESC;
   ```

**Salida Esperada:**

```
-- El plan debe mostrar el índice parcial para consultas que coinciden con su condición:
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Sort  (cost=456.78..467.89 rows=4444 width=60)
       (actual time=15.678..16.234 rows=4521 loops=1)
   ->  Hash Join  (cost=123.45..400.12 rows=4444 width=60)
                  (actual time=5.678..12.345 rows=4521 loops=1)
         ->  Index Scan using idx_ventas_pendientes_fecha on ventas v
               (cost=0.43..256.78 rows=4444 width=36)
               (actual time=0.034..7.890 rows=4521 loops=1)
               Index Cond: (fecha_venta >= (CURRENT_DATE - '365 days'::interval))

-- Comparación de tamaños (el índice parcial es significativamente más pequeño):
           indice            | tamano  | condicion_parcial
-----------------------------+---------+------------------------------------------
 idx_ventas_fecha_venta      | 2208 kB |
 idx_ventas_pendientes_fecha |  312 kB | (estado = 'pendiente')
 idx_ventas_alto_valor       |  456 kB | (precio_unitario > 500)
```

**Verificación:**

- Confirma que el plan usa `idx_ventas_pendientes_fecha` para consultas con `WHERE estado = 'pendiente'`
- Confirma que el índice parcial NO aparece en el plan de consultas con `WHERE estado = 'cancelado'`
- Verifica que los índices parciales son considerablemente más pequeños que el índice completo

---

### Paso 8: Optimizar Vistas Materializadas con Índices

**Objetivo:** Crear índices sobre vistas materializadas existentes y verificar que las consultas analíticas de alto nivel aprovechan estos índices para respuestas más rápidas.

**Instrucciones:**

1. Verifica las vistas materializadas existentes del laboratorio anterior:

   ```sql
   -- Listar vistas materializadas disponibles
   SELECT
       schemaname,
       matviewname,
       hasindexes,
       ispopulated,
       pg_size_pretty(pg_relation_size(schemaname || '.' || matviewname)) AS tamano
   FROM pg_matviews
   WHERE schemaname = 'public'
   ORDER BY matviewname;
   ```

2. Si no existe una vista materializada de resumen de ventas, créala ahora:

   ```sql
   -- Crear vista materializada de resumen de ventas por región y mes
   CREATE MATERIALIZED VIEW IF NOT EXISTS mv_resumen_ventas_mensual AS
   SELECT
       r.id AS region_id,
       r.nombre AS region_nombre,
       DATE_TRUNC('month', v.fecha_venta) AS mes,
       COUNT(*) AS total_transacciones,
       SUM(v.cantidad) AS unidades_vendidas,
       SUM(v.cantidad * v.precio_unitario) AS ingresos_brutos,
       SUM(v.cantidad * v.precio_unitario * (1 - v.descuento)) AS ingresos_netos,
       AVG(v.precio_unitario) AS precio_promedio,
       COUNT(DISTINCT v.cliente_id) AS clientes_unicos,
       COUNT(DISTINCT v.producto_id) AS productos_distintos
   FROM ventas v
   JOIN regiones r ON v.region_id = r.id
   WHERE v.estado = 'completado'
   GROUP BY r.id, r.nombre, DATE_TRUNC('month', v.fecha_venta)
   WITH DATA;
   ```

3. Analiza el plan de consulta sobre la vista materializada SIN índices:

   ```sql
   -- Consulta sobre vista materializada sin índices
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       region_nombre,
       mes,
       ingresos_netos,
       total_transacciones,
       clientes_unicos,
       LAG(ingresos_netos) OVER (PARTITION BY region_nombre ORDER BY mes) AS mes_anterior,
       ingresos_netos - LAG(ingresos_netos) OVER (PARTITION BY region_nombre ORDER BY mes) AS variacion
   FROM mv_resumen_ventas_mensual
   WHERE mes >= '2024-01-01'
   ORDER BY region_nombre, mes;
   ```

4. Crea índices sobre la vista materializada para optimizar consultas de dashboard:

   ```sql
   -- Índice B-Tree sobre mes para filtros temporales (el más frecuente en dashboards)
   CREATE INDEX idx_mv_resumen_mes
   ON mv_resumen_ventas_mensual(mes DESC);

   -- Índice compuesto para consultas por región y período
   CREATE INDEX idx_mv_resumen_region_mes
   ON mv_resumen_ventas_mensual(region_id, mes DESC);

   -- Índice cubriente: incluye columnas de métricas para evitar acceso a la tabla
   CREATE INDEX idx_mv_resumen_cubriente
   ON mv_resumen_ventas_mensual(mes DESC)
   INCLUDE (region_nombre, ingresos_netos, total_transacciones, clientes_unicos);
   ```

5. Verifica el impacto de los índices en la vista materializada:

   ```sql
   -- Misma consulta después de los índices
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       region_nombre,
       mes,
       ingresos_netos,
       total_transacciones,
       clientes_unicos,
       LAG(ingresos_netos) OVER (PARTITION BY region_nombre ORDER BY mes) AS mes_anterior,
       ingresos_netos - LAG(ingresos_netos) OVER (PARTITION BY region_nombre ORDER BY mes) AS variacion
   FROM mv_resumen_ventas_mensual
   WHERE mes >= '2024-01-01'
   ORDER BY region_nombre, mes;

   -- Consulta de KPI específico por región (aprovecha índice cubriente)
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT
       region_nombre,
       SUM(ingresos_netos) AS ingresos_anuales,
       SUM(total_transacciones) AS transacciones_anuales,
       SUM(clientes_unicos) AS alcance_clientes
   FROM mv_resumen_ventas_mensual
   WHERE mes BETWEEN '2024-01-01' AND '2024-12-31'
   GROUP BY region_nombre
   ORDER BY ingresos_anuales DESC;
   ```

6. Configura el proceso de refresco de la vista materializada con índices:

   ```sql
   -- Refrescar la vista materializada con datos actualizados
   -- CONCURRENTLY permite refrescar sin bloquear lecturas (requiere al menos un índice único)
   -- Primero creamos el índice único requerido para REFRESH CONCURRENTLY
   CREATE UNIQUE INDEX idx_mv_resumen_unique
   ON mv_resumen_ventas_mensual(region_id, mes);

   -- Ahora podemos refrescar sin bloquear lecturas
   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_ventas_mensual;
   ```

**Salida Esperada:**

```
-- Después de los índices, la consulta sobre la vista materializada debe usar Index Scan:
                                    QUERY PLAN
----------------------------------------------------------------------------------
 WindowAgg  (cost=234.56..345.67 rows=120 width=89)
            (actual time=8.901..9.234 rows=120 loops=1)
   ->  Sort  (cost=234.56..234.86 rows=120 width=73)
             (actual time=8.789..8.823 rows=120 loops=1)
         Sort Key: region_nombre, mes
         ->  Index Scan using idx_mv_resumen_mes on mv_resumen_ventas_mensual
               (cost=0.14..230.12 rows=120 width=73)
               (actual time=0.034..8.456 rows=120 loops=1)
               Index Cond: (mes >= '2024-01-01 00:00:00')
 Planning Time: 0.789 ms
 Execution Time: 9.456 ms
```

**Verificación:**

- Confirma que el plan usa `Index Scan using idx_mv_resumen_mes`
- Verifica que `REFRESH MATERIALIZED VIEW CONCURRENTLY` se ejecuta sin errores
- Compara el tiempo de ejecución antes y después de los índices en la vista materializada

---

### Paso 9: Monitorear Uso de Índices con pg_stat_user_indexes

**Objetivo:** Usar la vista de sistema `pg_stat_user_indexes` para identificar índices que el planificador usa frecuentemente y detectar índices que nunca se usan (candidatos para eliminación).

**Instrucciones:**

1. Ejecuta un conjunto de consultas representativas para generar estadísticas de uso:

   ```sql
   -- Ejecutar múltiples consultas para generar estadísticas de uso de índices
   -- Consulta 1: Filtro por fecha
   SELECT COUNT(*) FROM ventas WHERE fecha_venta >= '2024-01-01';

   -- Consulta 2: Filtro por cliente
   SELECT * FROM ventas WHERE cliente_id = 150 LIMIT 10;

   -- Consulta 3: JOIN con productos
   SELECT v.id, p.nombre FROM ventas v JOIN productos p ON v.producto_id = p.id
   WHERE v.fecha_venta >= '2024-06-01' LIMIT 20;

   -- Consulta 4: Búsqueda JSONB
   SELECT COUNT(*) FROM ventas WHERE metadata @> '{"canal": "tienda"}'::jsonb;

   -- Consulta 5: Ventas pendientes recientes
   SELECT * FROM ventas WHERE estado = 'pendiente' AND fecha_venta >= CURRENT_DATE - 30 LIMIT 10;

   -- Consulta 6: Ventas de alto valor
   SELECT cliente_id, SUM(precio_unitario) FROM ventas WHERE precio_unitario > 500 GROUP BY cliente_id;
   ```

2. Consulta las estadísticas de uso de índices:

   ```sql
   -- Reporte completo de uso de índices en la tabla ventas
   SELECT
       s.indexrelname AS indice,
       s.idx_scan AS veces_usado,
       s.idx_tup_read AS entradas_leidas,
       s.idx_tup_fetch AS filas_obtenidas,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS tamano_indice,
       CASE
           WHEN s.idx_scan = 0 THEN '⚠️  NUNCA USADO'
           WHEN s.idx_scan < 5 THEN '🔶 USO BAJO'
           ELSE '✅ USO ACTIVO'
       END AS estado_uso
   FROM pg_stat_user_indexes s
   WHERE s.schemaname = 'public'
     AND s.relname = 'ventas'
   ORDER BY s.idx_scan DESC;
   ```

3. Identifica índices potencialmente redundantes o innecesarios:

   ```sql
   -- Identificar índices con cero usos en todas las tablas del esquema
   SELECT
       s.relname AS tabla,
       s.indexrelname AS indice,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS espacio_desperdiciado,
       s.idx_scan AS veces_usado
   FROM pg_stat_user_indexes s
   JOIN pg_index i ON s.indexrelid = i.indexrelid
   WHERE s.schemaname = 'public'
     AND s.idx_scan = 0
     AND NOT i.indisprimary
     AND NOT i.indisunique
   ORDER BY pg_relation_size(s.indexrelid) DESC;
   ```

4. Analiza la relación entre tamaño de tabla e índices:

   ```sql
   -- Comparar tamaño de tabla vs tamaño total de sus índices
   SELECT
       t.relname AS tabla,
       pg_size_pretty(pg_relation_size(t.oid)) AS tamano_tabla,
       pg_size_pretty(
           COALESCE(SUM(pg_relation_size(i.indexrelid)), 0)
       ) AS tamano_total_indices,
       COUNT(i.indexrelid) AS cantidad_indices,
       ROUND(
           COALESCE(SUM(pg_relation_size(i.indexrelid)), 0)::numeric /
           NULLIF(pg_relation_size(t.oid), 0) * 100,
           1
       ) AS porcentaje_overhead_indices
   FROM pg_class t
   LEFT JOIN pg_index i ON t.oid = i.indrelid
   WHERE t.relkind = 'r'
     AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
   GROUP BY t.relname, t.oid
   ORDER BY pg_relation_size(t.oid) DESC;
   ```

5. Genera un reporte de recomendaciones de índices:

   ```sql
   -- Reporte de salud de índices
   SELECT
       'ELIMINAR - Nunca usado' AS recomendacion,
       s.relname AS tabla,
       s.indexrelname AS indice,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS tamano
   FROM pg_stat_user_indexes s
   JOIN pg_index i ON s.indexrelid = i.indexrelid
   WHERE s.schemaname = 'public'
     AND s.idx_scan = 0
     AND NOT i.indisprimary
     AND NOT i.indisunique

   UNION ALL

   SELECT
       'MANTENER - Alta actividad' AS recomendacion,
       s.relname AS tabla,
       s.indexrelname AS indice,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS tamano
   FROM pg_stat_user_indexes s
   WHERE s.schemaname = 'public'
     AND s.idx_scan > 10

   ORDER BY recomendacion, tamano DESC;
   ```

**Salida Esperada:**

```
-- Reporte de uso de índices en ventas:
          indice           | veces_usado | entradas_leidas | filas_obtenidas | tamano_indice |   estado_uso
---------------------------+-------------+-----------------+-----------------+---------------+----------------
 idx_ventas_fecha_venta    |          12 |          234567 |          189034 | 2208 kB       | ✅ USO ACTIVO
 idx_ventas_cliente_id     |           8 |           89012 |           78901 | 2208 kB       | ✅ USO ACTIVO
 idx_ventas_metadata_gin   |           4 |           45678 |           45678 | 8192 kB       | ✅ USO ACTIVO
 idx_ventas_pendientes_fecha|           3 |            4521 |            4521 | 312 kB        | ✅ USO ACTIVO
 idx_ventas_cliente_hash   |           2 |              50 |              50 | 1024 kB       | 🔶 USO BAJO
 idx_ventas_region_id      |           1 |           12345 |           12345 | 2208 kB       | 🔶 USO BAJO
```

**Verificación:**

- Confirma que los índices creados en pasos anteriores aparecen con `idx_scan > 0`
- Identifica al menos un índice con bajo uso como candidato a revisión
- Verifica que el overhead de índices en la tabla `ventas` no supera el 200% del tamaño de la tabla

---

### Paso 10: Visualizar Planes de Ejecución en pgAdmin 4

**Objetivo:** Usar el visualizador gráfico de planes de ejecución de pgAdmin 4 para interpretar visualmente la estructura del plan y identificar nodos costosos de forma más intuitiva.

**Instrucciones:**

1. Abre pgAdmin 4 en tu navegador (normalmente en `http://localhost:5050`):

   ```
   URL: http://localhost:5050
   Usuario: admin@admin.com (o el configurado en tu docker-compose)
   Contraseña: admin (o la configurada en tu entorno)
   ```

2. Navega hasta la base de datos `ventas_db` y abre el Query Tool (Herramienta de Consultas).

3. Ejecuta la siguiente consulta compleja en el Query Tool de pgAdmin:

   ```sql
   -- Consulta compleja para visualizar en pgAdmin
   SELECT
       r.nombre AS region,
       DATE_TRUNC('quarter', v.fecha_venta) AS trimestre,
       p.categoria AS categoria_producto,
       COUNT(*) AS total_ventas,
       SUM(v.cantidad * v.precio_unitario) AS ingresos_brutos,
       SUM(v.cantidad * v.precio_unitario * (1 - v.descuento)) AS ingresos_netos,
       COUNT(DISTINCT v.cliente_id) AS clientes_unicos,
       RANK() OVER (
           PARTITION BY r.nombre
           ORDER BY SUM(v.cantidad * v.precio_unitario) DESC
       ) AS ranking_trimestre
   FROM ventas v
   JOIN regiones r ON v.region_id = r.id
   JOIN productos p ON v.producto_id = p.id
   WHERE v.fecha_venta >= '2023-01-01'
     AND v.estado = 'completado'
   GROUP BY r.nombre, DATE_TRUNC('quarter', v.fecha_venta), p.categoria
   ORDER BY r.nombre, trimestre, ingresos_netos DESC;
   ```

4. En pgAdmin, en lugar de ejecutar con F5 (Run), usa **Explain** (F7) o **Explain Analyze** (Shift+F7) para ver el plan gráfico.

5. Observa el diagrama de árbol del plan de ejecución:
   - Los nodos más anchos representan mayor costo
   - El color indica el tipo de operación (azul=scan, verde=join, naranja=sort)
   - Haz clic en cada nodo para ver los detalles de costo y filas

6. Genera el plan en formato JSON para análisis externo:

   ```sql
   -- Plan completo en JSON para análisis con herramientas externas como explain.dalibo.com
   EXPLAIN (
       ANALYZE true,
       BUFFERS true,
       FORMAT JSON,
       VERBOSE true,
       SETTINGS true,
       WAL true
   )
   SELECT
       r.nombre AS region,
       DATE_TRUNC('quarter', v.fecha_venta) AS trimestre,
       p.categoria AS categoria_producto,
       COUNT(*) AS total_ventas,
       SUM(v.cantidad * v.precio_unitario) AS ingresos_netos
   FROM ventas v
   JOIN regiones r ON v.region_id = r.id
   JOIN productos p ON v.producto_id = p.id
   WHERE v.fecha_venta >= '2023-01-01'
     AND v.estado = 'completado'
   GROUP BY r.nombre, DATE_TRUNC('quarter', v.fecha_venta), p.categoria
   ORDER BY r.nombre, trimestre, ingresos_netos DESC;
   ```

   > 💡 **Tip:** Copia el output JSON y pégalo en [https://explain.dalibo.com](https://explain.dalibo.com) para una visualización interactiva avanzada del plan de ejecución.

**Salida Esperada:**

En pgAdmin verás un diagrama visual similar a:

```
[Nodo Raíz: Sort]
    └── [WindowAgg]
            └── [Sort]
                    └── [HashAggregate]
                            ├── [Hash Join]  ← nodo de mayor costo
                            │       ├── [Hash Join]
                            │       │       ├── [Index Scan: idx_ventas_fecha_venta] ← usa índice ✅
                            │       │       └── [Hash: regiones]
                            │       └── [Hash: productos]
```

**Verificación:**

- Confirma que puedes ver el diagrama gráfico del plan en pgAdmin (pestaña "Explain")
- Identifica visualmente el nodo de mayor costo (el más ancho o con mayor número)
- Verifica que el nodo de escaneo sobre `ventas` muestra "Index Scan" y no "Seq Scan"

---

## Validación y Pruebas

### Criterios de Éxito

- [ ] Se crearon al menos 6 índices diferentes: B-Tree simple, B-Tree compuesto, Hash, GIN, parcial por estado, y parcial por valor
- [ ] `EXPLAIN ANALYZE` muestra `Index Scan` (no `Seq Scan`) para consultas con filtro por `fecha_venta`, `cliente_id`, y `metadata @>`
- [ ] Los tiempos de ejecución de las consultas de prueba mejoraron al menos un 50% después de la indexación
- [ ] La vista materializada `mv_resumen_ventas_mensual` tiene al menos 3 índices y el plan usa `Index Scan`
- [ ] `pg_stat_user_indexes` muestra `idx_scan > 0` para los índices creados (evidencia de uso real)
- [ ] Se identificó al menos un índice con bajo o nulo uso mediante el reporte de `pg_stat_user_indexes`

### Procedimiento de Pruebas

1. Ejecuta la consulta de validación de índices creados:

   ```sql
   -- Verificar que todos los índices del laboratorio existen
   SELECT
       indexname AS indice,
       tablename AS tabla,
       indexdef AS definicion
   FROM pg_indexes
   WHERE schemaname = 'public'
     AND tablename IN ('ventas', 'mv_resumen_ventas_mensual')
     AND indexname NOT LIKE '%pkey'
   ORDER BY tablename, indexname;
   ```

   **Resultado Esperado:** Al menos 8 índices listados (excluyendo primary keys)

2. Ejecuta la prueba de rendimiento final comparativa:

   ```sql
   -- Prueba de rendimiento: debe usar índices en todos los nodos principales
   EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
   SELECT
       r.nombre AS region,
       COUNT(*) AS ventas_2024,
       SUM(v.cantidad * v.precio_unitario) AS ingresos,
       COUNT(DISTINCT v.cliente_id) AS clientes
   FROM ventas v
   JOIN regiones r ON v.region_id = r.id
   WHERE v.fecha_venta BETWEEN '2024-01-01' AND '2024-12-31'
     AND v.estado = 'completado'
     AND v.metadata @> '{"canal": "web"}'::jsonb
   GROUP BY r.nombre
   ORDER BY ingresos DESC;
   ```

   **Resultado Esperado:** El plan debe mostrar al menos `Index Scan` o `Bitmap Index Scan` en el nodo de escaneo de `ventas`, con tiempo de ejecución bajo 200ms

3. Verifica el uso activo de índices:

   ```sql
   -- Al menos 5 índices deben tener idx_scan > 0
   SELECT COUNT(*) AS indices_con_uso
   FROM pg_stat_user_indexes
   WHERE schemaname = 'public'
     AND relname = 'ventas'
     AND idx_scan > 0
     AND indexrelname NOT LIKE '%pkey';
   ```

   **Resultado Esperado:** `indices_con_uso >= 5`

4. Verifica la vista materializada con índices:

   ```sql
   -- La vista materializada debe tener índices y estar poblada
   SELECT
       matviewname,
       hasindexes,
       ispopulated,
       pg_size_pretty(pg_relation_size('public.' || matviewname)) AS tamano
   FROM pg_matviews
   WHERE schemaname = 'public'
     AND matviewname = 'mv_resumen_ventas_mensual';
   ```

   **Resultado Esperado:** `hasindexes = true`, `ispopulated = true`

---

## Solución de Problemas

### Problema 1: El Planificador Ignora el Índice y Sigue Usando Seq Scan

**Síntomas:**
- `EXPLAIN ANALYZE` muestra `Seq Scan` incluso después de crear el índice
- El tiempo de ejecución no mejora después de crear el índice
- El plan no menciona el nombre del índice creado

**Causa:**
El planificador de PostgreSQL puede preferir un Seq Scan cuando: (1) la tabla es pequeña y el Seq Scan es más rápido, (2) las estadísticas están desactualizadas, (3) la selectividad de la columna es baja (pocos valores distintos), o (4) el factor de correlación entre el índice y el orden físico de los datos es bajo.

**Solución:**

```sql
-- Paso 1: Actualizar estadísticas de la tabla
ANALYZE ventas;

-- Paso 2: Verificar el tamaño real de la tabla
SELECT
    relname,
    n_live_tup AS filas_estimadas,
    pg_size_pretty(pg_relation_size(oid)) AS tamano
FROM pg_class
WHERE relname = 'ventas';

-- Paso 3: Si la tabla tiene menos de 10,000 filas, el Seq Scan es normal y correcto
-- Para forzar el uso del índice en pruebas (NO usar en producción):
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM ventas WHERE fecha_venta >= '2024-01-01';
-- Restaurar siempre después de la prueba:
SET enable_seqscan = on;

-- Paso 4: Verificar que el índice existe y está válido
SELECT indexname, indisvalid
FROM pg_indexes
JOIN pg_index ON indexrelid = (
    SELECT oid FROM pg_class WHERE relname = indexname
)
WHERE tablename = 'ventas';
```

---

### Problema 2: Error "index already exists" al Crear un Índice

**Síntomas:**
- Mensaje: `ERROR: relation "idx_ventas_fecha_venta" already exists`
- El comando `CREATE INDEX` falla

**Causa:**
El índice ya fue creado previamente (posiblemente en una ejecución anterior del laboratorio o en un laboratorio previo).

**Solución:**

```sql
-- Opción 1: Verificar si el índice existe antes de crearlo
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'ventas'
          AND indexname = 'idx_ventas_fecha_venta'
    ) THEN
        EXECUTE 'CREATE INDEX CONCURRENTLY idx_ventas_fecha_venta ON ventas(fecha_venta)';
        RAISE NOTICE 'Índice creado exitosamente';
    ELSE
        RAISE NOTICE 'El índice ya existe, omitiendo creación';
    END IF;
END $$;

-- Opción 2: Eliminar y recrear (usar con precaución)
DROP INDEX IF EXISTS idx_ventas_fecha_venta;
CREATE INDEX CONCURRENTLY idx_ventas_fecha_venta ON ventas(fecha_venta);
```

---

### Problema 3: CREATE INDEX CONCURRENTLY Falla con Error de Transacción

**Síntomas:**
- Mensaje: `ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block`
- El error aparece cuando se ejecuta dentro de un bloque `BEGIN...COMMIT`

**Causa:**
`CREATE INDEX CONCURRENTLY` no puede ejecutarse dentro de una transacción explícita. Es una limitación de PostgreSQL ya que este comando necesita múltiples transacciones internas para funcionar.

**Solución:**

```sql
-- INCORRECTO: Dentro de una transacción
BEGIN;
CREATE INDEX CONCURRENTLY idx_ventas_fecha ON ventas(fecha_venta);  -- ERROR
COMMIT;

-- CORRECTO: Fuera de cualquier transacción (autocommit)
-- Asegúrate de NO estar dentro de un bloque BEGIN...COMMIT
CREATE INDEX CONCURRENTLY idx_ventas_fecha_venta ON ventas(fecha_venta);

-- Si necesitas agrupar múltiples índices, usa CREATE INDEX (sin CONCURRENTLY)
-- y acepta el bloqueo temporal de escrituras:
BEGIN;
CREATE INDEX idx_ventas_fecha_venta ON ventas(fecha_venta);
CREATE INDEX idx_ventas_cliente_id ON ventas(cliente_id);
COMMIT;
```

---

### Problema 4: REFRESH MATERIALIZED VIEW CONCURRENTLY Falla

**Síntomas:**
- Mensaje: `ERROR: cannot refresh materialized view "mv_resumen_ventas_mensual" concurrently`
- El error indica que se requiere un índice único

**Causa:**
`REFRESH MATERIALIZED VIEW CONCURRENTLY` requiere que exista al menos un índice `UNIQUE` sobre la vista materializada. Sin él, PostgreSQL no puede determinar qué filas han cambiado.

**Solución:**

```sql
-- Verificar si existe un índice único en la vista materializada
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'mv_resumen_ventas_mensual'
  AND indexdef LIKE '%UNIQUE%';

-- Si no existe, crear el índice único primero
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_resumen_unique
ON mv_resumen_ventas_mensual(region_id, mes);

-- Ahora el REFRESH CONCURRENTLY funcionará
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_ventas_mensual;

-- Alternativa: usar REFRESH sin CONCURRENTLY (bloquea lecturas temporalmente)
REFRESH MATERIALIZED VIEW mv_resumen_ventas_mensual;
```

---

### Problema 5: La Extensión pg_stat_statements No Está Disponible

**Síntomas:**
- Mensaje: `ERROR: extension "pg_stat_statements" is not available`
- O: `ERROR: could not open extension control file "/usr/share/postgresql/16/extension/pg_stat_statements.control"`

**Causa:**
La extensión `pg_stat_statements` requiere que esté habilitada en `postgresql.conf` mediante el parámetro `shared_preload_libraries` antes de que PostgreSQL inicie. No puede cargarse en caliente.

**Solución:**

```bash
# Paso 1: Modificar postgresql.conf dentro del contenedor
docker exec -it postgres_curso bash -c \
  "echo \"shared_preload_libraries = 'pg_stat_statements'\" >> /var/lib/postgresql/data/postgresql.conf"

# Paso 2: Reiniciar el contenedor para aplicar el cambio
docker restart postgres_curso

# Paso 3: Esperar que PostgreSQL inicie completamente
sleep 5

# Paso 4: Conectarse y crear la extensión
docker exec -it postgres_curso psql -U postgres -d ventas_db \
  -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# Verificar que la extensión está activa
docker exec -it postgres_curso psql -U postgres -d ventas_db \
  -c "SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';"
```

---

## Limpieza

Ejecuta los siguientes comandos para limpiar los objetos creados durante el laboratorio que no sean necesarios para laboratorios futuros:

```sql
-- Conectarse a la base de datos
-- docker exec -it postgres_curso psql -U postgres -d ventas_db

-- ============================================================
-- ÍNDICES A CONSERVAR (necesarios para laboratorios posteriores)
-- ============================================================
-- idx_ventas_fecha_venta    → Usado en Lab 06-00-01 (Power BI)
-- idx_ventas_cliente_id     → Usado en consultas de dashboard
-- idx_ventas_region_id      → Usado en reportes por región
-- idx_ventas_metadata_gin   → Usado en análisis JSONB
-- idx_mv_resumen_unique     → Requerido para REFRESH CONCURRENTLY

-- ============================================================
-- ÍNDICES OPCIONALES (eliminar si el espacio es una preocupación)
-- ============================================================

-- Eliminar índice Hash (redundante con el B-Tree de cliente_id)
DROP INDEX IF EXISTS idx_ventas_cliente_hash;

-- Eliminar índice compuesto de región+fecha (conservar si se usa en reportes)
-- DROP INDEX IF EXISTS idx_ventas_region_fecha;

-- ============================================================
-- LIMPIAR OBJETOS TEMPORALES DEL LABORATORIO
-- ============================================================

-- Eliminar tabla temporal de métricas (solo existe en la sesión actual)
DROP TABLE IF EXISTS metricas_rendimiento;

-- Restaurar configuración de JIT a su valor por defecto
SET jit = on;

-- ============================================================
-- VERIFICAR ESTADO FINAL
-- ============================================================

-- Confirmar índices que permanecen para laboratorios futuros
SELECT
    indexname AS indice,
    tablename AS tabla,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS tamano
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('ventas', 'mv_resumen_ventas_mensual')
  AND indexname NOT LIKE '%pkey'
ORDER BY tablename, indexname;
```

> ⚠️ **Advertencia:** No elimines los índices `idx_ventas_fecha_venta`, `idx_ventas_cliente_id`, `idx_ventas_region_id` ni `idx_ventas_metadata_gin`. Estos índices son fundamentales para el rendimiento de las consultas en el Laboratorio 06-00-01 (Power BI) y serán verificados al inicio de ese laboratorio.

> ⚠️ **Advertencia de Seguridad:** Las credenciales usadas en este laboratorio (`usuario: postgres`, `contraseña: postgres`) son exclusivamente para entornos de desarrollo local. **Nunca uses estas credenciales en un entorno de producción.** En producción, usa contraseñas seguras, roles con privilegios mínimos, y considera habilitar SSL para las conexiones a PostgreSQL.

---

## Resumen

### Lo que Lograste

- Configuraste el entorno de diagnóstico habilitando `pg_stat_statements` y estableciendo una línea base de rendimiento sin índices
- Analizaste planes de ejecución con `EXPLAIN` (estimado) y `EXPLAIN ANALYZE` (real) identificando Sequential Scans costosos en tablas de 100,000+ registros
- Creaste índices B-Tree sobre columnas de filtro frecuente (`fecha_venta`, `cliente_id`, `producto_id`, `region_id`) y verificaste la transición de Seq Scan a Index Scan
- Implementaste un índice Hash para búsquedas de igualdad exacta y comprendiste su limitación para consultas de rango
- Creaste un índice GIN sobre la columna `metadata` JSONB y observaste el uso de Bitmap Index Scan para búsquedas de contenido dentro de documentos JSON
- Diseñaste índices parciales para subconjuntos específicos de datos (ventas pendientes, ventas de alto valor), reduciendo el tamaño del índice y mejorando su eficiencia
- Optimizaste la vista materializada `mv_resumen_ventas_mensual` con índices cubrientes y habilitaste el refresco concurrente sin bloqueo de lecturas
- Monitoreaste el uso real de índices con `pg_stat_user_indexes` e identificaste índices candidatos para eliminación

### Conceptos Clave Aprendidos

- **Sequential Scan vs. Index Scan:** El planificador elige Seq Scan cuando la tabla es pequeña o la selectividad es baja; Index Scan cuando el índice filtra una fracción pequeña de las filas
- **Costo estimado vs. tiempo real:** `EXPLAIN` muestra costos relativos estimados; `EXPLAIN ANALYZE` muestra tiempos reales de ejecución. Siempre usar `ANALYZE` para diagnóstico real
- **Índices parciales:** Son más pequeños y eficientes que índices completos cuando las consultas siempre incluyen la misma condición de filtro
- **Índice GIN para JSONB:** El operador `@>` (contiene) requiere un índice GIN para ser eficiente; sin él, PostgreSQL debe deserializar cada documento JSON en un Seq Scan
- **Overhead de índices:** Cada índice adicional ralentiza las operaciones de escritura (`INSERT`, `UPDATE`, `DELETE`). El balance lectura/escritura es el criterio central de decisión
- **pg_stat_user_indexes:** La herramienta fundamental para auditar el uso real de índices y eliminar los que no aportan valor

### Próximos Pasos

- **Laboratorio 06-00-01:** Conectar Power BI Desktop a PostgreSQL usando el driver ODBC y construir dashboards que aprovechen los índices y vistas materializadas creadas en este laboratorio
- **Exploración adicional:** Investigar índices BRIN para la columna `fecha_venta` como alternativa más ligera para tablas de series de tiempo muy grandes
- **Práctica recomendada:** Ejecutar `REINDEX` sobre los índices fragmentados después de cargas masivas de datos usando el script generador de 500,000 registros mencionado en las consideraciones especiales del curso

---

## Recursos Adicionales

- **Documentación oficial de PostgreSQL - Índices:** Referencia completa sobre todos los tipos de índices, opciones de creación y comportamiento interno del planificador — [https://www.postgresql.org/docs/16/indexes.html](https://www.postgresql.org/docs/16/indexes.html)
- **Documentación de EXPLAIN:** Descripción detallada de todos los nodos de plan, opciones de formato y parámetros de EXPLAIN ANALYZE — [https://www.postgresql.org/docs/16/sql-explain.html](https://www.postgresql.org/docs/16/sql-explain.html)
- **pg_stat_user_indexes:** Referencia de la vista de sistema para monitoreo de uso de índices — [https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-INDEXES-VIEW](https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-ALL-INDEXES-VIEW)
- **Use The Index, Luke:** Guía práctica gratuita sobre indexación en bases de datos relacionales con ejemplos en PostgreSQL, incluyendo capítulos sobre planes de ejecución — [https://use-the-index-luke.com](https://use-the-index-luke.com)
- **explain.dalibo.com:** Herramienta web gratuita para visualizar planes de ejecución PostgreSQL en formato JSON de forma gráfica e interactiva — [https://explain.dalibo.com](https://explain.dalibo.com)
- **pgMustard:** Herramienta de análisis de planes de ejecución con recomendaciones automáticas de optimización — [https://www.pgmustard.com](https://www.pgmustard.com)

---

## Ejercicio de Reto (Evaluación Formativa)

> 🏆 **Reto – Nivel: Avanzado**
> 
> **Instrucción:** Sin consultar la solución del instructor, diseña e implementa una estrategia de indexación completa para el siguiente escenario:
> 
> El equipo de analítica ha identificado que la siguiente consulta tarda más de 5 segundos en ejecutarse y es llamada cada 30 segundos por el dashboard de Power BI:
> 
> ```sql
> SELECT
>     p.categoria,
>     p.subcategoria,
>     DATE_TRUNC('week', v.fecha_venta) AS semana,
>     COUNT(*) AS transacciones,
>     SUM(v.cantidad * v.precio_unitario * (1 - v.descuento)) AS ingresos_netos,
>     COUNT(DISTINCT v.cliente_id) AS clientes_activos,
>     AVG(v.cantidad * v.precio_unitario) AS ticket_promedio
> FROM ventas v
> JOIN productos p ON v.producto_id = p.id
> WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '90 days'
>   AND v.estado IN ('completado', 'pendiente')
>   AND p.activo = true
>   AND v.metadata @> '{"prioridad": "alta"}'::jsonb
> GROUP BY p.categoria, p.subcategoria, DATE_TRUNC('week', v.fecha_venta)
> ORDER BY semana DESC, ingresos_netos DESC;
> ```
> 
> **Tu tarea:**
> 1. Analiza el plan de ejecución actual con `EXPLAIN (ANALYZE, BUFFERS)`
> 2. Identifica todos los nodos de alto costo y explica por qué son costosos
> 3. Propone y crea una estrategia de indexación que incluya al menos: un índice compuesto, un índice parcial, y un índice GIN
> 4. Mide el tiempo de ejecución antes y después con `EXPLAIN ANALYZE`
> 5. Documenta el porcentaje de mejora obtenido y justifica cada índice creado
> 6. Evalúa si una vista materializada sería más apropiada que los índices para este caso de uso específico. Argumenta tu decisión.
> 
> **Criterio de éxito:** La consulta debe ejecutarse en menos de 500ms después de tu optimización.
> 
> **Entrega:** Script SQL comentado con la estrategia implementada y un párrafo explicando las decisiones tomadas.
