/*
================================================================
VERIFICACIÓN PASO 1: (Después de ejecutar 01_initial_data.sql)
================================================================
-- Objetivo: Confirmar que los catálogos y configuraciones base están cargados.
*/
USE ArteCryptoAuctions;
GO

-- 1.1: Conteo de catálogos y roles
PRINT '--- Conteo de Catálogos y Roles ---';
SELECT 'ops.Status' AS Tabla, COUNT(*) AS Filas FROM ops.Status
UNION ALL
SELECT 'core.Role' AS Tabla, COUNT(*) AS Filas FROM core.Role;
GO

-- 1.2: Ver los roles específicos (deben ser 4)
PRINT '--- Roles Creados ---';
SELECT RoleId, Name FROM core.Role;
GO

-- 1.3: Ver las configuraciones (debe ser 1 fila cada una)
PRINT '--- Configuraciones del Sistema ---';
SELECT * FROM nft.NFTSettings;
SELECT * FROM auction.AuctionSettings;
GO

-- 1.4: Revisar que las tablas de proceso estén vacías
PRINT '--- Tablas de Proceso (Deben estar en 0) ---';
SELECT 'core.[User]' AS Tabla, COUNT(*) AS Filas FROM core.[User]
UNION ALL
SELECT 'nft.NFT' AS Tabla, COUNT(*) AS Filas FROM nft.NFT
UNION ALL
SELECT 'auction.Auction' AS Tabla, COUNT(*) AS Filas FROM auction.Auction;
GO

-- -----------------------------------------------------------------------------

/*
================================================================
VERIFICACIÓN PASO 2: (Después de ejecutar 02_entity_actors.sql)
================================================================
-- Objetivo: Confirmar que los "Actores" (Usuarios, Wallets) existen.
*/
USE ArteCryptoAuctions;
GO

-- 2.1: Conteo de las nuevas tablas de "Actores"
PRINT '--- Conteo de Actores ---';
SELECT 'core.[User]' AS Tabla, COUNT(*) AS Filas FROM core.[User]
UNION ALL
SELECT 'core.UserRole' AS Tabla, COUNT(*) AS Filas FROM core.UserRole
UNION ALL
SELECT 'core.UserEmail' AS Tabla, COUNT(*) AS Filas FROM core.UserEmail
UNION ALL
SELECT 'core.Wallet' AS Tabla, COUNT(*) AS Filas FROM core.Wallet;
GO

-- 2.2: Revisión de Roles: ¿Cuántos usuarios hay por cada rol?
-- (Los números deben coincidir con tu lógica de 'role_probs')
PRINT '--- Distribución de Roles ---';
SELECT
    r.Name,
    COUNT(ur.UserId) AS TotalUsuarios
FROM core.UserRole ur
JOIN core.Role r ON ur.RoleId = r.RoleId
GROUP BY r.Name
ORDER BY TotalUsuarios DESC;
GO

-- 2.3: Revisión de Wallets: ¿Tienen fondos los postores (Bidders)?
-- (RoleId = 4 para 'BIDDER')
PRINT '--- Fondos de Postores (Bidders) ---';
SELECT
    AVG(w.BalanceETH) AS SaldoPromedio_Bidders,
    SUM(CASE WHEN w.BalanceETH > 0 THEN 1 ELSE 0 END) AS BiddersConFondos,
    COUNT(w.UserId) AS TotalBidders
FROM core.Wallet w
JOIN core.UserRole ur ON w.UserId = ur.UserId
WHERE ur.RoleId = 4; -- Asumiendo RoleId 4 = BIDDER
GO

-- 2.4: Verificar emails primarios (debe ser 1 por usuario)
PRINT '--- Conteo de Emails Primarios por Usuario (Debe ser 1.00) ---';
SELECT AVG(CAST(TotalPrimarios AS FLOAT)) AS Promedio_EmailsPrimarios_PorUsuario
FROM (
    SELECT UserId, SUM(CAST(IsPrimary AS INT)) AS TotalPrimarios
    FROM core.UserEmail
    GROUP BY UserId
) AS SubQuery;
GO

-- -------------------------------------------------------------------------------

/*
================================================================
VERIFICACIÓN PASO 3: (Después de ejecutar 03_process_simulation.sql)
================================================================
-- Objetivo: Confirmar que la simulación de procesos (NFTs, Subastas,
--           Pujas, Finanzas) se ejecutó y pobló las tablas.
*/

