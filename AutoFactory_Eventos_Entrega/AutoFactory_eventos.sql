USE auto_factory;

-- Eventos MySQL: Sistema 7 AutoFactory
-- Ejecutar después de crear la base y las tablas originales.
-- El usuario necesita permisos para habilitar event_scheduler.

SET GLOBAL event_scheduler = ON;

CREATE TABLE IF NOT EXISTS alerta_stock_componentes (
 ID_alerta INT AUTO_INCREMENT PRIMARY KEY,
 ID_componente INT NOT NULL,
 cantidad_disponible INT NOT NULL,
 stock_minimo INT NOT NULL,
 fecha_alerta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 estado VARCHAR(20) NOT NULL DEFAULT 'Pendiente',
 FOREIGN KEY (ID_componente) REFERENCES componente(ID_componente)
);

CREATE TABLE IF NOT EXISTS reporte_produccion_diario (
 ID_reporte INT AUTO_INCREMENT PRIMARY KEY,
 fecha_reporte DATE NOT NULL,
 ID_linea INT NOT NULL,
 total_vehiculos INT NOT NULL DEFAULT 0,
 tiempo_promedio DECIMAL(10,2) NULL,
 fecha_generacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_reporte_fecha_linea (fecha_reporte, ID_linea),
 FOREIGN KEY (ID_linea) REFERENCES linea_produccion(ID_linea)
);

CREATE TABLE IF NOT EXISTS plan_produccion (
 ID_plan INT AUTO_INCREMENT PRIMARY KEY,
 ID_mod INT NOT NULL,
 ID_linea INT NOT NULL,
 demanda_estimada INT NOT NULL DEFAULT 0,
 cantidad_planificada INT NOT NULL DEFAULT 0,
 fecha_plan DATE NOT NULL,
 estado VARCHAR(20) NOT NULL DEFAULT 'Actualizado',
 UNIQUE KEY uq_plan_modelo_linea_fecha (ID_mod, ID_linea, fecha_plan),
 FOREIGN KEY (ID_mod) REFERENCES modelo_vehiculo(ID_mod),
 FOREIGN KEY (ID_linea) REFERENCES linea_produccion(ID_linea)
);

CREATE TABLE IF NOT EXISTS mantenimiento_preventivo_estacion (
 ID_mantenimiento INT AUTO_INCREMENT PRIMARY KEY,
 ID_estacion INT NOT NULL,
 fecha_programada DATE NOT NULL,
 descripcion VARCHAR(255) NOT NULL,
 estado VARCHAR(20) NOT NULL DEFAULT 'Programado',
 fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_mantenimiento_estacion_fecha (ID_estacion, fecha_programada),
 FOREIGN KEY (ID_estacion) REFERENCES estacion_trabajo(ID_estacion)
);

DROP EVENT IF EXISTS EVT_VerificarStockComponentes;
DROP EVENT IF EXISTS EVT_GenerarReporteProduccion;
DROP EVENT IF EXISTS EVT_ActualizarPlanesProduccion;
DROP EVENT IF EXISTS EVT_ProgramarMantenimientoPreventivo;
DROP EVENT IF EXISTS EVT_ControlarTiemposEntregaProveedores;

DELIMITER $$

-- 1. Registra alertas cuando el inventario está por debajo del mínimo.
CREATE EVENT EVT_VerificarStockComponentes
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
 INSERT INTO alerta_stock_componentes
  (ID_componente, cantidad_disponible, stock_minimo, fecha_alerta, estado)
 SELECT c.ID_componente, COALESCE(i.cantidad_disponible, 0),
        c.stock_minimo, NOW(), 'Pendiente'
 FROM componente c
 LEFT JOIN inventario i ON i.ID_componente = c.ID_componente
 WHERE COALESCE(i.cantidad_disponible, 0) < c.stock_minimo
 AND NOT EXISTS (
   SELECT 1 FROM alerta_stock_componentes a
   WHERE a.ID_componente = c.ID_componente AND a.estado = 'Pendiente'
 );
END$$

