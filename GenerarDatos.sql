USE ArteCryptoAuctions
GO

-- ArteCrypto • Script de datos coherentes (seed) — escalable y versátil
-- Requisitos: DDL v3 + SPs/Trigger v3 ya instalados
-- Filosofía: parámetros de volumen, utilidades reusables, IDs capturados con OUTPUT,
--            uso de SPs de negocio para mantener coherencia (subastas, reservas, cierre).

/* =========================================================
   PARÁMETROS DE SEMILLA (ajusta a gusto)
   ========================================================= */
DECLARE @Artists            INT = 8;    -- # de artistas
DECLARE @Curators           INT = 3;    -- # de curadores
DECLARE @Collectors         INT = 25;   -- # de coleccionistas
DECLARE @NFTsPerArtist      INT = 6;    -- NFTs por artista
DECLARE @ApproveRatio       DECIMAL(5,2) = 0.75; -- % de NFTs que se aprueban
DECLARE @MinBidsPerAuction  INT = 3;    -- mínimo de pujas por subasta
DECLARE @MaxBidsPerAuction  INT = 8;    -- máximo de pujas por subasta
DECLARE @FinalizeRatio      DECIMAL(5,2) = 0.60; -- % de subastas a cerrar ahora
DECLARE @CollectorFundsETH  DECIMAL(38,18) = 500; -- saldo inicial coleccionistas
DECLARE @ArtistFundsETH     DECIMAL(38,18) = 50;  -- saldo inicial artistas
DECLARE @CuratorFundsETH    DECIMAL(38,18) = 10;  -- saldo inicial curadores
DECLARE @EnableEmails       BIT = 0;    -- 0 para no llenar la outbox durante el seed

-- Tag de lote para unicidad en nombres/emails
DECLARE @BatchTag NVARCHAR(20) = FORMAT(SYSUTCDATETIME(),'yyyyMMddHHmmss');

/* =========================================================
   UTILERÍAS: serie de números y random helpers
   ========================================================= */
IF OBJECT_ID('ops.fn_Series','IF') IS NULL
    EXEC('CREATE FUNCTION ops.fn_Series(@count INT) RETURNS TABLE AS RETURN ( SELECT TOP (@count) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects a CROSS JOIN sys.all_objects b );');
GO

-- Rand determinista por fila con NEWID() + semilla
IF OBJECT_ID('ops.fn_Rand01','IF') IS NULL
    EXEC('CREATE FUNCTION ops.fn_Rand01(@seed NVARCHAR(100)) RETURNS DECIMAL(9,6) AS BEGIN RETURN ABS(CONVERT(DECIMAL(9,6), CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES(''SHA2_256'', @seed)))) % 1000000) / 1000000 END');
GO

/* =========================================================
   ROLES (idempotente)
   ========================================================= */
MERGE core.Role AS t
USING (VALUES ('ARTIST'),('CURATOR'),('COLLECTOR'),('ADMIN')) AS s([Name])
ON t.[Name]=s.[Name]
WHEN NOT MATCHED THEN INSERT([Name]) VALUES(s.[Name]);

/* =========================================================
   CREACIÓN DE USUARIOS + EMAIL + WALLET (con OUTPUT)
   ========================================================= */
DECLARE @ArtistsIds     TABLE(UserId BIGINT);
DECLARE @CuratorsIds    TABLE(UserId BIGINT);
DECLARE @CollectorsIds  TABLE(UserId BIGINT);

-- Artistas
INSERT INTO core.[User](FullName)
OUTPUT INSERTED.UserId INTO @ArtistsIds(UserId)
SELECT CONCAT('Artist ', @BatchTag, '-', n)
FROM ops.fn_Series(@Artists) s;

-- Curadores
INSERT INTO core.[User](FullName)
OUTPUT INSERTED.UserId INTO @CuratorsIds(UserId)
SELECT CONCAT('Curator ', @BatchTag, '-', n)
FROM ops.fn_Series(@Curators) s;

-- Coleccionistas
INSERT INTO core.[User](FullName)
OUTPUT INSERTED.UserId INTO @CollectorsIds(UserId)
SELECT CONCAT('Collector ', @BatchTag, '-', n)
FROM ops.fn_Series(@Collectors) s;

-- Resolver RoleIds
DECLARE @RoleArtist BIGINT = (SELECT RoleId FROM core.Role WHERE [Name]='ARTIST');
DECLARE @RoleCurator BIGINT = (SELECT RoleId FROM core.Role WHERE [Name]='CURATOR');
DECLARE @RoleCollector BIGINT = (SELECT RoleId FROM core.Role WHERE [Name]='COLLECTOR');

