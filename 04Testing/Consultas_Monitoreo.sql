-- =====================================================================================
-- CONSULTAS DE MONITOREO - Sistema ArteCryptoAuctions
-- =====================================================================================
-- Consultas útiles para verificar el estado del sistema y los triggers
-- Ejecuta las consultas que necesites para verificar el funcionamiento
-- =====================================================================================

USE ArteCryptoAuctions;
GO

-- =====================================================================================
-- 1. VISTA GENERAL DEL SISTEMA
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '1. VISTA GENERAL DEL SISTEMA';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    'NFTs Totales' as Metrica,
    COUNT(*) as Cantidad,
    '' as Detalle
FROM nft.NFT
UNION ALL
SELECT 
    'NFTs Pendientes',
    COUNT(*),
    CAST(CAST(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM nft.NFT), 0) AS DECIMAL(5,2)) AS VARCHAR) + '%'
FROM nft.NFT WHERE StatusCode = 'PENDING'
UNION ALL
SELECT 
    'NFTs Aprobados',
    COUNT(*),
    CAST(CAST(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM nft.NFT), 0) AS DECIMAL(5,2)) AS VARCHAR) + '%'
FROM nft.NFT WHERE StatusCode = 'APPROVED'
UNION ALL
SELECT 
    'NFTs Rechazados',
    COUNT(*),
    CAST(CAST(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM nft.NFT), 0) AS DECIMAL(5,2)) AS VARCHAR) + '%'
FROM nft.NFT WHERE StatusCode = 'REJECTED'
UNION ALL
SELECT 
    'Subastas Activas',
    COUNT(*),
    ''
FROM auction.Auction WHERE StatusCode = 'ACTIVE'
UNION ALL
SELECT 
    'Total de Ofertas',
    COUNT(*),
    ''
FROM auction.Bid
UNION ALL
SELECT 
    'Emails Pendientes',
    COUNT(*),
    ''
FROM audit.EmailOutbox WHERE StatusCode = 'PENDING'
UNION ALL
SELECT 
    'Usuarios Totales',
    COUNT(*),
    ''
FROM core.[User];

PRINT '';

-- =====================================================================================
-- 2. FLUJO COMPLETO: NFT → CURACIÓN → SUBASTA → OFERTAS
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '2. FLUJO COMPLETO DE NFTs';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    n.NFTId,
    n.[Name] as NFT,
    ua.FullName as Artista,
    n.StatusCode as EstadoNFT,
    cr.DecisionCode as DecisionCurador,
    uc.FullName as Curador,
    a.AuctionId,
    a.StatusCode as EstadoSubasta,
    a.CurrentPriceETH as PrecioActual,
    ul.FullName as LiderActual,
    (SELECT COUNT(*) FROM auction.Bid WHERE AuctionId = a.AuctionId) as TotalOfertas,
    n.CreatedAtUtc as FechaCreacion,
    cr.ReviewedAtUtc as FechaRevision,
    a.StartAtUtc as InicioSubasta
FROM nft.NFT n
JOIN core.[User] ua ON ua.UserId = n.ArtistId
LEFT JOIN admin.CurationReview cr ON cr.NFTId = n.NFTId
LEFT JOIN core.[User] uc ON uc.UserId = cr.CuratorId
LEFT JOIN auction.Auction a ON a.NFTId = n.NFTId
LEFT JOIN core.[User] ul ON ul.UserId = a.CurrentLeaderId
ORDER BY n.NFTId DESC;

PRINT '';

-- =====================================================================================
-- 3. DISTRIBUCIÓN DE CARGA DE CURADORES (Round-Robin)
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '3. DISTRIBUCIÓN DE CARGA DE CURADORES';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    u.UserId,
    u.FullName as Curador,
    COUNT(cr.ReviewId) as NFTsAsignados,
    SUM(CASE WHEN cr.DecisionCode = 'PENDING' THEN 1 ELSE 0 END) as Pendientes,
    SUM(CASE WHEN cr.DecisionCode = 'APPROVED' THEN 1 ELSE 0 END) as Aprobados,
    SUM(CASE WHEN cr.DecisionCode = 'REJECTED' THEN 1 ELSE 0 END) as Rechazados,
    CAST(AVG(CASE 
        WHEN cr.ReviewedAtUtc IS NOT NULL 
        THEN DATEDIFF(MINUTE, cr.StartedAtUtc, cr.ReviewedAtUtc) 
        ELSE NULL 
    END) AS DECIMAL(10,2)) as TiempoPromedioMinutos
