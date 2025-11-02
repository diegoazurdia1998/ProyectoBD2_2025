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
(@Bidder1Id, 5.0),  -- Saldo inicial para Brenda (CLAVE PARA PRUEBA)
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
    PRINT '    Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;

WAITFOR DELAY '00:00:00';
-- 2. Envío exitoso de un NFT válido
PRINT '';
PRINT '-> 2. Intento exitoso: La artista sube un NFT que cumple todas las reglas...';

DECLARE @ValidHashCode1 CHAR(64) = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
EXEC nft.sp_SubmitNFT
    @ArtistId = 1, -- Valentina
    @SettingsID = 1,
    @Name = N'Amanecer en Atitlán',
    @Description = N'Una representación digital del majestuoso lago.',
    @ContentType = N'image/jpeg',
    @HashCode = @ValidHashCode1,
    @FileSizeBytes = 8000000, -- 8MB
    @WidthPx = 1920,
    @HeightPx = 1080,
    @SuggestedPriceETH = 1.25;

DECLARE @NewNFTId1 int
select @NewNFTId1 = n.NFTId from nft.NFT n where n.Name = 'Amanecer en Atitlán';

PRINT '-> Revisando el estado del NFT y la tarea de curación...';
SELECT NFTId, Name, ArtistId, StatusCode FROM nft.NFT WHERE Name = 'Amanecer en Atitlán';


WAITFOR DELAY '00:00:00';
-- 3. Proceso de Aprobación
PRINT '';
PRINT '-> 3. Curación: Carlos, el Curador, aprueba el NFT "Amanecer en Atitlán"...';
UPDATE admin.CurationReview
SET DecisionCode = 'APPROVED', ReviewedAtUtc = SYSUTCDATETIME()
WHERE NFTId = @NewNFTId1;

WAITFOR DELAY '00:00:00';
PRINT '-> Verificando el resultado del trigger de aprobación...';
PRINT '    - El estado del NFT debe ser "APPROVED".';
PRINT '    - Una nueva subasta debe haberse creado automáticamente.';

SELECT NFTId, Name, StatusCode, ApprovedAtUtc FROM nft.NFT WHERE NFTId = @NewNFTId1;
SELECT AuctionId, NFTId, StartingPriceETH, CurrentPriceETH, StatusCode AS AuctionStatus FROM auction.Auction WHERE NFTId = @NewNFTId1;


-- =====================================================================================
-- == INICIO DE SECCIÓN MODIFICADA: AÑADIR UN SEGUNDO NFT PARA LA FASE 3 AVANZADA ==
-- =====================================================================================
PRINT '';
PRINT '-> 4. Preparando un segundo NFT para pruebas de concurrencia de fondos...';
DECLARE @ValidHashCode2 CHAR(64) = 'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
EXEC nft.sp_SubmitNFT
    @ArtistId = 1, -- Valentina
    @SettingsID = 1,
    @Name = N'Luna de Neón',
    @Description = N'Paisaje urbano futurista.',
    @ContentType = N'image/jpeg',
    @HashCode = @ValidHashCode2,
    @FileSizeBytes = 7000000, -- 7MB
    @WidthPx = 2000,
    @HeightPx = 2000,
    @SuggestedPriceETH = 2.5;

DECLARE @NewNFTId2 int
select @NewNFTId2 = n.NFTId from nft.NFT n where n.Name = 'Luna de Neón';

PRINT '-> 5. Aprobando el segundo NFT para crear una segunda subasta activa...';
UPDATE admin.CurationReview
SET DecisionCode = 'APPROVED', ReviewedAtUtc = SYSUTCDATETIME()
WHERE NFTId = @NewNFTId2;

WAITFOR DELAY '00:00:00';
PRINT '-> Verificando que ambas subastas están activas:';
SELECT AuctionId, N.Name, A.StartingPriceETH, A.StatusCode AS AuctionStatus
FROM auction.Auction A
JOIN nft.NFT N ON A.NFTId = N.NFTId
WHERE A.StatusCode = 'ACTIVE';
-- =====================================================================================
-- == FIN DE SECCIÓN MODIFICADA                                                        ==
-- =====================================================================================


