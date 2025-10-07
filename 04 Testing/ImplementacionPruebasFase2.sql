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
        PRINT 'NFT insertado, curador asignado, 2 emails generados';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Verificaciones no cumplidas';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T1-002: Rechazo por Usuario sin Rol ARTIST
-- =====================================================================================
PRINT '--- CP-T1-002: Rechazo por Usuario sin Rol ARTIST ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId3, 1, 'Intento de NFT Sin Permiso', 'Usuario sin rol de artista', 'image/png', 2048000, 1920, 1080, 0.3, 'PENDING', SYSUTCDATETIME());
    
    -- Verificaciones
    IF NOT EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId3)
       AND EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @ArtistId3 AND [Subject] LIKE '%Rol Inválido%')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'NFT correctamente rechazado, email de notificación enviado';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'NFT insertado cuando debería ser rechazado o email no enviado';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T1-003: Rechazo por Usuario sin Email Primario
-- =====================================================================================
PRINT '--- CP-T1-003: Rechazo por Usuario sin Email Primario ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Crear usuario con rol ARTIST pero sin email primario
    DECLARE @ArtistSinEmail BIGINT;
    INSERT INTO core.[User](FullName, CreatedAtUtc) VALUES('Artista Sin Email', SYSUTCDATETIME());
    SET @ArtistSinEmail = SCOPE_IDENTITY();
    INSERT INTO core.UserRole(UserId, RoleId) VALUES(@ArtistSinEmail, 2);
    
    DELETE FROM audit.EmailOutbox;
    
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistSinEmail, 1, 'NFT Sin Email', 'Usuario sin email configurado', 'image/png', 2048000, 1920, 1080, 0.4, 'PENDING', SYSUTCDATETIME());
    
    -- Verificaciones
    IF NOT EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistSinEmail)
       AND EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @ArtistSinEmail AND [Subject] LIKE '%Email Requerido%')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'NFT correctamente rechazado, notificación generada';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'NFT insertado cuando debería ser rechazado';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T1-004: Rechazo por Dimensiones Inválidas (Ancho Excedido)
-- =====================================================================================
PRINT '--- CP-T1-004: Rechazo por Dimensiones Inválidas (Ancho Excedido) ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId2, 1, 'Imagen Muy Ancha', 'Excede el ancho máximo permitido', 'image/png', 2048000, 5000, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    -- Verificaciones
    IF NOT EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId2 AND [Name] = 'Imagen Muy Ancha')
       AND EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @ArtistId2 AND [Subject] LIKE '%Validación Técnica%')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'NFT rechazado por ancho excedido, email enviado';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'NFT insertado con dimensiones inválidas';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T1-005: Rechazo por Dimensiones Inválidas (Alto Menor al Mínimo)
-- =====================================================================================
PRINT '--- CP-T1-005: Rechazo por Dimensiones Inválidas (Alto Menor al Mínimo) ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId2, 1, 'Imagen Muy Baja', 'Altura menor al mínimo', 'image/png', 2048000, 1920, 400, 0.5, 'PENDING', SYSUTCDATETIME());
    
    -- Verificaciones
    IF NOT EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId2 AND [Name] = 'Imagen Muy Baja')
       AND EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @ArtistId2 AND [Subject] LIKE '%Validación Técnica%')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'NFT rechazado por altura menor al mínimo';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'NFT insertado con altura inválida';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T1-006: Rechazo por Tamaño de Archivo Excedido
-- =====================================================================================
PRINT '--- CP-T1-006: Rechazo por Tamaño de Archivo Excedido ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId2, 1, 'Archivo Muy Grande', 'Excede el tamaño máximo', 'image/png', 15000000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    -- Verificaciones
    IF NOT EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId2 AND [Name] = 'Archivo Muy Grande')
       AND EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @ArtistId2 AND [Subject] LIKE '%Validación Técnica%')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'NFT rechazado por tamaño de archivo excedido';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'NFT insertado con archivo muy grande';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T1-007: Rechazo por Ausencia de Curadores
