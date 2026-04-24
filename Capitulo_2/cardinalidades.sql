   -- Verificar cantidad de registros por tabla
   SELECT 'categorias'      AS tabla, COUNT(*) AS registros FROM categorias
   UNION ALL
   SELECT 'productos',                COUNT(*)               FROM productos
   UNION ALL
   SELECT 'clientes',                 COUNT(*)               FROM clientes
   UNION ALL
   SELECT 'vendedores',               COUNT(*)               FROM vendedores
   UNION ALL
   SELECT 'ordenes',                  COUNT(*)               FROM ordenes
   UNION ALL
   SELECT 'detalle_ordenes',          COUNT(*)               FROM detalle_ordenes;