WAITFOR DELAY '00:00:00';
PRINT '';
PRINT '================================================================================';
PRINT '=== FASE 3A: SUBASTA (OFERTAS, CONSISTENCIA Y NOTIFICACIONES)                ===';
PRINT '================================================================================';


DECLARE @AuctionId1 BIGINT = (SELECT AuctionId FROM auction.Auction WHERE NFTId = @NewNFTId1);
DECLARE @AuctionId2 BIGINT = (SELECT AuctionId FROM auction.Auction WHERE NFTId = @NewNFTId2);

PRINT '-> Subasta 1 ("Amanecer en Atitlán") está activa.';
PRINT '-> Precio Inicial: 1.25 ETH.';

-- 1. Primera oferta válida
PRINT '';
PRINT '-> 1. Brenda (Postor 1) hace la primera oferta válida de 1.5 ETH...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 1.5;


WAITFOR DELAY '00:00:00';
PRINT '-> Verificando estado post-oferta:';
SELECT AuctionId, CurrentPriceETH, CurrentLeaderId FROM auction.Auction WHERE AuctionId = @AuctionId1;
PRINT '-> Verificando wallets y reservas:';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);
SELECT ReservationId, UserId, AmountETH, StateCode FROM finance.FundsReservation WHERE AuctionId = @AuctionId1;

-- =====================================================================================
-- == INICIO DE NUEVA PRUEBA: REVISIÓN DE NOTIFICACIONES                          ==
-- =====================================================================================
PRINT '';
PRINT '-> 1B. Verificando notificaciones:';
PRINT '    - El SP debe haber generado un email para Brenda (confirmación) y Valentina (notificación de oferta).';
SELECT eo.EmailId, RecipientEmail, Subject
FROM audit.EmailOutbox eo
WHERE eo.SentAtUtc IS NULL;

-- Limpiamos la bandeja de salida para la siguiente prueba
UPDATE audit.EmailOutbox SET SentAtUtc = SYSUTCDATETIME() WHERE SentAtUtc IS NULL;
-- =====================================================================================
-- == FIN DE NUEVA PRUEBA                                                             ==
-- =====================================================================================

WAITFOR DELAY '00:00:00';
-- 2. Segunda oferta válida (supera a la anterior)
PRINT '';
PRINT '-> 2. David (Postor 2) supera la oferta con 2.0 ETH...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder2Id, @AmountETH = 2.0;


WAITFOR DELAY '00:00:00';
PRINT '-> Verificando estado post-oferta:';
PRINT '    - David debe ser el nuevo líder.';
PRINT '    - La reserva de Brenda debe estar "RELEASED".';
PRINT '    - La reserva de David debe estar "ACTIVE".';
PRINT '    - Los fondos reservados en las wallets deben reflejar el cambio.';

SELECT AuctionId, CurrentPriceETH, CurrentLeaderId FROM auction.Auction WHERE AuctionId = @AuctionId1;
PRINT '-> Verificando wallets y reservas:';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);
SELECT ReservationId, UserId, AmountETH, StateCode FROM finance.FundsReservation WHERE AuctionId = @AuctionId1 ORDER BY ReservationId DESC;

-- =====================================================================================
-- == INICIO DE NUEVA PRUEBA: REVISIÓN DE NOTIFICACIONES                          ==
-- =====================================================================================
PRINT '';
PRINT '-> 2B. Verificando notificaciones:';
PRINT '    - Deben existir 3 emails:';
PRINT '    - 1. Para David (confirmación de su oferta ganadora).';
PRINT '    - 2. Para Brenda (notificación de que su oferta fue superada).';
PRINT '    - 3. Para Valentina (notificación de nueva oferta).';
SELECT EmailId, RecipientEmail, Subject
FROM audit.EmailOutbox
WHERE SentAtUtc IS NULL;
UPDATE audit.EmailOutbox SET SentAtUtc = SYSUTCDATETIME() WHERE SentAtUtc IS NULL;
-- =====================================================================================
-- == FIN DE NUEVA PRUEBA                                                             ==
-- =====================================================================================


