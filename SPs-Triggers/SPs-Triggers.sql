-- ArteCrypto • SPs & Triggers (v3)
-- Compatibles con DDL v3 (ops.Status, StatusDomain computado, multi‑email)
-- Incluye: funciones utilitarias, outbox, SPs de negocio, trigger de auto‑subasta

/*=========================================================
  CONFIG COMÚN
=========================================================*/
USE ArteCryptoAuctions
GO
CREATE OR ALTER FUNCTION core.fn_UserPrimaryEmail (@UserId BIGINT)
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @e NVARCHAR(100);
    SELECT TOP (1) @e = Email
    FROM core.UserEmail
    WHERE UserId = @UserId AND IsPrimary = 1 AND StatusCode = 'ACTIVE'
    ORDER BY EmailId DESC;
    RETURN @e;
END
GO

CREATE OR ALTER FUNCTION ops.fn_GetSettingInt (@Key SYSNAME, @Default INT)
RETURNS INT
AS
BEGIN
    DECLARE @v INT = @Default;
    SELECT @v = TRY_CONVERT(INT, SettingValue) FROM ops.Settings WHERE SettingKey=@Key;
    RETURN @v;
END
GO

CREATE OR ALTER FUNCTION ops.fn_GetSettingDecimal (@Key SYSNAME, @Default DECIMAL(38,18))
RETURNS DECIMAL(38,18)
AS
BEGIN
    DECLARE @v DECIMAL(38,18) = @Default;
    SELECT @v = TRY_CONVERT(DECIMAL(38,18), SettingValue) FROM ops.Settings WHERE SettingKey=@Key;
    RETURN @v;
END
GO

/*=========================================================
  OUTBOX DE EMAIL + HELPER
=========================================================*/
GO
IF OBJECT_ID('audit.EmailOutbox') IS NULL
BEGIN
  CREATE TABLE audit.EmailOutbox (
      EmailId         BIGINT IDENTITY(1,1) PRIMARY KEY,
      RecipientUserId BIGINT         NULL,
      RecipientEmail  NVARCHAR(100)  NOT NULL,
      [Subject]       NVARCHAR(200)  NOT NULL,
      [Body]          NVARCHAR(MAX)  NOT NULL,
      StatusCode      VARCHAR(30)    NOT NULL DEFAULT 'PENDING',
      StatusDomain    AS CAST('EMAIL_OUTBOX' AS VARCHAR(50)) PERSISTED,
      CreatedAtUtc    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
      SentAtUtc       DATETIME2(3)   NULL,
      CorrelationKey  NVARCHAR(100)  NULL,
      CONSTRAINT FK_EmailOutbox_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.[Status]([Domain],[Code])
  );
  CREATE INDEX IX_EmailOutbox_Pending ON audit.EmailOutbox(StatusCode) WHERE StatusCode='PENDING';
END
GO

CREATE OR ALTER PROCEDURE ops.sp_Email_Enqueue
  @RecipientUserId BIGINT = NULL,
  @RecipientEmail  NVARCHAR(100) = NULL,
  @Subject         NVARCHAR(200),
  @Body            NVARCHAR(MAX),
  @CorrelationKey  NVARCHAR(100) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  BEGIN TRY
    BEGIN TRAN;
      DECLARE @email NVARCHAR(100) = @RecipientEmail;
      IF @email IS NULL AND @RecipientUserId IS NOT NULL
          SELECT @email = core.fn_UserPrimaryEmail(@RecipientUserId);

      IF @email IS NULL THROW 51001, 'No hay email de destino (ni principal ni explícito).', 1;

      INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], CorrelationKey)
      VALUES(@RecipientUserId, @email, @Subject, @Body, @CorrelationKey);
    COMMIT TRAN;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
  END CATCH
END
GO