-- =====================================================================================
PRINT '--- CP-T1-007: Rechazo por Ausencia de Curadores ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Guardar curadores actuales
    SELECT UserId, RoleId INTO #TempCurators FROM core.UserRole WHERE RoleId = 3;
    
    -- Eliminar curadores temporalmente
    DELETE FROM core.UserRole WHERE RoleId = 3;
    DELETE FROM audit.EmailOutbox;
    
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId2, 1, 'NFT Sin Curadores', 'Sistema sin curadores disponibles', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    -- Verificaciones
    IF NOT EXISTS (SELECT 1 FROM nft.NFT WHERE ArtistId = @ArtistId2 AND [Name] = 'NFT Sin Curadores')
       AND EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE RecipientUserId = @ArtistId2 AND [Subject] LIKE '%Sin Curadores%')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'NFT rechazado por ausencia de curadores, notificación enviada';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Comportamiento incorrecto sin curadores';
    END
    
    -- Restaurar curadores
    INSERT INTO core.UserRole(UserId, RoleId) SELECT UserId, RoleId FROM #TempCurators;
    DROP TABLE #TempCurators;
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    -- Restaurar curadores en caso de error
    IF OBJECT_ID('tempdb..#TempCurators') IS NOT NULL
    BEGIN
        INSERT INTO core.UserRole(UserId, RoleId) SELECT UserId, RoleId FROM #TempCurators;
        DROP TABLE #TempCurators;
    END
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T1-008: Inserción Múltiple con Distribución Round-Robin
-- =====================================================================================
PRINT '--- CP-T1-008: Inserción Múltiple con Distribución Round-Robin ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DELETE FROM audit.EmailOutbox;
    
    -- Insertar 4 NFTs
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES
        (@ArtistId2, 1, 'NFT RR 1', 'Prueba Round-Robin 1', 'image/png', 2048000, 1920, 1080, 0.3, 'PENDING', SYSUTCDATETIME()),
        (@ArtistId2, 1, 'NFT RR 2', 'Prueba Round-Robin 2', 'image/png', 2048000, 1920, 1080, 0.3, 'PENDING', SYSUTCDATETIME()),
        (@ArtistId2, 1, 'NFT RR 3', 'Prueba Round-Robin 3', 'image/png', 2048000, 1920, 1080, 0.3, 'PENDING', SYSUTCDATETIME()),
        (@ArtistId2, 1, 'NFT RR 4', 'Prueba Round-Robin 4', 'image/png', 2048000, 1920, 1080, 0.3, 'PENDING', SYSUTCDATETIME());
    
    -- Verificar distribución
    DECLARE @Curator1Count INT, @Curator2Count INT;
    SELECT @Curator1Count = COUNT(*) FROM admin.CurationReview WHERE CuratorId = @CuratorId1 AND NFTId IN (SELECT NFTId FROM nft.NFT WHERE [Name] LIKE 'NFT RR%');
    SELECT @Curator2Count = COUNT(*) FROM admin.CurationReview WHERE CuratorId = @CuratorId2 AND NFTId IN (SELECT NFTId FROM nft.NFT WHERE [Name] LIKE 'NFT RR%');
    
    IF @Curator1Count = 2 AND @Curator2Count = 2
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Distribución Round-Robin correcta: Curador1=' + CAST(@Curator1Count AS VARCHAR) + ', Curador2=' + CAST(@Curator2Count AS VARCHAR);
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Distribución incorrecta: Curador1=' + CAST(@Curator1Count AS VARCHAR) + ', Curador2=' + CAST(@Curator2Count AS VARCHAR);
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T1-009: Generación de HashCode Único
-- =====================================================================================
PRINT '--- CP-T1-009: Generación de HashCode Único ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES
        (@ArtistId1, 1, 'NFT Duplicado', 'Contenido idéntico', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME()),
        (@ArtistId1, 1, 'NFT Duplicado', 'Contenido idéntico', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME()),
        (@ArtistId1, 1, 'NFT Duplicado', 'Contenido idéntico', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    -- Verificar unicidad de HashCode
    DECLARE @UniqueHashCount INT;
    SELECT @UniqueHashCount = COUNT(DISTINCT HashCode) FROM nft.NFT WHERE ArtistId = @ArtistId1 AND [Name] = 'NFT Duplicado';
    
    IF @UniqueHashCount = 3
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT '3 NFTs con HashCode únicos generados';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'HashCode duplicados encontrados';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- TRIGGER 2: tr_CurationReview_Decision
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'TRIGGER 2: tr_CurationReview_Decision - Decisiones de Curación';
PRINT '=====================================================================================';
PRINT '';

-- =====================================================================================
-- CP-T2-001: Aprobación Exitosa de NFT
-- =====================================================================================
PRINT '--- CP-T2-001: Aprobación Exitosa de NFT ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Obtener un NFT pendiente
    DECLARE @NFTId1 BIGINT = (SELECT TOP 1 NFTId FROM nft.NFT WHERE StatusCode = 'PENDING' ORDER BY NFTId);
    DECLARE @ReviewId1 BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTId1);
    
    DELETE FROM audit.EmailOutbox;
    
    -- Aprobar el NFT
    UPDATE admin.CurationReview
    SET DecisionCode = 'APPROVED',
        ReviewedAtUtc = SYSUTCDATETIME(),
        Comment = 'Obra de excelente calidad artística'
    WHERE ReviewId = @ReviewId1;
    
    -- Verificaciones
    IF EXISTS (SELECT 1 FROM nft.NFT WHERE NFTId = @NFTId1 AND StatusCode = 'APPROVED')
       AND EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE [Subject] LIKE '%Aprobado%')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'NFT aprobado correctamente, emails enviados';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Estado no actualizado o emails no enviados';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T2-002: Rechazo de NFT
