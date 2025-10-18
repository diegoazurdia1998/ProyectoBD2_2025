USE [master]
GO
DROP DATABASE ArteCryptoAuctions
GO

-- =====================================================================================
-- DDL v6 - ArteCryptoAuctions (Versión Simplificada)
-- Sistema de Subastas de NFTs
-- Fecha: 2025-01-05
-- =====================================================================================

CREATE DATABASE ArteCryptoAuctions;
GO

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- CREACIÓN DE ESQUEMAS
-- =====================================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'admin')
    EXEC('CREATE SCHEMA admin');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'auction')
    EXEC('CREATE SCHEMA auction');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
    EXEC('CREATE SCHEMA audit');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
    EXEC('CREATE SCHEMA core');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'finance')
    EXEC('CREATE SCHEMA finance');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'nft')
    EXEC('CREATE SCHEMA nft');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')
    EXEC('CREATE SCHEMA ops');
GO

PRINT 'Esquemas creados correctamente';
GO

-- =====================================================================================
-- ESQUEMA: core (Usuarios, Roles, Wallets)
-- =====================================================================================

-- Tabla: core.User
CREATE TABLE core.[User] (
    UserId          BIGINT IDENTITY(1,1) PRIMARY KEY,
    FullName        NVARCHAR(100) NOT NULL,
    CreatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Tabla: core.Role
CREATE TABLE core.Role (
    RoleId          BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Name]          NVARCHAR(100) NOT NULL UNIQUE
);
GO

-- Tabla: core.UserRole (Relación muchos a muchos)
CREATE TABLE core.UserRole (
    UserId          BIGINT NOT NULL,
    RoleId          BIGINT NOT NULL,
    AsignacionUtc   DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT PK_UserRole PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_UserRole_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_UserRole_Role FOREIGN KEY (RoleId) REFERENCES core.Role(RoleId)
);
GO

-- Tabla: core.UserEmail
CREATE TABLE core.UserEmail (
    EmailId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId          BIGINT NOT NULL,
    Email           NVARCHAR(100) NOT NULL UNIQUE,
    IsPrimary       BIT NOT NULL DEFAULT 0,
    AddedAtUtc      DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    VerifiedAtUtc   DATETIME2(3) NULL,
    StatusCode      VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    StatusDomain    AS CONVERT(VARCHAR(50), 'USER_EMAIL') PERSISTED,
    
    CONSTRAINT FK_UserEmail_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId)
);
GO

-- Tabla: core.Wallet
CREATE TABLE core.Wallet (
    WalletId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId          BIGINT NOT NULL UNIQUE,
    BalanceETH      DECIMAL(38,18) NOT NULL DEFAULT 0,
    ReservedETH     DECIMAL(38,18) NOT NULL DEFAULT 0,
    UpdatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_Wallet_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_Wallet_Positive CHECK (BalanceETH >= 0 AND ReservedETH >= 0)
);
GO

PRINT 'Esquema CORE creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: nft (NFTs y Configuración)
-- =====================================================================================

-- Tabla: nft.NFTSettings
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

-- Tabla: nft.NFT
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

PRINT 'Esquema NFT creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: admin (Curación de NFTs)
-- =====================================================================================