/*=========================================================
  NFT: SUBMIT & REVIEW
=========================================================*/
GO
CREATE OR ALTER PROCEDURE nft.sp_NFT_Submit
(
    @ArtistId           BIGINT,
    @Name               NVARCHAR(160),
    @Description        NVARCHAR(MAX) = NULL,
    @ContentType        NVARCHAR(100),
    @HashCode           CHAR(64),
    @FileSizeBytes      BIGINT = NULL,
    @WidthPx            INT = NULL,
    @HeightPx           INT = NULL,
    @SuggestedPriceETH  DECIMAL(38,18) = NULL
)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  BEGIN TRY
    BEGIN TRAN;
      INSERT INTO nft.NFT(ArtistId, CurrentOwnerId, [Name], [Description], ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH)
      VALUES(@ArtistId, @ArtistId, @Name, @Description, @ContentType, @HashCode, @FileSizeBytes, @WidthPx, @HeightPx, @SuggestedPriceETH);

      DECLARE @NFTId BIGINT = SCOPE_IDENTITY();
      EXEC ops.sp_Email_Enqueue @RecipientUserId=@ArtistId,
           @Subject=N'NFT recibido',
           @Body= (N'Hemos recibido tu NFT y está en revisión. Id=' + CAST(@NFTId AS NVARCHAR(50))),
           @CorrelationKey = CAST(@NFTId AS NVARCHAR(50));
    COMMIT TRAN;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
  END CATCH
END
GO

CREATE OR ALTER PROCEDURE admin.sp_NFT_Review
(
    @CuratorId BIGINT,
    @NFTId     BIGINT,
    @Decision  VARCHAR(10), -- APPROVE | REJECT
    @Comment   NVARCHAR(MAX) = NULL
)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  IF (@Decision NOT IN ('APPROVE','REJECT')) THROW 50001, 'Decision inválida', 1;

  BEGIN TRY
    BEGIN TRAN;
      DECLARE @ArtistId BIGINT;
      SELECT @ArtistId = ArtistId FROM nft.NFT WHERE NFTId=@NFTId;
      IF @ArtistId IS NULL THROW 50002, 'NFT inexistente', 1;

      INSERT INTO admin.CurationReview(NFTId, CuratorId, DecisionCode, [Comment], ReviewedAtUtc)
      VALUES(@NFTId, @CuratorId, @Decision, @Comment, SYSUTCDATETIME());

      IF @Decision='APPROVE'
        UPDATE nft.NFT SET StatusCode='APPROVED', ApprovedAtUtc=SYSUTCDATETIME() WHERE NFTId=@NFTId;
      ELSE
        UPDATE nft.NFT SET StatusCode='REJECTED' WHERE NFTId=@NFTId;

      DECLARE @msg NVARCHAR(MAX) = CASE WHEN @Decision='APPROVE'
        THEN N'Tu NFT fue aprobado y será subastado automáticamente.'
        ELSE N'Tu NFT fue rechazado. Comentarios: ' + ISNULL(@Comment,N'(sin comentarios)') END;
      EXEC ops.sp_Email_Enqueue @RecipientUserId=@ArtistId,
           @Subject=N'Resultado de revisión de tu NFT',
           @Body=@msg,
           @CorrelationKey=CONVERT(NVARCHAR(50),@NFTId);
    COMMIT TRAN;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
  END CATCH
END
GO

/*=========================================================
  TRIGGER: Auto‑crear subasta al aprobar NFT
=========================================================*/
GO
CREATE OR ALTER TRIGGER nft.trg_NFT_AutoCreateAuction
ON nft.NFT
AFTER UPDATE
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    ;WITH c AS (
      SELECT i.NFTId, i.SuggestedPriceETH, i.ArtistId
      FROM inserted i
      JOIN deleted  d ON d.NFTId = i.NFTId
      WHERE d.StatusCode <> 'APPROVED' AND i.StatusCode = 'APPROVED'
    )
    INSERT INTO auction.Auction (NFTId, StartAtUtc, EndAtUtc, StartingPriceETH, CurrentPriceETH, StatusCode)
    SELECT 
      c.NFTId,
      SYSUTCDATETIME(),
      DATEADD(HOUR, ISNULL(ops.fn_GetSettingInt('DefaultAuctionHours',72),72), SYSUTCDATETIME()),
      ISNULL(c.SuggestedPriceETH, ops.fn_GetSettingDecimal('BasePriceETH', CAST(0.1 AS DECIMAL(38,18)))),
      ISNULL(c.SuggestedPriceETH, ops.fn_GetSettingDecimal('BasePriceETH', CAST(0.1 AS DECIMAL(38,18)))),
      'ACTIVE'
    FROM c;

    -- Notificar a artistas
    DECLARE @ArtistId BIGINT, @NId BIGINT;
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT ArtistId, NFTId FROM c;
    OPEN cur;
    FETCH NEXT FROM cur INTO @ArtistId, @NId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
      EXEC ops.sp_Email_Enqueue @RecipientUserId=@ArtistId,
        @Subject=N'Subasta creada para tu NFT',
        @Body=N'Tu NFT (Id=' + CONVERT(NVARCHAR(50),@NId) + N') ha sido listado en subasta.',
        @CorrelationKey=CONVERT(NVARCHAR(50),@NId);
      FETCH NEXT FROM cur INTO @ArtistId, @NId;
    END
    CLOSE cur; DEALLOCATE cur;
  END TRY
  BEGIN CATCH
    -- Si falla el trigger, la actualización de NFT también hará rollback
    THROW;
  END CATCH
