

## Tabla de ayuda – Comandos Docker

| Comando               | ¿Para qué sirve?                                  | Ejemplo rápido                               |
| --------------------- | ------------------------------------------------- | -------------------------------------------- |
| `docker --version`    | Ver versión de Docker                             | `docker --version`                           |
| `docker info`         | Ver información del sistema Docker                | `docker info`                                |
| `docker ps`           | Listar contenedores en ejecución                  | `docker ps`                                  |
| `docker ps -a`        | Listar todos los contenedores (incluye detenidos) | `docker ps -a`                               |
| `docker images`       | Listar imágenes disponibles                       | `docker images`                              |
| `docker pull`         | Descargar una imagen                              | `docker pull postgres:16`                    |
| `docker run`          | Crear y ejecutar un contenedor                    | `docker run -d -p 5432:5432 postgres`        |
| `docker start`        | Iniciar un contenedor detenido                    | `docker start postgres_sales`                |
| `docker stop`         | Detener un contenedor                             | `docker stop postgres_sales`                 |
| `docker restart`      | Reiniciar un contenedor                           | `docker restart postgres_sales`              |
| `docker rm`           | Eliminar un contenedor                            | `docker rm postgres_sales`                   |
| `docker rmi`          | Eliminar una imagen                               | `docker rmi postgres:16`                     |
| `docker exec`         | Ejecutar comando dentro de un contenedor          | `docker exec -it postgres_sales bash`        |
| `docker logs`         | Ver logs de un contenedor                         | `docker logs postgres_sales`                 |
| `docker logs -f`      | Ver logs en tiempo real                           | `docker logs -f postgres_sales`              |
| `docker inspect`      | Ver detalles de un contenedor                     | `docker inspect postgres_sales`              |
| `docker stats`        | Ver uso de recursos                               | `docker stats`                               |
| `docker cp`           | Copiar archivos entre host y contenedor           | `docker cp archivo.sql postgres_sales:/tmp/` |
| `docker network ls`   | Listar redes                                      | `docker network ls`                          |
| `docker volume ls`    | Listar volúmenes                                  | `docker volume ls`                           |
| `docker system prune` | Limpiar recursos no usados                        | `docker system prune -a`                     |


<br/>
<br/>

## PostgreSQL en contenedor

| Comando          | ¿Para qué sirve?    | Ejemplo                                                       |
| ---------------- | ------------------- | ------------------------------------------------------------- |
| Acceder a psql   | Entrar a PostgreSQL | `docker exec -it curso_postgres psql -U postgres -d ventas_db` |
| Verificar estado | Revisar conexión    | `docker exec curso_postgres pg_isready`                       |
| Ver logs DB      | Diagnóstico         | `docker logs curso_postgres`                                  |

<br/>
<br/>

> **Tip:** Docker trabaja con imágenes (plantillas) y contenedores (instancias en ejecución). Primero descargas una imagen (`pull`) y luego creas un contenedor (`run`).
```

