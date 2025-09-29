CREATE DATABASE ArteCryptoAuctions
GO

USE ArteCryptoAuctions;
GO
-- 1) Esquemas
CREATE SCHEMA admin; 
GO
CREATE SCHEMA auction;
GO
CREATE SCHEMA audit;
GO
CREATE SCHEMA core;
GO
CREATE SCHEMA finance;
GO
CREATE SCHEMA nft;
GO
CREATE SCHEMA ops;
GO

--------------------------------------------------------------------------------
-- 2) Catálogos operativos
--------------------------------------------------------------------------------
CREATE TABLE ops.Status (
  StatusId     int IDENTITY(1,1) PRIMARY KEY,
  Domain       varchar(50) NOT NULL,
  Code         varchar(30) NOT NULL,
  Description  nvarchar(200) NULL,
  CONSTRAINT UQ_Status_Domain_Code UNIQUE (Domain, Code)
);

CREATE TABLE ops.Settings (
  SettingKey    sysname       NOT NULL PRIMARY KEY,
  SettingValue  nvarchar(200) NOT NULL,
  UpdatedAtUtc  datetime2(3)  NOT NULL DEFAULT sysutcdatetime()
);

--------------------------------------------------------------------------------
-- 3) Núcleo de usuarios / roles / billeteras
--------------------------------------------------------------------------------
CREATE TABLE core.[User] (
  UserId        bigint IDENTITY(1,1) PRIMARY KEY,
  FullName      nvarchar(100) NOT NULL,
  CreatedAtUtc  datetime2(3)  NOT NULL DEFAULT sysutcdatetime()
);

CREATE TABLE core.Role (
  RoleId  bigint IDENTITY(1,1) PRIMARY KEY,
  [Name]  nvarchar(100) NOT NULL,
  CONSTRAINT UQ_Role_Name UNIQUE ([Name])
);

CREATE TABLE core.UserRole (
  UserId        bigint NOT NULL,
  RoleId        bigint NOT NULL,
  AsignacionUtc datetime2(3) NOT NULL DEFAULT sysutcdatetime(),
  CONSTRAINT PK_UserRole PRIMARY KEY (UserId, RoleId),
  CONSTRAINT FK_UserRole_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
  CONSTRAINT FK_UserRole_Role FOREIGN KEY (RoleId) REFERENCES core.Role(RoleId)
);

-- Estados de email referencian dominio USER_EMAIL en ops.Status
CREATE TABLE core.UserEmail (
  EmailId       bigint IDENTITY(1,1) PRIMARY KEY,
  UserId        bigint        NOT NULL,
  Email         nvarchar(100) NOT NULL,
  IsPrimary     bit           NOT NULL DEFAULT 0,
  AddedAtUtc    datetime2(3)  NOT NULL DEFAULT sysutcdatetime(),
  VerifiedAtUtc datetime2(3)  NULL,
  StatusCode    varchar(30)   NOT NULL DEFAULT 'ACTIVE',
  StatusDomain  AS CONVERT(varchar(50), 'USER_EMAIL') PERSISTED,
  CONSTRAINT UQ_UserEmail_Email UNIQUE (Email),
  CONSTRAINT FK_UserEmail_User   FOREIGN KEY (UserId)       REFERENCES core.[User](UserId),
  CONSTRAINT FK_UserEmail_Status FOREIGN KEY (StatusDomain, StatusCode)
    REFERENCES ops.Status(Domain, Code)
);

CREATE TABLE core.Wallet (
  WalletId     bigint IDENTITY(1,1) PRIMARY KEY,
  UserId       bigint       NOT NULL,
  BalanceETH   decimal(38,18) NOT NULL DEFAULT 0,
  ReservedETH  decimal(38,18) NOT NULL DEFAULT 0,
  UpdatedAtUtc datetime2(3)   NOT NULL DEFAULT sysutcdatetime(),
  CONSTRAINT UQ_Wallet_User UNIQUE (UserId),
  CONSTRAINT FK_Wallet_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
  CONSTRAINT CK_Wallet_Positive CHECK (BalanceETH >= 0 AND ReservedETH >= 0)
);

