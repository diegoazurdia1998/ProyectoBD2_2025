---- =====================================================================================
-- Casos de prueba fase 2
-- Proyecto: ArteCryptoAuctions
-- Descripción: Casos de prueba para fase 2 con el flujo NFT → Curación → Subasta
-- =====================================================================================

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- Datos requeridos paraa las pruebas
-- =====================================================================================

-- Usuarios

	-- Artistas (mínimo 2)
		INSERT INTO core.[User](FullName, CreatedAtUtc) 
		VALUES
		  ('Carlos Artista', SYSUTCDATETIME()),
		  ('María Pintora', SYSUTCDATETIME());

	-- Usuario sin rol (para pruebas de validación)
		INSERT INTO core.[User](FullName, CreatedAtUtc) 
		VALUES ('Juan Sin Rol', SYSUTCDATETIME());

	-- Curadores (mínimo 2)
		INSERT INTO core.[User](FullName, CreatedAtUtc) 
		VALUES
		  ('Ana Curadora', SYSUTCDATETIME()),
		  ('Pedro Curador', SYSUTCDATETIME());

	-- Oferentes (mínimo 3)
	INSERT INTO core.[User](FullName, CreatedAtUtc) 
	VALUES
		  ('Luis Comprador', SYSUTCDATETIME()),
		  ('Sofia Coleccionista', SYSUTCDATETIME()),
		  ('Diego Inversor', SYSUTCDATETIME());

-- Roles

		INSERT INTO core.UserRole(UserId, RoleId) 
		VALUES
		  (1, 2),  -- ARTIST
		  (2, 2),  -- ARTIST
		  (4, 3), -- CURATOR
		  (5, 3), -- CURATOR
		  (6, 4),  -- BIDDER
		  (7, 4),  -- BIDDER
		  (8, 4);  -- BIDDER

-- Emails

		INSERT INTO core.UserEmail(UserId, Email, IsPrimary, StatusCode)
		VALUES
		  (1, 'carlos.artista@test.com', 1, 'ACTIVE'),
		  (2, 'maria.pintora@test.com', 1, 'ACTIVE'),
		  (4, 'ana.curadora@test.com', 1, 'ACTIVE'),
		  (5, 'pedro.curador@test.com', 1, 'ACTIVE'),
		  (6, 'luis.comprador@test.com', 1, 'ACTIVE'),
		  (7, 'sofia.coleccionista@test.com', 1, 'ACTIVE'),
		  (8, 'diego.inversor@test.com', 1, 'ACTIVE');

--Configuracion

	-- NFT Settings
		INSERT INTO nft.NFTSettings(
		  SettingsID, MaxWidthPx, MinWidthPx, MaxHeightPx, 
		  MinHeigntPx, MaxFileSizeBytes, MinFileSizeBytes, CreatedAtUtc
		)
		VALUES(1, 4096, 512, 4096, 512, 10485760, 10240, SYSUTCDATETIME());

	-- Auction Settings
		INSERT INTO auction.AuctionSettings(
		  SettingsID, CompanyName, BasePriceETH, 
		  DefaultAuctionHours, MinBidIncrementPct
		)
		VALUES(1, 'ArteCryptoAuctions', 0.01, 72, 5);