/*
================================================================
SCRIPT 00: REINICIO DE DATOS (TRUNCATE)
================================================================
-- Objetivo: Vacía TODOS los datos de TODAS las tablas para una
--           nueva carga de simulación.
-- Es mucho más rápido que un DROP/CREATE.
*/
USE ArteCryptoAuctions;
GO

-- 1. Deshabilitar TODOS los constraints de FK
PRINT 'Deshabilitando constraints de Llaves Foráneas...';
EXEC sp_msforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";
GO

-- 2. Vaciar las tablas de proceso (Triggers y SPs no se borran)
PRINT 'Vaciando tablas de proceso...';
TRUNCATE TABLE audit.EmailOutbox;
TRUNCATE TABLE finance.Ledger;
TRUNCATE TABLE finance.FundsReservation;
TRUNCATE TABLE auction.Bid;
TRUNCATE TABLE admin.CurationReview;
TRUNCATE TABLE auction.Auction;
TRUNCATE TABLE nft.NFT;
GO

-- 3. Vaciar las tablas de actores
PRINT 'Vaciando tablas de actores...';
TRUNCATE TABLE core.Wallet;
TRUNCATE TABLE core.UserEmail;
TRUNCATE TABLE core.UserRole;
TRUNCATE TABLE core.[User];
GO

-- 4. Vaciar las tablas de catálogos y configuración
PRINT 'Vaciando tablas de catálogos y configuración...';
TRUNCATE TABLE auction.AuctionSettings;
TRUNCATE TABLE nft.NFTSettings;
TRUNCATE TABLE ops.Status;
TRUNCATE TABLE core.Role;
GO

-- 5. Vaciar la tabla de configuración de 'ops' (poblada por triggers)
PRINT 'Vaciando tabla de configuración de operaciones...';
-- Se usa DELETE porque TRUNCATE no es permitido en esta tabla
-- sin deshabilitar más cosas, pero DELETE es igual de efectivo aquí.
DELETE FROM ops.Settings;
GO

-- 6. Rehabilitar TODOS los constraints de FK
PRINT 'Rehabilitando constraints de Llaves Foráneas...';
EXEC sp_msforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all";
GO

PRINT '==================================================';
PRINT ' REINICIO COMPLETADO.';
PRINT ' La base de datos está vacía y lista para la carga.';
PRINT '==================================================';
GO