USE ArteCryptoAuctions;
GO

-- 3.1: Conteo de todas las tablas del proceso
PRINT '--- Conteo de Tablas de Proceso ---';
SELECT 'nft.NFT' AS Tabla, COUNT(*) AS Filas FROM nft.NFT
UNION ALL
SELECT 'admin.CurationReview' AS Tabla, COUNT(*) AS Filas FROM admin.CurationReview
UNION ALL
SELECT 'auction.Auction' AS Tabla, COUNT(*) AS Filas FROM auction.Auction
UNION ALL
SELECT 'auction.Bid' AS Tabla, COUNT(*) AS Filas FROM auction.Bid
UNION ALL
SELECT 'finance.FundsReservation' AS Tabla, COUNT(*) AS Filas FROM finance.FundsReservation
UNION ALL
SELECT 'finance.Ledger' AS Tabla, COUNT(*) AS Filas FROM finance.Ledger
UNION ALL
SELECT 'audit.EmailOutbox' AS Tabla, COUNT(*) AS Filas FROM audit.EmailOutbox;
GO

-- 3.2: ¿Cómo se distribuyeron los estados de los NFTs?
-- (Debería reflejar tu p_map = {"APPROVED":0.65, "PENDING":0.20, "REJECTED":0.15})
PRINT '--- Distribución de Estados de NFT ---';
SELECT
    StatusCode,
    COUNT(*) AS TotalNFTs,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)) AS Pct
FROM nft.NFT
GROUP BY StatusCode;
GO

-- 3.3: ¿Cómo se distribuyeron los estados de las Subastas?
-- (Debería reflejar tu lógica de simulación)
PRINT '--- Distribución de Estados de Subasta ---';
SELECT
    StatusCode,
    COUNT(*) AS TotalSubastas
FROM auction.Auction
GROUP BY StatusCode;
GO

-- 3.4: "Auditoría" de una subasta completada (la más cara)
-- Esta consulta revisa el resultado final:
-- 1. La Subasta completada
-- 2. El NFT con su nuevo dueño
-- 3. Las entradas del Ledger (DEBIT al ganador, CREDIT al artista)
-- 4. La Reserva de fondos (CAPTURED)
PRINT '--- Auditoría de la Subasta Más Cara (End-to-End) ---';
WITH TopAuction AS (
    SELECT TOP 1
        AuctionId,
        NFTId,
        CurrentLeaderId AS WinnerId,
        CurrentPriceETH AS FinalPrice
    FROM auction.Auction
    WHERE StatusCode = 'COMPLETED' AND CurrentLeaderId IS NOT NULL
    ORDER BY CurrentPriceETH DESC
)
SELECT
    'Subasta' AS Entidad,
    a.AuctionId,
    n.Name AS NFT_Name,
    u_winner.FullName AS Ganador,
    a.FinalPrice AS PrecioFinal_ETH,
    -- El CurrentOwnerId del NFT debe ser el WinnerId
    CASE
        WHEN n.CurrentOwnerId = a.WinnerId THEN 'COINCIDE'
        ELSE 'ERROR'
    END AS TransferenciaOK,
    u_artist.FullName AS Artista
FROM TopAuction a
JOIN nft.NFT n ON a.NFTId = n.NFTId
JOIN core.[User] u_winner ON a.WinnerId = u_winner.UserId
JOIN core.[User] u_artist ON n.ArtistId = u_artist.UserId

UNION ALL

-- Movimientos en el Ledger para esa subasta
SELECT
    'Ledger' AS Entidad,
    l.AuctionId,
    u.FullName AS Usuario,
    l.EntryType,
    l.AmountETH,
    NULL AS Tmp1,
    NULL AS Tmp2
FROM finance.Ledger l
JOIN TopAuction a ON l.AuctionId = a.AuctionId
JOIN core.[User] u ON l.UserId = u.UserId

UNION ALL

-- Reserva de fondos para esa subasta
SELECT
    'Reserva' AS Entidad,
    r.AuctionId,
    u.FullName AS Usuario,
    r.StateCode, -- Debe ser 'CAPTURED'
    r.AmountETH,
    NULL AS Tmp1,
    NULL AS Tmp2
FROM finance.FundsReservation r
JOIN TopAuction a ON r.AuctionId = a.AuctionId
JOIN core.[User] u ON r.UserId = u.UserId
WHERE r.StateCode = 'CAPTURED'; -- Solo nos interesa la reserva capturada
GO


