
USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- PROCEDIMIENTO ALMACENADO: nft.sp_SubmitNFT
-- Descripción: Punto de entrada para que un usuario ingrese un NFT.
-- =====================================================================================

-- Envío/validación de NFT (igual que v6.1)
CREATE OR ALTER PROCEDURE nft.sp_SubmitNFT
    @ArtistId BIGINT,
    @SettingsID INT,
    @Name NVARCHAR(160),
    @Description NVARCHAR(MAX),
    @ContentType NVARCHAR(100),
    @HashCode CHAR(64),
    @FileSizeBytes BIGINT,
    @WidthPx INT,
    @HeightPx INT,
    @SuggestedPriceETH DECIMAL(38,18) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM nft.NFTSettings WHERE SettingsID=@SettingsID)
        THROW 50000, 'SettingsID inválido.', 1;
    IF NOT EXISTS (SELECT 1 FROM core.[User] WHERE UserId=@ArtistId)
        THROW 50004, 'ArtistId inválido.', 1;

    DECLARE @MaxW BIGINT,@MinW BIGINT,@MaxH BIGINT,@MinH BIGINT,@MaxS BIGINT,@MinS BIGINT;
    SELECT @MaxW=MaxWidthPx,@MinW=MinWidthPx,@MaxH=MaxHeightPx,@MinH=MinHeigntPx,@MaxS=MaxFileSizeBytes,@MinS=MinFileSizeBytes
    FROM nft.NFTSettings WHERE SettingsID=@SettingsID;

    IF @WidthPx  IS NULL OR @HeightPx IS NULL OR @FileSizeBytes IS NULL
        THROW 50005, 'Dimensiones/tamaño requeridos.', 1;
    IF @WidthPx  NOT BETWEEN @MinW AND @MaxW  THROW 50001, 'Ancho fuera de límites.', 1;
    IF @HeightPx NOT BETWEEN @MinH AND @MaxH THROW 50002, 'Alto fuera de límites.', 1;
    IF @FileSizeBytes NOT BETWEEN @MinS AND @MaxS THROW 50003, 'Peso fuera de límites.', 1;
    IF EXISTS (SELECT 1 FROM nft.NFT WHERE HashCode=@HashCode)
        THROW 50006, 'HashCode duplicado.', 1;

    INSERT INTO nft.NFT (ArtistId,SettingsID,[Name],[Description],ContentType,HashCode,FileSizeBytes,WidthPx,HeightPx,SuggestedPriceETH,StatusCode,CreatedAtUtc)
    VALUES (@ArtistId,@SettingsID,@Name,@Description,@ContentType,@HashCode,@FileSizeBytes,@WidthPx,@HeightPx,@SuggestedPriceETH,'PENDING',SYSUTCDATETIME());
END;
GO

-- Consolidación de fallos de email (igual que v6.1, umbral >= 3)
CREATE OR ALTER PROCEDURE audit.sp_NotifyEmailFailures
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MinFailures INT = 3, @RecentMinutes INT = 10, @NowUtc DATETIME2(3) = SYSUTCDATETIME();

    IF EXISTS (
        SELECT 1 FROM audit.EmailOutbox
        WHERE StatusDomain='EMAIL_OUTBOX' AND StatusCode IN('PENDING','SENT')
          AND CorrelationKey='EMAIL_FAILURE_REPORT'
          AND CreatedAtUtc >= DATEADD(MINUTE,-@RecentMinutes,@NowUtc)
    ) RETURN;

    DECLARE @FailuresCount INT;
    SELECT @FailuresCount = COUNT(*) FROM audit.EmailOutbox WHERE StatusCode='FAILED';
    IF @FailuresCount < @MinFailures RETURN;

    DECLARE @Failures NVARCHAR(MAX);
    ;WITH F AS (
        SELECT E.EmailId, ISNULL(E.RecipientEmail,'N/A') AS RecipientEmail, E.[Subject], E.CreatedAtUtc,
               COALESCE(
                   CASE WHEN CHARINDEX('ERROR:',E.[Subject])>0 THEN SUBSTRING(E.[Subject], CHARINDEX('ERROR:',E.[Subject])+6, 200) END,
                   CASE WHEN CHARINDEX('ERROR:',E.Body)>0 THEN SUBSTRING(E.Body, CHARINDEX('ERROR:',E.Body)+6, 400) END,
                   E.CorrelationKey, N'N/D'
               ) AS FailureReason
        FROM audit.EmailOutbox E
        WHERE E.StatusCode='FAILED'
    )
    SELECT @Failures = STRING_AGG(
        CONCAT('ID: ',EmailId,' | Destino: ',RecipientEmail,' | Asunto: ',[Subject],
               ' | FechaUTC: ',CONVERT(varchar(19),CreatedAtUtc,126),' | Razón: ',FailureReason),
        CHAR(13)+CHAR(10))
    FROM F;

    IF @Failures IS NULL RETURN;

    INSERT INTO audit.EmailOutbox (RecipientEmail,[Subject],Body,StatusCode,CreatedAtUtc,CorrelationKey)
    VALUES ('admin@artecryptoauctions.com',
            N'⚠️ Reporte consolidado de errores de envío de correo',
            CONCAT(N'Se detectaron ',@FailuresCount,N' errores de envío. Detalle:',CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10),@Failures),
            'PENDING', @NowUtc, 'EMAIL_FAILURE_REPORT');
