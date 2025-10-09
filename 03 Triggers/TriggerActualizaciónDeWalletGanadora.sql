CREATE OR ALTER TRIGGER auction.TR_Auction_AfterStatusUpdate
ON auction.Auction
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(StatusCode)
    BEGIN
        -- Para subastas COMPLETED
        IF EXISTS (SELECT 1 FROM inserted WHERE StatusCode = 'COMPLETED')
        BEGIN
            PRINT 'Procesando pagos por subastas COMPLETED...';
            
            DECLARE @UserId BIGINT;
            DECLARE @AuctionId BIGINT;
            DECLARE @BidAmountETH DECIMAL(38,18);
            DECLARE @ReservationAmountETH DECIMAL(38,18);
            DECLARE @BidId BIGINT;
            
            -- Obtener datos específicos de la subasta ganadora
            SELECT 
                @UserId = i.CurrentLeaderId,
                @AuctionId = i.AuctionId,
                @BidAmountETH = i.CurrentPriceETH
            FROM inserted i
            WHERE i.StatusCode = 'COMPLETED';
            
            -- Obtener el BidId específico que ganó
            SELECT @BidId = BidId
            FROM auction.Bid
            WHERE AuctionId = @AuctionId 
            AND BidderId = @UserId
            AND AmountETH = @BidAmountETH;
            
            -- Obtener el monto de reserva específico para ESTA puja
            SELECT @ReservationAmountETH = AmountETH
            FROM finance.FundsReservation
            WHERE UserId = @UserId 
            AND AuctionId = @AuctionId
            AND BidId = @BidId
            AND StateCode = 'ACTIVE';
            
            -- Verificar que existe la reserva
            IF @ReservationAmountETH IS NOT NULL
            BEGIN
                -- Actualizar wallet específica
                UPDATE core.Wallet
                SET 
                    BalanceETH = BalanceETH - @BidAmountETH,           -- Descuenta el monto de la puja ganadora
                    ReservedETH = ReservedETH - @ReservationAmountETH, -- Libera SOLO la reserva de ESTA puja
                    UpdatedAtUtc = GETDATE()
                WHERE UserId = @UserId;
                
                -- Registrar en ledger
                INSERT INTO finance.Ledger (UserId, AuctionId, EntryType, AmountETH, [Description])
                VALUES (@UserId, @AuctionId, 'DEBIT', @BidAmountETH, 
                       'Pago por subasta ganada #' + CAST(@AuctionId AS NVARCHAR(20)));
                
                -- Actualizar SOLO la reserva específica
                UPDATE finance.FundsReservation
                SET StateCode = 'CAPTURED',
                    UpdatedAtUtc = GETDATE()
                WHERE UserId = @UserId 
                AND AuctionId = @AuctionId
                AND BidId = @BidId
                AND StateCode = 'ACTIVE';
                
                -- CORRECCIÓN: Convertir explícitamente los decimales a string
                PRINT 'Pago procesado: User=' + CAST(@UserId AS NVARCHAR(10)) + 
                      ', Bid=' + CAST(CAST(@BidAmountETH AS DECIMAL(10,2)) AS NVARCHAR(20)) + ' ETH, ' +
                      'Reserva liberada=' + CAST(CAST(@ReservationAmountETH AS DECIMAL(10,2)) AS NVARCHAR(20)) + ' ETH';
            END
            ELSE
            BEGIN
                PRINT 'ERROR: No se encontró reserva activa para la puja ganadora';
            END
        END
    END
END
GO
