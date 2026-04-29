
# Pocs. Uso de CTE vs CROSS JOIN 

<br/><br/>

## Objetivo

Comprender cómo combinar resultados agregados con valores globales utilizando:

* CTE (Common Table Expressions)
* `CROSS JOIN` como constante

<br/><br/>

## 1. Crear estructura temporal

```sql
CREATE TEMP TABLE ventas (
    fecha_venta DATE,
    monto NUMERIC
);
```

<br/><br/>

## 2. Insertar datos de prueba

```sql
INSERT INTO ventas VALUES
('2026-03-10', 100),
('2026-03-15', 200),
('2026-04-05', 150),
('2026-04-20', 250),
('2026-05-01', 300);
```

<br/><br/>

## 3. Versión con CTE (más legible)

```sql
WITH ventas_mensuales AS (
    SELECT 
        DATE_TRUNC('month', fecha_venta) AS mes,
        SUM(monto) AS total_mes
    FROM ventas
    GROUP BY mes
),
promedio_general AS (
    SELECT AVG(total_mes) AS promedio
    FROM ventas_mensuales
)
SELECT 
    vm.mes,
    vm.total_mes,
    round(pg.promedio,2),
    round(vm.total_mes - pg.promedio,2) AS diferencia
FROM ventas_mensuales vm,
     promedio_general pg
ORDER BY vm.mes;
```

<br/><br/>

### Observaciones

* `ventas_mensuales` agrega por mes
* `promedio_general` calcula un solo valor (1 fila)
* Al combinar:

```sql
FROM ventas_mensuales vm, promedio_general pg
```

Esto es **equivalente a un `CROSS JOIN`**

Pero como `pg` tiene **una sola fila**, se comporta como:

> **una constante que se replica para cada fila**

<br/><br/>

## 4. Versión equivalente usando solo JOINs

```sql
SELECT 
    vm.mes,
    vm.total_mes,
    round(pg.promedio,2),
    round(vm.total_mes - pg.promedio,2) AS diferencia
FROM (
    SELECT 
        DATE_TRUNC('month', fecha_venta) AS mes,
        SUM(monto) AS total_mes
    FROM ventas
    GROUP BY DATE_TRUNC('month', fecha_venta)
) vm
CROSS JOIN (
    SELECT 
        AVG(total_mes) AS promedio
    FROM (
        SELECT 
            DATE_TRUNC('month', fecha_venta) AS mes,
            SUM(monto) AS total_mes
        FROM ventas
        GROUP BY DATE_TRUNC('month', fecha_venta)
    ) t
) pg
ORDER BY vm.mes;
```

<br/><br/>

### Observaciones 

* Ambas consultas son **equivalentes**

* La diferencia es **forma, no resultado**

* La versión con CTE:

  * Más clara
  * Más reutilizable

* La versión con `CROSS JOIN`:

  * Más explícita en SQL puro
  * Útil para entender el motor

<br/><br/>

### Observaciones adicionales

> Un `CROSS JOIN` no siempre es “peligroso”
> Si una tabla tiene **1 sola fila**, actúa como una constante

<br/><br/>

### Verificación final

```sql
SELECT COUNT(*) FROM (
    SELECT DATE_TRUNC('month', fecha_venta)
    FROM ventas
    GROUP BY 1
) t;
```

Debe devolver **3 filas (3 meses)**
El promedio debe ser el mismo en todas las filas

<br/><br/>

### Pregunta 

> ¿Qué pasaría si `promedio_general` devolviera más de una fila?
>  `CROSS JOIN` se vuelve peligroso

<br/><br/>

---

# POCs: CROSS JOIN en PostgreSQL

## Objetivo

Entender cuándo un `CROSS JOIN`:

* Genera combinaciones (producto cartesiano)
* Se comporta como **constante distribuida**
* Puede ser peligroso 

<br/><br/>

##  POC 1: Producto cartesiano básico

<br/>

## 1. Datos

```sql
CREATE TEMP TABLE colores (color TEXT);
INSERT INTO colores VALUES ('Rojo'), ('Azul');

CREATE TEMP TABLE tallas (talla TEXT);
INSERT INTO tallas VALUES ('S'), ('M');
```

<br/>

## 2. CROSS JOIN

```sql
SELECT *
FROM colores
CROSS JOIN tallas;
```

<br/>

## Observaciones

> Filas resultado = 2 × 2 = 4
> Todas las combinaciones posibles

<br/><br/>

## POC 2: CROSS JOIN como constante

<br/>

## 1. Datos

```sql
CREATE TEMP TABLE ventas (
    producto TEXT,
    monto NUMERIC
);

INSERT INTO ventas VALUES
('A', 100),
('B', 200),
('C', 300);
```

<br/>

## 2. Consulta

```sql
SELECT 
    v.producto,
    v.monto,
    t.total
FROM ventas v
CROSS JOIN (
    SELECT SUM(monto) AS total FROM ventas
) t;
```

<br/>

### Observaciones

La subconsulta devuelve **1 fila**
Se replica en todas las filas

> CROSS JOIN = constante distribuida

<br/><br/>

## POC 3: Error común (explosión de filas)

<br/>

## 1. Datos adicionales

```sql
CREATE TEMP TABLE categorias (categoria TEXT);
INSERT INTO categorias VALUES ('X'), ('Y'), ('Z');
```

<br/>

## 2. CROSS JOIN

```sql
SELECT *
FROM ventas
CROSS JOIN categorias;
```

<br/>

## Observaciones

* 3 ventas × 3 categorías = 9 filas
* Esto escala muy rápido, podría ser un peligro real en producción

<br/><br/>

## POC 4: CROSS JOIN implícito (coma)

<br/>

### Consulta

```sql
SELECT *
FROM ventas v, categorias c;
```

<br/>

### Observaciones 

Esto es EXACTAMENTE lo mismo que:

```sql
SELECT *
FROM ventas v
CROSS JOIN categorias c;
```

<br/><br/>

## Recomendación

* Evitar en cursos:

```sql
FROM tabla1, tabla2
```

* Mejor práctica:

```sql
FROM tabla1
CROSS JOIN tabla2
```

> Más claro y explícito

<br/><br/>

## POC 5: CROSS JOIN + agregación (caso BI típico)

<br/>

```sql
SELECT 
    v.producto,
    v.monto,
    avg_data.promedio,
    v.monto - avg_data.promedio AS diferencia
FROM ventas v
CROSS JOIN (
    SELECT AVG(monto) AS promedio
    FROM ventas
) avg_data;
```

<br/>

### Observaciones

Este patrón es MUY usado en BI:

* Comparar contra promedio
* Comparar contra total
* KPIs

---

### Preguntas detonadoras

* ¿Qué pasa si ambas tablas tienen 1 millón de filas?
* ¿Cómo evitar un CROSS JOIN accidental?
* ¿En qué casos es correcto usarlo en BI?