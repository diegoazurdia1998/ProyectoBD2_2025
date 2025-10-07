-- =====================================================================================
-- SCRIPT DE PRUEBAS PARA TRIGGERS
-- Sistema: ArteCryptoAuctions
-- Descripción: Pruebas completas para los 4 triggers del flujo NFT → Subasta
-- =====================================================================================

USE ArteCryptoAuctions;
GO

PRINT '=====================================================================================';
PRINT 'INICIANDO PRUEBAS DE TRIGGERS';
PRINT 'Fecha: ' + CONVERT(VARCHAR(30), GETDATE(), 120);
PRINT '=====================================================================================';
PRINT '';

-- =====================================================================================
-- CONFIGURACIÓN INICIAL Y LIMPIEZA
-- =====================================================================================
PRINT '--- PASO 0: Configuración Inicial ---';
PRINT '';

-- Limpiar datos de prueba anteriores (en orden inverso de dependencias)
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

PRINT 'Datos de prueba anteriores eliminados.';
PRINT '';

-- Asegurar que existen los estados necesarios
IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'PENDING')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('NFT', 'PENDING', N'NFT pendiente de aprobación');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'APPROVED')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('NFT', 'APPROVED', N'NFT aprobado');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'REJECTED')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('NFT', 'REJECTED', N'NFT rechazado');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'CURATION_DECISION' AND Code = 'PENDING')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('CURATION_DECISION', 'PENDING', N'Pendiente de revisión');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'CURATION_DECISION' AND Code = 'APPROVED')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('CURATION_DECISION', 'APPROVED', N'Aprobado por curador');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'CURATION_DECISION' AND Code = 'REJECTED')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('CURATION_DECISION', 'REJECTED', N'Rechazado por curador');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'AUCTION' AND Code = 'ACTIVE')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('AUCTION', 'ACTIVE', N'Subasta activa');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'USER_EMAIL' AND Code = 'ACTIVE')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('USER_EMAIL', 'ACTIVE', N'Email activo');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'EMAIL_OUTBOX' AND Code = 'PENDING')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('EMAIL_OUTBOX', 'PENDING', N'Email pendiente de envío');

PRINT 'Estados del sistema verificados.';
PRINT '';

-- Asegurar que existen los roles
IF NOT EXISTS (SELECT 1 FROM core.Role WHERE RoleId = 2)
    SET IDENTITY_INSERT core.Role ON;
    INSERT INTO core.Role(RoleId, [Name]) VALUES(2, 'ARTIST');
    SET IDENTITY_INSERT core.Role OFF;

IF NOT EXISTS (SELECT 1 FROM core.Role WHERE RoleId = 3)
    SET IDENTITY_INSERT core.Role ON;
    INSERT INTO core.Role(RoleId, [Name]) VALUES(3, 'CURATOR');
    SET IDENTITY_INSERT core.Role OFF;

IF NOT EXISTS (SELECT 1 FROM core.Role WHERE RoleId = 4)
    SET IDENTITY_INSERT core.Role ON;
    INSERT INTO core.Role(RoleId, [Name]) VALUES(4, 'BIDDER');
    SET IDENTITY_INSERT core.Role OFF;

PRINT 'Roles del sistema verificados.';
PRINT '';

-- Asegurar configuración de NFT
IF NOT EXISTS (SELECT 1 FROM nft.NFTSettings WHERE SettingsID = 1)
BEGIN
    INSERT INTO nft.NFTSettings(SettingsID, MaxWidthPx, MinWidthPx, MaxHeightPx, MinHeigntPx, MaxFileSizeBytes, MinFileSizeBytes, CreatedAtUtc)
    VALUES(1, 4096, 512, 4096, 512, 10485760, 10240, SYSUTCDATETIME());
    PRINT 'Configuración de NFT creada.';
END

-- Asegurar configuración de Subasta
IF NOT EXISTS (SELECT 1 FROM auction.AuctionSettings WHERE SettingsID = 1)
BEGIN
    INSERT INTO auction.AuctionSettings(SettingsID, CompanyName, BasePriceETH, DefaultAuctionHours, MinBidIncrementPct)
    VALUES(1, 'ArteCryptoAuctions', 0.01, 72, 5);
    PRINT 'Configuración de Subasta creada.';
END

PRINT '';
PRINT '=====================================================================================';
PRINT 'CREANDO USUARIOS DE PRUEBA';
PRINT '=====================================================================================';
PRINT '';

-- Crear usuarios de prueba
DECLARE @ArtistId1 BIGINT, @ArtistId2 BIGINT, @ArtistId3 BIGINT;
DECLARE @CuratorId1 BIGINT, @CuratorId2 BIGINT;
DECLARE @BidderId1 BIGINT, @BidderId2 BIGINT, @BidderId3 BIGINT;

