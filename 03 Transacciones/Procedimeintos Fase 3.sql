-- =====================================================================================
-- PROCEDIMIENTOS
-- Descripción: 
-- =====================================================================================

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- PROCEDIMIENTO ALMACENADO: auction.sp_PlaceBid
-- Descripción: Punto de entrada para que un usuario realice una oferta en una subasta.
-- =====================================================================================
CREATE OR ALTER PROCEDURE auction.sp_PlaceBid
(
    @AuctionId BIGINT,
    @BidderId BIGINT,
    @AmountETH DECIMAL(38,18)
)
AS
BEGIN
    -- Optimiza el rendimiento evitando el retorno de mensajes "rows affected".
    SET NOCOUNT ON;

    BEGIN TRY
        -- Intenta insertar la oferta. La lógica real está en el trigger
        -- INSTEAD OF INSERT en la tabla auction.Bid.
        -- Si el trigger encuentra un error, lanzará una excepción que será
        -- capturada por el bloque CATCH.
        INSERT INTO auction.Bid (AuctionId, BidderId, AmountETH)
        VALUES (@AuctionId, @BidderId, @AmountETH);

        PRINT 'Oferta enviada exitosamente para procesamiento.';
    END TRY
    BEGIN CATCH
        -- Si el trigger (o el INSERT) falla, relanza el error para que 
        -- la aplicación que llamó a este SP pueda manejarlo.
        PRINT 'Ocurrió un error al procesar la oferta.';
        THROW;
    END CATCH
END;
GO

PRINT 'Funciones y Procedimiento Almacenado para la Fase 3 creados exitosamente.';