-- ArteCrypto • Plataforma de subastas de NFTs
-- DDL SQL Server (v2) — alineado al ER lógico con USER_EMAIL (multi‑email con principal)
-- Fecha: 2025‑09‑11
-- Notas:
--  • Tiempos en UTC (datetime2(3) + SYSUTCDATETIME()).
--  • Importes en ETH con decimal(38,18).
--  • Checks para estados y coherencias básicas.
--  • Índices únicos y filtrados donde aplica.

CREATE DATABASE ArteCrypto
GO
USE ArteCrypto
GO

/*================================
  ESQUEMAS
================================*/
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')    EXEC('CREATE SCHEMA core');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'nft')     EXEC('CREATE SCHEMA nft');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'auction') EXEC('CREATE SCHEMA auction');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'finance') EXEC('CREATE SCHEMA finance');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'admin')   EXEC('CREATE SCHEMA admin');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')     EXEC('CREATE SCHEMA ops');
GO

/*================================
  TABLAS DE REFERENCIA / OPS
================================*/
CREATE TABLE ops.Settings (
    SettingKey    SYSNAME        NOT NULL PRIMARY KEY,
    SettingValue  NVARCHAR(200)  NOT NULL,
    UpdatedAtUtc  DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

/*================================
  DOMINIO: USUARIOS & ROLES
================================*/
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
    UserId       BIGINT       NOT NULL,
    RoleId       BIGINT       NOT NULL,
    AsignacionUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_UserRole PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_UserRole_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_UserRole_Role FOREIGN KEY (RoleId) REFERENCES core.Role(RoleId)
);
GO

-- Multi-email por usuario + uno principal por usuario
CREATE TABLE core.UserEmail (
    EmailId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId        BIGINT         NOT NULL,
    [Email]       NVARCHAR(100)  NOT NULL,
    IsPrimary     BIT            NOT NULL DEFAULT(0),
    AddedAtUtc    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    VerifiedAtUtc DATETIME2(3)   NULL,
    StatusCode    VARCHAR(15)    NOT NULL DEFAULT 'ACTIVE', -- ACTIVE | INACTIVE
    CONSTRAINT FK_UserEmail_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT UQ_UserEmail_Email UNIQUE([Email]),
    CONSTRAINT CK_UserEmail_Status CHECK (StatusCode IN ('ACTIVE','INACTIVE'))
);
GO
-- Un (1) principal por usuario (índice único filtrado)
CREATE UNIQUE INDEX UQ_UserEmail_Primary ON core.UserEmail(UserId) WHERE IsPrimary = 1;
GO

/*================================
  DOMINIO: BILLETERA
================================*/
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

