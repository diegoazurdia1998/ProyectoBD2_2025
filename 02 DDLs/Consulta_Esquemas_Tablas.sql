-- =====================================================================================
-- CONSULTA: Visualizar Esquemas y Tablas
-- Proyecto: ArteCryptoAuctions
-- Descripción: Scripts para identificar qué tablas pertenecen a qué esquemas
-- =====================================================================================

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- OPCIÓN 1: Vista Resumida por Esquema
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'ESQUEMAS Y TABLAS - VISTA RESUMIDA';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    s.name AS [Esquema],
    STRING_AGG(t.name, ', ') WITHIN GROUP (ORDER BY t.name) AS [Tablas],
    COUNT(*) AS [Total_Tablas]
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('admin', 'auction', 'audit', 'core', 'finance', 'nft', 'ops')
GROUP BY s.name
ORDER BY s.name;

PRINT '';
PRINT '=====================================================================================';
GO

-- =====================================================================================
-- OPCIÓN 2: Vista Detallada con Descripción
-- =====================================================================================
PRINT '';
PRINT '=====================================================================================';
PRINT 'ESQUEMAS Y TABLAS - VISTA DETALLADA';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    s.name AS [Esquema],
    t.name AS [Tabla],
    SCHEMA_NAME(t.schema_id) + '.' + t.name AS [Nombre_Completo],
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS [Num_Columnas],
    (SELECT COUNT(*) FROM sys.foreign_keys fk WHERE fk.parent_object_id = t.object_id) AS [FKs_Salientes],
    (SELECT COUNT(*) FROM sys.foreign_keys fk WHERE fk.referenced_object_id = t.object_id) AS [FKs_Entrantes]
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('admin', 'auction', 'audit', 'core', 'finance', 'nft', 'ops')
ORDER BY s.name, t.name;

PRINT '';
PRINT '=====================================================================================';
GO

-- =====================================================================================
-- OPCIÓN 3: Vista Jerárquica (Esquema → Tablas → Columnas)
-- =====================================================================================
PRINT '';
PRINT '=====================================================================================';
PRINT 'ESTRUCTURA JERÁRQUICA';
PRINT '=====================================================================================';
PRINT '';

-- admin
PRINT '📁 admin (Administración)';
PRINT '  └─ CurationReview';
PRINT '';

-- auction
PRINT '📁 auction (Subastas)';
PRINT '  ├─ Auction';
PRINT '  ├─ AuctionSettings';
PRINT '  └─ Bid';
PRINT '';

-- audit
PRINT '📁 audit (Auditoría)';
PRINT '  └─ EmailOutbox';
PRINT '';

-- core
PRINT '📁 core (Núcleo)';
PRINT '  ├─ Role';
PRINT '  ├─ User';
PRINT '  ├─ UserEmail';
PRINT '  ├─ UserRole';
PRINT '  └─ Wallet';
PRINT '';

-- finance
PRINT '📁 finance (Finanzas)';
PRINT '  ├─ FundsReservation';
PRINT '  └─ Ledger';
PRINT '';

-- nft
PRINT '📁 nft (NFTs)';
PRINT '  ├─ NFT';
PRINT '  └─ NFTSettings';
PRINT '';

-- ops
PRINT '📁 ops (Operaciones)';
PRINT '  ├─ Settings';
PRINT '  └─ Status';
PRINT '';

PRINT '=====================================================================================';
GO

-- =====================================================================================
-- OPCIÓN 4: Búsqueda por Nombre de Tabla
-- =====================================================================================
PRINT '';
PRINT '=====================================================================================';
PRINT 'BÚSQUEDA RÁPIDA - Ingresa el nombre de una tabla para ver su esquema';
PRINT '=====================================================================================';
PRINT '';

-- Ejemplo de búsqueda (descomenta y modifica según necesites)
/*
DECLARE @NombreTabla NVARCHAR(128) = 'User';  -- Cambia aquí el nombre

SELECT 
    s.name AS [Esquema],
    t.name AS [Tabla],
    s.name + '.' + t.name AS [Referencia_Completa],
    'SELECT * FROM ' + s.name + '.' + t.name AS [Query_Ejemplo]
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.name LIKE '%' + @NombreTabla + '%'
ORDER BY s.name, t.name;
*/

