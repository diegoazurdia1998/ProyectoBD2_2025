--  Consultas

---
--- 1. Consulta de Eficiencia de Curadores
---
SELECT
    u.FullName AS [Nombre del curador],
    COUNT(cr.ReviewId) AS [NFTs revisados (total)],

    -- Calcula el promedio en horas, pero con precisión decimal
    AVG(DATEDIFF(SECOND, cr.StartedAtUtc, cr.ReviewedAtUtc) / 3600.0) AS [Tiempo promedio de revisión (horas)],

    -- Concatena los totales para una fácil lectura
    CONCAT(
        'Aprobados: ', SUM(CASE WHEN cr.DecisionCode = 'APPROVED' THEN 1 ELSE 0 END),
        ' / Rechazados: ', SUM(CASE WHEN cr.DecisionCode = 'REJECTED' THEN 1 ELSE 0 END)
    ) AS [NFTs aprobados vs rechazados],

    -- Tasa de rechazo (multiplicar por 100.0 para asegurar aritmética decimal)
    (SUM(CASE WHEN cr.DecisionCode = 'REJECTED' THEN 1 ELSE 0 END) * 100.0) / COUNT(cr.ReviewId) AS [Tasa de rechazo (%)]
FROM
    admin.CurationReview AS cr
JOIN
    core.[User] AS u ON cr.CuratorId = u.UserId
WHERE
    -- Solo incluir revisiones que ya han sido decididas
    cr.DecisionCode IN ('APPROVED', 'REJECTED')
    AND cr.ReviewedAtUtc IS NOT NULL
GROUP BY
    u.UserId, u.FullName
ORDER BY
    [NFTs revisados (total)] DESC;


---
--- 2. Consulta de Actividad de Coleccionistas (Bidders)
---
WITH
-- CTE 1: Identificar a todos los coleccionistas (Rol 'BIDDER')
Bidders AS (
    SELECT
        u.UserId,
        u.FullName,
        u.CreatedAtUtc,
        ue.Email
    FROM
        core.[User] AS u
    JOIN
        core.UserRole AS ur ON u.UserId = ur.UserId AND ur.RoleId = 4 -- Rol 4 = BIDDER
    LEFT JOIN
        core.UserEmail AS ue ON u.UserId = ue.UserId AND ue.IsPrimary = 1
),

-- CTE 2: Estadísticas de todas las ofertas realizadas
BidStats AS (
    SELECT
        BidderId,
        COUNT(BidId) AS TotalOfertasRealizadas,
        COUNT(DISTINCT AuctionId) AS TotalSubastasParticipadas
    FROM
        auction.Bid
    GROUP BY
        BidderId
),

-- CTE 3: Estadísticas de compras reales (basado en el Ledger)
PurchaseStats AS (
    SELECT
        UserId,
        COUNT(DISTINCT AuctionId) AS SubastasGanadas,
        SUM(AmountETH) AS MontoTotalInvertido
    FROM
        finance.Ledger
    WHERE
        EntryType = 'DEBIT' -- Débito por compra de NFT
    GROUP BY
        UserId
)

-- Consulta final: Combinar todos los datos
SELECT
    b.FullName AS [Nombre],
    b.Email AS [Email],
    b.CreatedAtUtc AS [Fecha registro],
    ISNULL(bs.TotalOfertasRealizadas, 0) AS [Total de ofertas realizadas],
    ISNULL(ps.SubastasGanadas, 0) AS [Subastas ganadas],
    ISNULL(ps.MontoTotalInvertido, 0.0) AS [Monto total invertido (ETH)],

    -- Tasa de éxito = (Ganadas / Participadas)
    CASE
        WHEN ISNULL(bs.TotalSubastasParticipadas, 0) > 0
        THEN (ISNULL(ps.SubastasGanadas, 0) * 100.0) / bs.TotalSubastasParticipadas
        ELSE 0.0
    END AS [Tasa de éxito (%)],

    -- Promedio de ofertas = (Total Ofertas / Participadas)
    CASE
        WHEN ISNULL(bs.TotalSubastasParticipadas, 0) > 0
        THEN CAST(ISNULL(bs.TotalOfertasRealizadas, 0) AS DECIMAL(18,2)) / bs.TotalSubastasParticipadas
        ELSE 0.0
    END AS [Promedio de ofertas por subasta]
FROM
    Bidders AS b
LEFT JOIN
    BidStats AS bs ON b.UserId = bs.BidderId
LEFT JOIN
    PurchaseStats AS ps ON b.UserId = ps.UserId
ORDER BY
    [Monto total invertido (ETH)] DESC,
    [Subastas ganadas] DESC;

---
--- 3. Consulta de Valorización de Artistas (Adaptada)
---
WITH
-- CTE 1: Identificar Artistas (Rol 'ARTIST')
Artists AS (
    SELECT
        u.UserId AS ArtistId,
        u.FullName AS ArtistName
    FROM
        core.[User] AS u
    JOIN
        core.UserRole AS ur ON u.UserId = ur.UserId AND ur.RoleId = 2 -- Rol 2 = ARTIST
),

-- CTE 2: Recopilar todas las ventas (ingresos/créditos a artistas)
ArtistSales AS (
    SELECT
        l.UserId AS ArtistId,
        l.AmountETH AS SalePriceETH,
        l.CreatedAtUtc AS SaleDate,
        a.NFTId
    FROM
        finance.Ledger AS l
    JOIN
        auction.Auction AS a ON l.AuctionId = a.AuctionId
    WHERE
        l.EntryType = 'CREDIT' -- Ingreso por venta
        AND a.StatusCode = 'COMPLETED'
        AND a.CurrentLeaderId IS NOT NULL -- Asegurar que fue una venta exitosa
),

