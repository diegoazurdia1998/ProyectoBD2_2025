USE [ArteCryptoAuctions]
GO

CREATE OR ALTER TRIGGER [auction].[TR_Auction_ProcesarCompletada]
ON [auction].[Auction]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(StatusCode)
    BEGIN
        IF EXISTS (SELECT 1 FROM inserted WHERE StatusCode = 'COMPLETED')
        BEGIN
            PRINT '=== INICIANDO PROCESAMIENTO DE SUBASTAS COMPLETADAS ===';
            
            DECLARE @TotalAuctions INT;
            SELECT @TotalAuctions = COUNT(*) FROM inserted WHERE StatusCode = 'COMPLETED';
            PRINT 'Subastas a procesar: ' + CAST(@TotalAuctions AS NVARCHAR(10));
            
            DECLARE @CompletedAuctions TABLE(
                AuctionId BIGINT PRIMARY KEY,
                CurrentLeaderId BIGINT,
                CurrentPriceETH DECIMAL(38,18),
                NFTId BIGINT,
                ArtistId BIGINT,
                ProcessingOrder INT IDENTITY(1,1)
            );
            
            INSERT INTO @CompletedAuctions (AuctionId, CurrentLeaderId, CurrentPriceETH, NFTId, ArtistId)
            SELECT 
                i.AuctionId, 
                i.CurrentLeaderId, 
                i.CurrentPriceETH,
                i.NFTId,
                n.ArtistId
            FROM inserted i
            INNER JOIN nft.NFT n ON i.NFTId = n.NFTId
            WHERE i.StatusCode = 'COMPLETED';
            
            DECLARE @AuctionId BIGINT, 
                    @UserId BIGINT, 
                    @BidAmountETH DECIMAL(38,18),
                    @NFTId BIGINT, 
                    @ArtistId BIGINT,
                    @ProcessingOrder INT;
            
            DECLARE @ErrorMessage NVARCHAR(4000),
                    @ErrorSeverity INT,
                    @ErrorState INT;
            
            DECLARE auction_cursor CURSOR LOCAL FORWARD_ONLY READ_ONLY
            FOR 
            SELECT AuctionId, CurrentLeaderId, CurrentPriceETH, NFTId, ArtistId, ProcessingOrder
            FROM @CompletedAuctions
            ORDER BY ProcessingOrder;
            
            OPEN auction_cursor;
            FETCH NEXT FROM auction_cursor INTO @AuctionId, @UserId, @BidAmountETH, @NFTId, @ArtistId, @ProcessingOrder;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                PRINT '--- Procesando subasta #' + CAST(@AuctionId AS NVARCHAR(20)) + ' (Orden: ' + CAST(@ProcessingOrder AS NVARCHAR(5)) + ') ---';
                
                BEGIN TRY
                    BEGIN TRANSACTION;
                    
                    IF NOT EXISTS (SELECT 1 FROM auction.Auction WHERE AuctionId = @AuctionId AND StatusCode = 'COMPLETED')
                    BEGIN
                        PRINT '   ⚠ Subasta ya no está COMPLETED, saltando...';
                        ROLLBACK TRANSACTION;
                        GOTO NextAuction;
                    END;
                    
                    IF @UserId IS NULL
                    BEGIN
                        PRINT '   ⚠ Subasta sin ganador, solo liberando fondos...';
                        
                        UPDATE finance.FundsReservation
                        SET StateCode = 'RELEASED',
                            UpdatedAtUtc = GETDATE()
                        WHERE AuctionId = @AuctionId
                        AND StateCode = 'ACTIVE';
                        
                        UPDATE w
                        SET ReservedETH = ReservedETH - fr.AmountETH,
                            UpdatedAtUtc = GETDATE()
                        FROM core.Wallet w
                        INNER JOIN finance.FundsReservation fr ON w.UserId = fr.UserId
                        WHERE fr.AuctionId = @AuctionId
                        AND fr.StateCode = 'RELEASED';
                        
                        PRINT '   ✅ Fondos liberados para subasta sin ganador';
                        COMMIT TRANSACTION;
                        GOTO NextAuction;
                    END;
                    
                    PRINT '   1. Procesando GANADOR (Usuario ' + CAST(@UserId AS NVARCHAR(10)) + ')';
                    
                    DECLARE @ReservationAmountETH DECIMAL(38,18);
                    
                    SELECT @ReservationAmountETH = AmountETH
                    FROM finance.FundsReservation WITH (UPDLOCK)
                    WHERE UserId = @UserId 
                    AND AuctionId = @AuctionId
                    AND StateCode = 'ACTIVE';
                    
                    IF @ReservationAmountETH IS NOT NULL
                    BEGIN
                        UPDATE core.Wallet
                        SET 
                            BalanceETH = BalanceETH - @BidAmountETH,
                            ReservedETH = ReservedETH - @ReservationAmountETH,
                            UpdatedAtUtc = GETDATE()
                        WHERE UserId = @UserId;
                        
                        INSERT INTO finance.Ledger (UserId, AuctionId, EntryType, AmountETH, [Description], CreatedAtUtc)
                        VALUES (@UserId, @AuctionId, 'DEBIT', @BidAmountETH, 
                               'Pago por subasta ganada #' + CAST(@AuctionId AS NVARCHAR(20)),
                               GETDATE());
                        
                        UPDATE finance.FundsReservation
                        SET StateCode = 'CAPTURED',
                            UpdatedAtUtc = GETDATE()
                        WHERE UserId = @UserId 
                        AND AuctionId = @AuctionId
                        AND StateCode = 'ACTIVE';
                        
                        UPDATE nft.NFT
                        SET CurrentOwnerId = @UserId
                        WHERE NFTId = @NFTId;
                        
                        PRINT '   ✅ Ganador procesado: -' + CAST(@BidAmountETH AS NVARCHAR(50)) + ' ETH, NFT transferido';
                    END
                    ELSE
                    BEGIN
                        PRINT '   ❌ No se encontró reserva activa para el ganador';
                        THROW 51000, 'Reserva de fondos no encontrada para el ganador', 1;
                    END;
                    
                    PRINT '   2. Liberando PERDEDORES...';
                    
                    DECLARE @PerdedoresCount INT;
                    
                    UPDATE finance.FundsReservation
                        SET StateCode = 'RELEASED',
                            UpdatedAtUtc = GETDATE()
                        WHERE AuctionId = @AuctionId
                        AND UserId != @UserId
                        AND StateCode = 'ACTIVE';
                    
                    SET @PerdedoresCount = @@ROWCOUNT;
                    
                    IF @PerdedoresCount > 0
                    BEGIN
                        UPDATE w
                        SET ReservedETH = ReservedETH - fr.AmountETH,
                            UpdatedAtUtc = GETDATE()
                        FROM core.Wallet w
                        INNER JOIN finance.FundsReservation fr ON w.UserId = fr.UserId
                        WHERE fr.AuctionId = @AuctionId
                        AND fr.UserId != @UserId
                        AND fr.StateCode = 'RELEASED';
                        
                        PRINT '   ✅ Perdedores liberados: ' + CAST(@PerdedoresCount AS NVARCHAR(10)) + ' usuarios';
                    END
                    ELSE
                    BEGIN
                        PRINT '   ℹ No hay perdedores que liberar';
                    END;
                    
                    PRINT '   3. Programando notificaciones...';
                    
                    INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body], StatusCode, CreatedAtUtc)
                    VALUES (
                        @UserId, 
                        '¡Felicidades! Ganaste la subasta #' + CAST(@AuctionId AS NVARCHAR(20)),
                        'Has ganado la subasta con una oferta de ' + CAST(@BidAmountETH AS NVARCHAR(50)) + 
                        ' ETH. El NFT ha sido transferido a tu cuenta.',
                        'PENDING',
                        GETDATE()
                    );
                    
                    INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body], StatusCode, CreatedAtUtc)
                    VALUES (
                        @ArtistId,
                        '¡Subasta completada! #' + CAST(@AuctionId AS NVARCHAR(20)),
                        'Tu NFT ha sido vendido por ' + CAST(@BidAmountETH AS NVARCHAR(50)) + 
                        ' ETH en la subasta #' + CAST(@AuctionId AS NVARCHAR(20)) + '.',
                        'PENDING',
                        GETDATE()
                    );
                    
                    IF @PerdedoresCount > 0
                    BEGIN
                        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body], StatusCode, CreatedAtUtc)
                        SELECT 
                            fr.UserId,
                            'Subasta finalizada #' + CAST(@AuctionId AS NVARCHAR(20)),
                            'La subasta ha finalizado. Tus fondos reservados (' + 
                            CAST(fr.AmountETH AS NVARCHAR(50)) + ' ETH) han sido liberados.',
                            'PENDING',
                            GETDATE()
                        FROM finance.FundsReservation fr
                        WHERE fr.AuctionId = @AuctionId
                        AND fr.UserId != @UserId
                        AND fr.StateCode = 'RELEASED';
                    END;
                    
                    COMMIT TRANSACTION;
                    PRINT '   ✅ Subasta #' + CAST(@AuctionId AS NVARCHAR(20)) + ' procesada EXITOSAMENTE';
                    
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0
                        ROLLBACK TRANSACTION;
                    
                    SET @ErrorMessage = 'Error procesando subasta #' + CAST(@AuctionId AS NVARCHAR(20)) + 
                                       ': ' + ERROR_MESSAGE();
                    SET @ErrorSeverity = ERROR_SEVERITY();
                    SET @ErrorState = ERROR_STATE();
                    
                    INSERT INTO audit.EmailOutbox (RecipientEmail, [Subject], [Body], StatusCode, CreatedAtUtc)
                    VALUES (
                        'admin@artecryptoauctions.com',
                        'ERROR - Procesamiento Subasta #' + CAST(@AuctionId AS NVARCHAR(20)),
                        @ErrorMessage + CHAR(13) + CHAR(10) +
                        'Severidad: ' + CAST(@ErrorSeverity AS NVARCHAR(10)) + 
                        ', Estado: ' + CAST(@ErrorState AS NVARCHAR(10)),
                        'PENDING',
                        GETDATE()
                    );
                    
                    PRINT '   ❌ ERROR en subasta #' + CAST(@AuctionId AS NVARCHAR(20)) + ': ' + ERROR_MESSAGE();
                    PRINT '   ⚠ Subasta marcada para reprocesamiento manual';
                    
                END CATCH;
                
                NextAuction:
                FETCH NEXT FROM auction_cursor INTO @AuctionId, @UserId, @BidAmountETH, @NFTId, @ArtistId, @ProcessingOrder;
            END;
            
            CLOSE auction_cursor;
            DEALLOCATE auction_cursor;
            
            PRINT '=== PROCESAMIENTO DE SUBASTAS COMPLETADO ===';
        END
    END
END;
GO