/*================================
  DOMINIO: NFTS
================================*/
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
    StatusCode        VARCHAR(20)    NOT NULL DEFAULT 'PENDING', -- PENDING|APPROVED|REJECTED|FINALIZED
    CreatedAtUtc      DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    ApprovedAtUtc     DATETIME2(3)   NULL,
    CONSTRAINT UQ_NFT_Hash UNIQUE(HashCode),
    CONSTRAINT FK_NFT_Artist FOREIGN KEY (ArtistId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_NFT_Owner  FOREIGN KEY (CurrentOwnerId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_NFT_Status CHECK (StatusCode IN ('PENDING','APPROVED','REJECTED','FINALIZED'))
);
GO
CREATE INDEX IX_NFT_Artist ON nft.NFT(ArtistId, CreatedAtUtc);
GO

/*================================
  DOMINIO: CURADURÍA
================================*/
CREATE TABLE admin.CurationReview (
    ReviewId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    NFTId           BIGINT         NOT NULL,
    CuratorId       BIGINT         NOT NULL,
    DecisionCode    VARCHAR(10)    NOT NULL, -- APPROVE | REJECT
    [Comment]       NVARCHAR(MAX)  NULL,
    StartedAtUtc    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    ReviewedAtUtc   DATETIME2(3)   NULL,
    CONSTRAINT FK_CReview_NFT     FOREIGN KEY (NFTId)    REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_CReview_Curator FOREIGN KEY (CuratorId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_CReview_Decision CHECK (DecisionCode IN ('APPROVE','REJECT')),
    CONSTRAINT CK_CReview_Times CHECK (ReviewedAtUtc IS NULL OR ReviewedAtUtc >= StartedAtUtc)
);
GO
CREATE INDEX IX_CReview_NFT ON admin.CurationReview(NFTId, ReviewedAtUtc);
GO

/*================================
  DOMINIO: SUBASTAS
================================*/
CREATE TABLE auction.Auction (
    AuctionId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    NFTId            BIGINT         NOT NULL,
    StartAtUtc       DATETIME2(3)   NOT NULL,
    EndAtUtc         DATETIME2(3)   NOT NULL,
    StartingPriceETH DECIMAL(38,18) NOT NULL,
    CurrentPriceETH  DECIMAL(38,18) NOT NULL,
    CurrentLeaderId  BIGINT         NULL,
    StatusCode       VARCHAR(15)    NOT NULL DEFAULT 'ACTIVE', -- ACTIVE|FINALIZED|CANCELED
    CONSTRAINT FK_Auction_NFT FOREIGN KEY (NFTId) REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_Auction_Leader FOREIGN KEY (CurrentLeaderId) REFERENCES core.[User](UserId),
    CONSTRAINT UQ_Auction_NFT UNIQUE(NFTId),
    CONSTRAINT CK_Auction_Dates CHECK (EndAtUtc > StartAtUtc),
    CONSTRAINT CK_Auction_Prices CHECK (StartingPriceETH > 0 AND CurrentPriceETH >= StartingPriceETH),
    CONSTRAINT CK_Auction_Status CHECK (StatusCode IN ('ACTIVE','FINALIZED','CANCELED'))
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

/*================================
  DOMINIO: FINANZAS
================================*/
CREATE TABLE finance.FundsReservation (
    ReservationId  BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId         BIGINT         NOT NULL,
    AuctionId      BIGINT         NOT NULL,
    BidId          BIGINT         NULL,
    AmountETH      DECIMAL(38,18) NOT NULL,
    StateCode      VARCHAR(10)    NOT NULL DEFAULT 'ACTIVE', -- ACTIVE|RELEASED|APPLIED
    CreatedAtUtc   DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc   DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_FRes_User    FOREIGN KEY (UserId)    REFERENCES core.[User](UserId),
    CONSTRAINT FK_FRes_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_FRes_Bid     FOREIGN KEY (BidId)     REFERENCES auction.Bid(BidId),
    CONSTRAINT CK_FRes_State   CHECK (StateCode IN ('ACTIVE','RELEASED','APPLIED')),
    CONSTRAINT CK_FRes_Positive CHECK (AmountETH > 0)
);
GO
CREATE INDEX IX_FRes_AuctionState ON finance.FundsReservation (AuctionId, StateCode);
CREATE INDEX IX_FRes_UserState    ON finance.FundsReservation (UserId, StateCode);
GO

CREATE TABLE finance.Ledger (
    EntryId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId        BIGINT         NOT NULL,
    AuctionId     BIGINT         NULL,
    EntryType     VARCHAR(10)    NOT NULL, -- DEBIT|CREDIT
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

/*================================
  SEED SUGERIDO (opcional)
================================*/
MERGE ops.Settings AS t
USING (VALUES
    ('DefaultAuctionHours','72'),
    ('BasePriceETH','0.1'),
    ('MinBidIncrementPct','5')
) AS s(SettingKey, SettingValue)
ON t.SettingKey = s.SettingKey
WHEN NOT MATCHED THEN INSERT (SettingKey, SettingValue) VALUES (s.SettingKey, s.SettingValue)
WHEN MATCHED AND t.SettingValue <> s.SettingValue THEN UPDATE SET t.SettingValue = s.SettingValue, UpdatedAtUtc = SYSUTCDATETIME();
GO

/*================================
  COMPROBACIONES DE INTEGRIDAD (opcionales)
  - Consistencia de Wallet.ReservedETH con reservas ACTIVAS se verifica en procesos (SP/jobs).
  - Una (1) dirección primaria por usuario está reforzada por índice filtrado.
================================*/