-- Artistas
INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('Carlos Artista', SYSUTCDATETIME());
SET @ArtistId1 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('María Pintora', SYSUTCDATETIME());
SET @ArtistId2 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('Juan Sin Rol', SYSUTCDATETIME());
SET @ArtistId3 = SCOPE_IDENTITY();

-- Curadores
INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('Ana Curadora', SYSUTCDATETIME());
SET @CuratorId1 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('Pedro Curador', SYSUTCDATETIME());
SET @CuratorId2 = SCOPE_IDENTITY();

-- Oferentes
INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('Luis Comprador', SYSUTCDATETIME());
SET @BidderId1 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('Sofia Coleccionista', SYSUTCDATETIME());
SET @BidderId2 = SCOPE_IDENTITY();

INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('Diego Inversor', SYSUTCDATETIME());
SET @BidderId3 = SCOPE_IDENTITY();

PRINT 'Usuarios creados:';
PRINT '  Artistas: ' + CAST(@ArtistId1 AS VARCHAR) + ', ' + CAST(@ArtistId2 AS VARCHAR) + ', ' + CAST(@ArtistId3 AS VARCHAR);
PRINT '  Curadores: ' + CAST(@CuratorId1 AS VARCHAR) + ', ' + CAST(@CuratorId2 AS VARCHAR);
PRINT '  Oferentes: ' + CAST(@BidderId1 AS VARCHAR) + ', ' + CAST(@BidderId2 AS VARCHAR) + ', ' + CAST(@BidderId3 AS VARCHAR);
PRINT '';

-- Asignar roles
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@ArtistId1, 2); -- ARTIST
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@ArtistId2, 2); -- ARTIST
-- @ArtistId3 NO tiene rol (para prueba de validación)

INSERT INTO core.UserRole(UserId, RoleId) VALUES(@CuratorId1, 3); -- CURATOR
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@CuratorId2, 3); -- CURATOR

INSERT INTO core.UserRole(UserId, RoleId) VALUES(@BidderId1, 4); -- BIDDER
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@BidderId2, 4); -- BIDDER
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@BidderId3, 4); -- BIDDER

PRINT 'Roles asignados correctamente.';
PRINT '';

-- Crear emails primarios
INSERT INTO core.UserEmail(UserId, Email, IsPrimary, StatusCode)
VALUES
    (@ArtistId1, 'carlos.artista@test.com', 1, 'ACTIVE'),
    (@ArtistId2, 'maria.pintora@test.com', 1, 'ACTIVE'),
    (@ArtistId3, 'juan.sinrol@test.com', 1, 'ACTIVE'),
    (@CuratorId1, 'ana.curadora@test.com', 1, 'ACTIVE'),
    (@CuratorId2, 'pedro.curador@test.com', 1, 'ACTIVE'),
    (@BidderId1, 'luis.comprador@test.com', 1, 'ACTIVE'),
    (@BidderId2, 'sofia.coleccionista@test.com', 1, 'ACTIVE'),
    (@BidderId3, 'diego.inversor@test.com', 1, 'ACTIVE');

PRINT 'Emails primarios configurados.';
PRINT '';

-- Crear wallets para oferentes
INSERT INTO core.Wallet(UserId, BalanceETH, ReservedETH)
VALUES
    (@BidderId1, 10.0, 0.0),
    (@BidderId2, 5.0, 0.0),
    (@BidderId3, 15.0, 0.0);

PRINT 'Wallets creados para oferentes.';
PRINT '';

-- =====================================================================================
-- PRUEBA 1: TRIGGER tr_NFT_InsertFlow
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'PRUEBA 1: TRIGGER tr_NFT_InsertFlow (Inserción de NFT)';
PRINT '=====================================================================================';
PRINT '';

-- Limpiar emails de pruebas anteriores
DELETE FROM audit.EmailOutbox;

PRINT '--- Test 1.1: Inserción exitosa de NFT con artista válido ---';
BEGIN TRY
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId1, 1, 'Obra Maestra Digital', 'Una hermosa obra de arte digital', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    PRINT 'NFT insertado correctamente';
    
    -- Verificar que se creó el NFT
    IF EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId1 AND [Name] = 'Obra Maestra Digital')
        PRINT 'NFT encontrado en la tabla nft.NFT';
    ELSE
        PRINT 'ERROR: NFT no encontrado';
    
    -- Verificar que se asignó un curador
    IF EXISTS (SELECT 1 FROM admin.CurationReview WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE ArtistId = @ArtistId1 AND [Name] = 'Obra Maestra Digital'))
        PRINT 'Registro de curación creado';
    ELSE
        PRINT 'ERROR: No se creó registro de curación';
    
    -- Verificar emails enviados
    DECLARE @EmailCount INT = (SELECT COUNT(*) FROM audit.EmailOutbox);
    PRINT 'Emails generados: ' + CAST(@EmailCount AS VARCHAR) + ' (esperados: 2 - artista + curador)';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

