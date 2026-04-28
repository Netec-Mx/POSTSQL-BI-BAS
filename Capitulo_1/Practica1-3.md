
# Práctica 1.3 Consulta federada con Trino, PostgreSQL 18 y MySQL - Opcional

<br/><br/>

## Objetivo

Crear una arquitectura local con Docker donde:

* PostgreSQL 18 almacena información de clientes.
* MySQL 8 almacena información de compras.
* Trino consulta ambas fuentes.
* Trino ejecuta una consulta federada uniendo datos de PostgreSQL y MySQL.

<br/><br/>

## Instrucciones

### Crear red Docker

```bash
docker network create red_trino_lab
```

<br/><br/>

Verificar:

```bash
docker network ls
```

<br/><br/>

### Crear volúmenes

```bash
docker volume create pg18_data
docker volume create mysql_data
docker volume create trino_data
```

<br/><br/>

Verificar:

```bash
docker volume ls
```

<br/><br/>

### Levantar PostgreSQL 18

```bash
docker run -d ^
  --name postgres18_lab ^
  --network red_trino_lab ^
  -p 5432:5432 ^
  -e POSTGRES_USER=postgres ^
  -e POSTGRES_PASSWORD=postgres ^
  -e POSTGRES_DB=clientes_db ^
  -v pg18_data:/var/lib/postgresql ^
  postgres:18
```

En Linux/macOS:

```bash
docker run -d \
  --name postgres18_lab \
  --network red_trino_lab \
  -p 5432:5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=clientes_db \
  -v pg18_data:/var/lib/postgresql \
  postgres:18
```

<br/><br/>

Validar:

```bash
docker ps
docker logs postgres18_lab
```

<br/><br/>

### Crear tabla y datos en PostgreSQL

Entrar a PostgreSQL:

```bash
docker exec -it postgres18_lab psql -U postgres -d clientes_db
```

<br/><br/>

Crear tabla:

```sql
CREATE TABLE clientes (
    id_cliente INT PRIMARY KEY,
    nombre VARCHAR(50),
    ciudad VARCHAR(50)
);
```

<br/><br/>

Insertar datos:

```sql
INSERT INTO clientes (id_cliente, nombre, ciudad) VALUES
(1, 'Hugo', 'CDMX'),
(2, 'Paco', 'Guadalajara'),
(3, 'Luis', 'Monterrey'),
(4, 'Greta', 'Puebla');
```

<br/><br/>

Validar:

```sql
SELECT * FROM clientes;
```

<br/><br/>

Salir:

```sql
\q
```

<br/><br/>

### Levantar MySQL 8

```bash
docker run -d ^
  --name mysql8_lab ^
  --network red_trino_lab ^
  -p 3306:3306 ^
  -e MYSQL_ROOT_PASSWORD=root ^
  -e MYSQL_DATABASE=compras_db ^
  -v mysql_data:/var/lib/mysql ^
  mysql:8
```

En Linux/macOS:

```bash
docker run -d \
  --name mysql8_lab \
  --network red_trino_lab \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=compras_db \
  -v mysql_data:/var/lib/mysql \
  mysql:8
```

<br/><br/>

Validar:

```bash
docker ps
docker logs mysql8_lab
```

<br/><br/>

### Crear tabla y datos en MySQL

Entrar a MySQL:

```bash
docker exec -it mysql8_lab mysql -uroot -proot compras_db
```

<br/><br/>

Crear tabla:

```sql
CREATE TABLE compras (
    id_compra INT PRIMARY KEY,
    id_cliente INT,
    producto VARCHAR(50),
    monto DECIMAL(10,2)
);
```

<br/><br/>

Insertar datos:

```sql
INSERT INTO compras (id_compra, id_cliente, producto, monto) VALUES
(101, 1, 'Laptop', 18500.00),
(102, 2, 'Monitor', 4200.00),
(103, 3, 'Teclado', 850.00),
(104, 4, 'Mouse', 450.00),
(105, 1, 'Docking Station', 3200.00),
(106, 4, 'Audífonos', 1250.00);
```

<br/><br/>

Validar:

```sql
SELECT * FROM compras;
```

<br/><br/>

Salir:

```sql
exit;
```

<br/><br/>

### Crear carpeta local para catálogos de Trino

En Windows:

```bash
mkdir C:\users\netec\trino-lab
mkdir C:\users\netec\trino-lab\catalog
```

<br/><br/>

En Linux/macOS:

```bash
mkdir -p ~/trino-lab/catalog
```

<br/><br/>

### Crear catálogo de PostgreSQL para Trino

Crear archivo:

```text
C:\trino-lab\catalog\postgresql.properties
```

Contenido:

```properties
connector.name=postgresql
connection-url=jdbc:postgresql://postgres18_lab:5432/clientes_db
connection-user=postgres
connection-password=postgres
```

<br/><br/>

### Crear catálogo de MySQL para Trino

Crear archivo:

```text
C:\trino-lab\catalog\mysql.properties
```

Contenido:

```properties
connector.name=mysql
connection-url=jdbc:mysql://mysql8_lab:3306
connection-user=root
connection-password=root
```

<br/><br/>

### Levantar Trino

En Windows:

```bash
docker run -d ^
  --name trino_lab ^
  --network red_trino_lab ^
  -p 8080:8080 ^
  -v C:\trino-lab\catalog:/etc/trino/catalog ^
  -v trino_data:/data/trino ^
  trinodb/trino
```

En Linux/macOS:

