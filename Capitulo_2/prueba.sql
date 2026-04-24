-- Script de validación de la práctica 2.1
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Validar categorias
    SELECT COUNT(*) INTO v_count FROM categorias;
    IF v_count <> 8 THEN
        RAISE EXCEPTION 'ERROR: categorias tiene % registros, se esperaban 8', v_count;
    END IF;

    -- Validar productos
    SELECT COUNT(*) INTO v_count FROM productos;
    IF v_count <> 33 THEN
        RAISE EXCEPTION 'ERROR: productos tiene % registros, se esperaban 33', v_count;
    END IF;

    -- Validar clientes
    SELECT COUNT(*) INTO v_count FROM clientes;
    IF v_count <> 21 THEN
        RAISE EXCEPTION 'ERROR: clientes tiene % registros, se esperaban 21', v_count;
    END IF;

    -- Validar vendedores
    SELECT COUNT(*) INTO v_count FROM vendedores;
    IF v_count <> 8 THEN
        RAISE EXCEPTION 'ERROR: vendedores tiene % registros, se esperaban 8', v_count;
    END IF;

    -- Validar ordenes
    SELECT COUNT(*) INTO v_count FROM ordenes;
    IF v_count <> 30 THEN
        RAISE EXCEPTION 'ERROR: ordenes tiene % registros, se esperaban 30', v_count;
    END IF;

    -- Validar detalle_ordenes
    SELECT COUNT(*) INTO v_count FROM detalle_ordenes;
    IF v_count <> 54 THEN
        RAISE EXCEPTION 'ERROR: detalle_ordenes tiene % registros, se esperaban 54', v_count;
    END IF;

    RAISE NOTICE 'VALIDACIÓN EXITOSA: Todas las tablas tienen los registros correctos.';
END;
$$;