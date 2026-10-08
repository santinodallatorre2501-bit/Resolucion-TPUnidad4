-- 1. Estructura desnormalizada (resumen diario de categorías)
CREATE TABLE IF NOT EXISTS reporte_diario_categoria (
    id_categoria BIGINT,
    fecha DATE,
    total_vendido NUMERIC(15,2) DEFAULT 0,
    PRIMARY KEY (id_categoria, fecha)
);

-- 2. Mecanismo de sincronización (Disparador transaccional en PL/pgSQL)
CREATE OR REPLACE FUNCTION fn_sync_ventas_categoria()
RETURNS TRIGGER AS $$
DECLARE
    v_cat_id BIGINT;
    v_fecha DATE;
    v_subtotal NUMERIC(15,2);
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Obtenemos categoría y fecha usando las claves reales de tu esquema
        SELECT id_categoria INTO v_cat_id FROM producto WHERE id_producto = NEW.id_producto;
        SELECT fecha::date INTO v_fecha FROM pedido WHERE nro_pedido = NEW.nro_pedido;
        
        -- Calculamos el subtotal al vuelo con las columnas reales
        v_subtotal := NEW.cantidad * NEW.precio_unitario;
        
        -- Insertamos o actualizamos la fila del reporte diario
        INSERT INTO reporte_diario_categoria (id_categoria, fecha, total_vendido)
        VALUES (v_cat_id, v_fecha, v_subtotal)
        ON CONFLICT (id_categoria, fecha)
        DO UPDATE SET total_vendido = reporte_diario_categoria.total_vendido + v_subtotal;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Creación del Trigger en la tabla detalle_pedido
DROP TRIGGER IF EXISTS trg_sync_ventas_cat ON detalle_pedido;
CREATE TRIGGER trg_sync_ventas_cat
AFTER INSERT ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_sync_ventas_categoria();

-- 4. Consulta optimizada (La que usamos para sacar la segunda captura)
EXPLAIN ANALYZE 
SELECT c.nombre AS categoria, rdc.total_vendido
FROM reporte_diario_categoria rdc
JOIN categoria c ON c.id_categoria = rdc.id_categoria
WHERE rdc.fecha = CURRENT_DATE
ORDER BY rdc.total_vendido DESC
LIMIT 5;

-- 5. Script de auditoría de consistencia (Para verificar integridad)
SELECT rdc.id_categoria, rdc.fecha, rdc.total_vendido AS calculado_trigger, SUM(dp.cantidad * dp.precio_unitario) AS real_en_tablas
FROM reporte_diario_categoria rdc
JOIN producto pr ON pr.id_categoria = rdc.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = pr.id_producto
JOIN pedido ped ON ped.nro_pedido = dp.nro_pedido AND ped.fecha::date = rdc.fecha
GROUP BY rdc.id_categoria, rdc.fecha, rdc.total_vendido
HAVING rdc.total_vendido <> SUM(dp.cantidad * dp.precio_unitario);