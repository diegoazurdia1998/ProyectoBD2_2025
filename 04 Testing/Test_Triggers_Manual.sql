-- =====================================================================================
-- PRUEBAS MANUALES PASO A PASO - Triggers ArteCryptoAuctions
-- =====================================================================================
-- Este script te permite probar los triggers de forma interactiva
-- =====================================================================================

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- PASO 0: PREPARACIÓN (Ejecutar primero)
-- =====================================================================================

USE ArteCryptoAuctions;
GO

PRINT '=== PASO 0: PREPARACIÓN ===';
PRINT 'Limpiando datos de prueba...';

-- Limpiar datos previos
DELETE FROM finance.FundsReservation;
DELETE FROM finance.Ledger;
DELETE FROM auction.Bid;
DELETE FROM auction.Auction;
DELETE FROM admin.CurationReview;
DELETE FROM nft.NFT;
DELETE FROM core.Wallet;
DELETE FROM core.UserEmail;
DELETE FROM core.UserRole;
DELETE FROM audit.EmailOutbox;
DELETE FROM core.[User];

PRINT 'Datos limpiados.';
PRINT '';

-- Crear usuarios de prueba
PRINT 'Creando usuarios de prueba...';

DECLARE @Artist1 BIGINT, @Artist2 BIGINT;
DECLARE @Curator1 BIGINT, @Curator2 BIGINT;
DECLARE @Bidder1 BIGINT, @Bidder2 BIGINT, @Bidder3 BIGINT;

-- Artistas
INSERT INTO core.[User](FullName) VALUES('Carlos Artista');
SET @Artist1 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName) VALUES('María Pintora');
SET @Artist2 = SCOPE_IDENTITY();

-- Curadores
INSERT INTO core.[User](FullName) VALUES('Ana Curadora');
SET @Curator1 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName) VALUES('Pedro Curador');
SET @Curator2 = SCOPE_IDENTITY();

-- Oferentes
INSERT INTO core.[User](FullName) VALUES('Luis Comprador');
SET @Bidder1 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName) VALUES('Sofia Coleccionista');
SET @Bidder2 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName) VALUES('Diego Inversor');
SET @Bidder3 = SCOPE_IDENTITY();

-- Asignar roles
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@Artist1, 2), (@Artist2, 2); -- ARTIST
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@Curator1, 3), (@Curator2, 3); -- CURATOR
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@Bidder1, 4), (@Bidder2, 4), (@Bidder3, 4); -- BIDDER

-- Crear emails
INSERT INTO core.UserEmail(UserId, Email, IsPrimary, StatusCode) VALUES
    (@Artist1, 'carlos@test.com', 1, 'ACTIVE'),
    (@Artist2, 'maria@test.com', 1, 'ACTIVE'),
    (@Curator1, 'ana@test.com', 1, 'ACTIVE'),
    (@Curator2, 'pedro@test.com', 1, 'ACTIVE'),
    (@Bidder1, 'luis@test.com', 1, 'ACTIVE'),
    (@Bidder2, 'sofia@test.com', 1, 'ACTIVE'),
    (@Bidder3, 'diego@test.com', 1, 'ACTIVE');

-- Crear wallets
INSERT INTO core.Wallet(UserId, BalanceETH, ReservedETH) VALUES
    (@Bidder1, 10.0, 0.0),
    (@Bidder2, 5.0, 0.0),
    (@Bidder3, 15.0, 0.0);

PRINT 'Usuarios creados:';
PRINT '  Artista 1 (ID: ' + CAST(@Artist1 AS VARCHAR) + ') - carlos@test.com';
PRINT '  Artista 2 (ID: ' + CAST(@Artist2 AS VARCHAR) + ') - maria@test.com';
PRINT '  Curador 1 (ID: ' + CAST(@Curator1 AS VARCHAR) + ') - ana@test.com';
PRINT '  Curador 2 (ID: ' + CAST(@Curator2 AS VARCHAR) + ') - pedro@test.com';
PRINT '  Oferente 1 (ID: ' + CAST(@Bidder1 AS VARCHAR) + ') - luis@test.com';
PRINT '  Oferente 2 (ID: ' + CAST(@Bidder2 AS VARCHAR) + ') - sofia@test.com';
PRINT '  Oferente 3 (ID: ' + CAST(@Bidder3 AS VARCHAR) + ') - diego@test.com';
PRINT '';
PRINT 'Preparación completada. Ahora puedes ejecutar los siguientes pasos.';
PRINT '';
GO

