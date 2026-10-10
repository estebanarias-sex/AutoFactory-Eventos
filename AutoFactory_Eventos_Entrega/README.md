# AutoFactory --- Eventos programados en MySQL

## Descripción

Proyecto para la actividad de desempeño ASP-03-05, Sistema 7:
AutoFactory. Implementa cinco eventos programados de MySQL para
automatizar tareas de inventario, producción, planificación,
mantenimiento y seguimiento de proveedores.

## Eventos implementados

1.  `EVT_VerificarStockComponentes`: diariamente registra alertas cuando
    el inventario está por debajo del stock mínimo y evita duplicar
    alertas pendientes.
2.  `EVT_GenerarReporteProduccion`: genera un reporte diario por línea
    con vehículos fabricados el día anterior y tiempo promedio de
    producción.
3.  `EVT_ActualizarPlanesProduccion`: estima la demanda con los
    vehículos fabricados en los últimos 30 días y limita el plan a la
    capacidad diaria de la línea.
4.  `EVT_ProgramarMantenimientoPreventivo`: programa mantenimiento
    preventivo para estaciones de trabajo a 30 días.
5.  `EVT_ControlarTiemposEntregaProveedores`: marca como `Retrasada` una
    orden de compra vencida que aún está pendiente o en proceso.

## Tablas auxiliares

Se crean cuatro tablas para guardar los resultados:
`alerta_stock_componentes`, `reporte_produccion_diario`,
`plan_produccion` y `mantenimiento_preventivo_estacion`. Las tablas
originales no se recrean.

## Requisitos e instrucciones

1.  Ejecutar primero el script original de `auto_factory`.
2.  Abrir `AutoFactory_eventos.sql` en MySQL Workbench y ejecutar el
    archivo.
3.  El usuario necesita permiso para habilitar `event_scheduler`. Si
    `SET GLOBAL event_scheduler = ON` genera error de permisos, pedir al
    administrador de MySQL que lo habilite.
4.  Verificar el programador con
    `SHOW VARIABLES LIKE 'event_scheduler';`.
5.  Comprobar los eventos con `SHOW EVENTS FROM auto_factory;`.
6.  Consultar las tablas auxiliares después de la ejecución programada.

Los eventos se ejecutan diariamente y su primera ejecución ocurre un día
después de instalar el script. Requieren que el servidor MySQL esté
activo y que `event_scheduler` esté habilitado.

## Estructura

``` text
AutoFactory-Eventos/
├── AutoFactory_eventos.sql
└── README.md
```
