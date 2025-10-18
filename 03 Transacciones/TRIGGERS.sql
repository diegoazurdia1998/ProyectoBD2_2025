-- TRIGGERS
use ArteCryptoAuctions
go

-- =====================================================================================
-- TRIGGER 1: Inserción de NFT con validaciones y asignación de curador
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
        -- 1) Validación: Usuario debe tener rol ARTIST (RoleId = 2)
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
                N'NFT Rechazado - Rol Inválido',
                N'Su NFT "' + x.[Name] + N'" no pudo ser aceptado. Razón: El usuario no posee el rol de Artista. Por favor, contacte al administrador para obtener los permisos necesarios.',
                'PENDING'
            FROM @InputNFT x
            LEFT JOIN core.UserRole ur ON ur.UserId = x.ArtistId AND ur.RoleId = 2
            WHERE ur.UserId IS NULL;
            
            RETURN; -- No insertar NFTs
        END;

        -------------------------------------------------------------------
        -- 2) Validación: Email primario debe existir
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
                N'Su NFT "' + x.[Name] + N'" no pudo ser aceptado. Razón: No tiene un email primario configurado. Por favor, configure un email primario en su perfil.',
                'PENDING'
            FROM @InputNFT x
            LEFT JOIN core.UserEmail ue ON ue.UserId = x.ArtistId AND ue.IsPrimary = 1
            WHERE ue.EmailId IS NULL;
            
            RETURN;
        END;

        -------------------------------------------------------------------
        -- 3) Validaciones técnicas contra NFTSettings
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
                WHEN s.SettingsID IS NULL THEN N'Configuración de NFT inexistente'
                WHEN x.WidthPx IS NULL AND s.MinWidthPx IS NOT NULL THEN N'Ancho (WidthPx) es requerido'
                WHEN x.WidthPx < s.MinWidthPx THEN N'Ancho menor al mínimo permitido (' + CAST(s.MinWidthPx AS NVARCHAR) + N'px)'
                WHEN x.WidthPx > s.MaxWidthPx THEN N'Ancho mayor al máximo permitido (' + CAST(s.MaxWidthPx AS NVARCHAR) + N'px)'
                WHEN x.HeightPx IS NULL AND s.MinHeigntPx IS NOT NULL THEN N'Alto (HeightPx) es requerido'
                WHEN x.HeightPx < s.MinHeigntPx THEN N'Alto menor al mínimo permitido (' + CAST(s.MinHeigntPx AS NVARCHAR) + N'px)'
                WHEN x.HeightPx > s.MaxHeightPx THEN N'Alto mayor al máximo permitido (' + CAST(s.MaxHeightPx AS NVARCHAR) + N'px)'
                WHEN x.FileSizeBytes IS NULL AND s.MinFileSizeBytes IS NOT NULL THEN N'Tamaño de archivo es requerido'
                WHEN x.FileSizeBytes < s.MinFileSizeBytes THEN N'Archivo muy pequeño (mínimo: ' + CAST(s.MinFileSizeBytes AS NVARCHAR) + N' bytes)'
                WHEN x.FileSizeBytes > s.MaxFileSizeBytes THEN N'Archivo muy grande (máximo: ' + CAST(s.MaxFileSizeBytes AS NVARCHAR) + N' bytes)'
                ELSE NULL
            END
        FROM @InputNFT x
        LEFT JOIN nft.NFTSettings s ON s.SettingsID = x.SettingsID;

        -- Si hay errores de validación, notificar y salir
        IF EXISTS (SELECT 1 FROM @ValidationResults WHERE ValidationError IS NOT NULL)
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT DISTINCT 
                v.ArtistId,
                (SELECT TOP 1 ue.Email 
                 FROM core.UserEmail ue 
                 WHERE ue.UserId = v.ArtistId AND ue.IsPrimary = 1 
                 ORDER BY ue.EmailId),
                N'NFT Rechazado - Validación Técnica',
                N'Su NFT "' + v.[Name] + N'" no pudo ser aceptado. Razón: ' + v.ValidationError + N'. Por favor, corrija el archivo y vuelva a intentarlo.',
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
                N'Su NFT "' + x.[Name] + N'" ha sido aceptado pero actualmente no hay curadores disponibles. Será asignado automáticamente cuando haya un curador disponible.',
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
            VALUES('CURATION_DECISION', 'PENDING', N'Pendiente de revisión por curador');
        END;

        IF NOT EXISTS (SELECT 1 FROM ops.Status WHERE Domain = 'NFT' AND Code = 'PENDING')
        BEGIN
            INSERT INTO ops.Status(Domain, Code, Description)
            VALUES('NFT', 'PENDING', N'NFT pendiente de aprobación');
        END;

        -------------------------------------------------------------------
        -- 6) INSERTAR NFTs válidos con HashCode autogenerado
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

        -- Agregar RowNum después del INSERT
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
        -- 7) Asignación Round-Robin de curadores
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

        -- Obtener posición actual del round-robin
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
        -- 9) Notificar a artistas (NFT aceptado y en revisión)
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            n.ArtistId,
            ue.Email,
            N'NFT Aceptado - En Revisión',
            N'¡Felicidades! Su NFT "' + n.[Name] + N'" ha sido aceptado por el sistema y ha sido enviado a curación. Un curador revisará su obra pronto y recibirá una notificación con la decisión.',
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
            N'Nuevo NFT para Revisión',
            N'Se le ha asignado un nuevo NFT para revisión:' + CHAR(13) + CHAR(10) +
            N'- NFT ID: ' + CAST(a.NFTId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'- Nombre: "' + a.[Name] + N'"' + CHAR(13) + CHAR(10) +
            N'- Artista ID: ' + CAST(a.ArtistId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'Por favor, revise el NFT y tome una decisión (APPROVED/REJECTED).',
            'PENDING'
        FROM @Assignments a;

        -------------------------------------------------------------------
        -- 11) Actualizar posición del round-robin
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
            N'Error en Sistema - Inserción NFT',
            @ErrorMsg,
            'PENDING'
        );
        
        -- Re-lanzar el error
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 2: Decisión del curador (APPROVED/REJECTED)
-- =====================================================================================
CREATE OR ALTER TRIGGER admin.tr_CurationReview_Decision
ON admin.CurationReview
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo procesar si se actualizó DecisionCode
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
            N'¡NFT Aprobado!',
            N'¡Excelentes noticias! Su NFT "' + d.NFTName + N'" ha sido aprobado por el curador.' + CHAR(13) + CHAR(10) +
            N'Su obra entrará automáticamente en subasta. Recibirá una notificación cuando la subasta esté activa.',
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
            N'Lamentamos informarle que su NFT "' + d.NFTName + N'" no ha sido aprobado en esta ocasión.' + CHAR(13) + CHAR(10) +
            N'Le invitamos a revisar las políticas de contenido y volver a intentarlo con una nueva obra.',
            'PENDING'
        FROM @Decisions d
        WHERE d.DecisionCode = 'REJECTED';

        -------------------------------------------------------------------
        -- Notificar a curadores sobre su decisión procesada
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            d.CuratorId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = d.CuratorId AND ue.IsPrimary = 1 
             ORDER BY ue.EmailId),
            N'Decisión Procesada',
            N'Su decisión sobre el NFT "' + d.NFTName + N'" (ID: ' + CAST(d.NFTId AS NVARCHAR(20)) + N') ha sido procesada exitosamente.' + CHAR(13) + CHAR(10) +
            N'Decisión: ' + CASE d.DecisionCode WHEN 'APPROVED' THEN N'APROBADO' ELSE N'RECHAZADO' END,
            'PENDING'
        FROM @Decisions d;

    END TRY
    BEGIN CATCH
        SET @ErrorMsg = N'Error en tr_CurationReview_Decision: ' + ERROR_MESSAGE();
        
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        VALUES(
            NULL,
            'admin@artecryptoauctions.com',
            N'Error en Sistema - Decisión Curador',
            @ErrorMsg,
            'PENDING'
        );
        
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 3: Crear subasta automáticamente cuando NFT es aprobado
-- =====================================================================================
CREATE OR ALTER TRIGGER nft.tr_NFT_CreateAuction
ON nft.NFT
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo procesar si se actualizó StatusCode a APPROVED
    IF NOT UPDATE(StatusCode)
        RETURN;
    
    BEGIN TRY
        DECLARE @ErrorMsg NVARCHAR(MAX);
        
        -- Tabla para NFTs recién aprobados
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
        -- Obtener configuración de subastas
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

        -- Si no hay configuración, usar valores por defecto
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
            N'¡Subasta Iniciada!',
            N'¡Su NFT "' + na.NFTName + N'" ya está en subasta!' + CHAR(13) + CHAR(10) +
            N'- ID de Subasta: ' + CAST(na.AuctionId AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
            N'- Precio Inicial: ' + CAST(na.StartingPriceETH AS NVARCHAR(50)) + N' ETH' + CHAR(13) + CHAR(10) +
            N'- Inicio: ' + CONVERT(NVARCHAR(30), na.StartAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'- Fin: ' + CONVERT(NVARCHAR(30), na.EndAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'¡Buena suerte con su subasta!',
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
            N'¡Nueva obra disponible para subasta!' + CHAR(13) + CHAR(10) +
            N'- NFT: "' + na.NFTName + N'"' + CHAR(13) + CHAR(10) +
            N'- Precio Inicial: ' + CAST(na.StartingPriceETH AS NVARCHAR(50)) + N' ETH' + CHAR(13) + CHAR(10) +
            N'- Finaliza: ' + CONVERT(NVARCHAR(30), na.EndAtUtc, 120) + N' UTC' + CHAR(13) + CHAR(10) +
            N'¡No pierda la oportunidad de participar!',
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
            N'Error en Sistema - Creación de Subasta',
            @ErrorMsg,
            'PENDING'
        );
        
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- TRIGGER 4: Validar y procesar ofertas (Bids) - VERSIÓN REFACTORIZADA
-- Descripción: Usa funciones para validación e implementa la reserva de fondos.
-- =====================================================================================
CREATE OR ALTER TRIGGER auction.tr_Bid_Validation
ON auction.Bid
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Usamos un nivel de aislamiento alto para prevenir condiciones de carrera
    -- durante la validación y actualización del precio de la subasta.
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    BEGIN TRY
        DECLARE @ErrorMsg NVARCHAR(MAX);

        -- -------------------------------------------------------------------
        -- 1) Capturar y validar las ofertas entrantes en un solo paso
        -- -------------------------------------------------------------------
        DECLARE @InputBids TABLE(
            RowNum INT IDENTITY(1,1) PRIMARY KEY,
            AuctionId BIGINT,
            BidderId BIGINT,
            ArtistId BIGINT,
            AmountETH DECIMAL(38,18),
            PlacedAtUtc DATETIME2(3),
            CurrentPriceETH DECIMAL(38,18),
            MinNextBid DECIMAL(38,18),
            AvailableBalance DECIMAL(38,18),
            OldLeaderId BIGINT,
            AuctionStatusCode VARCHAR(30),
            AuctionEndAtUtc DATETIME2(3),
            ErrorMessage NVARCHAR(500)
        );

        -- Se recopilan todos los datos necesarios para la validación de una sola vez
        INSERT INTO @InputBids(
            AuctionId, BidderId, AmountETH, PlacedAtUtc,
            ArtistId, CurrentPriceETH, AuctionStatusCode, AuctionEndAtUtc,
            MinNextBid, AvailableBalance
        )
        SELECT 
            i.AuctionId, i.BidderId, i.AmountETH, i.PlacedAtUtc,
            nft.ArtistId,
            a.CurrentPriceETH,
            a.StatusCode,
            a.EndAtUtc, -- Uso de las nuevas funciones para validación
            auction.fn_GetMinNextBid(i.AuctionId),
            finance.fn_GetAvailableBalance(i.BidderId)
        FROM inserted i
        LEFT JOIN auction.Auction a ON a.AuctionId = i.AuctionId
        LEFT JOIN nft.NFT nft ON nft.NFTId = a.NFTId;

        -- Se generan los mensajes de error basados en los datos recolectados
        UPDATE @InputBids
        SET ErrorMessage = 
            CASE
                WHEN AuctionStatusCode IS NULL THEN N'La subasta no existe.'
                WHEN AuctionStatusCode <> 'ACTIVE' THEN N'La subasta no está activa.'
                WHEN AuctionEndAtUtc < SYSUTCDATETIME() THEN N'La subasta ya ha finalizado.'
                WHEN ArtistId = BidderId THEN N'El artista no puede ofertar en su propia obra.'
                WHEN AmountETH < MinNextBid THEN N'Su oferta es muy baja. Se requiere al menos ' + CAST(MinNextBid AS NVARCHAR(50)) + N' ETH.'
                WHEN AvailableBalance < AmountETH THEN N'Saldo insuficiente. Su saldo disponible es de ' + CAST(AvailableBalance AS NVARCHAR(50)) + N' ETH.'
                ELSE NULL
            END;

        -- -------------------------------------------------------------------
        -- 2) Si hay errores, notificar y detener el proceso
        -- -------------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM @InputBids WHERE ErrorMessage IS NOT NULL)
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body])
            SELECT
                ib.BidderId,
                ue.Email,
                N'Oferta Rechazada',
                N'Su oferta en la subasta #' + CAST(ib.AuctionId AS NVARCHAR(20)) + N' no pudo ser procesada. Razón: ' + ib.ErrorMessage
            FROM @InputBids ib
            JOIN core.UserEmail ue ON ue.UserId = ib.BidderId AND ue.IsPrimary = 1
            WHERE ib.ErrorMessage IS NOT NULL;
            
            RETURN; -- Detiene la ejecución del trigger
        END;

        -- -------------------------------------------------------------------
        -- 3) Procesar las ofertas válidas una por una para manejar la lógica de fondos
        -- -------------------------------------------------------------------
        DECLARE @CurrentRow INT = 1;
        DECLARE @TotalRows INT = (SELECT COUNT(*) FROM @InputBids);
        DECLARE @AuctionId BIGINT, @BidderId BIGINT, @AmountETH DECIMAL(38,18), @OldLeaderId BIGINT;

        WHILE @CurrentRow <= @TotalRows
        BEGIN
            -- Obtener la oferta actual a procesar
            SELECT 
                @AuctionId = AuctionId,
                @BidderId = BidderId,
                @AmountETH = AmountETH
            FROM @InputBids WHERE RowNum = @CurrentRow;

            BEGIN TRANSACTION; -- Inicia una transacción para asegurar la atomicidad

            -- Obtener el líder anterior DENTRO de la transacción para bloquear la fila
            SELECT @OldLeaderId = CurrentLeaderId 
            FROM auction.Auction WITH (UPDLOCK) 
            WHERE AuctionId = @AuctionId;
            
            -- A) LIBERAR FONDOS DEL LÍDER ANTERIOR (si existe y es diferente del nuevo postor)
            IF @OldLeaderId IS NOT NULL AND @OldLeaderId <> @BidderId
            BEGIN
                DECLARE @OldBidAmount DECIMAL(38,18);

                -- Obtener el monto de la reserva anterior que estaba activa
                SELECT @OldBidAmount = AmountETH 
                FROM finance.FundsReservation 
                WHERE AuctionId = @AuctionId AND UserId = @OldLeaderId AND StateCode = 'ACTIVE';
                
                IF @OldBidAmount IS NOT NULL
                BEGIN
                    -- Actualizar billetera del líder anterior
                    UPDATE core.Wallet SET ReservedETH = ReservedETH - @OldBidAmount WHERE UserId = @OldLeaderId;
                    -- Marcar la reserva como liberada
                    UPDATE finance.FundsReservation SET StateCode = 'RELEASED', UpdatedAtUtc = SYSUTCDATETIME() WHERE AuctionId = @AuctionId AND UserId = @OldLeaderId AND StateCode = 'ACTIVE';
                END
            END

            -- B) RESERVAR FONDOS DEL NUEVO LÍDER
            UPDATE core.Wallet SET ReservedETH = ReservedETH + @AmountETH WHERE UserId = @BidderId;

            -- C) INSERTAR EL REGISTRO DE LA OFERTA
            DECLARE @NewBidId BIGINT;
            INSERT INTO auction.Bid(AuctionId, BidderId, AmountETH)
            VALUES (@AuctionId, @BidderId, @AmountETH);
            SET @NewBidId = SCOPE_IDENTITY(); -- Capturar el ID de la nueva oferta

            -- D) CREAR LA NUEVA RESERVA DE FONDOS
            INSERT INTO finance.FundsReservation(UserId, AuctionId, BidId, AmountETH, StateCode)
            VALUES(@BidderId, @AuctionId, @NewBidId, @AmountETH, 'ACTIVE');

            -- E) ACTUALIZAR LA SUBASTA con el nuevo precio y líder
            UPDATE auction.Auction 
            SET CurrentPriceETH = @AmountETH, CurrentLeaderId = @BidderId 
            WHERE AuctionId = @AuctionId;

            COMMIT TRANSACTION; -- Confirmar todos los cambios si no hubo errores


            SET @CurrentRow = @CurrentRow + 1;
        END;
		
        -- F) GESTIONAR NOTIFICACIONES (fuera de la transacción principal)
        -- -------------------------------------------------------------------
        -- 4) Enviar todas las notificaciones después de procesar
        -- -------------------------------------------------------------------
        -- Notificar al nuevo líder
        INSERT INTO audit.EmailOutbox(RecipientUserId, [Subject], [Body])
        SELECT DISTINCT BidderId, N'¡Oferta Aceptada!', N'Su oferta de ' + CAST(AmountETH AS NVARCHAR(50)) + N' ETH ha sido aceptada. Ahora es el líder de la subasta #' + CAST(AuctionId AS NVARCHAR(20)) + N'.' FROM @InputBids;

        -- Notificar al líder anterior (si existió)
        INSERT INTO audit.EmailOutbox(RecipientUserId, [Subject], [Body])
        SELECT DISTINCT OldLeaderId, N'Ha sido superado en la subasta', N'Su oferta en la subasta #' + CAST(AuctionId AS NVARCHAR(20)) + N' ha sido superada. La nueva oferta es de ' + CAST(AmountETH AS NVARCHAR(50)) + N' ETH.' FROM @InputBids WHERE OldLeaderId IS NOT NULL AND OldLeaderId <> BidderId;

        -- Notificar al artista
        INSERT INTO audit.EmailOutbox(RecipientUserId, [Subject], [Body])
        SELECT DISTINCT ArtistId, N'Nueva oferta en su NFT', N'Su NFT ha recibido una nueva oferta de ' + CAST(AmountETH AS NVARCHAR(50)) + N' ETH en la subasta #' + CAST(AuctionId AS NVARCHAR(20)) + N'.' FROM @InputBids;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION; -- Revertir la transacción si algo falla

        SET @ErrorMsg = N'Error en tr_Bid_Validation: ' + ERROR_MESSAGE();
        
        -- Notificar al administrador del sistema sobre el error
        INSERT INTO audit.EmailOutbox(RecipientEmail, [Subject], [Body])
        VALUES('admin@artecryptoauctions.com', N'Error Crítico en Sistema - Procesamiento de Oferta', @ErrorMsg);
            
        THROW; -- Relanzar el error para que la aplicación lo reciba
    END CATCH
