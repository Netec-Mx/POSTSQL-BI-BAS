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