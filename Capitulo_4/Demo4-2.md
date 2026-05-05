Aquí tienes una **demo / POC completa** para usar una función en **PL/Python en 
#  Demo 4.2: Uso de funciones PL/Python en PostgreSQL

<br/><br/>

### 1. Verificar si PL/Python está disponible

```sql
-- Ver extensiones disponibles relacionadas con Python
SELECT * 
FROM pg_available_extensions
WHERE name LIKE '%python%';
```

Debes ver algo como:

* `plpython3u` (la más común)

<br/><br/>

### 2. Habilitar la extensión

```sql
CREATE EXTENSION plpython3u;
```

Notas:

* La `u` significa **untrusted** (no restringida)
* Requiere permisos de superusuario

<br/><br/>

### 3. Crear una función simple en PL/Python

```sql
CREATE OR REPLACE FUNCTION f_saludo(nombre TEXT)
RETURNS TEXT
AS $$
    return "Hola, " + nombre + " desde Python!"
$$ LANGUAGE plpython3u;
```

<br/><br/>

### 4. Ejecutar la función

```sql
SELECT f_saludo('TIGO');
```

Resultado esperado:

```
Hola, TIGO desde Python!
```

<br/><br/>

### POC 2: Lógica más útil (limpieza de datos)

Supongamos que tienes datos con caracteres mixtos y quieres **extraer solo números**.

<br/><br/>

### 5. Función para limpiar texto

```sql
CREATE OR REPLACE FUNCTION f_extraer_numeros(texto TEXT)
RETURNS TEXT
AS $$
    import re
    return ''.join(re.findall(r'\d+', texto))
$$ LANGUAGE plpython3u;
```

<br/><br/>

### 6. Probar la función

```sql
SELECT f_extraer_numeros('ABC123XYZ456');
```

esultado:

```
123456
```

<br/><br/>

## POC 3: Uso en un JOIN (TIGO)

### 7. Crear tablas de ejemplo

```sql
CREATE TABLE t_A (
    id SERIAL,
    codigo TEXT
);

CREATE TABLE t_B (
    id SERIAL,
    codigo_numerico INT
);

INSERT INTO t_A (codigo) VALUES
('A-100'),
('B-200'),
('C-300');

INSERT INTO t_B (codigo_numerico) VALUES
(100),
(200),
(400);
```

<br/><br/>

### 8. JOIN usando la función en PL/Python

```sql
SELECT a.codigo, b.codigo_numerico
FROM t_A a
JOIN t_B b
  ON f_extraer_numeros(a.codigo)::INT = b.codigo_numerico;
```

Resultado esperado:

```
A-100 | 100
B-200 | 200
```

<br/><br/>

### Función con lógica analítica

Ejemplo tipo BI, clasificar clientes.

```sql
CREATE OR REPLACE FUNCTION f_clasificar_monto(monto NUMERIC)
RETURNS TEXT
AS $$
    if monto < 100:
        return "Bajo"
    elif monto < 500:
        return "Medio"
    else:
        return "Alto"
$$ LANGUAGE plpython3u;
```

<br/><br/>

### Uso:

```sql
SELECT 
    monto,
    f_clasificar_monto(monto)
FROM (VALUES (50), (200), (800)) AS t(monto);
```

<br/><br/>

### Consideraciones importantes  

* `plpython3u` es **no confiable**, esto es, puede ejecutar código Python real
* No es recomendable en entornos productivos sin control
* Puede acceder a:

  * librerías Python
  * sistema operativo (dependiendo configuración)

<br/><br/>

### Casos de uso reales 

* Limpieza de datos (regex)
* Transformaciones complejas (JSON, texto)
* Normalización previa a JOINs (TIGO)

<br/><br/>

## Conclusión 

PL/Python sirve cuando:

* SQL es insuficiente o muy complejo
* Necesitas lógica avanzada (regex, parsing, etc.)

Pero:

* Debe usarse con cuidado por seguridad y performance


<br/><br/>

## En caso de no contar con PL Python

Cuando ejecutas `CREATE EXTENSION plpython3u;` y marca error significa:

* PostgreSQL no encuentra la extensión 
* No basta con `CREATE EXTENSION`
* Primero se instala el paquete a nivel S.O.

Ese error no es de SQL… es de **instalación a nivel sistema operativo / contenedor**.
PostgreSQL *sí soporta* PL/Python, pero tu instalación **no tiene el paquete instalado**.



## Opción 1: Docker 

Si usas imagen `postgres:16`, **NO incluye PL/Python por defecto**.

###  Instalar dentro del contenedor

```bash
docker exec -it curso_postgres bash
```

Luego dentro:

```bash
apt update
apt install -y postgresql-plpython3-16
```

Salir:

```bash
exit
```

<br/><br/>

### Crear imagenes Docker customizadas

```dockerfile
FROM postgres:16

RUN apt update &&  apt install -y postgresql-plpython3-16
```

Construir:

```bash
docker build -t postgres-plpython .
```

Ejecutar:

```bash

docker run -d --name postgres_py -e POSTGRES_PASSWORD=postgres -p 5432:5432  postgres-plpython

```

<br/><br/>

### Linux (fuera de Docker)

* Debian / Ubuntu

```bash
sudo apt update
sudo apt install postgresql-plpython3-16
```

* RedHat / CentOS / Rocky

```bash
sudo dnf install postgresql16-plpython3
```

### Windows

El instalador oficial de PostgreSQL (EDB) **NO incluye PL/Python por defecto**

Opciones:

1. Reinstalar PostgreSQL y marcar **PL/Python**
2. Usar Docker (más fácil para entornos de prueba)

<br/><br/>

### Después de instalar

Vuelve a PostgreSQL:

```sql
CREATE EXTENSION plpython3u;
```

Verifica:

```sql
SELECT lanname 
FROM pg_language;
```

Debe aparecer:

```text
plpython3u
```

