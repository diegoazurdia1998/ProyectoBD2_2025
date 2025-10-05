-- =====================================================================================
-- SCRIPT DE INSERCIÓN DE DATOS - ArteCryptoAuctions
-- Generado: 2025-10-05 17:08:21
-- =====================================================================================

USE [ArteCryptoAuctions];
GO

SET NOCOUNT ON;
GO

-- =====================================================================================
-- ops.Status
-- =====================================================================================
PRINT 'Insertando datos en ops.Status...';
GO

INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (1, N'NFT', N'PENDING', N'NFT en revisión');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (2, N'NFT', N'APPROVED', N'NFT aprobado');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (3, N'NFT', N'REJECTED', N'NFT rechazado');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (4, N'AUCTION', N'ACTIVE', N'Subasta activa');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (5, N'AUCTION', N'COMPLETED', N'Subasta completada');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (6, N'AUCTION', N'CANCELLED', N'Subasta cancelada');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (7, N'FUNDS_RESERVATION', N'ACTIVE', N'Reserva activa');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (8, N'FUNDS_RESERVATION', N'RELEASED', N'Reserva liberada');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (9, N'FUNDS_RESERVATION', N'APPLIED', N'Reserva aplicada');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (10, N'USER_EMAIL', N'ACTIVE', N'Email activo');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (11, N'USER_EMAIL', N'INACTIVE', N'Email inactivo');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (12, N'EMAIL_OUTBOX', N'PENDING', N'Correo en cola');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (13, N'EMAIL_OUTBOX', N'SENT', N'Correo enviado');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (14, N'EMAIL_OUTBOX', N'FAILED', N'Fallo de envío');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (15, N'CURATION_DECISION', N'PENDING', N'Pendiente de revisión');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (16, N'CURATION_DECISION', N'APPROVED', N'Aprobado por curador');
INSERT INTO [ops].[Status] ([StatusId], [Domain], [Code], [Description]) VALUES (17, N'CURATION_DECISION', N'REJECTED', N'Rechazado por curador');

GO

-- =====================================================================================
-- core.Role
-- =====================================================================================
PRINT 'Insertando datos en core.Role...';
GO

INSERT INTO [core].[Role] ([RoleId], [Name]) VALUES (1, N'ADMIN');
INSERT INTO [core].[Role] ([RoleId], [Name]) VALUES (2, N'ARTIST');
INSERT INTO [core].[Role] ([RoleId], [Name]) VALUES (3, N'BIDDER');
INSERT INTO [core].[Role] ([RoleId], [Name]) VALUES (4, N'CURATOR');

GO

-- =====================================================================================
-- core.User
-- =====================================================================================
PRINT 'Insertando datos en core.User...';
GO

INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (1, N'Lucía Azurdia', '2025-04-17 19:27:32.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (2, N'Sofía Ramírez', '2025-02-24 04:35:15.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (3, N'Lucía Mendoza', '2025-02-03 18:19:43.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (4, N'Hugo Ortiz', '2025-01-13 08:14:09.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (5, N'Diego Martínez', '2025-03-26 21:51:13.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (6, N'Sofía Cruz', '2025-08-22 19:13:16.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (7, N'Diego Mendoza', '2025-03-19 05:18:04.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (8, N'Paola Ortiz', '2025-03-27 14:39:19.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (9, N'Jorge Romero', '2025-04-19 00:55:31.000');
INSERT INTO [core].[User] ([UserId], [FullName], [CreatedAtUtc]) VALUES (10, N'Diego Gómez', '2025-09-29 03:07:50.000');

GO

-- =====================================================================================
-- dbo.NFTSettings
-- =====================================================================================
PRINT 'Insertando datos en dbo.NFTSettings...';
GO

INSERT INTO [dbo].[NFTSettings] ([SettingsID], [MaxWidthPx], [MinWidthPx], [MaxHeightPx], [MinHeightPx], [MaxFileSizeBytes], [MinFileSizeBytes], [CreatedAtUtc]) VALUES 
(1, 4096, 512, 4096, 512, 10485760, 1024, '2025-01-01 00:00:00.000');

GO

-- =====================================================================================
-- auction.AuctionSettings
-- =====================================================================================
PRINT 'Insertando datos en auction.AuctionSettings...';
GO

INSERT INTO [auction].[AuctionSettings] ([SettingsID], [CompanyName], [BasePriceETH], [DefaultAuctionHours], [MinBidIncrementPct]) VALUES 
(1, N'ArteCrypto Auctions', 0.05000000, 72, 5);

GO

-- =====================================================================================
-- core.UserRole
-- =====================================================================================
PRINT 'Insertando datos en core.UserRole...';
GO

INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (1, 2, '2025-07-08 20:59:05.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (2, 1, '2025-07-06 07:57:07.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (2, 2, '2025-06-12 02:32:10.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (2, 3, '2025-04-25 13:45:41.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (3, 1, '2025-04-28 09:11:53.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (4, 3, '2025-05-24 01:31:27.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (5, 2, '2025-04-15 18:11:16.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (5, 3, '2025-04-13 22:04:50.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (6, 3, '2025-09-10 05:52:06.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (7, 3, '2025-04-25 18:45:47.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (8, 3, '2025-06-05 07:37:13.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (9, 1, '2025-09-30 14:32:07.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (9, 2, '2025-06-24 19:52:30.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (9, 3, '2025-08-14 06:29:33.000');
INSERT INTO [core].[UserRole] ([UserId], [RoleId], [AsignacionUtc]) VALUES (10, 3, '2025-09-29 22:23:32.000');

GO

-- =====================================================================================
-- core.UserEmail
-- =====================================================================================
PRINT 'Insertando datos en core.UserEmail...';
GO

INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (1, 1, N'lucia.azurdia6988@gmail.com', 1, '2025-09-21 12:56:57.000', NULL, N'INACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (2, 2, N'sofia.ramirez2708@outlook.com', 1, '2025-03-13 01:34:29.000', NULL, N'INACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (3, 3, N'lucia.mendoza9820@gmail.com', 1, '2025-08-01 04:28:43.000', '2025-09-22 05:58:50.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (4, 4, N'hugo.ortiz5910@uni.edu.gt', 1, '2025-03-02 19:41:59.000', '2025-07-27 19:53:45.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (5, 5, N'diego.martinez8033@yahoo.com', 1, '2025-04-11 05:05:20.000', '2025-07-27 09:47:04.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (6, 5, N'diego.martinez694@uni.edu.gt', 0, '2025-05-22 20:09:48.000', '2025-09-21 21:50:13.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (7, 6, N'sofia.cruz3112@outlook.com', 1, '2025-09-21 19:50:55.000', '2025-09-26 05:10:56.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (8, 6, N'sofia.cruz7421@gmail.com', 0, '2025-09-19 19:53:06.000', '2025-09-22 03:53:35.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (9, 7, N'diego.mendoza6958@yahoo.com', 1, '2025-04-15 05:36:07.000', '2025-04-24 03:09:32.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (10, 8, N'paola.ortiz6185@outlook.com', 1, '2025-08-03 00:21:56.000', '2025-08-25 03:24:25.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (11, 8, N'paola.ortiz1377@outlook.com', 0, '2025-08-24 17:24:53.000', '2025-09-07 18:34:34.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (12, 9, N'jorge.romero1804@uni.edu.gt', 1, '2025-05-04 12:46:58.000', '2025-06-18 17:40:00.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (13, 9, N'jorge.romero3666@uni.edu.gt', 0, '2025-05-08 15:37:33.000', NULL, N'INACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (14, 10, N'diego.gomez3043@uni.edu.gt', 1, '2025-09-30 06:48:37.000', '2025-09-30 11:52:14.000', N'ACTIVE');
INSERT INTO [core].[UserEmail] ([EmailId], [UserId], [Email], [IsPrimary], [AddedAtUtc], [VerifiedAtUtc], [StatusCode]) VALUES (15, 10, N'diego.gomez2416@uni.edu.gt', 0, '2025-09-30 12:08:48.000', '2025-09-30 23:43:08.000', N'ACTIVE');

GO

-- =====================================================================================
-- core.Wallet
-- =====================================================================================
PRINT 'Insertando datos en core.Wallet...';
GO

INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (1, 1, 12.97589485, 1.18693018, '2025-09-26 18:41:42.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (2, 2, 15.98442737, 0.54777388, '2025-07-15 21:04:11.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (3, 3, 15.17513344, 2.95270900, '2025-04-07 22:22:28.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (4, 4, 0.55694127, 0.39839278, '2025-06-06 02:34:21.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (5, 5, 12.71857971, 2.78605513, '2025-06-03 21:32:06.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (6, 6, 14.85626859, 0.04453516, '2025-09-01 23:18:52.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (7, 7, 7.95440537, 1.23806636, '2025-06-30 21:42:53.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (8, 8, 0.37550540, 0.09431811, '2025-08-10 21:22:29.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (9, 9, 9.00321490, 1.81947900, '2025-08-29 18:29:17.000');
INSERT INTO [core].[Wallet] ([WalletId], [UserId], [BalanceETH], [ReservedETH], [UpdatedAtUtc]) VALUES (10, 10, 13.95915159, 1.57737101, '2025-09-29 08:19:47.000');

GO

-- =====================================================================================
-- nft.NFT
-- =====================================================================================
PRINT 'Insertando datos en nft.NFT...';
GO

INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (1, 5, 1, 5, N'Obra #0001', N'Obra generada para dataset ArteCrypto (ID 1).', N'image/png', N'a9f1f144361a9f7c773866fa23fc79d8ee54398374e26588f3069d2b9ddc1219', 2140932, 3164, 952, 2.06936662, N'APPROVED', '2025-07-23 04:36:35.000', '2025-09-22 20:12:58.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (2, 5, 1, 2, N'Obra #0002', N'Obra generada para dataset ArteCrypto (ID 2).', N'image/jpeg', N'84fa7e6faa7aff41ace1652773775e64a3b8abc7fa87dc1ea58f2ca9d6d7aeb5', 1875769, 3419, 3815, 2.73237139, N'APPROVED', '2025-04-29 03:25:03.000', '2025-08-10 20:41:23.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (3, 1, 1, 1, N'Obra #0003', N'Obra generada para dataset ArteCrypto (ID 3).', N'image/png', N'b5c94b246cf9e363d2fe37e437f9a5c71e00cff043a966c3e549ab29e1a05e98', 560976, 1300, 1752, 1.11045545, N'PENDING', '2025-09-06 09:26:09.000', NULL);
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (4, 1, 1, 9, N'Obra #0004', N'Obra generada para dataset ArteCrypto (ID 4).', N'image/png', N'd4d65c40b962e9286c6f9b31baa146ff4eea586d5502e62ee451fd129a3116c7', 7728225, 1530, 3013, 3.89294242, N'APPROVED', '2025-06-04 08:21:37.000', '2025-07-06 01:52:15.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (5, 9, 1, 9, N'Obra #0005', N'Obra generada para dataset ArteCrypto (ID 5).', N'image/jpeg', N'fde1b935f91e57fd717fad750a05880f1bc8fd5e89a31dd0051b5d795063c40d', 6208842, 4085, 2495, 1.97868772, N'REJECTED', '2025-07-17 19:12:50.000', NULL);
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (6, 1, 1, 1, N'Obra #0006', N'Obra generada para dataset ArteCrypto (ID 6).', N'image/png', N'9ec88baffe3a187b5ddbf7e005258dd51848e1583ce2582a3498ef890366d7bc', 6936818, 1293, 2250, 1.40963344, N'PENDING', '2025-06-30 11:50:57.000', NULL);
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (7, 9, 1, 2, N'Obra #0007', N'Obra generada para dataset ArteCrypto (ID 7).', N'image/jpeg', N'd91d6d8975882704a798e0746c306b28bda05a4d674d2b40665c11d5dc6a6fcb', 944798, 877, 2954, 2.72432706, N'APPROVED', '2025-06-10 10:58:23.000', '2025-09-26 14:32:49.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (8, 2, 1, 2, N'Obra #0008', N'Obra generada para dataset ArteCrypto (ID 8).', N'image/png', N'2f72ddec4b71e22656e5459300d797e28e1e57150a2ad334940637a2dd47c3dc', 2501613, 2634, 697, 1.29045413, N'APPROVED', '2025-05-20 11:32:57.000', '2025-09-30 10:04:58.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (9, 1, 1, 1, N'Obra #0009', N'Obra generada para dataset ArteCrypto (ID 9).', N'image/png', N'5d33b4d6cd59f700c6b7cac5ef8a29cd2b45426fa81c18ba79a825a4ee639bcd', 1273923, 3152, 2933, 0.06853457, N'APPROVED', '2025-06-19 18:43:33.000', '2025-06-30 15:24:56.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (10, 1, 1, 1, N'Obra #0010', N'Obra generada para dataset ArteCrypto (ID 10).', N'image/jpeg', N'd6151405907c21aaf988cd90915eda27469f1bb79a07993b40a666f94484e7a0', 2166548, 637, 1450, 2.10321765, N'APPROVED', '2025-06-01 06:54:00.000', '2025-06-07 12:29:52.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (11, 1, 1, 1, N'Obra #0011', N'Obra generada para dataset ArteCrypto (ID 11).', N'image/png', N'4fa266055f27e4b2db9420a2283c9da3433f2f2a02985c1e8a3d8aaa4af8c601', 3792962, 3497, 4007, 4.27250583, N'PENDING', '2025-09-21 03:14:39.000', NULL);
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (12, 5, 1, 5, N'Obra #0012', N'Obra generada para dataset ArteCrypto (ID 12).', N'image/png', N'5059d5bc3145f9d7159cac33f2b0e924f9230a89550d66e287a4bf109e4ea98f', 1546174, 1186, 2909, 1.88983760, N'PENDING', '2025-05-27 03:58:16.000', NULL);
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (13, 5, 1, 7, N'Obra #0013', N'Obra generada para dataset ArteCrypto (ID 13).', N'image/jpeg', N'40addfaa25cb8694bd832fce241ced4d95a9ac6a1ec5c70f7805dee5b9a4ac34', 3331796, 2063, 2389, 2.91435307, N'APPROVED', '2025-06-12 19:25:01.000', '2025-08-03 19:10:47.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (14, 2, 1, 9, N'Obra #0014', N'Obra generada para dataset ArteCrypto (ID 14).', N'image/jpeg', N'9d61546cc27329663edf0ffd7294258c7213d188715d8887a76dc164eca8078a', 3797402, 3601, 3427, 0.12137854, N'APPROVED', '2025-03-21 21:30:36.000', '2025-05-01 20:45:40.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (15, 9, 1, 9, N'Obra #0015', N'Obra generada para dataset ArteCrypto (ID 15).', N'image/jpeg', N'2246bb94f791b3ca42d6db3bc8455da7f6ba6113a0070cb9c887f047d99db1d6', 6153625, 2726, 1806, 3.66445538, N'APPROVED', '2025-08-07 04:10:33.000', '2025-09-06 17:25:42.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (16, 2, 1, 2, N'Obra #0016', N'Obra generada para dataset ArteCrypto (ID 16).', N'image/png', N'2e607fedd4440cf692806617f4a26b6329d3ed0fd5e3c7f4863b6cf4fc4f05c9', 5303105, 2304, 1904, 4.04980627, N'APPROVED', '2025-05-17 18:24:37.000', '2025-09-22 00:58:33.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (17, 5, 1, 5, N'Obra #0017', N'Obra generada para dataset ArteCrypto (ID 17).', N'image/jpeg', N'555139fc421c40b5c4a36a41f46e107cef7331e1c9cb28b14053b2929c8a24a9', 6813294, 1281, 2480, 0.30558358, N'PENDING', '2025-07-01 20:26:23.000', NULL);
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (18, 5, 1, 5, N'Obra #0018', N'Obra generada para dataset ArteCrypto (ID 18).', N'image/png', N'37d9a765f2f20c5e5a8d6102d26c0b3357a7887ecee51dfe480a0c24dc42b20a', 2466536, 2943, 1552, 0.64942306, N'APPROVED', '2025-06-11 17:37:54.000', '2025-09-08 20:02:10.000');
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (19, 9, 1, 9, N'Obra #0019', N'Obra generada para dataset ArteCrypto (ID 19).', N'image/jpeg', N'69de9401c7830365fde4fb36e9b7b4e965e694e26c8a58dd8610c2cc9659bc8f', 3437647, 2430, 813, 0.94704964, N'REJECTED', '2025-05-16 18:45:18.000', NULL);
INSERT INTO [nft].[NFT] ([NFTId], [ArtistId], [SettingsID], [CurrentOwnerId], [Name], [Description], [ContentType], [HashCode], [FileSizeBytes], [WidthPx], [HeightPx], [SuggestedPriceETH], [StatusCode], [CreatedAtUtc], [ApprovedAtUtc]) VALUES (20, 1, 1, 1, N'Obra #0020', N'Obra generada para dataset ArteCrypto (ID 20).', N'image/png', N'844a63756745f9cab598f954451a84fa0eae8df1c5a15809b291bba04495baff', 4378940, 1368, 1153, 2.01671691, N'APPROVED', '2025-06-08 05:53:23.000', '2025-07-05 08:36:51.000');

GO

-- =====================================================================================
-- admin.CurationReview
-- =====================================================================================
PRINT 'Insertando datos en admin.CurationReview...';
GO

INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (1, 1, 6, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-08-16 03:17:36.000', '2025-09-21 07:16:06.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (2, 2, 5, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-08-16 03:34:57.000', '2025-09-11 07:32:11.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (3, 3, 7, N'PENDING', N'Revisión automática - Decisión: PENDING', '2025-09-19 03:33:07.000', NULL);
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (4, 4, 8, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-09-25 20:43:42.000', '2025-09-28 11:07:24.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (5, 5, 2, N'REJECTED', N'Revisión automática - Decisión: REJECTED', '2025-09-12 10:56:38.000', '2025-09-22 03:36:41.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (6, 6, 3, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-08-04 15:21:43.000', '2025-08-25 22:24:58.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (7, 7, 5, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-07-07 07:38:44.000', '2025-08-25 18:55:40.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (8, 8, 4, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-08-24 07:29:58.000', '2025-08-28 17:24:59.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (9, 9, 1, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-06-28 22:18:14.000', '2025-09-20 12:49:08.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (10, 10, 9, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-06-22 13:54:07.000', '2025-07-22 06:11:38.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (11, 11, 7, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-09-28 18:00:03.000', '2025-09-29 05:39:01.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (12, 12, 10, N'PENDING', N'Revisión automática - Decisión: PENDING', '2025-08-17 03:22:44.000', NULL);
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (13, 13, 3, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-06-25 03:28:39.000', '2025-09-07 20:37:23.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (14, 14, 2, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-06-03 23:59:05.000', '2025-09-27 17:01:33.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (15, 15, 2, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-09-21 14:48:40.000', '2025-09-28 00:55:36.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (16, 16, 10, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-07-05 14:05:05.000', '2025-08-28 07:11:40.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (17, 17, 7, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-09-23 10:12:06.000', '2025-09-23 13:32:44.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (18, 18, 1, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-07-03 23:28:53.000', '2025-09-08 03:58:54.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (19, 19, 4, N'REJECTED', N'Revisión automática - Decisión: REJECTED', '2025-08-29 01:13:05.000', '2025-09-11 00:05:30.000');
INSERT INTO [admin].[CurationReview] ([ReviewId], [NFTId], [CuratorId], [DecisionCode], [Comment], [StartedAtUtc], [ReviewedAtUtc]) VALUES (20, 20, 2, N'APPROVED', N'Revisión automática - Decisión: APPROVED', '2025-08-13 07:13:20.000', '2025-08-24 03:09:27.000');

GO

-- =====================================================================================
-- auction.Auction
-- =====================================================================================
PRINT 'Insertando datos en auction.Auction...';
GO

INSERT INTO [auction].[Auction] ([AuctionId], [SettingsID], [NFTId], [StartAtUtc], [EndAtUtc], [StartingPriceETH], [CurrentPriceETH], [CurrentLeaderId], [StatusCode]) VALUES (1, 1, 18, '2025-09-15 23:00:44.000', '2025-09-18 23:00:44.000', 0.63501369, 1.84939425, 9, N'ACTIVE');
INSERT INTO [auction].[Auction] ([AuctionId], [SettingsID], [NFTId], [StartAtUtc], [EndAtUtc], [StartingPriceETH], [CurrentPriceETH], [CurrentLeaderId], [StatusCode]) VALUES (2, 1, 1, '2025-09-28 02:51:02.000', '2025-10-01 02:51:02.000', 1.74152741, 3.37660355, 4, N'ACTIVE');
INSERT INTO [auction].[Auction] ([AuctionId], [SettingsID], [NFTId], [StartAtUtc], [EndAtUtc], [StartingPriceETH], [CurrentPriceETH], [CurrentLeaderId], [StatusCode]) VALUES (3, 1, 13, '2025-08-19 03:42:50.000', '2025-08-22 03:42:50.000', 2.47650630, 3.10896571, 7, N'COMPLETED');
INSERT INTO [auction].[Auction] ([AuctionId], [SettingsID], [NFTId], [StartAtUtc], [EndAtUtc], [StartingPriceETH], [CurrentPriceETH], [CurrentLeaderId], [StatusCode]) VALUES (4, 1, 4, '2025-08-19 03:07:25.000', '2025-08-22 03:07:25.000', 3.47095299, 6.16121193, 9, N'COMPLETED');
INSERT INTO [auction].[Auction] ([AuctionId], [SettingsID], [NFTId], [StartAtUtc], [EndAtUtc], [StartingPriceETH], [CurrentPriceETH], [CurrentLeaderId], [StatusCode]) VALUES (5, 1, 10, '2025-06-08 03:37:19.000', '2025-06-11 03:37:19.000', 2.40787414, 2.40787414, NULL, N'CANCELLED');
INSERT INTO [auction].[Auction] ([AuctionId], [SettingsID], [NFTId], [StartAtUtc], [EndAtUtc], [StartingPriceETH], [CurrentPriceETH], [CurrentLeaderId], [StatusCode]) VALUES (6, 1, 2, '2025-09-05 10:25:50.000', '2025-09-08 10:25:50.000', 3.03336807, 4.18852811, 2, N'COMPLETED');
INSERT INTO [auction].[Auction] ([AuctionId], [SettingsID], [NFTId], [StartAtUtc], [EndAtUtc], [StartingPriceETH], [CurrentPriceETH], [CurrentLeaderId], [StatusCode]) VALUES (7, 1, 14, '2025-08-07 01:39:41.000', '2025-08-10 01:39:41.000', 0.10570101, 0.21156846, 9, N'COMPLETED');
INSERT INTO [auction].[Auction] ([AuctionId], [SettingsID], [NFTId], [StartAtUtc], [EndAtUtc], [StartingPriceETH], [CurrentPriceETH], [CurrentLeaderId], [StatusCode]) VALUES (8, 1, 7, '2025-09-27 16:33:54.000', '2025-09-30 16:33:54.000', 3.12822492, 6.60942211, 2, N'COMPLETED');

GO

-- =====================================================================================
-- auction.Bid
-- =====================================================================================
PRINT 'Insertando datos en auction.Bid...';
GO

INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (1, 1, 8, 0.72353230, '2025-09-16 01:43:38.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (2, 1, 9, 0.76718610, '2025-09-16 11:13:42.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (3, 1, 10, 0.82972491, '2025-09-16 11:55:22.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (4, 1, 10, 0.89303071, '2025-09-17 06:38:53.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (5, 1, 10, 0.99891509, '2025-09-17 07:27:20.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (6, 1, 7, 1.11808257, '2025-09-17 07:38:48.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (7, 1, 4, 1.21719161, '2025-09-17 09:45:16.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (8, 1, 10, 1.38296465, '2025-09-17 23:21:34.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (9, 1, 7, 1.47276209, '2025-09-18 03:57:44.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (10, 1, 7, 1.59111888, '2025-09-18 07:23:27.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (11, 1, 9, 1.73133369, '2025-09-18 07:41:56.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (12, 1, 9, 1.84939425, '2025-09-18 18:29:18.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (13, 2, 4, 1.87045722, '2025-09-28 05:40:47.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (14, 2, 10, 2.11271235, '2025-09-28 08:06:19.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (15, 2, 9, 2.28896768, '2025-09-29 12:04:28.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (16, 2, 10, 2.57059674, '2025-09-30 07:30:13.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (17, 2, 8, 2.92470259, '2025-09-30 12:22:29.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (18, 2, 9, 3.21505617, '2025-09-30 14:32:24.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (19, 2, 4, 3.37660355, '2025-10-01 00:17:40.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (20, 3, 6, 2.62846893, '2025-08-19 13:39:24.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (21, 3, 4, 2.92357290, '2025-08-19 23:18:36.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (22, 3, 7, 3.10896571, '2025-08-21 07:21:58.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (23, 4, 5, 3.87255172, '2025-08-20 01:26:10.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (24, 4, 4, 4.09981074, '2025-08-20 03:47:37.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (25, 4, 8, 4.50761172, '2025-08-20 11:20:42.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (26, 4, 9, 4.75396198, '2025-08-20 15:11:12.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (27, 4, 7, 4.99622547, '2025-08-20 20:11:52.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (28, 4, 9, 5.70803077, '2025-08-20 20:23:30.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (29, 4, 9, 6.16121193, '2025-08-21 02:27:37.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (30, 6, 6, 3.27313904, '2025-09-06 02:04:03.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (31, 6, 2, 3.47608867, '2025-09-06 08:35:50.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (32, 6, 10, 3.78757529, '2025-09-06 12:15:50.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (33, 6, 2, 4.18852811, '2025-09-07 09:36:38.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (34, 7, 5, 0.12128158, '2025-08-07 02:54:54.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (35, 7, 10, 0.13869379, '2025-08-07 16:33:18.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (36, 7, 10, 0.15359624, '2025-08-08 04:53:09.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (37, 7, 4, 0.17445562, '2025-08-08 21:40:30.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (38, 7, 5, 0.20054328, '2025-08-09 00:18:11.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (39, 7, 9, 0.21156846, '2025-08-09 17:51:15.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (40, 8, 5, 3.58643975, '2025-09-27 19:46:12.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (41, 8, 8, 3.97693587, '2025-09-27 20:54:36.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (42, 8, 2, 4.53892596, '2025-09-28 03:00:00.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (43, 8, 4, 5.00143234, '2025-09-28 08:29:57.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (44, 8, 2, 5.61656952, '2025-09-28 13:48:38.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (45, 8, 10, 6.25617458, '2025-09-29 03:37:23.000');
INSERT INTO [auction].[Bid] ([BidId], [AuctionId], [BidderId], [AmountETH], [PlacedAtUtc]) VALUES (46, 8, 2, 6.60942211, '2025-09-30 03:16:46.000');

GO

-- =====================================================================================
-- finance.FundsReservation
-- =====================================================================================
PRINT 'Insertando datos en finance.FundsReservation...';
GO

INSERT INTO [finance].[FundsReservation] ([ReservationId], [AuctionId], [UserId], [AmountETH], [StateCode], [CreatedAtUtc]) VALUES (1, 3, 7, 3.10896571, N'APPLIED', '2025-08-22 03:42:50.000');
INSERT INTO [finance].[FundsReservation] ([ReservationId], [AuctionId], [UserId], [AmountETH], [StateCode], [CreatedAtUtc]) VALUES (2, 4, 9, 6.16121193, N'APPLIED', '2025-08-22 03:07:25.000');
INSERT INTO [finance].[FundsReservation] ([ReservationId], [AuctionId], [UserId], [AmountETH], [StateCode], [CreatedAtUtc]) VALUES (3, 6, 2, 4.18852811, N'APPLIED', '2025-09-08 10:25:50.000');
INSERT INTO [finance].[FundsReservation] ([ReservationId], [AuctionId], [UserId], [AmountETH], [StateCode], [CreatedAtUtc]) VALUES (4, 7, 9, 0.21156846, N'APPLIED', '2025-08-10 01:39:41.000');
INSERT INTO [finance].[FundsReservation] ([ReservationId], [AuctionId], [UserId], [AmountETH], [StateCode], [CreatedAtUtc]) VALUES (5, 8, 2, 6.60942211, N'APPLIED', '2025-09-30 16:33:54.000');

GO

-- =====================================================================================
-- finance.Ledger
-- =====================================================================================
PRINT 'Insertando datos en finance.Ledger...';
GO

INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (1, 3, 7, 3.10896571, N'DEBIT', '2025-08-22 03:42:50.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (2, 3, 5, 3.04678640, N'CREDIT', '2025-08-22 03:42:50.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (3, 4, 9, 6.16121193, N'DEBIT', '2025-08-22 03:07:25.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (4, 4, 1, 6.03798769, N'CREDIT', '2025-08-22 03:07:25.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (5, 6, 2, 4.18852811, N'DEBIT', '2025-09-08 10:25:50.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (6, 6, 5, 4.10475755, N'CREDIT', '2025-09-08 10:25:50.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (7, 7, 9, 0.21156846, N'DEBIT', '2025-08-10 01:39:41.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (8, 7, 2, 0.20733709, N'CREDIT', '2025-08-10 01:39:41.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (9, 8, 2, 6.60942211, N'DEBIT', '2025-09-30 16:33:54.000');
INSERT INTO [finance].[Ledger] ([EntryId], [AuctionId], [UserId], [AmountETH], [EntryType], [CreatedAtUtc]) VALUES (10, 8, 9, 6.47723367, N'CREDIT', '2025-09-30 16:33:54.000');

GO

-- =====================================================================================
-- audit.EmailOutbox
-- =====================================================================================
PRINT 'Insertando datos en audit.EmailOutbox...';
GO

INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (1, 5, N'diego.martinez8033@yahoo.com', N'Subasta creada para NFT #18', N'Tu NFT ha sido listado en subasta (Auction #1).', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (2, 5, N'diego.martinez8033@yahoo.com', N'Subasta creada para NFT #1', N'Tu NFT ha sido listado en subasta (Auction #2).', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (3, 5, N'diego.martinez8033@yahoo.com', N'Subasta creada para NFT #13', N'Tu NFT ha sido listado en subasta (Auction #3).', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (4, 1, N'lucia.azurdia6988@gmail.com', N'Subasta creada para NFT #4', N'Tu NFT ha sido listado en subasta (Auction #4).', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (5, 1, N'lucia.azurdia6988@gmail.com', N'Subasta creada para NFT #10', N'Tu NFT ha sido listado en subasta (Auction #5).', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (6, 5, N'diego.martinez8033@yahoo.com', N'Subasta creada para NFT #2', N'Tu NFT ha sido listado en subasta (Auction #6).', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (7, 2, N'sofia.ramirez2708@outlook.com', N'Subasta creada para NFT #14', N'Tu NFT ha sido listado en subasta (Auction #7).', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (8, 9, N'jorge.romero1804@uni.edu.gt', N'Subasta creada para NFT #7', N'Tu NFT ha sido listado en subasta (Auction #8).', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (9, 5, N'diego.martinez8033@yahoo.com', N'NFT #1 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (10, 5, N'diego.martinez8033@yahoo.com', N'NFT #2 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (11, 1, N'lucia.azurdia6988@gmail.com', N'NFT #4 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (12, 9, N'jorge.romero1804@uni.edu.gt', N'NFT #5 rechazado', N'Tu NFT ha sido rechazado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (13, 1, N'lucia.azurdia6988@gmail.com', N'NFT #6 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (14, 9, N'jorge.romero1804@uni.edu.gt', N'NFT #7 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (15, 2, N'sofia.ramirez2708@outlook.com', N'NFT #8 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (16, 1, N'lucia.azurdia6988@gmail.com', N'NFT #9 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (17, 1, N'lucia.azurdia6988@gmail.com', N'NFT #10 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (18, 1, N'lucia.azurdia6988@gmail.com', N'NFT #11 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (19, 5, N'diego.martinez8033@yahoo.com', N'NFT #13 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (20, 2, N'sofia.ramirez2708@outlook.com', N'NFT #14 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (21, 9, N'jorge.romero1804@uni.edu.gt', N'NFT #15 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (22, 2, N'sofia.ramirez2708@outlook.com', N'NFT #16 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (23, 5, N'diego.martinez8033@yahoo.com', N'NFT #17 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (24, 5, N'diego.martinez8033@yahoo.com', N'NFT #18 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (25, 9, N'jorge.romero1804@uni.edu.gt', N'NFT #19 rechazado', N'Tu NFT ha sido rechazado por el curador.', N'PENDING');
INSERT INTO [audit].[EmailOutbox] ([EmailId], [RecipientUserId], [RecipientEmail], [Subject], [Body], [StatusCode]) VALUES (26, 1, N'lucia.azurdia6988@gmail.com', N'NFT #20 aprobado', N'Tu NFT ha sido aprobado por el curador.', N'PENDING');

GO

PRINT 'Inserción de datos completada exitosamente.';
GO