-- =====================================================================================
-- PASO 1: INSERTAR UN NFT (Trigger: tr_NFT_InsertFlow)
-- =====================================================================================

USE ArteCryptoAuctions;
GO

PRINT '=== PASO 1: INSERTAR NFT ===';
PRINT 'Insertando NFT de prueba...';
PRINT '';

-- Obtener el ID del primer artista
DECLARE @ArtistId BIGINT = (SELECT TOP 1 UserId FROM core.UserRole WHERE RoleId = 2 ORDER BY UserId);

-- Insertar NFT
INSERT INTO nft.NFT(
    ArtistId, 
    SettingsID, 
    [Name], 
    [Description], 
    ContentType, 
    FileSizeBytes, 
    WidthPx, 
    HeightPx, 
    SuggestedPriceETH, 
    StatusCode, 
    CreatedAtUtc
)
VALUES(
    @ArtistId,
    1,
    'Obra Maestra Digital',
    'Una hermosa obra de arte digital creada con IA',
    'image/png',
    2048000,
    1920,
    1080,
    0.5,
    'PENDING',
    SYSUTCDATETIME()
);

PRINT 'NFT insertado';
PRINT '';

-- Verificar resultados
PRINT '--- NFT Creado ---';
SELECT 
    NFTId,
    ArtistId,
    [Name],
    StatusCode,
    HashCode,
    CreatedAtUtc
FROM nft.NFT
WHERE ArtistId = @ArtistId;
PRINT '';

PRINT '--- Curador Asignado ---';
SELECT 
    cr.ReviewId,
    cr.NFTId,
    cr.CuratorId,
    u.FullName as CuradorNombre,
    cr.DecisionCode,
    cr.StartedAtUtc
FROM admin.CurationReview cr
JOIN core.[User] u ON u.UserId = cr.CuratorId
WHERE cr.NFTId = (SELECT TOP 1 NFTId FROM nft.NFT WHERE ArtistId = @ArtistId ORDER BY NFTId DESC);
PRINT '';

PRINT '--- Emails Generados ---';
SELECT 
    EmailId,
    RecipientEmail,
    [Subject],
    LEFT([Body], 80) as BodyPreview
FROM audit.EmailOutbox
ORDER BY EmailId DESC;
PRINT '';
GO

-- =====================================================================================
-- PASO 2: APROBAR EL NFT (Trigger: tr_CurationReview_Decision)
-- =====================================================================================

USE ArteCryptoAuctions;
GO

PRINT '=== PASO 2: APROBAR NFT ===';
PRINT 'El curador aprueba el NFT...';
PRINT '';

-- Limpiar emails anteriores para ver solo los nuevos
DELETE FROM audit.EmailOutbox;

-- Obtener el ReviewId del NFT pendiente
DECLARE @ReviewId BIGINT = (
    SELECT TOP 1 ReviewId 
    FROM admin.CurationReview 
    WHERE DecisionCode = 'PENDING' 
    ORDER BY ReviewId
);

-- Aprobar el NFT
UPDATE admin.CurationReview
SET 
    DecisionCode = 'APPROVED',
    ReviewedAtUtc = SYSUTCDATETIME(),
    Comment = 'Excelente obra de arte, aprobada para subasta'
WHERE ReviewId = @ReviewId;

PRINT 'NFT aprobado por el curador';
PRINT '';

-- Verificar resultados
PRINT '--- Estado del NFT ---';
SELECT 
    NFTId,
    [Name],
    StatusCode,
    CreatedAtUtc,
    ApprovedAtUtc
FROM nft.NFT
WHERE NFTId = (SELECT NFTId FROM admin.CurationReview WHERE ReviewId = @ReviewId);
PRINT '';

