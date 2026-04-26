# Práctica 1: Instalación de imagen PostgreSQL en Docker

<br/><br/>

## Objetivos

Al completar esta práctica, serás capaz de:

- Verificar que Docker Desktop está correctamente instalado y configurado en tu sistema operativo
- Crear un archivo `docker-compose.yml` que levante simultáneamente PostgreSQL 16 y pgAdmin 4 con volúmenes persistentes
- Conectarse a la instancia de PostgreSQL usando `psql` desde dentro del contenedor Docker
- Explorar la base de datos usando los meta-comandos básicos de `psql`: `\l`, `\c`, `\dt`, `\d`, `\h` y `\?`
- Conectarse a PostgreSQL desde pgAdmin 4 a través del navegador web
- Identificar los componentes principales de la arquitectura de PostgreSQL: postmaster, shared buffers, WAL, query planner y storage engine


<br/><br/>

## Objetivo Visual

![Docker Compose Lab](../images/i1.png)


<br/><br/>

## Prerrequisitos

### Conocimiento Requerido

- Uso básico de la línea de comandos (bash en Linux/macOS o PowerShell/CMD en Windows)
- Comprensión básica de conceptos de bases de datos relacionales (tablas, filas, columnas)
- Familiaridad con la edición de archivos de texto plano (cualquier editor de texto)
- Haber revisado la Lección 1.1 sobre el proyecto y la comunidad PostgreSQL

### Acceso y Software Requerido

