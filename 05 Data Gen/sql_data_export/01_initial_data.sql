/* FASE 1: DATOS INICIALES (Catálogos y Configuración) */
USE ArteCryptoAuctions;
GO

-- Data for [ops].[Status]
SET IDENTITY_INSERT [ops].[Status] ON;
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES
  (1, N'NFT', N'PENDING', N'NFT en revisión'),
  (2, N'NFT', N'APPROVED', N'NFT aprobado'),
  (3, N'NFT', N'REJECTED', N'NFT rechazado'),
  (4, N'AUCTION', N'ACTIVE', N'Subasta activa'),
  (5, N'AUCTION', N'COMPLETED', N'Subasta completada'),
  (6, N'AUCTION', N'CANCELLED', N'Subasta cancelada'),
  (7, N'FUNDS_RESERVATION', N'ACTIVE', N'Reserva activa'),
  (8, N'FUNDS_RESERVATION', N'RELEASED', N'Reserva liberada'),
  (9, N'FUNDS_RESERVATION', N'CAPTURED', N'Reserva capturada/cobrada'),
  (10, N'USER_EMAIL', N'ACTIVE', N'Email activo'),
  (11, N'USER_EMAIL', N'INACTIVE', N'Email inactivo'),
  (12, N'EMAIL_OUTBOX', N'PENDING', N'Correo en cola'),
  (13, N'EMAIL_OUTBOX', N'SENT', N'Correo enviado'),
  (14, N'EMAIL_OUTBOX', N'FAILED', N'Fallo de envío'),
  (15, N'CURATION_DECISION', N'PENDING', N'Pendiente de revisión'),
  (16, N'CURATION_DECISION', N'APPROVED', N'Aprobado por curador'),
  (17, N'CURATION_DECISION', N'REJECTED', N'Rechazado por curador');
SET IDENTITY_INSERT [ops].[Status] OFF;
GO

-- Data for [core].[Role]
SET IDENTITY_INSERT [core].[Role] ON;
INSERT INTO [core].[Role] ([RoleId], [Name]) VALUES
  (1, N'ADMIN'),
  (2, N'ARTIST'),
  (3, N'BIDDER'),
  (4, N'CURATOR');
SET IDENTITY_INSERT [core].[Role] OFF;
GO

-- Data for [nft].[NFTSettings]
INSERT INTO [nft].[NFTSettings] ([SettingsID], [MaxWidthPx], [MinWidthPx], [MaxHeightPx], [MinHeigntPx], [MaxFileSizeBytes], [MinFileSizeBytes], [CreatedAtUtc]) VALUES
  (1, 4096, 512, 4096, 512, 10485760, 1024, N'2025-01-01 00:00:00.000');
GO

-- Data for [auction].[AuctionSettings]
INSERT INTO [auction].[AuctionSettings] ([SettingsID], [CompanyName], [BasePriceETH], [DefaultAuctionHours], [MinBidIncrementPct]) VALUES
  (1, N'ArteCrypto Auctions', 0.05, 72, 5);
GO