-- =====================================================================================
PRINT '--- CP-T2-002: Rechazo de NFT ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Obtener otro NFT pendiente
    DECLARE @NFTId2 BIGINT = (SELECT TOP 1 NFTId FROM nft.NFT WHERE StatusCode = 'PENDING' ORDER BY NFTId);
    DECLARE @ReviewId2 BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTId2);
    
    DELETE FROM audit.EmailOutbox;
    
    -- Rechazar el NFT
    UPDATE admin.CurationReview
    SET DecisionCode = 'REJECTED',
        ReviewedAtUtc = SYSUTCDATETIME(),
        Comment = 'No cumple con los estándares de calidad requeridos'
    WHERE ReviewId = @ReviewId2;
    
    -- Verificaciones
    IF EXISTS (SELECT 1 FROM nft.NFT WHERE NFTId = @NFTId2 AND StatusCode = 'REJECTED')
       AND NOT EXISTS (SELECT 1 FROM auction.Auction WHERE NFTId = @NFTId2)
       AND EXISTS (SELECT 1 FROM audit.EmailOutbox WHERE [Subject] LIKE '%No Aprobado%')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'NFT rechazado correctamente, sin subasta creada';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Estado incorrecto o subasta creada indebidamente';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T2-003: Actualización sin Cambio de Decisión