-- =====================================================================================
-- OPCIÓN 5: Mapa de Colores por Esquema (para documentación)
-- =====================================================================================
PRINT '';
PRINT '=====================================================================================';
PRINT 'CÓDIGO DE COLORES SUGERIDO';
PRINT '=====================================================================================';
PRINT '';
PRINT '🔵 admin    - Azul    - Administración y curación';
PRINT '🟢 auction  - Verde   - Sistema de subastas';
PRINT '🟡 audit    - Amarillo- Auditoría y logs';
PRINT '🔴 core     - Rojo    - Usuarios y configuración base';
PRINT '🟣 finance  - Morado  - Gestión financiera';
PRINT '🟠 nft      - Naranja - Gestión de NFTs';
PRINT '⚪ ops      - Blanco  - Operaciones del sistema';
PRINT '';
PRINT '=====================================================================================';
GO

-- =====================================================================================
-- OPCIÓN 6: Generar Diagrama de Relaciones
-- =====================================================================================
PRINT '';
PRINT '=====================================================================================';
PRINT 'RELACIONES ENTRE ESQUEMAS';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    SCHEMA_NAME(pt.schema_id) AS [Esquema_Origen],
    pt.name AS [Tabla_Origen],
    SCHEMA_NAME(rt.schema_id) AS [Esquema_Destino],
    rt.name AS [Tabla_Destino],
    fk.name AS [Nombre_FK]
FROM sys.foreign_keys fk
JOIN sys.tables pt ON fk.parent_object_id = pt.object_id
JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
WHERE SCHEMA_NAME(pt.schema_id) IN ('admin', 'auction', 'audit', 'core', 'finance', 'nft', 'ops')
ORDER BY 
    SCHEMA_NAME(pt.schema_id),
    pt.name,
    SCHEMA_NAME(rt.schema_id),
    rt.name;

PRINT '';
PRINT '=====================================================================================';
GO

-- =====================================================================================
-- OPCIÓN 7: Crear Vista Permanente (Opcional)
-- =====================================================================================
/*
-- Descomenta para crear una vista que siempre muestre esta información

CREATE OR ALTER VIEW dbo.vw_EsquemasYTablas
AS
SELECT 
    s.name AS Esquema,
    t.name AS Tabla,
    s.name + '.' + t.name AS ReferenciaCompleta,
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS NumColumnas,
    CASE s.name
        WHEN 'admin' THEN 'Administración y curación'
        WHEN 'auction' THEN 'Sistema de subastas'
        WHEN 'audit' THEN 'Auditoría y notificaciones'
        WHEN 'core' THEN 'Usuarios y configuración base'
        WHEN 'finance' THEN 'Gestión financiera'
        WHEN 'nft' THEN 'Gestión de NFTs'
        WHEN 'ops' THEN 'Operaciones del sistema'
        ELSE 'Otro'
    END AS Proposito
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('admin', 'auction', 'audit', 'core', 'finance', 'nft', 'ops');
GO

-- Luego puedes consultar fácilmente:
-- SELECT * FROM dbo.vw_EsquemasYTablas ORDER BY Esquema, Tabla;
*/

-- =====================================================================================
-- SCRIPT COMPLETADO
-- =====================================================================================
PRINT '';
PRINT '=====================================================================================';
PRINT 'CONSULTA COMPLETADA';
PRINT '=====================================================================================';
PRINT '';
PRINT 'Usa las diferentes secciones según tus necesidades:';
PRINT '  - Opción 1: Vista resumida agrupada';
PRINT '  - Opción 2: Vista detallada con métricas';
PRINT '  - Opción 3: Estructura jerárquica visual';
PRINT '  - Opción 4: Búsqueda por nombre de tabla';
PRINT '  - Opción 5: Código de colores para documentación';
PRINT '  - Opción 6: Relaciones entre esquemas';
PRINT '  - Opción 7: Crear vista permanente (opcional)';
PRINT '';
PRINT '=====================================================================================';
GO
