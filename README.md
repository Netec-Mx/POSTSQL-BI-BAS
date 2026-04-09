<img src="images/neteclogo.png" alt="logo" width="300"/>



# Nombre del curso

### [Práctica 1.1 Instalación de imagen PostgreSQL en Docker](Capitulo_1/Readme1-1.md) 

En este laboratorio configurarás desde cero el entorno de desarrollo que utilizarás durante todo el curso. Levantarás un contenedor PostgreSQL 16 junto con pgAdmin 4 usando Docker Compose, realizarás tus primeras conexiones al motor de base de datos y explorarás los comandos fundamentales del cliente psql. Este entorno es la base sobre la que construirás todos los ejercicios de SQL avanzado, optimización e integración con Power BI de los módulos siguientes.

La relevancia práctica de este laboratorio va más allá del curso: saber levantar un entorno PostgreSQL reproducible con Docker es una habilidad directamente aplicable en equipos de desarrollo y análisis de datos del mundo real, donde la consistencia del entorno entre desarrolladores es crítica.

- **Duración estimada**: 60 min.

<br/><br/>

### [Práctica 2.1 Consultas sobre tablas](Capitulo_2/Readme2-1.md)

En este laboratorio construirás y consultarás un dataset de ventas minoristas compuesto por seis tablas relacionadas: clientes, productos, categorias, vendedores, ordenes y detalle_ordenes. Partiendo desde SELECTs simples con filtros WHERE, avanzarás progresivamente hacia consultas multi-tabla con distintos tipos de JOIN, manejo de valores NULL y análisis agregados con GROUP BY. Al finalizar, serás capaz de responder preguntas de negocio concretas usando SQL como herramienta analítica, aplicando todas las convenciones de estilo y reglas de escritura estudiadas en la Lección 2.1.

Este laboratorio es el punto de partida del dataset de ventas que se reutilizará y enriquecerá en todos los laboratorios posteriores del curso. Es fundamental completarlo en su totalidad antes de avanzar al Laboratorio 03-00-01.

  - **Duración estimada**: 60 min.

<br/><br/>

### [Práctica 3.1 Creación de Consultas con Subconsultas y CTEs](Capitulo_3/Readme3-1.md)

En este práctica ampliarás el esquema del dataset de ventas incorporando una tabla de categorías jerárquica (relación padre-hijo) y una tabla de empleados con estructura de reporte (manager-subordinado). A partir de ese esquema enriquecido, aprenderás a escribir subconsultas no correlacionadas y correlacionadas en las cláusulas `WHERE`, `FROM` y `SELECT`, para luego refactorizar esas mismas consultas utilizando CTEs (`WITH`) y CTEs recursivos (`WITH RECURSIVE`). La práctica culmina con un ejercicio comparativo que te permitirá evaluar la legibilidad y el plan de ejecución de ambos enfoques, consolidando criterios prácticos para elegir la técnica más adecuada en cada situación analítica.


  - **Duración estimada**: 60 min.

<br/><br/>

### [Práctica 3.2 Aplicación de Funciones de Ventana](Capitulo_3/Readme3-2.md)

En este laboratorio aplicarás las funciones de ventana (window functions) de PostgreSQL, una de las herramientas más poderosas del SQL analítico moderno. A diferencia de las funciones de agregación tradicionales con `GROUP BY`, las funciones de ventana calculan valores sobre un conjunto de filas relacionadas **sin colapsar el resultado**, permitiéndote combinar detalle y agregación en una sola consulta.

Trabajarás con el dataset de ventas enriquecido con 24 meses de datos temporales construido en el laboratorio anterior. Aplicarás funciones de ranking para clasificar productos y vendedores, calcularás variaciones porcentuales mes a mes con `LAG()` y `LEAD()`, implementarás promedios móviles con la sintaxis `ROWS BETWEEN`, segmentarás clientes en cuartiles con `NTILE(4)`, y aprenderás a reutilizar definiciones de ventana con la cláusula `WINDOW`. Estas técnicas son fundamentales en análisis financiero, reportes de KPIs y dashboards de Business Intelligence.

  - **Duración estimada**: 60 min.

<br/><br/>

### [Práctica 3.3 Uso de Agrupaciones Avanzadas](Capitulo_3/Readme3-3.md)

En esta prática explorarás las capacidades de agregación avanzada de PostgreSQL para construir análisis multidimensionales sobre el dataset de ventas. Aprenderás a generar múltiples niveles de resumen en una sola consulta usando `GROUPING SETS`, `ROLLUP` y `CUBE`, evitando la necesidad de ejecutar múltiples consultas separadas y unirlas con `UNION ALL`. Adicionalmente, utilizarás la cláusula `FILTER` para calcular métricas condicionales en una sola pasada, y aplicarás funciones estadísticas avanzadas como `STDDEV()`, `VARIANCE()`, `CORR()` y `PERCENTILE_CONT()` para derivar KPIs financieros significativos.

