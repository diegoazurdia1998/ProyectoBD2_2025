# 📋 Guía de Esquemas y Tablas - ArteCryptoAuctions

## 🗂️ Estructura de la Base de Datos

Esta guía muestra la organización de todas las tablas por esquema en el proyecto.

---

## 📊 Resumen por Esquema

| Esquema | Tablas | Propósito |
|---------|--------|-----------|
| **admin** | 1 | Administración y curación |
| **auction** | 3 | Sistema de subastas |
| **audit** | 1 | Auditoría y notificaciones |
| **core** | 5 | Usuarios y configuración base |
| **finance** | 2 | Gestión financiera |
| **nft** | 2 | Gestión de NFTs |
| **ops** | 2 | Operaciones y configuración |

**Total: 7 esquemas, 16 tablas**

---

## 🔵 admin (Administración)

### Tablas:
- **`admin.CurationReview`** - Revisiones de curación de NFTs
  - Almacena las decisiones de los curadores sobre NFTs
  - Estados: PENDING, APPROVED, REJECTED

---

## 🟢 auction (Subastas)

### Tablas:
- **`auction.Auction`** - Subastas activas
  - Información de cada subasta (fechas, precios, líder actual)
  
- **`auction.AuctionSettings`** - Configuración de subastas
  - Parámetros globales (precio base, duración por defecto)
  
- **`auction.Bid`** - Ofertas realizadas
  - Historial de todas las ofertas en las subastas

---

## 🟡 audit (Auditoría)

### Tablas:
- **`audit.EmailOutbox`** - Cola de emails salientes
  - Notificaciones pendientes y enviadas
  - Estados: PENDING, SENT, FAILED

---

## 🔴 core (Núcleo del Sistema)

### Tablas:
- **`core.User`** - Usuarios del sistema
  - Información básica de todos los usuarios
  
- **`core.UserEmail`** - Emails de usuarios
  - Múltiples emails por usuario, con email primario
  
- **`core.UserRole`** - Roles asignados
  - Relación muchos-a-muchos entre usuarios y roles
  
- **`core.Role`** - Catálogo de roles
  - Roles disponibles: ADMIN, ARTIST, CURATOR, BIDDER
  
- **`core.Wallet`** - Billeteras de usuarios
  - Balance y fondos reservados en ETH

---

## 🟣 finance (Finanzas)

### Tablas:
- **`finance.FundsReservation`** - Reservas de fondos
  - Fondos bloqueados para ofertas activas
  
- **`finance.Ledger`** - Libro mayor
  - Registro contable de todas las transacciones

---

## 🟠 nft (NFTs)

### Tablas:
- **`nft.NFT`** - NFTs del sistema
  - Información completa de cada NFT
  - Estados: PENDING, APPROVED, REJECTED
  
- **`nft.NFTSettings`** - Configuración de NFTs
  - Restricciones técnicas (tamaño, dimensiones)

---

## ⚪ ops (Operaciones)

### Tablas:
- **`ops.Status`** - Catálogo de estados
  - Estados válidos por dominio (NFT, AUCTION, etc.)
  
- **`ops.Settings`** - Configuración del sistema
  - Parámetros clave-valor para operación

---

## 🔍 Búsqueda Rápida por Tabla

### A
- `admin.CurationReview` → **admin**
- `auction.Auction` → **auction**
- `auction.AuctionSettings` → **auction**
- `auction.Bid` → **auction**
- `audit.EmailOutbox` → **audit**

### C-F
- `core.Role` → **core**
- `core.User` → **core**
- `core.UserEmail` → **core**
- `core.UserRole` → **core**
- `core.Wallet` → **core**
- `finance.FundsReservation` → **finance**
- `finance.Ledger` → **finance**

### N-O
- `nft.NFT` → **nft**
- `nft.NFTSettings` → **nft**
- `ops.Settings` → **ops**
- `ops.Status` → **ops**

---

## 📝 Convenciones de Nomenclatura

### Formato de Referencia:
```sql
[esquema].[Tabla]
```

### Ejemplos:
```sql
SELECT * FROM core.User;
SELECT * FROM auction.Bid;
SELECT * FROM nft.NFT;
```

---

## 🎯 Uso en Queries

### ✅ Correcto:
```sql
-- Siempre especificar el esquema
SELECT * FROM core.User WHERE UserId = 1;
SELECT * FROM nft.NFT WHERE StatusCode = 'APPROVED';
```

### ❌ Incorrecto:
```sql
-- Evitar omitir el esquema
SELECT * FROM User WHERE UserId = 1;  -- ¿Qué esquema?
SELECT * FROM NFT WHERE StatusCode = 'APPROVED';  -- Ambiguo
```

---

## 🔗 Relaciones Principales

### Flujo NFT → Subasta:
```
nft.NFT 
  ↓
admin.CurationReview (curador revisa)
  ↓
nft.NFT (StatusCode = APPROVED)
  ↓
auction.Auction (se crea subasta)
  ↓
auction.Bid (usuarios ofertan)
```

### Flujo de Usuario:
```
core.User
  ├→ core.UserEmail (emails)
  ├→ core.UserRole (roles)
  ├→ core.Wallet (billetera)
  ├→ nft.NFT (como artista)
  └→ auction.Bid (como oferente)
```

---

## 📌 Notas Importantes

1. **Todos los esquemas deben especificarse** en las queries
2. **ops.Status** es referenciado por múltiples tablas mediante FKs compuestas
3. **core.User** es la tabla central del sistema
4. **nft.NFTSettings** define las restricciones técnicas para NFTs
5. **audit.EmailOutbox** registra todas las notificaciones del sistema

---

## 🛠️ Para Desarrolladores

### Crear nueva tabla:
```sql
CREATE TABLE [esquema].[NombreTabla](
    -- columnas
) ON [PRIMARY];
```

### Consultar esquema de una tabla:
```sql
SELECT 
    SCHEMA_NAME(schema_id) AS Esquema,
    name AS Tabla
FROM sys.tables
WHERE name = 'NombreTabla';
```

### Listar todas las tablas por esquema:
```sql
SELECT 
    s.name AS Esquema,
    t.name AS Tabla,
    COUNT(c.column_id) AS NumColumnas
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN sys.columns c ON t.object_id = c.object_id
WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
GROUP BY s.name, t.name
ORDER BY s.name, t.name;
```

---

**Última actualización:** 2025-01-05  
**Versión DDL:** v6  
**Base de datos:** ArteCryptoAuctions