-- =====================================================================================
PRINT '--- CP-T2-003: Actualización sin Cambio de Decisión ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DECLARE @NFTId3 BIGINT = (SELECT TOP 1 NFTId FROM nft.NFT WHERE StatusCode = 'PENDING' ORDER BY NFTId);
    DECLARE @ReviewId3 BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTId3);
    
    DELETE FROM audit.EmailOutbox;
    
    -- Actualizar solo comentario
    UPDATE admin.CurationReview
    SET Comment = 'Comentario actualizado'
    WHERE ReviewId = @ReviewId3;
    
    -- Verificaciones
    IF (SELECT COUNT(*) FROM audit.EmailOutbox) = 0
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Trigger no ejecutado, sin emails generados';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Trigger ejecutado cuando no debería';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T2-004: Cambio de PENDING a APPROVED con ReviewedAtUtc NULL
-- =====================================================================================
PRINT '--- CP-T2-004: Cambio de PENDING a APPROVED con ReviewedAtUtc NULL ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DECLARE @NFTId4 BIGINT = (SELECT TOP 1 NFTId FROM nft.NFT WHERE StatusCode = 'PENDING' ORDER BY NFTId);
    DECLARE @ReviewId4 BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTId4);
    
    -- Asegurar que ReviewedAtUtc es NULL
    UPDATE admin.CurationReview SET ReviewedAtUtc = NULL WHERE ReviewId = @ReviewId4;
    
    -- Aprobar sin proporcionar ReviewedAtUtc
    UPDATE admin.CurationReview
    SET DecisionCode = 'APPROVED'
    WHERE ReviewId = @ReviewId4;
    
    -- Verificaciones
    IF EXISTS (SELECT 1 FROM admin.CurationReview WHERE ReviewId = @ReviewId4 AND ReviewedAtUtc IS NOT NULL)
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'ReviewedAtUtc actualizado automáticamente';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'ReviewedAtUtc no actualizado';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T2-005: Múltiples Decisiones Simultáneas
-- =====================================================================================
PRINT '--- CP-T2-005: Múltiples Decisiones Simultáneas ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Obtener 3 NFTs pendientes
    DECLARE @ReviewIds TABLE(ReviewId BIGINT, NFTId BIGINT);
    INSERT INTO @ReviewIds
    SELECT TOP 3 cr.ReviewId, cr.NFTId 
    FROM admin.CurationReview cr
    JOIN nft.NFT n ON n.NFTId = cr.NFTId
    WHERE n.StatusCode = 'PENDING' AND cr.DecisionCode = 'PENDING'
    ORDER BY cr.ReviewId;
    
    DELETE FROM audit.EmailOutbox;
    
    -- Aprobar múltiples
    UPDATE admin.CurationReview
    SET DecisionCode = 'APPROVED',
        ReviewedAtUtc = SYSUTCDATETIME()
    WHERE ReviewId IN (SELECT ReviewId FROM @ReviewIds);
    
    -- Verificaciones
    DECLARE @ApprovedCount INT = (SELECT COUNT(*) FROM nft.NFT WHERE NFTId IN (SELECT NFTId FROM @ReviewIds) AND StatusCode = 'APPROVED');
    
    IF @ApprovedCount = 3
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT '3 NFTs aprobados simultáneamente';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'No todos los NFTs fueron aprobados';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T2-006: Intento de Cambio de APPROVED a PENDING
-- =====================================================================================
PRINT '--- CP-T2-006: Intento de Cambio de APPROVED a PENDING ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DECLARE @ApprovedReviewId BIGINT = (SELECT TOP 1 ReviewId FROM admin.CurationReview WHERE DecisionCode = 'APPROVED' ORDER BY ReviewId);
    DECLARE @ApprovedNFTId BIGINT = (SELECT NFTId FROM admin.CurationReview WHERE ReviewId = @ApprovedReviewId);
    
    DELETE FROM audit.EmailOutbox;
    
    -- Intentar cambiar a PENDING
    UPDATE admin.CurationReview
    SET DecisionCode = 'PENDING'
    WHERE ReviewId = @ApprovedReviewId;
    
    -- Verificaciones
    IF EXISTS (SELECT 1 FROM nft.NFT WHERE NFTId = @ApprovedNFTId AND StatusCode = 'APPROVED')
       AND (SELECT COUNT(*) FROM audit.EmailOutbox) = 0
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Estado del NFT no revertido, trigger no ejecutado';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Estado revertido o trigger ejecutado indebidamente';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- TRIGGER 3: tr_NFT_CreateAuction
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'TRIGGER 3: tr_NFT_CreateAuction - Creación Automática de Subastas';
PRINT '=====================================================================================';
PRINT '';