END;
GO

-- =====================================================================================
-- PROCEDIMIENTO ALMACENADO: auction.sp_PlaceBid
-- Descripción: Punto de entrada para que un usuario realice una oferta en una subasta.
-- =====================================================================================

CREATE OR ALTER PROCEDURE auction.sp_PlaceBid
    @AuctionId BIGINT,
    @BidderId  BIGINT,
    @AmountETH DECIMAL(38,18)
AS
BEGIN
    SET NOCOUNT ON;

    -- Máxima seguridad contra condiciones de carrera
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRAN;

    BEGIN TRY
        IF @AmountETH IS NULL OR @AmountETH <= 0
            THROW 51000, 'Monto de oferta inválido.', 1;

        -- Bloquear fila de la subasta para lectura/escritura concurrente controlada
        DECLARE
            @SettingsID INT,
            @StatusCode VARCHAR(30),
            @StartAt DATETIME2(3),
            @EndAt   DATETIME2(3),
            @CurrentPrice DECIMAL(38,18),
            @CurrentLeader BIGINT;

        SELECT @SettingsID = A.SettingsID,
               @StatusCode = A.StatusCode,
               @StartAt    = A.StartAtUtc,
               @EndAt      = A.EndAtUtc,
               @CurrentPrice = A.CurrentPriceETH,
               @CurrentLeader = A.CurrentLeaderId
        FROM auction.Auction A WITH (UPDLOCK, ROWLOCK)
        WHERE AuctionId = @AuctionId;

        IF @StatusCode IS NULL
            THROW 51001, 'Subasta no existe.', 1;

        IF @StatusCode <> 'ACTIVE'
            THROW 51002, 'La subasta no está activa.', 1;

        IF SYSUTCDATETIME() < @StartAt OR SYSUTCDATETIME() >= @EndAt
            THROW 51003, 'La subasta no está en ventana de tiempo.', 1;

        -- Obtener incremento mínimo (default 5% si no hay Settings)
        DECLARE @MinIncPct TINYINT = 5;
        IF @SettingsID IS NOT NULL
            SELECT @MinIncPct = MinBidIncrementPct FROM auction.AuctionSettings WHERE SettingsID = @SettingsID;

        -- Calcular precio mínimo aceptable
        DECLARE @MinAcceptable DECIMAL(38,18);
        SET @MinAcceptable = ROUND(@CurrentPrice * (1 + (CONVERT(DECIMAL(38,18), @MinIncPct) / 100.0)), 18);

        IF @AmountETH < @MinAcceptable
            THROW 51004, 'Oferta insuficiente según incremento mínimo.', 1;

        -- Validar fondos del postor
        DECLARE @Bal DECIMAL(38,18), @Res DECIMAL(38,18);
        SELECT @Bal = BalanceETH, @Res = ReservedETH
        FROM core.Wallet WITH (UPDLOCK, ROWLOCK)
        WHERE UserId = @BidderId;

        IF @Bal IS NULL
            THROW 51005, 'Cartera no encontrada.', 1;

        IF (@Bal - @Res) < @AmountETH
            THROW 51006, 'Saldo disponible insuficiente.', 1;

        -- Insertar oferta
        DECLARE @NewBidId BIGINT;
        INSERT INTO auction.Bid (AuctionId, BidderId, AmountETH)
        VALUES (@AuctionId, @BidderId, @AmountETH);
        SET @NewBidId = SCOPE_IDENTITY();

        -- Manejo de reservas:
        -- 1) Si hay líder anterior distinto al nuevo, liberar su reserva ACTIVE de esta subasta
        IF @CurrentLeader IS NOT NULL AND @CurrentLeader <> @BidderId
        BEGIN
            DECLARE @PrevResId BIGINT, @PrevAmount DECIMAL(38,18);
            SELECT TOP 1 @PrevResId = ReservationId, @PrevAmount = AmountETH
            FROM finance.FundsReservation WITH (UPDLOCK, ROWLOCK)
            WHERE AuctionId = @AuctionId AND UserId = @CurrentLeader AND StateCode = 'ACTIVE'
            ORDER BY CreatedAtUtc DESC;

            IF @PrevResId IS NOT NULL
            BEGIN
                UPDATE finance.FundsReservation
                  SET StateCode='RELEASED', UpdatedAtUtc=SYSUTCDATETIME()
                WHERE ReservationId=@PrevResId;

                -- Disminuir ReservedETH del líder anterior
                UPDATE core.Wallet
                  SET ReservedETH = ReservedETH - @PrevAmount,
                      UpdatedAtUtc = SYSUTCDATETIME()
                WHERE UserId = @CurrentLeader;

                -- Notificar al líder anterior que perdió liderazgo
                INSERT INTO audit.EmailOutbox (RecipientUserId,[Subject],Body,StatusCode,CreatedAtUtc,CorrelationKey)
                VALUES (
                    @CurrentLeader,
                    N'Has perdido el liderazgo en una subasta',
                    CONCAT(N'Has sido superado en la subasta ', @AuctionId, N'. Tu reserva anterior fue liberada.'),
                    'PENDING',
                    SYSUTCDATETIME(),
                    CONCAT('AUCTION_LOST_LEAD_', @AuctionId)
                );
            END
        END

        -- 2) Si el mismo postor ya era líder, ajustar su reserva; si no, crear nueva
        DECLARE @ExistingResId BIGINT, @ExistingAmount DECIMAL(38,18);
        SELECT TOP 1 @ExistingResId = ReservationId, @ExistingAmount = AmountETH
        FROM finance.FundsReservation WITH (UPDLOCK, ROWLOCK)
        WHERE AuctionId=@AuctionId AND UserId=@BidderId AND StateCode='ACTIVE'
        ORDER BY CreatedAtUtc DESC;

        IF @ExistingResId IS NULL
        BEGIN
            -- Crear nueva reserva
            INSERT INTO finance.FundsReservation (UserId, AuctionId, BidId, AmountETH, StateCode)
            VALUES (@BidderId, @AuctionId, @NewBidId, @AmountETH, 'ACTIVE');

            UPDATE core.Wallet
              SET ReservedETH = ReservedETH + @AmountETH,
                  UpdatedAtUtc = SYSUTCDATETIME()
            WHERE UserId = @BidderId;
        END
        ELSE
        BEGIN
            -- Actualizar reserva del mismo líder (aumentar al nuevo monto)
            DECLARE @Delta DECIMAL(38,18) = @AmountETH - @ExistingAmount;
            IF @Delta > 0
            BEGIN
                UPDATE finance.FundsReservation
                  SET AmountETH = @AmountETH, BidId = @NewBidId, UpdatedAtUtc = SYSUTCDATETIME()
                WHERE ReservationId = @ExistingResId;

                UPDATE core.Wallet
                  SET ReservedETH = ReservedETH + @Delta,
                      UpdatedAtUtc = SYSUTCDATETIME()
                WHERE UserId = @BidderId;
            END
        END

        -- 3) Actualizar subasta: nuevo precio y líder
        UPDATE auction.Auction
          SET CurrentPriceETH = @AmountETH,
              CurrentLeaderId = @BidderId
        WHERE AuctionId = @AuctionId;

        -- Notificar al nuevo líder
        INSERT INTO audit.EmailOutbox (RecipientUserId,[Subject],Body,StatusCode,CreatedAtUtc,CorrelationKey)
        VALUES (
            @BidderId,
            N'¡Oferta aceptada! Ahora lideras la subasta',
            CONCAT(N'Tu oferta de ', CONVERT(NVARCHAR(50),@AmountETH), N' ETH fue aceptada en la subasta ', @AuctionId, N'.'),
            'PENDING',
            SYSUTCDATETIME(),
            CONCAT('AUCTION_LEAD_', @AuctionId)
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        DECLARE @Msg NVARCHAR(4000) = ERROR_MESSAGE(), @Num INT = ERROR_NUMBER(), @Sev INT = ERROR_SEVERITY(), @State INT = ERROR_STATE();
        RAISERROR(@Msg, @Sev, @State);
    END CATCH
END;
GO