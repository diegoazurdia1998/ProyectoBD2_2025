-- ArteCrypto • Plataforma de subastas de NFT
-- DDL SQL Server (v4) 
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


/* =========================================================
   TABLAS
========================================================= */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** admin.CurationReview ******/
CREATE TABLE [admin].[CurationReview](
  [ReviewId]      [bigint] IDENTITY(1,1) NOT NULL,
  [NFTId]         [bigint] NOT NULL,
  [CuratorId]     [bigint] NOT NULL,
  [DecisionCode]  [varchar](30) NOT NULL,
  [StatusDomain]  AS (CONVERT([varchar](50),'CURATION_DECISION')) PERSISTED,
  [Comment]       [nvarchar](max) NULL,
  [StartedAtUtc]  [datetime2](3) NOT NULL,
  [ReviewedAtUtc] [datetime2](3) NULL,
  CONSTRAINT [PK_CurationReview] PRIMARY KEY CLUSTERED ([ReviewId] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** auction.Auction ******/
CREATE TABLE [auction].[Auction](
  [AuctionId]        [bigint] IDENTITY(1,1) NOT NULL,
  [NFTId]            [bigint] NOT NULL,
  [StartAtUtc]       [datetime2](3) NOT NULL,
  [EndAtUtc]         [datetime2](3) NOT NULL,
  [StartingPriceETH] [decimal](38, 18) NOT NULL,
  [CurrentPriceETH]  [decimal](38, 18) NOT NULL,
  [CurrentLeaderId]  [bigint] NULL,
  [StatusCode]       [varchar](30) NOT NULL,
  [StatusDomain]     AS (CONVERT([varchar](50),'AUCTION')) PERSISTED,
  CONSTRAINT [PK_Auction] PRIMARY KEY CLUSTERED ([AuctionId] ASC),
  CONSTRAINT [UQ_Auction_NFT] UNIQUE NONCLUSTERED ([NFTId] ASC)
) ON [PRIMARY]
GO

/****** auction.Bid ******/
CREATE TABLE [auction].[Bid](
  [BidId]       [bigint] IDENTITY(1,1) NOT NULL,
  [AuctionId]   [bigint] NOT NULL,
  [BidderId]    [bigint] NOT NULL,
  [AmountETH]   [decimal](38, 18) NOT NULL,
  [PlacedAtUtc] [datetime2](3) NOT NULL,
  CONSTRAINT [PK_Bid] PRIMARY KEY CLUSTERED ([BidId] ASC)
) ON [PRIMARY]
GO

/****** audit.EmailOutbox ******/
CREATE TABLE [audit].[EmailOutbox](
  [EmailId]         [bigint] IDENTITY(1,1) NOT NULL,
  [RecipientUserId] [bigint] NULL,             -- ahora NULL (permite externos)
  [RecipientEmail]  [nvarchar](100) NULL,      -- correo efectivo opcional
  [Subject]         [nvarchar](200) NOT NULL,
  [Body]            [nvarchar](max) NOT NULL,
  [StatusCode]      [varchar](30) NOT NULL,
  [StatusDomain]    AS (CONVERT([varchar](50),'EMAIL_OUTBOX')) PERSISTED,
  [CreatedAtUtc]    [datetime2](3) NOT NULL,
  [SentAtUtc]       [datetime2](3) NULL,       -- ahora NULL (PENDING no tiene fecha)
  [CorrelationKey]  [nvarchar](100) NULL,
  CONSTRAINT [PK_EmailOutbox] PRIMARY KEY CLUSTERED ([EmailId] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** core.Role ******/
CREATE TABLE [core].[Role](
  [RoleId] [bigint] IDENTITY(1,1) NOT NULL,
  [Name]   [nvarchar](100) NOT NULL,
  CONSTRAINT [PK_Role] PRIMARY KEY CLUSTERED ([RoleId] ASC),
  CONSTRAINT [UQ_Role_Name] UNIQUE NONCLUSTERED ([Name] ASC)
) ON [PRIMARY]
GO

/****** core.User ******/
CREATE TABLE [core].[User](
  [UserId]       [bigint] IDENTITY(1,1) NOT NULL,
  [FullName]     [nvarchar](100) NOT NULL,
  [CreatedAtUtc] [datetime2](3) NOT NULL,
  CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED ([UserId] ASC)
) ON [PRIMARY]
GO

/****** core.UserEmail ******/
CREATE TABLE [core].[UserEmail](
  [EmailId]       [bigint] IDENTITY(1,1) NOT NULL,
  [UserId]        [bigint] NOT NULL,
  [Email]         [nvarchar](100) NOT NULL,
  [IsPrimary]     [bit] NOT NULL,
  [AddedAtUtc]    [datetime2](3) NOT NULL,
  [VerifiedAtUtc] [datetime2](3) NULL,
  [StatusCode]    [varchar](30) NOT NULL,
  [StatusDomain]  AS (CONVERT([varchar](50),'USER_EMAIL')) PERSISTED,
  CONSTRAINT [PK_UserEmail] PRIMARY KEY CLUSTERED ([EmailId] ASC),
  CONSTRAINT [UQ_UserEmail_Email] UNIQUE NONCLUSTERED ([Email] ASC)
) ON [PRIMARY]
GO

/****** core.UserRole ******/
CREATE TABLE [core].[UserRole](
  [UserId]        [bigint] NOT NULL,
  [RoleId]        [bigint] NOT NULL,
  [AsignacionUtc] [datetime2](3) NOT NULL,
  CONSTRAINT [PK_UserRole] PRIMARY KEY CLUSTERED ([UserId] ASC, [RoleId] ASC)
) ON [PRIMARY]
GO

/****** core.Wallet ******/
CREATE TABLE [core].[Wallet](
  [WalletId]    [bigint] IDENTITY(1,1) NOT NULL,
  [UserId]      [bigint] NOT NULL,
  [BalanceETH]  [decimal](38, 18) NOT NULL,
  [ReservedETH] [decimal](38, 18) NOT NULL,
  [UpdatedAtUtc][datetime2](3) NOT NULL,
  CONSTRAINT [PK_Wallet] PRIMARY KEY CLUSTERED ([WalletId] ASC),
  CONSTRAINT [UQ_Wallet_User] UNIQUE NONCLUSTERED ([UserId] ASC)
) ON [PRIMARY]
GO

/****** finance.FundsReservation ******/
CREATE TABLE [finance].[FundsReservation](
  [ReservationId] [bigint] IDENTITY(1,1) NOT NULL,
  [UserId]        [bigint] NOT NULL,
  [AuctionId]     [bigint] NOT NULL,
  [BidId]         [bigint] NULL,
  [AmountETH]     [decimal](38, 18) NOT NULL,
  [StateCode]     [varchar](30) NOT NULL,
  [StatusDomain]  AS (CONVERT([varchar](50),'FUNDS_RESERVATION')) PERSISTED,
  [CreatedAtUtc]  [datetime2](3) NOT NULL,
  [UpdatedAtUtc]  [datetime2](3) NOT NULL,
  CONSTRAINT [PK_FundsReservation] PRIMARY KEY CLUSTERED ([ReservationId] ASC)
) ON [PRIMARY]
GO

/****** finance.Ledger ******/
CREATE TABLE [finance].[Ledger](
  [EntryId]     [bigint] IDENTITY(1,1) NOT NULL,
  [UserId]      [bigint] NOT NULL,
  [AuctionId]   [bigint] NOT NULL,
  [EntryType]   [varchar](10) NOT NULL,
  [AmountETH]   [decimal](38, 18) NOT NULL,
  [Description] [nvarchar](200) NULL,
  [CreatedAtUtc][datetime2](3) NOT NULL,
  CONSTRAINT [PK_Ledger] PRIMARY KEY CLUSTERED ([EntryId] ASC)
) ON [PRIMARY]
GO

/****** nft.NFT ******/
CREATE TABLE [nft].[NFT](
  [NFTId]             [bigint] IDENTITY(1,1) NOT NULL,
  [ArtistId]          [bigint] NOT NULL,
  [CurrentOwnerId]    [bigint] NULL,
  [Name]              [nvarchar](160) NOT NULL,
  [Description]       [nvarchar](max) NULL,
  [ContentType]       [nvarchar](100) NOT NULL,
  [HashCode]          [char](64) NOT NULL,
  [FileSizeBytes]     [bigint] NULL,
  [WidthPx]           [int] NULL,
  [HeightPx]          [int] NULL,
  [SuggestedPriceETH] [decimal](38, 18) NULL,
  [StatusCode]        [varchar](30) NOT NULL,
  [StatusDomain]      AS (CONVERT([varchar](50),'NFT')) PERSISTED,
  [CreatedAtUtc]      [datetime2](3) NOT NULL,
  [ApprovedAtUtc]     [datetime2](3) NULL,
  CONSTRAINT [PK_NFT] PRIMARY KEY CLUSTERED ([NFTId] ASC),
  CONSTRAINT [UQ_NFT_Hash] UNIQUE NONCLUSTERED ([HashCode] ASC)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** ops.Settings ******/
CREATE TABLE [ops].[Settings](
  [SettingKey]   [sysname] NOT NULL,
  [SettingValue] [nvarchar](200) NOT NULL,
  [UpdatedAtUtc] [datetime2](3) NOT NULL,
  CONSTRAINT [PK_Settings] PRIMARY KEY CLUSTERED ([SettingKey] ASC)
) ON [PRIMARY]
GO

/****** ops.Status ******/
CREATE TABLE [ops].[Status](
  [StatusId]    [int] IDENTITY(1,1) NOT NULL,
  [Domain]      [varchar](50) NOT NULL,
  [Code]        [varchar](30) NOT NULL,
  [Description] [nvarchar](200) NULL,
  CONSTRAINT [PK_Status] PRIMARY KEY CLUSTERED ([StatusId] ASC),
  CONSTRAINT [UQ_Status_Domain_Code] UNIQUE NONCLUSTERED ([Domain] ASC, [Code] ASC)
) ON [PRIMARY]
GO

/* =========================================================
   DEFAULTS
========================================================= */

ALTER TABLE [admin].[CurationReview] ADD  DEFAULT (sysutcdatetime()) FOR [StartedAtUtc]
GO

ALTER TABLE [auction].[Auction] ADD  DEFAULT ('ACTIVE') FOR [StatusCode]
GO

ALTER TABLE [auction].[Bid] ADD  DEFAULT (sysutcdatetime()) FOR [PlacedAtUtc]
GO

ALTER TABLE [audit].[EmailOutbox] ADD  DEFAULT ('PENDING') FOR [StatusCode]
GO

ALTER TABLE [audit].[EmailOutbox] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO

ALTER TABLE [core].[User] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO

ALTER TABLE [core].[UserEmail] ADD  DEFAULT ((0)) FOR [IsPrimary]
GO

ALTER TABLE [core].[UserEmail] ADD  DEFAULT (sysutcdatetime()) FOR [AddedAtUtc]
GO

ALTER TABLE [core].[UserEmail] ADD  DEFAULT ('ACTIVE') FOR [StatusCode]
GO

ALTER TABLE [core].[UserRole] ADD  DEFAULT (sysutcdatetime()) FOR [AsignacionUtc]
GO

ALTER TABLE [core].[Wallet] ADD  DEFAULT ((0)) FOR [BalanceETH]
GO

ALTER TABLE [core].[Wallet] ADD  DEFAULT ((0)) FOR [ReservedETH]
GO

ALTER TABLE [core].[Wallet] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
GO

ALTER TABLE [finance].[FundsReservation] ADD  DEFAULT ('ACTIVE') FOR [StateCode]
GO

ALTER TABLE [finance].[FundsReservation] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO

ALTER TABLE [finance].[FundsReservation] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
GO

ALTER TABLE [finance].[Ledger] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO

ALTER TABLE [nft].[NFT] ADD  DEFAULT ('PENDING') FOR [StatusCode]
GO

ALTER TABLE [nft].[NFT] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
GO

ALTER TABLE [ops].[Settings] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
GO

/* =========================================================
   FOREIGN KEYS
========================================================= */

-- CurationReview
ALTER TABLE [admin].[CurationReview]  WITH CHECK ADD CONSTRAINT [FK_CReview_Curator] FOREIGN KEY([CuratorId]) REFERENCES [core].[User] ([UserId]);
ALTER TABLE [admin].[CurationReview] CHECK CONSTRAINT [FK_CReview_Curator];
ALTER TABLE [admin].[CurationReview]  WITH CHECK ADD CONSTRAINT [FK_CReview_NFT]     FOREIGN KEY([NFTId])     REFERENCES [nft].[NFT]  ([NFTId]);
ALTER TABLE [admin].[CurationReview] CHECK CONSTRAINT [FK_CReview_NFT];
ALTER TABLE [admin].[CurationReview]  WITH CHECK ADD CONSTRAINT [FK_CurationReview_Status] FOREIGN KEY([StatusDomain], [DecisionCode]) REFERENCES [ops].[Status] ([Domain], [Code]);
ALTER TABLE [admin].[CurationReview] CHECK CONSTRAINT [FK_CurationReview_Status];
GO

-- Auction
ALTER TABLE [auction].[Auction] WITH CHECK ADD CONSTRAINT [FK_Auction_Leader] FOREIGN KEY([CurrentLeaderId]) REFERENCES [core].[User] ([UserId]);
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [FK_Auction_Leader];
ALTER TABLE [auction].[Auction] WITH CHECK ADD CONSTRAINT [FK_Auction_NFT]    FOREIGN KEY([NFTId]) REFERENCES [nft].[NFT] ([NFTId]);
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [FK_Auction_NFT];
ALTER TABLE [auction].[Auction] WITH CHECK ADD CONSTRAINT [FK_Auction_Status] FOREIGN KEY([StatusDomain], [StatusCode]) REFERENCES [ops].[Status] ([Domain], [Code]);
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [FK_Auction_Status];
GO

-- Bid
ALTER TABLE [auction].[Bid] WITH CHECK ADD CONSTRAINT [FK_Bid_Auction] FOREIGN KEY([AuctionId]) REFERENCES [auction].[Auction] ([AuctionId]);
ALTER TABLE [auction].[Bid] CHECK CONSTRAINT [FK_Bid_Auction];
ALTER TABLE [auction].[Bid] WITH CHECK ADD CONSTRAINT [FK_Bid_User]    FOREIGN KEY([BidderId])  REFERENCES [core].[User]    ([UserId]);
ALTER TABLE [auction].[Bid] CHECK CONSTRAINT [FK_Bid_User];
GO

-- EmailOutbox
ALTER TABLE [audit].[EmailOutbox] WITH CHECK ADD CONSTRAINT [FK_EmailOutbox_Status] FOREIGN KEY([StatusDomain], [StatusCode]) REFERENCES [ops].[Status] ([Domain], [Code]);
ALTER TABLE [audit].[EmailOutbox] CHECK CONSTRAINT [FK_EmailOutbox_Status];
ALTER TABLE [audit].[EmailOutbox] WITH CHECK ADD CONSTRAINT [FK_EmailOutbox_User]   FOREIGN KEY([RecipientUserId]) REFERENCES [core].[User] ([UserId]);
ALTER TABLE [audit].[EmailOutbox] CHECK CONSTRAINT [FK_EmailOutbox_User];
GO

-- UserEmail
ALTER TABLE [core].[UserEmail] WITH CHECK ADD CONSTRAINT [FK_UserEmail_Status] FOREIGN KEY([StatusDomain], [StatusCode]) REFERENCES [ops].[Status] ([Domain], [Code]);
ALTER TABLE [core].[UserEmail] CHECK CONSTRAINT [FK_UserEmail_Status];
ALTER TABLE [core].[UserEmail] WITH CHECK ADD CONSTRAINT [FK_UserEmail_User]   FOREIGN KEY([UserId]) REFERENCES [core].[User] ([UserId]);
ALTER TABLE [core].[UserEmail] CHECK CONSTRAINT [FK_UserEmail_User];
GO

-- UserRole
ALTER TABLE [core].[UserRole] WITH CHECK ADD CONSTRAINT [FK_UserRole_Role] FOREIGN KEY([RoleId]) REFERENCES [core].[Role] ([RoleId]);
ALTER TABLE [core].[UserRole] CHECK CONSTRAINT [FK_UserRole_Role];
ALTER TABLE [core].[UserRole] WITH CHECK ADD CONSTRAINT [FK_UserRole_User] FOREIGN KEY([UserId]) REFERENCES [core].[User] ([UserId]);
ALTER TABLE [core].[UserRole] CHECK CONSTRAINT [FK_UserRole_User];
GO

-- Wallet
ALTER TABLE [core].[Wallet] WITH CHECK ADD CONSTRAINT [FK_Wallet_User] FOREIGN KEY([UserId]) REFERENCES [core].[User] ([UserId]);
ALTER TABLE [core].[Wallet] CHECK CONSTRAINT [FK_Wallet_User];
GO

-- FundsReservation
ALTER TABLE [finance].[FundsReservation] WITH CHECK ADD CONSTRAINT [FK_FRes_Auction] FOREIGN KEY([AuctionId]) REFERENCES [auction].[Auction] ([AuctionId]);
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [FK_FRes_Auction];
ALTER TABLE [finance].[FundsReservation] WITH CHECK ADD CONSTRAINT [FK_FRes_Bid]     FOREIGN KEY([BidId])    REFERENCES [auction].[Bid]    ([BidId]);
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [FK_FRes_Bid];
ALTER TABLE [finance].[FundsReservation] WITH CHECK ADD CONSTRAINT [FK_FRes_Status]  FOREIGN KEY([StatusDomain], [StateCode]) REFERENCES [ops].[Status] ([Domain], [Code]);
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [FK_FRes_Status];
ALTER TABLE [finance].[FundsReservation] WITH CHECK ADD CONSTRAINT [FK_FRes_User]    FOREIGN KEY([UserId])   REFERENCES [core].[User] ([UserId]);
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [FK_FRes_User];
GO

-- Ledger
ALTER TABLE [finance].[Ledger] WITH CHECK ADD CONSTRAINT [FK_Ledger_Auction] FOREIGN KEY([AuctionId]) REFERENCES [auction].[Auction] ([AuctionId]);
ALTER TABLE [finance].[Ledger] CHECK CONSTRAINT [FK_Ledger_Auction];
ALTER TABLE [finance].[Ledger] WITH CHECK ADD CONSTRAINT [FK_Ledger_User]    FOREIGN KEY([UserId])   REFERENCES [core].[User] ([UserId]);
ALTER TABLE [finance].[Ledger] CHECK CONSTRAINT [FK_Ledger_User];
GO

-- NFT
ALTER TABLE [nft].[NFT] WITH CHECK ADD CONSTRAINT [FK_NFT_Artist] FOREIGN KEY([ArtistId])       REFERENCES [core].[User] ([UserId]);
ALTER TABLE [nft].[NFT] CHECK CONSTRAINT [FK_NFT_Artist];
ALTER TABLE [nft].[NFT] WITH CHECK ADD CONSTRAINT [FK_NFT_Owner]  FOREIGN KEY([CurrentOwnerId]) REFERENCES [core].[User] ([UserId]);
ALTER TABLE [nft].[NFT] CHECK CONSTRAINT [FK_NFT_Owner];
ALTER TABLE [nft].[NFT] WITH CHECK ADD CONSTRAINT [FK_NFT_Status] FOREIGN KEY([StatusDomain], [StatusCode]) REFERENCES [ops].[Status] ([Domain], [Code]);
ALTER TABLE [nft].[NFT] CHECK CONSTRAINT [FK_NFT_Status];
GO

/* =========================================================
   CHECK CONSTRAINTS
========================================================= */

ALTER TABLE [admin].[CurationReview]
  WITH CHECK ADD CONSTRAINT [CK_CReview_Times]
  CHECK ( [ReviewedAtUtc] IS NULL OR [ReviewedAtUtc] >= [StartedAtUtc] );
ALTER TABLE [admin].[CurationReview] CHECK CONSTRAINT [CK_CReview_Times];
GO

ALTER TABLE [auction].[Auction]
  WITH CHECK ADD CONSTRAINT [CK_Auction_Dates]
  CHECK ( [EndAtUtc] > [StartAtUtc] );
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [CK_Auction_Dates];
GO

ALTER TABLE [auction].[Auction]
  WITH CHECK ADD CONSTRAINT [CK_Auction_Prices]
  CHECK ( [StartingPriceETH] > (0) AND [CurrentPriceETH] >= [StartingPriceETH] );
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [CK_Auction_Prices];
GO

ALTER TABLE [auction].[Bid]
  WITH CHECK ADD CONSTRAINT [CK_Bid_Positive]
  CHECK ( [AmountETH] > (0) );
ALTER TABLE [auction].[Bid] CHECK CONSTRAINT [CK_Bid_Positive];
GO

ALTER TABLE [core].[Wallet]
  WITH CHECK ADD CONSTRAINT [CK_Wallet_Positive]
  CHECK ( [BalanceETH] >= (0) AND [ReservedETH] >= (0) );
ALTER TABLE [core].[Wallet] CHECK CONSTRAINT [CK_Wallet_Positive];
GO

ALTER TABLE [finance].[FundsReservation]
  WITH CHECK ADD CONSTRAINT [CK_FRes_Positive]
  CHECK ( [AmountETH] > (0) );
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [CK_FRes_Positive];
GO

ALTER TABLE [finance].[Ledger]
  WITH CHECK ADD CONSTRAINT [CK_Ledger_Positive]
  CHECK ( [AmountETH] > (0) );
ALTER TABLE [finance].[Ledger] CHECK CONSTRAINT [CK_Ledger_Positive];
GO

ALTER TABLE [finance].[Ledger]
  WITH CHECK ADD CONSTRAINT [CK_Ledger_Type]
  CHECK ( [EntryType] = 'CREDIT' OR [EntryType] = 'DEBIT' );
ALTER TABLE [finance].[Ledger] CHECK CONSTRAINT [CK_Ledger_Type];
GO

/* =========================================================
   ÍNDICES ADICIONALES (DISEÑO / RENDIMIENTO)
========================================================= */

-- Email principal por usuario (regla de negocio)
CREATE UNIQUE INDEX [UX_UserEmail_PrimaryPerUser]
  ON [core].[UserEmail]([UserId])
  WHERE [IsPrimary] = 1;
GO

-- (Opcional) Una sola reserva ACTIVA por usuario y subasta
CREATE UNIQUE INDEX [UX_FRes_UserAuction_Active]
  ON [finance].[FundsReservation]([UserId], [AuctionId])
  WHERE [StateCode] = 'ACTIVE';
GO

-- Recomendados para reportes
CREATE INDEX [IX_Auction_Status_End]
  ON [auction].[Auction]([StatusCode], [EndAtUtc])
  INCLUDE([NFTId], [CurrentPriceETH], [CurrentLeaderId]);
GO

CREATE INDEX [IX_Bid_Auction]
  ON [auction].[Bid]([AuctionId], [AmountETH] DESC, [PlacedAtUtc] ASC)
  INCLUDE([BidderId]);
GO

CREATE INDEX [IX_Bid_User]
  ON [auction].[Bid]([BidderId], [PlacedAtUtc])
  INCLUDE([AuctionId], [AmountETH]);
GO

CREATE INDEX [IX_FRes_AuctionState]
  ON [finance].[FundsReservation]([AuctionId], [StateCode])
  INCLUDE([UserId], [AmountETH]);
GO

CREATE INDEX [IX_FRes_UserState]
  ON [finance].[FundsReservation]([UserId], [StateCode])
  INCLUDE([AuctionId], [AmountETH]);
GO

CREATE INDEX [IX_Ledger_UserTime]
  ON [finance].[Ledger]([UserId], [CreatedAtUtc])
  INCLUDE([EntryType], [AmountETH], [AuctionId]);
GO

CREATE INDEX [IX_NFT_Artist]
  ON [nft].[NFT]([ArtistId], [CreatedAtUtc]);
GO

CREATE INDEX [IX_CReview_NFT]
  ON [admin].[CurationReview]([NFTId], [ReviewedAtUtc]);
GO

-- Útil para “dispatcher” de correos
CREATE INDEX [IX_EmailOutbox_Pending]
  ON [audit].[EmailOutbox]([StatusCode])
  WHERE [StatusCode] = 'PENDING';
GO

-- Status base (Domain, Code, Desc)

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
