

## Tabla de ayuda – Comandos de PostgreSQL (psql)

| Comando          | ¿Para qué sirve?                          | Ejemplo rápido  |
| ---------------- | ----------------------------------------- | --------------- |
| `\l`             | Listar todas las bases de datos           | `\l`            |
| `\c`             | Conectarse a una base de datos            | `\c sales_db`   |
| `\conninfo`      | Mostrar información de la conexión actual | `\conninfo`     |
| `\dt`            | Listar tablas del esquema actual          | `\dt`           |
| `\dt *.*`        | Listar tablas de todos los esquemas       | `\dt *.*`       |
| `\d tabla`       | Ver estructura de una tabla               | `\d products`   |
| `\dn`            | Listar esquemas                           | `\dn`           |
| `\du`            | Listar usuarios/roles                     | `\du`           |
| `\df`            | Listar funciones                          | `\df`           |
| `\dv`            | Listar vistas                             | `\dv`           |
| `\di`            | Listar índices                            | `\di`           |
| `\ds`            | Listar secuencias                         | `\ds`           |
| `\x`             | Activar/desactivar formato expandido      | `\x`            |
| `\timing`        | Activar/desactivar medición de tiempo     | `\timing`       |
| `\i archivo.sql` | Ejecutar un script SQL                    | `\i setup.sql`  |
| `\o archivo.txt` | Guardar salida en archivo                 | `\o salida.txt` |
| `\! comando`     | Ejecutar comando del sistema              | `\! ls`         |
| `\h`             | Ayuda de comandos SQL                     | `\h SELECT`     |
| `\?`             | Ayuda de comandos de psql                 | `\?`            |
| `\q`             | Salir de psql                             | `\q`            |


<br/>

> **Tip:** Los comandos que comienzan con "\" son propios de psql (no son SQL) y se ejecutan directamente en la consola de PostgreSQL.

<br/>
<br/>