-- Tabla: admin.CurationReview
CREATE TABLE admin.CurationReview (
    ReviewId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    NFTId           BIGINT NOT NULL,
    CuratorId       BIGINT NOT NULL,
    DecisionCode    VARCHAR(30) NOT NULL,
    StatusDomain    AS CONVERT(VARCHAR(50), 'CURATION_DECISION') PERSISTED,
    Comment         NVARCHAR(MAX) NULL,
    StartedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ReviewedAtUtc   DATETIME2(3) NULL,
    
    CONSTRAINT FK_CReview_NFT FOREIGN KEY (NFTId) REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_CReview_Curator FOREIGN KEY (CuratorId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_CReview_Times CHECK (ReviewedAtUtc IS NULL OR ReviewedAtUtc >= StartedAtUtc)
);
GO

PRINT 'Esquema ADMIN creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: auction (Subastas y Ofertas)
-- =====================================================================================

-- Tabla: auction.AuctionSettings
CREATE TABLE auction.AuctionSettings (
    SettingsID              INT PRIMARY KEY,
    CompanyName             NVARCHAR(250) NOT NULL,
    BasePriceETH            DECIMAL(38,18) NOT NULL,
    DefaultAuctionHours     TINYINT NOT NULL,
    MinBidIncrementPct      TINYINT NOT NULL
);
GO

-- Tabla: auction.Auction
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
    
    CONSTRAINT FK_Auction_NFT FOREIGN KEY (NFTId) REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_Auction_Leader FOREIGN KEY (CurrentLeaderId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_Auction_Settings FOREIGN KEY (SettingsID) REFERENCES auction.AuctionSettings(SettingsID),
    CONSTRAINT CK_Auction_Dates CHECK (EndAtUtc > StartAtUtc),
    CONSTRAINT CK_Auction_Prices CHECK (StartingPriceETH > 0 AND CurrentPriceETH >= StartingPriceETH)
);
GO

-- Tabla: auction.Bid
CREATE TABLE auction.Bid (
    BidId           BIGINT IDENTITY(1,1) PRIMARY KEY,
    AuctionId       BIGINT NOT NULL,
    BidderId        BIGINT NOT NULL,
    AmountETH       DECIMAL(38,18) NOT NULL,
    PlacedAtUtc     DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_Bid_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_Bid_User FOREIGN KEY (BidderId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_Bid_Positive CHECK (AmountETH > 0)
);
GO

PRINT 'Esquema AUCTION creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: finance (Finanzas y Transacciones)
-- =====================================================================================

-- Tabla: finance.FundsReservation
CREATE TABLE finance.FundsReservation (
    ReservationId   BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId          BIGINT NOT NULL,
    AuctionId       BIGINT NOT NULL,
    BidId           BIGINT NULL,
    AmountETH       DECIMAL(38,18) NOT NULL,
    StateCode       VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    StatusDomain    AS CONVERT(VARCHAR(50), 'FUNDS_RESERVATION') PERSISTED,
    CreatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_FRes_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_FRes_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_FRes_Bid FOREIGN KEY (BidId) REFERENCES auction.Bid(BidId),
    CONSTRAINT CK_FRes_Positive CHECK (AmountETH > 0)
);
GO

-- Tabla: finance.Ledger
CREATE TABLE finance.Ledger (
    EntryId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId          BIGINT NOT NULL,
    AuctionId       BIGINT NOT NULL,
    EntryType       VARCHAR(10) NOT NULL,
    AmountETH       DECIMAL(38,18) NOT NULL,
    [Description]   NVARCHAR(200) NULL,
    CreatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_Ledger_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_Ledger_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT CK_Ledger_Type CHECK (EntryType IN ('CREDIT', 'DEBIT')),
    CONSTRAINT CK_Ledger_Positive CHECK (AmountETH > 0)
);
GO

PRINT 'Esquema FINANCE creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: audit (Auditoría y Notificaciones)
-- =====================================================================================

-- Tabla: audit.EmailOutbox
CREATE TABLE audit.EmailOutbox (
    EmailId             BIGINT IDENTITY(1,1) PRIMARY KEY,
    RecipientUserId     BIGINT NULL,
    RecipientEmail      NVARCHAR(100) NULL,
    [Subject]           NVARCHAR(200) NOT NULL,
    Body                NVARCHAR(MAX) NOT NULL,
    StatusCode          VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    StatusDomain        AS CONVERT(VARCHAR(50), 'EMAIL_OUTBOX') PERSISTED,
    CreatedAtUtc        DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    SentAtUtc           DATETIME2(3) NULL,
    CorrelationKey      NVARCHAR(100) NULL,
    
    CONSTRAINT FK_EmailOutbox_User FOREIGN KEY (RecipientUserId) REFERENCES core.[User](UserId)
);
GO

PRINT 'Esquema AUDIT creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: ops (Operaciones y Configuración del Sistema)
-- =====================================================================================

-- Tabla: ops.Status
CREATE TABLE ops.Status (
    StatusId        INT IDENTITY(1,1) PRIMARY KEY,
    Domain          VARCHAR(50) NOT NULL,
    Code            VARCHAR(30) NOT NULL,
    [Description]   NVARCHAR(200) NULL,
    
    CONSTRAINT UQ_Status_Domain_Code UNIQUE (Domain, Code)
);
GO

-- Tabla: ops.Settings
CREATE TABLE ops.Settings (
    SettingKey      SYSNAME PRIMARY KEY,
    SettingValue    NVARCHAR(200) NOT NULL,
    UpdatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

PRINT 'Esquema OPS creado correctamente';
GO

-- =====================================================================================
-- FOREIGN KEYS ADICIONALES (Referencias a ops.Status)
-- =====================================================================================

-- Agregar FKs a ops.Status después de que la tabla exista
ALTER TABLE core.UserEmail
    ADD CONSTRAINT FK_UserEmail_Status 
    FOREIGN KEY (StatusDomain, StatusCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE nft.NFT
    ADD CONSTRAINT FK_NFT_Status 
    FOREIGN KEY (StatusDomain, StatusCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE admin.CurationReview
    ADD CONSTRAINT FK_CReview_Status 
    FOREIGN KEY (StatusDomain, DecisionCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE auction.Auction
    ADD CONSTRAINT FK_Auction_Status 
    FOREIGN KEY (StatusDomain, StatusCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE finance.FundsReservation
    ADD CONSTRAINT FK_FRes_Status 
    FOREIGN KEY (StatusDomain, StateCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE audit.EmailOutbox
    ADD CONSTRAINT FK_EmailOutbox_Status 
    FOREIGN KEY (StatusDomain, StatusCode) 
    REFERENCES ops.Status(Domain, Code);
GO

PRINT 'Foreign Keys a ops.Status creadas correctamente';
GO

-- =====================================================================================
-- DATOS INICIALES
-- =====================================================================================

-- Insertar roles básicos
SET IDENTITY_INSERT core.Role ON;
INSERT INTO core.Role (RoleId, [Name]) VALUES
    (1, 'ADMIN'),
    (2, 'ARTIST'),
    (3, 'CURATOR'),
    (4, 'BIDDER');
SET IDENTITY_INSERT core.Role OFF;
GO

-- Insertar estados del sistema
INSERT INTO ops.Status (Domain, Code, [Description]) VALUES
    -- Estados de NFT
    ('NFT', 'PENDING', 'NFT pendiente de aprobación'),
    ('NFT', 'APPROVED', 'NFT aprobado y listo para subasta'),
    ('NFT', 'REJECTED', 'NFT rechazado por curador'),
    
    -- Estados de Curación
    ('CURATION_DECISION', 'PENDING', 'Pendiente de revisión por curador'),
    ('CURATION_DECISION', 'APPROVED', 'Aprobado por curador'),
    ('CURATION_DECISION', 'REJECTED', 'Rechazado por curador'),
    
    -- Estados de Subasta
    ('AUCTION', 'ACTIVE', 'Subasta activa'),
    ('AUCTION', 'COMPLETED', 'Subasta completada'),
    ('AUCTION', 'CANCELLED', 'Subasta cancelada'),
    
    -- Estados de Email
    ('EMAIL_OUTBOX', 'PENDING', 'Email pendiente de envío'),
    ('EMAIL_OUTBOX', 'SENT', 'Email enviado'),
    ('EMAIL_OUTBOX', 'FAILED', 'Fallo al enviar email'),
    
    -- Estados de UserEmail
    ('USER_EMAIL', 'ACTIVE', 'Email activo'),
    ('USER_EMAIL', 'INACTIVE', 'Email inactivo'),
    
    -- Estados de Reserva de Fondos
    ('FUNDS_RESERVATION', 'ACTIVE', 'Reserva activa'),
    ('FUNDS_RESERVATION', 'RELEASED', 'Fondos liberados'),
    ('FUNDS_RESERVATION', 'CAPTURED', 'Fondos capturados');
GO

-- Configuración inicial de NFT
INSERT INTO nft.NFTSettings (SettingsID, MaxWidthPx, MinWidthPx, MaxHeightPx, MinHeigntPx, MaxFileSizeBytes, MinFileSizeBytes, CreatedAtUtc)
VALUES (1, 4096, 512, 4096, 512, 10485760, 10240, SYSUTCDATETIME());
GO

-- Configuración inicial de Subasta
INSERT INTO auction.AuctionSettings (SettingsID, CompanyName, BasePriceETH, DefaultAuctionHours, MinBidIncrementPct)
VALUES (1, 'ArteCryptoAuctions', 0.01, 72, 5);
GO

PRINT 'Datos iniciales insertados correctamente';
GO

-- =====================================================================================
-- ÍNDICES ADICIONALES (Opcional - para mejorar rendimiento)
-- =====================================================================================

-- Índices en tablas más consultadas
CREATE INDEX IX_NFT_ArtistId ON nft.NFT(ArtistId);
CREATE INDEX IX_NFT_StatusCode ON nft.NFT(StatusCode);
CREATE INDEX IX_Auction_NFTId ON auction.Auction(NFTId);
CREATE INDEX IX_Auction_StatusCode ON auction.Auction(StatusCode);
CREATE INDEX IX_Bid_AuctionId ON auction.Bid(AuctionId);
CREATE INDEX IX_Bid_BidderId ON auction.Bid(BidderId);
CREATE INDEX IX_CurationReview_NFTId ON admin.CurationReview(NFTId);
CREATE INDEX IX_CurationReview_CuratorId ON admin.CurationReview(CuratorId);
GO

PRINT 'Índices creados correctamente';
GO

-- =====================================================================================
-- RESUMEN
-- =====================================================================================

PRINT '';
PRINT '=====================================================================================';
PRINT 'DDL v6 - CREACIÓN COMPLETADA EXITOSAMENTE';
PRINT '=====================================================================================';
PRINT '';
PRINT 'Esquemas creados:';
PRINT 'core     - Usuarios, Roles, Wallets';
PRINT 'nft      - NFTs y Configuración';
PRINT 'admin    - Curación de NFTs';
PRINT 'auction  - Subastas y Ofertas';
PRINT 'finance  - Finanzas y Transacciones';
PRINT 'audit    - Auditoría y Notificaciones';
PRINT 'ops      - Operaciones y Configuración';
PRINT '';
PRINT 'Tablas creadas: 16';
PRINT 'Roles iniciales: 4 (ADMIN, ARTIST, CURATOR, BIDDER)';
PRINT 'Estados del sistema: 15';
PRINT '';
PRINT 'Base de datos lista para usar.';
PRINT '=====================================================================================';
GO

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

-- PROCEDURES

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

-- TRIGGERS

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

use ArteCryptoAuctions
go

-- =====================================================================================
-- TRIGGER 1: Inserción de NFT con validaciones y asignación de curador
-- =====================================================================================
CREATE OR ALTER TRIGGER nft.tr_NFT_InsertFlow
ON nft.NFT
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Variables de control
        DECLARE @ErrorMsg NVARCHAR(MAX);
        DECLARE @CuratorCount INT;
        
        -------------------------------------------------------------------
        -- 0) Normalizar batch a tabla temporal
        -------------------------------------------------------------------
        DECLARE @InputNFT TABLE(
            RowNum           INT IDENTITY(1,1),
            ArtistId         BIGINT NOT NULL,
            SettingsID       INT NOT NULL,
            CurrentOwnerId   BIGINT NULL,
            [Name]           NVARCHAR(160) NOT NULL,
            [Description]    NVARCHAR(MAX) NULL,
            ContentType      NVARCHAR(100) NOT NULL,
            FileSizeBytes    BIGINT NULL,
            WidthPx          INT NULL,
            HeightPx         INT NULL,
            SuggestedPriceETH DECIMAL(38,18) NULL,
            StatusCode       VARCHAR(30) NOT NULL,
            CreatedAtUtc     DATETIME2(3) NOT NULL
        );

        INSERT INTO @InputNFT
        SELECT 
            i.ArtistId, i.SettingsID, i.CurrentOwnerId,
            i.[Name], i.[Description], i.ContentType,
            i.FileSizeBytes, i.WidthPx, i.HeightPx, 
            i.SuggestedPriceETH, i.StatusCode, i.CreatedAtUtc
        FROM inserted i;

        -------------------------------------------------------------------
        -- 1) Validación: Usuario debe tener rol ARTIST (RoleId = 2)
        -------------------------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM @InputNFT x
            LEFT JOIN core.UserRole ur ON ur.UserId = x.ArtistId AND ur.RoleId = 2
            WHERE ur.UserId IS NULL
        )
        BEGIN
            -- Notificar a usuarios sin rol de artista
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                x.ArtistId,
                (SELECT TOP 1 ue.Email 
                 FROM core.UserEmail ue 
                 WHERE ue.UserId = x.ArtistId AND ue.IsPrimary = 1 
                 ORDER BY ue.EmailId),
                N'NFT Rechazado - Rol Inválido',
                N'Su NFT "' + x.[Name] + N'" no pudo ser aceptado. Razón: El usuario no posee el rol de Artista. Por favor, contacte al administrador para obtener los permisos necesarios.',
                'PENDING'
            FROM @InputNFT x
            LEFT JOIN core.UserRole ur ON ur.UserId = x.ArtistId AND ur.RoleId = 2
            WHERE ur.UserId IS NULL;
            
            RETURN; -- No insertar NFTs
        END;

        -------------------------------------------------------------------
        -- 2) Validación: Email primario debe existir
        -------------------------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM @InputNFT x
            LEFT JOIN core.UserEmail ue ON ue.UserId = x.ArtistId AND ue.IsPrimary = 1
            WHERE ue.EmailId IS NULL
        )
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                x.ArtistId,
                NULL,
                N'NFT Rechazado - Email Requerido',
                N'Su NFT "' + x.[Name] + N'" no pudo ser aceptado. Razón: No tiene un email primario configurado. Por favor, configure un email primario en su perfil.',
                'PENDING'
            FROM @InputNFT x
            LEFT JOIN core.UserEmail ue ON ue.UserId = x.ArtistId AND ue.IsPrimary = 1
            WHERE ue.EmailId IS NULL;
            
            RETURN;
        END;

        -------------------------------------------------------------------
        -- 3) Validaciones técnicas contra NFTSettings
        -------------------------------------------------------------------
        DECLARE @ValidationResults TABLE(
            RowNum INT,
            ArtistId BIGINT,
            [Name] NVARCHAR(160),
            SettingsID INT,
            WidthPx INT,
            HeightPx INT,
            FileSizeBytes BIGINT,
            MinWidthPx BIGINT,
            MaxWidthPx BIGINT,
            MinHeightPx BIGINT,
            MaxHeightPx BIGINT,
            MinFileSizeBytes BIGINT,
            MaxFileSizeBytes BIGINT,
            SettingsExists BIT,
            ValidationError NVARCHAR(500)
        );

        INSERT INTO @ValidationResults
        SELECT 
            x.RowNum,
            x.ArtistId,
            x.[Name],
            x.SettingsID,
            x.WidthPx,
            x.HeightPx,
            x.FileSizeBytes,
            s.MinWidthPx,
            s.MaxWidthPx,
            s.MinHeigntPx,
            s.MaxHeightPx,
            s.MinFileSizeBytes,
            s.MaxFileSizeBytes,
            CASE WHEN s.SettingsID IS NULL THEN 0 ELSE 1 END,
            CASE 
                WHEN s.SettingsID IS NULL THEN N'Configuración de NFT inexistente'
                WHEN x.WidthPx IS NULL AND s.MinWidthPx IS NOT NULL THEN N'Ancho (WidthPx) es requerido'
                WHEN x.WidthPx < s.MinWidthPx THEN N'Ancho menor al mínimo permitido (' + CAST(s.MinWidthPx AS NVARCHAR) + N'px)'
                WHEN x.WidthPx > s.MaxWidthPx THEN N'Ancho mayor al máximo permitido (' + CAST(s.MaxWidthPx AS NVARCHAR) + N'px)'
                WHEN x.HeightPx IS NULL AND s.MinHeigntPx IS NOT NULL THEN N'Alto (HeightPx) es requerido'
                WHEN x.HeightPx < s.MinHeigntPx THEN N'Alto menor al mínimo permitido (' + CAST(s.MinHeigntPx AS NVARCHAR) + N'px)'
                WHEN x.HeightPx > s.MaxHeightPx THEN N'Alto mayor al máximo permitido (' + CAST(s.MaxHeightPx AS NVARCHAR) + N'px)'
                WHEN x.FileSizeBytes IS NULL AND s.MinFileSizeBytes IS NOT NULL THEN N'Tamaño de archivo es requerido'
                WHEN x.FileSizeBytes < s.MinFileSizeBytes THEN N'Archivo muy pequeño (mínimo: ' + CAST(s.MinFileSizeBytes AS NVARCHAR) + N' bytes)'
                WHEN x.FileSizeBytes > s.MaxFileSizeBytes THEN N'Archivo muy grande (máximo: ' + CAST(s.MaxFileSizeBytes AS NVARCHAR) + N' bytes)'
                ELSE NULL
            END
        FROM @InputNFT x
        LEFT JOIN nft.NFTSettings s ON s.SettingsID = x.SettingsID;

        -- Si hay errores de validación, notificar y salir
        IF EXISTS (SELECT 1 FROM @ValidationResults WHERE ValidationError IS NOT NULL)
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                v.ArtistId,
                (SELECT TOP 1 ue.Email 
                 FROM core.UserEmail ue 
                 WHERE ue.UserId = v.ArtistId AND ue.IsPrimary = 1 
                 ORDER BY ue.EmailId),
                N'NFT Rechazado - Validación Técnica',
                N'Su NFT "' + v.[Name] + N'" no pudo ser aceptado. Razón: ' + v.ValidationError + N'. Por favor, corrija el archivo y vuelva a intentarlo.',
                'PENDING'
            FROM @ValidationResults v
            WHERE v.ValidationError IS NOT NULL;
            
            RETURN;
        END;

        -------------------------------------------------------------------
        -- 4) Verificar que existan curadores disponibles
        -------------------------------------------------------------------
        SELECT @CuratorCount = COUNT(DISTINCT ur.UserId)
        FROM core.UserRole ur
        WHERE ur.RoleId = 3; -- Rol CURATOR

        IF @CuratorCount = 0
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                x.ArtistId,
                (SELECT TOP 1 ue.Email 
                 FROM core.UserEmail ue 
                 WHERE ue.UserId = x.ArtistId AND ue.IsPrimary = 1 
                 ORDER BY ue.EmailId),
                N'NFT en Espera - Sin Curadores',
                N'Su NFT "' + x.[Name] + N'" ha sido aceptado pero actualmente no hay curadores disponibles. Será asignado automáticamente cuando haya un curador disponible.',
                'PENDING'
            FROM @InputNFT x;
            
            RETURN;
        END;

        -------------------------------------------------------------------
        -- 5) Asegurar que existe el estado PENDING en ops.Status
        -------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'CURATION_DECISION' AND Code = 'PENDING')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('CURATION_DECISION', 'PENDING', N'Pendiente de revisión por curador');
        END;

        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'PENDING')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('NFT', 'PENDING', N'NFT pendiente de aprobación');
        END;

        -------------------------------------------------------------------
        -- 6) INSERTAR NFTs válidos con HashCode autogenerado
        -------------------------------------------------------------------
        DECLARE @NewNFTs TABLE(
            NFTId BIGINT,
            ArtistId BIGINT,
            [Name] NVARCHAR(160)
        );

        -- Insertar NFTs y capturar IDs
        INSERT INTO nft.NFT(
            ArtistId, SettingsID, CurrentOwnerId, [Name], [Description],
            ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx,
            SuggestedPriceETH, StatusCode, CreatedAtUtc
        )
        OUTPUT 
            inserted.NFTId, 
            inserted.ArtistId, 
            inserted.[Name]
        INTO @NewNFTs(NFTId, ArtistId, [Name])
        SELECT
            x.ArtistId,
            x.SettingsID,
            x.CurrentOwnerId,
            x.[Name],
            x.[Description],
            x.ContentType,
            -- HashCode autogenerado con SHA2_256
            LEFT(
                CONVERT(VARCHAR(64),
                    HASHBYTES('SHA2_256',
                        CAST(NEWID() AS VARBINARY(16))
                        + CAST(x.ArtistId AS VARBINARY(8))
                        + CAST(SYSUTCDATETIME() AS VARBINARY(16))
                        + CRYPT_GEN_RANDOM(16)
                    ), 2
                ),
                64
            ),
            x.FileSizeBytes,
            x.WidthPx,
            x.HeightPx,
            x.SuggestedPriceETH,
            'PENDING', -- Estado inicial
            x.CreatedAtUtc
        FROM @InputNFT x;

        -- Agregar RowNum después del INSERT
        DECLARE @NewNFTsWithRow TABLE(
            NFTId BIGINT,
            ArtistId BIGINT,
            [Name] NVARCHAR(160),
            RowNum INT
        );

        INSERT INTO @NewNFTsWithRow
        SELECT 
            n.NFTId,
            n.ArtistId,
            n.[Name],
            x.RowNum
        FROM @NewNFTs n
        JOIN @InputNFT x ON x.ArtistId = n.ArtistId AND x.[Name] = n.[Name];

        -------------------------------------------------------------------
        -- 7) Asignación Round-Robin de curadores
        -------------------------------------------------------------------
        DECLARE @Curators TABLE(
            Idx INT IDENTITY(1,1),
            CuratorId BIGINT
        );

        INSERT INTO @Curators(CuratorId)
        SELECT DISTINCT ur.UserId
        FROM core.UserRole ur
        WHERE ur.RoleId = 3
        ORDER BY ur.UserId;

        -- Obtener posición actual del round-robin
        DECLARE @CurrentPos INT;
        
        SELECT @CurrentPos = TRY_CAST(SettingValue AS INT)
        FROM ops.Settings WITH (UPDLOCK, HOLDLOCK)
        WHERE SettingKey = 'CURATION_RR_POS';

        IF @CurrentPos IS NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM ops.Settings WHERE SettingKey = 'CURATION_RR_POS')
                UPDATE ops.Settings 
                SET SettingValue = '0', UpdatedAtUtc = SYSUTCDATETIME() 
                WHERE SettingKey = 'CURATION_RR_POS';
            ELSE
                INSERT INTO ops.Settings(SettingKey, SettingValue)
                VALUES('CURATION_RR_POS', '0');
            
            SET @CurrentPos = 0;
        END;

        -- Asignar curadores usando round-robin
        DECLARE @Assignments TABLE(
            NFTId BIGINT,
            ArtistId BIGINT,
            [Name] NVARCHAR(160),
            CuratorIdx INT,
            CuratorId BIGINT
        );

        ;WITH AssignmentCTE AS (
            SELECT 
                n.NFTId,
                n.ArtistId,
                n.[Name],
                ((@CurrentPos + n.RowNum - 1) % @CuratorCount) + 1 AS CuratorIdx
            FROM @NewNFTsWithRow n
        )
        INSERT INTO @Assignments(NFTId, ArtistId, [Name], CuratorIdx, CuratorId)
        SELECT 
            a.NFTId,
            a.ArtistId,
            a.[Name],
            a.CuratorIdx,
            c.CuratorId
        FROM AssignmentCTE a
        JOIN @Curators c ON c.Idx = a.CuratorIdx;

        -------------------------------------------------------------------
        -- 8) Crear registros de CurationReview
        -------------------------------------------------------------------
        INSERT INTO admin.CurationReview(NFTId, CuratorId, DecisionCode, StartedAtUtc)
        SELECT 
            a.NFTId,
            a.CuratorId,
            'PENDING',
            SYSUTCDATETIME()
        FROM @Assignments a;

        -------------------------------------------------------------------
        -- 9) Notificar a artistas (NFT aceptado y en revisión)
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            n.ArtistId,
            ue.Email,
            N'NFT Aceptado - En Revisión',
            N'¡Felicidades! Su NFT "' + n.[Name] + N'" ha sido aceptado por el sistema y ha sido enviado a curación. Un curador revisará su obra pronto y recibirá una notificación con la decisión.',
            'PENDING'
        FROM @NewNFTs n
        JOIN core.UserEmail ue ON ue.UserId = n.ArtistId AND ue.IsPrimary = 1;

        -------------------------------------------------------------------
        -- 10) Notificar a curadores asignados
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            a.CuratorId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = a.CuratorId AND ue.IsPrimary = 1 
             ORDER BY ue.EmailId),
            N'Nuevo NFT para Revisión',
            N'Se le ha asignado un nuevo NFT para revisión:' + CHAR(13) + CHAR(10) +
            N'- NFT ID: ' + CAST(a.NFTId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'- Nombre: "' + a.[Name] + N'"' + CHAR(13) + CHAR(10) +
            N'- Artista ID: ' + CAST(a.ArtistId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'Por favor, revise el NFT y tome una decisión (APPROVED/REJECTED).',
            'PENDING'
        FROM @Assignments a;

        -------------------------------------------------------------------
        -- 11) Actualizar posición del round-robin
        -------------------------------------------------------------------
        DECLARE @NFTCount INT = (SELECT COUNT(*) FROM @NewNFTs);
        
        UPDATE ops.Settings
        SET 
            SettingValue = CAST(((@CurrentPos + @NFTCount) % @CuratorCount) AS NVARCHAR(50)),
            UpdatedAtUtc = SYSUTCDATETIME()
        WHERE SettingKey = 'CURATION_RR_POS';

    END TRY
    BEGIN CATCH
        -- Manejo de errores
        SET @ErrorMsg = N'Error en tr_NFT_InsertFlow: ' + ERROR_MESSAGE();
        
        -- Log del error
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        VALUES(
            NULL,
            'admin@artecryptoauctions.com',
            N'Error en Sistema - Inserción NFT',
            @ErrorMsg,
            'PENDING'
        );
        
        -- Re-lanzar el error
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 2: Decisión del curador (APPROVED/REJECTED)
-- =====================================================================================
CREATE OR ALTER TRIGGER admin.tr_CurationReview_Decision
ON admin.CurationReview
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo procesar si se actualizó DecisionCode
    IF NOT UPDATE(DecisionCode)
        RETURN;
    
    BEGIN TRY
        DECLARE @ErrorMsg NVARCHAR(MAX);
        
        -- Tabla para procesar decisiones
        DECLARE @Decisions TABLE(
            ReviewId BIGINT,
            NFTId BIGINT,
            CuratorId BIGINT,
            ArtistId BIGINT,
            ArtistEmail NVARCHAR(100),
            NFTName NVARCHAR(160),
            DecisionCode VARCHAR(30),
            OldDecisionCode VARCHAR(30),
            ReviewedAtUtc DATETIME2(3)
        );

        -- Capturar solo las decisiones que cambiaron de PENDING a APPROVED/REJECTED
        INSERT INTO @Decisions
        SELECT 
            i.ReviewId,
            i.NFTId,
            i.CuratorId,
            nft.ArtistId,
            ue.Email,
            nft.[Name],
            i.DecisionCode,
            d.DecisionCode,
            i.ReviewedAtUtc
        FROM inserted i
        JOIN deleted d ON d.ReviewId = i.ReviewId
        JOIN nft.NFT nft ON nft.NFTId = i.NFTId
        JOIN core.UserEmail ue ON ue.UserId = nft.ArtistId AND ue.IsPrimary = 1
        WHERE i.DecisionCode IN ('APPROVED', 'REJECTED')
          AND d.DecisionCode = 'PENDING'
          AND i.DecisionCode <> d.DecisionCode;

        -- Si no hay decisiones nuevas, salir
        IF NOT EXISTS (SELECT 1 FROM @Decisions)
            RETURN;

        -------------------------------------------------------------------
        -- Asegurar que existen los estados necesarios
        -------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'APPROVED')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('NFT', 'APPROVED', N'NFT aprobado y listo para subasta');
        END;

        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'REJECTED')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('NFT', 'REJECTED', N'NFT rechazado por curador');
        END;

        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'AUCTION' AND Code = 'ACTIVE')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('AUCTION', 'ACTIVE', N'Subasta activa');
        END;

        -------------------------------------------------------------------
        -- Actualizar ReviewedAtUtc si es NULL
        -------------------------------------------------------------------
        UPDATE admin.CurationReview
        SET ReviewedAtUtc = SYSUTCDATETIME()
        WHERE ReviewId IN (SELECT ReviewId FROM @Decisions)
          AND ReviewedAtUtc IS NULL;

        -------------------------------------------------------------------
        -- Procesar NFTs APROBADOS
        -------------------------------------------------------------------
        -- Actualizar estado del NFT
        UPDATE nft.NFT
        SET 
            StatusCode = 'APPROVED',
            ApprovedAtUtc = SYSUTCDATETIME()
        WHERE NFTId IN (
            SELECT NFTId 
            FROM @Decisions 
            WHERE DecisionCode = 'APPROVED'
        );

        -- Notificar a artistas (APROBADO)
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            d.ArtistId,
            d.ArtistEmail,
            N'¡NFT Aprobado!',
            N'¡Excelentes noticias! Su NFT "' + d.NFTName + N'" ha sido aprobado por el curador.' + CHAR(13) + CHAR(10) +
            N'Su obra entrará automáticamente en subasta. Recibirá una notificación cuando la subasta esté activa.',
            'PENDING'
        FROM @Decisions d
        WHERE d.DecisionCode = 'APPROVED';

        -------------------------------------------------------------------
        -- Procesar NFTs RECHAZADOS
        -------------------------------------------------------------------
        -- Actualizar estado del NFT
        UPDATE nft.NFT
        SET StatusCode = 'REJECTED'
        WHERE NFTId IN (
            SELECT NFTId 
            FROM @Decisions 
            WHERE DecisionCode = 'REJECTED'
        );

        -- Notificar a artistas (RECHAZADO)
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            d.ArtistId,
            d.ArtistEmail,
            N'NFT No Aprobado',
            N'Lamentamos informarle que su NFT "' + d.NFTName + N'" no ha sido aprobado en esta ocasión.' + CHAR(13) + CHAR(10) +
            N'Le invitamos a revisar las políticas de contenido y volver a intentarlo con una nueva obra.',
            'PENDING'
        FROM @Decisions d
        WHERE d.DecisionCode = 'REJECTED';

        -------------------------------------------------------------------
        -- Notificar a curadores sobre su decisión procesada
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            d.CuratorId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = d.CuratorId AND ue.IsPrimary = 1 
             ORDER BY ue.EmailId),
            N'Decisión Procesada',
            N'Su decisión sobre el NFT "' + d.NFTName + N'" (ID: ' + CAST(d.NFTId AS NVARCHAR(20)) + N') ha sido procesada exitosamente.' + CHAR(13) + CHAR(10) +
            N'Decisión: ' + CASE d.DecisionCode WHEN 'APPROVED' THEN N'APROBADO' ELSE N'RECHAZADO' END,
            'PENDING'
        FROM @Decisions d;

    END TRY
    BEGIN CATCH
        SET @ErrorMsg = N'Error en tr_CurationReview_Decision: ' + ERROR_MESSAGE();
        
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        VALUES(
            NULL,
            'admin@artecryptoauctions.com',
            N'Error en Sistema - Decisión Curador',
            @ErrorMsg,
            'PENDING'
        );
        
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 3: Crear subasta automáticamente cuando NFT es aprobado
-- =====================================================================================
CREATE OR ALTER TRIGGER nft.tr_NFT_CreateAuction
ON nft.NFT
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo procesar si se actualizó StatusCode a APPROVED
    IF NOT UPDATE(StatusCode)
        RETURN;
    
    BEGIN TRY
        DECLARE @ErrorMsg NVARCHAR(MAX);
        
        -- Tabla para NFTs recién aprobados
        DECLARE @ApprovedNFTs TABLE(
            NFTId BIGINT,
            ArtistId BIGINT,
            ArtistEmail NVARCHAR(100),
            NFTName NVARCHAR(160),
            SuggestedPriceETH DECIMAL(38,18)
        );

        -- Capturar NFTs que cambiaron a APPROVED
        INSERT INTO @ApprovedNFTs
        SELECT 
            i.NFTId,
            i.ArtistId,
            ue.Email,
            i.[Name],
            i.SuggestedPriceETH
        FROM inserted i
        JOIN deleted d ON d.NFTId = i.NFTId
        JOIN core.UserEmail ue ON ue.UserId = i.ArtistId AND ue.IsPrimary = 1
        WHERE i.StatusCode = 'APPROVED'
          AND d.StatusCode <> 'APPROVED'
          AND i.ApprovedAtUtc IS NOT NULL;

        -- Si no hay NFTs aprobados, salir
        IF NOT EXISTS (SELECT 1 FROM @ApprovedNFTs)
            RETURN;

        -------------------------------------------------------------------
        -- Obtener configuración de subastas
        -------------------------------------------------------------------
        DECLARE @SettingsID INT;
        DECLARE @BasePriceETH DECIMAL(38,18);
        DECLARE @DefaultAuctionHours TINYINT;

        SELECT TOP 1
            @SettingsID = SettingsID,
            @BasePriceETH = BasePriceETH,
            @DefaultAuctionHours = DefaultAuctionHours
        FROM auction.AuctionSettings
        ORDER BY SettingsID;

        -- Si no hay configuración, usar valores por defecto
        IF @SettingsID IS NULL
        BEGIN
            SET @BasePriceETH = 0.01;
            SET @DefaultAuctionHours = 72;
        END;

        -------------------------------------------------------------------
        -- Crear subastas para cada NFT aprobado
        -------------------------------------------------------------------
        DECLARE @NewAuctions TABLE(
            AuctionId BIGINT,
            NFTId BIGINT,
            StartingPriceETH DECIMAL(38,18),
            StartAtUtc DATETIME2(3),
            EndAtUtc DATETIME2(3)
        );

        -- Insertar subastas
        INSERT INTO auction.Auction(
            SettingsID,
            NFTId,
            StartAtUtc,
            EndAtUtc,
            StartingPriceETH,
            CurrentPriceETH,
            StatusCode
        )
        OUTPUT 
            inserted.AuctionId,
            inserted.NFTId,
            inserted.StartingPriceETH,
            inserted.StartAtUtc,
            inserted.EndAtUtc
        INTO @NewAuctions
        SELECT 
            @SettingsID,
            a.NFTId,
            SYSUTCDATETIME(), -- Inicia inmediatamente
            DATEADD(HOUR, @DefaultAuctionHours, SYSUTCDATETIME()),
            COALESCE(a.SuggestedPriceETH, @BasePriceETH),
            COALESCE(a.SuggestedPriceETH, @BasePriceETH),
            'ACTIVE'
        FROM @ApprovedNFTs a
        WHERE NOT EXISTS (
            SELECT 1 
            FROM auction.Auction au 
            WHERE au.NFTId = a.NFTId
        ); -- Evitar duplicados

        -- Combinar datos para notificaciones
        DECLARE @AuctionsWithDetails TABLE(
            AuctionId BIGINT,
            NFTId BIGINT,
            ArtistId BIGINT,
            ArtistEmail NVARCHAR(100),
            NFTName NVARCHAR(160),
            StartingPriceETH DECIMAL(38,18),
            StartAtUtc DATETIME2(3),
            EndAtUtc DATETIME2(3)
        );

        INSERT INTO @AuctionsWithDetails
        SELECT 
            na.AuctionId,
            na.NFTId,
            an.ArtistId,
            an.ArtistEmail,
            an.NFTName,
            na.StartingPriceETH,
            na.StartAtUtc,
            na.EndAtUtc
        FROM @NewAuctions na
        JOIN @ApprovedNFTs an ON an.NFTId = na.NFTId;

        -------------------------------------------------------------------
        -- Notificar a artistas sobre subasta creada
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            na.ArtistId,
            na.ArtistEmail,
            N'¡Subasta Iniciada!',
            N'¡Su NFT "' + na.NFTName + N'" ya está en subasta!' + CHAR(13) + CHAR(10) +
            N'- ID de Subasta: ' + CAST(na.AuctionId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'- Precio Inicial: ' + CAST(na.StartingPriceETH AS NVARCHAR(50)) + N' ETH' + CHAR(13) + CHAR(10) +
            N'- Inicio: ' + CONVERT(NVARCHAR(30), na.StartAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'- Fin: ' + CONVERT(NVARCHAR(30), na.EndAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'¡Buena suerte con su subasta!',
            'PENDING'
        FROM @AuctionsWithDetails na;

        -------------------------------------------------------------------
        -- Notificar a todos los usuarios con rol BIDDER sobre nueva subasta
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT DISTINCT
            ur.UserId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = ur.UserId AND ue.IsPrimary = 1 
             ORDER BY ue.EmailId),
            N'Nueva Subasta Disponible',
            N'¡Nueva obra disponible para subasta!' + CHAR(13) + CHAR(10) +
            N'- NFT: "' + na.NFTName + N'"' + CHAR(13) + CHAR(10) +
            N'- Precio Inicial: ' + CAST(na.StartingPriceETH AS NVARCHAR(50)) + N' ETH' + CHAR(13) + CHAR(10) +
            N'- Finaliza: ' + CONVERT(NVARCHAR(30), na.EndAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'¡No pierda la oportunidad de participar!',
            'PENDING'
        FROM @AuctionsWithDetails na
        CROSS JOIN core.UserRole ur
        WHERE ur.RoleId = 4 -- Rol BIDDER
          AND EXISTS (
              SELECT 1 
              FROM core.UserEmail ue 
              WHERE ue.UserId = ur.UserId AND ue.IsPrimary = 1
          );

    END TRY
    BEGIN CATCH
        SET @ErrorMsg = N'Error en tr_NFT_CreateAuction: ' + ERROR_MESSAGE();
        
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        VALUES(
            NULL,
            'admin@artecryptoauctions.com',
            N'Error en Sistema - Creación de Subasta',
            @ErrorMsg,
            'PENDING'
        );
        
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 4: tr_EmailOutbox_Failed_Aggregator
-- Descripción: Usa funciones para validación de emails enviadoos con status 'FAILED'
-- =====================================================================================

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
-- TRIGGER 5: Finalización de subastas (VERSIÓN CORREGIDA Y COMPLETA)
-- =====================================================================================

USE ArteCryptoAuctions;
GO

CREATE OR ALTER TRIGGER auction.tr_Auction_ProcesarCompletada
ON auction.Auction
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(StatusCode) OR NOT EXISTS (SELECT 1 FROM inserted WHERE StatusCode = 'COMPLETED')
        RETURN;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Recopilar datos de las subastas recién completadas
        DECLARE @CompletedAuctions TABLE(
            AuctionId BIGINT PRIMARY KEY, NFTId BIGINT NOT NULL, ArtistId BIGINT NOT NULL,
            WinnerId BIGINT NULL, FinalPriceETH DECIMAL(38,18) NOT NULL
        );
        INSERT INTO @CompletedAuctions (AuctionId, NFTId, ArtistId, WinnerId, FinalPriceETH)
        SELECT i.AuctionId, i.NFTId, n.ArtistId, i.CurrentLeaderId, i.CurrentPriceETH
        FROM inserted i
        JOIN deleted d ON i.AuctionId = d.AuctionId
        JOIN nft.NFT n ON i.NFTId = n.NFTId
        WHERE i.StatusCode = 'COMPLETED' AND d.StatusCode <> 'COMPLETED';

        IF NOT EXISTS (SELECT 1 FROM @CompletedAuctions) RETURN;

        -- 2. Procesar a los GANADORES
        UPDATE w SET 
            BalanceETH = w.BalanceETH - ca.FinalPriceETH,
            ReservedETH = w.ReservedETH - ca.FinalPriceETH,
            UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN @CompletedAuctions ca ON w.UserId = ca.WinnerId
        WHERE ca.WinnerId IS NOT NULL;

        UPDATE n SET CurrentOwnerId = ca.WinnerId
        FROM nft.NFT n
        JOIN @CompletedAuctions ca ON n.NFTId = ca.NFTId
        WHERE ca.WinnerId IS NOT NULL;

        UPDATE fr SET StateCode = 'CAPTURED', UpdatedAtUtc = SYSUTCDATETIME()
        FROM finance.FundsReservation fr
        JOIN @CompletedAuctions ca ON fr.AuctionId = ca.AuctionId AND fr.UserId = ca.WinnerId
        WHERE ca.WinnerId IS NOT NULL AND fr.StateCode = 'ACTIVE';

        INSERT INTO finance.Ledger (UserId, AuctionId, EntryType, AmountETH, [Description])
        SELECT WinnerId, AuctionId, 'DEBIT', FinalPriceETH, 'Pago por subasta ganada #' + CAST(AuctionId AS NVARCHAR(20))
        FROM @CompletedAuctions
        WHERE WinnerId IS NOT NULL;

        -- 2.5. Procesar el pago al ARTISTA
        -- A) Aumentar el saldo en la wallet del artista.

        --    Calcular una comisión?
        UPDATE w
        SET
            BalanceETH = w.BalanceETH + ca.FinalPriceETH, -- Se acredita el monto final
            UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN @CompletedAuctions ca ON w.UserId = ca.ArtistId
        WHERE ca.WinnerId IS NOT NULL; -- Solo se paga si hubo un ganador

        -- B) Insertar el registro de CRÉDITO en el libro contable para el artista.
        INSERT INTO finance.Ledger (UserId, AuctionId, EntryType, AmountETH, [Description])
        SELECT
            ArtistId,
            AuctionId,
            'CREDIT',
            FinalPriceETH,
            'Ingreso por venta de NFT en subasta #' + CAST(AuctionId AS NVARCHAR(20))
        FROM @CompletedAuctions
        WHERE WinnerId IS NOT NULL;

        -- 3. Procesar a los PERDEDORES y subastas SIN GANADOR
        DECLARE @ReservationsToRelease TABLE (ReservationId BIGINT, UserId BIGINT, AuctionId BIGINT, AmountETH DECIMAL(38,18));
        INSERT INTO @ReservationsToRelease (ReservationId, UserId, AuctionId, AmountETH)
        SELECT fr.ReservationId, fr.UserId, fr.AuctionId, fr.AmountETH
        FROM finance.FundsReservation fr
        JOIN @CompletedAuctions ca ON fr.AuctionId = ca.AuctionId
        WHERE fr.StateCode = 'ACTIVE' AND (ca.WinnerId IS NULL OR fr.UserId <> ca.WinnerId);
        
        UPDATE fr SET StateCode = 'RELEASED', UpdatedAtUtc = SYSUTCDATETIME()
        FROM finance.FundsReservation fr
        JOIN @ReservationsToRelease rtr ON fr.ReservationId = rtr.ReservationId;

        UPDATE w SET 
            ReservedETH = w.ReservedETH - r.TotalReleased,
            UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN (
            SELECT UserId, SUM(AmountETH) as TotalReleased
            FROM @ReservationsToRelease GROUP BY UserId
        ) AS r ON w.UserId = r.UserId;

        -- 4. Enviar todas las NOTIFICACIONES
        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT WinnerId, '¡Felicidades! Ganaste la subasta #' + CAST(AuctionId AS NVARCHAR(20)), 'Has ganado la subasta con una oferta de ' + CAST(FinalPriceETH AS NVARCHAR(50)) + ' ETH. El NFT ha sido transferido a tu cuenta.'
        FROM @CompletedAuctions WHERE WinnerId IS NOT NULL;
        
        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT ArtistId, '¡Subasta completada! #' + CAST(AuctionId AS NVARCHAR(20)), CASE WHEN WinnerId IS NOT NULL THEN 'Tu NFT ha sido vendido por ' + CAST(FinalPriceETH AS NVARCHAR(50)) + ' ETH. Los fondos han sido acreditados en tu wallet.' ELSE 'Tu subasta ha finalizado sin un ganador.' END
        FROM @CompletedAuctions;

        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT UserId, 'Subasta finalizada #' + CAST(AuctionId AS NVARCHAR(20)), 'La subasta ha finalizado. Tus fondos reservados (' + CAST(AmountETH AS NVARCHAR(50)) + ' ETH) han sido liberados.'
        FROM @ReservationsToRelease;
        
        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO audit.EmailOutbox (RecipientEmail, [Subject], [Body])
        VALUES ('admin@artecryptoauctions.com', 'ERROR Crítico - Procesamiento de Subastas Completadas', @ErrorMessage);
        
        THROW;
    END CATCH;
END;
GO