-- =====================================================================================
-- CP-T3-001: Creación Exitosa de Subasta
-- =====================================================================================
PRINT '--- CP-T3-001: Creación Exitosa de Subasta ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- El NFT aprobado en CP-T2-001 debería tener subasta
    DECLARE @ApprovedNFT BIGINT = (SELECT TOP 1 NFTId FROM nft.NFT WHERE StatusCode = 'APPROVED' ORDER BY ApprovedAtUtc DESC);
    
    -- Verificaciones
    IF EXISTS (SELECT 1 FROM auction.Auction WHERE NFTId = @ApprovedNFT AND StatusCode = 'ACTIVE')
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Subasta creada automáticamente con estado ACTIVE';
        
        SELECT AuctionId, StartingPriceETH, CurrentPriceETH, StartAtUtc, EndAtUtc
        FROM auction.Auction WHERE NFTId = @ApprovedNFT;
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Subasta no creada';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-002: Uso de SuggestedPriceETH como Precio Inicial
-- =====================================================================================
PRINT '--- CP-T3-002: Uso de SuggestedPriceETH como Precio Inicial ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Crear NFT con precio sugerido específico
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId1, 1, 'NFT Precio Sugerido', 'Con precio sugerido 0.75', 'image/png', 2048000, 1920, 1080, 0.75, 'PENDING', SYSUTCDATETIME());
    
    DECLARE @NFTConPrecio BIGINT = (SELECT NFTId FROM nft.NFT WHERE [Name] = 'NFT Precio Sugerido');
    DECLARE @ReviewPrecio BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTConPrecio);
    
    -- Aprobar
    UPDATE admin.CurationReview SET DecisionCode = 'APPROVED', ReviewedAtUtc = SYSUTCDATETIME() WHERE ReviewId = @ReviewPrecio;
    
    -- Verificaciones
    DECLARE @StartPrice DECIMAL(38,18) = (SELECT StartingPriceETH FROM auction.Auction WHERE NFTId = @NFTConPrecio);
    
    IF @StartPrice = 0.75
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Precio inicial = 0.75 ETH (precio sugerido)';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Precio inicial incorrecto: ' + CAST(@StartPrice AS VARCHAR);
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-003: Uso de BasePriceETH cuando SuggestedPriceETH es NULL
-- =====================================================================================
PRINT '--- CP-T3-003: Uso de BasePriceETH cuando SuggestedPriceETH es NULL ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Crear NFT sin precio sugerido
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId1, 1, 'NFT Sin Precio', 'Sin precio sugerido', 'image/png', 2048000, 1920, 1080, NULL, 'PENDING', SYSUTCDATETIME());
    
    DECLARE @NFTSinPrecio BIGINT = (SELECT NFTId FROM nft.NFT WHERE [Name] = 'NFT Sin Precio');
    DECLARE @ReviewSinPrecio BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTSinPrecio);
    
    -- Aprobar
    UPDATE admin.CurationReview SET DecisionCode = 'APPROVED', ReviewedAtUtc = SYSUTCDATETIME() WHERE ReviewId = @ReviewSinPrecio;
    
    -- Verificaciones
    DECLARE @BasePrice DECIMAL(38,18) = (SELECT StartingPriceETH FROM auction.Auction WHERE NFTId = @NFTSinPrecio);
    
    IF @BasePrice = 0.01
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Precio inicial = 0.01 ETH (BasePriceETH)';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Precio inicial incorrecto: ' + CAST(@BasePrice AS VARCHAR);
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-004: Duración de Subasta según Configuración
-- =====================================================================================
PRINT '--- CP-T3-004: Duración de Subasta según Configuración ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DECLARE @TestAuctionId BIGINT = (SELECT TOP 1 AuctionId FROM auction.Auction ORDER BY AuctionId DESC);
    DECLARE @StartTime DATETIME2(3) = (SELECT StartAtUtc FROM auction.Auction WHERE AuctionId = @TestAuctionId);
    DECLARE @EndTime DATETIME2(3) = (SELECT EndAtUtc FROM auction.Auction WHERE AuctionId = @TestAuctionId);
    DECLARE @DurationHours INT = DATEDIFF(HOUR, @StartTime, @EndTime);
    
    IF @DurationHours = 72
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Duración = 72 horas (DefaultAuctionHours)';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Duración incorrecta: ' + CAST(@DurationHours AS VARCHAR) + ' horas';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-005: Prevención de Subastas Duplicadas
-- =====================================================================================
PRINT '--- CP-T3-005: Prevención de Subastas Duplicadas ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DECLARE @NFTConSubasta BIGINT = (SELECT TOP 1 NFTId FROM auction.Auction ORDER BY AuctionId);
    DECLARE @CountBefore INT = (SELECT COUNT(*) FROM auction.Auction WHERE NFTId = @NFTConSubasta);
    
    -- Intentar actualizar nuevamente a APPROVED
    UPDATE nft.NFT SET StatusCode = 'APPROVED' WHERE NFTId = @NFTConSubasta;
    
    DECLARE @CountAfter INT = (SELECT COUNT(*) FROM auction.Auction WHERE NFTId = @NFTConSubasta);
    
    IF @CountBefore = @CountAfter AND @CountAfter = 1
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'No se creó subasta duplicada';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Subasta duplicada creada';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-006: Notificación a Múltiples Bidders
-- =====================================================================================
PRINT '--- CP-T3-006: Notificación a Múltiples Bidders ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    DECLARE @BidderCount INT = (SELECT COUNT(DISTINCT UserId) FROM core.UserRole WHERE RoleId = 4);
    
    -- Crear y aprobar NFT
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId1, 1, 'NFT Notificaciones', 'Prueba notificaciones bidders', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    DECLARE @NFTNotif BIGINT = (SELECT NFTId FROM nft.NFT WHERE [Name] = 'NFT Notificaciones');
    DECLARE @ReviewNotif BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTNotif);
    
    DELETE FROM audit.EmailOutbox;
    
    UPDATE admin.CurationReview SET DecisionCode = 'APPROVED', ReviewedAtUtc = SYSUTCDATETIME() WHERE ReviewId = @ReviewNotif;
    
    -- Contar emails a bidders
    DECLARE @BidderEmails INT = (SELECT COUNT(*) FROM audit.EmailOutbox WHERE [Subject] LIKE '%Nueva Subasta Disponible%');
    
    IF @BidderEmails = @BidderCount
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Todos los bidders notificados: ' + CAST(@BidderEmails AS VARCHAR);
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Emails enviados: ' + CAST(@BidderEmails AS VARCHAR) + ', esperados: ' + CAST(@BidderCount AS VARCHAR);
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-007: Contenido de Notificación al Artista
-- =====================================================================================
PRINT '--- CP-T3-007: Contenido de Notificación al Artista ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Usar subasta ya creada
    DECLARE @TestNFTId BIGINT = (SELECT TOP 1 NFTId FROM auction.Auction ORDER BY AuctionId DESC);
    DECLARE @ArtistEmail VARCHAR(MAX) = (SELECT TOP 1 Body FROM audit.EmailOutbox WHERE [Subject] LIKE '%Subasta Iniciada%' ORDER BY EmailId DESC);
    
    IF @ArtistEmail LIKE '%AuctionId%' 
       AND @ArtistEmail LIKE '%ETH%'
       AND @ArtistEmail LIKE '%UTC%'
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Email contiene información completa de la subasta';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Email no contiene información completa';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-008: Manejo de Ausencia de Configuración de Subasta
-- =====================================================================================
PRINT '--- CP-T3-008: Manejo de Ausencia de Configuración de Subasta ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Guardar configuración actual
    SELECT * INTO #TempAuctionSettings FROM auction.AuctionSettings;
    
    -- Eliminar configuración
    DELETE FROM auction.AuctionSettings;
    
    -- Crear y aprobar NFT
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId1, 1, 'NFT Sin Config', 'Sin configuración de subasta', 'image/png', 2048000, 1920, 1080, NULL, 'PENDING', SYSUTCDATETIME());
    
    DECLARE @NFTSinConfig BIGINT = (SELECT NFTId FROM nft.NFT WHERE [Name] = 'NFT Sin Config');
    DECLARE @ReviewSinConfig BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTSinConfig);
    
    UPDATE admin.CurationReview SET DecisionCode = 'APPROVED', ReviewedAtUtc = SYSUTCDATETIME() WHERE ReviewId = @ReviewSinConfig;
    
    -- Verificar que se creó subasta con valores por defecto
    IF EXISTS (SELECT 1 FROM auction.Auction WHERE NFTId = @NFTSinConfig AND StartingPriceETH = 0.01)
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'Subasta creada con valores por defecto';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Subasta no creada o valores incorrectos';
    END
    
    -- Restaurar configuración
    INSERT INTO auction.AuctionSettings SELECT * FROM #TempAuctionSettings;
    DROP TABLE #TempAuctionSettings;
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    -- Restaurar configuración en caso de error
    IF OBJECT_ID('tempdb..#TempAuctionSettings') IS NOT NULL
    BEGIN
        INSERT INTO auction.AuctionSettings SELECT * FROM #TempAuctionSettings;
        DROP TABLE #TempAuctionSettings;
    END
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-009: Trigger No se Activa para NFT Rechazado
-- =====================================================================================
PRINT '--- CP-T3-009: Trigger No se Activa para NFT Rechazado ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Crear NFT y rechazarlo
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId1, 1, 'NFT Para Rechazar', 'Será rechazado', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    DECLARE @NFTRechazar BIGINT = (SELECT NFTId FROM nft.NFT WHERE [Name] = 'NFT Para Rechazar');
    DECLARE @ReviewRechazar BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTRechazar);
    
    UPDATE admin.CurationReview SET DecisionCode = 'REJECTED', ReviewedAtUtc = SYSUTCDATETIME() WHERE ReviewId = @ReviewRechazar;
    
    -- Verificar que NO se creó subasta
    IF NOT EXISTS (SELECT 1 FROM auction.Auction WHERE NFTId = @NFTRechazar)
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'No se creó subasta para NFT rechazado';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Subasta creada para NFT rechazado';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- CP-T3-010: Timestamp de Inicio Inmediato
-- =====================================================================================
PRINT '--- CP-T3-010: Timestamp de Inicio Inmediato ---';
SET @TotalTests = @TotalTests + 1;
BEGIN TRY
    -- Registrar timestamp antes de aprobar
    DECLARE @TimestampBeforeApproval DATETIME2(3) = SYSUTCDATETIME();
    
    -- Crear y aprobar NFT
    INSERT INTO nft.NFT(ArtistId, SettingsID, [Name], [Description], ContentType, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode, CreatedAtUtc)
    VALUES(@ArtistId1, 1, 'NFT Inicio Inmediato', 'Prueba timestamp de inicio', 'image/png', 2048000, 1920, 1080, 0.5, 'PENDING', SYSUTCDATETIME());
    
    DECLARE @NFTInmediato BIGINT = (SELECT NFTId FROM nft.NFT WHERE [Name] = 'NFT Inicio Inmediato');
    DECLARE @ReviewInmediato BIGINT = (SELECT ReviewId FROM admin.CurationReview WHERE NFTId = @NFTInmediato);
    
    -- Aprobar
    UPDATE admin.CurationReview SET DecisionCode = 'APPROVED', ReviewedAtUtc = SYSUTCDATETIME() WHERE ReviewId = @ReviewInmediato;
    
    -- Obtener StartAtUtc de la subasta creada
    DECLARE @AuctionStartTime DATETIME2(3) = (SELECT StartAtUtc FROM auction.Auction WHERE NFTId = @NFTInmediato);
    DECLARE @TimestampAfterApproval DATETIME2(3) = SYSUTCDATETIME();
    
    -- Calcular diferencia en segundos
    DECLARE @DiffSeconds INT = DATEDIFF(SECOND, @TimestampBeforeApproval, @AuctionStartTime);
    DECLARE @DiffSecondsAfter INT = DATEDIFF(SECOND, @AuctionStartTime, @TimestampAfterApproval);
    
    -- Verificar que la diferencia es menor a 2 segundos (tolerancia para procesamiento)
    IF @DiffSeconds >= 0 AND @DiffSeconds <= 2 AND @DiffSecondsAfter >= 0 AND @DiffSecondsAfter <= 2
    BEGIN
        SET @PassedTests = @PassedTests + 1;
        PRINT 'RESULTADO: EXITOSO';
        PRINT 'StartAtUtc es aproximadamente igual al timestamp de aprobación';
        PRINT 'Diferencia: ' + CAST(@DiffSeconds AS VARCHAR) + ' segundos';
    END
    ELSE
    BEGIN
        SET @FailedTests = @FailedTests + 1;
        PRINT 'RESULTADO: FALLIDO';
        PRINT 'Diferencia de tiempo excede el límite aceptable';
        PRINT 'Diferencia: ' + CAST(@DiffSeconds AS VARCHAR) + ' segundos';
    END
END TRY
BEGIN CATCH
    SET @FailedTests = @FailedTests + 1;
    PRINT 'RESULTADO: FALLIDO';
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
PRINT '';

-- =====================================================================================
-- FIN DE CASOS DE PRUEBA
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'EJECUCIÓN DE PRUEBAS COMPLETADA';
PRINT '=====================================================================================';
PRINT '';
PRINT 'Total de Pruebas Ejecutadas: ' + CAST(@TotalTests AS VARCHAR);
PRINT 'Pruebas Exitosas: ' + CAST(@PassedTests AS VARCHAR);
PRINT 'Pruebas Fallidas: ' + CAST(@FailedTests AS VARCHAR);
PRINT 'Porcentaje de Éxito: ' + CAST((@PassedTests * 100.0 / @TotalTests) AS VARCHAR(10)) + '%';
PRINT '';
PRINT '=====================================================================================';
GO