FROM core.[User] u
JOIN core.UserRole ur ON ur.UserId = u.UserId AND ur.RoleId = 3
LEFT JOIN admin.CurationReview cr ON cr.CuratorId = u.UserId
GROUP BY u.UserId, u.FullName
ORDER BY NFTsAsignados DESC;

PRINT '';

-- =====================================================================================
-- 4. ACTIVIDAD DE SUBASTAS
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '4. ACTIVIDAD DE SUBASTAS';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    a.AuctionId,
    n.[Name] as NFT,
    ua.FullName as Artista,
    a.StartingPriceETH as PrecioInicial,
    a.CurrentPriceETH as PrecioActual,
    CAST((a.CurrentPriceETH - a.StartingPriceETH) / a.StartingPriceETH * 100 AS DECIMAL(10,2)) as IncrementoPct,
    ul.FullName as LiderActual,
    (SELECT COUNT(*) FROM auction.Bid WHERE AuctionId = a.AuctionId) as TotalOfertas,
    (SELECT COUNT(DISTINCT BidderId) FROM auction.Bid WHERE AuctionId = a.AuctionId) as ParticipantesUnicos,
    a.StatusCode,
    a.StartAtUtc as Inicio,
    a.EndAtUtc as Fin,
    CASE 
        WHEN a.EndAtUtc > SYSUTCDATETIME() 
        THEN CAST(DATEDIFF(HOUR, SYSUTCDATETIME(), a.EndAtUtc) AS VARCHAR) + ' horas restantes'
        ELSE 'Finalizada'
    END as TiempoRestante
FROM auction.Auction a
JOIN nft.NFT n ON n.NFTId = a.NFTId
JOIN core.[User] ua ON ua.UserId = n.ArtistId
LEFT JOIN core.[User] ul ON ul.UserId = a.CurrentLeaderId
ORDER BY a.AuctionId DESC;

PRINT '';

-- =====================================================================================
-- 5. RANKING DE OFERENTES
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '5. RANKING DE OFERENTES';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    u.UserId,
    u.FullName as Oferente,
    ue.Email,
    COUNT(b.BidId) as TotalOfertas,
    MIN(b.AmountETH) as OfertaMinima,
    MAX(b.AmountETH) as OfertaMaxima,
    AVG(b.AmountETH) as OfertaPromedio,
    SUM(CASE 
        WHEN b.BidderId = (SELECT CurrentLeaderId FROM auction.Auction WHERE AuctionId = b.AuctionId)
        THEN 1 ELSE 0 
    END) as SubastasLiderando,
    w.BalanceETH as SaldoActual,
    w.ReservedETH as SaldoReservado
FROM core.[User] u
JOIN core.UserRole ur ON ur.UserId = u.UserId AND ur.RoleId = 4
LEFT JOIN core.UserEmail ue ON ue.UserId = u.UserId AND ue.IsPrimary = 1
LEFT JOIN auction.Bid b ON b.BidderId = u.UserId
LEFT JOIN core.Wallet w ON w.UserId = u.UserId
GROUP BY u.UserId, u.FullName, ue.Email, w.BalanceETH, w.ReservedETH
ORDER BY TotalOfertas DESC, OfertaMaxima DESC;

PRINT '';

-- =====================================================================================
-- 6. HISTORIAL DE OFERTAS POR SUBASTA
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '6. HISTORIAL DETALLADO DE OFERTAS';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    b.BidId,
    a.AuctionId,
    n.[Name] as NFT,
    b.BidderId,
    u.FullName as Oferente,
    b.AmountETH as Oferta,
    b.PlacedAtUtc as FechaOferta,
    CASE 
        WHEN b.BidderId = a.CurrentLeaderId THEN '👑 LÍDER ACTUAL'
        WHEN b.AmountETH = (
            SELECT MAX(AmountETH) 
            FROM auction.Bid 
            WHERE AuctionId = b.AuctionId 
            AND BidId < b.BidId
        ) THEN '⭐ Fue líder'
        ELSE ''
    END as Estado,
    LAG(b.AmountETH) OVER (PARTITION BY b.AuctionId ORDER BY b.PlacedAtUtc) as OfertaAnterior,
    b.AmountETH - LAG(b.AmountETH) OVER (PARTITION BY b.AuctionId ORDER BY b.PlacedAtUtc) as Incremento
FROM auction.Bid b
JOIN auction.Auction a ON a.AuctionId = b.AuctionId
JOIN nft.NFT n ON n.NFTId = a.NFTId
JOIN core.[User] u ON u.UserId = b.BidderId
ORDER BY b.AuctionId, b.PlacedAtUtc;

PRINT '';

-- =====================================================================================
-- 7. ANÁLISIS DE EMAILS
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '7. ANÁLISIS DE NOTIFICACIONES (EMAILS)';
PRINT '=====================================================================================';
PRINT '';

