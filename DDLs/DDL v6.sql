-- =====================================================================================
-- DDL v6 - ArteCryptoAuctions (Versión Simplificada)
-- Sistema de Subastas de NFTs
-- Fecha: 2025-01-05
-- =====================================================================================

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- CREACIÓN DE ESQUEMAS
-- =====================================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'admin')
    EXEC('CREATE SCHEMA admin');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'auction')
    EXEC('CREATE SCHEMA auction');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
    EXEC('CREATE SCHEMA audit');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
    EXEC('CREATE SCHEMA core');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'finance')
    EXEC('CREATE SCHEMA finance');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'nft')
    EXEC('CREATE SCHEMA nft');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')
    EXEC('CREATE SCHEMA ops');
GO

PRINT 'Esquemas creados correctamente';
GO

-- =====================================================================================
-- ESQUEMA: core (Usuarios, Roles, Wallets)
-- =====================================================================================

-- Tabla: core.User
CREATE TABLE core.[User] (
    UserId          BIGINT IDENTITY(1,1) PRIMARY KEY,
    FullName        NVARCHAR(100) NOT NULL,
    CreatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Tabla: core.Role
CREATE TABLE core.Role (
    RoleId          BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Name]          NVARCHAR(100) NOT NULL UNIQUE
);
GO

-- Tabla: core.UserRole (Relación muchos a muchos)
CREATE TABLE core.UserRole (
    UserId          BIGINT NOT NULL,
    RoleId          BIGINT NOT NULL,
    AsignacionUtc   DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT PK_UserRole PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_UserRole_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_UserRole_Role FOREIGN KEY (RoleId) REFERENCES core.Role(RoleId)
);
GO

-- Tabla: core.UserEmail
CREATE TABLE core.UserEmail (
    EmailId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId          BIGINT NOT NULL,
    Email           NVARCHAR(100) NOT NULL UNIQUE,
    IsPrimary       BIT NOT NULL DEFAULT 0,
    AddedAtUtc      DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    VerifiedAtUtc   DATETIME2(3) NULL,
    StatusCode      VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    StatusDomain    AS CONVERT(VARCHAR(50), 'USER_EMAIL') PERSISTED,
    
    CONSTRAINT FK_UserEmail_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId)
);
GO

-- Tabla: core.Wallet
CREATE TABLE core.Wallet (
    WalletId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId          BIGINT NOT NULL UNIQUE,
    BalanceETH      DECIMAL(38,18) NOT NULL DEFAULT 0,
    ReservedETH     DECIMAL(38,18) NOT NULL DEFAULT 0,
    UpdatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_Wallet_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_Wallet_Positive CHECK (BalanceETH >= 0 AND ReservedETH >= 0)
);
GO

PRINT 'Esquema CORE creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: nft (NFTs y Configuración)
-- =====================================================================================

-- Tabla: nft.NFTSettings
CREATE TABLE nft.NFTSettings (
    SettingsID          INT PRIMARY KEY,
    MaxWidthPx          BIGINT NOT NULL,
    MinWidthPx          BIGINT NOT NULL,
    MaxHeightPx         BIGINT NOT NULL,
    MinHeigntPx         BIGINT NOT NULL,
    MaxFileSizeBytes    BIGINT NOT NULL,
    MinFileSizeBytes    BIGINT NOT NULL,
    CreatedAtUtc        DATETIME2(3) NOT NULL
);
GO

