-- =====================================================================================
-- DDL v7 - ArteCryptoAuctions (Subastas con Ofertas y Reservas de Fondos)
-- Sistema de Subastas de NFTs
-- Fecha: 2025-10-12 (v7)
-- Contiene TODO lo de v6.1 + Fase 3 (ofertas):
--   - auction.sp_PlaceBid: validaciones, reservas y notificaciones (incluye correo a líder anterior).
--   - Mantiene: nft.sp_SubmitNFT, audit.sp_NotifyEmailFailures, trigger de consolidación (umbral >= 3).
-- =====================================================================================

CREATE DATABASE ArteCryptoAuctions;
GO

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- ESQUEMAS
-- =====================================================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'admin')  EXEC('CREATE SCHEMA admin');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'auction') EXEC('CREATE SCHEMA auction');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')  EXEC('CREATE SCHEMA audit');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')   EXEC('CREATE SCHEMA core');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'finance') EXEC('CREATE SCHEMA finance');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'nft')    EXEC('CREATE SCHEMA nft');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')    EXEC('CREATE SCHEMA ops');
GO

-- =====================================================================================
-- core
-- =====================================================================================
CREATE TABLE core.[User] (
    UserId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    FullName     NVARCHAR(100) NOT NULL,
    CreatedAtUtc DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
CREATE TABLE core.Role (
    RoleId BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Name] NVARCHAR(100) NOT NULL UNIQUE
);
GO
CREATE TABLE core.UserRole (
    UserId BIGINT NOT NULL,
    RoleId BIGINT NOT NULL,
    AsignacionUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_UserRole PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_UserRole_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_UserRole_Role FOREIGN KEY (RoleId) REFERENCES core.Role(RoleId)
);
GO
CREATE TABLE core.UserEmail (
    EmailId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId  BIGINT NOT NULL,
    Email   NVARCHAR(100) NOT NULL UNIQUE,
    IsPrimary BIT NOT NULL DEFAULT 0,
    AddedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    VerifiedAtUtc DATETIME2(3) NULL,
    StatusCode VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    StatusDomain AS CONVERT(VARCHAR(50), 'USER_EMAIL') PERSISTED,
    CONSTRAINT FK_UserEmail_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId)
);
GO
CREATE TABLE core.Wallet (
    WalletId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId   BIGINT NOT NULL UNIQUE,
    BalanceETH  DECIMAL(38,18) NOT NULL DEFAULT 0,
    ReservedETH DECIMAL(38,18) NOT NULL DEFAULT 0,
    UpdatedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Wallet_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_Wallet_Positive CHECK (BalanceETH >= 0 AND ReservedETH >= 0)
);
GO