-- Resumen por tipo de email
SELECT 
    [Subject] as TipoEmail,
    COUNT(*) as Cantidad,
    SUM(CASE WHEN StatusCode = 'PENDING' THEN 1 ELSE 0 END) as Pendientes,
    SUM(CASE WHEN StatusCode = 'SENT' THEN 1 ELSE 0 END) as Enviados,
    MIN(CreatedAtUtc) as PrimerEmail,
    MAX(CreatedAtUtc) as UltimoEmail
FROM audit.EmailOutbox
GROUP BY [Subject]
ORDER BY Cantidad DESC;

PRINT '';

-- Últimos 10 emails
PRINT '--- Últimos 10 Emails Generados ---';
SELECT TOP 10
    EmailId,
    RecipientEmail,
    [Subject],
    LEFT([Body], 100) as BodyPreview,
    StatusCode,
    CreatedAtUtc
FROM audit.EmailOutbox
ORDER BY EmailId DESC;

PRINT '';

-- =====================================================================================
-- 8. RENDIMIENTO DE ARTISTAS
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '8. RENDIMIENTO DE ARTISTAS';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    u.UserId,
    u.FullName as Artista,
    ue.Email,
    COUNT(n.NFTId) as NFTsCreados,
    SUM(CASE WHEN n.StatusCode = 'PENDING' THEN 1 ELSE 0 END) as Pendientes,
    SUM(CASE WHEN n.StatusCode = 'APPROVED' THEN 1 ELSE 0 END) as Aprobados,
    SUM(CASE WHEN n.StatusCode = 'REJECTED' THEN 1 ELSE 0 END) as Rechazados,
    CAST(SUM(CASE WHEN n.StatusCode = 'APPROVED' THEN 1 ELSE 0 END) * 100.0 / 
         NULLIF(COUNT(n.NFTId), 0) AS DECIMAL(5,2)) as TasaAprobacionPct,
    COUNT(a.AuctionId) as SubastasActivas,
    ISNULL(SUM(a.CurrentPriceETH), 0) as ValorTotalEnSubasta,
    (SELECT COUNT(*) FROM auction.Bid b 
     JOIN auction.Auction au ON au.AuctionId = b.AuctionId 
     WHERE au.NFTId IN (SELECT NFTId FROM nft.NFT WHERE ArtistId = u.UserId)) as TotalOfertasRecibidas
FROM core.[User] u
JOIN core.UserRole ur ON ur.UserId = u.UserId AND ur.RoleId = 2
LEFT JOIN core.UserEmail ue ON ue.UserId = u.UserId AND ue.IsPrimary = 1
LEFT JOIN nft.NFT n ON n.ArtistId = u.UserId
LEFT JOIN auction.Auction a ON a.NFTId = n.NFTId AND a.StatusCode = 'ACTIVE'
GROUP BY u.UserId, u.FullName, ue.Email
ORDER BY NFTsCreados DESC, TasaAprobacionPct DESC;

PRINT '';

-- =====================================================================================
-- 9. VERIFICACIÓN DE INTEGRIDAD
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '9. VERIFICACIÓN DE INTEGRIDAD DEL SISTEMA';
PRINT '=====================================================================================';
PRINT '';

-- NFTs sin curador asignado
PRINT '--- NFTs sin Curador Asignado ---';
SELECT 
    n.NFTId,
    n.[Name],
    n.StatusCode,
    n.CreatedAtUtc
FROM nft.NFT n
LEFT JOIN admin.CurationReview cr ON cr.NFTId = n.NFTId
WHERE cr.ReviewId IS NULL;

PRINT '';

-- NFTs aprobados sin subasta
PRINT '--- NFTs Aprobados sin Subasta ---';
SELECT 
    n.NFTId,
    n.[Name],
    n.StatusCode,
    n.ApprovedAtUtc
FROM nft.NFT n
LEFT JOIN auction.Auction a ON a.NFTId = n.NFTId
WHERE n.StatusCode = 'APPROVED'
  AND a.AuctionId IS NULL;

PRINT '';

-- Subastas sin ofertas
PRINT '--- Subastas sin Ofertas ---';
SELECT 
    a.AuctionId,
    n.[Name] as NFT,
    a.StartingPriceETH,
    a.StatusCode,
    DATEDIFF(HOUR, a.StartAtUtc, SYSUTCDATETIME()) as HorasActiva
FROM auction.Auction a
JOIN nft.NFT n ON n.NFTId = a.NFTId
WHERE NOT EXISTS (SELECT 1 FROM auction.Bid WHERE AuctionId = a.AuctionId)
  AND a.StatusCode = 'ACTIVE';