END;
GO


-- =====================================================================================
-- TRIGGER 5: Finalización de subastas
-- =====================================================================================

USE ArteCryptoAuctions;
GO

CREATE OR ALTER TRIGGER auction.tr_Auction_ProcesarCompletada
ON auction.Auction
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo actuar si la columna StatusCode fue actualizada y hay subastas completadas
    IF NOT UPDATE(StatusCode) OR NOT EXISTS (SELECT 1 FROM inserted WHERE StatusCode = 'COMPLETED')
        RETURN;

    BEGIN TRY
        -- Iniciar una transacción atómica para todo el lote
        BEGIN TRANSACTION;

        -- -------------------------------------------------------------------
        -- 1. Recopilar datos de todas las subastas recién completadas
        -- -------------------------------------------------------------------
        DECLARE @CompletedAuctions TABLE(
            AuctionId BIGINT PRIMARY KEY,
            NFTId BIGINT NOT NULL,
            ArtistId BIGINT NOT NULL,
            WinnerId BIGINT NULL, -- Puede no haber un ganador
            FinalPriceETH DECIMAL(38,18) NOT NULL
        );

        INSERT INTO @CompletedAuctions (AuctionId, NFTId, ArtistId, WinnerId, FinalPriceETH)
        SELECT 
            i.AuctionId, 
            i.NFTId,
            n.ArtistId,
            i.CurrentLeaderId,
            i.CurrentPriceETH
        FROM inserted i
        JOIN deleted d ON i.AuctionId = d.AuctionId
        JOIN nft.NFT n ON i.NFTId = n.NFTId
        WHERE i.StatusCode = 'COMPLETED' AND d.StatusCode <> 'COMPLETED';

        -- Si no hay subastas que realmente hayan cambiado a 'COMPLETED', salir.
        IF NOT EXISTS (SELECT 1 FROM @CompletedAuctions)
            RETURN;

        -- -------------------------------------------------------------------
        -- 2. Procesar a los GANADORES
        -- -------------------------------------------------------------------
        -- A) Actualizar wallets: Bajar balance y reserva
        UPDATE w
        SET 
            BalanceETH = w.BalanceETH - ca.FinalPriceETH,
            ReservedETH = w.ReservedETH - ca.FinalPriceETH, -- Asumimos que la reserva es el precio final
            UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN @CompletedAuctions ca ON w.UserId = ca.WinnerId
        WHERE ca.WinnerId IS NOT NULL;

        -- B) Transferir propiedad del NFT
        UPDATE n
        SET CurrentOwnerId = ca.WinnerId
        FROM nft.NFT n
        JOIN @CompletedAuctions ca ON n.NFTId = ca.NFTId
        WHERE ca.WinnerId IS NOT NULL;

        -- C) Marcar la reserva de fondos como CAPTURADA
        UPDATE fr
        SET StateCode = 'CAPTURED', UpdatedAtUtc = SYSUTCDATETIME()
        FROM finance.FundsReservation fr
        JOIN @CompletedAuctions ca ON fr.AuctionId = ca.AuctionId AND fr.UserId = ca.WinnerId
        WHERE ca.WinnerId IS NOT NULL AND fr.StateCode = 'ACTIVE';

        -- D) Insertar registro de DÉBITO en el libro contable
        INSERT INTO finance.Ledger (UserId, AuctionId, EntryType, AmountETH, [Description])
        SELECT 
            WinnerId, 
            AuctionId, 
            'DEBIT', 
            FinalPriceETH, 
            'Pago por subasta ganada #' + CAST(AuctionId AS NVARCHAR(20))
        FROM @CompletedAuctions
        WHERE WinnerId IS NOT NULL;

        -- -------------------------------------------------------------------
        -- 3. Procesar a los PERDEDORES y subastas SIN GANADOR
        -- -------------------------------------------------------------------
        -- Identificar todas las reservas que deben ser liberadas
        DECLARE @ReservationsToRelease TABLE (ReservationId BIGINT, UserId BIGINT, AuctionId BIGINT, AmountETH DECIMAL(38,18));

        INSERT INTO @ReservationsToRelease (ReservationId, UserId, AuctionId, AmountETH)
        SELECT fr.ReservationId, fr.UserId, fr.AuctionId, fr.AmountETH
        FROM finance.FundsReservation fr
        -- Unirse a las subastas completadas
        JOIN @CompletedAuctions ca ON fr.AuctionId = ca.AuctionId
        -- El usuario de la reserva NO es el ganador de esa subasta
        WHERE fr.StateCode = 'ACTIVE' 
          AND (ca.WinnerId IS NULL OR fr.UserId <> ca.WinnerId);
        
        -- A) Marcar las reservas como LIBERADAS
        UPDATE fr
        SET StateCode = 'RELEASED', UpdatedAtUtc = SYSUTCDATETIME()
        FROM finance.FundsReservation fr
        JOIN @ReservationsToRelease rtr ON fr.ReservationId = rtr.ReservationId;

        -- B) Devolver los fondos reservados a las wallets correspondientes
        UPDATE w
        SET 
            ReservedETH = w.ReservedETH - r.TotalReleased,
            UpdatedAtUtc = SYSUTCDATETIME()
        FROM core.Wallet w
        JOIN (
            -- Agrupar por si un usuario perdió en múltiples subastas en el mismo lote
            SELECT UserId, SUM(AmountETH) as TotalReleased
            FROM @ReservationsToRelease
            GROUP BY UserId
        ) AS r ON w.UserId = r.UserId;

        -- -------------------------------------------------------------------
        -- 4. Enviar todas las NOTIFICACIONES
        -- -------------------------------------------------------------------
        -- A) Notificar a los ganadores
        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT 
            WinnerId,
            '¡Felicidades! Ganaste la subasta #' + CAST(AuctionId AS NVARCHAR(20)),
            'Has ganado la subasta con una oferta de ' + CAST(FinalPriceETH AS NVARCHAR(50)) + 
            ' ETH. El NFT ha sido transferido a tu cuenta.'
        FROM @CompletedAuctions
        WHERE WinnerId IS NOT NULL;
        
        -- B) Notificar a los artistas
        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT 
            ArtistId,
            '¡Subasta completada! #' + CAST(AuctionId AS NVARCHAR(20)),
            CASE 
                WHEN WinnerId IS NOT NULL THEN 'Tu NFT ha sido vendido por ' + CAST(FinalPriceETH AS NVARCHAR(50)) + ' ETH.'
                ELSE 'Tu subasta ha finalizado sin un ganador.'
            END
        FROM @CompletedAuctions;

        -- C) Notificar a los perdedores y participantes de subastas sin ganador
        INSERT INTO audit.EmailOutbox (RecipientUserId, [Subject], [Body])
        SELECT 
            UserId,
            'Subasta finalizada #' + CAST(AuctionId AS NVARCHAR(20)),
            'La subasta ha finalizado. Tus fondos reservados (' + 
            CAST(AmountETH AS NVARCHAR(50)) + ' ETH) han sido liberados.'
        FROM @ReservationsToRelease;
        
        -- Si todo fue exitoso, confirmar la transacción
        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        -- Si algo falla, revertir todos los cambios del lote
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Loguear el error para el administrador
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO audit.EmailOutbox (RecipientEmail, [Subject], [Body])
        VALUES ('admin@artecryptoauctions.com', 'ERROR Crítico - Procesamiento de Subastas Completadas', @ErrorMessage);
        
        -- Relanzar el error para que la capa de aplicación sea notificada
        THROW;
    END CATCH;
END;
GO