
# Demo 4.1: Volatilidad de funciones en PostgreSQL (VOLATILE, STABLE, IMMUTABLE)

<br/><br/>

## Objetivo

Comprender cómo PostgreSQL optimiza consultas dependiendo de la volatilidad de las funciones, analizando:

* número de ejecuciones
* uso de índices
* impacto en rendimiento

<br/><br/>

## Conceptos

PostgreSQL clasifica las funciones según su **nivel de volatilidad**:

* VOLATILE, puede cambiar en cualquier momento
* STABLE, no cambia durante una consulta
* IMMUTABLE, nunca cambia

Esta clasificación afecta directamente:

* El plan de ejecución
* El uso de índices
* El costo de la consulta

<br/><br/>

## Instricciones

### 1. Preparación del entorno

```sql
DROP TABLE IF EXISTS demo_volatilidad;

CREATE TABLE demo_volatilidad (
    id SERIAL PRIMARY KEY,
    valor INTEGER
);

INSERT INTO demo_volatilidad (valor)
SELECT generate_series(1, 1000000);
```

<br/>

Resultado esperado: tabla con 1,000,000 registros.

<br/><br/>

### 2. Crear funciones con distinta volatilidad

#### Función VOLATILE

Una función VOLATITLE en PostgreSQL puede modificar la base de datos y devolver resultados diferentes en cada llamada con los mismos argumentos.

Ee la categoría predetermina, obliga al optimizador a reevaluar la función en cada fila. Ejemplos: incluye funciones con numéros aleatorios, timeofday(), o comandos INSERT/UPDATE/DELETE.

<br/>

```sql
CREATE OR REPLACE FUNCTION f_volatil(x INT)
RETURNS INT
LANGUAGE plpgsql
VOLATILE
AS $$
BEGIN
    RETURN x + (random() * 10)::INT;
END;
$$;
```

<br/><br/>

#### Función STABLE

En PostgreSQL, laSTABLE palabra clave es una categoría de volatilidad que se utiliza durante la creación de funciones para indicar al optimizador cómo se comporta la función en relación con el estado de la base de datos y la ejecución de la consulta. 

Una función marcada como STABLE:
- No se puede modificar la base de datos: no debe contener comandos como INSERT, UPDATE, o DELETE.
- Se garantiza que devolverá el mismo resultado para los mismos argumentos de entrada a lo largo de una única instrucción SQL.

```sql
CREATE OR REPLACE FUNCTION f_stable(x INT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN x + 10;
END;
$$;
```

<br/><br/>

#### Función IMMUTABLE

Una función INMUTABLE en PostgreSQL garantiza devolver el mismo resultado siempre que se la llame con los mismos valores de argumento.  

Una función marcada como IMMUTABLE:

- Función pura, se comporta como operaciones matemáticas, por ejemplo: 2 + 2, abs(-10)
- No puede contener comandos DML

<br/>

```sql
CREATE OR REPLACE FUNCTION f_inmutable(x INT)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN x + 10;
END;
$$;
```

<br/><br/>

### 3. Prueba 1: Evaluación directa

```sql
SELECT 
    f_volatil(10),
    f_volatil(10),
    f_volatil(10),
    f_stable(10),
    f_stable(10),
    f_stable(10),
    f_inmutable(10),
    f_inmutable(10),
    f_inmutable(10);
```

<br/>

Resultado esperado:

* VOLATILE cada invocación devuelve valores distintos
* STABLE devuelve los mismos valores
* IMMUTABLE devuelve los mismos valores

<br/><br/>

### 4. Prueba 2: Uso en filtro 

#### IMMUTABLE

```sql
EXPLAIN ANALYZE
SELECT *
FROM demo_volatilidad
WHERE valor = f_inmutable(50000);
```

<br/>

Observación:

* La función se evalúa una sola vez
* PostgreSQL usa índice o búsqueda directa
* Ejecución rápida

<br/>

#### STABLE

```sql
EXPLAIN ANALYZE
SELECT *
FROM demo_volatilidad
WHERE valor = f_stable(50000);
```

<br/>

Observación:

* Comportamiento muy similar a IMMUTABLE
* Evaluación una vez por consulta
* Diferencia poco visible en este caso

<br/>

#### VOLATILE