PRINT '--- Test 1.2: Rechazo por usuario sin rol ARTIST ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId3, 1, 'Obra Sin Permiso', 'Intento de usuario sin rol', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    -- Verificar que NO se insertó
    IF NOT EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId3)
        PRINT 'NFT correctamente rechazado (usuario sin rol ARTIST)';
    ELSE
        PRINT 'ERROR: NFT insertado cuando debería ser rechazado';
    
    -- Verificar email de notificación
    IF EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @ArtistId3 AND [Subject] LIKE '%Rol Inválido%')
        PRINT 'Email de rechazo enviado al usuario';
    ELSE
        PRINT 'ERROR: No se envió email de notificación';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

PRINT '--- Test 1.3: Rechazo por dimensiones inválidas ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    -- Intentar insertar con dimensiones fuera de rango
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId2, 1, 'Obra Muy Grande', 'Dimensiones inválidas', 'image/png', 2048000, 5000, 5000, 0.5, 'PENDING', SYSUTCDATETIME());
    
    -- Verificar que NO se insertó
    IF NOT EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId2 AND [Name] = 'Obra Muy Grande')
        PRINT 'NFT correctamente rechazado (dimensiones inválidas)';
    ELSE
        PRINT 'ERROR: NFT insertado con dimensiones inválidas';
    
    -- Verificar email de notificación
    IF EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @ArtistId2 AND [Subject] LIKE '%Validación Técnica%')
        PRINT 'Email de rechazo enviado al artista';
    ELSE
        PRINT 'ERROR: No se envió email de notificación';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

PRINT '--- Test 1.4: Inserción múltiple con Round-Robin ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    -- Insertar 3 NFTs para verificar distribución round-robin
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES
        (@ArtistId2, 1, 'Obra Digital 1', 'Primera obra', 'image/png', 2048000, 1920, 1080, 0.3, 'PENDING', SYSUTCDATETIME()),
        (@ArtistId2, 1, 'Obra Digital 2', 'Segunda obra', 'image/png', 2048000, 1920, 1080, 0.4, 'PENDING', SYSUTCDATETIME()),
        (@ArtistId2, 1, 'Obra Digital 3', 'Tercera obra', 'image/png', 2048000, 1920, 1080, 0.6, 'PENDING', SYSUTCDATETIME());
    
    PRINT '3 NFTs insertados correctamente';
    
    -- Verificar distribución de curadores
    SELECT 
        cr.CuratorId,
        u.FullName,
        COUNT(*) as NFTsAsignados
    FROM admin.CurationReview cr
    JOIN core.[User] u ON u.UserId = cr.CuratorId
    WHERE cr.NFTId IN (
        SELECT NFTId FROM nft.NFT 
        WHERE ArtistId = @ArtistId2 
        AND [Name] LIKE 'Obra Digital%'
    )
    GROUP BY cr.CuratorId, u.FullName;
    
    PRINT 'Distribución Round-Robin verificada (ver tabla arriba)';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- PRUEBA 2: TRIGGER tr_CurationReview_Decision
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'PRUEBA 2: TRIGGER tr_CurationReview_Decision (Decisión del Curador)';
PRINT '=====================================================================================';
PRINT '';

PRINT '--- Test 2.1: Aprobar NFT ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    -- Obtener un NFT pendiente
    DECLARE @NFTId1 BIGINT = (SELECT TOP 1 NFTId FROM nft.NFT WHERE StatusCode = 'PENDING' ORDER BY NFTId);
    DECLARE @ReviewId1 BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTId1);
    
    -- Aprobar el NFT
    UPDATE admin.CurationReview
    SET DecisionCode = 'APPROVED',
        ReviewedAtUtc = SYSUTCDATETIME(),
        Comment = 'Obra de excelente calidad'
    WHERE ReviewId = @ReviewId1;
    
    -- Verificar que el NFT cambió a APPROVED
    IF EXISTS (SELECT 1 FROM nft.NFT WHERE NFTId = @NFTId1 AND StatusCode = 'APPROVED')
        PRINT 'NFT aprobado correctamente';
    ELSE
        PRINT 'ERROR: NFT no cambió a estado APPROVED';
    
    -- Verificar emails
    IF EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE [Subject] LIKE '%Aprobado%')
        PRINT 'Email de aprobación enviado';
    ELSE
        PRINT 'ERROR: No se envió email de aprobación';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