--------------------------------------------------------------------------------
-- 4) NFTs y curación
--------------------------------------------------------------------------------
-- Estados de NFT referencian dominio NFT en ops.Status
CREATE TABLE nft.NFT (
  NFTId            bigint IDENTITY(1,1) PRIMARY KEY,
  ArtistId         bigint        NOT NULL,
  CurrentOwnerId   bigint        NULL,
  [Name]           nvarchar(160) NOT NULL,
  [Description]    nvarchar(max) NULL,
  ContentType      nvarchar(100) NOT NULL,
  HashCode         char(64)      NOT NULL,
  FileSizeBytes    bigint        NULL,
  WidthPx          int           NULL,
  HeightPx         int           NULL,
  SuggestedPriceETH decimal(38,18) NULL,
  StatusCode       varchar(30)   NOT NULL DEFAULT 'PENDING',
  StatusDomain     AS CONVERT(varchar(50), 'NFT') PERSISTED,
  CreatedAtUtc     datetime2(3)  NOT NULL DEFAULT sysutcdatetime(),
  ApprovedAtUtc    datetime2(3)  NULL,
  CONSTRAINT UQ_NFT_Hash UNIQUE (HashCode),
  CONSTRAINT FK_NFT_Artist FOREIGN KEY (ArtistId)       REFERENCES core.[User](UserId),
  CONSTRAINT FK_NFT_Owner  FOREIGN KEY (CurrentOwnerId) REFERENCES core.[User](UserId),
  CONSTRAINT FK_NFT_Status FOREIGN KEY (StatusDomain, StatusCode)
    REFERENCES ops.Status(Domain, Code)
);

-- Decisiones de curación referencian dominio CURATION_DECISION en ops.Status
CREATE TABLE admin.CurationReview (
  ReviewId      bigint IDENTITY(1,1) PRIMARY KEY,
  NFTId         bigint        NOT NULL,
  CuratorId     bigint        NOT NULL,
  DecisionCode  varchar(30)   NOT NULL,
  StatusDomain  AS CONVERT(varchar(50), 'CURATION_DECISION') PERSISTED,
  [Comment]     nvarchar(max) NULL,
  StartedAtUtc  datetime2(3)  NOT NULL DEFAULT sysutcdatetime(),
  ReviewedAtUtc datetime2(3)  NULL,
  CONSTRAINT FK_CReview_NFT     FOREIGN KEY (NFTId)    REFERENCES nft.NFT(NFTId),
  CONSTRAINT FK_CReview_Curator FOREIGN KEY (CuratorId)REFERENCES core.[User](UserId),
  CONSTRAINT FK_CReview_Status  FOREIGN KEY (StatusDomain, DecisionCode)
    REFERENCES ops.Status(Domain, Code),
  CONSTRAINT CK_CReview_Times CHECK (ReviewedAtUtc IS NULL OR ReviewedAtUtc >= StartedAtUtc)
);

--------------------------------------------------------------------------------
-- 5) Configuración y subastas
--------------------------------------------------------------------------------
CREATE TABLE auction.AuctionSettings (
  SettingsID           int          NOT NULL PRIMARY KEY,
  CompanyName          nvarchar(250) NOT NULL,         -- <— simplificado desde varbinary(250)
  BasePriceETH         decimal(38,18) NOT NULL,
  DefaultAuctionHours  tinyint        NOT NULL,
  MinBidIncrementPct   tinyint        NOT NULL
);

-- Estados de subasta referencian dominio AUCTION en ops.Status
CREATE TABLE auction.Auction (
  AuctionId        bigint IDENTITY(1,1) PRIMARY KEY,
  SettingsID       int           NULL,
  NFTId            bigint        NOT NULL,
  StartAtUtc       datetime2(3)  NOT NULL,
  EndAtUtc         datetime2(3)  NOT NULL,
  StartingPriceETH decimal(38,18) NOT NULL,
  CurrentPriceETH  decimal(38,18) NOT NULL,
  CurrentLeaderId  bigint        NULL,
  StatusCode       varchar(30)   NOT NULL DEFAULT 'ACTIVE',
  StatusDomain     AS CONVERT(varchar(50), 'AUCTION') PERSISTED,
  CONSTRAINT UQ_Auction_NFT UNIQUE (NFTId),
  CONSTRAINT FK_Auction_Settings FOREIGN KEY (SettingsID)      REFERENCES auction.AuctionSettings(SettingsID),
  CONSTRAINT FK_Auction_NFT      FOREIGN KEY (NFTId)           REFERENCES nft.NFT(NFTId),
  CONSTRAINT FK_Auction_Leader   FOREIGN KEY (CurrentLeaderId) REFERENCES core.[User](UserId),
  CONSTRAINT FK_Auction_Status   FOREIGN KEY (StatusDomain, StatusCode)
    REFERENCES ops.Status(Domain, Code),
  CONSTRAINT CK_Auction_Dates   CHECK (EndAtUtc > StartAtUtc),
  CONSTRAINT CK_Auction_Prices  CHECK (StartingPriceETH > 0 AND CurrentPriceETH >= StartingPriceETH)
);

