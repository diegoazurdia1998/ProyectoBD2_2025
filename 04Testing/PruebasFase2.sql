-- =====================================================================================
-- IMPLEMENTACIÓN DE CASOS DE PRUEBA - FASE 2
-- Sistema: ArteCryptoAuctions
-- Descripción: Implementación completa de los 25 casos de prueba documentados
-- Basado en: Casos_Prueba_Fase2.md
-- =====================================================================================

USE ArteCryptoAuctions;
GO

SET NOCOUNT ON;
GO

PRINT '=====================================================================================';
PRINT 'CASOS DE PRUEBA - FASE 2';
PRINT 'Sistema de Triggers para Gestión de NFTs y Subastas';
PRINT 'Fecha de Ejecución: ' + CONVERT(VARCHAR(30), GETDATE(), 120);
PRINT '=====================================================================================';
PRINT '';

-- =====================================================================================
-- VARIABLES GLOBALES PARA TRACKING DE RESULTADOS
-- =====================================================================================
DECLARE @TotalTests INT = 0;
DECLARE @PassedTests INT = 0;
DECLARE @FailedTests INT = 0;
DECLARE @TestResult VARCHAR(10);

-- =====================================================================================
-- PASO 0: CONFIGURACIÓN INICIAL Y LIMPIEZA
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'PASO 0: CONFIGURACIÓN INICIAL Y LIMPIEZA';
PRINT '=====================================================================================';
PRINT '';

-- Limpiar datos de prueba anteriores
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

-- Asegurar estados necesarios
IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'PENDING')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('NFT', 'PENDING', 'NFT pendiente de aprobación');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'APPROVED')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('NFT', 'APPROVED', 'NFT aprobado');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'REJECTED')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('NFT', 'REJECTED', 'NFT rechazado');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'CURATION_DECISION' AND Code = 'PENDING')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('CURATION_DECISION', 'PENDING', 'Pendiente de revisión');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'CURATION_DECISION' AND Code = 'APPROVED')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('CURATION_DECISION', 'APPROVED', 'Aprobado por curador');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'CURATION_DECISION' AND Code = 'REJECTED')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('CURATION_DECISION', 'REJECTED', 'Rechazado por curador');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'AUCTION' AND Code = 'ACTIVE')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('AUCTION', 'ACTIVE', 'Subasta activa');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'USER_EMAIL' AND Code = 'ACTIVE')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('USER_EMAIL', 'ACTIVE', 'Email activo');

IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'EMAIL_OUTBOX' AND Code = 'PENDING')
    INSERT INTO ops.Status(Domain, Code, Description) VALUES('EMAIL_OUTBOX', 'PENDING', 'Email pendiente de envío');

PRINT 'Estados del sistema verificados.';
PRINT '';

-- Asegurar roles
IF NOT EXISTS (SELECT 1 FROM core.Role WHERE RoleId = 2)
BEGIN
    SET IDENTITY_INSERT core.Role ON;
    INSERT INTO core.Role(RoleId, [Name]) VALUES(2, 'ARTIST');
    SET IDENTITY_INSERT core.Role OFF;
END

IF NOT EXISTS (SELECT 1 FROM core.Role WHERE RoleId = 3)
BEGIN
    SET IDENTITY_INSERT core.Role ON;
    INSERT INTO core.Role(RoleId, [Name]) VALUES(3, 'CURATOR');
    SET IDENTITY_INSERT core.Role OFF;
END

IF NOT EXISTS (SELECT 1 FROM core.Role WHERE RoleId = 4)
BEGIN
    SET IDENTITY_INSERT core.Role ON;
    INSERT INTO core.Role(RoleId, [Name]) VALUES(4, 'BIDDER');
    SET IDENTITY_INSERT core.Role OFF;
END

PRINT 'Roles del sistema verificados.';
PRINT '';

-- Configuración de NFT
IF NOT EXISTS (SELECT 1 FROM nft.NFTSettings WHERE SettingsID = 1)
BEGIN
    INSERT INTO nft.NFTSettings(SettingsID, MaxWidthPx, MinWidthPx, MaxHeightPx, MinHeigntPx, MaxFileSizeBytes, MinFileSizeBytes, CreatedAtUtc)
    VALUES(1, 4096, 512, 4096, 512, 10485760, 10240, SYSUTCDATETIME());
    PRINT 'Configuración de NFT creada.';
END

-- Configuración de Subasta
IF NOT EXISTS (SELECT 1 FROM auction.AuctionSettings WHERE SettingsID = 1)
BEGIN
    INSERT INTO auction.AuctionSettings(SettingsID, CompanyName, BasePriceETH, DefaultAuctionHours, MinBidIncrementPct)
    VALUES(1, 'ArteCryptoAuctions', 0.01, 72, 5);
    PRINT 'Configuración de Subasta creada.';
END

-- Resetear Round-Robin
IF EXISTS (SELECT 1 FROM ops.Settings WHERE SettingKey = 'CURATION_RR_POS')
    UPDATE ops.Settings SET SettingValue = '0', UpdatedAtUtc = SYSUTCDATETIME() WHERE SettingKey = 'CURATION_RR_POS';
ELSE
    INSERT INTO ops.Settings(SettingKey, SettingValue) VALUES('CURATION_RR_POS', '0');

PRINT '';

-- =====================================================================================
-- CREAR USUARIOS DE PRUEBA
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'CREANDO USUARIOS DE PRUEBA';
PRINT '=====================================================================================';
PRINT '';

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
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@ArtistId1, 2);
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@ArtistId2, 2);
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@CuratorId1, 3);
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@CuratorId2, 3);
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@BidderId1, 4);
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@BidderId2, 4);
INSERT INTO core.UserRole(UserId, RoleId) VALUES(@BidderId3, 4);

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
-- TRIGGER 1: tr_NFT_InsertFlow
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'TRIGGER 1: tr_NFT_InsertFlow - Inserción y Validación de NFTs';
PRINT '=====================================================================================';
PRINT '';

-- =====================================================================================
-- CP-T1-001: Inserción Exitosa de NFT con Datos Válidos
-- =====================================================================================
PRINT '--- CP-T1-001: Inserción Exitosa de NFT con Datos Válidos ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId1, 1, 'Obra Digital Abstracta', 'Composición digital de arte abstracto', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    -- Verificaciones
    IF EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId1 AND [Name] = 'Obra Digital Abstracta')
       AND EXISTS (SELECT 1 FROM admin.CurationReview WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE ArtistId = @ArtistId1 AND [Name] = 'Obra Digital Abstracta'))
       AND (SELECT COUNT(*) FROM audit.EmailOutbox) = 2
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
