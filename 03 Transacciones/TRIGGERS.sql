-- TRIGGERS
use ArteCryptoAuctions
go

-- =====================================================================================
-- TRIGGER 1: Inserci�n de NFT con validaciones y asignaci�n de curador
-- =====================================================================================
CREATE OR ALTER TRIGGER nft.tr_NFT_InsertFlow
ON nft.NFT
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Variables de control
        DECLARE @ErrorMsg NVARCHAR(MAX);
        DECLARE @CuratorCount INT;
        
        -------------------------------------------------------------------
        -- 0) Normalizar batch a tabla temporal
        -------------------------------------------------------------------
        DECLARE @InputNFT TABLE(
            RowNum           INT IDENTITY(1,1),
            ArtistId         BIGINT NOT NULL,
            SettingsID       INT NOT NULL,
            CurrentOwnerId   BIGINT NULL,
            [Name]           NVARCHAR(160) NOT NULL,
            [Description]    NVARCHAR(MAX) NULL,
            ContentType      NVARCHAR(100) NOT NULL,
            FileSizeBytes    BIGINT NULL,
            WidthPx          INT NULL,
            HeightPx         INT NULL,
            SuggestedPriceETH DECIMAL(38,18) NULL,
            StatusCode       VARCHAR(30) NOT NULL,
            CreatedAtUtc     DATETIME2(3) NOT NULL
        );

        INSERT INTO @InputNFT
        SELECT 
            i.ArtistId, i.SettingsID, i.CurrentOwnerId,
            i.[Name], i.[Description], i.ContentType,
            i.FileSizeBytes, i.WidthPx, i.HeightPx, 
            i.SuggestedPriceETH, i.StatusCode, i.CreatedAtUtc
        FROM inserted i;

        -------------------------------------------------------------------
        -- 1) Validaci�n: Usuario debe tener rol ARTIST (RoleId = 2)
        -------------------------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM @InputNFT x
            LEFT JOIN core.UserRole ur ON ur.UserId = x.ArtistId AND ur.RoleId = 2
            WHERE ur.UserId IS NULL
        )
        BEGIN
            -- Notificar a usuarios sin rol de artista
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                x.ArtistId,
                (SELECT TOP 1 ue.Email 
                 FROM core.UserEmail ue 
                 WHERE ue.UserId = x.ArtistId AND ue.IsPrimary = 1 
                 ORDER BY ue.EmailId),
                N'NFT Rechazado - Rol Inv�lido',
                N'Su NFT "' + x.[Name] + N'" no pudo ser aceptado. Raz�n: El usuario no posee el rol de Artista. Por favor, contacte al administrador para obtener los permisos necesarios.',
                'PENDING'
            FROM @InputNFT x
            LEFT JOIN core.UserRole ur ON ur.UserId = x.ArtistId AND ur.RoleId = 2
            WHERE ur.UserId IS NULL;
            
            RETURN; -- No insertar NFTs
        END;

        -------------------------------------------------------------------
        -- 2) Validaci�n: Email primario debe existir
        -------------------------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM @InputNFT x
            LEFT JOIN core.UserEmail ue ON ue.UserId = x.ArtistId AND ue.IsPrimary = 1
            WHERE ue.EmailId IS NULL
        )
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                x.ArtistId,
                NULL,
                N'NFT Rechazado - Email Requerido',
                N'Su NFT "' + x.[Name] + N'" no pudo ser aceptado. Raz�n: No tiene un email primario configurado. Por favor, configure un email primario en su perfil.',
                'PENDING'
            FROM @InputNFT x
            LEFT JOIN core.UserEmail ue ON ue.UserId = x.ArtistId AND ue.IsPrimary = 1
            WHERE ue.EmailId IS NULL;
            
            RETURN;
        END;

        -------------------------------------------------------------------
        -- 3) Validaciones t�cnicas contra NFTSettings
        -------------------------------------------------------------------
        DECLARE @ValidationResults TABLE(
            RowNum INT,
            ArtistId BIGINT,
            [Name] NVARCHAR(160),
            SettingsID INT,
            WidthPx INT,
            HeightPx INT,
            FileSizeBytes BIGINT,
            MinWidthPx BIGINT,
            MaxWidthPx BIGINT,
            MinHeightPx BIGINT,
            MaxHeightPx BIGINT,
            MinFileSizeBytes BIGINT,
            MaxFileSizeBytes BIGINT,
            SettingsExists BIT,
            ValidationError NVARCHAR(500)
        );

        INSERT INTO @ValidationResults
        SELECT 
            x.RowNum,
            x.ArtistId,
            x.[Name],
            x.SettingsID,
            x.WidthPx,
            x.HeightPx,
            x.FileSizeBytes,
            s.MinWidthPx,
            s.MaxWidthPx,
            s.MinHeigntPx,
            s.MaxHeightPx,
            s.MinFileSizeBytes,
            s.MaxFileSizeBytes,
            CASE WHEN s.SettingsID IS NULL THEN 0 ELSE 1 END,
            CASE 
                WHEN s.SettingsID IS NULL THEN N'Configuraci�n de NFT inexistente'
                WHEN x.WidthPx IS NULL AND s.MinWidthPx IS NOT NULL THEN N'Ancho (WidthPx) es requerido'
                WHEN x.WidthPx < s.MinWidthPx THEN N'Ancho menor al m�nimo permitido (' + CAST(s.MinWidthPx AS NVARCHAR) + N'px)'
                WHEN x.WidthPx > s.MaxWidthPx THEN N'Ancho mayor al m�ximo permitido (' + CAST(s.MaxWidthPx AS NVARCHAR) + N'px)'
                WHEN x.HeightPx IS NULL AND s.MinHeigntPx IS NOT NULL THEN N'Alto (HeightPx) es requerido'
                WHEN x.HeightPx < s.MinHeigntPx THEN N'Alto menor al m�nimo permitido (' + CAST(s.MinHeigntPx AS NVARCHAR) + N'px)'
                WHEN x.HeightPx > s.MaxHeightPx THEN N'Alto mayor al m�ximo permitido (' + CAST(s.MaxHeightPx AS NVARCHAR) + N'px)'
                WHEN x.FileSizeBytes IS NULL AND s.MinFileSizeBytes IS NOT NULL THEN N'Tama�o de archivo es requerido'
                WHEN x.FileSizeBytes < s.MinFileSizeBytes THEN N'Archivo muy peque�o (m�nimo: ' + CAST(s.MinFileSizeBytes AS NVARCHAR) + N' bytes)'
                WHEN x.FileSizeBytes > s.MaxFileSizeBytes THEN N'Archivo muy grande (m�ximo: ' + CAST(s.MaxFileSizeBytes AS NVARCHAR) + N' bytes)'
                ELSE NULL
            END
        FROM @InputNFT x
        LEFT JOIN nft.NFTSettings s ON s.SettingsID = x.SettingsID;

        -- Si hay errores de validaci�n, notificar y salir
        IF EXISTS (SELECT 1 FROM @ValidationResults WHERE ValidationError IS NOT NULL)
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                v.ArtistId,
                (SELECT TOP 1 ue.Email 
                 FROM core.UserEmail ue 
                 WHERE ue.UserId = v.ArtistId AND ue.IsPrimary = 1 
                 ORDER BY ue.EmailId),
                N'NFT Rechazado - Validaci�n T�cnica',
                N'Su NFT "' + v.[Name] + N'" no pudo ser aceptado. Raz�n: ' + v.ValidationError + N'. Por favor, corrija el archivo y vuelva a intentarlo.',
                'PENDING'
            FROM @ValidationResults v
            WHERE v.ValidationError IS NOT NULL;
            
            RETURN;
        END;

        -------------------------------------------------------------------
        -- 4) Verificar que existan curadores disponibles
        -------------------------------------------------------------------
        SELECT @CuratorCount = COUNT(DISTINCT ur.UserId)
        FROM core.UserRole ur
        WHERE ur.RoleId = 3; -- Rol CURATOR

        IF @CuratorCount = 0
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                x.ArtistId,
                (SELECT TOP 1 ue.Email 
                 FROM core.UserEmail ue 
                 WHERE ue.UserId = x.ArtistId AND ue.IsPrimary = 1 
                 ORDER BY ue.EmailId),
                N'NFT en Espera - Sin Curadores',
                N'Su NFT "' + x.[Name] + N'" ha sido aceptado pero actualmente no hay curadores disponibles. Ser� asignado autom�ticamente cuando haya un curador disponible.',
                'PENDING'
            FROM @InputNFT x;
            
            RETURN;
        END;

        -------------------------------------------------------------------
        -- 5) Asegurar que existe el estado PENDING en ops.Status
        -------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'CURATION_DECISION' AND Code = 'PENDING')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('CURATION_DECISION', 'PENDING', N'Pendiente de revisi�n por curador');
        END;

        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'PENDING')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('NFT', 'PENDING', N'NFT pendiente de aprobaci�n');
        END;

        -------------------------------------------------------------------
        -- 6) INSERTAR NFTs v�lidos con HashCode autogenerado
        -------------------------------------------------------------------
        DECLARE @NewNFTs TABLE(
            NFTId BIGINT,
            ArtistId BIGINT,
            [Name] NVARCHAR(160)
        );

        -- Insertar NFTs y capturar IDs
        INSERT INTO nft.NFT(
            ArtistId, SettingsID, CurrentOwnerId, [Name], [Description],
            ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx,
            SuggestedPriceETH, StatusCode, CreatedAtUtc
        )
        OUTPUT 
            inserted.NFTId, 
            inserted.ArtistId, 
            inserted.[Name]
        INTO @NewNFTs(NFTId, ArtistId, [Name])
        SELECT
            x.ArtistId,
            x.SettingsID,
            x.CurrentOwnerId,
            x.[Name],
            x.[Description],
            x.ContentType,
            -- HashCode autogenerado con SHA2_256
            LEFT(
                CONVERT(VARCHAR(64),
                    HASHBYTES('SHA2_256',
                        CAST(NEWID() AS VARBINARY(16))
                        + CAST(x.ArtistId AS VARBINARY(8))
                        + CAST(SYSUTCDATETIME() AS VARBINARY(16))
                        + CRYPT_GEN_RANDOM(16)
                    ), 2
                ),
                64
            ),
            x.FileSizeBytes,
            x.WidthPx,
            x.HeightPx,
            x.SuggestedPriceETH,
            'PENDING', -- Estado inicial
            x.CreatedAtUtc
        FROM @InputNFT x;

        -- Agregar RowNum despu�s del INSERT
        DECLARE @NewNFTsWithRow TABLE(
            NFTId BIGINT,
            ArtistId BIGINT,
            [Name] NVARCHAR(160),
            RowNum INT
        );

        INSERT INTO @NewNFTsWithRow
        SELECT 
            n.NFTId,
            n.ArtistId,
            n.[Name],
            x.RowNum
        FROM @NewNFTs n
        JOIN @InputNFT x ON x.ArtistId = n.ArtistId AND x.[Name] = n.[Name];

        -------------------------------------------------------------------
        -- 7) Asignaci�n Round-Robin de curadores
        -------------------------------------------------------------------
        DECLARE @Curators TABLE(
            Idx INT IDENTITY(1,1),
            CuratorId BIGINT
        );

        INSERT INTO @Curators(CuratorId)
        SELECT DISTINCT ur.UserId
        FROM core.UserRole ur
        WHERE ur.RoleId = 3
        ORDER BY ur.UserId;

        -- Obtener posici�n actual del round-robin
        DECLARE @CurrentPos INT;
        
        SELECT @CurrentPos = TRY_CAST(SettingValue AS INT)
        FROM ops.Settings WITH (UPDLOCK, HOLDLOCK)
        WHERE SettingKey = 'CURATION_RR_POS';

        IF @CurrentPos IS NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM ops.Settings WHERE SettingKey = 'CURATION_RR_POS')
                UPDATE ops.Settings 
                SET SettingValue = '0', UpdatedAtUtc = SYSUTCDATETIME() 
                WHERE SettingKey = 'CURATION_RR_POS';
            ELSE
                INSERT INTO ops.Settings(SettingKey, SettingValue)
                VALUES('CURATION_RR_POS', '0');
            
            SET @CurrentPos = 0;
        END;

        -- Asignar curadores usando round-robin
        DECLARE @Assignments TABLE(
            NFTId BIGINT,
            ArtistId BIGINT,
            [Name] NVARCHAR(160),
            CuratorIdx INT,
            CuratorId BIGINT
        );

        ;WITH AssignmentCTE AS (
            SELECT 
                n.NFTId,
                n.ArtistId,
                n.[Name],
                ((@CurrentPos + n.RowNum - 1) % @CuratorCount) + 1 AS CuratorIdx
            FROM @NewNFTsWithRow n
        )
        INSERT INTO @Assignments(NFTId, ArtistId, [Name], CuratorIdx, CuratorId)
        SELECT 
            a.NFTId,
            a.ArtistId,
            a.[Name],
            a.CuratorIdx,
            c.CuratorId
        FROM AssignmentCTE a
        JOIN @Curators c ON c.Idx = a.CuratorIdx;

        -------------------------------------------------------------------
        -- 8) Crear registros de CurationReview
        -------------------------------------------------------------------
        INSERT INTO admin.CurationReview(NFTId, CuratorId, DecisionCode, StartedAtUtc)
        SELECT 
            a.NFTId,
            a.CuratorId,
            'PENDING',
            SYSUTCDATETIME()
        FROM @Assignments a;

        -------------------------------------------------------------------
        -- 9) Notificar a artistas (NFT aceptado y en revisi�n)
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            n.ArtistId,
            ue.Email,
            N'NFT Aceptado - En Revisi�n',
            N'�Felicidades! Su NFT "' + n.[Name] + N'" ha sido aceptado por el sistema y ha sido enviado a curaci�n. Un curador revisar� su obra pronto y recibir� una notificaci�n con la decisi�n.',
            'PENDING'
        FROM @NewNFTs n
        JOIN core.UserEmail ue ON ue.UserId = n.ArtistId AND ue.IsPrimary = 1;

        -------------------------------------------------------------------
        -- 10) Notificar a curadores asignados
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            a.CuratorId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = a.CuratorId AND ue.IsPrimary = 1 
             ORDER BY ue.EmailId),
            N'Nuevo NFT para Revisi�n',
            N'Se le ha asignado un nuevo NFT para revisi�n:' + CHAR(13) + CHAR(10) +
            N'- NFT ID: ' + CAST(a.NFTId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'- Nombre: "' + a.[Name] + N'"' + CHAR(13) + CHAR(10) +
            N'- Artista ID: ' + CAST(a.ArtistId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'Por favor, revise el NFT y tome una decisi�n (APPROVED/REJECTED).',
            'PENDING'
        FROM @Assignments a;

        -------------------------------------------------------------------
        -- 11) Actualizar posici�n del round-robin
        -------------------------------------------------------------------
        DECLARE @NFTCount INT = (SELECT COUNT(*) FROM @NewNFTs);
        
        UPDATE ops.Settings
        SET 
            SettingValue = CAST(((@CurrentPos + @NFTCount) % @CuratorCount) AS NVARCHAR(50)),
            UpdatedAtUtc = SYSUTCDATETIME()
        WHERE SettingKey = 'CURATION_RR_POS';

    END TRY
    BEGIN CATCH
        -- Manejo de errores
        SET @ErrorMsg = N'Error en tr_NFT_InsertFlow: ' + ERROR_MESSAGE();
        
        -- Log del error
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        VALUES(
            NULL,
            'admin@artecryptoauctions.com',
            N'Error en Sistema - Inserci�n NFT',
            @ErrorMsg,
            'PENDING'
        );
        
        -- Re-lanzar el error
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 2: Decisi�n del curador (APPROVED/REJECTED)
-- =====================================================================================
CREATE OR ALTER TRIGGER admin.tr_CurationReview_Decision
ON admin.CurationReview
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo procesar si se actualiz� DecisionCode
    IF NOT UPDATE(DecisionCode)
        RETURN;
    
    BEGIN TRY
        DECLARE @ErrorMsg NVARCHAR(MAX);
        
        -- Tabla para procesar decisiones
        DECLARE @Decisions TABLE(
            ReviewId BIGINT,
            NFTId BIGINT,
            CuratorId BIGINT,
            ArtistId BIGINT,
            ArtistEmail NVARCHAR(100),
            NFTName NVARCHAR(160),
            DecisionCode VARCHAR(30),
            OldDecisionCode VARCHAR(30),
            ReviewedAtUtc DATETIME2(3)
        );

        -- Capturar solo las decisiones que cambiaron de PENDING a APPROVED/REJECTED
        INSERT INTO @Decisions
        SELECT 
            i.ReviewId,
            i.NFTId,
            i.CuratorId,
            nft.ArtistId,
            ue.Email,
            nft.[Name],
            i.DecisionCode,
            d.DecisionCode,
            i.ReviewedAtUtc
        FROM inserted i
        JOIN deleted d ON d.ReviewId = i.ReviewId
        JOIN nft.NFT nft ON nft.NFTId = i.NFTId
        JOIN core.UserEmail ue ON ue.UserId = nft.ArtistId AND ue.IsPrimary = 1
        WHERE i.DecisionCode IN ('APPROVED', 'REJECTED')
          AND d.DecisionCode = 'PENDING'
          AND i.DecisionCode <> d.DecisionCode;

        -- Si no hay decisiones nuevas, salir
        IF NOT EXISTS (SELECT 1 FROM @Decisions)
            RETURN;

        -------------------------------------------------------------------
        -- Asegurar que existen los estados necesarios
        -------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'APPROVED')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('NFT', 'APPROVED', N'NFT aprobado y listo para subasta');
        END;

        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'REJECTED')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('NFT', 'REJECTED', N'NFT rechazado por curador');
        END;

        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'AUCTION' AND Code = 'ACTIVE')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('AUCTION', 'ACTIVE', N'Subasta activa');
        END;

        -------------------------------------------------------------------
        -- Actualizar ReviewedAtUtc si es NULL
        -------------------------------------------------------------------
        UPDATE admin.CurationReview
        SET ReviewedAtUtc = SYSUTCDATETIME()
        WHERE ReviewId IN (SELECT ReviewId FROM @Decisions)
          AND ReviewedAtUtc IS NULL;

        -------------------------------------------------------------------
        -- Procesar NFTs APROBADOS
        -------------------------------------------------------------------
        -- Actualizar estado del NFT
        UPDATE nft.NFT
        SET 
            StatusCode = 'APPROVED',
            ApprovedAtUtc = SYSUTCDATETIME()
        WHERE NFTId IN (
            SELECT NFTId 
            FROM @Decisions 
            WHERE DecisionCode = 'APPROVED'
        );

        -- Notificar a artistas (APROBADO)
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            d.ArtistId,
            d.ArtistEmail,
            N'�NFT Aprobado!',
            N'�Excelentes noticias! Su NFT "' + d.NFTName + N'" ha sido aprobado por el curador.' + CHAR(13) + CHAR(10) +
            N'Su obra entrar� autom�ticamente en subasta. Recibir� una notificaci�n cuando la subasta est� activa.',
            'PENDING'
        FROM @Decisions d
        WHERE d.DecisionCode = 'APPROVED';

        -------------------------------------------------------------------
        -- Procesar NFTs RECHAZADOS
        -------------------------------------------------------------------
        -- Actualizar estado del NFT
        UPDATE nft.NFT
        SET StatusCode = 'REJECTED'
        WHERE NFTId IN (
            SELECT NFTId 
            FROM @Decisions 
            WHERE DecisionCode = 'REJECTED'
        );

        -- Notificar a artistas (RECHAZADO)
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            d.ArtistId,
            d.ArtistEmail,
            N'NFT No Aprobado',
            N'Lamentamos informarle que su NFT "' + d.NFTName + N'" no ha sido aprobado en esta ocasi�n.' + CHAR(13) + CHAR(10) +
            N'Le invitamos a revisar las pol�ticas de contenido y volver a intentarlo con una nueva obra.',
            'PENDING'
        FROM @Decisions d
        WHERE d.DecisionCode = 'REJECTED';

        -------------------------------------------------------------------
        -- Notificar a curadores sobre su decisi�n procesada
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            d.CuratorId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = d.CuratorId AND ue.IsPrimary = 1 
             ORDER BY ue.EmailId),
            N'Decisi�n Procesada',
            N'Su decisi�n sobre el NFT "' + d.NFTName + N'" (ID: ' + CAST(d.NFTId AS NVARCHAR(20)) + N') ha sido procesada exitosamente.' + CHAR(13) + CHAR(10) +
            N'Decisi�n: ' + CASE d.DecisionCode WHEN 'APPROVED' THEN N'APROBADO' ELSE N'RECHAZADO' END,
            'PENDING'
        FROM @Decisions d;

    END TRY
    BEGIN CATCH
        SET @ErrorMsg = N'Error en tr_CurationReview_Decision: ' + ERROR_MESSAGE();
        
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        VALUES(
            NULL,
            'admin@artecryptoauctions.com',
            N'Error en Sistema - Decisi�n Curador',
            @ErrorMsg,
            'PENDING'
        );
        
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 3: Crear subasta autom�ticamente cuando NFT es aprobado
-- =====================================================================================
CREATE OR ALTER TRIGGER nft.tr_NFT_CreateAuction
ON nft.NFT
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo procesar si se actualiz� StatusCode a APPROVED
    IF NOT UPDATE(StatusCode)
        RETURN;
    
    BEGIN TRY
        DECLARE @ErrorMsg NVARCHAR(MAX);
        
        -- Tabla para NFTs reci�n aprobados
        DECLARE @ApprovedNFTs TABLE(
            NFTId BIGINT,
            ArtistId BIGINT,
            ArtistEmail NVARCHAR(100),
            NFTName NVARCHAR(160),
            SuggestedPriceETH DECIMAL(38,18)
        );

        -- Capturar NFTs que cambiaron a APPROVED
        INSERT INTO @ApprovedNFTs
        SELECT 
            i.NFTId,
            i.ArtistId,
            ue.Email,
            i.[Name],
            i.SuggestedPriceETH
        FROM inserted i
        JOIN deleted d ON d.NFTId = i.NFTId
        JOIN core.UserEmail ue ON ue.UserId = i.ArtistId AND ue.IsPrimary = 1
        WHERE i.StatusCode = 'APPROVED'
          AND d.StatusCode <> 'APPROVED'
          AND i.ApprovedAtUtc IS NOT NULL;

        -- Si no hay NFTs aprobados, salir
        IF NOT EXISTS (SELECT 1 FROM @ApprovedNFTs)
            RETURN;

        -------------------------------------------------------------------
        -- Obtener configuraci�n de subastas
        -------------------------------------------------------------------
        DECLARE @SettingsID INT;
        DECLARE @BasePriceETH DECIMAL(38,18);
        DECLARE @DefaultAuctionHours TINYINT;

        SELECT TOP 1
            @SettingsID = SettingsID,
            @BasePriceETH = BasePriceETH,
            @DefaultAuctionHours = DefaultAuctionHours
        FROM auction.AuctionSettings
        ORDER BY SettingsID;

        -- Si no hay configuraci�n, usar valores por defecto
        IF @SettingsID IS NULL
        BEGIN
            SET @BasePriceETH = 0.01;
            SET @DefaultAuctionHours = 72;
        END;

        -------------------------------------------------------------------
        -- Crear subastas para cada NFT aprobado
        -------------------------------------------------------------------
        DECLARE @NewAuctions TABLE(
            AuctionId BIGINT,
            NFTId BIGINT,
            StartingPriceETH DECIMAL(38,18),
            StartAtUtc DATETIME2(3),
            EndAtUtc DATETIME2(3)
        );

        -- Insertar subastas
        INSERT INTO auction.Auction(
            SettingsID,
            NFTId,
            StartAtUtc,
            EndAtUtc,
            StartingPriceETH,
            CurrentPriceETH,
            StatusCode
        )
        OUTPUT 
            inserted.AuctionId,
            inserted.NFTId,
            inserted.StartingPriceETH,
            inserted.StartAtUtc,
            inserted.EndAtUtc
        INTO @NewAuctions
        SELECT 
            @SettingsID,
            a.NFTId,
            SYSUTCDATETIME(), -- Inicia inmediatamente
            DATEADD(HOUR, @DefaultAuctionHours, SYSUTCDATETIME()),
            COALESCE(a.SuggestedPriceETH, @BasePriceETH),
            COALESCE(a.SuggestedPriceETH, @BasePriceETH),
            'ACTIVE'
        FROM @ApprovedNFTs a
        WHERE NOT EXISTS (
            SELECT 1 
            FROM auction.Auction au 
            WHERE au.NFTId = a.NFTId
        ); -- Evitar duplicados

        -- Combinar datos para notificaciones
        DECLARE @AuctionsWithDetails TABLE(
            AuctionId BIGINT,
            NFTId BIGINT,
            ArtistId BIGINT,
            ArtistEmail NVARCHAR(100),
            NFTName NVARCHAR(160),
            StartingPriceETH DECIMAL(38,18),
            StartAtUtc DATETIME2(3),
            EndAtUtc DATETIME2(3)
        );

        INSERT INTO @AuctionsWithDetails
        SELECT 
            na.AuctionId,
            na.NFTId,
            an.ArtistId,
            an.ArtistEmail,
            an.NFTName,
            na.StartingPriceETH,
            na.StartAtUtc,
            na.EndAtUtc
        FROM @NewAuctions na
        JOIN @ApprovedNFTs an ON an.NFTId = na.NFTId;

        -------------------------------------------------------------------
        -- Notificar a artistas sobre subasta creada
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            na.ArtistId,
            na.ArtistEmail,
            N'�Subasta Iniciada!',
            N'�Su NFT "' + na.NFTName + N'" ya est� en subasta!' + CHAR(13) + CHAR(10) +
            N'- ID de Subasta: ' + CAST(na.AuctionId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'- Precio Inicial: ' + CAST(na.StartingPriceETH AS NVARCHAR(50)) + N' ETH' + CHAR(13) + CHAR(10) +
            N'- Inicio: ' + CONVERT(NVARCHAR(30), na.StartAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'- Fin: ' + CONVERT(NVARCHAR(30), na.EndAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'�Buena suerte con su subasta!',
            'PENDING'
        FROM @AuctionsWithDetails na;

        -------------------------------------------------------------------
        -- Notificar a todos los usuarios con rol BIDDER sobre nueva subasta
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT DISTINCT
            ur.UserId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = ur.UserId AND ue.IsPrimary = 1 
             ORDER BY ue.EmailId),
            N'Nueva Subasta Disponible',
            N'�Nueva obra disponible para subasta!' + CHAR(13) + CHAR(10) +
            N'- NFT: "' + na.NFTName + N'"' + CHAR(13) + CHAR(10) +
            N'- Precio Inicial: ' + CAST(na.StartingPriceETH AS NVARCHAR(50)) + N' ETH' + CHAR(13) + CHAR(10) +
            N'- Finaliza: ' + CONVERT(NVARCHAR(30), na.EndAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'�No pierda la oportunidad de participar!',
            'PENDING'
        FROM @AuctionsWithDetails na
        CROSS JOIN core.UserRole ur
        WHERE ur.RoleId = 4 -- Rol BIDDER
          AND EXISTS (
              SELECT 1 
              FROM core.UserEmail ue 
              WHERE ue.UserId = ur.UserId AND ue.IsPrimary = 1
          );

    END TRY
    BEGIN CATCH
        SET @ErrorMsg = N'Error en tr_NFT_CreateAuction: ' + ERROR_MESSAGE();
        
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        VALUES(
            NULL,
            'admin@artecryptoauctions.com',
            N'Error en Sistema - Creaci�n de Subasta',
            @ErrorMsg,
            'PENDING'
        );
        
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 4: tr_EmailOutbox_Failed_Aggregator
-- Descripci�n: Usa funciones para validaci�n de emails enviadoos con status 'FAILED'
-- =====================================================================================

CREATE OR ALTER TRIGGER audit.tr_EmailOutbox_Failed_Aggregator
ON audit.EmailOutbox
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE StatusCode='FAILED')
        EXEC audit.sp_NotifyEmailFailures;
END;
GO


-- =====================================================================================
-- TRIGGER 5: Finalizaci�n de subastas (VERSI�N CORREGIDA Y COMPLETA)
-- =====================================================================================

USE ArteCryptoAuctions;
GO

CREATE OR ALTER TRIGGER auction.tr_Auction_ProcesarCompletada
ON auction.Auction
AFTER UPDATE
AS
BEGIN
� � SET NOCOUNT ON;

� � IF NOT UPDATE(StatusCode) OR NOT EXISTS (SELECT 1 FROM inserted WHERE StatusCode = 'COMPLETED')
� � � � RETURN;

� � BEGIN TRY
� � � � BEGIN TRANSACTION;

� � � � -- 1. Recopilar datos de las subastas reci�n completadas
� � � � DECLARE @CompletedAuctions TABLE(
� � � � � � AuctionId BIGINT PRIMARY KEY, NFTId BIGINT NOT NULL, ArtistId BIGINT NOT NULL,
� � � � � � WinnerId BIGINT NULL, FinalPriceETH DECIMAL(38,18) NOT NULL
� � � � );
� � � � INSERT INTO @CompletedAuctions (AuctionId, NFTId, ArtistId, WinnerId, FinalPriceETH)
� � � � SELECT i.AuctionId, i.NFTId, n.ArtistId, i.CurrentLeaderId, i.CurrentPriceETH
� � � � FROM inserted i
� � � � JOIN deleted d ON i.AuctionId = d.AuctionId
� � � � JOIN nft.NFT n ON i.NFTId = n.NFTId
� � � � WHERE i.StatusCode = 'COMPLETED' AND d.StatusCode <> 'COMPLETED';

� � � � IF NOT EXISTS (SELECT 1 FROM @CompletedAuctions) RETURN;

� � � � -- 2. Procesar a los GANADORES
� � � � UPDATE w SET�
� � � � � � BalanceETH = w.BalanceETH - ca.FinalPriceETH,
� � � � � � ReservedETH = w.ReservedETH - ca.FinalPriceETH,
� � � � � � UpdatedAtUtc = SYSUTCDATETIME()
� � � � FROM core.Wallet w
� � � � JOIN @CompletedAuctions ca ON w.UserId = ca.WinnerId
� � � � WHERE ca.WinnerId IS NOT NULL;

� � � � UPDATE n SET CurrentOwnerId = ca.WinnerId
� � � � FROM nft.NFT n
� � � � JOIN @CompletedAuctions ca ON n.NFTId = ca.NFTId
� � � � WHERE ca.WinnerId IS NOT NULL;

� � � � UPDATE fr SET StateCode = 'CAPTURED', UpdatedAtUtc = SYSUTCDATETIME()
� � � � FROM finance.FundsReservation fr
� � � � JOIN @CompletedAuctions ca ON fr.AuctionId = ca.AuctionId AND fr.UserId = ca.WinnerId
� � � � WHERE ca.WinnerId IS NOT NULL AND fr.StateCode = 'ACTIVE';

� � � � INSERT INTO finance.Ledger (UserId, AuctionId, EntryType, AmountETH, [Description])
� � � � SELECT WinnerId, AuctionId, 'DEBIT', FinalPriceETH, 'Pago por subasta ganada #' + CAST(AuctionId AS NVARCHAR(20))
� � � � FROM @CompletedAuctions
� � � � WHERE WinnerId IS NOT NULL;

� � � � -- 2.5. Procesar el pago al ARTISTA
        -- A) Aumentar el saldo en la wallet del artista.

        --    Calcular una comisi�n?
        UPDATE w
        SET
            BalanceETH = w.BalanceETH + ca.FinalPriceETH, -- Se acredita el monto final
            UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN @CompletedAuctions ca ON w.UserId = ca.ArtistId
        WHERE ca.WinnerId IS NOT NULL; -- Solo se paga si hubo un ganador

        -- B) Insertar el registro de CR�DITO en el libro contable para el artista.
        INSERT INTO finance.Ledger (UserId, AuctionId, EntryType, AmountETH, [Description])
        SELECT
            ArtistId,
            AuctionId,
            'CREDIT',
            FinalPriceETH,
            'Ingreso por venta de NFT en subasta #' + CAST(AuctionId AS NVARCHAR(20))
        FROM @CompletedAuctions
        WHERE WinnerId IS NOT NULL;