END
GO

/*=========================================================
  AUCTION: Colocar oferta con reservas coherentes
=========================================================*/
GO
CREATE OR ALTER PROCEDURE auction.sp_PlaceBid
(
  @AuctionId BIGINT,
  @BidderId  BIGINT,
  @AmountETH DECIMAL(38,18)
)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  IF @AmountETH IS NULL OR @AmountETH <= 0 THROW 50010, 'Monto inválido', 1;

  DECLARE @pctInc DECIMAL(9,4) = TRY_CONVERT(DECIMAL(9,4), (SELECT SettingValue FROM ops.Settings WHERE SettingKey='MinBidIncrementPct'));
  IF @pctInc IS NULL SET @pctInc = 0;

  BEGIN TRY
    BEGIN TRAN;
      -- Bloquear la subasta para lectura/actualización coherente
      DECLARE @start DATETIME2(3), @end DATETIME2(3), @status VARCHAR(30), @currentPrice DECIMAL(38,18), @leader BIGINT;
      SELECT @start=StartAtUtc, @end=EndAtUtc, @status=StatusCode, @currentPrice=CurrentPriceETH, @leader=CurrentLeaderId
      FROM auction.Auction WITH (UPDLOCK, HOLDLOCK)
      WHERE AuctionId = @AuctionId;

      IF @status IS NULL THROW 50011, 'Subasta no existe', 1;
      IF @status <> 'ACTIVE' OR SYSUTCDATETIME() < @start OR SYSUTCDATETIME() >= @end THROW 50012, 'Subasta inactiva o fuera de ventana', 1;

      DECLARE @minRequired DECIMAL(38,18) = CASE WHEN @pctInc > 0 THEN @currentPrice * (1 + (@pctInc/100.0)) ELSE @currentPrice + 0.000000000000000001 END;
      IF @AmountETH < @minRequired THROW 50013, 'Oferta insuficiente según reglas', 1;

      -- Obtener/crear billetera del postor con bloqueo
      DECLARE @bal DECIMAL(38,18), @res DECIMAL(38,18);
      SELECT @bal = BalanceETH, @res = ReservedETH FROM core.Wallet WITH(UPDLOCK, HOLDLOCK) WHERE UserId=@BidderId;
      IF @bal IS NULL THROW 50014, 'Billetera inexistente', 1;

      -- Reserva ACTIVA existente del postor en esta subasta
      DECLARE @oldRes DECIMAL(38,18) = NULL, @resId BIGINT = NULL;
      SELECT TOP(1) @resId = ReservationId, @oldRes = AmountETH
      FROM finance.FundsReservation WITH(UPDLOCK, HOLDLOCK)
      WHERE UserId=@BidderId AND AuctionId=@AuctionId AND StateCode='ACTIVE'
      ORDER BY ReservationId DESC;

      DECLARE @delta DECIMAL(38,18) = CASE WHEN @oldRes IS NULL THEN @AmountETH ELSE @AmountETH - @oldRes END;
      IF @delta < 0 THROW 50015, 'No se permite reducir la oferta previa', 1;
      IF (@bal - @res) < @delta THROW 50016, 'Saldo insuficiente para reservar', 1;

      -- Insertar oferta
      INSERT INTO auction.Bid(AuctionId, BidderId, AmountETH) VALUES(@AuctionId, @BidderId, @AmountETH);

      -- Actualizar líder/price
      UPDATE auction.Auction
        SET CurrentPriceETH = @AmountETH,
            CurrentLeaderId = @BidderId
      WHERE AuctionId = @AuctionId;

      -- Upsert de reserva ACTIVA
      IF @resId IS NULL
        INSERT INTO finance.FundsReservation(UserId, AuctionId, AmountETH, StateCode)
        VALUES(@BidderId, @AuctionId, @AmountETH, 'ACTIVE');
      ELSE
        UPDATE finance.FundsReservation
          SET AmountETH = @AmountETH, UpdatedAtUtc = SYSUTCDATETIME()
        WHERE ReservationId = @resId;

      -- Ajustar ReservedETH por delta
      UPDATE core.Wallet
        SET ReservedETH = ReservedETH + @delta,
            UpdatedAtUtc = SYSUTCDATETIME()
      WHERE UserId = @BidderId;

      -- Notificación al postor
      EXEC ops.sp_Email_Enqueue @RecipientUserId=@BidderId,
        @Subject=N'Confirmación de oferta',
        @Body=N'Tu oferta por ' + CONVERT(NVARCHAR(64),@AmountETH) + N' ETH fue registrada.',
        @CorrelationKey=CONVERT(NVARCHAR(50),@AuctionId);
    COMMIT TRAN;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
  END CATCH
