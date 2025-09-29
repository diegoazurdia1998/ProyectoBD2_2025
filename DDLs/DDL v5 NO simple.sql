USE [ArteCryptoAuctions]
GO
/****** Object:  Schema [admin]    Script Date: 29/09/2025 16:04:06 ******/
CREATE SCHEMA [admin]
GO
/****** Object:  Schema [auction]    Script Date: 29/09/2025 16:04:06 ******/
CREATE SCHEMA [auction]
GO
/****** Object:  Schema [audit]    Script Date: 29/09/2025 16:04:06 ******/
CREATE SCHEMA [audit]
GO
/****** Object:  Schema [core]    Script Date: 29/09/2025 16:04:06 ******/
CREATE SCHEMA [core]
GO
/****** Object:  Schema [finance]    Script Date: 29/09/2025 16:04:06 ******/
CREATE SCHEMA [finance]
GO
/****** Object:  Schema [nft]    Script Date: 29/09/2025 16:04:06 ******/
CREATE SCHEMA [nft]
GO
/****** Object:  Schema [ops]    Script Date: 29/09/2025 16:04:06 ******/
CREATE SCHEMA [ops]
GO
/****** Object:  Table [admin].[CurationReview]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [admin].[CurationReview](
	[ReviewId] [bigint] IDENTITY(1,1) NOT NULL,
	[NFTId] [bigint] NOT NULL,
	[CuratorId] [bigint] NOT NULL,
	[DecisionCode] [varchar](30) NOT NULL,
	[StatusDomain]  AS (CONVERT([varchar](50),'CURATION_DECISION')) PERSISTED,
	[Comment] [nvarchar](max) NULL,
	[StartedAtUtc] [datetime2](3) NOT NULL,
	[ReviewedAtUtc] [datetime2](3) NULL,
 CONSTRAINT [PK_CurationReview] PRIMARY KEY CLUSTERED 
(
	[ReviewId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [auction].[Auction]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [auction].[Auction](
	[AuctionId] [bigint] IDENTITY(1,1) NOT NULL,
	[SettingsID] [int] NULL,
	[NFTId] [bigint] NOT NULL,
	[StartAtUtc] [datetime2](3) NOT NULL,
	[EndAtUtc] [datetime2](3) NOT NULL,
	[StartingPriceETH] [decimal](38, 18) NOT NULL,
	[CurrentPriceETH] [decimal](38, 18) NOT NULL,
	[CurrentLeaderId] [bigint] NULL,
	[StatusCode] [varchar](30) NOT NULL,
	[StatusDomain]  AS (CONVERT([varchar](50),'AUCTION')) PERSISTED,
 CONSTRAINT [PK_Auction] PRIMARY KEY CLUSTERED 
(
	[AuctionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Auction_NFT] UNIQUE NONCLUSTERED 
(
	[NFTId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [auction].[Bid]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [auction].[Bid](
	[BidId] [bigint] IDENTITY(1,1) NOT NULL,
	[AuctionId] [bigint] NOT NULL,
	[BidderId] [bigint] NOT NULL,
	[AmountETH] [decimal](38, 18) NOT NULL,
	[PlacedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_Bid] PRIMARY KEY CLUSTERED 
(
	[BidId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [audit].[EmailOutbox]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [audit].[EmailOutbox](
	[EmailId] [bigint] IDENTITY(1,1) NOT NULL,
	[RecipientUserId] [bigint] NULL,
	[RecipientEmail] [nvarchar](100) NULL,
	[Subject] [nvarchar](200) NOT NULL,
	[Body] [nvarchar](max) NOT NULL,
	[StatusCode] [varchar](30) NOT NULL,
	[StatusDomain]  AS (CONVERT([varchar](50),'EMAIL_OUTBOX')) PERSISTED,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[SentAtUtc] [datetime2](3) NULL,
	[CorrelationKey] [nvarchar](100) NULL,
 CONSTRAINT [PK_EmailOutbox] PRIMARY KEY CLUSTERED 
(
	[EmailId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [core].[Role]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [core].[Role](
	[RoleId] [bigint] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_Role] PRIMARY KEY CLUSTERED 
(
	[RoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Role_Name] UNIQUE NONCLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [core].[User]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [core].[User](
	[UserId] [bigint] IDENTITY(1,1) NOT NULL,
	[FullName] [nvarchar](100) NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [core].[UserEmail]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [core].[UserEmail](
	[EmailId] [bigint] IDENTITY(1,1) NOT NULL,
	[UserId] [bigint] NOT NULL,
	[Email] [nvarchar](100) NOT NULL,
	[IsPrimary] [bit] NOT NULL,
	[AddedAtUtc] [datetime2](3) NOT NULL,
	[VerifiedAtUtc] [datetime2](3) NULL,
	[StatusCode] [varchar](30) NOT NULL,
	[StatusDomain]  AS (CONVERT([varchar](50),'USER_EMAIL')) PERSISTED,
 CONSTRAINT [PK_UserEmail] PRIMARY KEY CLUSTERED 
(
	[EmailId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_UserEmail_Email] UNIQUE NONCLUSTERED 
(
	[Email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [core].[UserRole]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [core].[UserRole](
	[UserId] [bigint] NOT NULL,
	[RoleId] [bigint] NOT NULL,
	[AsignacionUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_UserRole] PRIMARY KEY CLUSTERED 
(
	[UserId] ASC,
	[RoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [core].[Wallet]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [core].[Wallet](
	[WalletId] [bigint] IDENTITY(1,1) NOT NULL,
	[UserId] [bigint] NOT NULL,
	[BalanceETH] [decimal](38, 18) NOT NULL,
	[ReservedETH] [decimal](38, 18) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_Wallet] PRIMARY KEY CLUSTERED 
(
	[WalletId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Wallet_User] UNIQUE NONCLUSTERED 
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AuctionSettings]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AuctionSettings](
	[SettingsID] [int] NOT NULL,
	[CompanyName] [varbinary](250) NOT NULL,
	[BasePriceETH] [decimal](38, 18) NOT NULL,
	[DefaultAuctionHours] [tinyint] NOT NULL,
	[MinBidIncrementPct] [tinyint] NOT NULL,
 CONSTRAINT [PK_AuctionSettings] PRIMARY KEY CLUSTERED 
(
	[SettingsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [finance].[FundsReservation]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [finance].[FundsReservation](
	[ReservationId] [bigint] IDENTITY(1,1) NOT NULL,
	[UserId] [bigint] NOT NULL,
	[AuctionId] [bigint] NOT NULL,
	[BidId] [bigint] NULL,
	[AmountETH] [decimal](38, 18) NOT NULL,
	[StateCode] [varchar](30) NOT NULL,
	[StatusDomain]  AS (CONVERT([varchar](50),'FUNDS_RESERVATION')) PERSISTED,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_FundsReservation] PRIMARY KEY CLUSTERED 
(
	[ReservationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [finance].[Ledger]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [finance].[Ledger](
	[EntryId] [bigint] IDENTITY(1,1) NOT NULL,
	[UserId] [bigint] NOT NULL,
	[AuctionId] [bigint] NOT NULL,
	[EntryType] [varchar](10) NOT NULL,
	[AmountETH] [decimal](38, 18) NOT NULL,
	[Description] [nvarchar](200) NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_Ledger] PRIMARY KEY CLUSTERED 
(
	[EntryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [nft].[NFT]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [nft].[NFT](
	[NFTId] [bigint] IDENTITY(1,1) NOT NULL,
	[ArtistId] [bigint] NOT NULL,
	[CurrentOwnerId] [bigint] NULL,
	[Name] [nvarchar](160) NOT NULL,
	[Description] [nvarchar](max) NULL,
	[ContentType] [nvarchar](100) NOT NULL,
	[HashCode] [char](64) NOT NULL,
	[FileSizeBytes] [bigint] NULL,
	[WidthPx] [int] NULL,
	[HeightPx] [int] NULL,
	[SuggestedPriceETH] [decimal](38, 18) NULL,
	[StatusCode] [varchar](30) NOT NULL,
	[StatusDomain]  AS (CONVERT([varchar](50),'NFT')) PERSISTED,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[ApprovedAtUtc] [datetime2](3) NULL,
 CONSTRAINT [PK_NFT] PRIMARY KEY CLUSTERED 
(
	[NFTId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_NFT_Hash] UNIQUE NONCLUSTERED 
(
	[HashCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [ops].[Settings]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [ops].[Settings](
	[SettingKey] [sysname] NOT NULL,
	[SettingValue] [nvarchar](200) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_Settings] PRIMARY KEY CLUSTERED 
(
	[SettingKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [ops].[Status]    Script Date: 29/09/2025 16:04:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [ops].[Status](
	[StatusId] [int] IDENTITY(1,1) NOT NULL,
	[Domain] [varchar](50) NOT NULL,
	[Code] [varchar](30) NOT NULL,
	[Description] [nvarchar](200) NULL,
 CONSTRAINT [PK_Status] PRIMARY KEY CLUSTERED 
(
	[StatusId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Status_Domain_Code] UNIQUE NONCLUSTERED 
(
	[Domain] ASC,
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [admin].[CurationReview] ADD  DEFAULT (sysutcdatetime()) FOR [StartedAtUtc]
GO
ALTER TABLE [auction].[Auction] ADD  CONSTRAINT [DF__Auction__StatusC__571DF1D5]  DEFAULT ('ACTIVE') FOR [StatusCode]
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
ALTER TABLE [admin].[CurationReview]  WITH CHECK ADD  CONSTRAINT [FK_CReview_Curator] FOREIGN KEY([CuratorId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [admin].[CurationReview] CHECK CONSTRAINT [FK_CReview_Curator]
GO
ALTER TABLE [admin].[CurationReview]  WITH CHECK ADD  CONSTRAINT [FK_CReview_NFT] FOREIGN KEY([NFTId])
REFERENCES [nft].[NFT] ([NFTId])
GO
ALTER TABLE [admin].[CurationReview] CHECK CONSTRAINT [FK_CReview_NFT]
GO
ALTER TABLE [admin].[CurationReview]  WITH CHECK ADD  CONSTRAINT [FK_CurationReview_Status] FOREIGN KEY([StatusDomain], [DecisionCode])
REFERENCES [ops].[Status] ([Domain], [Code])
GO
ALTER TABLE [admin].[CurationReview] CHECK CONSTRAINT [FK_CurationReview_Status]
GO
ALTER TABLE [auction].[Auction]  WITH CHECK ADD  CONSTRAINT [FK_Auction_AuctionSettings] FOREIGN KEY([SettingsID])
REFERENCES [dbo].[AuctionSettings] ([SettingsID])
GO
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [FK_Auction_AuctionSettings]
GO
ALTER TABLE [auction].[Auction]  WITH CHECK ADD  CONSTRAINT [FK_Auction_Leader] FOREIGN KEY([CurrentLeaderId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [FK_Auction_Leader]
GO
ALTER TABLE [auction].[Auction]  WITH CHECK ADD  CONSTRAINT [FK_Auction_NFT] FOREIGN KEY([NFTId])
REFERENCES [nft].[NFT] ([NFTId])
GO
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [FK_Auction_NFT]
GO
ALTER TABLE [auction].[Auction]  WITH CHECK ADD  CONSTRAINT [FK_Auction_Status] FOREIGN KEY([StatusDomain], [StatusCode])
REFERENCES [ops].[Status] ([Domain], [Code])
GO
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [FK_Auction_Status]
GO
ALTER TABLE [auction].[Bid]  WITH CHECK ADD  CONSTRAINT [FK_Bid_Auction] FOREIGN KEY([AuctionId])
REFERENCES [auction].[Auction] ([AuctionId])
GO
ALTER TABLE [auction].[Bid] CHECK CONSTRAINT [FK_Bid_Auction]
GO
ALTER TABLE [auction].[Bid]  WITH CHECK ADD  CONSTRAINT [FK_Bid_User] FOREIGN KEY([BidderId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [auction].[Bid] CHECK CONSTRAINT [FK_Bid_User]
GO
ALTER TABLE [audit].[EmailOutbox]  WITH CHECK ADD  CONSTRAINT [FK_EmailOutbox_Status] FOREIGN KEY([StatusDomain], [StatusCode])
REFERENCES [ops].[Status] ([Domain], [Code])
GO
ALTER TABLE [audit].[EmailOutbox] CHECK CONSTRAINT [FK_EmailOutbox_Status]
GO
ALTER TABLE [audit].[EmailOutbox]  WITH CHECK ADD  CONSTRAINT [FK_EmailOutbox_User] FOREIGN KEY([RecipientUserId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [audit].[EmailOutbox] CHECK CONSTRAINT [FK_EmailOutbox_User]
GO
ALTER TABLE [core].[UserEmail]  WITH CHECK ADD  CONSTRAINT [FK_UserEmail_Status] FOREIGN KEY([StatusDomain], [StatusCode])
REFERENCES [ops].[Status] ([Domain], [Code])
GO
ALTER TABLE [core].[UserEmail] CHECK CONSTRAINT [FK_UserEmail_Status]
GO
ALTER TABLE [core].[UserEmail]  WITH CHECK ADD  CONSTRAINT [FK_UserEmail_User] FOREIGN KEY([UserId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [core].[UserEmail] CHECK CONSTRAINT [FK_UserEmail_User]
GO
ALTER TABLE [core].[UserRole]  WITH CHECK ADD  CONSTRAINT [FK_UserRole_Role] FOREIGN KEY([RoleId])
REFERENCES [core].[Role] ([RoleId])
GO
ALTER TABLE [core].[UserRole] CHECK CONSTRAINT [FK_UserRole_Role]
GO
ALTER TABLE [core].[UserRole]  WITH CHECK ADD  CONSTRAINT [FK_UserRole_User] FOREIGN KEY([UserId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [core].[UserRole] CHECK CONSTRAINT [FK_UserRole_User]
GO
ALTER TABLE [core].[Wallet]  WITH CHECK ADD  CONSTRAINT [FK_Wallet_User] FOREIGN KEY([UserId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [core].[Wallet] CHECK CONSTRAINT [FK_Wallet_User]
GO
ALTER TABLE [finance].[FundsReservation]  WITH CHECK ADD  CONSTRAINT [FK_FRes_Auction] FOREIGN KEY([AuctionId])
REFERENCES [auction].[Auction] ([AuctionId])
GO
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [FK_FRes_Auction]
GO
ALTER TABLE [finance].[FundsReservation]  WITH CHECK ADD  CONSTRAINT [FK_FRes_Bid] FOREIGN KEY([BidId])
REFERENCES [auction].[Bid] ([BidId])
GO
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [FK_FRes_Bid]
GO
ALTER TABLE [finance].[FundsReservation]  WITH CHECK ADD  CONSTRAINT [FK_FRes_Status] FOREIGN KEY([StatusDomain], [StateCode])
REFERENCES [ops].[Status] ([Domain], [Code])
GO
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [FK_FRes_Status]
GO
ALTER TABLE [finance].[FundsReservation]  WITH CHECK ADD  CONSTRAINT [FK_FRes_User] FOREIGN KEY([UserId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [FK_FRes_User]
GO
ALTER TABLE [finance].[Ledger]  WITH CHECK ADD  CONSTRAINT [FK_Ledger_Auction] FOREIGN KEY([AuctionId])
REFERENCES [auction].[Auction] ([AuctionId])
GO
ALTER TABLE [finance].[Ledger] CHECK CONSTRAINT [FK_Ledger_Auction]
GO
ALTER TABLE [finance].[Ledger]  WITH CHECK ADD  CONSTRAINT [FK_Ledger_User] FOREIGN KEY([UserId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [finance].[Ledger] CHECK CONSTRAINT [FK_Ledger_User]
GO
ALTER TABLE [nft].[NFT]  WITH CHECK ADD  CONSTRAINT [FK_NFT_Artist] FOREIGN KEY([ArtistId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [nft].[NFT] CHECK CONSTRAINT [FK_NFT_Artist]
GO
ALTER TABLE [nft].[NFT]  WITH CHECK ADD  CONSTRAINT [FK_NFT_Owner] FOREIGN KEY([CurrentOwnerId])
REFERENCES [core].[User] ([UserId])
GO
ALTER TABLE [nft].[NFT] CHECK CONSTRAINT [FK_NFT_Owner]
GO
ALTER TABLE [nft].[NFT]  WITH CHECK ADD  CONSTRAINT [FK_NFT_Status] FOREIGN KEY([StatusDomain], [StatusCode])
REFERENCES [ops].[Status] ([Domain], [Code])
GO
ALTER TABLE [nft].[NFT] CHECK CONSTRAINT [FK_NFT_Status]
GO
ALTER TABLE [admin].[CurationReview]  WITH CHECK ADD  CONSTRAINT [CK_CReview_Times] CHECK  (([ReviewedAtUtc] IS NULL OR [ReviewedAtUtc]>=[StartedAtUtc]))
GO
ALTER TABLE [admin].[CurationReview] CHECK CONSTRAINT [CK_CReview_Times]
GO
ALTER TABLE [auction].[Auction]  WITH CHECK ADD  CONSTRAINT [CK_Auction_Dates] CHECK  (([EndAtUtc]>[StartAtUtc]))
GO
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [CK_Auction_Dates]
GO
ALTER TABLE [auction].[Auction]  WITH CHECK ADD  CONSTRAINT [CK_Auction_Prices] CHECK  (([StartingPriceETH]>(0) AND [CurrentPriceETH]>=[StartingPriceETH]))
GO
ALTER TABLE [auction].[Auction] CHECK CONSTRAINT [CK_Auction_Prices]
GO
ALTER TABLE [auction].[Bid]  WITH CHECK ADD  CONSTRAINT [CK_Bid_Positive] CHECK  (([AmountETH]>(0)))
GO
ALTER TABLE [auction].[Bid] CHECK CONSTRAINT [CK_Bid_Positive]
GO
ALTER TABLE [core].[Wallet]  WITH CHECK ADD  CONSTRAINT [CK_Wallet_Positive] CHECK  (([BalanceETH]>=(0) AND [ReservedETH]>=(0)))
GO
ALTER TABLE [core].[Wallet] CHECK CONSTRAINT [CK_Wallet_Positive]
GO
ALTER TABLE [finance].[FundsReservation]  WITH CHECK ADD  CONSTRAINT [CK_FRes_Positive] CHECK  (([AmountETH]>(0)))
GO
ALTER TABLE [finance].[FundsReservation] CHECK CONSTRAINT [CK_FRes_Positive]
GO
ALTER TABLE [finance].[Ledger]  WITH CHECK ADD  CONSTRAINT [CK_Ledger_Positive] CHECK  (([AmountETH]>(0)))
GO
ALTER TABLE [finance].[Ledger] CHECK CONSTRAINT [CK_Ledger_Positive]
GO
ALTER TABLE [finance].[Ledger]  WITH CHECK ADD  CONSTRAINT [CK_Ledger_Type] CHECK  (([EntryType]='CREDIT' OR [EntryType]='DEBIT'))
GO
ALTER TABLE [finance].[Ledger] CHECK CONSTRAINT [CK_Ledger_Type]
GO
