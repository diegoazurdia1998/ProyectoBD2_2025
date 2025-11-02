USE ArteCryptoAuctions;
GO

CREATE OR ALTER PROCEDURE auction.sp_FinalizeEndedAuctions
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AuctionsToFinalize TABLE (AuctionId BIGINT);

    -- 1. Encontrar todas las subastas activas cuya fecha de fin ya pasó
    INSERT INTO @AuctionsToFinalize (AuctionId)
    SELECT AuctionId
    FROM auction.Auction
    WHERE
        StatusCode = 'ACTIVE'
        AND EndAtUtc < SYSUTCDATETIME();

    -- 2. Actualizar el estado a 'COMPLETED'
    -- IMPORTANTE: Esto disparará el trigger 'tr_Auction_ProcesarCompletada'
    -- para cada fila actualizada, procesando automáticamente los pagos.
    UPDATE auction.Auction
    SET StatusCode = 'COMPLETED'
    WHERE AuctionId IN (SELECT AuctionId FROM @AuctionsToFinalize);

    PRINT CONCAT('Se finalizaron ', @@ROWCOUNT, ' subastas.');
END;
GO