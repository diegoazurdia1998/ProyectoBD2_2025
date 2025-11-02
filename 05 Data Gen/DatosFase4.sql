/*
=====================================================================================
 SCRIPT DE SIMULACIÓN DE DATOS - ArteCryptoAuctions
 
 Propósito: Poblar la base de datos siguiendo la lógica de negocio 
            (triggers y procedimientos almacenados) para probar las 
            consultas analíticas.
=====================================================================================
*/
USE ArteCryptoAuctions;
GO

SET NOCOUNT ON;

-- Usamos una transacción para asegurar que todo se ejecute correctamente.
BEGIN TRANSACTION;

BEGIN TRY

    -- Variables para almacenar los IDs de los usuarios
    DECLARE @AdminId BIGINT, @ArtistId_Ana BIGINT, @ArtistId_Bruno BIGINT;
    DECLARE @CuratorId_Clara BIGINT, @CuratorId_David BIGINT;
    DECLARE @BidderId_Eva BIGINT, @BidderId_Franco BIGINT;
    
    -- Variables para IDs de entidades
    DECLARE @Ana_NFT1_Id BIGINT, @Ana_NFT2_Id BIGINT, @Ana_NFT3_Id BIGINT;
    DECLARE @Bruno_NFT1_Id BIGINT, @Bruno_NFT2_Id BIGINT;
    
    DECLARE @AuctionId_Ana1 BIGINT, @AuctionId_Ana3 BIGINT, @AuctionId_Bruno1 BIGINT, @AuctionId_Bruno2 BIGINT;

    -- Variable para simular fechas (hace un mes)
    DECLARE @UnMesAtras DATETIME2(3) = DATEADD(MONTH, -1, SYSUTCDATETIME());


    PRINT '======================================================================';
    PRINT 'PASO 1: Creación de Usuarios, Roles, Emails y Wallets';
    PRINT '======================================================================';

    -- Insertar Usuarios
    INSERT INTO core.[User] (FullName, CreatedAtUtc) VALUES
    (N'Admin Plataforma', @UnMesAtras), -- ID 1 (asumido por IDENTITY)
    (N'Ana Artista', @UnMesAtras),      -- ID 2
    (N'Bruno Artista', @UnMesAtras),    -- ID 3
    (N'Clara Curadora', @UnMesAtras),   -- ID 4
    (N'David Curador', @UnMesAtras),    -- ID 5
    (N'Eva Bidder', @UnMesAtras),        -- ID 6
    (N'Franco Bidder', @UnMesAtras);     -- ID 7

    -- Capturar IDs
    SELECT @AdminId = UserId FROM core.[User] WHERE FullName = N'Admin Plataforma';
    SELECT @ArtistId_Ana = UserId FROM core.[User] WHERE FullName = N'Ana Artista';
    SELECT @ArtistId_Bruno = UserId FROM core.[User] WHERE FullName = N'Bruno Artista';
    SELECT @CuratorId_Clara = UserId FROM core.[User] WHERE FullName = N'Clara Curadora';
    SELECT @CuratorId_David = UserId FROM core.[User] WHERE FullName = N'David Curador';
    SELECT @BidderId_Eva = UserId FROM core.[User] WHERE FullName = N'Eva Bidder';
    SELECT @BidderId_Franco = UserId FROM core.[User] WHERE FullName = N'Franco Bidder';

    -- Asignar Roles
    INSERT INTO core.UserRole (UserId, RoleId) VALUES
    (@AdminId, 1), -- ADMIN
    (@ArtistId_Ana, 2), -- ARTIST
    (@ArtistId_Bruno, 2), -- ARTIST
    (@CuratorId_Clara, 3), -- CURATOR
    (@CuratorId_David, 3), -- CURATOR
    (@BidderId_Eva, 4), -- BIDDER
    (@BidderId_Franco, 4); -- BIDDER

    -- Asignar Emails (Requerido por tr_NFT_InsertFlow)
    INSERT INTO core.UserEmail (UserId, Email, IsPrimary, VerifiedAtUtc, StatusCode) VALUES
    (@AdminId, 'admin@crypto.com', 1, @UnMesAtras, 'ACTIVE'),
    (@ArtistId_Ana, 'ana@artista.com', 1, @UnMesAtras, 'ACTIVE'),
    (@ArtistId_Bruno, 'bruno@artista.com', 1, @UnMesAtras, 'ACTIVE'),
    (@CuratorId_Clara, 'clara@curadora.com', 1, @UnMesAtras, 'ACTIVE'),
    (@CuratorId_David, 'david@curador.com', 1, @UnMesAtras, 'ACTIVE'),
    (@BidderId_Eva, 'eva@bidder.com', 1, @UnMesAtras, 'ACTIVE'),
    (@BidderId_Franco, 'franco@bidder.com', 1, @UnMesAtras, 'ACTIVE');

    -- Asignar Wallets (Requerido por sp_PlaceBid)
    INSERT INTO core.Wallet (UserId, BalanceETH, ReservedETH) VALUES
    (@AdminId, 1000.0, 0),
    (@ArtistId_Ana, 0.0, 0),    -- Artistas empiezan en 0
    (@ArtistId_Bruno, 0.0, 0),  -- Artistas empiezan en 0
    (@CuratorId_Clara, 10.0, 0),
    (@CuratorId_David, 10.0, 0),
    (@BidderId_Eva, 20.0, 0),    -- Bidders necesitan fondos
    (@BidderId_Franco, 20.0, 0); -- Bidders necesitan fondos

    PRINT '... Usuarios y Wallets creados.';


    PRINT '======================================================================';
    PRINT 'PASO 2: Simulación de Actividad (MES PASADO)';
    PRINT '======================================================================';

    PRINT '--- 2.1: Ana (Artista) sube un NFT (Mes Pasado) ---';
    -- Se inserta con datos mínimos. El Trigger [tr_NFT_InsertFlow] hará el trabajo.
    INSERT INTO nft.NFT 
        (ArtistId, SettingsID, [Name], [Description], ContentType, HashCode, 
         FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, CreatedAtUtc)
    VALUES
        (@ArtistId_Ana, 1, N'Amanecer Cripto', N'La primera obra de Ana', 'image/png', 'HASH_DUMMY_1', 
         500000, 1024, 1024, 0.5, @UnMesAtras);

    -- Capturamos el ID del NFT creado
    SELECT @Ana_NFT1_Id = NFTId FROM nft.NFT WHERE [Name] = N'Amanecer Cripto';
    PRINT N'... NFT ''Amanecer Cripto'' (ID: ' + CAST(@Ana_NFT1_Id AS NVARCHAR) + N') enviado a curación.';
    
    PRINT '--- 2.2: Clara (Curadora) APRUEBA el NFT (Mes Pasado) ---';
    -- El trigger [tr_NFT_InsertFlow] ya creó la revisión. La actualizamos.
    -- Simulamos que tardó 8 horas.
    UPDATE admin.CurationReview
    SET 
        DecisionCode = 'APPROVED',
        ReviewedAtUtc = DATEADD(HOUR, 8, StartedAtUtc)
    WHERE 
        NFTId = @Ana_NFT1_Id AND DecisionCode = 'PENDING';

    PRINT N'... NFT (ID: ' + CAST(@Ana_NFT1_Id AS NVARCHAR) + N') APROBADO por Clara.';
    PRINT N'... Trigger [tr_CurationReview_Decision] disparado.';
    PRINT N'... Trigger [tr_NFT_CreateAuction] disparado: Subasta creada automáticamente.';

    -- Capturamos el ID de la subasta creada por el trigger
    SELECT @AuctionId_Ana1 = AuctionId FROM auction.Auction WHERE NFTId = @Ana_NFT1_Id;

   PRINT '--- 2.3: Bidders ofertan por la obra de Ana (Mes Pasado) ---';
    -- NOTA: La subasta (ID: @AuctionId_Ana1) está activa AHORA (creada por el trigger).
    -- Realizamos las ofertas AHORA, y LUEGO movemos las fechas al pasado.

    -- 1. Definir fechas objetivo del pasado
    DECLARE @FechaInicioSubasta DATETIME2(3) = DATEADD(DAY, -30, SYSUTCDATETIME());
    DECLARE @FechaOferta1_Pasado DATETIME2(3) = DATEADD(DAY, -29, SYSUTCDATETIME());
    DECLARE @FechaOferta2_Pasado DATETIME2(3) = DATEADD(DAY, -28, SYSUTCDATETIME());
    DECLARE @FechaFinSubasta_Pasado DATETIME2(3) = DATEADD(DAY, -27, SYSUTCDATETIME());

    -- 2. Colocar ofertas (el SP se ejecuta en tiempo real, con la subasta activa)
    PRINT N'... Eva oferta 0.6 ETH';
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId_Ana1, @BidderId = @BidderId_Eva, @AmountETH = 0.6;
    
    PRINT N'... Franco oferta 0.7 ETH';
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId_Ana1, @BidderId = @BidderId_Franco, @AmountETH = 0.7;

    -- 3. "Viajar en el tiempo": Mover las fechas de las ofertas al pasado
    -- (Actualizamos las ofertas que acabamos de hacer para que APARENTEN ser del pasado)
    UPDATE auction.Bid 
    SET PlacedAtUtc = @FechaOferta1_Pasado 
    WHERE AuctionId = @AuctionId_Ana1 AND BidderId = @BidderId_Eva;
    
    UPDATE auction.Bid 
    SET PlacedAtUtc = @FechaOferta2_Pasado 
    WHERE AuctionId = @AuctionId_Ana1 AND BidderId = @BidderId_Franco;
    
    -- 4. "Viajar en el tiempo": Mover la subasta al pasado
    -- (Ahora que las ofertas terminaron, movemos el marco de tiempo de la subasta)
    UPDATE auction.Auction
    SET 
        StartAtUtc = @FechaInicioSubasta,
        EndAtUtc = @FechaFinSubasta_Pasado
    WHERE AuctionId = @AuctionId_Ana1;
    
    PRINT '... Ofertas y Subasta movidas exitosamente al mes pasado.';


    PRINT '--- 2.4: Se cierra la subasta (Mes Pasado) ---';
    -- Marcamos la subasta como completada
    UPDATE auction.Auction
    SET 
        StatusCode = 'COMPLETED',
        -- El SP ya actualizó el líder (Franco) y el precio (0.7)
        -- Nos aseguramos que la fecha de fin sea la del pasado
        EndAtUtc = @FechaFinSubasta_Pasado
    WHERE 
        AuctionId = @AuctionId_Ana1;
        
    PRINT N'... Subasta (ID: ' + CAST(@AuctionId_Ana1 AS NVARCHAR) + N') marcada como COMPLETADA.';
    PRINT N'... Trigger [tr_Auction_ProcesarCompletada] disparado:';
    PRINT N'    - Fondos transferidos a Ana (Artista).';
    PRINT N'    - NFT transferido a Franco (Ganador).';
    PRINT N'    - Reserva de Eva (Perdedora) liberada.';

    PRINT '======================================================================';
    PRINT 'PASO 3: Simulación de Actividad (MES ACTUAL)';
    PRINT '======================================================================';

    PRINT '--- 3.1: Artistas suben más NFTs (Mes Actual) ---';
    
    -- Ana sube 2 más
    INSERT INTO nft.NFT (ArtistId, SettingsID, [Name], [Description], ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, CreatedAtUtc) VALUES
    (@ArtistId_Ana, 1, N'Atardecer Rojo', N'La segunda obra de Ana', 'image/png', 'HASH_DUMMY_2', 600000, 1024, 768, 0.8, SYSUTCDATETIME()),
    (@ArtistId_Ana, 1, N'Noche Estrellada', N'La tercera obra de Ana', 'image/png', 'HASH_DUMMY_3', 700000, 1280, 1024, 1.0, SYSUTCDATETIME());
    
    -- Bruno sube 2
    INSERT INTO nft.NFT (ArtistId, SettingsID, [Name], [Description], ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx, SuggestedPriceETH, CreatedAtUtc) VALUES
    (@ArtistId_Bruno, 1, N'Geometría Pura', N'La obra maestra de Bruno', 'image/png', 'HASH_DUMMY_4', 800000, 2048, 2048, 1.2, SYSUTCDATETIME()),
    (@ArtistId_Bruno, 1, N'El Cubo', N'La segunda de Bruno', 'image/png', 'HASH_DUMMY_5', 400000, 1000, 1000, 0.4, SYSUTCDATETIME());

    -- Capturamos IDs
    SELECT @Ana_NFT2_Id = NFTId FROM nft.NFT WHERE [Name] = N'Atardecer Rojo';
    SELECT @Ana_NFT3_Id = NFTId FROM nft.NFT WHERE [Name] = N'Noche Estrellada';
    SELECT @Bruno_NFT1_Id = NFTId FROM nft.NFT WHERE [Name] = N'Geometría Pura';
    SELECT @Bruno_NFT2_Id = NFTId FROM nft.NFT WHERE [Name] = N'El Cubo';

    PRINT '... 4 nuevos NFTs enviados a curación.';
    PRINT '... Trigger [tr_NFT_InsertFlow] asignó curadores (Round-Robin).';

    PRINT '--- 3.2: Curadores revisan (Mes Actual) ---';

    -- Clara RECHAZA 'Atardecer Rojo' (Simula 30 horas)
    -- (Para el informe de Eficiencia de Curadores)
    UPDATE admin.CurationReview
    SET DecisionCode = 'REJECTED', ReviewedAtUtc = DATEADD(HOUR, 30, StartedAtUtc)
    WHERE NFTId = @Ana_NFT2_Id;
    PRINT N'... Clara RECHAZA ''Atardecer Rojo'' (Lento).';

    -- David APRUEBA 'Noche Estrellada' (Simula 4 horas)
    UPDATE admin.CurationReview
    SET DecisionCode = 'APPROVED', ReviewedAtUtc = DATEADD(HOUR, 4, StartedAtUtc)
    WHERE NFTId = @Ana_NFT3_Id;
    PRINT N'... David APRUEBA ''Noche Estrellada'' (Rápido).';

    -- David APRUEBA 'Geometría Pura' (Simula 6 horas)
    UPDATE admin.CurationReview
    SET DecisionCode = 'APPROVED', ReviewedAtUtc = DATEADD(HOUR, 6, StartedAtUtc)
    WHERE NFTId = @Bruno_NFT1_Id;
    PRINT N'... David APRUEBA ''Geometría Pura'' (Rápido).';

    -- David APRUEBA 'El Cubo' (Simula 5 horas)
    UPDATE admin.CurationReview
    SET DecisionCode = 'APPROVED', ReviewedAtUtc = DATEADD(HOUR, 5, StartedAtUtc)
    WHERE NFTId = @Bruno_NFT2_Id;
    PRINT N'... David APRUEBA ''El Cubo'' (Rápido).';

    PRINT '... 3 nuevas subastas creadas por los triggers.';

    -- Capturamos IDs de las nuevas subastas
    SELECT @AuctionId_Ana3 = AuctionId FROM auction.Auction WHERE NFTId = @Ana_NFT3_Id;
    SELECT @AuctionId_Bruno1 = AuctionId FROM auction.Auction WHERE NFTId = @Bruno_NFT1_Id;
    SELECT @AuctionId_Bruno2 = AuctionId FROM auction.Auction WHERE NFTId = @Bruno_NFT2_Id;

    PRINT '--- 3.3: Bidders ofertan (Mes Actual) ---';

    -- Subasta 1: 'Noche Estrellada' (Ana)
    -- Precio inicial: 1.0 ETH. Mínimo 1.05 ETH
    PRINT N'... Subasta ''Noche Estrellada'':';
    PRINT N'    - Eva oferta 1.05 ETH'; -- CORREGIDO: 1.0 -> 1.05
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId_Ana3, @BidderId = @BidderId_Eva, @AmountETH = 1.05;
    
    -- Nuevo CurrentPrice: 1.05 ETH. Mínimo 1.1025 ETH
    PRINT N'    - Franco oferta 1.11 ETH (Gana Liderazgo)'; -- CORREGIDO: 1.1 -> 1.11
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId_Ana3, @BidderId = @BidderId_Franco, @AmountETH = 1.11;

    -- Subasta 2: 'Geometría Pura' (Bruno)
    -- Precio inicial: 1.2 ETH. Mínimo 1.26 ETH
    PRINT N'... Subasta ''Geometría Pura'':';
    PRINT N'    - Eva oferta 1.3 ETH'; -- Esta oferta (1.3) ya era válida
    EXEC auction.sp_PlaceBid @AuctionId = @AuctionId_Bruno1, @BidderId = @BidderId_Eva, @AmountETH = 1.3;

    -- Subasta 3: 'El Cubo' (Bruno)
    -- Precio inicial: 0.4 ETH. Mínimo 0.42 ETH
    PRINT N'... Subasta ''El Cubo'': (Sin ofertas)';
    
    PRINT '--- 3.4: Se cierran las subastas (Mes Actual) ---';
    
    -- Subasta 'Noche Estrellada' (GANADOR: Franco)
    UPDATE auction.Auction SET StatusCode = 'COMPLETED', EndAtUtc = SYSUTCDATETIME()
    WHERE AuctionId = @AuctionId_Ana3;
    PRINT N'... Subasta ''Noche Estrellada'' completada. Ganador: Franco (1.1 ETH).';

    -- Subasta 'Geometría Pura' (GANADOR: Eva)
    UPDATE auction.Auction SET StatusCode = 'COMPLETED', EndAtUtc = SYSUTCDATETIME()
    WHERE AuctionId = @AuctionId_Bruno1;
    PRINT N'... Subasta ''Geometría Pura'' completada. Ganador: Eva (1.3 ETH).';
    
    -- Subasta 'El Cubo' (SIN GANADOR)
    UPDATE auction.Auction SET StatusCode = 'COMPLETED', EndAtUtc = SYSUTCDATETIME()
    WHERE AuctionId = @AuctionId_Bruno2;
    PRINT N'... Subasta ''El Cubo'' completada. (Sin ganador).';

    PRINT '... Triggers [tr_Auction_ProcesarCompletada] disparados para las 3 subastas.';

    PRINT '======================================================================';
    PRINT 'SIMULACIÓN COMPLETADA';
    PRINT '======================================================================';

    -- Si todo fue bien, confirmamos la transacción
    COMMIT TRANSACTION;
    
    PRINT 'DATOS INSERTADOS Y PROCESADOS CORRECTAMENTE.';
    PRINT '¡Ahora puedes ejecutar tus consultas analíticas!';

END TRY
BEGIN CATCH
    -- Si algo falló, revertimos todo
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT '======================================================================';
    PRINT 'ERROR: Ocurrió un error. Se revirtieron todos los cambios.';
    PRINT '======================================================================';
    
    -- Mostrar el error
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorLine INT = ERROR_LINE();
    PRINT N'Error en línea ' + CAST(@ErrorLine AS NVARCHAR(10)) + N': ' + @ErrorMessage;
END CATCH
GO