```sql
EXPLAIN ANALYZE
SELECT *
FROM demo_volatilidad
WHERE valor = f_volatil(50000);
```

<br/>

Observación:

* Evaluación por cada fila
* Seq Scan
* Alto costo

<br/><br/>

### 5. Prueba 3: Conteo de ejecuciones (debug)

#### Crear función con traza

```sql
CREATE OR REPLACE FUNCTION f_debug(x INT)
RETURNS INT
LANGUAGE plpgsql
VOLATILE
AS $$
BEGIN
    RAISE NOTICE 'Ejecutando %', x;
    RETURN x + 10;
END;
$$;
```

<br/>

```sql
SELECT *
FROM demo_volatilidad
WHERE valor = f_debug(50000);
```

<br/>

Observación:

* Se imprime muchas veces, una invocación por fila

<br/>

Cambiar a IMMUTABLE:

```sql
CREATE OR REPLACE FUNCTION f_debug(x INT)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RAISE NOTICE 'Ejecutando %', x;
    RETURN x + 10;
END;
$$;
```

<br/>

Observación:

* Se imprime una sola vez

<br/><br/>

### 6. Prueba 4: Índices

#### Crear índice con función IMMUTABLE

```sql
CREATE INDEX idx_demo_inmutable
ON demo_volatilidad (f_inmutable(valor));
```

<br/>

- Resultado esperado: creación exitosa.

<br/>

#### Intentar con VOLATILE

```sql
CREATE INDEX idx_demo_volatil
ON demo_volatilidad (f_volatil(valor));
```

<br/>

Resultado esperado:

- Error, solo funciones IMMUTABLE pueden indexarse.

<br/><br/>

### 7. Prueba 5: Uso del índice

```sql
EXPLAIN ANALYZE
SELECT *
FROM demo_volatilidad
WHERE f_inmutable(valor) = 50010;
```

<br/>

Observación:

* Uso de Index Scan
* Mejora significativa

<br/><br/>

### 8. Prueba 6: Medición con pg_stat_statements

Esta librería debe de configurarse en el contenedor Docker agregando en el Docker_compose

```bash
docker stop curso_postgres
docker rm curso_postgres
docker compose UP -d 
```

<br/>

```yaml
services:

  postgres:
    image: postgres:16
    container_name: curso_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: curso_db
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ./pgdata:/var/lib/postgresql/data
      - ./init:/docker-entrypoint-initdb.d   # Se agrega esta ruta para el desafío
    ports:
      - "5432:5432"
    networks:
      - curso_network
    command:
      postgres -c shared_preload_libraries=pg_stat_statements
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d curso_db"]
      interval: 10s
      timeout: 5s
      retries: 5

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: curso_pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: escamillablanca@gmail.com
      PGADMIN_DEFAULT_PASSWORD: admin123
      PGADMIN_CONFIG_SERVER_MODE: 'False'
    volumes:
      - ./pgadmin-data:/var/lib/pgadmin
    ports:
      - "8080:80"
    networks:
      - curso_network
    depends_on:
      postgres:
        condition: service_healthy

  trino:
    image: trinodb/trino
    container_name: trino
    ports:
      - "8090:8080"
    networks:
      - curso_network
    volumes:
      - ./trino/catalog:/etc/trino/catalog
    depends_on:
      postgres:
        condition: service_healthy

networks:
  curso_network:
    driver: bridge

```

<br/>

```sql
SELECT * FROM pg_extension;

CREATE EXTENSION pg_stat_statements;

SHOW shared_preload_libraries;

SELECT current_database();

SELECT * FROM pg_extension;

-- Consulta de estadísticas de uso
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time
FROM pg_stat_statements
WHERE query LIKE '%demo_volatilidad%';
```

<br/>

Observaciones:

* IMMUTABLE debe de ser bajo tiempo
* VOLATILE considerablemente mas alto tiempo
* No mide funciones internas
* Mide impacto total de la consulta

<br/><br/>

### 9. Conclusión

<br/>

| Tipo      | Evaluación   | Índices | Rendimiento |
| --------- | ------------ | ------- | ----------- |
| VOLATILE  | por fila     | No      | Bajo        |
| STABLE    | por consulta | No      | Medio       |
| IMMUTABLE | pre-cálculo  | Sí      | Alto        |

<br/>