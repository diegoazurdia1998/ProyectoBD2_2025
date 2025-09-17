-- ArteCrypto • Seed v2 (procedimental, robusto, sin problemas de GO)
-- Generación de datos coherentes empaquetada en un SP con parámetros
-- • No depende de variables de sesión ni de múltiples batches
-- • Usa solo CONCAT/variables intermedias (sin concatenación directa en EXEC)
-- • Compatible con DDL/SPA/Triggers v3.2
-- Fecha: 2025-09-13

/* =========================================================
   Helper: asegurar utilidades (idempotente)
   ========================================================= */
IF OBJECT_ID('ops.fn_Series','IF') IS NULL
  EXEC('CREATE FUNCTION ops.fn_Series(@count INT) RETURNS TABLE AS RETURN (
           SELECT TOP (CASE WHEN @count > 0 THEN @count ELSE 0 END)
                  ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
           FROM sys.all_objects a CROSS JOIN sys.all_objects b
        );');

IF OBJECT_ID('ops.fn_Rand01','IF') IS NULL
  EXEC('CREATE FUNCTION ops.fn_Rand01(@seed NVARCHAR(100)) RETURNS DECIMAL(9,6) AS
        BEGIN
          RETURN ABS(CONVERT(DECIMAL(9,6),
                 CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES(''SHA2_256'', @seed))))
                 % 1000000) / 1000000
        END');
GO

/* =========================================================
   SP: admin.sp_GenerateDemoData
   ========================================================= */
CREATE OR ALTER PROCEDURE admin.sp_GenerateDemoData
  @Artists            INT = 8,
  @Curators           INT = 3,
  @Collectors         INT = 25,
  @NFTsPerArtist      INT = 6,
  @ApproveRatio       DECIMAL(5,2) = 0.75,          -- 0..1
  @MinBidsPerAuction  INT = 3,
  @MaxBidsPerAuction  INT = 8,
  @FinalizeRatio      DECIMAL(5,2) = 0.60,          -- 0..1
  @CollectorFundsETH  DECIMAL(38,18) = 500,
  @ArtistFundsETH     DECIMAL(38,18) = 50,
  @CuratorFundsETH    DECIMAL(38,18) = 10,
  @EnableEmails       BIT = 0,                       -- 0 = marcar outbox como SENT al final
  @UseDeterministic   BIT = 1,                       -- 1 = rand determinista por @BatchTag
  @BatchTag           NVARCHAR(20) = NULL            -- si NULL, se genera automático