END
GO

/*=========================================================
  AUCTION: Finalizar subastas vencidas
=========================================================*/
GO
CREATE OR ALTER PROCEDURE auction.sp_FinalizeDueAuctions
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

  DECLARE @toClose TABLE (AuctionId BIGINT PRIMARY KEY);
  INSERT INTO @toClose(AuctionId)
  SELECT AuctionId FROM auction.Auction WITH (READPAST)
  WHERE StatusCode='ACTIVE' AND EndAtUtc <= @now;

  DECLARE @A BIGINT;
  WHILE EXISTS (SELECT 1 FROM @toClose)
  BEGIN
    SELECT TOP(1) @A = AuctionId FROM @toClose ORDER BY AuctionId;
    DELETE FROM @toClose WHERE AuctionId=@A;

    BEGIN TRY
      SET XACT_ABORT ON;
      BEGIN TRAN;
        -- Bloquear subasta
        DECLARE @status VARCHAR(30), @nft BIGINT;
        SELECT @status=StatusCode, @nft=NFTId
        FROM auction.Auction WITH(UPDLOCK, HOLDLOCK)
        WHERE AuctionId=@A;
        IF @status IS NULL BEGIN ROLLBACK TRAN; CONTINUE; END;
        IF @status <> 'ACTIVE' BEGIN COMMIT TRAN; CONTINUE; END;

        -- Ganador
        DECLARE @winner BIGINT = NULL, @amount DECIMAL(38,18) = NULL, @placed DATETIME2(3) = NULL;
        SELECT TOP(1) @winner = b.BidderId, @amount = b.AmountETH, @placed = b.PlacedAtUtc
        FROM auction.Bid b
        WHERE b.AuctionId=@A
        ORDER BY b.AmountETH DESC, b.PlacedAtUtc ASC, b.BidId ASC;

        IF @winner IS NULL
        BEGIN
          UPDATE auction.Auction SET StatusCode='FINALIZED' WHERE AuctionId=@A;
          COMMIT TRAN; CONTINUE;
        END

        DECLARE @artist BIGINT; SELECT @artist = n.ArtistId FROM nft.NFT n WHERE n.NFTId=@nft;

        -- Reserva del ganador (ACTIVA)
        DECLARE @winResId BIGINT, @winResAmt DECIMAL(38,18);
        SELECT TOP(1) @winResId = ReservationId, @winResAmt = AmountETH
        FROM finance.FundsReservation WITH(UPDLOCK, HOLDLOCK)
        WHERE UserId=@winner AND AuctionId=@A AND StateCode='ACTIVE'
        ORDER BY ReservationId DESC;
        IF @winResId IS NULL OR @winResAmt < @amount THROW 50030, 'Reserva del ganador inexistente o insuficiente', 1;

        -- Aplicar ganador: bajar reservado y balance; asiento DEBIT
        UPDATE core.Wallet
          SET ReservedETH = ReservedETH - @amount,
              BalanceETH  = BalanceETH  - @amount,
              UpdatedAtUtc = SYSUTCDATETIME()
        WHERE UserId=@winner;

        UPDATE finance.FundsReservation
          SET StateCode='APPLIED', UpdatedAtUtc=SYSUTCDATETIME()
        WHERE ReservationId=@winResId;

        INSERT INTO finance.Ledger(UserId, AuctionId, EntryType, AmountETH, [Description])
        VALUES(@winner, @A, 'DEBIT', @amount, N'Compra NFT');

        -- Pagar al artista
        UPDATE core.Wallet
          SET BalanceETH = BalanceETH + @amount,
              UpdatedAtUtc = SYSUTCDATETIME()
        WHERE UserId=@artist;

        INSERT INTO finance.Ledger(UserId, AuctionId, EntryType, AmountETH, [Description])
        VALUES(@artist, @A, 'CREDIT', @amount, N'Venta NFT');

        -- Liberar reservas de perdedores
        UPDATE fr SET StateCode='RELEASED', UpdatedAtUtc=SYSUTCDATETIME()
        FROM finance.FundsReservation fr
        WHERE fr.AuctionId=@A AND fr.UserId<>@winner AND fr.StateCode='ACTIVE';

        UPDATE w
          SET ReservedETH = w.ReservedETH - fr.AmountETH,
              UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN finance.FundsReservation fr ON fr.UserId = w.UserId
        WHERE fr.AuctionId=@A AND fr.UserId<>@winner AND fr.StateCode='RELEASED';

        -- Transferir propiedad del NFT + cerrar subasta (precio/leader finales)
        UPDATE nft.NFT SET CurrentOwnerId=@winner, StatusCode='FINALIZED' WHERE NFTId=@nft;
        UPDATE auction.Auction SET StatusCode='FINALIZED', CurrentLeaderId=@winner, CurrentPriceETH=@amount WHERE AuctionId=@A;

        -- Notificar
        EXEC ops.sp_Email_Enqueue @RecipientUserId=@artist,
          @Subject=N'¡Venta exitosa!',
          @Body=N'Tu NFT se vendió por ' + CONVERT(NVARCHAR(64),@amount) + N' ETH.';
        EXEC ops.sp_Email_Enqueue @RecipientUserId=@winner,
          @Subject=N'¡Ganaste la subasta!',
          @Body=N'Ganaste con una oferta de ' + CONVERT(NVARCHAR(64),@amount) + N' ETH.';

      COMMIT TRAN;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0 ROLLBACK TRAN;
      -- continuar con la siguiente sin abortar el lote
    END CATCH
  END