� � � � -- 3. Procesar a los PERDEDORES y subastas SIN GANADOR
� � � � DECLARE @ReservationsToRelease TABLE (ReservationId BIGINT, UserId BIGINT, AuctionId BIGINT, AmountETH DECIMAL(38,18));
� � � � INSERT INTO @ReservationsToRelease (ReservationId, UserId, AuctionId, AmountETH)
� � � � SELECT fr.ReservationId, fr.UserId, fr.AuctionId, fr.AmountETH
� � � � FROM finance.FundsReservation fr
� � � � JOIN @CompletedAuctions ca ON fr.AuctionId = ca.AuctionId
� � � � WHERE fr.StateCode = 'ACTIVE' AND (ca.WinnerId IS NULL OR fr.UserId <> ca.WinnerId);
� � � ��
� � � � UPDATE fr SET StateCode = 'RELEASED', UpdatedAtUtc = SYSUTCDATETIME()
� � � � FROM finance.FundsReservation fr
� � � � JOIN @ReservationsToRelease rtr ON fr.ReservationId = rtr.ReservationId;

� � � � UPDATE w SET�
� � � � � � ReservedETH = w.ReservedETH - r.TotalReleased,
� � � � � � UpdatedAtUtc = SYSUTCDATETIME()
� � � � FROM core.Wallet w
� � � � JOIN (
� � � � � � SELECT UserId, SUM(AmountETH) as TotalReleased
� � � � � � FROM @ReservationsToRelease GROUP BY UserId
� � � � ) AS r ON w.UserId = r.UserId;

