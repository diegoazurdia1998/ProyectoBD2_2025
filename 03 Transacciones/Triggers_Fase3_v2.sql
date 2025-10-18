use ArteCryptoAuctions
go

-- =====================================================================================
-- TRIGGER 4: Validar y procesar ofertas (Bids) - VERSIÓN REFACTORIZADA
-- Descripción: Usa funciones para validación e implementa la reserva de fondos.
-- =====================================================================================
CREATE OR ALTER TRIGGER auction.tr_Bid_Validation
ON auction.Bid
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Usamos un nivel de aislamiento alto para prevenir condiciones de carrera
    -- durante la validación y actualización del precio de la subasta.
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    BEGIN TRY
        DECLARE @ErrorMsg NVARCHAR(MAX);

        -- -------------------------------------------------------------------
        -- 1) Capturar y validar las ofertas entrantes en un solo paso
        -- -------------------------------------------------------------------
        DECLARE @InputBids TABLE(
            RowNum INT IDENTITY(1,1) PRIMARY KEY,
            AuctionId BIGINT,
            BidderId BIGINT,
            ArtistId BIGINT,
            AmountETH DECIMAL(38,18),
            PlacedAtUtc DATETIME2(3),
            CurrentPriceETH DECIMAL(38,18),
            MinNextBid DECIMAL(38,18),
            AvailableBalance DECIMAL(38,18),
            OldLeaderId BIGINT,
            AuctionStatusCode VARCHAR(30),
            AuctionEndAtUtc DATETIME2(3),
            ErrorMessage NVARCHAR(500)
        );

        -- Se recopilan todos los datos necesarios para la validación de una sola vez
        INSERT INTO @InputBids(
            AuctionId, BidderId, AmountETH, PlacedAtUtc,
            ArtistId, CurrentPriceETH, AuctionStatusCode, AuctionEndAtUtc,
            MinNextBid, AvailableBalance
        )
        SELECT 
            i.AuctionId, i.BidderId, i.AmountETH, i.PlacedAtUtc,
            nft.ArtistId,
            a.CurrentPriceETH,
            a.StatusCode,
            a.EndAtUtc, -- Uso de las nuevas funciones para validación
            auction.fn_GetMinNextBid(i.AuctionId),
            finance.fn_GetAvailableBalance(i.BidderId)
        FROM inserted i
        LEFT JOIN auction.Auction a ON a.AuctionId = i.AuctionId
        LEFT JOIN nft.NFT nft ON nft.NFTId = a.NFTId;

        -- Se generan los mensajes de error basados en los datos recolectados
        UPDATE @InputBids
        SET ErrorMessage = 
            CASE
                WHEN AuctionStatusCode IS NULL THEN N'La subasta no existe.'
                WHEN AuctionStatusCode <> 'ACTIVE' THEN N'La subasta no está activa.'
                WHEN AuctionEndAtUtc < SYSUTCDATETIME() THEN N'La subasta ya ha finalizado.'
                WHEN ArtistId = BidderId THEN N'El artista no puede ofertar en su propia obra.'
                WHEN AmountETH < MinNextBid THEN N'Su oferta es muy baja. Se requiere al menos ' + CAST(MinNextBid AS NVARCHAR(50)) + N' ETH.'
                WHEN AvailableBalance < AmountETH THEN N'Saldo insuficiente. Su saldo disponible es de ' + CAST(AvailableBalance AS NVARCHAR(50)) + N' ETH.'
                ELSE NULL
            END;

        -- -------------------------------------------------------------------
        -- 2) Si hay errores, notificar y detener el proceso
        -- -------------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM @InputBids WHERE ErrorMessage IS NOT NULL)
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body])
            SELECT
                ib.BidderId,
                ue.Email,
                N'Oferta Rechazada',
                N'Su oferta en la subasta #' + CAST(ib.AuctionId AS NVARCHAR(20)) + N' no pudo ser procesada. Razón: ' + ib.ErrorMessage
            FROM @InputBids ib
            JOIN core.UserEmail ue ON ue.UserId = ib.BidderId AND ue.IsPrimary = 1
            WHERE ib.ErrorMessage IS NOT NULL;
            
            RETURN; -- Detiene la ejecución del trigger
        END;

        -- -------------------------------------------------------------------
        -- 3) Procesar las ofertas válidas una por una para manejar la lógica de fondos
        -- -------------------------------------------------------------------
        DECLARE @CurrentRow INT = 1;
        DECLARE @TotalRows INT = (SELECT COUNT(*) FROM @InputBids);
        DECLARE @AuctionId BIGINT, @BidderId BIGINT, @AmountETH DECIMAL(38,18), @OldLeaderId BIGINT;

        WHILE @CurrentRow <= @TotalRows
        BEGIN
            -- Obtener la oferta actual a procesar
            SELECT 
                @AuctionId = AuctionId,
                @BidderId = BidderId,
                @AmountETH = AmountETH
            FROM @InputBids WHERE RowNum = @CurrentRow;

            BEGIN TRANSACTION; -- Inicia una transacción para asegurar la atomicidad

            -- Obtener el líder anterior DENTRO de la transacción para bloquear la fila
            SELECT @OldLeaderId = CurrentLeaderId 
            FROM auction.Auction WITH (UPDLOCK) 
            WHERE AuctionId = @AuctionId;
            
            -- A) LIBERAR FONDOS DEL LÍDER ANTERIOR (si existe y es diferente del nuevo postor)
            IF @OldLeaderId IS NOT NULL AND @OldLeaderId <> @BidderId
            BEGIN
                DECLARE @OldBidAmount DECIMAL(38,18);

                -- Obtener el monto de la reserva anterior que estaba activa
                SELECT @OldBidAmount = AmountETH 
                FROM finance.FundsReservation 
                WHERE AuctionId = @AuctionId AND UserId = @OldLeaderId AND StateCode = 'ACTIVE';
                
                IF @OldBidAmount IS NOT NULL
                BEGIN
                    -- Actualizar billetera del líder anterior
                    UPDATE core.Wallet SET ReservedETH = ReservedETH - @OldBidAmount WHERE UserId = @OldLeaderId;
                    -- Marcar la reserva como liberada
                    UPDATE finance.FundsReservation SET StateCode = 'RELEASED', UpdatedAtUtc = SYSUTCDATETIME() WHERE AuctionId = @AuctionId AND UserId = @OldLeaderId AND StateCode = 'ACTIVE';
                END
            END

            -- B) RESERVAR FONDOS DEL NUEVO LÍDER
            UPDATE core.Wallet SET ReservedETH = ReservedETH + @AmountETH WHERE UserId = @BidderId;

            -- C) INSERTAR EL REGISTRO DE LA OFERTA
            DECLARE @NewBidId BIGINT;
            INSERT INTO auction.Bid(AuctionId, BidderId, AmountETH)
            VALUES (@AuctionId, @BidderId, @AmountETH);
            SET @NewBidId = SCOPE_IDENTITY(); -- Capturar el ID de la nueva oferta

            -- D) CREAR LA NUEVA RESERVA DE FONDOS
            INSERT INTO finance.FundsReservation(UserId, AuctionId, BidId, AmountETH, StateCode)
            VALUES(@BidderId, @AuctionId, @NewBidId, @AmountETH, 'ACTIVE');

            -- E) ACTUALIZAR LA SUBASTA con el nuevo precio y líder
            UPDATE auction.Auction 
            SET CurrentPriceETH = @AmountETH, CurrentLeaderId = @BidderId 
            WHERE AuctionId = @AuctionId;

            COMMIT TRANSACTION; -- Confirmar todos los cambios si no hubo errores


            SET @CurrentRow = @CurrentRow + 1;
        END;
		
        -- F) GESTIONAR NOTIFICACIONES (fuera de la transacción principal)
        -- -------------------------------------------------------------------
        -- 4) Enviar todas las notificaciones después de procesar
        -- -------------------------------------------------------------------
        -- Notificar al nuevo líder
        INSERT INTO audit.EmailOutbox(RecipientUserId, [Subject], [Body])
        SELECT DISTINCT BidderId, N'¡Oferta Aceptada!', N'Su oferta de ' + CAST(AmountETH AS NVARCHAR(50)) + N' ETH ha sido aceptada. Ahora es el líder de la subasta #' + CAST(AuctionId AS NVARCHAR(20)) + N'.' FROM @InputBids;

        -- Notificar al líder anterior (si existió)
        INSERT INTO audit.EmailOutbox(RecipientUserId, [Subject], [Body])
        SELECT DISTINCT OldLeaderId, N'Ha sido superado en la subasta', N'Su oferta en la subasta #' + CAST(AuctionId AS NVARCHAR(20)) + N' ha sido superada. La nueva oferta es de ' + CAST(AmountETH AS NVARCHAR(50)) + N' ETH.' FROM @InputBids WHERE OldLeaderId IS NOT NULL AND OldLeaderId <> BidderId;

        -- Notificar al artista
        INSERT INTO audit.EmailOutbox(RecipientUserId, [Subject], [Body])
        SELECT DISTINCT ArtistId, N'Nueva oferta en su NFT', N'Su NFT ha recibido una nueva oferta de ' + CAST(AmountETH AS NVARCHAR(50)) + N' ETH en la subasta #' + CAST(AuctionId AS NVARCHAR(20)) + N'.' FROM @InputBids;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION; -- Revertir la transacción si algo falla

        SET @ErrorMsg = N'Error en tr_Bid_Validation: ' + ERROR_MESSAGE();
        
        -- Notificar al administrador del sistema sobre el error
        INSERT INTO audit.EmailOutbox(RecipientEmail, [Subject], [Body])
        VALUES('admin@artecryptoauctions.com', N'Error Crítico en Sistema - Procesamiento de Oferta', @ErrorMsg);
            
        THROW; -- Relanzar el error para que la aplicación lo reciba
    END CATCH