-- 2. Genera reporte diario de vehículos fabricados por línea.
CREATE EVENT EVT_GenerarReporteProduccion
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
 INSERT INTO reporte_produccion_diario
  (fecha_reporte, ID_linea, total_vehiculos, tiempo_promedio, fecha_generacion)
 SELECT CURDATE() - INTERVAL 1 DAY, lp.ID_linea,
        COUNT(v.ID_vehiculo), ROUND(AVG(v.tiempo_produccion), 2), NOW()
 FROM linea_produccion lp
 LEFT JOIN vehiculo v ON v.ID_linea = lp.ID_linea
   AND DATE(v.fecha_fabricacion) = CURDATE() - INTERVAL 1 DAY
 GROUP BY lp.ID_linea
 ON DUPLICATE KEY UPDATE
  total_vehiculos = VALUES(total_vehiculos),
  tiempo_promedio = VALUES(tiempo_promedio),
  fecha_generacion = NOW();
END$$

-- 3. Actualiza planes según demanda histórica y capacidad diaria.
-- Demanda estimada: vehículos del modelo fabricados en los últimos 30 días.
CREATE EVENT EVT_ActualizarPlanesProduccion
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
 INSERT INTO plan_produccion
  (ID_mod, ID_linea, demanda_estimada, cantidad_planificada, fecha_plan, estado)
 SELECT mv.ID_mod, lp.ID_linea, COALESCE(d.demanda, 0),
        LEAST(COALESCE(d.demanda, 0), lp.capacidad_diaria), CURDATE(), 'Actualizado'
 FROM modelo_vehiculo mv
 JOIN linea_produccion lp
   ON LOWER(TRIM(lp.tipo_vehiculo)) = LOWER(TRIM(mv.categoria))
 LEFT JOIN (
   SELECT ID_mod, COUNT(*) AS demanda
   FROM vehiculo
   WHERE fecha_fabricacion >= CURDATE() - INTERVAL 30 DAY
   GROUP BY ID_mod
 ) d ON d.ID_mod = mv.ID_mod
 ON DUPLICATE KEY UPDATE
  demanda_estimada = VALUES(demanda_estimada),
  cantidad_planificada = VALUES(cantidad_planificada),
  estado = 'Actualizado';
END$$

-- 4. Programa mantenimiento de las estaciones a 30 días.
CREATE EVENT EVT_ProgramarMantenimientoPreventivo
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
 INSERT IGNORE INTO mantenimiento_preventivo_estacion
  (ID_estacion, fecha_programada, descripcion, estado)
 SELECT ID_estacion, CURDATE() + INTERVAL 30 DAY,
        CONCAT('Mantenimiento preventivo de estación ', codigo_estacion),
        'Programado'
 FROM estacion_trabajo;
END$$

-- 5. Marca como retrasadas las órdenes de compra vencidas y pendientes.
CREATE EVENT EVT_ControlarTiemposEntregaProveedores
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE ENABLE
DO
BEGIN
 UPDATE orden_compra
 SET estado = 'Retrasada'
 WHERE fecha_entrega_estimada < CURDATE()
   AND LOWER(estado) IN ('pendiente', 'en proceso');
END$$

DELIMITER ;

-- Comprobaciones
SHOW VARIABLES LIKE 'event_scheduler';
SHOW EVENTS FROM auto_factory;
SELECT * FROM alerta_stock_componentes;
SELECT * FROM reporte_produccion_diario;
SELECT * FROM plan_produccion;
SELECT * FROM mantenimiento_preventivo_estacion;
SELECT * FROM orden_compra WHERE LOWER(estado) = 'retrasada';

-- Consultar la definición de cada evento:
-- SHOW CREATE EVENT EVT_VerificarStockComponentes;
-- SHOW CREATE EVENT EVT_GenerarReporteProduccion;
-- SHOW CREATE EVENT EVT_ActualizarPlanesProduccion;
-- SHOW CREATE EVENT EVT_ProgramarMantenimientoPreventivo;
-- SHOW CREATE EVENT EVT_ControlarTiemposEntregaProveedores;
