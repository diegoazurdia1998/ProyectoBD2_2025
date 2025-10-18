-- =====================================================================================
-- SCRIPT DE DEMOSTRACIÓN COMPLETA - PROYECTO ARTECRYPTOAUCTIONS
-- Descripción: Este script simula el flujo completo del sistema, desde la creación
-- de usuarios hasta la finalización de una subasta, demostrando las Fases 1, 2 y 3.
-- =====================================================================================

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- FASE 0: LIMPIEZA Y RESETEO DE LA BASE DE DATOS
-- =====================================================================================
PRINT '============================================================';
PRINT '=== FASE 0: INICIANDO LIMPIEZA DE DATOS ANTERIORES...    ===';
PRINT '============================================================';

BEGIN TRANSACTION;
    -- Se eliminan los datos en orden inverso a las dependencias para evitar errores de FK
    PRINT '-> Eliminando datos transaccionales...';
    DELETE FROM finance.Ledger;
    DELETE FROM finance.FundsReservation;
    DELETE FROM auction.Bid;
    DELETE FROM admin.CurationReview;
    DELETE FROM auction.Auction;
    DELETE FROM audit.EmailOutbox;
    DELETE FROM core.UserRole;
    DELETE FROM core.UserEmail;
    DELETE FROM core.Wallet;
    DELETE FROM nft.NFT;
    DELETE FROM core.[User];
COMMIT;
GO

PRINT '-> Reiniciando contadores de identidad (IDENTITY)...';
-- Reseteamos los contadores para que los IDs empiecen desde 1 otra vez
DBCC CHECKIDENT ('finance.Ledger', RESEED, 0);
DBCC CHECKIDENT ('finance.FundsReservation', RESEED, 0);
DBCC CHECKIDENT ('auction.Bid', RESEED, 0);
DBCC CHECKIDENT ('admin.CurationReview', RESEED, 0);
DBCC CHECKIDENT ('auction.Auction', RESEED, 0);
DBCC CHECKIDENT ('audit.EmailOutbox', RESEED, 0);
DBCC CHECKIDENT ('core.UserEmail', RESEED, 0);
DBCC CHECKIDENT ('core.Wallet', RESEED, 0);
DBCC CHECKIDENT ('nft.NFT', RESEED, 0);
DBCC CHECKIDENT ('core.User', RESEED, 0);
GO

PRINT '✅ Limpieza completada. La base de datos está como nueva.';
GO

WAITFOR DELAY '00:00:00';

PRINT '============================================================';
PRINT '=== FASE 1: CONFIGURACIÓN INICIAL (USUARIOS Y WALLETS) ===';
PRINT '============================================================';

-- 1. Crear usuarios con sus roles
PRINT '-> Creando usuarios: 1 Artista, 1 Curador, y 2 Postores (Bidders)...';

INSERT INTO core.[User] (FullName) VALUES 
('Valentina, la Artista'),
('Carlos, el Curador'),
('Brenda, la Postora'),
('David, el Postor');

DECLARE @ArtistId BIGINT = (SELECT UserId FROM core.[User] WHERE FullName = 'Valentina, la Artista');
DECLARE @CuratorId BIGINT = (SELECT UserId FROM core.[User] WHERE FullName = 'Carlos, el Curador');
DECLARE @Bidder1Id BIGINT = (SELECT UserId FROM core.[User] WHERE FullName = 'Brenda, la Postora');
DECLARE @Bidder2Id BIGINT = (SELECT UserId FROM core.[User] WHERE FullName = 'David, el Postor');

INSERT INTO core.UserRole (UserId, RoleId) VALUES
(@ArtistId, 2),  -- ARTIST
(@CuratorId, 3), -- CURATOR
(@Bidder1Id, 4), -- BIDDER
(@Bidder2Id, 4); -- BIDDER

-- 2. Asignar emails y wallets con saldo inicial
PRINT '-> Configurando emails y wallets con saldo inicial...';

INSERT INTO core.UserEmail (UserId, Email, IsPrimary) VALUES
(@ArtistId, 'valentina@arte.com', 1),
(@CuratorId, 'carlos@curador.com', 1),
(@Bidder1Id, 'brenda@bid.com', 1),
(@Bidder2Id, 'david@bid.com', 1);

INSERT INTO core.Wallet (UserId, BalanceETH) VALUES
(@ArtistId, 10.0), -- Saldo inicial para el artista
(@Bidder1Id, 5.0),  -- Saldo inicial para Brenda
(@Bidder2Id, 7.5);  -- Saldo inicial para David

