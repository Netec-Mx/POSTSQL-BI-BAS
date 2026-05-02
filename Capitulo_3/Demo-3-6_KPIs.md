
# Demo: KPIs Financieros y de Retención en PostgreSQL

<br/><br/>

## Resumen pedagógico 

| KPI         | Técnica SQL      | Concepto BI              |
| ----------- | ---------------- | ------------------------ |
| MRR         | SUM + FILTER     | ingresos activos         |
| ARR         | cálculo derivado | proyección anual         |
| LTV         | ventana          | valor por cliente        |
| Churn       | FILTER           | pérdida de clientes      |
| Cohortes    | GROUP BY         | análisis por adquisición |
| Retención   | FILTER + GROUP   | supervivencia            |
| Crecimiento | LAG              | tendencia                |


<br/><br/>

## 1. Crear tabla base SAS

```sql
CREATE TEMP TABLE suscripciones (
    cliente_id INT,
    fecha_inicio DATE,
    fecha_cancelacion DATE,
    monto_mensual NUMERIC
);
```

<br/><br/>

## 2. Insertar datos de prueba


```sql

-- cliente_id, fecha_inicio, fecha_cancelacion, monto_mensual

INSERT INTO suscripciones VALUES
(1, '2026-01-01', NULL, 100),
(2, '2026-01-15', '2026-03-10', 80),
(3, '2026-02-01', NULL, 120),
(4, '2026-02-10', '2026-04-01', 90),
(5, '2026-03-01', NULL, 110),
(6, '2026-03-15', '2026-03-30', 70);
```

<br/><br/>

## 3. KPI Financiero: MRR (Monthly Recurring Revenue)

Ingresos recurrentes mensuales activos

```sql
SELECT
    DATE_TRUNC('month', fecha_inicio) AS mes,
    SUM(monto_mensual) FILTER (
        WHERE fecha_cancelacion IS NULL
        OR fecha_cancelacion > DATE_TRUNC('month', fecha_inicio)
    ) AS mrr
FROM suscripciones
GROUP BY 1
ORDER BY 1;
```

<br/>

Explicación:

* `FILTER` permite contar solo clientes activos
* `GROUP BY` agrupa por mes
* KPI típico de SaaS

<br/><br/>


## 4. KPI Financiero: ARR

Annual Recurring Revenue

```sql
SELECT
    mes,
    mrr,
    mrr * 12 AS arr
FROM (
    SELECT
        DATE_TRUNC('month', fecha_inicio) AS mes,
        SUM(monto_mensual) AS mrr
    FROM suscripciones
    GROUP BY 1
) t;
```

<br/>

Explicación:

* ARR = MRR * 12
* Se usa subconsulta para claridad pedagógica

<br/><br/>

##  5. KPI Financiero: LTV (Customer Lifetime Value)

Valor total esperado por cliente

```sql
SELECT
    cliente_id,
    SUM(monto_mensual) OVER (
        PARTITION BY cliente_id
    ) AS ltv_estimado
FROM suscripciones;
```

<br/>

Explicación:

* Función ventana → no pierde detalle
* LTV básico (sin churn rate aún)

<br/><br/>

## 6. KPI Retención: Churn Rate

% de clientes que cancelan

```sql
SELECT
    COUNT(*) FILTER (WHERE fecha_cancelacion IS NOT NULL) AS cancelados,
    COUNT(*) AS total_clientes,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE fecha_cancelacion IS NOT NULL)
        / COUNT(*),
    2) AS churn_pct
FROM suscripciones;
```

<br/>

Explicación:

* `FILTER` simplifica mucho vs CASE
* Métrica crítica de negocio

<br/><br/>


## 7. Cohortes (Retención por mes de inicio)

Agrupar clientes por mes en que iniciaron

```sql
SELECT
    DATE_TRUNC('month', fecha_inicio) AS cohorte,
    COUNT(*) AS clientes
FROM suscripciones
GROUP BY 1
ORDER BY 1;
```

<br/>

Explicación:

* Aquí nace el concepto de **cohorte**
* Es un grupo de usuarios con comportamiento común

<br/><br/>


## 8. Cohorte + Retención (con funciones ventana)

Evolución de clientes activos

```sql
SELECT
    cohorte,
    COUNT(*) FILTER (WHERE fecha_cancelacion IS NULL) AS activos,
    COUNT(*) AS total,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE fecha_cancelacion IS NULL)
        / COUNT(*),
    2) AS retention_pct
FROM (
    SELECT
        cliente_id,
        DATE_TRUNC('month', fecha_inicio) AS cohorte,
        fecha_cancelacion
    FROM suscripciones
) t
GROUP BY cohorte
ORDER BY cohorte;
```

<br/>

Explicación:

* Cohorte = mes de adquisición
* Retención = clientes que siguen activos

<br/><br/>


## 9. Evolución del MRR 

Crecimiento mes a mes

```sql
SELECT
    mes,
    mrr,
    LAG(mrr) OVER (ORDER BY mes) AS mrr_anterior,
    ROUND(
        100.0 * (mrr - LAG(mrr) OVER (ORDER BY mes))
        / NULLIF(LAG(mrr) OVER (ORDER BY mes), 0),
    2) AS crecimiento_pct
FROM (
    SELECT
        DATE_TRUNC('month', fecha_inicio) AS mes,
        SUM(monto_mensual) AS mrr
    FROM suscripciones
    GROUP BY 1
) t;
```

<br/>

Explicación:

* `LAG` → compara con periodo anterior
* KPI típico: crecimiento MoM

<br/><br/>


## Notas 

* **MRR** → cuánto dinero entra cada mes
* **ARR** → cuánto valdría eso en un año
* **LTV** → cuánto vale un cliente en total
* **Churn** → cuántos se van
* **Cohorte** → agrupar clientes por cuándo llegaron
* **Retención** → cuántos siguen vivos
* **LAG** → comparar contra el pasado

<br/><br/>