WAITFOR DELAY '00:00:00';
-- 3. Intento de oferta inválida (monto muy bajo)
PRINT '';
PRINT '-> 3. Intento fallido: Brenda intenta ofertar 2.05 ETH, que es menor al incremento mínimo...';
BEGIN TRY
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 2.05;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El SP rechazó la oferta baja como se esperaba.';
    PRINT '    Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;

WAITFOR DELAY '00:00:00';
-- 4. Intento de oferta inválida (fondos insuficientes)
PRINT '';
PRINT '-> 4. Intento fallido: Brenda intenta ofertar 10.0 ETH, pero no tiene saldo disponible...';
BEGIN TRY
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 10.0;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El SP rechazó la oferta por falta de fondos.';
    PRINT '    Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;

WAITFOR DELAY '00:00:00';

PRINT '';
PRINT '================================================================================';
PRINT '=== FASE 3A: SUBASTA (OFERTAS INICIALES)                                     ===';
PRINT '================================================================================';

PRINT '-> Subasta 1 ("Amanecer en Atitlán") está activa. Precio Inicial: 1.25 ETH.';
PRINT '-> Subasta 2 ("Luna de Neón") está activa. Precio Inicial: 2.5 ETH.';

-- 1. Primera oferta válida (Brenda)
PRINT '';
PRINT '-> 1. Brenda (Postor 1) hace la primera oferta válida de 1.5 ETH en Subasta 1...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 1.5;

PRINT '-> Verificando wallets y reservas:';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);

WAITFOR DELAY '00:00:00';
-- 2. Segunda oferta válida (David)
PRINT '';
PRINT '-> 2. David (Postor 2) supera la oferta con 2.0 ETH en Subasta 1...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder2Id, @AmountETH = 2.0;

PRINT '-> Verificando wallets y reservas post-oferta:';
PRINT '    - David debe ser el nuevo líder.';
PRINT '    - La reserva de Brenda (1.5) debe estar "RELEASED".';
PRINT '    - El ReservedETH de Brenda debe ser 0.0.';
PRINT '    - El ReservedETH de David debe ser 2.0.';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);

PRINT '-> Verificando estado de Reservas:';
SELECT ReservationId, UserId, AmountETH, StateCode FROM finance.FundsReservation WHERE AuctionId = @AuctionId1 ORDER BY ReservationId DESC;

WAITFOR DELAY '00:00:00';
PRINT '';
PRINT '================================================================================';
PRINT '=== FASE 3B: GUERRA DE OFERTAS (PRUEBA DE CONSISTENCIA)                        ===';
PRINT '================================================================================';
PRINT '-> Inicia la guerra de ofertas por "Amanecer en Atitlán"...';
PRINT '-> Estado actual: David es líder con 2.0 ETH.';

-- OFERTA 3 (Brenda)
PRINT '';
PRINT '-> OFERTA 3: Brenda (Postor 1) responde con 2.5 ETH...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 2.5;

PRINT '-> Verificando: Brenda es líder. La reserva de David (2.0) debe ser "RELEASED".';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);

WAITFOR DELAY '00:00:01';

-- OFERTA 4 (David)
PRINT '';
PRINT '-> OFERTA 4: David (Postor 2) no se rinde y ofrece 3.0 ETH...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder2Id, @AmountETH = 3.0;

PRINT '-> Verificando: David es líder. La reserva de Brenda (2.5) debe ser "RELEASED".';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);

WAITFOR DELAY '00:00:01';

-- OFERTA 5 (Brenda)
PRINT '';
PRINT '-> OFERTA 5: Brenda hace un gran salto a 3.75 ETH...';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 3.75;