PRINT '--- Test 2.2: Rechazar NFT ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    -- Obtener otro NFT pendiente
    DECLARE @NFTId2 BIGINT = (SELECT TOP 1 NFTId FROM nft.NFT WHERE StatusCode = 'PENDING' ORDER BY NFTId);
    DECLARE @ReviewId2 BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTId2);
    
    -- Rechazar el NFT
    UPDATE admin.CurationReview
    SET DecisionCode = 'REJECTED',
        ReviewedAtUtc = SYSUTCDATETIME(),
        Comment = 'No cumple con los estándares de calidad'
    WHERE ReviewId = @ReviewId2;
    
    -- Verificar que el NFT cambió a REJECTED
    IF EXISTS (SELECT 1 FROM nft.NFT WHERE NFTId = @NFTId2 AND StatusCode = 'REJECTED')
        PRINT 'NFT rechazado correctamente';
    ELSE
        PRINT 'ERROR: NFT no cambió a estado REJECTED';
    
    -- Verificar emails
    IF EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE [Subject] LIKE '%No Aprobado%')
        PRINT 'Email de rechazo enviado';
    ELSE
        PRINT 'ERROR: No se envió email de rechazo';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- PRUEBA 3: TRIGGER tr_NFT_CreateAuction
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'PRUEBA 3: TRIGGER tr_NFT_CreateAuction (Creación Automática de Subasta)';
PRINT '=====================================================================================';
PRINT '';

PRINT '--- Test 3.1: Crear subasta automáticamente al aprobar NFT ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    -- El NFT aprobado en Test 2.1 debería tener una subasta
    DECLARE @ApprovedNFTId BIGINT = (SELECT TOP 1 NFTId FROM nft.NFT WHERE StatusCode = 'APPROVED' ORDER BY ApprovedAtUtc DESC);
    
    -- Verificar que se creó la subasta
    IF EXISTS (SELECT 1 FROM auction.Auction WHERE NFTId = @ApprovedNFTId)
    BEGIN
        PRINT 'Subasta creada automáticamente';
        
        -- Mostrar detalles de la subasta
        SELECT 
            AuctionId,
            NFTId,
            StartingPriceETH,
            CurrentPriceETH,
            StatusCode,
            StartAtUtc,
            EndAtUtc
        FROM auction.Auction
        WHERE NFTId = @ApprovedNFTId;
        
        PRINT 'Detalles de subasta mostrados arriba';
    END
    ELSE
        PRINT 'ERROR: No se creó la subasta automáticamente';
    
    -- Verificar emails (artista + bidders)
    DECLARE @AuctionEmailCount INT = (SELECT COUNT(*) FROM audit.EmailOutbox WHERE [Subject] LIKE '%Subasta%');
    PRINT 'Emails de subasta enviados: ' + CAST(@AuctionEmailCount AS VARCHAR);
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- PRUEBA 4: TRIGGER tr_Bid_Validation
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'PRUEBA 4: TRIGGER tr_Bid_Validation (Validación de Ofertas)';
PRINT '=====================================================================================';
PRINT '';

PRINT '--- Test 4.1: Oferta válida ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    -- Obtener una subasta activa
    DECLARE @AuctionId BIGINT = (SELECT TOP 1 AuctionId FROM auction.Auction WHERE StatusCode = 'ACTIVE' ORDER BY AuctionId);
    DECLARE @CurrentPrice DECIMAL(38,18) = (SELECT CurrentPriceETH FROM auction.Auction WHERE AuctionId = @AuctionId);
    
    -- Hacer una oferta válida
    INSERT INTO auction.Bid(AuctionId, BidderId, AmountETH, PlacedAtUtc)
    VALUES(@AuctionId, @BidderId1, @CurrentPrice + 0.1, SYSUTCDATETIME());
    
    -- Verificar que se insertó la oferta
    IF EXISTS (SELECT 1 FROM auction.Bid WHERE AuctionId = @AuctionId AND BidderId = @BidderId1)
        PRINT 'Oferta insertada correctamente';
    ELSE
        PRINT 'ERROR: Oferta no insertada';
    
    -- Verificar que se actualizó el precio actual
    DECLARE @NewPrice DECIMAL(38,18) = (SELECT CurrentPriceETH FROM auction.Auction WHERE AuctionId = @AuctionId);
    IF @NewPrice = @CurrentPrice + 0.1
        PRINT 'Precio actual actualizado correctamente';
    ELSE
        PRINT 'ERROR: Precio actual no actualizado';
    
    -- Verificar emails
    IF EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE [Subject] LIKE '%Oferta Aceptada%')
        PRINT 'Email de confirmación enviado al oferente';
    ELSE
        PRINT 'ERROR: No se envió email de confirmación';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