Estas técnicas son fundamentales en entornos de Business Intelligence donde los reportes requieren subtotales, totales generales y análisis cruzados por múltiples dimensiones simultáneamente, como los que se construyen en herramientas como Power BI o Tableau.

  - **Duración estimada**: 60 min.

<br/><br/>

### [Práctica 3.4 Uso de Funciones de Tiempo](Capitulo_3/Readme3-4.md)

En esta práctica aplicarás técnicas avanzadas de análisis temporal en PostgreSQL utilizando el dataset de ventas enriquecido construido en las prácticas anteriores. Dominarás funciones clave como DATE_TRUNC(), EXTRACT(), INTERVAL y generate_series() para realizar agrupaciones temporales, detectar gaps en datos, construir comparaciones Year-over-Year (YoY) y Month-over-Month (MoM), e implementar un análisis de cohortes de clientes. Finalizarás explorando TimescaleDB, una extensión de PostgreSQL diseñada específicamente para series de tiempo, aprendiendo a crear hypertables y ejecutar consultas optimizadas con time_bucket().

El análisis temporal es una competencia fundamental en cualquier proyecto de analítica de negocio. Las técnicas aprendidas aquí son directamente aplicables en reportes financieros, análisis de retención de clientes, detección de anomalías operacionales y construcción de dashboards de KPIs en herramientas como Power BI.

  - **Duración estimada**: 60 min.

<br/><br/>

### [Práctica 4.1. Creación y Uso de Vistas y Vistas Materializadas](Capitulo_4/Readme4-1.md)

En esta práctica aprenderás a crear y gestionar vistas lógicas y vistas materializadas en PostgreSQL 16 como mecanismo de abstracción sobre el modelo de datos de ventas construido en los módulos anteriores. Las vistas lógicas encapsulan consultas complejas con JOINs y agregaciones, simplificando el acceso a datos para aplicaciones y analistas. Las vistas materializadas van un paso más allá: persisten físicamente los resultados de consultas costosas, reduciendo drásticamente los tiempos de respuesta para dashboards y reportes.

Esta práctica tiene relevancia directa en entornos de producción: las vistas materializadas son una de las técnicas más utilizadas para optimizar el rendimiento de dashboards de Power BI conectados a PostgreSQL, ya que permiten que las herramientas de visualización consulten datos pre-agregados en lugar de recalcular millones de filas en cada actualización del reporte.

  - **Duración estimada**: 60 min.

<br/><br/>

### [Práctica 4.2 Creación de Procedimientos y Funciones](Capitulo_4/Readme4-2.md)

En esta práctica aprenderás a programar lógica de negocio directamente en PostgreSQL usando PL/pgSQL. Comenzarás con funciones simples para calcular descuentos y categorizar clientes, avanzarás hacia funciones con múltiples parámetros de salida, e implementarás un procedimiento completo de carga incremental con manejo explícito de transacciones (`COMMIT` / `ROLLBACK`). Finalmente, utilizarás cursores explícitos para procesar registros de forma iterativa y bloques `DO $$` para ejecutar lógica ad-hoc, concluyendo con una introducción a pgAgent para programar la ejecución automática del procedimiento de carga diaria.

Esta práctica refleja patrones reales de ingeniería de datos: encapsular reglas de negocio en la base de datos garantiza consistencia, reutilización y mantenibilidad en entornos analíticos y de producción.

   - **Duración estimada**: 60 min.

<br/><br/>

### [ Práctica 5.1. Monitoreo y Optimización de Consultas](Capitulo_5/Readme5-1.md)

En esta práctica aplicarás técnicas de indexación avanzada sobre el dataset de ventas construido en las prácticas  anteriores para diagnosticar y eliminar cuellos de botella en consultas lentas. Partirás de un conjunto de consultas deliberadamente no optimizadas, analizarás sus planes de ejecución con `EXPLAIN` y `EXPLAIN ANALYZE`, crearás índices B-Tree, Hash, GIN y parciales estratégicamente, y medirás el impacto real en tiempos de respuesta antes y después de cada optimización. Esta práctica refleja el flujo de trabajo real de un DBA o analista de datos que debe garantizar que los dashboards de Power BI respondan en tiempo aceptable sobre millones de registros.

  - **Duración estimada**: 60 min.
 
<br/><br/>


### [Práctica 6.2 Nombre de la práctica](Capitulo_6/Readme6-1.md)

  - **Descripción**: xxx.

  - **Duración estimada**: xx min.

<br/><br/>



## **Contacto y más información**

Si tienes alguna pregunta o necesitas más detalles, no dudes en [contactarnos](mailto:soporte@netec.com). También puedes encontrar más recursos en nuestra [página](https://netec.com).


<br/><br/>

¡Gracias por visitar nuestra plataforma! No olvides revisar todos los laboratorios y comenzar tu viaje de aprendizaje hoy mismo.
