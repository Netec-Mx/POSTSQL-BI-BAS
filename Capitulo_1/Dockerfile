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