� � � � -- 4. Enviar todas las NOTIFICACIONES
� � � � INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
� � � � SELECT WinnerId, '�Felicidades! Ganaste la subasta #' + CAST(AuctionId AS NVARCHAR(20)), 'Has ganado la subasta con una oferta de ' + CAST(FinalPriceETH AS NVARCHAR(50)) + ' ETH. El NFT ha sido transferido a tu cuenta.'
� � � � FROM @CompletedAuctions WHERE WinnerId IS NOT NULL;
� � � ��
� � � � INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
� � � � SELECT ArtistId, '�Subasta completada! #' + CAST(AuctionId AS NVARCHAR(20)), CASE WHEN WinnerId IS NOT NULL THEN 'Tu NFT ha sido vendido por ' + CAST(FinalPriceETH AS NVARCHAR(50)) + ' ETH. Los fondos han sido acreditados en tu wallet.' ELSE 'Tu subasta ha finalizado sin un ganador.' END
� � � � FROM @CompletedAuctions;

� � � � INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
� � � � SELECT UserId, 'Subasta finalizada #' + CAST(AuctionId AS NVARCHAR(20)), 'La subasta ha finalizado. Tus fondos reservados (' + CAST(AmountETH AS NVARCHAR(50)) + ' ETH) han sido liberados.'
� � � � FROM @ReservationsToRelease;
� � � ��
� � � � COMMIT TRANSACTION;

� � END TRY
� � BEGIN CATCH
� � � � IF @@TRANCOUNT > 0
� � � � � � ROLLBACK TRANSACTION;

� � � � DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
� � � � INSERT INTO audit.EmailOutbox (RecipientEmail, [Subject], [Body])
� � � � VALUES ('admin@artecryptoauctions.com', 'ERROR Cr�tico - Procesamiento de Subastas Completadas', @ErrorMessage);
� � � ��
� � � � THROW;
� � END CATCH;
END;
GO