- Permisos de administrador en el sistema operativo (necesario para instalar Docker Desktop)
- Docker Desktop 4.25.0 o superior descargado desde [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
- Conexión a internet para descargar las imágenes Docker de Docker Hub
- Al menos 20 GB de espacio libre en disco
- Al menos 8 GB de RAM en el sistema


<br/><br/>

## Entorno para prácticas

### Requerimientos de Hardware

| Componente | Especificación Mínima | Especificación Recomendada |
|------------|----------------------|---------------------------|
| Procesador | Intel Core i5 / AMD Ryzen 5 (8va gen) | Intel Core i7 / AMD Ryzen 7 |
| RAM | 8 GB | 16 GB |
| Almacenamiento | 20 GB libres (HDD) | 20 GB libres (SSD) |
| Sistema Operativo | Windows 10 64-bit / macOS 12 / Ubuntu 20.04 | Windows 11 / macOS 13+ / Ubuntu 22.04 |
| Virtualización | Habilitada en BIOS/UEFI | Habilitada en BIOS/UEFI |

<br/><br/>

### Requerimientos de Software

| Software | Versión | Propósito |
|----------|---------|-----------|
| Docker Desktop | 4.25.0 o superior | Plataforma de contenedores |
| Docker Compose | 2.x (incluido en Docker Desktop) | Orquestación multi-contenedor |
| PostgreSQL (imagen Docker) | `postgres:16` (oficial) | Motor de base de datos |
| pgAdmin 4 (imagen Docker) | `dpage/pgadmin4:latest` | Interfaz gráfica web |
| Editor de texto | VS Code 1.85+ recomendado | Edición de archivos YAML y SQL |
| Navegador web | Chrome, Firefox o Edge (reciente) | Acceso a pgAdmin 4 |

<br/><br/>

### Configuración Inicial de Docker Desktop

Antes de comenzar los pasos de la práctica, configura los límites de memoria de Docker Desktop para evitar que consuma todos los recursos del sistema:

**En Windows y macOS (Docker Desktop con interfaz gráfica):**

1. Abre Docker Desktop
2. Ve a **Settings** (ícono de engranaje) → **Resources** → **Advanced**
3. Configura los siguientes valores según tu RAM disponible:

| RAM del sistema | Memory para Docker | CPUs para Docker |
|----------------|-------------------|-----------------|
| 8 GB | 4 GB | 2 |
| 16 GB | 8 GB | 4 |
| 32 GB o más | 12 GB | 6 |

4. Haz clic en **Apply & Restart**

**En Linux (Docker Engine sin Docker Desktop):**

En Linux no se aplican límites de la misma forma, pero puedes configurar `--memory` en el `docker-compose.yml` si es necesario (se muestra en el Paso 3).

<br/><br/>

## Instrucciones

### Paso 1: Verificar la instalación de Docker Desktop

1. Abre una terminal (PowerShell en Windows, Terminal en macOS, o bash en Linux).

2. Verifica la versión de Docker instalada:

   ```bash
   docker --version
   ```

3. Verifica que Docker Compose está disponible:

   ```bash
   docker compose version
   ```

4. Confirma que el daemon de Docker está en ejecución ejecutando un contenedor de prueba:

   ```bash
   docker run --rm hello-world
   ```

5. Verifica que puedes descargar imágenes de Docker Hub (esto también prueba tu conexión a internet):

   ```bash
   docker pull postgres:16
   ```


<br/>

**Verificación:**

- [ ] El comando `docker --version` muestra la versión 4.25.0 o superior
- [ ] El comando `docker compose version` muestra la versión 2.x
- [ ] El contenedor `hello-world` se ejecutó y mostró el mensaje de bienvenida
- [ ] La imagen `postgres:16` se descargó correctamente


> **Si Docker no está instalado:** Descarga Docker Desktop desde [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop), instálalo siguiendo el asistente y asegúrate de habilitar la virtualización en tu BIOS/UEFI si se te solicita. En Windows, Docker Desktop puede requerir activar WSL2 o Hyper-V.


<br/><br/>


### Paso 2: Crear la estructura de directorios del proyecto

1. Crea el directorio raíz del curso y navega hacia él:

   **En Linux/macOS:**
   ```bash
   mkdir -p ~/curso-postgresql/lab-01
   cd ~/curso-postgresql/lab-01
   ```

   **En Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\curso-postgresql\lab-01"
   Set-Location "$env:USERPROFILE\curso-postgresql\lab-01"
   ```

2. Crea los subdirectorios para datos persistentes:

   **En Linux/macOS:**
   ```bash
   mkdir -p pgdata pgadmin-data
   ```

   **En Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "pgdata"
   New-Item -ItemType Directory -Force -Path "pgadmin-data"
   ```

3. Verifica la estructura creada:

   **En Linux/macOS:**
   ```bash
   ls -la
   ```

   **En Windows (PowerShell):**
   ```powershell
   Get-ChildItem
   ```


<br/>

**Verificación:**

- [ ] El directorio `~/curso-postgresql/lab-01` (o su equivalente en Windows) fue creado
- [ ] Los subdirectorios `pgdata` y `pgadmin-data` existen dentro de `lab-01`


<br/><br/>


### Paso 3: Crear el archivo docker-compose.yml


1. Asegúrate de estar en el directorio `lab-01`:

   **En Linux/macOS:**
   ```bash
   pwd
   # Debe mostrar: /home/tu-usuario/curso-postgresql/lab-01
   ```

   **En Windows (PowerShell):**
   ```powershell
   Get-Location
   # Debe mostrar: C:\Users\TuUsuario\curso-postgresql\lab-01
   ```

2. Crea el archivo `docker-compose.yml` con el siguiente contenido. **Usa el ejemplo correspondiente a tu sistema operativo:**

   **Para Linux y macOS** — crea el archivo `docker-compose.yml`:

   ```yaml
   version: '3.8'

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
       ports:
         - "5432:5432"
       networks:
         - curso_network
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
         PGADMIN_DEFAULT_EMAIL: admin@curso.com
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

   networks:
     curso_network:
       driver: bridge
   ```


   **Para Windows (PowerShell)** — crea el archivo `docker-compose.yml` (los paths de volúmenes usan notación relativa, compatible con WSL2):

   ```yaml
   version: '3.8'

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
       ports:
         - "5432:5432"
       networks:
         - curso_network
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
         PGADMIN_DEFAULT_EMAIL: admin@curso.local
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

   networks:
     curso_network:
       driver: bridge
   ```

<br/>

   > **Nota sobre los paths en Windows con WSL2:** Si usas Docker Desktop con WSL2 en Windows, los paths relativos (`./pgdata`) funcionan correctamente. Si experimentas problemas de permisos con los volúmenes, consulta la sección de Solución de Problemas al final de esta práctica.


3. Verifica que el archivo fue creado correctamente mostrando su contenido:

   **En Linux/macOS:**
   ```bash
   cat docker-compose.yml
   ```

   **En Windows (PowerShell):**
   ```powershell
   Get-Content docker-compose.yml
   ```

<br/>

**Verificación:**

- [ ] El archivo `docker-compose.yml` existe en el directorio `lab-01`
- [ ] El contenido del archivo muestra los dos servicios: `postgres` y `pgadmin`
- [ ] Los puertos configurados son `5432` para PostgreSQL y `8080` para pgAdmin
- [ ] Los volúmenes apuntan a los directorios `./pgdata` y `./pgadmin-data` creados en el Paso 2

<br/>

> **Explicación de las variables de entorno clave:**
> - `POSTGRES_USER`: Usuario administrador de PostgreSQL
> - `POSTGRES_PASSWORD`: Contraseña del usuario administrador (**solo para desarrollo**)
> - `POSTGRES_DB`: Base de datos que se crea automáticamente al iniciar
> - `PGDATA`: Ruta interna donde PostgreSQL almacena sus archivos de datos
> - `PGADMIN_DEFAULT_EMAIL`: Credencial de acceso a la interfaz web de pgAdmin
> - `PGADMIN_CONFIG_SERVER_MODE: 'False'`: Permite usar pgAdmin sin autenticación de servidor (modo desktop)


<br/><br/>


### Paso 4: Levantar los contenedores con Docker Compose

1. Desde el directorio `lab-01`, levanta los contenedores en modo detached (segundo plano):

   ```bash
   docker compose up -d
   ```

2. Observa el progreso de la descarga e inicio. Si las imágenes no estaban descargadas previamente, Docker las descargará de Docker Hub:

   ```bash
   docker compose logs -f
   ```

   Presiona `Ctrl+C` para salir del seguimiento de logs cuando veas que los servicios están listos.

3. Verifica el estado de los contenedores:

   ```bash
   docker compose ps
   ```

4. Verifica específicamente el healthcheck de PostgreSQL:

   ```bash
   docker inspect curso_postgres --format='{{.State.Health.Status}}'
   ```

<br/>


**Verificación:**

- [ ] Ambos contenedores (`curso_postgres` y `curso_pgadmin`) aparecen con estado `Up`
- [ ] El contenedor de PostgreSQL muestra `(healthy)` en la columna STATUS
- [ ] El puerto `5432` está mapeado correctamente para PostgreSQL
- [ ] El puerto `8080` está mapeado correctamente para pgAdmin

<br/>

> **Tiempo de espera:** pgAdmin puede tardar entre 30 y 60 segundos en estar completamente disponible después de que PostgreSQL pase su healthcheck. Si el contenedor de pgAdmin muestra `starting` en lugar de `Up`, espera unos segundos y vuelve a ejecutar `docker compose ps`.


<br/><br/>


### Paso 5: Conectarse a PostgreSQL con psql desde el contenedor

1. Abre una sesión interactiva de `psql` dentro del contenedor de PostgreSQL:

   ```bash
   docker exec -it curso_postgres psql -U postgres -d curso_db
   ```

2. Verifica la versión de PostgreSQL conectada:

   ```sql
   SELECT version();
   ```

3. Lista todas las bases de datos disponibles:

   ```
   \l
   ```

4. Conéctate a la base de datos `curso_db` (ya deberías estar en ella, pero practica el comando):

   ```
   \c curso_db
   ```

5. Lista las tablas del esquema actual (estará vacío por ahora):

   ```
   \dt
   ```

6. Explora los esquemas disponibles:

   ```
   \dn
   ```

7. Lista los usuarios/roles de PostgreSQL:

   ```
   \du
   ```

8. Obtén ayuda sobre los comandos SQL disponibles:

   ```
   \h SELECT
   ```

9. Obtén ayuda sobre todos los meta-comandos de psql:

   ```
   \?
   ```

   Presiona `q` para salir del paginador de ayuda.

10. Ejecuta una consulta SQL para verificar la conectividad con el servidor:

    ```sql
    SELECT current_database(), current_user, inet_server_addr(), inet_server_port();
    ```

11. Sal de psql:

    ```
    \q
    ```

<br/>

**Verificación:**

- [ ] La conexión a `psql` se estableció sin errores
- [ ] `SELECT version()` muestra PostgreSQL 16.x
- [ ] `\l` muestra al menos 4 bases de datos: `curso_db`, `postgres`, `template0`, `template1`
- [ ] `\du` muestra el rol `postgres` con atributos de superusuario
- [ ] `\q` cerró la sesión de psql correctamente


<br/><br/>


### Paso 6: Crear una tabla de prueba para verificar la persistencia

1. Conéctate nuevamente a psql:

   ```bash
   docker exec -it curso_postgres psql -U postgres -d curso_db
   ```

2. Crea una tabla de prueba:

   ```sql
   CREATE TABLE prueba_persistencia (
       id SERIAL PRIMARY KEY,
       mensaje TEXT NOT NULL,
       creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

3. Inserta algunos registros:

   ```sql
   INSERT INTO prueba_persistencia (mensaje) VALUES
       ('Primer registro - Lab 01'),
       ('PostgreSQL 16 funcionando correctamente'),
       ('Volúmenes Docker configurados');
   ```

4. Verifica los datos insertados:

   ```sql
   SELECT * FROM prueba_persistencia;
   ```

5. Verifica la estructura de la tabla:

   ```
   \d prueba_persistencia
   ```

6. Sal de psql:

   ```
   \q
   ```

7. Reinicia el contenedor de PostgreSQL para probar la persistencia:

   ```bash
   docker compose restart postgres
   ```

8. Espera 10 segundos y verifica que el contenedor volvió a estado `healthy`:

   ```bash
   docker compose ps
   ```

9. Conéctate nuevamente y verifica que los datos persisten:

   ```bash
   docker exec -it curso_postgres psql -U postgres -d curso_db -c "SELECT * FROM prueba_persistencia;"
   ```


<br/>

**Verificación:**

- [ ] La tabla `prueba_persistencia` fue creada sin errores
- [ ] Los 3 registros fueron insertados correctamente
- [ ] Después del reinicio del contenedor, los datos siguen presentes
- [ ] El directorio `pgdata` en tu máquina local contiene archivos (evidencia de persistencia)


<br/><br/>

### Paso 7: Conectarse a PostgreSQL desde pgAdmin 4

1. Abre tu navegador web y navega a:

   ```
   http://localhost:8080
   ```

2. Inicia sesión con las credenciales configuradas en el `docker-compose.yml`:
   - **Email:** `admin@curso.local`
   - **Password:** `admin123`

3. En el panel izquierdo de pgAdmin, haz clic derecho sobre **Servers** y selecciona **Register → Server...**

4. En la pestaña **General**, configura:
   - **Name:** `PostgreSQL 16 - Curso`

5. En la pestaña **Connection**, configura:
   - **Host name/address:** `curso_postgres`
   - **Port:** `5432`
   - **Maintenance database:** `curso_db`
   - **Username:** `postgres`
   - **Password:** `postgres`
   - Marca la casilla **Save password**

<br/>

> **Importante:** El hostname debe ser `curso_postgres` (el nombre del contenedor), NO `localhost`. Ambos contenedores están en la misma red Docker (`curso_network`), por lo que se comunican usando los nombres de los contenedores como hostnames.

6. Haz clic en **Save** para guardar y conectar.

7. En el panel izquierdo, expande la conexión: **PostgreSQL 16 - Curso → Databases → curso_db → Schemas → public → Tables**

8. Verifica que aparece la tabla `prueba_persistencia` creada en el Paso 6.

9. Haz clic derecho sobre `prueba_persistencia` y selecciona **View/Edit Data → All Rows** para ver los datos.

10. Abre el **Query Tool** (ícono de SQL en la barra superior o clic derecho sobre la base de datos → Query Tool) y ejecuta:

    ```sql
    SELECT
        schemaname,
        tablename,
        tableowner,
        tablespace,
        hasindexes,
        hasrules,
        hastriggers
    FROM pg_tables
    WHERE schemaname = 'public';
    ```


<br/>

**Verificación:**

- [ ] pgAdmin 4 carga correctamente en `http://localhost:8080`
- [ ] El login con `admin@curso.local` / `admin123` fue exitoso
- [ ] La conexión al servidor `curso_postgres` se estableció sin errores
- [ ] La tabla `prueba_persistencia` es visible en el árbol de objetos
- [ ] El Query Tool ejecutó la consulta y mostró resultados


<br/><br/>

### Paso 8: Explorar la arquitectura de PostgreSQL desde psql

1. Conéctate a psql:

   ```bash
   docker exec -it curso_postgres psql -U postgres -d curso_db
   ```

2. Consulta los procesos activos de PostgreSQL (equivalente al proceso postmaster y sus workers):

   ```sql
   SELECT pid, usename, application_name, client_addr, state, query
   FROM pg_stat_activity
   WHERE datname = 'curso_db';
   ```

3. Consulta la configuración de memoria (shared_buffers es uno de los parámetros más importantes):

   ```sql
   SELECT name, setting, unit, short_desc
   FROM pg_settings
   WHERE name IN (
       'shared_buffers',
       'work_mem',
       'maintenance_work_mem',
       'max_connections',
       'wal_level',
       'max_wal_size'
   )
   ORDER BY name;
   ```

4. Verifica la configuración del WAL (Write-Ahead Logging):

   ```sql
   SELECT name, setting, unit, short_desc
   FROM pg_settings
   WHERE name LIKE 'wal%'
   ORDER BY name;
   ```

5. Consulta las extensiones disponibles en el sistema:

   ```sql
   SELECT name, default_version, installed_version, comment
   FROM pg_available_extensions
   WHERE name IN ('pg_stat_statements', 'uuid-ossp', 'hstore', 'pgcrypto')
   ORDER BY name;
   ```

6. Instala la extensión `pg_stat_statements` que usaremos en módulos posteriores:

   ```sql
   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
   ```

7. Verifica las extensiones instaladas:

   ```sql
   SELECT extname, extversion
   FROM pg_extension
   ORDER BY extname;
   ```

8. Consulta el tamaño actual de la base de datos:

   ```sql
   SELECT
       pg_database.datname AS "Base de Datos",
       pg_size_pretty(pg_database_size(pg_database.datname)) AS "Tamaño"
   FROM pg_database
   ORDER BY pg_database_size(pg_database.datname) DESC;
   ```

9. Sal de psql:

   ```
   \q
   ```

<br/>


**Verificación:**

- [ ] `pg_stat_activity` muestra la sesión activa de psql
- [ ] `pg_settings` muestra los parámetros de configuración de memoria y WAL
- [ ] La extensión `pg_stat_statements` fue instalada correctamente
- [ ] La consulta de tamaños muestra las 4 bases de datos del sistema

<br/>

> **Contexto arquitectónico:** Lo que acabas de explorar son los componentes fundamentales de PostgreSQL:
> - **postmaster:** El proceso principal que acepta conexiones y gestiona los procesos hijo
> - **shared_buffers:** La caché de memoria compartida donde PostgreSQL almacena páginas de datos frecuentemente accedidas (por defecto 128MB en la imagen Docker)
> - **WAL (Write-Ahead Logging):** El registro de transacciones que garantiza la durabilidad de los datos (el `D` en ACID)
> - **work_mem:** Memoria disponible para cada operación de ordenamiento o hash en una consulta
> - **pg_stat_statements:** Extensión que registra estadísticas de ejecución de todas las consultas (fundamental para optimización en el Módulo 5)


<br/><br/>

## Validación y Pruebas

### Criterios de Éxito

- [ ] Docker Desktop está instalado y en ejecución con versión 4.25.0 o superior
- [ ] El archivo `docker-compose.yml` levanta correctamente los contenedores `curso_postgres` y `curso_pgadmin`
- [ ] El contenedor de PostgreSQL muestra estado `healthy` en `docker compose ps`
- [ ] La conexión a psql desde el contenedor funciona con `docker exec -it curso_postgres psql -U postgres -d curso_db`
- [ ] Los meta-comandos `\l`, `\c`, `\dt`, `\dn`, `\du`, `\d`, `\h` y `\?` funcionan correctamente en psql
- [ ] pgAdmin 4 es accesible en `http://localhost:8080` y puede conectarse a `curso_postgres`
- [ ] Los datos de la tabla `prueba_persistencia` persisten después de reiniciar el contenedor de PostgreSQL
- [ ] La extensión `pg_stat_statements` está instalada en `curso_db`
- [ ] Los volúmenes Docker están mapeados a directorios locales (`pgdata` y `pgadmin-data`)

<br/>

### Procedimiento de Pruebas

1. Prueba completa de conectividad y estado del entorno:

   ```bash
   docker compose ps
   ```
   **Resultado Esperado:** Ambos contenedores con estado `Up` y PostgreSQL con `(healthy)`

2. Prueba de persistencia de datos:

   ```bash
   docker exec -it curso_postgres psql -U postgres -d curso_db -c "SELECT COUNT(*) FROM prueba_persistencia;"
   ```
   **Resultado Esperado:**
   ```
    count
   -------
        3
   (1 row)
   ```

3. Prueba de extensiones instaladas:

   ```bash
   docker exec -it curso_postgres psql -U postgres -d curso_db -c "SELECT extname, extversion FROM pg_extension ORDER BY extname;"
   ```
   **Resultado Esperado:**
   ```
         extname       | extversion
   --------------------+------------
    pg_stat_statements | 1.10
    plpgsql            | 1.0
   (2 rows)
   ```

4. Prueba de acceso a pgAdmin:

   Abre `http://localhost:8080` en el navegador. Debe cargar la pantalla de login de pgAdmin.

   **Resultado Esperado:** Página de login de pgAdmin visible sin errores de conexión.

5. Prueba de volúmenes persistentes:

   **En Linux/macOS:**
   ```bash
   ls -la ~/curso-postgresql/lab-01/pgdata/pgdata/
   ```

   **En Windows (PowerShell):**
   ```powershell
   Get-ChildItem "$env:USERPROFILE\curso-postgresql\lab-01\pgdata\pgdata\"
   ```
   **Resultado Esperado:** Directorio con archivos de PostgreSQL incluyendo `PG_VERSION`, `base/`, `global/`, `pg_wal/`


<br/><br/>

## Solución de Problemas

### Problema 1: El contenedor de PostgreSQL no inicia o muestra estado "unhealthy"

**Síntomas:**
- `docker compose ps` muestra `curso_postgres` con estado `unhealthy` o `Exit 1`
- Los logs muestran errores de permisos o de inicialización

**Causa:**
El directorio `pgdata` puede tener permisos incorrectos o datos corruptos de una instalación anterior.

**Solución:**

```bash
# Detener y eliminar los contenedores
docker compose down

# Eliminar el directorio de datos (ADVERTENCIA: esto borra todos los datos)
# En Linux/macOS:
rm -rf ~/curso-postgresql/lab-01/pgdata
mkdir -p ~/curso-postgresql/lab-01/pgdata

# En Windows (PowerShell):
Remove-Item -Recurse -Force "$env:USERPROFILE\curso-postgresql\lab-01\pgdata"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\curso-postgresql\lab-01\pgdata"

# Reiniciar los contenedores
docker compose up -d

# Verificar el estado
docker compose ps
```


<br/><br/>


### Problema 2: El puerto 5432 ya está en uso

**Síntomas:**
- Error al ejecutar `docker compose up`: `Bind for 0.0.0.0:5432 failed: port is already allocated`
- `docker compose ps` muestra el contenedor en estado `Exit`

**Causa:**
Hay otra instancia de PostgreSQL (o aplicación) usando el puerto 5432 en el sistema host.

**Solución:**

```bash
# Identificar qué proceso usa el puerto 5432
# En Linux/macOS:
sudo lsof -i :5432

# En Windows (PowerShell):
netstat -ano | findstr :5432

# Opción 1: Detener el proceso conflictivo
# En Linux (si es PostgreSQL local):
sudo systemctl stop postgresql

# Opción 2: Cambiar el puerto en docker-compose.yml
# Edita la sección ports del servicio postgres:
# ports:
#   - "5433:5432"    # Usa el puerto 5433 en el host en lugar de 5432

# Después de cambiar el puerto, reinicia:
docker compose down
docker compose up -d

# Si cambias el puerto, recuerda usar 5433 al conectarte con psql:
docker exec -it curso_postgres psql -U postgres -d curso_db
# (psql dentro del contenedor siempre usa 5432 internamente)
```

<br/><br/>

### Problema 3: pgAdmin no carga en http://localhost:8080

**Síntomas:**
- El navegador muestra "Esta página no está disponible" o "Connection refused"
- `docker compose ps` muestra `curso_pgadmin` en estado `Up` pero pgAdmin no responde

**Causa:**
pgAdmin puede tardar hasta 60 segundos en inicializarse completamente después de que el contenedor inicia. También puede haber un conflicto con el puerto 8080.

**Solución:**

```bash
# Verificar si pgAdmin está completamente inicializado
docker logs curso_pgadmin --tail 20

# Esperar y reintentar (pgAdmin puede tardar hasta 60 segundos)
sleep 30

# Si el puerto 8080 está en uso, cambiar en docker-compose.yml:
# ports:
#   - "8081:80"    # Usa el puerto 8081 en lugar de 8080
# Y acceder a http://localhost:8081

# Reiniciar solo pgAdmin sin afectar PostgreSQL:
docker compose restart pgadmin

# Ver logs en tiempo real para diagnosticar:
docker compose logs -f pgadmin
```

<br/><br/>

### Problema 4: Error de conexión en pgAdmin - "could not connect to server"

**Síntomas:**
- Al intentar conectar pgAdmin al servidor PostgreSQL, aparece el error: `could not connect to server: Connection refused`
- O: `FATAL: password authentication failed for user "postgres"`

**Causa:**
El hostname configurado en pgAdmin es incorrecto (se usó `localhost` en lugar del nombre del contenedor), o la contraseña no coincide con la configurada en el `docker-compose.yml`.

**Solución:**

```
# Verificar la configuración de conexión en pgAdmin:
# - Host name/address: curso_postgres  (NO localhost, NO 127.0.0.1)
# - Port: 5432
# - Username: postgres
# - Password: postgres

# Si olvidaste la contraseña configurada, puedes verla en el docker-compose.yml:
grep POSTGRES_PASSWORD docker-compose.yml

# También puedes resetear la conexión en pgAdmin:
# Clic derecho sobre el servidor → Properties → Connection → actualizar datos
```


<br/><br/>

### Problema 5: Problemas de volúmenes en Windows con WSL2

**Síntomas:**
- Los datos no persisten después de reiniciar el contenedor en Windows
- Error: `chown: changing ownership of '/var/lib/postgresql/data': Permission denied`

**Causa:**
En Windows con WSL2, los paths de volúmenes pueden tener problemas de permisos cuando el directorio del host está en el sistema de archivos de Windows (C:\Users\...).

**Solución:**

```yaml
# Opción 1: Usar volúmenes nombrados de Docker en lugar de bind mounts
# Modifica docker-compose.yml reemplazando los volumes del servicio postgres:

services:
  postgres:
    volumes:
      - pgdata_volume:/var/lib/postgresql/data    # volumen nombrado

  pgadmin:
    volumes:
      - pgadmin_volume:/var/lib/pgadmin           # volumen nombrado

volumes:
  pgdata_volume:
  pgadmin_volume:
```

```bash
# Después de modificar el archivo, reinicia:
docker compose down
docker compose up -d

# Verificar que los volúmenes nombrados fueron creados:
docker volume ls
```


<br/><br/>

## Limpieza

> **Advertencia Importante:** Los siguientes comandos detendrán los contenedores. **NO ejecutes los comandos que eliminan volúmenes** si quieres conservar los datos para las prácticas siguientes.  


### Detener los contenedores (sin eliminar datos)

```bash
# Detener los contenedores sin eliminar volúmenes ni redes
# Usa este comando al final de cada sesión de trabajo
cd ~/curso-postgresql/lab-01
docker compose stop
```

### Reiniciar los contenedores (para la próxima sesión)

```bash
# Iniciar los contenedores en la próxima sesión
cd ~/curso-postgresql/lab-01
docker compose start
```

### Eliminar completamente el entorno (SOLO si deseas empezar desde cero)

```bash
# ADVERTENCIA: Esto elimina TODOS los datos de la práctica
# Solo ejecutar si necesitas reinstalar completamente

# Detener y eliminar contenedores, redes y volúmenes
docker compose down --volumes

# Eliminar las imágenes descargadas (opcional, libera espacio en disco)
docker rmi postgres:16
docker rmi dpage/pgadmin4

# Eliminar el directorio de datos local
# En Linux/macOS:
rm -rf ~/curso-postgresql/lab-01/pgdata
rm -rf ~/curso-postgresql/lab-01/pgadmin-data

# En Windows (PowerShell):
Remove-Item -Recurse -Force "$env:USERPROFILE\curso-postgresql\lab-01\pgdata"
Remove-Item -Recurse -Force "$env:USERPROFILE\curso-postgresql\lab-01\pgadmin-data"
```

<br/><br/>

## Resumen

### Lo que Lograste

- **Configuraste un entorno Docker completo** con PostgreSQL 16 y pgAdmin 4 usando Docker Compose, con volúmenes persistentes y red interna entre contenedores.
- **Realizaste tu primera conexión a PostgreSQL** usando el cliente `psql` desde dentro del contenedor y exploraste los meta-comandos fundamentales para navegar bases de datos, tablas y esquemas.
- **Verificaste la persistencia de datos** creando una tabla de prueba, insertando registros y confirmando que sobreviven al reinicio del contenedor.
- **Configuraste pgAdmin 4** como herramienta gráfica de administración, estableciendo la conexión al servidor PostgreSQL usando la red interna de Docker.
- **Exploraste la arquitectura de PostgreSQL** consultando el catálogo del sistema para identificar procesos activos, parámetros de configuración de memoria, configuración del WAL y extensiones disponibles.
- **Instalaste la extensión `pg_stat_statements`** que será fundamental para el análisis de rendimiento de consultas en el Módulo 5.

<br/><br/>

### Conceptos Clave Aprendidos

- **Docker Compose** permite definir y orquestar múltiples contenedores con un solo archivo YAML, simplificando la configuración de entornos de desarrollo reproducibles.
- **Los volúmenes Docker** son esenciales para la persistencia de datos: sin ellos, todos los datos se perderían al detener el contenedor.
- **La red interna de Docker** (`curso_network`) permite que los contenedores se comuniquen entre sí usando sus nombres como hostnames, sin exponer puertos innecesariamente al exterior.
- **El healthcheck** de PostgreSQL garantiza que pgAdmin solo intente conectarse cuando el motor está completamente listo, evitando errores de inicio.
- **`pg_stat_statements`** es una extensión del catálogo del sistema que registra estadísticas de ejecución de consultas, fundamental para identificar consultas lentas en optimización.
- **Los meta-comandos de psql** (`\l`, `\c`, `\dt`, `\d`, `\du`, `\dn`) son atajos poderosos para explorar la estructura de la base de datos sin escribir SQL complejo.


<br/><br/>


## Recursos Adicionales

- **Documentación oficial de Docker Compose** — [docs.docker.com/compose](https://docs.docker.com/compose/): Referencia completa del formato de archivos `docker-compose.yml` y todos los parámetros disponibles.
- **Imagen oficial de PostgreSQL en Docker Hub** — [hub.docker.com/_/postgres](https://hub.docker.com/_/postgres): Documentación de todas las variables de entorno disponibles para la imagen oficial, scripts de inicialización y configuraciones avanzadas.
- **Documentación de psql** — [postgresql.org/docs/16/app-psql.html](https://www.postgresql.org/docs/16/app-psql.html): Referencia completa de todos los meta-comandos y opciones de línea de comandos de psql.
- **pgAdmin 4 Documentation** — [pgadmin.org/docs/pgadmin4/latest](https://www.pgadmin.org/docs/pgadmin4/latest/): Guías completas para administrar servidores PostgreSQL desde la interfaz web de pgAdmin.
- **"The Internals of PostgreSQL"** — [interdb.jp/pg](https://www.interdb.jp/pg/): Libro gratuito en línea que explica en detalle la arquitectura interna del motor, incluyendo el proceso postmaster, shared buffers y WAL.
- **pg_stat_statements** — [postgresql.org/docs/16/pgstatstatements.html](https://www.postgresql.org/docs/16/pgstatstatements.html): Documentación de la extensión que instalaste en el Paso 8, fundamental para el módulo de optimización.