PRINT '';

-- Usuarios sin email primario
PRINT '--- Usuarios sin Email Primario ---';
SELECT 
    u.UserId,
    u.FullName,
    STRING_AGG(r.[Name], ', ') as Roles
FROM core.[User] u
LEFT JOIN core.UserEmail ue ON ue.UserId = u.UserId AND ue.IsPrimary = 1
LEFT JOIN core.UserRole ur ON ur.UserId = u.UserId
LEFT JOIN core.Role r ON r.RoleId = ur.RoleId
WHERE ue.EmailId IS NULL
GROUP BY u.UserId, u.FullName;

PRINT '';

-- =====================================================================================
-- 10. CONFIGURACIÓN DEL SISTEMA
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '10. CONFIGURACIÓN DEL SISTEMA';
PRINT '=====================================================================================';
PRINT '';

-- Settings de NFT
PRINT '--- Configuración de NFT ---';
SELECT * FROM nft.NFTSettings;
PRINT '';

-- Settings de Subasta
PRINT '--- Configuración de Subasta ---';
SELECT * FROM auction.AuctionSettings;
PRINT '';

-- Settings operacionales
PRINT '--- Configuración Operacional ---';
SELECT * FROM ops.Settings ORDER BY SettingKey;
PRINT '';

-- Estados del sistema
PRINT '--- Estados Disponibles ---';
SELECT 
    Domain,
    Code,
    Description,
    COUNT(*) OVER (PARTITION BY Domain) as EstadosPorDominio
FROM ops.Status
ORDER BY Domain, Code;
PRINT '';

-- Roles del sistema
PRINT '--- Roles del Sistema ---';
SELECT 
    r.RoleId,
    r.[Name] as Rol,
    COUNT(ur.UserId) as UsuariosConRol
FROM core.Role r
LEFT JOIN core.UserRole ur ON ur.RoleId = r.RoleId
GROUP BY r.RoleId, r.[Name]
ORDER BY r.RoleId;

PRINT '';

-- =====================================================================================
-- 11. TIMELINE DE ACTIVIDAD
-- =====================================================================================
PRINT '=====================================================================================';
PRINT '11. TIMELINE DE ACTIVIDAD (Últimas 24 horas)';
PRINT '=====================================================================================';
PRINT '';

SELECT 
    Evento,
    Descripcion,
    FechaHora,
    Usuario
FROM (
    -- NFTs creados
    SELECT 
        'NFT Creado' as Evento,
        n.[Name] as Descripcion,
        n.CreatedAtUtc as FechaHora,
        u.FullName as Usuario
    FROM nft.NFT n
    JOIN core.[User] u ON u.UserId = n.ArtistId
    WHERE n.CreatedAtUtc >= DATEADD(HOUR, -24, SYSUTCDATETIME())
    
    UNION ALL
    
    -- Revisiones completadas
    SELECT 
        'Revisión ' + cr.DecisionCode,
        n.[Name],
        cr.ReviewedAtUtc,
        u.FullName
    FROM admin.CurationReview cr
    JOIN nft.NFT n ON n.NFTId = cr.NFTId
    JOIN core.[User] u ON u.UserId = cr.CuratorId
    WHERE cr.ReviewedAtUtc >= DATEADD(HOUR, -24, SYSUTCDATETIME())
    
    UNION ALL
    
    -- Subastas iniciadas
    SELECT 
        'Subasta Iniciada',
        n.[Name],
        a.StartAtUtc,
        u.FullName
    FROM auction.Auction a
    JOIN nft.NFT n ON n.NFTId = a.NFTId
    JOIN core.[User] u ON u.UserId = n.ArtistId
    WHERE a.StartAtUtc >= DATEADD(HOUR, -24, SYSUTCDATETIME())
    
    UNION ALL
    
    -- Ofertas realizadas
    SELECT 
        'Oferta: ' + CAST(b.AmountETH AS VARCHAR) + ' ETH',
        n.[Name],
        b.PlacedAtUtc,
        u.FullName
    FROM auction.Bid b
    JOIN auction.Auction a ON a.AuctionId = b.AuctionId
    JOIN nft.NFT n ON n.NFTId = a.NFTId
    JOIN core.[User] u ON u.UserId = b.BidderId
    WHERE b.PlacedAtUtc >= DATEADD(HOUR, -24, SYSUTCDATETIME())
) AS Timeline
ORDER BY FechaHora DESC;

PRINT '';

PRINT '=====================================================================================';
PRINT 'FIN DE CONSULTAS DE MONITOREO';
PRINT '=====================================================================================';
GO