PRINT '-> Estado inicial de las wallets:';
SELECT U.FullName, W.BalanceETH, W.ReservedETH
FROM core.Wallet W
JOIN core.[User] U ON U.UserId = W.UserId;

WAITFOR DELAY '00:00:00';
PRINT '';
PRINT '========================================================================';
PRINT '=== FASE 2: ENVÍO Y CURACIÓN DE UN NFT (VALIDACIONES Y APROBACIÓN) ===';
PRINT '========================================================================';

-- 1. Intento de envío de NFT con datos inválidos (demuestra validación)
PRINT '-> 1. Intento fallido: La artista intenta subir un NFT con dimensiones incorrectas...';

BEGIN TRY
    EXEC nft.sp_SubmitNFT
        @ArtistId = 1, -- Valentina
        @SettingsID = 1,
        @Name = N'Cielo de Fuego (Versión Inválida)',
        @Description = N'Una obra que no cumple los requisitos.',
        @ContentType = N'image/png',
        @HashCode = '1111111111111111111111111111111111111111111111111111111111111111',
        @FileSizeBytes = 50000,
        @WidthPx = 100, -- Ancho inválido (muy pequeño)
        @HeightPx = 800,
        @SuggestedPriceETH = 0.5;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El procedimiento almacenado rechazó el NFT como se esperaba.';
    PRINT '   Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;

WAITFOR DELAY '00:00:00';
-- 2. Envío exitoso de un NFT válido
PRINT '';
PRINT '-> 2. Intento exitoso: La artista sube un NFT que cumple todas las reglas...';

DECLARE @ValidHashCode CHAR(64) = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
EXEC nft.sp_SubmitNFT
    @ArtistId = 1, -- Valentina
    @SettingsID = 1,
    @Name = N'Amanecer en Atitlán',
    @Description = N'Una representación digital del majestuoso lago.',
    @ContentType = N'image/jpeg',
    @HashCode = @ValidHashCode,
    @FileSizeBytes = 8000000, -- 8MB
    @WidthPx = 1920,
    @HeightPx = 1080,
    @SuggestedPriceETH = 1.25;

DECLARE @NewNFTId int
select @NewNFTId = n.NFTId from nft.NFT n where n.Name = 'Amanecer en Atitlán';
WAITFOR DELAY '00:00:00';
PRINT '-> Revisando el estado del NFT y la tarea de curación...';
SELECT NFTId, Name, ArtistId, StatusCode FROM nft.NFT WHERE Name = 'Amanecer en Atitlán';


WAITFOR DELAY '00:00:00';
-- 3. Proceso de Aprobación
PRINT '';
PRINT '-> 3. Curación: Carlos, el Curador, aprueba el NFT...';
UPDATE admin.CurationReview
SET DecisionCode = 'APPROVED', ReviewedAtUtc = SYSUTCDATETIME()
WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE Name = 'Amanecer en Atitlán');

WAITFOR DELAY '00:00:00';
PRINT '-> Verificando el resultado del trigger de aprobación...';
PRINT '   - El estado del NFT debe ser "APPROVED".';
PRINT '   - Una nueva subasta debe haberse creado automáticamente.';

SELECT NFTId, Name, StatusCode, ApprovedAtUtc FROM nft.NFT WHERE Name = 'Amanecer en Atitlán';
SELECT AuctionId, NFTId, StartingPriceETH, CurrentPriceETH, StatusCode AS AuctionStatus FROM auction.Auction WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE Name = 'Amanecer en Atitlán');

WAITFOR DELAY '00:00:00';
PRINT '';
PRINT '=======================================================================';
PRINT '=== FASE 3: SUBASTA (OFERTAS, CONCURRENCIA Y CONSISTENCIA) ===';
PRINT '=======================================================================';


DECLARE @AuctionId BIGINT = (SELECT AuctionId FROM auction.Auction WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE Name = 'Amanecer en Atitlán'));

PRINT '-> La subasta para "Amanecer en Atitlán" está activa.';
PRINT '-> Precio Inicial: 1.25 ETH.';

-- 1. Primera oferta válida
PRINT '';
PRINT '-> 1. Brenda (Postor 1) hace la primera oferta válida de 1.5 ETH...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId, @BidderId = @Bidder1Id, @AmountETH = 1.5;