PRINT '--- Test 4.2: Oferta inválida (menor al precio actual) ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    DECLARE @CurrentPrice2 DECIMAL(38,18) = (SELECT CurrentPriceETH FROM auction.Auction WHERE AuctionId = @AuctionId);
    
    -- Intentar oferta menor
    INSERT INTO auction.Bid(AuctionId, BidderId, AmountETH, PlacedAtUtc)
    VALUES(@AuctionId, @BidderId2, @CurrentPrice2 - 0.05, SYSUTCDATETIME());
    
    -- Verificar que NO se insertó
    IF NOT EXISTS (SELECT 1 FROM auction.Bid WHERE AuctionId = @AuctionId AND BidderId = @BidderId2)
        PRINT 'Oferta rechazada correctamente (menor al precio actual)';
    ELSE
        PRINT 'ERROR: Oferta insertada cuando debería ser rechazada';
    
    -- Verificar email de rechazo
    IF EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @BidderId2 AND [Subject] LIKE '%Rechazada%')
        PRINT 'Email de rechazo enviado';
    ELSE
        PRINT 'ERROR: No se envió email de rechazo';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

PRINT '--- Test 4.3: Múltiples ofertas y notificación al líder anterior ---';
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    DECLARE @CurrentPrice3 DECIMAL(38,18) = (SELECT CurrentPriceETH FROM auction.Auction WHERE AuctionId = @AuctionId);
    
    -- Segunda oferta (supera a la primera)
    INSERT INTO auction.Bid(AuctionId, BidderId, AmountETH, PlacedAtUtc)
    VALUES(@AuctionId, @BidderId3, @CurrentPrice3 + 0.2, SYSUTCDATETIME());
    
    -- Verificar que se insertó
    IF EXISTS (SELECT 1 FROM auction.Bid WHERE AuctionId = @AuctionId AND BidderId = @BidderId3)
        PRINT 'Segunda oferta insertada correctamente';
    ELSE
        PRINT 'ERROR: Segunda oferta no insertada';
    
    -- Verificar que el líder cambió
    DECLARE @NewLeader BIGINT = (SELECT CurrentLeaderId FROM auction.Auction WHERE AuctionId = @AuctionId);
    IF @NewLeader = @BidderId3
        PRINT 'Líder actualizado correctamente';
    ELSE
        PRINT 'ERROR: Líder no actualizado';
    
    -- Verificar email al líder anterior
    IF EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @BidderId1 AND [Subject] LIKE '%superado%')
        PRINT 'Email enviado al líder anterior';
    ELSE
        PRINT 'ERROR: No se notificó al líder anterior';
    
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- RESUMEN DE PRUEBAS
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'RESUMEN DE PRUEBAS';
PRINT '=====================================================================================';
PRINT '';

PRINT '--- Estado de NFTs ---';
SELECT 
    StatusCode,
    COUNT(*) as Cantidad
FROM nft.NFT
GROUP BY StatusCode;
PRINT '';

PRINT '--- Estado de Revisiones de Curación ---';
SELECT 
    DecisionCode,
    COUNT(*) as Cantidad
FROM admin.CurationReview
GROUP BY DecisionCode;
PRINT '';

PRINT '--- Subastas Creadas ---';
SELECT 
    COUNT(*) as TotalSubastas,
    SUM(CASE WHEN StatusCode = 'ACTIVE' THEN 1 ELSE 0 END) as Activas
FROM auction.Auction;
PRINT '';

PRINT '--- Ofertas Realizadas ---';
SELECT 
    COUNT(*) as TotalOfertas,
    MIN(AmountETH) as OfertaMinima,
    MAX(AmountETH) as OfertaMaxima,
    AVG(AmountETH) as OfertaPromedio
FROM auction.Bid;
PRINT '';

PRINT '--- Emails Generados ---';
SELECT 
    [Subject],
    COUNT(*) as Cantidad
FROM audit.EmailOutbox
GROUP BY [Subject]
ORDER BY COUNT(*) DESC;
PRINT '';

PRINT '=====================================================================================';
PRINT 'PRUEBAS COMPLETADAS';
PRINT 'Fecha: ' + CONVERT(VARCHAR(30), GETDATE(), 120);
PRINT '=====================================================================================';
GO