```bash
docker run -d \
  --name trino_lab \
  --network red_trino_lab \
  -p 8080:8080 \
  -v ~/trino-lab/catalog:/etc/trino/catalog \
  -v trino_data:/data/trino \
  trinodb/trino
```

<br/><br/>

Validar:

```bash
docker ps
docker logs trino_lab
docker logs -f trino_lab
```

<br/><br/>

### Entrar a Trino CLI

```bash
docker exec -it trino_lab trino
```

<br/><br/>

### Validar catálogos

```sql
SHOW CATALOGS;
```

Resultado esperado:

```text
Catalog
----------
mysql
postgresql
system
```

<br/><br/>

### Validar esquemas

```sql
SHOW SCHEMAS FROM postgresql;
SHOW SCHEMAS FROM mysql;
```

<br/><br/>

### Consultar PostgreSQL desde Trino

```sql
SELECT *
FROM postgresql.public.clientes;
```

<br/><br/>

Resultado esperado:

```text
 id_cliente | nombre | ciudad
------------+--------+-------------
 1          | Hugo   | CDMX
 2          | Paco   | Guadalajara
 3          | Luis   | Monterrey
 4          | Greta  | Puebla
```

<br/><br/>

### Consultar MySQL desde Trino

```sql
SELECT *
FROM mysql.compras_db.compras;
```

<br/><br/>

Resultado esperado:

```text
 id_compra | id_cliente | producto        | monto
-----------+------------+-----------------+----------
 101       | 1          | Laptop          | 18500.00
 102       | 2          | Monitor         | 4200.00
 103       | 3          | Teclado         | 850.00
 104       | 4          | Mouse           | 450.00
 105       | 1          | Docking Station | 3200.00
 106       | 4          | Audífonos       | 1250.00
```

<br/><br/>

### Consulta federada

Esta consulta une datos que viven en dos motores diferentes:

* `clientes` está en PostgreSQL.
* `compras` está en MySQL.

```sql
SELECT
    c.id_cliente,
    c.nombre,
    c.ciudad,
    co.producto,
    co.monto
FROM postgresql.public.clientes c
JOIN mysql.compras_db.compras co
    ON c.id_cliente = co.id_cliente
ORDER BY c.id_cliente, co.id_compra;
```

<br/><br/>

Resultado esperado:

```text
 id_cliente | nombre | ciudad      | producto        | monto
------------+--------+-------------+-----------------+----------
 1          | Hugo   | CDMX        | Laptop          | 18500.00
 1          | Hugo   | CDMX        | Docking Station | 3200.00
 2          | Paco   | Guadalajara | Monitor         | 4200.00
 3          | Luis   | Monterrey   | Teclado         | 850.00
 4          | Greta  | Puebla      | Mouse           | 450.00
 4          | Greta  | Puebla      | Audífonos       | 1250.00
```

<br/><br/>

### Consulta federada con agregación

```sql
SELECT
    c.nombre,
    c.ciudad,
    COUNT(co.id_compra) AS total_compras,
    SUM(co.monto) AS monto_total
FROM postgresql.public.clientes c
JOIN mysql.compras_db.compras co
    ON c.id_cliente = co.id_cliente
GROUP BY c.nombre, c.ciudad
ORDER BY monto_total DESC;
```

<br/><br/>

Resultado esperado:

```text
 nombre | ciudad      | total_compras | monto_total
--------+-------------+---------------+-------------
 Hugo   | CDMX        | 2             | 21700.00
 Paco   | Guadalajara | 1             | 4200.00
 Greta  | Puebla      | 2             | 1700.00
 Luis   | Monterrey   | 1             | 850.00
```

<br/><br/>

### Notas:

- Trino no reemplaza a PostgreSQL ni a MySQL. Trino funciona como un motor de consulta distribuido.
- Cada base conserva sus propios datos, usuarios, archivos y almacenamiento.
- La consulta federada ocurre cuando Trino consulta varias fuentes al mismo tiempo y las presenta como si fueran parte de un mismo entorno SQL.
- La información se encuentra fuera del contenedor de Trino
- No fue necesario ningún ETL, o consolidar la información en el servidor de Trino


<br/><br/>

### Comandos útiles de diagnóstico

Ver contenedores:

```bash
docker ps
```

<br/><br/>

Ver redes:

```bash
docker network ls
```

<br/><br/>

Ver qué contenedores están en la red:

```bash
docker network inspect red_trino_lab
```

<br/><br/>

Ver logs de Trino:

```bash
docker logs trino_lab
```

<br/><br/>

Ver logs de PostgreSQL:

```bash
docker logs postgres18_lab
```

<br/><br/>

Ver logs de MySQL:

```bash
docker logs mysql8_lab
```

<br/><br/>

### Limpieza 

Detener contenedores:

```bash
docker stop trino_lab postgres18_lab mysql8_lab
```

<br/><br/>

Eliminar contenedores:

```bash
docker rm trino_lab postgres18_lab mysql8_lab
```

<br/><br/>

Eliminar volúmenes:

```bash
docker volume rm pg18_data mysql_data trino_data
```

<br/><br/>

Eliminar red:

```bash
docker network rm red_trino_lab
```

<br/><br/>

###  Punto clave para evitar el error con PostgreSQL 18

Incorrecto para PostgreSQL 18:

```bash
-v pg18_data:/var/lib/postgresql/data
```

Correcto para PostgreSQL 18:

```bash
-v pg18_data:/var/lib/postgresql
```

Esto evita el error relacionado con el cambio de estructura de datos en las imágenes oficiales de PostgreSQL 18+.