-- =====================================================================================
-- nft
-- =====================================================================================
CREATE TABLE nft.NFTSettings (
    SettingsID          INT PRIMARY KEY,
    MaxWidthPx          BIGINT NOT NULL,
    MinWidthPx          BIGINT NOT NULL,
    MaxHeightPx         BIGINT NOT NULL,
    MinHeigntPx         BIGINT NOT NULL,
    MaxFileSizeBytes    BIGINT NOT NULL,
    MinFileSizeBytes    BIGINT NOT NULL,
    CreatedAtUtc        DATETIME2(3) NOT NULL
);
GO
CREATE TABLE nft.NFT (
    NFTId               BIGINT IDENTITY(1,1) PRIMARY KEY,
    ArtistId            BIGINT NOT NULL,
    SettingsID          INT NOT NULL,
    CurrentOwnerId      BIGINT NULL,
    [Name]              NVARCHAR(160) NOT NULL,
    [Description]       NVARCHAR(MAX) NULL,
    ContentType         NVARCHAR(100) NOT NULL,
    HashCode            CHAR(64) NOT NULL UNIQUE,
    FileSizeBytes       BIGINT NULL,
    WidthPx             INT NULL,
    HeightPx            INT NULL,
    SuggestedPriceETH   DECIMAL(38,18) NULL,
    StatusCode          VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    StatusDomain        AS CONVERT(VARCHAR(50), 'NFT') PERSISTED,
    CreatedAtUtc        DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ApprovedAtUtc       DATETIME2(3) NULL,
    CONSTRAINT FK_NFT_Artist FOREIGN KEY (ArtistId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_NFT_Owner FOREIGN KEY (CurrentOwnerId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_NFT_NFTSettings FOREIGN KEY (SettingsID) REFERENCES nft.NFTSettings(SettingsID)
);
GO

-- =====================================================================================
-- admin
-- =====================================================================================
CREATE TABLE admin.CurationReview (
    ReviewId      BIGINT IDENTITY(1,1) PRIMARY KEY,
    NFTId         BIGINT NOT NULL,
    CuratorId     BIGINT NOT NULL,
    DecisionCode  VARCHAR(30) NOT NULL,
    StatusDomain  AS CONVERT(VARCHAR(50), 'CURATION_DECISION') PERSISTED,
    Comment       NVARCHAR(MAX) NULL,
    StartedAtUtc  DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ReviewedAtUtc DATETIME2(3) NULL,
    CONSTRAINT FK_CReview_NFT     FOREIGN KEY (NFTId) REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_CReview_Curator FOREIGN KEY (CuratorId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_CReview_Times CHECK (ReviewedAtUtc IS NULL OR ReviewedAtUtc >= StartedAtUtc)
);
GO

-- =====================================================================================
-- auction
-- =====================================================================================
CREATE TABLE auction.AuctionSettings (
    SettingsID              INT PRIMARY KEY,
    CompanyName             NVARCHAR(250) NOT NULL,
    BasePriceETH            DECIMAL(38,18) NOT NULL,
    DefaultAuctionHours     TINYINT NOT NULL,
    MinBidIncrementPct      TINYINT NOT NULL
);
GO
CREATE TABLE auction.Auction (
    AuctionId           BIGINT IDENTITY(1,1) PRIMARY KEY,
    SettingsID          INT NULL,
    NFTId               BIGINT NOT NULL UNIQUE,
    StartAtUtc          DATETIME2(3) NOT NULL,
    EndAtUtc            DATETIME2(3) NOT NULL,
    StartingPriceETH    DECIMAL(38,18) NOT NULL,
    CurrentPriceETH     DECIMAL(38,18) NOT NULL,
    CurrentLeaderId     BIGINT NULL,
    StatusCode          VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    StatusDomain        AS CONVERT(VARCHAR(50), 'AUCTION') PERSISTED,
    CONSTRAINT FK_Auction_NFT      FOREIGN KEY (NFTId) REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_Auction_Leader   FOREIGN KEY (CurrentLeaderId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_Auction_Settings FOREIGN KEY (SettingsID) REFERENCES auction.AuctionSettings(SettingsID),
    CONSTRAINT CK_Auction_Dates CHECK (EndAtUtc > StartAtUtc),
    CONSTRAINT CK_Auction_Prices CHECK (StartingPriceETH > 0 AND CurrentPriceETH >= StartingPriceETH)
);
GO
CREATE TABLE auction.Bid (
    BidId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    AuctionId   BIGINT NOT NULL,
    BidderId    BIGINT NOT NULL,
    AmountETH   DECIMAL(38,18) NOT NULL,
    PlacedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Bid_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_Bid_User    FOREIGN KEY (BidderId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_Bid_Positive CHECK (AmountETH > 0)
);
GO

-- =====================================================================================
-- finance
-- =====================================================================================
CREATE TABLE finance.FundsReservation (
    ReservationId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId        BIGINT NOT NULL,
    AuctionId     BIGINT NOT NULL,
    BidId         BIGINT NULL,
    AmountETH     DECIMAL(38,18) NOT NULL,
    StateCode     VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE | RELEASED | CAPTURED
    StatusDomain  AS CONVERT(VARCHAR(50), 'FUNDS_RESERVATION') PERSISTED,
    CreatedAtUtc  DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc  DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_FRes_User    FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_FRes_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_FRes_Bid     FOREIGN KEY (BidId) REFERENCES auction.Bid(BidId),
    CONSTRAINT CK_FRes_Positive CHECK (AmountETH > 0)
);
GO
CREATE TABLE finance.Ledger (
    EntryId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId        BIGINT NOT NULL,
    AuctionId     BIGINT NOT NULL,
    EntryType     VARCHAR(10) NOT NULL, -- CREDIT | DEBIT
    AmountETH     DECIMAL(38,18) NOT NULL,
    [Description] NVARCHAR(200) NULL,
    CreatedAtUtc  DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Ledger_User   FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_Ledger_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT CK_Ledger_Type CHECK (EntryType IN ('CREDIT','DEBIT')),
    CONSTRAINT CK_Ledger_Positive CHECK (AmountETH > 0)
);
GO

-- =====================================================================================
-- audit
-- =====================================================================================
CREATE TABLE audit.EmailOutbox (
    EmailId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    RecipientUserId BIGINT NULL,
    RecipientEmail  NVARCHAR(100) NULL,
    [Subject]       NVARCHAR(200) NOT NULL,
    Body            NVARCHAR(MAX) NOT NULL,
    StatusCode      VARCHAR(30) NOT NULL DEFAULT 'PENDING', -- PENDING | SENT | FAILED
    StatusDomain    AS CONVERT(VARCHAR(50), 'EMAIL_OUTBOX') PERSISTED,
    CreatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    SentAtUtc       DATETIME2(3) NULL,
    CorrelationKey  NVARCHAR(100) NULL,
    CONSTRAINT FK_EmailOutbox_User FOREIGN KEY (RecipientUserId) REFERENCES core.[User](UserId)
);
GO

-- =====================================================================================
-- ops
-- =====================================================================================
CREATE TABLE ops.Status (
    StatusId INT IDENTITY(1,1) PRIMARY KEY,
    Domain   VARCHAR(50) NOT NULL,
    Code     VARCHAR(30) NOT NULL,
    [Description] NVARCHAR(200) NULL,
    CONSTRAINT UQ_Status_Domain_Code UNIQUE (Domain, Code)
);
GO
CREATE TABLE ops.Settings (
    SettingKey   SYSNAME PRIMARY KEY,
    SettingValue NVARCHAR(200) NOT NULL,
    UpdatedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- =====================================================================================
-- FKs a ops.Status
-- =====================================================================================
ALTER TABLE core.UserEmail
  ADD CONSTRAINT FK_UserEmail_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.Status(Domain, Code);
ALTER TABLE nft.NFT
  ADD CONSTRAINT FK_NFT_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.Status(Domain, Code);
ALTER TABLE admin.CurationReview
  ADD CONSTRAINT FK_CReview_Status FOREIGN KEY (StatusDomain, DecisionCode) REFERENCES ops.Status(Domain, Code);
ALTER TABLE auction.Auction
  ADD CONSTRAINT FK_Auction_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.Status(Domain, Code);
ALTER TABLE finance.FundsReservation
  ADD CONSTRAINT FK_FRes_Status FOREIGN KEY (StatusDomain, StateCode) REFERENCES ops.Status(Domain, Code);
ALTER TABLE audit.EmailOutbox
  ADD CONSTRAINT FK_EmailOutbox_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.Status(Domain, Code);
GO

-- =====================================================================================
-- DATOS INICIALES
-- =====================================================================================
SET IDENTITY_INSERT core.Role ON;
INSERT INTO core.Role (RoleId,[Name]) VALUES (1,'ADMIN'),(2,'ARTIST'),(3,'CURATOR'),(4,'BIDDER');
SET IDENTITY_INSERT core.Role OFF;
GO

INSERT INTO ops.Status (Domain, Code, [Description]) VALUES
('NFT','PENDING','NFT pendiente de aprobación'),
('NFT','APPROVED','NFT aprobado y listo para subasta'),
('NFT','REJECTED','NFT rechazado por curador'),
('CURATION_DECISION','PENDING','Pendiente de revisión por curador'),
('CURATION_DECISION','APPROVED','Aprobado por curador'),
('CURATION_DECISION','REJECTED','Rechazado por curador'),
('AUCTION','ACTIVE','Subasta activa'),
('AUCTION','COMPLETED','Subasta completada'),
('AUCTION','CANCELLED','Subasta cancelada'),
('EMAIL_OUTBOX','PENDING','Email pendiente de envío'),
('EMAIL_OUTBOX','SENT','Email enviado'),
('EMAIL_OUTBOX','FAILED','Fallo al enviar email'),
('USER_EMAIL','ACTIVE','Email activo'),
('USER_EMAIL','INACTIVE','Email inactivo'),
('FUNDS_RESERVATION','ACTIVE','Reserva activa'),
('FUNDS_RESERVATION','RELEASED','Fondos liberados'),
('FUNDS_RESERVATION','CAPTURED','Fondos capturados');
GO

INSERT INTO nft.NFTSettings (SettingsID, MaxWidthPx, MinWidthPx, MaxHeightPx, MinHeigntPx, MaxFileSizeBytes, MinFileSizeBytes, CreatedAtUtc)
VALUES (1, 4096, 512, 4096, 512, 10485760, 10240, SYSUTCDATETIME());
GO

INSERT INTO auction.AuctionSettings (SettingsID, CompanyName, BasePriceETH, DefaultAuctionHours, MinBidIncrementPct)
VALUES (1, 'ArteCryptoAuctions', 0.01, 72, 5);
GO

-- =====================================================================================
-- ÍNDICES
-- =====================================================================================
CREATE INDEX IX_NFT_ArtistId ON nft.NFT(ArtistId);
CREATE INDEX IX_NFT_StatusCode ON nft.NFT(StatusCode);
CREATE INDEX IX_Auction_NFTId ON auction.Auction(NFTId);
CREATE INDEX IX_Auction_StatusCode ON auction.Auction(StatusCode);
CREATE INDEX IX_Bid_AuctionId ON auction.Bid(AuctionId);
CREATE INDEX IX_Bid_BidderId ON auction.Bid(BidderId);
CREATE INDEX IX_CurationReview_NFTId ON admin.CurationReview(NFTId);
CREATE INDEX IX_CurationReview_CuratorId ON admin.CurationReview(CuratorId);
GO

-- =====================================================================================
-- v7: STORED PROCEDURES (NFT submit, email failures, bids) + TRIGGER
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

CREATE OR ALTER TRIGGER audit.tr_EmailOutbox_Failed_Aggregator
ON audit.EmailOutbox
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE StatusCode='FAILED')
        EXEC audit.sp_NotifyEmailFailures;
END;
GO

-- =====================================================================================
-- v7: Sistema de Ofertas (Fase 3) - PlaceBid
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
        FROM auction.Auction WITH (UPDLOCK, ROWLOCK)
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

-- =====================================================================================
-- RESUMEN
-- =====================================================================================
PRINT '';
PRINT '=====================================================================================';
PRINT 'DDL v7 - CREACIÓN COMPLETADA EXITOSAMENTE';
PRINT '=====================================================================================';
PRINT 'Incluye: v6.1 + sistema de ofertas (reservas, liberación líder anterior, emails).';
PRINT 'Trigger consolidación de fallos de email (umbral >= 3) activo.';
PRINT '=====================================================================================';
GO