CREATE TABLE auction.Bid (
  BidId      bigint IDENTITY(1,1) PRIMARY KEY,
  AuctionId  bigint         NOT NULL,
  BidderId   bigint         NOT NULL,
  AmountETH  decimal(38,18) NOT NULL,
  PlacedAtUtc datetime2(3)  NOT NULL DEFAULT sysutcdatetime(),
  CONSTRAINT FK_Bid_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
  CONSTRAINT FK_Bid_User    FOREIGN KEY (BidderId)  REFERENCES core.[User](UserId),
  CONSTRAINT CK_Bid_Positive CHECK (AmountETH > 0)
);

--------------------------------------------------------------------------------
-- 6) Finanzas
--------------------------------------------------------------------------------
-- Estados de reserva referencian dominio FUNDS_RESERVATION en ops.Status
CREATE TABLE finance.FundsReservation (
  ReservationId bigint IDENTITY(1,1) PRIMARY KEY,
  UserId        bigint         NOT NULL,
  AuctionId     bigint         NOT NULL,
  BidId         bigint         NULL,
  AmountETH     decimal(38,18) NOT NULL,
  StateCode     varchar(30)    NOT NULL DEFAULT 'ACTIVE',
  StatusDomain  AS CONVERT(varchar(50), 'FUNDS_RESERVATION') PERSISTED,
  CreatedAtUtc  datetime2(3)   NOT NULL DEFAULT sysutcdatetime(),
  UpdatedAtUtc  datetime2(3)   NOT NULL DEFAULT sysutcdatetime(),
  CONSTRAINT FK_FRes_User   FOREIGN KEY (UserId)    REFERENCES core.[User](UserId),
  CONSTRAINT FK_FRes_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
  CONSTRAINT FK_FRes_Bid     FOREIGN KEY (BidId)     REFERENCES auction.Bid(BidId),
  CONSTRAINT FK_FRes_Status  FOREIGN KEY (StatusDomain, StateCode)
    REFERENCES ops.Status(Domain, Code),
  CONSTRAINT CK_FRes_Positive CHECK (AmountETH > 0)
);

CREATE TABLE finance.Ledger (
  EntryId      bigint IDENTITY(1,1) PRIMARY KEY,
  UserId       bigint         NOT NULL,
  AuctionId    bigint         NOT NULL,
  EntryType    varchar(10)    NOT NULL, -- 'CREDIT' | 'DEBIT'
  AmountETH    decimal(38,18) NOT NULL,
  [Description] nvarchar(200) NULL,
  CreatedAtUtc datetime2(3)   NOT NULL DEFAULT sysutcdatetime(),
  CONSTRAINT FK_Ledger_User    FOREIGN KEY (UserId)    REFERENCES core.[User](UserId),
  CONSTRAINT FK_Ledger_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
  CONSTRAINT CK_Ledger_Type    CHECK (EntryType IN ('CREDIT','DEBIT')),
  CONSTRAINT CK_Ledger_Positive CHECK (AmountETH > 0)
);

--------------------------------------------------------------------------------
-- 7) Auditoría / Outbox
--------------------------------------------------------------------------------
-- Estados de correo referencian dominio EMAIL_OUTBOX en ops.Status
CREATE TABLE audit.EmailOutbox (
  EmailId         bigint IDENTITY(1,1) PRIMARY KEY,
  RecipientUserId bigint         NULL,
  RecipientEmail  nvarchar(100)  NULL,
  [Subject]       nvarchar(200)  NOT NULL,
  [Body]          nvarchar(max)  NOT NULL,
  StatusCode      varchar(30)    NOT NULL DEFAULT 'PENDING',
  StatusDomain    AS CONVERT(varchar(50), 'EMAIL_OUTBOX') PERSISTED,
  CreatedAtUtc    datetime2(3)   NOT NULL DEFAULT sysutcdatetime(),
  SentAtUtc       datetime2(3)   NULL,
  CorrelationKey  nvarchar(100)  NULL,
  CONSTRAINT FK_EmailOutbox_User   FOREIGN KEY (RecipientUserId)         REFERENCES core.[User](UserId),
  CONSTRAINT FK_EmailOutbox_Status FOREIGN KEY (StatusDomain, StatusCode) REFERENCES ops.Status(Domain, Code)
);