AS
BEGIN
  SET NOCOUNT ON;

  /* ---------- Validaciones rápidas ---------- */
  IF @Artists < 0 OR @Curators < 0 OR @Collectors < 0 THROW 60010, 'Los conteos no pueden ser negativos.', 1;
  IF @NFTsPerArtist < 0 THROW 60011, 'NFTsPerArtist no puede ser negativo.', 1;
  IF @MaxBidsPerAuction < @MinBidsPerAuction THROW 60012, 'MaxBidsPerAuction debe ser >= MinBidsPerAuction.', 1;
  IF @ApproveRatio  < 0 OR @ApproveRatio  > 1 THROW 60013, 'ApproveRatio debe estar entre 0 y 1.', 1;
  IF @FinalizeRatio < 0 OR @FinalizeRatio > 1 THROW 60014, 'FinalizeRatio debe estar entre 0 y 1.', 1;

  /* ---------- BatchTag ---------- */
  IF @BatchTag IS NULL
    SET @BatchTag = CONVERT(char(8), SYSUTCDATETIME(), 112) + REPLACE(CONVERT(char(8), SYSUTCDATETIME(),108),':','');

  /* ---------- Roles (idempotente) ---------- */
  MERGE core.Role AS t
  USING (VALUES ('ARTIST'),('CURATOR'),('COLLECTOR'),('ADMIN')) AS s([Name])
  ON t.[Name]=s.[Name]
  WHEN NOT MATCHED THEN INSERT([Name]) VALUES(s.[Name]);

  DECLARE @RoleArtist BIGINT = (SELECT RoleId FROM core.Role WHERE [Name]='ARTIST');
  DECLARE @RoleCurator BIGINT = (SELECT RoleId FROM core.Role WHERE [Name]='CURATOR');
  DECLARE @RoleCollector BIGINT = (SELECT RoleId FROM core.Role WHERE [Name]='COLLECTOR');

  /* ---------- Usuarios + emails + wallets ---------- */
  DECLARE @ArtistsIds     TABLE(UserId BIGINT PRIMARY KEY);
  DECLARE @CuratorsIds    TABLE(UserId BIGINT PRIMARY KEY);
  DECLARE @CollectorsIds  TABLE(UserId BIGINT PRIMARY KEY);

  INSERT INTO core.[User](FullName)
  OUTPUT INSERTED.UserId INTO @ArtistsIds(UserId)
  SELECT CONCAT('Artist ', @BatchTag, '-', s.n)
  FROM ops.fn_Series(@Artists) s;

  INSERT INTO core.[User](FullName)
  OUTPUT INSERTED.UserId INTO @CuratorsIds(UserId)
  SELECT CONCAT('Curator ', @BatchTag, '-', s.n)
  FROM ops.fn_Series(@Curators) s;

  INSERT INTO core.[User](FullName)
  OUTPUT INSERTED.UserId INTO @CollectorsIds(UserId)
  SELECT CONCAT('Collector ', @BatchTag, '-', s.n)
  FROM ops.fn_Series(@Collectors) s;

  INSERT INTO core.UserRole(UserId, RoleId)
  SELECT a.UserId, @RoleArtist FROM @ArtistsIds a
  UNION ALL SELECT c.UserId, @RoleCurator FROM @CuratorsIds c
  UNION ALL SELECT x.UserId, @RoleCollector FROM @CollectorsIds x;

  INSERT INTO core.UserEmail(UserId, Email, IsPrimary, StatusCode)
  SELECT UserId, CONCAT('artist', ROW_NUMBER() OVER (ORDER BY UserId), '.', @BatchTag, '@example.test'), 1, 'ACTIVE' FROM @ArtistsIds
  UNION ALL
  SELECT UserId, CONCAT('curator', ROW_NUMBER() OVER (ORDER BY UserId), '.', @BatchTag, '@example.test'), 1, 'ACTIVE' FROM @CuratorsIds
  UNION ALL
  SELECT UserId, CONCAT('collector', ROW_NUMBER() OVER (ORDER BY UserId), '.', @BatchTag, '@example.test'), 1, 'ACTIVE' FROM @CollectorsIds;

  INSERT INTO core.Wallet(UserId, BalanceETH, ReservedETH)
  SELECT UserId, @ArtistFundsETH, 0 FROM @ArtistsIds
  UNION ALL SELECT UserId, @CuratorFundsETH, 0 FROM @CuratorsIds
  UNION ALL SELECT UserId, @CollectorFundsETH, 0 FROM @CollectorsIds;

  /* ---------- NFTs ---------- */
  DECLARE @NFTIds TABLE(NFTId BIGINT PRIMARY KEY, ArtistId BIGINT);

  INSERT INTO nft.NFT(ArtistId, CurrentOwnerId, [Name], [Description], ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, StatusCode)
  OUTPUT INSERTED.NFTId, INSERTED.ArtistId INTO @NFTIds(NFTId, ArtistId)
  SELECT a.UserId,
         a.UserId,
         CONCAT('NFT ', @BatchTag, '-', a.UserId, '-', s.n),
         CONCAT('Obra generada #', s.n, ' del artista ', a.UserId),
         'image/png',
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), CONCAT(@BatchTag, ':', a.UserId, ':', s.n))), 2),
         200000 + s.n*1000,
         1024,
         1024,
         CAST(0.10 + (s.n*0.01) AS DECIMAL(38,18)),
         'PENDING'
  FROM @ArtistsIds a
  CROSS APPLY ops.fn_Series(@NFTsPerArtist) s;

  /* ---------- Curaduría (usa SP para disparar trigger) ---------- */
  DECLARE @curator BIGINT = (SELECT TOP(1) UserId FROM @CuratorsIds ORDER BY NEWID());

  DECLARE @NFTId BIGINT, @ArtistId BIGINT;
  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT NFTId, ArtistId FROM @NFTIds;
  OPEN cur;
  FETCH NEXT FROM cur INTO @NFTId, @ArtistId;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    DECLARE @r DECIMAL(9,6) = CASE WHEN @UseDeterministic=1
                                   THEN ops.fn_Rand01(CONCAT('approve:', @BatchTag, ':', @NFTId))
                                   ELSE ABS(CHECKSUM(NEWID())) % 1000000 / 1000000.0 END;
    IF @r <= @ApproveRatio
      EXEC admin.sp_NFT_Review @CuratorId=@curator, @NFTId=@NFTId, @Decision='APPROVE', @Comment=NULL;
    ELSE
      EXEC admin.sp_NFT_Review @CuratorId=@curator, @NFTId=@NFTId, @Decision='REJECT',  @Comment=N'Seed: no aprobada';

    FETCH NEXT FROM cur INTO @NFTId, @ArtistId;
  END
  CLOSE cur; DEALLOCATE cur;

  -- Opcional: no llenar outbox durante seed
  IF @EnableEmails = 0
    UPDATE audit.EmailOutbox SET StatusCode='SENT', SentAtUtc=SYSUTCDATETIME() WHERE StatusCode='PENDING';

  /* ---------- Ajuste de ventanas de subasta para pujar ahora ---------- */
  UPDATE a SET StartAtUtc = DATEADD(MINUTE, -60, SYSUTCDATETIME()),
               EndAtUtc   = DATEADD(MINUTE, +60, SYSUTCDATETIME())
  FROM auction.Auction a
  JOIN nft.NFT n ON n.NFTId = a.NFTId
  WHERE n.CreatedAtUtc >= DATEADD(DAY, -1, SYSUTCDATETIME())
    AND a.StatusCode='ACTIVE';

  /* ---------- Ofertas ---------- */
  DECLARE @A BIGINT;
  DECLARE auc CURSOR LOCAL FAST_FORWARD FOR SELECT AuctionId FROM auction.Auction WHERE StatusCode='ACTIVE';
  OPEN auc;
  FETCH NEXT FROM auc INTO @A;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    DECLARE @range INT = (@MaxBidsPerAuction - @MinBidsPerAuction + 1);
    DECLARE @bids INT = CASE WHEN @range > 0 THEN @MinBidsPerAuction + (ABS(CHECKSUM(NEWID())) % @range) ELSE @MinBidsPerAuction END;
    DECLARE @i INT = 0;
    WHILE @i < @bids
    BEGIN
      DECLARE @BidderId BIGINT = (SELECT TOP(1) UserId FROM @CollectorsIds ORDER BY NEWID());
      DECLARE @currPrice DECIMAL(38,18) = (SELECT CurrentPriceETH FROM auction.Auction WHERE AuctionId=@A);
      DECLARE @pctInc DECIMAL(9,4) = TRY_CONVERT(DECIMAL(9,4), (SELECT SettingValue FROM ops.Settings WHERE SettingKey='MinBidIncrementPct'));
      IF @pctInc IS NULL SET @pctInc = 0;

      DECLARE @minRequired DECIMAL(38,18) = CASE WHEN @pctInc>0 THEN @currPrice*(1+(@pctInc/100.0)) ELSE @currPrice + 0.000000000000000001 END;
      DECLARE @bump DECIMAL(38,18) = (@minRequired - @currPrice) * (1 + ABS(CHECKSUM(NEWID())) % 10 / 10.0);
      DECLARE @offer DECIMAL(38,18) = @currPrice + @bump;

      BEGIN TRY
        EXEC auction.sp_PlaceBid @AuctionId=@A, @BidderId=@BidderId, @AmountETH=@offer;
        SET @i += 1;
      END TRY
      BEGIN CATCH
        -- ignorar y reintentar con otro postor
      END CATCH
    END

    FETCH NEXT FROM auc INTO @A;
  END
  CLOSE auc; DEALLOCATE auc;

  /* ---------- Finalizar parte de las subastas ---------- */
  UPDATE a
     SET EndAtUtc = DATEADD(SECOND, -5, SYSUTCDATETIME())
  FROM auction.Auction a
  WHERE a.StatusCode='ACTIVE'
    AND (CASE WHEN @UseDeterministic=1 THEN ops.fn_Rand01(CONCAT('finalize:', @BatchTag, ':', a.AuctionId))
              ELSE ABS(CHECKSUM(NEWID())) % 1000000 / 1000000.0 END) <= @FinalizeRatio;

  EXEC auction.sp_FinalizeDueAuctions;

  IF @EnableEmails = 0
    UPDATE audit.EmailOutbox SET StatusCode='SENT', SentAtUtc=SYSUTCDATETIME() WHERE StatusCode='PENDING';

  /* ---------- Resumen ---------- */
  SELECT 'BatchTag' AS item, @BatchTag AS value
  UNION ALL SELECT 'Usuarios', CAST(COUNT(*) AS NVARCHAR(100)) FROM core.[User]
  UNION ALL SELECT 'Artistas', CAST((SELECT COUNT(*) FROM @ArtistsIds) AS NVARCHAR(100))
  UNION ALL SELECT 'Curadores', CAST((SELECT COUNT(*) FROM @CuratorsIds) AS NVARCHAR(100))
  UNION ALL SELECT 'Coleccionistas', CAST((SELECT COUNT(*) FROM @CollectorsIds) AS NVARCHAR(100))
  UNION ALL SELECT 'NFTs', CAST(COUNT(*) AS NVARCHAR(100)) FROM nft.NFT
  UNION ALL SELECT 'Subastas ACTIVE', CAST(COUNT(*) AS NVARCHAR(100)) FROM auction.Auction WHERE StatusCode='ACTIVE'
  UNION ALL SELECT 'Subastas FINALIZED', CAST(COUNT(*) AS NVARCHAR(100)) FROM auction.Auction WHERE StatusCode='FINALIZED'
  UNION ALL SELECT 'Bids', CAST(COUNT(*) AS NVARCHAR(100)) FROM auction.Bid
  UNION ALL SELECT 'Ledger', CAST(COUNT(*) AS NVARCHAR(100)) FROM finance.Ledger
  UNION ALL SELECT 'EmailOutbox', CAST(COUNT(*) AS NVARCHAR(100)) FROM audit.EmailOutbox;
END
GO

/* =========================================================
   Runner de ejemplo (ajusta parámetros a gusto)
   ========================================================= */
-- EXEC admin.sp_GenerateDemoData
--   @Artists=8,
--   @Curators=3,
--   @Collectors=25,
--   @NFTsPerArtist=6,
--   @ApproveRatio=0.75,
--   @MinBidsPerAuction=3,
--   @MaxBidsPerAuction=8,
--   @FinalizeRatio=0.60,
--   @CollectorFundsETH=500,
--   @ArtistFundsETH=50,
--   @CuratorFundsETH=10,
--   @EnableEmails=0,
--   @UseDeterministic=1,
--   @BatchTag=NULL;
