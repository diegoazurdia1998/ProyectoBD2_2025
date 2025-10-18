-- =====================================================================================
-- 🧪 PRUEBAS FASE 3 - Sistema de Ofertas (auction.sp_PlaceBid)
-- Debe ejecutarse DESPUÉS del DDL v7.
-- =====================================================================================

-- =============================================
-- 🧪 SETUP: Usuarios, billeteras, NFT y subasta
-- =============================================

-- Crear usuarios
INSERT INTO core.[User] (FullName) VALUES 
('Artista NFT'),
('Postor A'),
('Postor B'),
('Postor C');

-- Crear billeteras con saldo inicial
INSERT INTO core.Wallet (UserId, BalanceETH) VALUES
(1, 1.000000000000000000),  -- Artista
(2, 2.000000000000000000),  -- Postor A
(3, 1.500000000000000000),  -- Postor B
(4, 0.200000000000000000);  -- Postor C (saldo pequeño para pruebas de error)

-- Crear un NFT aprobado para subasta
INSERT INTO nft.NFT (
    ArtistId, SettingsID, [Name], ContentType, HashCode, StatusCode, CreatedAtUtc
) VALUES (
    1, 1, 'Obra Fase 3', 'image/png', 'HASH12345', 'APPROVED', SYSUTCDATETIME()
);

-- Crear subasta activa para ese NFT
INSERT INTO auction.Auction (
    SettingsID, NFTId, StartAtUtc, EndAtUtc, StartingPriceETH, CurrentPriceETH, StatusCode
) VALUES (
    1, 1, SYSUTCDATETIME(), DATEADD(HOUR, 72, SYSUTCDATETIME()), 0.100000000000000000, 0.100000000000000000, 'ACTIVE'
);

-- =====================================================================================
-- ✅ CASO 1 – Oferta válida inicial
-- =====================================================================================
PRINT '✅ CASO 1 - Oferta válida inicial';
EXEC auction.sp_PlaceBid
    @AuctionId = 1,
    @BidderId = 2,      -- Postor A
    @AmountETH = 0.110; -- Oferta inicial válida

-- =====================================================================================
-- ✅ CASO 2 – Oferta superior válida de otro usuario
-- =====================================================================================
PRINT '✅ CASO 2 - Oferta superior válida de otro usuario';
EXEC auction.sp_PlaceBid
    @AuctionId = 1,
    @BidderId = 3,      -- Postor B
    @AmountETH = 0.120; -- Oferta mayor válida

-- =====================================================================================
-- ❌ CASO 3 – Oferta menor al incremento mínimo
-- =====================================================================================
PRINT '❌ CASO 3 - Oferta menor al incremento mínimo (debe fallar)';
BEGIN TRY
    EXEC auction.sp_PlaceBid
        @AuctionId = 1,
        @BidderId = 2,      
        @AmountETH = 0.121; -- Muy baja, no supera el 5%
END TRY
BEGIN CATCH
    PRINT '⚠️ Error esperado: ' + ERROR_MESSAGE();
END CATCH

-- =====================================================================================
-- ❌ CASO 4 – Oferta con saldo insuficiente
-- =====================================================================================
PRINT '❌ CASO 4 - Oferta con saldo insuficiente (debe fallar)';
BEGIN TRY
    EXEC auction.sp_PlaceBid
        @AuctionId = 1,
        @BidderId = 4,      
        @AmountETH = 0.300; -- Postor C no tiene saldo suficiente
END TRY
BEGIN CATCH
    PRINT '⚠️ Error esperado: ' + ERROR_MESSAGE();
END CATCH

-- =====================================================================================
-- ✅ CASO 5 – Líder actual mejora su propia oferta
-- =====================================================================================
PRINT '✅ CASO 5 - Líder actual mejora su propia oferta';
EXEC auction.sp_PlaceBid
    @AuctionId = 1,
    @BidderId = 3,      -- Postor B (líder actual)
    @AmountETH = 0.140; -- Sube su propia oferta

-- =====================================================================================
-- ❌ CASO 6 – Empate (oferta igual al precio actual)
-- =====================================================================================
PRINT '❌ CASO 6 - Oferta igual al precio actual (debe fallar)';
BEGIN TRY
    EXEC auction.sp_PlaceBid
        @AuctionId = 1,
        @BidderId = 2,      
        @AmountETH = 0.140; -- Igual al precio actual, no válida
END TRY
BEGIN CATCH
    PRINT '⚠️ Error esperado: ' + ERROR_MESSAGE();
END CATCH

-- =====================================================================================
-- ✅ CASO 7 – Oferta muy grande (stress test)
-- =====================================================================================
PRINT '✅ CASO 7 - Oferta grande (stress test)';
EXEC auction.sp_PlaceBid
    @AuctionId = 1,
    @BidderId = 2,      
    @AmountETH = 1.000000000000000000; -- Oferta alta válida

-- =====================================================================================
-- 🔎 CONSULTAS DE VERIFICACIÓN (Resultados finales)
-- =====================================================================================

PRINT '🔍 Historial de Ofertas:';
SELECT * FROM auction.Bid ORDER BY PlacedAtUtc;

PRINT '🔍 Estado final de la Subasta:';
SELECT * FROM auction.Auction WHERE AuctionId = 1;

PRINT '🔍 Reservas de Fondos:';
SELECT * FROM finance.FundsReservation WHERE AuctionId = 1;

PRINT '🔍 Estado de las Billeteras:';
SELECT UserId, BalanceETH, ReservedETH FROM core.Wallet;

PRINT '🔍 Correos enviados:';
SELECT * FROM audit.EmailOutbox ORDER BY CreatedAtUtc DESC;