PRINT '--- Revisión de Curación ---';
SELECT 
    ReviewId,
    NFTId,
    CuratorId,
    DecisionCode,
    Comment,
    ReviewedAtUtc
FROM admin.CurationReview
WHERE ReviewId = @ReviewId;
PRINT '';

PRINT '--- Emails de Aprobación ---';
SELECT 
    EmailId,
    RecipientEmail,
    [Subject],
    LEFT([Body], 80) as BodyPreview
FROM audit.EmailOutbox
ORDER BY EmailId DESC;
PRINT '';
GO

-- =====================================================================================
-- PASO 3: VERIFICAR SUBASTA CREADA (Trigger: tr_NFT_CreateAuction)
-- =====================================================================================

USE ArteCryptoAuctions;
GO

PRINT '=== PASO 3: VERIFICAR SUBASTA AUTOMÁTICA ===';
PRINT 'La subasta debería haberse creado automáticamente...';
PRINT '';

-- Verificar subasta
PRINT '--- Subasta Creada ---';
SELECT 
    a.AuctionId,
    a.NFTId,
    n.[Name] as NFTName,
    a.StartingPriceETH,
    a.CurrentPriceETH,
    a.StatusCode,
    a.StartAtUtc,
    a.EndAtUtc,
    DATEDIFF(HOUR, a.StartAtUtc, a.EndAtUtc) as DuracionHoras
FROM auction.Auction a
JOIN nft.NFT n ON n.NFTId = a.NFTId
WHERE a.StatusCode = 'ACTIVE';
PRINT '';

PRINT '--- Emails de Nueva Subasta ---';
SELECT 
    COUNT(*) as TotalEmails,
    [Subject]
FROM audit.EmailOutbox
GROUP BY [Subject];
PRINT '';
GO

-- =====================================================================================
-- RESUMEN FINAL
-- =====================================================================================

USE ArteCryptoAuctions;
GO

PRINT '=== RESUMEN FINAL ===';
PRINT '';

PRINT '--- Todos los NFTs ---';
SELECT 
    NFTId,
    ArtistId,
    [Name],
    StatusCode,
    SuggestedPriceETH,
    CreatedAtUtc,
    ApprovedAtUtc
FROM nft.NFT
ORDER BY NFTId;
PRINT '';

PRINT '--- Todas las Revisiones ---';
SELECT 
    cr.ReviewId,
    cr.NFTId,
    n.[Name] as NFTName,
    cr.CuratorId,
    u.FullName as Curador,
    cr.DecisionCode,
    cr.Comment
FROM admin.CurationReview cr
JOIN nft.NFT n ON n.NFTId = cr.NFTId
JOIN core.[User] u ON u.UserId = cr.CuratorId
ORDER BY cr.ReviewId;
PRINT '';

PRINT '--- Todas las Subastas ---';
SELECT 
    a.AuctionId,
    a.NFTId,
    n.[Name] as NFTName,
    a.StartingPriceETH,
    a.CurrentPriceETH,
    a.CurrentLeaderId,
    u.FullName as LiderActual,
    a.StatusCode
FROM auction.Auction a
JOIN nft.NFT n ON n.NFTId = a.NFTId
LEFT JOIN core.[User] u ON u.UserId = a.CurrentLeaderId
ORDER BY a.AuctionId;
PRINT '';

PRINT '--- Estadísticas ---';
SELECT 
    'NFTs Totales' as Metrica,
    COUNT(*) as Valor
FROM nft.NFT
UNION ALL
SELECT 
    'NFTs Aprobados',
    COUNT(*)
FROM nft.NFT
WHERE StatusCode = 'APPROVED'
UNION ALL
SELECT 
    'Subastas Activas',
    COUNT(*)
FROM auction.Auction
WHERE StatusCode = 'ACTIVE'
UNION ALL
SELECT 
    'Total de Ofertas',
    COUNT(*)
FROM auction.Bid
UNION ALL
SELECT 
    'Emails Generados (Total)',
    COUNT(*)
FROM audit.EmailOutbox;
PRINT '';

PRINT '=====================================================================================';
PRINT 'PRUEBAS MANUALES COMPLETADAS';
PRINT '=====================================================================================';
GO