END;
GO


-- =====================================================================================
-- TRIGGER 5: Finalización de subastas
-- =====================================================================================

USE ArteCryptoAuctions;
GO

CREATE OR ALTER TRIGGER auction.tr_Auction_ProcesarCompletada
ON auction.Auction
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo actuar si la columna StatusCode fue actualizada y hay subastas completadas
    IF NOT UPDATE(StatusCode) OR NOT EXISTS (SELECT 1 FROM inserted WHERE StatusCode = 'COMPLETED')
        RETURN;

    BEGIN TRY
        -- Iniciar una transacción atómica para todo el lote
        BEGIN TRANSACTION;

        -- -------------------------------------------------------------------
        -- 1. Recopilar datos de todas las subastas recién completadas
        -- -------------------------------------------------------------------
        DECLARE @CompletedAuctions TABLE(
            AuctionId BIGINT PRIMARY KEY,
            NFTId BIGINT NOT NULL,
            ArtistId BIGINT NOT NULL,
            WinnerId BIGINT NULL, -- Puede no haber un ganador
            FinalPriceETH DECIMAL(38,18) NOT NULL
        );

        INSERT INTO @CompletedAuctions (AuctionId, NFTId, ArtistId, WinnerId, FinalPriceETH)
        SELECT 
            i.AuctionId, 
            i.NFTId,
            n.ArtistId,
            i.CurrentLeaderId,
            i.CurrentPriceETH
        FROM inserted i
        JOIN deleted d ON i.AuctionId = d.AuctionId
        JOIN nft.NFT n ON i.NFTId = n.NFTId
        WHERE i.StatusCode = 'COMPLETED' AND d.StatusCode <> 'COMPLETED';

        -- Si no hay subastas que realmente hayan cambiado a 'COMPLETED', salir.
        IF NOT EXISTS (SELECT 1 FROM @CompletedAuctions)
            RETURN;

        -- -------------------------------------------------------------------
        -- 2. Procesar a los GANADORES
        -- -------------------------------------------------------------------
        -- A) Actualizar wallets: Bajar balance y reserva
        UPDATE w
        SET 
            BalanceETH = w.BalanceETH - ca.FinalPriceETH,
            ReservedETH = w.ReservedETH - ca.FinalPriceETH, -- Asumimos que la reserva es el precio final
            UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN @CompletedAuctions ca ON w.UserId = ca.WinnerId
        WHERE ca.WinnerId IS NOT NULL;

        -- B) Transferir propiedad del NFT
        UPDATE n
        SET CurrentOwnerId = ca.WinnerId
        FROM nft.NFT n
        JOIN @CompletedAuctions ca ON n.NFTId = ca.NFTId
        WHERE ca.WinnerId IS NOT NULL;

        -- C) Marcar la reserva de fondos como CAPTURADA
        UPDATE fr
        SET StateCode = 'CAPTURED', UpdatedAtUtc = SYSUTCDATETIME()
        FROM finance.FundsReservation fr
        JOIN @CompletedAuctions ca ON fr.AuctionId = ca.AuctionId AND fr.UserId = ca.WinnerId
        WHERE ca.WinnerId IS NOT NULL AND fr.StateCode = 'ACTIVE';

        -- D) Insertar registro de DÉBITO en el libro contable
        INSERT INTO finance.Ledger (UserId, AuctionId, EntryType, AmountETH, [Description])
        SELECT 
            WinnerId, 
            AuctionId, 
            'DEBIT', 
            FinalPriceETH, 
            'Pago por subasta ganada #' + CAST(AuctionId AS NVARCHAR(20))
        FROM @CompletedAuctions
        WHERE WinnerId IS NOT NULL;

        -- -------------------------------------------------------------------
        -- 3. Procesar a los PERDEDORES y subastas SIN GANADOR
        -- -------------------------------------------------------------------
        -- Identificar todas las reservas que deben ser liberadas
        DECLARE @ReservationsToRelease TABLE (ReservationId BIGINT, UserId BIGINT, AuctionId BIGINT, AmountETH DECIMAL(38,18));

        INSERT INTO @ReservationsToRelease (ReservationId, UserId, AuctionId, AmountETH)
        SELECT fr.ReservationId, fr.UserId, fr.AuctionId, fr.AmountETH
        FROM finance.FundsReservation fr
        -- Unirse a las subastas completadas
        JOIN @CompletedAuctions ca ON fr.AuctionId = ca.AuctionId
        -- El usuario de la reserva NO es el ganador de esa subasta
        WHERE fr.StateCode = 'ACTIVE' 
          AND (ca.WinnerId IS NULL OR fr.UserId <> ca.WinnerId);
        
        -- A) Marcar las reservas como LIBERADAS
        UPDATE fr
        SET StateCode = 'RELEASED', UpdatedAtUtc = SYSUTCDATETIME()
        FROM finance.FundsReservation fr
        JOIN @ReservationsToRelease rtr ON fr.ReservationId = rtr.ReservationId;

        -- B) Devolver los fondos reservados a las wallets correspondientes
        UPDATE w
        SET 
            ReservedETH = w.ReservedETH - r.TotalReleased,
            UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN (
            -- Agrupar por si un usuario perdió en múltiples subastas en el mismo lote
            SELECT UserId, SUM(AmountETH) as TotalReleased
            FROM @ReservationsToRelease
            GROUP BY UserId
        ) AS r ON w.UserId = r.UserId;

        -- -------------------------------------------------------------------
        -- 4. Enviar todas las NOTIFICACIONES
        -- -------------------------------------------------------------------
        -- A) Notificar a los ganadores
        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT 
            WinnerId,
            '¡Felicidades! Ganaste la subasta #' + CAST(AuctionId AS NVARCHAR(20)),
            'Has ganado la subasta con una oferta de ' + CAST(FinalPriceETH AS NVARCHAR(50)) + 
            ' ETH. El NFT ha sido transferido a tu cuenta.'
        FROM @CompletedAuctions
        WHERE WinnerId IS NOT NULL;
        
        -- B) Notificar a los artistas
        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT 
            ArtistId,
            '¡Subasta completada! #' + CAST(AuctionId AS NVARCHAR(20)),
            CASE 
                WHEN WinnerId IS NOT NULL THEN 'Tu NFT ha sido vendido por ' + CAST(FinalPriceETH AS NVARCHAR(50)) + ' ETH.'
                ELSE 'Tu subasta ha finalizado sin un ganador.'
            END
        FROM @CompletedAuctions;

        -- C) Notificar a los perdedores y participantes de subastas sin ganador
        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT 
            UserId,
            'Subasta finalizada #' + CAST(AuctionId AS NVARCHAR(20)),
            'La subasta ha finalizado. Tus fondos reservados (' + 
            CAST(AmountETH AS NVARCHAR(50)) + ' ETH) han sido liberados.'
        FROM @ReservationsToRelease;
        
        -- Si todo fue exitoso, confirmar la transacción
        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        -- Si algo falla, revertir todos los cambios del lote
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Loguear el error para el administrador
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO audit.EmailOutbox (RecipientEmail, [Subject], [Body])
        VALUES ('admin@artecryptoauctions.com', 'ERROR Crítico - Procesamiento de Subastas Completadas', @ErrorMessage);
        
        -- Relanzar el error para que la capa de aplicación sea notificada
        THROW;
    END CATCH;
END;
GO