WAITFOR DELAY '00:00:00';
PRINT '-> Verificando estado post-oferta:';
SELECT AuctionId, CurrentPriceETH, CurrentLeaderId FROM auction.Auction WHERE AuctionId = (SELECT AuctionId FROM auction.Auction WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE Name = 'Amanecer en Atitlán'));
PRINT '-> Verificando wallets y reservas:';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);
SELECT ReservationId, UserId, AmountETH, StateCode FROM finance.FundsReservation WHERE AuctionId = (SELECT AuctionId FROM auction.Auction WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE Name = 'Amanecer en Atitlán'));


WAITFOR DELAY '00:00:00';
-- 2. Segunda oferta válida (supera a la anterior)
PRINT '';
PRINT '-> 2. David (Postor 2) supera la oferta con 2.0 ETH...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId, @BidderId = @Bidder2Id, @AmountETH = 2.0;


WAITFOR DELAY '00:00:00';
PRINT '-> Verificando estado post-oferta:';
PRINT '   - David debe ser el nuevo líder.';
PRINT '   - La reserva de Brenda debe estar "RELEASED".';
PRINT '   - La reserva de David debe estar "ACTIVE".';
PRINT '   - Los fondos reservados en las wallets deben reflejar el cambio.';

SELECT AuctionId, CurrentPriceETH, CurrentLeaderId FROM auction.Auction WHERE AuctionId = (SELECT AuctionId FROM auction.Auction WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE Name = 'Amanecer en Atitlán'));
PRINT '-> Verificando wallets y reservas:';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);
SELECT ReservationId, UserId, AmountETH, StateCode FROM finance.FundsReservation WHERE AuctionId = (SELECT AuctionId FROM auction.Auction WHERE NFTId = (SELECT NFTId FROM nft.NFT WHERE Name = 'Amanecer en Atitlán'));


WAITFOR DELAY '00:00:00';
-- 3. Intento de oferta inválida (monto muy bajo)
PRINT '';
PRINT '-> 3. Intento fallido: Brenda intenta ofertar 2.05 ETH, que es menor al incremento mínimo...';
BEGIN TRY
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId, @BidderId = @Bidder1Id, @AmountETH = 2.05;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El SP rechazó la oferta baja como se esperaba.';
    PRINT '   Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;

WAITFOR DELAY '00:00:00';
-- 4. Intento de oferta inválida (fondos insuficientes)
PRINT '';
PRINT '-> 4. Intento fallido: Brenda intenta ofertar 10.0 ETH, pero no tiene saldo disponible...';
BEGIN TRY
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId, @BidderId = @Bidder1Id, @AmountETH = 10.0;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El SP rechazó la oferta por falta de fondos.';
    PRINT '   Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;

WAITFOR DELAY '00:00:02';
-- 5. Finalización de la Subasta (Simulación)
PRINT '';
PRINT '-> 5. Finalizando la subasta... (Simulando que el tiempo ha pasado)';
UPDATE auction.Auction
SET EndAtUtc = DATEADD(SECOND, -1, SYSUTCDATETIME()) -- Mover la fecha de fin al pasado
WHERE AuctionId = @AuctionId;

UPDATE auction.Auction
SET StatusCode = 'COMPLETED' -- Esto disparará el trigger de liquidación
WHERE AuctionId = @AuctionId;

WAITFOR DELAY '00:00:00';
PRINT '-> Verificando el estado final del sistema tras la liquidación:';
PRINT '   - David (Ganador) debe ser el nuevo dueño del NFT.';
PRINT '   - El balance de David debe haber disminuido en 2.0 ETH.';
PRINT '   - La reserva de David debe estar "CAPTURED".';
PRINT '   - El balance de la Artista (Valentina) debe haber aumentado.';
PRINT '   - Deben existir los asientos contables (Ledger) correctos.';

PRINT '-> Propietario final del NFT:';
SELECT NFTId, Name, CurrentOwnerId, U.FullName AS OwnerName FROM nft.NFT N JOIN core.[User] U ON U.UserId = N.CurrentOwnerId WHERE N.NFTId = @NewNFTId;

PRINT '-> Wallets finales (Artista y Postores):';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@ArtistId, @Bidder1Id, @Bidder2Id);

PRINT '-> Estado final de las reservas de fondos:';
SELECT ReservationId, UserId, AmountETH, StateCode FROM finance.FundsReservation WHERE AuctionId = @AuctionId;

PRINT '-> Libro Contable (Ledger) para esta subasta:';
SELECT EntryId, UserId, EntryType, AmountETH, [Description] FROM finance.Ledger WHERE AuctionId = @AuctionId;
GO

PRINT '';
PRINT '============================================================';
PRINT '===              DEMOSTRACIÓN FINALIZADA                 ===';
PRINT '============================================================';
GO