-- Asignar roles (M:N)
INSERT INTO core.UserRole(UserId, RoleId)
SELECT a.UserId, @RoleArtist FROM @ArtistsIds a
UNION ALL
SELECT c.UserId, @RoleCurator FROM @CuratorsIds c
UNION ALL
SELECT x.UserId, @RoleCollector FROM @CollectorsIds x;

-- Emails primarios
INSERT INTO core.UserEmail(UserId, Email, IsPrimary, StatusCode)
SELECT UserId, CONCAT('artist', ROW_NUMBER() OVER (ORDER BY UserId), '.', @BatchTag, '@email.art'), 1, 'ACTIVE'
FROM @ArtistsIds
UNION ALL
SELECT UserId, CONCAT('curator', ROW_NUMBER() OVER (ORDER BY UserId), '.', @BatchTag, '@correo.cure'), 1, 'ACTIVE'
FROM @CuratorsIds
UNION ALL
SELECT UserId, CONCAT('collector', ROW_NUMBER() OVER (ORDER BY UserId), '.', @BatchTag, '@mail.coll'), 1, 'ACTIVE'
FROM @CollectorsIds;

-- Wallets con saldo inicial
INSERT INTO core.Wallet(UserId, BalanceETH, ReservedETH)
SELECT UserId, @ArtistFundsETH, 0 FROM @ArtistsIds
UNION ALL
SELECT UserId, @CuratorFundsETH, 0 FROM @CuratorsIds
UNION ALL
SELECT UserId, @CollectorFundsETH, 0 FROM @CollectorsIds;

/* =========================================================
   CREACIÓN DE NFTS (PENDING)
   ========================================================= */
DECLARE @NFTIds TABLE(NFTId BIGINT, ArtistId BIGINT);

INSERT INTO nft.NFT(ArtistId, CurrentOwnerId, [Name], [Description], ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode)
OUTPUT INSERTED.NFTId, INSERTED.ArtistId INTO @NFTIds(NFTId, ArtistId)
SELECT a.UserId,
       a.UserId,
       CONCAT('NFT ', @BatchTag, '-', a.UserId, '-', s.n),
       CONCAT('Obra generada para pruebas #', s.n, ' del artista ', a.UserId),
       'image/png',
       CONVERT(CHAR(64), CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT(@BatchTag, ':', a.UserId, ':', s.n)), 2)),
       200000 + s.n*1000,
       1024,
       1024,
       CAST(0.10 + (s.n*0.01) AS DECIMAL(38,18)),
       'PENDING'
FROM @ArtistsIds a
CROSS APPLY ops.fn_Series(@NFTsPerArtist) s;

/* =========================================================
   CURADURÍA: Aprobar aleatoriamente @ApproveRatio de NFTs
   (usa SP para disparar trigger de subastas)
   ========================================================= */
DECLARE @curator BIGINT = (SELECT TOP(1) UserId FROM @CuratorsIds ORDER BY NEWID());

DECLARE @NFTId BIGINT, @ArtistId BIGINT;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
SELECT n.NFTId, n.ArtistId FROM @NFTIds n;
OPEN cur;
FETCH NEXT FROM cur INTO @NFTId, @ArtistId;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @r DECIMAL(9,6) = ops.fn_Rand01(CONCAT('approve:', @BatchTag, ':', @NFTId));
    IF @r <= @ApproveRatio
    BEGIN
        EXEC admin.sp_NFT_Review @CuratorId=@curator, @NFTId=@NFTId, @Decision='APPROVE', @Comment=NULL;
    END
    ELSE
    BEGIN
        EXEC admin.sp_NFT_Review @CuratorId=@curator, @NFTId=@NFTId, @Decision='REJECT', @Comment=N'No cumple criterios (seed)';
    END
    FETCH NEXT FROM cur INTO @NFTId, @ArtistId;
END
CLOSE cur; DEALLOCATE cur;

-- Opcional: si no quieres llenar la outbox, marca como SENT lo generado
IF @EnableEmails = 0
  UPDATE audit.EmailOutbox SET StatusCode='SENT', SentAtUtc=SYSUTCDATETIME() WHERE StatusCode='PENDING';

/* =========================================================
   AJUSTE DE VENTANAS DE SUBASTA
   - Hacer ACTIVE con ventana actual (para colocar ofertas)
   ========================================================= */
UPDATE a
   SET StartAtUtc = DATEADD(MINUTE, -60, SYSUTCDATETIME()),
       EndAtUtc   = DATEADD(MINUTE, +60, SYSUTCDATETIME())