-- CTE 3: Ranquear las ventas por fecha para cada artista
RankedSales AS (
    SELECT
        ArtistId,
        SalePriceETH,
        SaleDate,
        -- La primera venta cronológica tendrá Rank 1
        ROW_NUMBER() OVER(PARTITION BY ArtistId ORDER BY SaleDate ASC) AS SaleRankAsc,
        -- La última venta cronológica tendrá Rank 1
        ROW_NUMBER() OVER(PARTITION BY ArtistId ORDER BY SaleDate DESC) AS SaleRankDesc
    FROM
        ArtistSales
),

-- CTE 4: Obtener métricas agregadas y pivotar la primera/última venta
FinalArtistStats AS (
    SELECT
        s.ArtistId,
        COUNT(s.NFTId) AS [Total NFTs Vendidos],
        AVG(s.SalePriceETH) AS [Precio Promedio (ETH)],
        MAX(CASE WHEN rs.SaleRankAsc = 1 THEN rs.SalePriceETH END) AS [Precio Primera Venta (ETH)],
        MAX(CASE WHEN rs.SaleRankDesc = 1 THEN rs.SalePriceETH END) AS [Precio Última Venta (ETH)]
    FROM
        ArtistSales AS s
    LEFT JOIN
        RankedSales AS rs ON s.ArtistId = rs.ArtistId AND s.SaleDate = rs.SaleDate
    GROUP BY
        s.ArtistId
)

-- Consulta final: Combinar y calcular revalorización
SELECT
    ar.ArtistName AS [Nombre del Artista],
    ISNULL(fs.[Total NFTs Vendidos], 0) AS [Total NFTs Vendidos],
    fs.[Precio Primera Venta (ETH)],
    fs.[Precio Última Venta (ETH)],

    -- Revalorización = ((Última - Primera) / Primera) * 100
    CASE
        WHEN fs.[Precio Primera Venta (ETH)] IS NOT NULL AND fs.[Precio Primera Venta (ETH)] > 0
             AND fs.[Total NFTs Vendidos] > 1 -- Solo si hay más de 1 venta
        THEN ((fs.[Precio Última Venta (ETH)] - fs.[Precio Primera Venta (ETH)]) / fs.[Precio Primera Venta (ETH)]) * 100.0
        ELSE 0.0
    END AS [Revalorización (%)],
    fs.[Precio Promedio (ETH)]
FROM
    Artists AS ar
LEFT JOIN
    FinalArtistStats AS fs ON ar.ArtistId = fs.ArtistId
WHERE
    ISNULL(fs.[Total NFTs Vendidos], 0) > 0 -- Mostrar solo artistas que han vendido
ORDER BY
    [Revalorización (%)] DESC,
    [Total NFTs Vendidos] DESC;

---
--- 4. Consulta de Métricas de Plataforma por Período (Año-Mes)
---
SELECT
    -- Agrupar por Año y Mes
    FORMAT(a.StartAtUtc, 'yyyy-MM') AS [Año y Mes],

    -- 1. Total de subastas que iniciaron en ese período
    COUNT(DISTINCT a.AuctionId) AS [Total de subastas realizadas],

    -- 2. Artistas únicos de esas subastas
    COUNT(DISTINCT n.ArtistId) AS [Número de artistas únicos],

    -- 3. Total de ofertas en esas subastas
    COUNT(b.BidId) AS [Total de ofertas realizadas],

    -- 4. Monto movilizado (solo de subastas completadas y vendidas)
    SUM(CASE
        WHEN a.StatusCode = 'COMPLETED' AND a.CurrentLeaderId IS NOT NULL
        THEN a.CurrentPriceETH
        ELSE 0
    END) AS [Monto total movilizado (ETH)],

    -- 5. Promedio de ofertas por subasta
    CASE
        WHEN COUNT(DISTINCT a.AuctionId) > 0
        THEN CAST(COUNT(b.BidId) AS DECIMAL(18,2)) / COUNT(DISTINCT a.AuctionId)
        ELSE 0
    END AS [Promedio de ofertas por subasta],

    -- 6. Monto promedio por subasta (solo vendidas)
    AVG(CASE
        WHEN a.StatusCode = 'COMPLETED' AND a.CurrentLeaderId IS NOT NULL
        THEN a.CurrentPriceETH
        ELSE NULL -- AVG ignora NULLs, dándonos el promedio solo de las vendidas
    END) AS [Monto promedio por subasta (ETH)],

    -- 7. Tasa de éxito (% de subastas completadas que se vendieron)
    CASE
        -- Evitar división por cero si no hubo subastas completadas
        WHEN COUNT(DISTINCT CASE WHEN a.StatusCode = 'COMPLETED' THEN a.AuctionId END) > 0
        THEN (
            COUNT(DISTINCT CASE WHEN a.StatusCode = 'COMPLETED' AND a.CurrentLeaderId IS NOT NULL THEN a.AuctionId END) * 100.0
        ) / COUNT(DISTINCT CASE WHEN a.StatusCode = 'COMPLETED' THEN a.AuctionId END)
        ELSE 0
    END AS [Tasa de éxito (% de subastas vendidas)]

FROM
    auction.Auction AS a
JOIN
    nft.NFT AS n ON a.NFTId = n.NFTId
LEFT JOIN
    -- Left Join para incluir subastas sin ofertas
    auction.Bid AS b ON a.AuctionId = b.AuctionId
GROUP BY
    FORMAT(a.StartAtUtc, 'yyyy-MM')
ORDER BY
    [Año y Mes] DESC;