select * from ops.Status

select * from core."User"

select * from core.UserRole

select * from core.UserEmail

select * from core.Wallet

select * from auction.AuctionSettings

select * from auction.Auction

select * from auction.Bid

select * from nft.NFT

select * from nft.NFTSettings

select * from audit.EmailOutbox

select * from admin.CurationReview

select * from finance.Ledger

select cr.CuratorId, u.FullName, cr.NFTId, cr.StartedAtUtc, cr.ReviewedAtUtc, DATEDIFF(SECOND, cr.StartedAtUtc, cr.ReviewedAtUtc) as segundos, (DATEDIFF(SECOND, cr.StartedAtUtc, cr.ReviewedAtUtc)/3600) as horas
from admin.CurationReview cr
join core.[User] u on cr.CuratorId = u.UserId
order by cr.CuratorId


USE ArteCryptoAuctions;
GO

CREATE VIEW ops.vw_PerformanceMetrics_ByPeriod AS

WITH AuctionBidCounts AS (
    -- 1. Pre-calcula el total de ofertas para cada subasta
    SELECT AuctionId, COUNT(BidId) AS TotalBids
    FROM auction.Bid
    GROUP BY AuctionId
)
SELECT
    -- Periodo de agrupación (basado en la fecha de finalización)
    YEAR(a.EndAtUtc) AS PeriodoAño,
    MONTH(a.EndAtUtc) AS PeriodoMes,
    
    -- Métrica 1: Total de subastas realizadas (que terminaron en este período)
    COUNT(a.AuctionId) AS TotalSubastasRealizadas,
    
    -- Métrica 2: Número de artistas únicos participantes
    -- (Artistas cuyas subastas terminaron en este período)
    COUNT(DISTINCT n.ArtistId) AS ArtistasUnicosParticipantes,
    
    -- Métrica 3: Monto total movilizado (ETH)
    ISNULL(SUM(CASE 
        WHEN a.StatusCode = 'COMPLETED' AND a.CurrentLeaderId IS NOT NULL 
        THEN a.CurrentPriceETH 
        ELSE 0 
    END), 0) AS MontoTotalMovilizadoETH,
    
    -- Métrica 4: Total de ofertas realizadas
    ISNULL(SUM(abc.TotalBids), 0) AS TotalOfertasRealizadas,
    
    -- Métrica 5: Promedio de ofertas por subasta
    ISNULL(CAST(SUM(abc.TotalBids) AS FLOAT) / NULLIF(COUNT(a.AuctionId), 0), 0) AS PromedioOfertasPorSubasta,
    
    -- Métrica 6: Monto promedio por subasta
    ISNULL(SUM(CASE 
        WHEN a.StatusCode = 'COMPLETED' AND a.CurrentLeaderId IS NOT NULL 
        THEN a.CurrentPriceETH 
        ELSE 0 
    END) / NULLIF(COUNT(a.AuctionId), 0), 0) AS MontoPromedioPorSubasta,
    
    -- Métrica 7: Tasa de éxito (% de subastas vendidas)
    AVG(CASE 
        WHEN a.StatusCode = 'COMPLETED' AND a.CurrentLeaderId IS NOT NULL 
        THEN 100.0 
        ELSE 0.0 
    END) AS TasaExitoPct

FROM auction.Auction a
	JOIN nft.NFT n ON a.NFTId = n.NFTId
	LEFT JOIN AuctionBidCounts abc ON a.AuctionId = abc.AuctionId
WHERE
    a.StatusCode IN ('COMPLETED', 'CANCELLED')
GROUP BY
    YEAR(a.EndAtUtc),
    MONTH(a.EndAtUtc)
GO

-- Ejemplo de cómo consultarla:
SELECT * FROM ops.vw_PerformanceMetrics_ByPeriod ORDER BY PeriodoAño, PeriodoMes;