PRINT '-> Verificando: Brenda es líder. La reserva de David (3.0) debe ser "RELEASED".';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);

WAITFOR DELAY '00:00:01';

-- OFERTA 6 (David - Final)
PRINT '';
PRINT '-> OFERTA 6 (Final): David decide ganar y ofrece 4.25 ETH.';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder2Id, @AmountETH = 4.25;

PRINT '-> Verificando: David es el líder definitivo. La reserva de Brenda (3.75) debe ser "RELEASED".';
SELECT AuctionId, CurrentPriceETH, U.FullName AS CurrentLeader
FROM auction.Auction A JOIN core.[User] U ON U.UserId = A.CurrentLeaderId
WHERE A.AuctionId = @AuctionId1;
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@Bidder1Id, @Bidder2Id);

PRINT '-> Verificando el estado de TODAS las reservas de fondos para la Subasta 1:';
PRINT '   - Solo la última reserva (de David por 4.25) debe estar "ACTIVE".';
PRINT '   - Todas las demás deben estar "RELEASED".';
SELECT R.ReservationId, U.FullName, R.AmountETH, R.StateCode
FROM finance.FundsReservation R
JOIN core.[User] U ON U.UserId = R.UserId
WHERE R.AuctionId = @AuctionId1 ORDER BY R.ReservationId DESC;

PRINT '-> Verificando el historial completo de ofertas (tabla auction.Bid):';
SELECT B.BidderId, U.FullName, B.AmountETH, B.PlacedAtUtc
FROM auction.Bid B
JOIN core.[User] U ON U.UserId = B.BidderId
WHERE B.AuctionId = @AuctionId1 ORDER BY B.PlacedAtUtc ASC;

WAITFOR DELAY '00:00:00';
PRINT '';
PRINT '================================================================================';
PRINT '=== FASE 3C: PRUEBAS DE ROBUSTEZ Y LÓGICA DE NEGOCIO                         ===';
PRINT '================================================================================';

-- 1. Intento de oferta inválida (monto muy bajo)
PRINT '';
PRINT '-> 1. Intento fallido: Brenda intenta ofertar 4.30 ETH (incremento mínimo no cumplido)...';
BEGIN TRY
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 4.30;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El SP rechazó la oferta baja como se esperaba.';
    PRINT '    Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;

WAITFOR DELAY '00:00:00';
-- 2. Prueba de Fondos Compleja (Múltiples Subastas)
PRINT '';
PRINT '-> 2. Prueba de Fondos: Brenda (Saldo 5.0) intentará ofertar en la Subasta 2.';
PRINT '    - Brenda primero oferta 3.0 ETH en la Subasta 2 ("Luna de Neón").';
EXEC auction.sp_PlaceBid @AuctionId = @AuctionId2, @BidderId = @Bidder1Id, @AmountETH = 3.0;

PRINT '-> Verificando estado de Brenda: Saldo 5.0, Reservado 3.0 (Disponible 2.0)';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId = @Bidder1Id;

PRINT '';
PRINT '-> 3. Intento fallido (Fondos Insuficientes por Reserva):';
PRINT '    - Brenda intentará ofertar 4.5 ETH en la Subasta 1 (Líder David con 4.25).';
PRINT '    - La oferta es válida en monto, pero fallará porque su saldo DISPONIBLE es solo 2.0 ETH.';
BEGIN TRY
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 4.5;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El SP rechazó la oferta por falta de fondos DISPONIBLES (saldo - reserva).';
    PRINT '    Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;

WAITFOR DELAY '00:00:00';
-- 4. Prueba de Lógica de Negocio (Artista)
PRINT '';
PRINT '-> 4. Intento fallido (Lógica de Negocio): La artista (Valentina) intenta ofertar...';
BEGIN TRY
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @ArtistId, @AmountETH = 5.0;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El SP rechazó la oferta de la propia artista.';
    PRINT '    Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;


