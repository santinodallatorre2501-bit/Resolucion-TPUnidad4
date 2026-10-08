-- 1. Esquema original y datos de ejemplo
CREATE TABLE control_lote_almacen (
    lote_id BIGINT NOT NULL REFERENCES lote(id),
    deposito_id BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen VALUES
(501, 30, 801),
(502, 30, 801),
(503, 31, 802);

-- 2. Tablas descompuestas (Aplicación de FNBC)
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id BIGINT NOT NULL REFERENCES deposito(id)
);

CREATE TABLE lote_responsable (
    lote_id BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- 3. Migración de datos verificada
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;

INSERT INTO lote_responsable (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id FROM control_lote_almacen;

-- 4. Vista de compatibilidad
CREATE VIEW v_control_lote_almacen AS
SELECT lr.lote_id, rd.deposito_id, lr.responsable_control_id
FROM lote_responsable lr
JOIN responsable_deposito rd ON lr.responsable_control_id = rd.responsable_control_id;