-- ArteCrypto • Plataforma de subastas de NFT
-- DDL SQL Server (v3) — Consolidado con catálogo global de estados (ops.Status)
-- Fecha: 2025‑09‑11
-- Convenciones:
--  • Timestamps en UTC -> datetime2(3) con default SYSUTCDATETIME().
--  • Importes (ETH) con decimal(38,18).
--  • Integridad de estados mediante FK compuesto (Domain, Code) hacia ops.Status con columna computada StatusDomain.

CREATE DATABASE ArteCryptoAuctions
GO

USE ArteCryptoAuctions
GO

/*=========================================================
  PRE: Esquemas
=========================================================*/
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')    EXEC('CREATE SCHEMA core');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'nft')     EXEC('CREATE SCHEMA nft');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'auction') EXEC('CREATE SCHEMA auction');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'finance') EXEC('CREATE SCHEMA finance');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'admin')   EXEC('CREATE SCHEMA admin');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')     EXEC('CREATE SCHEMA ops');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')   EXEC('CREATE SCHEMA audit');
GO

/*=========================================================
  OPS: Parámetros y catálogo de estados
=========================================================*/
CREATE TABLE ops.Settings (
    SettingKey    SYSNAME        NOT NULL PRIMARY KEY,
    SettingValue  NVARCHAR(200)  NOT NULL,
    UpdatedAtUtc  DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE ops.[Status](
    StatusId      INT IDENTITY(1,1) PRIMARY KEY,
    [Domain]      VARCHAR(50)   NOT NULL,     -- NFT | AUCTION | FUNDS_RESERVATION | USER_EMAIL | EMAIL_OUTBOX | ...
    [Code]        VARCHAR(30)   NOT NULL,     -- PENDING | APPROVED | ACTIVE | ...
    [Description] NVARCHAR(200) NULL,
    CONSTRAINT UQ_Status_Domain_Code UNIQUE([Domain],[Code])
);
GO

-- Seed de estados (idempotente: inserta si no existe)
MERGE ops.[Status] AS t
USING (VALUES
  ('NFT','PENDING',    N'NFT en revisión'),
  ('NFT','APPROVED',   N'NFT aprobado'),
  ('NFT','REJECTED',   N'NFT rechazado'),
  ('NFT','FINALIZED',  N'NFT finalizado'),

  ('AUCTION','ACTIVE',    N'Subasta activa'),
  ('AUCTION','FINALIZED', N'Subasta finalizada'),
  ('AUCTION','CANCELED',  N'Subasta cancelada'),

  ('FUNDS_RESERVATION','ACTIVE',   N'Reserva activa'),
  ('FUNDS_RESERVATION','RELEASED', N'Reserva liberada'),
  ('FUNDS_RESERVATION','APPLIED',  N'Reserva aplicada'),

  ('USER_EMAIL','ACTIVE',  N'Email activo'),
  ('USER_EMAIL','INACTIVE',N'Email inactivo'),

  ('EMAIL_OUTBOX','PENDING', N'Correo en cola'),
  ('EMAIL_OUTBOX','SENT',    N'Correo enviado'),
  ('EMAIL_OUTBOX','FAILED',  N'Fallo de envío'),

  ('CURATION_DECISION', 'APPROVE', N'NFT aprovó la curacion'),
  ('CURATION_DECISION', 'REJECT', N'NFT no aprovo la curacion')
) AS s([Domain],[Code],[Description])
ON (t.[Domain]=s.[Domain] AND t.[Code]=s.[Code])
WHEN NOT MATCHED THEN INSERT([Domain],[Code],[Description]) VALUES(s.[Domain],s.[Code],s.[Description]);
GO

/*=========================================================
  CORE: Usuarios, roles, emails, billeteras
=========================================================*/
CREATE TABLE core.[User] (
    UserId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    FullName      NVARCHAR(100) NOT NULL,
    CreatedAtUtc  DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE core.Role (
    RoleId   BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Name]   NVARCHAR(100) NOT NULL,
    CONSTRAINT UQ_Role_Name UNIQUE([Name])
);
GO

CREATE TABLE core.UserRole (
    UserId        BIGINT       NOT NULL,
    RoleId        BIGINT       NOT NULL,
    AsignacionUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_UserRole PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_UserRole_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_UserRole_Role FOREIGN KEY (RoleId) REFERENCES core.Role(RoleId)
);
GO

CREATE TABLE core.UserEmail (
    EmailId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId        BIGINT         NOT NULL,
    [Email]       NVARCHAR(100)  NOT NULL,
    IsPrimary     BIT            NOT NULL DEFAULT(0),
    AddedAtUtc    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    VerifiedAtUtc DATETIME2(3)   NULL,
    StatusCode    VARCHAR(30)    NOT NULL DEFAULT 'ACTIVE', -- via FK ops.Status
    -- Dominio de estados (computado-persistido)
    StatusDomain  AS CAST('USER_EMAIL' AS VARCHAR(50)) PERSISTED,
    CONSTRAINT FK_UserEmail_User   FOREIGN KEY (UserId)                 REFERENCES core.[User](UserId),
    CONSTRAINT FK_UserEmail_Status FOREIGN KEY (StatusDomain,StatusCode) REFERENCES ops.[Status]([Domain],[Code]),
    CONSTRAINT UQ_UserEmail_Email UNIQUE([Email])
);
GO
CREATE UNIQUE INDEX UQ_UserEmail_Primary ON core.UserEmail(UserId) WHERE IsPrimary = 1;
GO

CREATE TABLE core.Wallet (
    WalletId     BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId       BIGINT         NOT NULL,
    BalanceETH   DECIMAL(38,18) NOT NULL DEFAULT (0),
    ReservedETH  DECIMAL(38,18) NOT NULL DEFAULT (0),
    UpdatedAtUtc DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Wallet_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT UQ_Wallet_User UNIQUE(UserId),
    CONSTRAINT CK_Wallet_Positive CHECK (BalanceETH >= 0 AND ReservedETH >= 0)
);
GO

/*=========================================================
  NFT: Obras
=========================================================*/
CREATE TABLE nft.NFT (
    NFTId             BIGINT IDENTITY(1,1) PRIMARY KEY,
    ArtistId          BIGINT         NOT NULL, -- core.User (ARTIST)
    CurrentOwnerId    BIGINT         NULL,     -- core.User
    [Name]            NVARCHAR(160)  NOT NULL,
    [Description]     NVARCHAR(MAX)  NULL,
    ContentType       NVARCHAR(100)  NOT NULL,
    HashCode          CHAR(64)       NOT NULL, -- SHA-256 hex
    FileSizeBytes     BIGINT         NULL,
    WidthPx           INT            NULL,
    HeightPx          INT            NULL,
    SuggestedPriceETH DECIMAL(38,18) NULL,
    StatusCode        VARCHAR(30)    NOT NULL DEFAULT 'PENDING', -- via FK ops.Status
    StatusDomain      AS CAST('NFT' AS VARCHAR(50)) PERSISTED,
    CreatedAtUtc      DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    ApprovedAtUtc     DATETIME2(3)   NULL,
    CONSTRAINT UQ_NFT_Hash UNIQUE(HashCode),
    CONSTRAINT FK_NFT_Artist FOREIGN KEY (ArtistId)       REFERENCES core.[User](UserId),
    CONSTRAINT FK_NFT_Owner  FOREIGN KEY (CurrentOwnerId)  REFERENCES core.[User](UserId),
    CONSTRAINT FK_NFT_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.[Status]([Domain],[Code])
);
GO
CREATE INDEX IX_NFT_Artist ON nft.NFT(ArtistId, CreatedAtUtc);
GO

/*=========================================================
  ADMIN: Curaduría
=========================================================*/
CREATE TABLE admin.CurationReview (
    ReviewId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    NFTId           BIGINT         NOT NULL,
    CuratorId       BIGINT         NOT NULL,
    DecisionCode    VARCHAR(30)    NOT NULL, -- APPROVE | REJECT (si quieres también en ops.Status, crea dominio CURATION_DECISION)
	StatusDomain    AS CAST('CURATION_DECISION' AS VARCHAR(50)) PERSISTED,
    [Comment]       NVARCHAR(MAX)  NULL,
    StartedAtUtc    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    ReviewedAtUtc   DATETIME2(3)   NULL,
    CONSTRAINT FK_CReview_NFT     FOREIGN KEY (NFTId)    REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_CReview_Curator FOREIGN KEY (CuratorId) REFERENCES core.[User](UserId),
	CONSTRAINT FK_CurationReview_Status FOREIGN KEY (StatusDomain, DecisionCode) REFERENCES ops.[Status]([Domain],[Code]),
    CONSTRAINT CK_CReview_Times CHECK (ReviewedAtUtc IS NULL OR ReviewedAtUtc >= StartedAtUtc)
);
GO
CREATE INDEX IX_CReview_NFT ON admin.CurationReview(NFTId, ReviewedAtUtc);
GO

/*=========================================================
  AUCTION: Subastas y ofertas
=========================================================*/
CREATE TABLE auction.Auction (
    AuctionId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    NFTId            BIGINT         NOT NULL,
    StartAtUtc       DATETIME2(3)   NOT NULL,
    EndAtUtc         DATETIME2(3)   NOT NULL,
    StartingPriceETH DECIMAL(38,18) NOT NULL,
    CurrentPriceETH  DECIMAL(38,18) NOT NULL,
    CurrentLeaderId  BIGINT         NULL,
    StatusCode       VARCHAR(30)    NOT NULL DEFAULT 'ACTIVE', -- via FK ops.Status
    StatusDomain     AS CAST('AUCTION' AS VARCHAR(50)) PERSISTED,
    CONSTRAINT FK_Auction_NFT FOREIGN KEY (NFTId) REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_Auction_Leader FOREIGN KEY (CurrentLeaderId) REFERENCES core.[User](UserId),
    CONSTRAINT UQ_Auction_NFT UNIQUE(NFTId),
    CONSTRAINT CK_Auction_Dates CHECK (EndAtUtc > StartAtUtc),
    CONSTRAINT CK_Auction_Prices CHECK (StartingPriceETH > 0 AND CurrentPriceETH >= StartingPriceETH),
    CONSTRAINT FK_Auction_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.[Status]([Domain],[Code])
);
GO
CREATE INDEX IX_Auction_Status_End ON auction.Auction(StatusCode, EndAtUtc);
GO

CREATE TABLE auction.Bid (
    BidId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    AuctionId    BIGINT         NOT NULL,
    BidderId     BIGINT         NOT NULL,
    AmountETH    DECIMAL(38,18) NOT NULL,
    PlacedAtUtc  DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Bid_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_Bid_User    FOREIGN KEY (BidderId)  REFERENCES core.[User](UserId),
    CONSTRAINT CK_Bid_Positive CHECK (AmountETH > 0)
);
GO
CREATE INDEX IX_Bid_Auction ON auction.Bid (AuctionId, AmountETH DESC, PlacedAtUtc ASC);
CREATE INDEX IX_Bid_User    ON auction.Bid (BidderId, PlacedAtUtc DESC);
GO

/*=========================================================
  FINANCE: Reservas y libro mayor
=========================================================*/
CREATE TABLE finance.FundsReservation (
    ReservationId  BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId         BIGINT         NOT NULL,
    AuctionId      BIGINT         NOT NULL,
    BidId          BIGINT         NULL,
    AmountETH      DECIMAL(38,18) NOT NULL,
    StateCode      VARCHAR(30)    NOT NULL DEFAULT 'ACTIVE', -- via FK ops.Status
    StatusDomain   AS CAST('FUNDS_RESERVATION' AS VARCHAR(50)) PERSISTED,
    CreatedAtUtc   DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc   DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_FRes_User    FOREIGN KEY (UserId)    REFERENCES core.[User](UserId),
    CONSTRAINT FK_FRes_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_FRes_Bid     FOREIGN KEY (BidId)     REFERENCES auction.Bid(BidId),
    CONSTRAINT CK_FRes_Positive CHECK (AmountETH > 0),
    CONSTRAINT FK_FRes_Status FOREIGN KEY (StatusDomain, StateCode) REFERENCES ops.[Status]([Domain],[Code])
);
GO
CREATE INDEX IX_FRes_AuctionState ON finance.FundsReservation (AuctionId, StateCode);
CREATE INDEX IX_FRes_UserState    ON finance.FundsReservation (UserId, StateCode);
GO

CREATE TABLE finance.Ledger (
    EntryId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId        BIGINT         NOT NULL,
    AuctionId     BIGINT         NULL,
    EntryType     VARCHAR(10)    NOT NULL, -- DEBIT | CREDIT
    AmountETH     DECIMAL(38,18) NOT NULL,
    [Description] NVARCHAR(200)  NULL,
    CreatedAtUtc  DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Ledger_User    FOREIGN KEY (UserId)    REFERENCES core.[User](UserId),
    CONSTRAINT FK_Ledger_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT CK_Ledger_Type    CHECK (EntryType IN ('DEBIT','CREDIT')),
    CONSTRAINT CK_Ledger_Positive CHECK (AmountETH > 0)
);
GO
CREATE INDEX IX_Ledger_UserTime ON finance.Ledger (UserId, CreatedAtUtc DESC);
GO

/*=========================================================
  AUDIT: Outbox de emails (para notificaciones)
=========================================================*/
CREATE TABLE audit.EmailOutbox (
    EmailId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    RecipientUserId BIGINT         NULL,
    RecipientEmail  NVARCHAR(100)  NOT NULL,
    [Subject]       NVARCHAR(200)  NOT NULL,
    [Body]          NVARCHAR(MAX)  NOT NULL,
    StatusCode      VARCHAR(30)    NOT NULL DEFAULT 'PENDING', -- via FK ops.Status
    StatusDomain    AS CAST('EMAIL_OUTBOX' AS VARCHAR(50)) PERSISTED,
    CreatedAtUtc    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    SentAtUtc       DATETIME2(3)   NULL,
    CorrelationKey  NVARCHAR(100)  NULL,
    CONSTRAINT FK_EmailOutbox_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.[Status]([Domain],[Code])
);
GO
CREATE INDEX IX_EmailOutbox_Pending ON audit.EmailOutbox(StatusCode) WHERE StatusCode='PENDING';
GO

/*=========================================================
  SEED de Settings (solo inserta si no existe)
=========================================================*/
IF NOT EXISTS (SELECT 1 FROM ops.Settings WHERE SettingKey='DefaultAuctionHours')
  INSERT INTO ops.Settings(SettingKey, SettingValue) VALUES ('DefaultAuctionHours','72');
IF NOT EXISTS (SELECT 1 FROM ops.Settings WHERE SettingKey='BasePriceETH')
  INSERT INTO ops.Settings(SettingKey, SettingValue) VALUES ('BasePriceETH','0.1');
IF NOT EXISTS (SELECT 1 FROM ops.Settings WHERE SettingKey='MinBidIncrementPct')
  INSERT INTO ops.Settings(SettingKey, SettingValue) VALUES ('MinBidIncrementPct','5');
GO

-- Fin del DDL v3.