END
GO

/*=========================================================
  OPS: Actualizar Settings con validación
=========================================================*/
GO
CREATE OR ALTER PROCEDURE ops.sp_Setting_Set
  @SettingKey   SYSNAME,
  @SettingValue NVARCHAR(200)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  -- Validaciones simples
  IF @SettingKey = 'DefaultAuctionHours'
  BEGIN
    IF TRY_CONVERT(INT, @SettingValue) IS NULL OR TRY_CONVERT(INT, @SettingValue) <= 0
      THROW 50001, 'DefaultAuctionHours debe ser entero > 0', 1;
  END
  IF @SettingKey = 'BasePriceETH'
  BEGIN
    IF TRY_CONVERT(DECIMAL(38,18), @SettingValue) IS NULL
      THROW 50002, 'BasePriceETH debe ser decimal', 1;
  END
  IF @SettingKey = 'MinBidIncrementPct'
  BEGIN
    IF TRY_CONVERT(DECIMAL(9,4), @SettingValue) IS NULL OR TRY_CONVERT(DECIMAL(9,4), @SettingValue) < 0
      THROW 50003, 'MinBidIncrementPct debe ser decimal >= 0', 1;
  END

  BEGIN TRY
    BEGIN TRAN;
      IF EXISTS (SELECT 1 FROM ops.Settings WITH (UPDLOCK, HOLDLOCK) WHERE SettingKey = @SettingKey)
        UPDATE ops.Settings SET SettingValue = @SettingValue, UpdatedAtUtc = SYSUTCDATETIME() WHERE SettingKey = @SettingKey;
      ELSE
        INSERT INTO ops.Settings(SettingKey, SettingValue) VALUES (@SettingKey, @SettingValue);
    COMMIT TRAN;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
  END CATCH
END
GO

-- Fin de SPs & Trigger v3
