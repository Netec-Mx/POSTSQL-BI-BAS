
# Práctica 1.2 Imagen Docker Personalizada de PostgreSQL - Opcional

<br/>

## Objetivos

Al finalizar esta práctica, serás capaz de:

- Crear una imagen personalizada de PostgreSQL
- Inicializar automáticamente una base de datos
- Persistir datos correctamente
- Generar contenedores desde tu imagen
- Publicar la imagen en Docker Hub

<br/>

## Instrucciones

### 1. Estructura del proyecto

Crea una carpeta:

```bash
mkdir postgres-custom
cd postgres-custom
```

Estructura:

```bash
postgres-custom/
│
├── Dockerfile
├── init.sql
└── postgresql.conf
```

<br/><br/>

### 2. Script de inicialización (`init.sql`)

Este archivo se ejecuta automáticamente al crear el contenedor por primera vez:

```sql
CREATE DATABASE demo_db;

\c demo_db;

CREATE TABLE clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    ciudad VARCHAR(100),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO clientes (nombre, ciudad) VALUES
('Hugo', 'CDMX'),
('Paco', 'Guadalajara'),
('Luis', 'Monterrey');
```

<br/><br/>

### 3. Configuración personalizada (`postgresql.conf`)

Configuración sencillo para el POC:

```conf
max_connections = 150
shared_buffers = 256MB
work_mem = 8MB
maintenance_work_mem = 64MB
log_statement = 'all'
```

<br/><br/>

### 4. Dockerfile personalizado

```dockerfile
FROM postgres:18

# Variables por defecto
ENV POSTGRES_USER=admin
ENV POSTGRES_PASSWORD=admin
ENV POSTGRES_DB=postgres

# Copiar script de inicialización
COPY init.sql /docker-entrypoint-initdb.d/

# Copiar configuración personalizada
COPY postgresql.conf /etc/postgresql/postgresql.conf

# Sobrescribir config por defecto
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
```

<br/><br/>

### 5. Construcción de la imagen

```bash
docker build -t tu_usuario/postgres-custom:1.0 .
```

Ejemplo real:

```bash
docker build -t blankiss/postgres-custom:1.0 .
```

<br/><br/>

### 6. Crear contenedor con persistencia

Primero crea volumen:

```bash
docker volume create pgdata_custom
```

Ahora levanta el contenedor:

```bash
docker run -d --name postgres_custom  -p 5555:5432   -v pgdata_custom:/var/lib/postgresql tu_usuario/postgres-custom:1.0
```

> Nota: Para PostgreSQL 16 -v pgdata_custom:/var/lib/postgresql

<br/><br/>

### 7. Validación

Entrar al contenedor:

```bash

netstat -ano | grep 5555

docker exec -it postgres_custom psql -U admin -d demo_db

```

Consulta:

```sql
\l

\dt

\d clientes

SELECT * FROM clientes;

```

<br/>

> Debes ver los datos insertados automáticamente

<br/><br/>

### 8. Prueba de persistencia

```bash
docker stop postgres_custom
docker rm postgres_custom
```

Levantar de nuevo:

```bash
docker run -d --name postgres_custom -p 5555:5432 -v pgdata_custom:/var/lib/postgresql/data tu_usuario/postgres-custom:1.0
```

<br/>

> Los datos **siguen existiendo** (no se vuelve a ejecutar `init.sql`)

<br/><br/>

### 9. Publicar en Docker Hub

#### Login

```bash
docker login
```

<br/><br/>

#### Etiquetar imagen

```bash
docker tag tu_usuario/postgres-custom:1.0 tu_usuario/postgres-custom:latest
```

<br/><br/>

### Subir imagen

```bash
docker push tu_usuario/postgres-custom:1.0
docker push tu_usuario/postgres-custom:latest
```

<br/><br/>

### 10. Uso desde otra máquina

```bash

docker pull tu_usuario/postgres-custom:latest

docker run -d --name postgres_custom -p 5432:5432 -v pgdata_custom:/var/lib/postgresql/data tu_usuario/postgres-custom:latest

```

<br/><br/>

### Notas

**¿Qué acabamos de hacer realmente?**

* Creamos una imagen basada en `postgres`

* Inyectamos:
  * esquema inicial (`init.sql`)
  * configuración (`postgresql.conf`)

* Generamos un contenedor reutilizable

* Separamos:
  * **imagen = plantilla**
  * **volumen = datos**

* Publicamos la imagen → reutilizable globalmente


<br/><br/>

## Conceptos Importantes

| Concepto                       | Explicación                       |
| ------------------------------ | --------------------------------- |
| `/docker-entrypoint-initdb.d/` | Solo se ejecuta en inicialización |
| Volumen                        | Evita pérdida de datos            |
| Imagen personalizada           | Estandariza entornos              |
| Docker Hub                     | Distribución                      |