-- Tabla: nft.NFT
CREATE TABLE nft.NFT (
    NFTId               BIGINT IDENTITY(1,1) PRIMARY KEY,
    ArtistId            BIGINT NOT NULL,
    SettingsID          INT NOT NULL,
    CurrentOwnerId      BIGINT NULL,
    [Name]              NVARCHAR(160) NOT NULL,
    [Description]       NVARCHAR(MAX) NULL,
    ContentType         NVARCHAR(100) NOT NULL,
    HashCode            CHAR(64) NOT NULL UNIQUE,
    FileSizeBytes       BIGINT NULL,
    WidthPx             INT NULL,
    HeightPx            INT NULL,
    SuggestedPriceETH   DECIMAL(38,18) NULL,
    StatusCode          VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    StatusDomain        AS CONVERT(VARCHAR(50), 'NFT') PERSISTED,
    CreatedAtUtc        DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ApprovedAtUtc       DATETIME2(3) NULL,
    
    CONSTRAINT FK_NFT_Artist FOREIGN KEY (ArtistId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_NFT_Owner FOREIGN KEY (CurrentOwnerId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_NFT_NFTSettings FOREIGN KEY (SettingsID) REFERENCES nft.NFTSettings(SettingsID)
);
GO

PRINT 'Esquema NFT creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: admin (Curación de NFTs)
-- =====================================================================================

-- Tabla: admin.CurationReview
CREATE TABLE admin.CurationReview (
    ReviewId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    NFTId           BIGINT NOT NULL,
    CuratorId       BIGINT NOT NULL,
    DecisionCode    VARCHAR(30) NOT NULL,
    StatusDomain    AS CONVERT(VARCHAR(50), 'CURATION_DECISION') PERSISTED,
    Comment         NVARCHAR(MAX) NULL,
    StartedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ReviewedAtUtc   DATETIME2(3) NULL,
    
    CONSTRAINT FK_CReview_NFT FOREIGN KEY (NFTId) REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_CReview_Curator FOREIGN KEY (CuratorId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_CReview_Times CHECK (ReviewedAtUtc IS NULL OR ReviewedAtUtc >= StartedAtUtc)
);
GO

PRINT 'Esquema ADMIN creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: auction (Subastas y Ofertas)
-- =====================================================================================

-- Tabla: auction.AuctionSettings
CREATE TABLE auction.AuctionSettings (
    SettingsID              INT PRIMARY KEY,
    CompanyName             NVARCHAR(250) NOT NULL,
    BasePriceETH            DECIMAL(38,18) NOT NULL,
    DefaultAuctionHours     TINYINT NOT NULL,
    MinBidIncrementPct      TINYINT NOT NULL
);
GO

-- Tabla: auction.Auction
CREATE TABLE auction.Auction (
    AuctionId           BIGINT IDENTITY(1,1) PRIMARY KEY,
    SettingsID          INT NULL,
    NFTId               BIGINT NOT NULL UNIQUE,
    StartAtUtc          DATETIME2(3) NOT NULL,
    EndAtUtc            DATETIME2(3) NOT NULL,
    StartingPriceETH    DECIMAL(38,18) NOT NULL,
    CurrentPriceETH     DECIMAL(38,18) NOT NULL,
    CurrentLeaderId     BIGINT NULL,
    StatusCode          VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    StatusDomain        AS CONVERT(VARCHAR(50), 'AUCTION') PERSISTED,
    
    CONSTRAINT FK_Auction_NFT FOREIGN KEY (NFTId) REFERENCES nft.NFT(NFTId),
    CONSTRAINT FK_Auction_Leader FOREIGN KEY (CurrentLeaderId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_Auction_Settings FOREIGN KEY (SettingsID) REFERENCES auction.AuctionSettings(SettingsID),
    CONSTRAINT CK_Auction_Dates CHECK (EndAtUtc > StartAtUtc),
    CONSTRAINT CK_Auction_Prices CHECK (StartingPriceETH > 0 AND CurrentPriceETH >= StartingPriceETH)
);
GO

-- Tabla: auction.Bid
CREATE TABLE auction.Bid (
    BidId           BIGINT IDENTITY(1,1) PRIMARY KEY,
    AuctionId       BIGINT NOT NULL,
    BidderId        BIGINT NOT NULL,
    AmountETH       DECIMAL(38,18) NOT NULL,
    PlacedAtUtc     DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_Bid_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_Bid_User FOREIGN KEY (BidderId) REFERENCES core.[User](UserId),
    CONSTRAINT CK_Bid_Positive CHECK (AmountETH > 0)
);
GO

PRINT 'Esquema AUCTION creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: finance (Finanzas y Transacciones)
-- =====================================================================================

-- Tabla: finance.FundsReservation
CREATE TABLE finance.FundsReservation (
    ReservationId   BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId          BIGINT NOT NULL,
    AuctionId       BIGINT NOT NULL,
    BidId           BIGINT NULL,
    AmountETH       DECIMAL(38,18) NOT NULL,
    StateCode       VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    StatusDomain    AS CONVERT(VARCHAR(50), 'FUNDS_RESERVATION') PERSISTED,
    CreatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_FRes_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_FRes_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT FK_FRes_Bid FOREIGN KEY (BidId) REFERENCES auction.Bid(BidId),
    CONSTRAINT CK_FRes_Positive CHECK (AmountETH > 0)
);
GO

-- Tabla: finance.Ledger
CREATE TABLE finance.Ledger (
    EntryId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId          BIGINT NOT NULL,
    AuctionId       BIGINT NOT NULL,
    EntryType       VARCHAR(10) NOT NULL,
    AmountETH       DECIMAL(38,18) NOT NULL,
    [Description]   NVARCHAR(200) NULL,
    CreatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CONSTRAINT FK_Ledger_User FOREIGN KEY (UserId) REFERENCES core.[User](UserId),
    CONSTRAINT FK_Ledger_Auction FOREIGN KEY (AuctionId) REFERENCES auction.Auction(AuctionId),
    CONSTRAINT CK_Ledger_Type CHECK (EntryType IN ('CREDIT', 'DEBIT')),
    CONSTRAINT CK_Ledger_Positive CHECK (AmountETH > 0)
);
GO

PRINT 'Esquema FINANCE creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: audit (Auditoría y Notificaciones)
-- =====================================================================================

-- Tabla: audit.EmailOutbox
CREATE TABLE audit.EmailOutbox (
    EmailId             BIGINT IDENTITY(1,1) PRIMARY KEY,
    RecipientUserId     BIGINT NULL,
    RecipientEmail      NVARCHAR(100) NULL,
    [Subject]           NVARCHAR(200) NOT NULL,
    Body                NVARCHAR(MAX) NOT NULL,
    StatusCode          VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    StatusDomain        AS CONVERT(VARCHAR(50), 'EMAIL_OUTBOX') PERSISTED,
    CreatedAtUtc        DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    SentAtUtc           DATETIME2(3) NULL,
    CorrelationKey      NVARCHAR(100) NULL,
    
    CONSTRAINT FK_EmailOutbox_User FOREIGN KEY (RecipientUserId) REFERENCES core.[User](UserId)
);
GO

PRINT 'Esquema AUDIT creado correctamente';
GO

-- =====================================================================================
-- ESQUEMA: ops (Operaciones y Configuración del Sistema)
-- =====================================================================================

-- Tabla: ops.Status
CREATE TABLE ops.Status (
    StatusId        INT IDENTITY(1,1) PRIMARY KEY,
    Domain          VARCHAR(50) NOT NULL,
    Code            VARCHAR(30) NOT NULL,
    [Description]   NVARCHAR(200) NULL,
    
    CONSTRAINT UQ_Status_Domain_Code UNIQUE (Domain, Code)
);
GO

-- Tabla: ops.Settings
CREATE TABLE ops.Settings (
    SettingKey      SYSNAME PRIMARY KEY,
    SettingValue    NVARCHAR(200) NOT NULL,
    UpdatedAtUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

PRINT 'Esquema OPS creado correctamente';
GO

-- =====================================================================================
-- FOREIGN KEYS ADICIONALES (Referencias a ops.Status)
-- =====================================================================================

-- Agregar FKs a ops.Status después de que la tabla exista
ALTER TABLE core.UserEmail
    ADD CONSTRAINT FK_UserEmail_Status 
    FOREIGN KEY (StatusDomain, StatusCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE nft.NFT
    ADD CONSTRAINT FK_NFT_Status 
    FOREIGN KEY (StatusDomain, StatusCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE admin.CurationReview
    ADD CONSTRAINT FK_CReview_Status 
    FOREIGN KEY (StatusDomain, DecisionCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE auction.Auction
    ADD CONSTRAINT FK_Auction_Status 
    FOREIGN KEY (StatusDomain, StatusCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE finance.FundsReservation
    ADD CONSTRAINT FK_FRes_Status 
    FOREIGN KEY (StatusDomain, StateCode) 
    REFERENCES ops.Status(Domain, Code);
GO

ALTER TABLE audit.EmailOutbox
    ADD CONSTRAINT FK_EmailOutbox_Status 
    FOREIGN KEY (StatusDomain, StatusCode) 
    REFERENCES ops.Status(Domain, Code);
GO

PRINT 'Foreign Keys a ops.Status creadas correctamente';
GO

-- =====================================================================================
-- DATOS INICIALES
-- =====================================================================================

-- Insertar roles básicos
SET IDENTITY_INSERT core.Role ON;
INSERT INTO core.Role (RoleId, [Name]) VALUES
    (1, 'ADMIN'),
    (2, 'ARTIST'),
    (3, 'CURATOR'),
    (4, 'BIDDER');
SET IDENTITY_INSERT core.Role OFF;
GO

-- Insertar estados del sistema
INSERT INTO ops.Status (Domain, Code, [Description]) VALUES
    -- Estados de NFT
    ('NFT', 'PENDING', 'NFT pendiente de aprobación'),
    ('NFT', 'APPROVED', 'NFT aprobado y listo para subasta'),
    ('NFT', 'REJECTED', 'NFT rechazado por curador'),
    
    -- Estados de Curación
    ('CURATION_DECISION', 'PENDING', 'Pendiente de revisión por curador'),
    ('CURATION_DECISION', 'APPROVED', 'Aprobado por curador'),
    ('CURATION_DECISION', 'REJECTED', 'Rechazado por curador'),
    
    -- Estados de Subasta
    ('AUCTION', 'ACTIVE', 'Subasta activa'),
    ('AUCTION', 'COMPLETED', 'Subasta completada'),
    ('AUCTION', 'CANCELLED', 'Subasta cancelada'),
    
    -- Estados de Email
    ('EMAIL_OUTBOX', 'PENDING', 'Email pendiente de envío'),
    ('EMAIL_OUTBOX', 'SENT', 'Email enviado'),
    ('EMAIL_OUTBOX', 'FAILED', 'Fallo al enviar email'),
    
    -- Estados de UserEmail
    ('USER_EMAIL', 'ACTIVE', 'Email activo'),
    ('USER_EMAIL', 'INACTIVE', 'Email inactivo'),
    
    -- Estados de Reserva de Fondos
    ('FUNDS_RESERVATION', 'ACTIVE', 'Reserva activa'),
    ('FUNDS_RESERVATION', 'RELEASED', 'Fondos liberados'),
    ('FUNDS_RESERVATION', 'CAPTURED', 'Fondos capturados');
GO

-- Configuración inicial de NFT
INSERT INTO nft.NFTSettings (SettingsID, MaxWidthPx, MinWidthPx, MaxHeightPx, MinHeigntPx, MaxFileSizeBytes, MinFileSizeBytes, CreatedAtUtc)
VALUES (1, 4096, 512, 4096, 512, 10485760, 10240, SYSUTCDATETIME());
GO

-- Configuración inicial de Subasta
INSERT INTO auction.AuctionSettings (SettingsID, CompanyName, BasePriceETH, DefaultAuctionHours, MinBidIncrementPct)
VALUES (1, 'ArteCryptoAuctions', 0.01, 72, 5);
GO

PRINT 'Datos iniciales insertados correctamente';
GO

-- =====================================================================================
-- ÍNDICES ADICIONALES (Opcional - para mejorar rendimiento)
-- =====================================================================================

-- Índices en tablas más consultadas
CREATE INDEX IX_NFT_ArtistId ON nft.NFT(ArtistId);
CREATE INDEX IX_NFT_StatusCode ON nft.NFT(StatusCode);
CREATE INDEX IX_Auction_NFTId ON auction.Auction(NFTId);
CREATE INDEX IX_Auction_StatusCode ON auction.Auction(StatusCode);
CREATE INDEX IX_Bid_AuctionId ON auction.Bid(AuctionId);
CREATE INDEX IX_Bid_BidderId ON auction.Bid(BidderId);
CREATE INDEX IX_CurationReview_NFTId ON admin.CurationReview(NFTId);
CREATE INDEX IX_CurationReview_CuratorId ON admin.CurationReview(CuratorId);
GO

PRINT 'Índices creados correctamente';
GO

-- =====================================================================================
-- RESUMEN
-- =====================================================================================

PRINT '';
PRINT '=====================================================================================';
PRINT 'DDL v6 - CREACIÓN COMPLETADA EXITOSAMENTE';
PRINT '=====================================================================================';
PRINT '';
PRINT 'Esquemas creados:';
PRINT '  ✓ core     - Usuarios, Roles, Wallets';
PRINT '  ✓ nft      - NFTs y Configuración';
PRINT '  ✓ admin    - Curación de NFTs';
PRINT '  ✓ auction  - Subastas y Ofertas';
PRINT '  ✓ finance  - Finanzas y Transacciones';
PRINT '  ✓ audit    - Auditoría y Notificaciones';
PRINT '  ✓ ops      - Operaciones y Configuración';
PRINT '';
PRINT 'Tablas creadas: 16';
PRINT 'Roles iniciales: 4 (ADMIN, ARTIST, CURATOR, BIDDER)';
PRINT 'Estados del sistema: 15';
PRINT '';
PRINT 'Base de datos lista para usar.';
PRINT '=====================================================================================';
GO
