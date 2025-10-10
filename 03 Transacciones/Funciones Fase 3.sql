-- =====================================================================================
-- FUNCIONES
-- Descripci�n: 
-- =====================================================================================

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- FUNCI�N: finance.fn_GetAvailableBalance
-- Descripci�n: Calcula el saldo disponible de un usuario (Balance - Reservado).
-- =====================================================================================
CREATE OR ALTER FUNCTION finance.fn_GetAvailableBalance
(
    @UserId BIGINT
)
RETURNS DECIMAL(38,18)
AS
BEGIN
    DECLARE @AvailableBalance DECIMAL(38,18);

    -- Selecciona el balance disponible de la billetera del usuario.
    -- ISNULL se usa para manejar el caso de que el usuario no tenga billetera.
    SELECT 
        @AvailableBalance = ISNULL(BalanceETH - ReservedETH, 0)
    FROM 
        core.Wallet
    WHERE 
        UserId = @UserId;

    -- Si la consulta no devuelve filas (usuario sin wallet), asegura devolver 0.
    RETURN ISNULL(@AvailableBalance, 0);
END;
GO

-- =====================================================================================
-- FUNCI�N: auction.fn_GetMinNextBid
-- Descripci�n: Calcula el monto m�nimo para la siguiente oferta v�lida en una subasta.
-- =====================================================================================
CREATE OR ALTER FUNCTION auction.fn_GetMinNextBid
(
    @AuctionId BIGINT
)
RETURNS DECIMAL(38,18)
AS
BEGIN
    DECLARE @CurrentPriceETH DECIMAL(38,18);
    DECLARE @MinBidIncrementPct TINYINT;
    DECLARE @MinNextBid DECIMAL(38,18);

    -- Obtener el precio actual de la subasta.
    SELECT @CurrentPriceETH = CurrentPriceETH
    FROM auction.Auction
    WHERE AuctionId = @AuctionId;

    -- Si la subasta no existe, no se puede calcular; devuelve NULL.
    IF @CurrentPriceETH IS NULL
        RETURN NULL;

    -- Obtener el porcentaje de incremento m�nimo de la configuraci�n global.
    -- Se asume una �nica fila de configuraci�n.
    SELECT TOP 1 @MinBidIncrementPct = MinBidIncrementPct
    FROM auction.AuctionSettings
    ORDER BY SettingsID;

    -- Si no hay configuraci�n, se usa un valor por defecto (e.g., 5%) para evitar errores.
    SET @MinBidIncrementPct = ISNULL(@MinBidIncrementPct, 5);
    
    -- Calcular la oferta m�nima. Se divide por 100.0 para asegurar c�lculo decimal.
    SET @MinNextBid = @CurrentPriceETH + (@CurrentPriceETH * (@MinBidIncrementPct / 100.0));

    RETURN @MinNextBid;
END;
GO