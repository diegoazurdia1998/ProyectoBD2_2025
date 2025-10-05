-- =====================================================================================
-- TRIGGERS CONSOLIDADOS - Sistema de Subastas NFT
-- Proyecto: ArteCryptoAuctions
-- Descripción: Triggers para gestión completa del flujo NFT → Curación → Subasta
-- =====================================================================================

USE ArteCryptoAuctions;
GO

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
            [Name] NVARCHAR(160),
            RowNum INT
        );

        INSERT INTO nft.NFT(
            ArtistId, SettingsID, CurrentOwnerId, [Name], [Description],
            ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx,
            SuggestedPriceETH, StatusCode, CreatedAtUtc
        )
        OUTPUT 
            inserted.NFTId, 
            inserted.ArtistId, 
            inserted.[Name],
            (SELECT x.RowNum FROM @InputNFT x WHERE x.ArtistId = inserted.ArtistId AND x.[Name] = inserted.[Name])
        INTO @NewNFTs(NFTId, ArtistId, [Name], RowNum)
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
            FROM @NewNFTs n
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
        
        -- Log del error (si existe tabla de logs)
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
            ArtistId BIGINT,
            ArtistEmail NVARCHAR(100),
            NFTName NVARCHAR(160),
            StartingPriceETH DECIMAL(38,18),
            StartAtUtc DATETIME2(3),
            EndAtUtc DATETIME2(3)
        );

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
            (SELECT a.ArtistId FROM @ApprovedNFTs a WHERE a.NFTId = inserted.NFTId),
            (SELECT a.ArtistEmail FROM @ApprovedNFTs a WHERE a.NFTId = inserted.NFTId),
            (SELECT a.NFTName FROM @ApprovedNFTs a WHERE a.NFTId = inserted.NFTId),
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
        FROM @NewAuctions na;

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
        FROM @NewAuctions na
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
-- TRIGGER 4: Validar y procesar ofertas (Bids)
-- =====================================================================================
CREATE OR ALTER TRIGGER auction.tr_Bid_Validation
ON auction.Bid
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        DECLARE @ErrorMsg NVARCHAR(MAX);
        
        -- Tabla para validar bids
        DECLARE @InputBids TABLE(
            RowNum INT IDENTITY(1,1),
            AuctionId BIGINT,
            BidderId BIGINT,
            AmountETH DECIMAL(38,18),
            PlacedAtUtc DATETIME2(3)
        );

        INSERT INTO @InputBids
        SELECT AuctionId, BidderId, AmountETH, PlacedAtUtc
        FROM inserted;

        -------------------------------------------------------------------
        -- Validaciones
        -------------------------------------------------------------------
        DECLARE @ValidationErrors TABLE(
            BidderId BIGINT,
            BidderEmail NVARCHAR(100),
            AuctionId BIGINT,
            ErrorMessage NVARCHAR(500)
        );

        -- Validar que la subasta existe y está activa
        INSERT INTO @ValidationErrors
        SELECT 
            ib.BidderId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = ib.BidderId AND ue.IsPrimary = 1),
            ib.AuctionId,
            CASE 
                WHEN a.AuctionId IS NULL THEN N'La subasta no existe'
                WHEN a.StatusCode <> 'ACTIVE' THEN N'La subasta no está activa'
                WHEN SYSUTCDATETIME() < a.StartAtUtc THEN N'La subasta aún no ha comenzado'
                WHEN SYSUTCDATETIME() > a.EndAtUtc THEN N'La subasta ya finalizó'
                WHEN ib.AmountETH <= a.CurrentPriceETH THEN N'La oferta debe ser mayor al precio actual (' + CAST(a.CurrentPriceETH AS NVARCHAR(50)) + N' ETH)'
                WHEN ib.BidderId = nft.ArtistId THEN N'El artista no puede ofertar en su propia subasta'
                ELSE NULL
            END
        FROM @InputBids ib
        LEFT JOIN auction.Auction a ON a.AuctionId = ib.AuctionId
        LEFT JOIN nft.NFT nft ON nft.NFTId = a.NFTId
        WHERE a.AuctionId IS NULL
           OR a.StatusCode <> 'ACTIVE'
           OR SYSUTCDATETIME() < a.StartAtUtc
           OR SYSUTCDATETIME() > a.EndAtUtc
           OR ib.AmountETH <= a.CurrentPriceETH
           OR ib.BidderId = nft.ArtistId;

        -- Si hay errores, notificar y salir
        IF EXISTS (SELECT 1 FROM @ValidationErrors)
        BEGIN
            INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
            SELECT 
                ve.BidderId,
                ve.BidderEmail,
                N'Oferta Rechazada',
                N'Su oferta en la subasta #' + CAST(ve.AuctionId AS NVARCHAR(20)) + N' no pudo ser procesada.' + CHAR(13) + CHAR(10) +
                N'Razón: ' + ve.ErrorMessage,
                'PENDING'
            FROM @ValidationErrors ve
            WHERE ve.ErrorMessage IS NOT NULL;
            
            RETURN;
        END;

        -------------------------------------------------------------------
        -- Insertar bids válidos
        -------------------------------------------------------------------
        DECLARE @NewBids TABLE(
            BidId BIGINT,
            AuctionId BIGINT,
            BidderId BIGINT,
            AmountETH DECIMAL(38,18),
            PlacedAtUtc DATETIME2(3)
        );

        INSERT INTO auction.Bid(AuctionId, BidderId, AmountETH, PlacedAtUtc)
        OUTPUT 
            inserted.BidId,
            inserted.AuctionId,
            inserted.BidderId,
            inserted.AmountETH,
            inserted.PlacedAtUtc
        INTO @NewBids
        SELECT AuctionId, BidderId, AmountETH, PlacedAtUtc
        FROM @InputBids;

        -------------------------------------------------------------------
        -- Actualizar CurrentPriceETH y CurrentLeaderId en Auction
        -------------------------------------------------------------------
        UPDATE a
        SET 
            CurrentPriceETH = nb.AmountETH,
            CurrentLeaderId = nb.BidderId
        FROM auction.Auction a
        JOIN @NewBids nb ON nb.AuctionId = a.AuctionId;

        -------------------------------------------------------------------
        -- Notificar al nuevo líder
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT 
            nb.BidderId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = nb.BidderId AND ue.IsPrimary = 1),
            N'¡Oferta Aceptada!',
            N'Su oferta de ' + CAST(nb.AmountETH AS NVARCHAR(50)) + N' ETH ha sido aceptada.' + CHAR(13) + CHAR(10) +
            N'Actualmente es el líder de la subasta #' + CAST(nb.AuctionId AS NVARCHAR(20)) + N'.',
            'PENDING'
        FROM @NewBids nb;

        -------------------------------------------------------------------
        -- Notificar al líder anterior (si existe)
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT DISTINCT
            a.CurrentLeaderId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = a.CurrentLeaderId AND ue.IsPrimary = 1),
            N'Ha sido superado en la subasta',
            N'Su oferta en la subasta #' + CAST(a.AuctionId AS NVARCHAR(20)) + N' ha sido superada.' + CHAR(13) + CHAR(10) +
            N'Nueva oferta líder: ' + CAST(nb.AmountETH AS NVARCHAR(50)) + N' ETH',
            'PENDING'
        FROM @NewBids nb
        JOIN auction.Auction a ON a.AuctionId = nb.AuctionId
        WHERE a.CurrentLeaderId IS NOT NULL
          AND a.CurrentLeaderId <> nb.BidderId;

        -------------------------------------------------------------------
        -- Notificar al artista sobre nueva oferta
        -------------------------------------------------------------------
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        SELECT DISTINCT
            nft.ArtistId,
            (SELECT TOP 1 ue.Email 
             FROM core.UserEmail ue 
             WHERE ue.UserId = nft.ArtistId AND ue.IsPrimary = 1),
            N'Nueva oferta en su NFT',
            N'Su NFT "' + nft.[Name] + N'" ha recibido una nueva oferta de ' + CAST(nb.AmountETH AS NVARCHAR(50)) + N' ETH.',
            'PENDING'
        FROM @NewBids nb
        JOIN auction.Auction a ON a.AuctionId = nb.AuctionId
        JOIN nft.NFT nft ON nft.NFTId = a.NFTId;

    END TRY
    BEGIN CATCH
        SET @ErrorMsg = N'Error en tr_Bid_Validation: ' + ERROR_MESSAGE();
        
        INSERT INTO audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
        VALUES(
            NULL,
            'admin@artecryptoauctions.com',
            N'Error en Sistema - Procesamiento de Oferta',
            @ErrorMsg,
            'PENDING'
        );
        
        THROW;
    END CATCH
END;
GO

-- =====================================================================================
-- SCRIPT DE VERIFICACIÓN
-- =====================================================================================
PRINT '=====================================================================================';
PRINT 'TRIGGERS CONSOLIDADOS CREADOS EXITOSAMENTE';
PRINT '=====================================================================================';
PRINT '';
PRINT 'Triggers creados:';
PRINT '1. nft.tr_NFT_InsertFlow - Validación e inserción de NFTs con asignación de curador';
PRINT '2. admin.tr_CurationReview_Decision - Procesamiento de decisiones de curación';
PRINT '3. nft.tr_NFT_CreateAuction - Creación automática de subastas para NFTs aprobados';
PRINT '4. auction.tr_Bid_Validation - Validación y procesamiento de ofertas';
PRINT '';
PRINT 'Flujo completo implementado:';
PRINT '  NFT Insert → Validación → Asignación Curador → Notificaciones';
PRINT '  ↓';
PRINT '  Decisión Curador → Actualización Estado → Notificaciones';
PRINT '  ↓';
PRINT '  Si APPROVED → Crear Subasta → Notificaciones';
PRINT '  ↓';
PRINT '  Ofertas → Validación → Actualización Líder → Notificaciones';
PRINT '';
PRINT '=====================================================================================';
GO