WAITFOR DELAY '00:00:02';
PRINT '';
PRINT '================================================================================';
PRINT '=== FASE 4: FINALIZACIÓN Y LIQUIDACIÓN DE LA SUBASTA                         ===';
PRINT '================================================================================';

PRINT '';
PRINT '-> 1. Finalizando la subasta principal ("Amanecer en Atitlán")...';
PRINT '    - El líder actual es David con 4.25 ETH.';
UPDATE auction.Auction
SET EndAtUtc = DATEADD(SECOND, -1, SYSUTCDATETIME()) -- Mover la fecha de fin al pasado
WHERE AuctionId = @AuctionId1;

UPDATE auction.Auction
SET StatusCode = 'COMPLETED' -- Esto disparará el trigger de liquidación
WHERE AuctionId = @AuctionId1;

WAITFOR DELAY '00:00:00';

-- 2. Intento de oferta inválida (Subasta Cerrada)
PRINT '';
PRINT '-> 2. Intento fallido (Lógica de Estado): Brenda intenta ofertar en la subasta ya "COMPLETED"...';
BEGIN TRY
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId1, @BidderId = @Bidder1Id, @AmountETH = 5.0;
END TRY
BEGIN CATCH
    PRINT '-> ✅ ÉXITO: El SP rechazó la oferta en una subasta cerrada.';
    PRINT '    Mensaje de error: ' + ERROR_MESSAGE();
END CATCH;


WAITFOR DELAY '00:00:00';
PRINT '';
PRINT '-> 3. Verificando el estado final del sistema tras la liquidación (Subasta 1):';
PRINT '    - David (Ganador) debe ser el nuevo dueño del NFT "Amanecer en Atitlán".';
PRINT '    - El balance de David debe haber disminuido en 4.25 ETH (7.5 - 4.25 = 3.25).';
PRINT '    - La reserva de David (4.25) debe estar "CAPTURED".';
PRINT '    - El balance de la Artista (Valentina) debe haber aumentado.';
PRINT '    - La Subasta 2 ("Luna de Neón") sigue activa y la reserva de Brenda (3.0) sigue "ACTIVE".';

PRINT '-> Propietario final del NFT 1:';
SELECT NFTId, Name, CurrentOwnerId, U.FullName AS OwnerName FROM nft.NFT N JOIN core.[User] U ON U.UserId = N.CurrentOwnerId WHERE N.NFTId = @NewNFTId1;

PRINT '-> Wallets finales (Artista y Postores):';
SELECT U.FullName, W.BalanceETH, W.ReservedETH FROM core.Wallet W JOIN core.[User] U ON U.UserId = W.UserId WHERE W.UserId IN (@ArtistId, @Bidder1Id, @Bidder2Id);

PRINT '-> Estado final de las reservas de fondos (Ambas subastas):';
SELECT R.AuctionId, U.FullName, R.AmountETH, R.StateCode
FROM finance.FundsReservation R
JOIN core.[User] U ON U.UserId = R.UserId
WHERE R.AuctionId IN (@AuctionId1, @AuctionId2)
ORDER BY R.AuctionId, R.ReservationId;

PRINT '-> Libro Contable (Ledger) para la Subasta 1:';
SELECT EntryId, UserId, EntryType, AmountETH, [Description] FROM finance.Ledger WHERE AuctionId = @AuctionId1;

PRINT '-> Estado de la Subasta 2 (Debe seguir activa):';
SELECT AuctionId, N.Name, A.StatusCode, U.FullName AS CurrentLeader
FROM auction.Auction A
JOIN nft.NFT N ON A.NFTId = N.NFTId
LEFT JOIN core.[User] U ON U.UserId = A.CurrentLeaderId
WHERE A.AuctionId = @AuctionId2;
GO

PRINT '';
PRINT '============================================================';
PRINT '===           DEMOSTRACIÓN AVANZADA FINALIZADA           ===';
PRINT '============================================================';
GO