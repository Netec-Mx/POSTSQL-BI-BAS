
# Demo. Recursividad con CTE en PostgreSQL

<br/><br/>

### 1. Crear estructura

```sql
CREATE TABLE empleados (
    id INT PRIMARY KEY,
    nombre TEXT,
    jefe_id INT
);
```

<br/><br/>

### 2. Insertar datos

```sql
INSERT INTO empleados (id, nombre, jefe_id) VALUES
(1, 'CEO', NULL),
(2, 'Gerente Ventas', 1),
(3, 'Gerente TI', 1),
(4, 'Ventas 1', 2),
(5, 'Ventas 2', 2),
(6, 'Dev 1', 3),
(7, 'Dev 2', 3),
(8, 'Intern TI', 6);
```

<br/><br/>

### 3. Consulta con CTE Recursiva

```sql
WITH RECURSIVE jerarquia AS (
    
    -- Caso base, stop de la recursión (nivel 1)
    SELECT 
        id,
        nombre,
        jefe_id,
        1 AS nivel,
        nombre::TEXT AS ruta
    FROM empleados
    WHERE jefe_id IS NULL

    UNION ALL

    -- Parte recursiva
    SELECT 
        e.id,
        e.nombre,
        e.jefe_id,
        j.nivel + 1,
        j.ruta || ' -> ' || e.nombre
    FROM empleados e
    INNER JOIN jerarquia j   -- estamos dentro de CTE
        ON e.jefe_id = j.id
)
SELECT * 
FROM jerarquia
ORDER BY nivel, id;
```


<br/><br/>

### Resultado esperado

| id | nombre         | jefe_id | nivel | ruta                          |
| -- | -------------- | ------- | ----- | ----------------------------- |
| 1  | CEO            | NULL    | 1     | CEO                           |
| 2  | Gerente Ventas | 1       | 2     | CEO -> Gerente Ventas         |
| 3  | Gerente TI     | 1       | 2     | CEO -> Gerente TI             |
| 4  | Ventas 1       | 2       | 3     | CEO -> Gerente Ventas -> ...  |
| 8  | Intern TI      | 6       | 4     | CEO -> Gerente TI -> Dev 1... |


<br/><br/>

### Notas

Una CTE recursiva tiene **dos partes obligatorias**:

* **Caso base** → punto de inicio (raíz)
* **Parte recursiva** → se llama a sí misma

<br/>

### Reglas importantes

* Usar `UNION ALL` (no `UNION`)
* La recursividad termina cuando ya no hay coincidencias
* El `JOIN` debe hacerse contra la CTE


<br/>

### Variaciones útiles

### 1. Obtener solo un subárbol

```sql
WHERE id = 3  -- Gerente TI
```

<br/>

### 2. ¿Cuántos niveles tiene la jerarquía?

```sql
SELECT MAX(nivel) FROM jerarquia;
```

<br/>

### 3. Detectar empleados sin subordinados

```sql
SELECT *
FROM jerarquia j
WHERE NOT EXISTS (
    SELECT 1 
    FROM empleados e 
    WHERE e.jefe_id = j.id
);
```

<br/>

### Errores comunes

* Olvidar `UNION ALL`
* No definir condición de parada → loops infinitos
* Usar `JOIN` incorrecto (debe ser hacia la CTE)
* No incluir columna de control (`nivel`, `ruta`)