FROM auction.Auction a
JOIN nft.NFT n ON n.NFTId = a.NFTId
WHERE n.CreatedAtUtc >= DATEADD(DAY, -1, SYSUTCDATETIME()); -- sólo las recién creadas

/* =========================================================
   OFERTAS: generar pujas por subasta con reglas de incremento
   ========================================================= */
DECLARE @AuctionIds TABLE(AuctionId BIGINT);
INSERT INTO @AuctionIds(AuctionId)
SELECT a.AuctionId FROM auction.Auction a WHERE a.StatusCode='ACTIVE';

DECLARE @A BIGINT;
DECLARE auc CURSOR LOCAL FAST_FORWARD FOR SELECT AuctionId FROM @AuctionIds;
OPEN auc;
FETCH NEXT FROM auc INTO @A;
WHILE @@FETCH_STATUS = 0
BEGIN
  DECLARE @bids INT = @MinBidsPerAuction + ABS(CHECKSUM(NEWID())) % (1 + @MaxBidsPerAuction - @MinBidsPerAuction);
  DECLARE @i INT = 0;
  WHILE @i < @bids
  BEGIN
     DECLARE @BidderId BIGINT = (SELECT TOP(1) UserId FROM @CollectorsIds ORDER BY NEWID());
     DECLARE @currPrice DECIMAL(38,18), @pctInc DECIMAL(9,4);
     SELECT @currPrice = CurrentPriceETH FROM auction.Auction WHERE AuctionId=@A;
     SELECT @pctInc = TRY_CONVERT(DECIMAL(9,4), SettingValue) FROM ops.Settings WHERE SettingKey='MinBidIncrementPct';
     IF @pctInc IS NULL SET @pctInc = 0;

     DECLARE @minRequired DECIMAL(38,18) = CASE WHEN @pctInc>0 THEN @currPrice*(1+(@pctInc/100.0)) ELSE @currPrice + 0.000000000000000001 END;
     DECLARE @bump DECIMAL(38,18) = (@minRequired - @currPrice) * (1 + ABS(CHECKSUM(NEWID())) % 10 / 10.0); -- entre 1x y 1.9x del incremento mínimo
     DECLARE @offer DECIMAL(38,18) = @currPrice + @bump;

     BEGIN TRY
        EXEC auction.sp_PlaceBid @AuctionId=@A, @BidderId=@BidderId, @AmountETH=@offer;
        SET @i += 1;
     END TRY
     BEGIN CATCH
        -- Si falla (saldo, ventana, etc.), intenta con otro postor
        CONTINUE;
     END CATCH
  END
  FETCH NEXT FROM auc INTO @A;
END
CLOSE auc; DEALLOCATE auc;

/* =========================================================
   FINALIZAR un porcentaje de subastas (para poblar ledger y ventas)
   ========================================================= */
-- Marcar aleatoriamente subastas para cierre inmediato
UPDATE a
   SET EndAtUtc = DATEADD(SECOND, -5, SYSUTCDATETIME())
FROM auction.Auction a
WHERE a.StatusCode='ACTIVE'
  AND ops.fn_Rand01(CONCAT('finalize:', @BatchTag, ':', a.AuctionId)) <= @FinalizeRatio;

EXEC auction.sp_FinalizeDueAuctions;

-- Opcional: marcar emails a SENT
IF @EnableEmails = 0
  UPDATE audit.EmailOutbox SET StatusCode='SENT', SentAtUtc=SYSUTCDATETIME() WHERE StatusCode='PENDING';

/* =========================================================
   REPORTES RÁPIDOS DE SANIDAD (opcionales)
   ========================================================= */
PRINT '==== RESUMEN ====';
SELECT 'Usuarios' AS item, COUNT(*) AS qty FROM core.[User]
UNION ALL SELECT 'Artistas', (SELECT COUNT(*) FROM @ArtistsIds)
UNION ALL SELECT 'Curadores', (SELECT COUNT(*) FROM @CuratorsIds)
UNION ALL SELECT 'Coleccionistas', (SELECT COUNT(*) FROM @CollectorsIds)
UNION ALL SELECT 'NFTs', COUNT(*) FROM nft.NFT
UNION ALL SELECT 'Subastas ACTIVE', COUNT(*) FROM auction.Auction WHERE StatusCode='ACTIVE'
UNION ALL SELECT 'Subastas FINALIZED', COUNT(*) FROM auction.Auction WHERE StatusCode='FINALIZED'
UNION ALL SELECT 'Bids', COUNT(*) FROM auction.Bid
UNION ALL SELECT 'Ledger', COUNT(*) FROM finance.Ledger
UNION ALL SELECT 'EmailOutbox', COUNT(*) FROM audit.EmailOutbox;

-- Fin del script de seed coherente y escalable
