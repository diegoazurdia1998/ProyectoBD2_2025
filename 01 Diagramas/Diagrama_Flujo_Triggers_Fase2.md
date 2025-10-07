# 📊 Diagrama de Flujo - Triggers Fase 2
## Sistema ArteCryptoAuctions

---

## 🎯 Visión General del Proceso

El sistema de triggers implementa un flujo automatizado completo desde la creación de un NFT hasta las ofertas en subastas, pasando por validaciones técnicas, curación administrativa y creación automática de subastas.

### Flujo Principal:
```
NFT Creado → Validaciones → Asignación Curador → Decisión Curador → Subasta Automática → Ofertas
```

---

## 📋 Detalle de Cada Trigger

### 🔵 TRIGGER 1: tr_NFT_InsertFlow
**Tabla:** `nft.NFT`  
**Tipo:** INSTEAD OF INSERT  
**Propósito:** Validar y procesar la inserción de nuevos NFTs

#### Validaciones Realizadas:
1. ✅ **Validación de Rol**
   - Usuario debe tener RoleId = 2 (ARTIST)
   - Consulta: `core.UserRole`

2. ✅ **Validación de Email**
   - Usuario debe tener email primario
   - Consulta: `core.UserEmail WHERE IsPrimary = 1`

3. ✅ **Validaciones Técnicas** (contra `nft.NFTSettings`)
   - WidthPx: entre MinWidthPx y MaxWidthPx
   - HeightPx: entre MinHeightPx y MaxHeightPx
   - FileSizeBytes: entre MinFileSizeBytes y MaxFileSizeBytes

4. ✅ **Validación de Curadores**
   - Debe existir al menos un curador (RoleId = 3)

#### Acciones Realizadas:
```sql
-- 1. Insertar NFT
INSERT INTO nft.NFT (
    ArtistId, SettingsID, [Name], [Description],
    ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx,
    SuggestedPriceETH, StatusCode = 'PENDING', CreatedAtUtc
)

-- 2. Generar HashCode único
HashCode = LEFT(CONVERT(VARCHAR(64), 
    HASHBYTES('SHA2_256', 
        NEWID() + ArtistId + SYSUTCDATETIME() + CRYPT_GEN_RANDOM(16)
    ), 2), 64)

-- 3. Asignar curador (Round-Robin)
-- Usa ops.Settings con clave 'CURATION_RR_POS'
CuradorIdx = (CurrentPos + RowNum - 1) % TotalCuradores + 1

-- 4. Crear registro de curación
INSERT INTO admin.CurationReview (
    NFTId, CuratorId, DecisionCode = 'PENDING', StartedAtUtc
)

-- 5. Actualizar posición Round-Robin
UPDATE ops.Settings 
SET SettingValue = (CurrentPos + NFTCount) % TotalCuradores
WHERE SettingKey = 'CURATION_RR_POS'
```

#### Notificaciones Email:
| Destinatario | Asunto | Condición |
|--------------|--------|-----------|
| Artista | "NFT Rechazado - Rol Inválido" | Sin rol ARTIST |
| Artista | "NFT Rechazado - Email Requerido" | Sin email primario |
| Artista | "NFT Rechazado - Validación Técnica" | Falla validación técnica |
| Artista | "NFT en Espera - Sin Curadores" | No hay curadores |
| Artista | "NFT Aceptado - En Revisión" | ✅ NFT insertado |
| Curador | "Nuevo NFT para Revisión" | ✅ NFT asignado |

---

### 🟡 TRIGGER 2: tr_CurationReview_Decision
**Tabla:** `admin.CurationReview`  
**Tipo:** AFTER UPDATE  
**Propósito:** Procesar decisiones de curadores

#### Condición de Activación:
```sql
-- Solo si DecisionCode cambió de PENDING a APPROVED/REJECTED
WHERE i.DecisionCode IN ('APPROVED', 'REJECTED')
  AND d.DecisionCode = 'PENDING'
  AND i.DecisionCode <> d.DecisionCode
```

#### Flujo APPROVED:
```sql
-- 1. Actualizar NFT
UPDATE nft.NFT
SET StatusCode = 'APPROVED',
    ApprovedAtUtc = SYSUTCDATETIME()
WHERE NFTId IN (SELECT NFTId FROM @Decisions WHERE DecisionCode = 'APPROVED')

-- 2. Esto dispara automáticamente el TRIGGER 3
```

#### Flujo REJECTED:
```sql
-- 1. Actualizar NFT
UPDATE nft.NFT
SET StatusCode = 'REJECTED'
WHERE NFTId IN (SELECT NFTId FROM @Decisions WHERE DecisionCode = 'REJECTED')

-- 2. FIN del proceso (no se crea subasta)
```

#### Notificaciones Email:
| Destinatario | Asunto | Condición |
|--------------|--------|-----------|
| Artista | "¡NFT Aprobado!" | DecisionCode = APPROVED |
| Artista | "NFT No Aprobado" | DecisionCode = REJECTED |
| Curador | "Decisión Procesada" | Siempre |

---

### 🟢 TRIGGER 3: tr_NFT_CreateAuction
**Tabla:** `nft.NFT`  
**Tipo:** AFTER UPDATE  
**Propósito:** Crear subasta automáticamente cuando NFT es aprobado

#### Condición de Activación:
```sql
-- Solo si StatusCode cambió a APPROVED
WHERE i.StatusCode = 'APPROVED'
  AND d.StatusCode <> 'APPROVED'
  AND i.ApprovedAtUtc IS NOT NULL
```

#### Configuración de Subasta:
```sql
-- Obtener configuración
SELECT TOP 1
    @SettingsID = SettingsID,
    @BasePriceETH = BasePriceETH,
    @DefaultAuctionHours = DefaultAuctionHours
FROM auction.AuctionSettings

-- Valores por defecto si no existe configuración
@BasePriceETH = 0.01
@DefaultAuctionHours = 72
```

#### Creación de Subasta:
```sql
INSERT INTO auction.Auction (
    SettingsID,
    NFTId,
    StartAtUtc = SYSUTCDATETIME(),  -- Inicia inmediatamente
    EndAtUtc = DATEADD(HOUR, @DefaultAuctionHours, SYSUTCDATETIME()),
    StartingPriceETH = COALESCE(SuggestedPriceETH, @BasePriceETH),
    CurrentPriceETH = COALESCE(SuggestedPriceETH, @BasePriceETH),
    StatusCode = 'ACTIVE'
)
```

#### Notificaciones Email:
| Destinatario | Asunto | Información Incluida |
|--------------|--------|---------------------|
| Artista | "¡Subasta Iniciada!" | AuctionId, Precio Inicial, Fechas |
| Todos los BIDDERS | "Nueva Subasta Disponible" | NFT Name, Precio Inicial, Fecha Fin |

---

## 📊 Tablas Involucradas por Trigger

### TRIGGER 1 (tr_NFT_InsertFlow):
- 📝 **INSERT:** `nft.NFT`, `admin.CurationReview`, `audit.EmailOutbox`
- 🔍 **SELECT:** `core.UserRole`, `core.UserEmail`, `nft.NFTSettings`, `ops.Status`, `ops.Settings`
- ✏️ **UPDATE:** `ops.Settings` (Round-Robin position)

### TRIGGER 2 (tr_CurationReview_Decision):
- 📝 **INSERT:** `audit.EmailOutbox`, `ops.Status` (si no existe)
- 🔍 **SELECT:** `nft.NFT`, `core.UserEmail`
- ✏️ **UPDATE:** `nft.NFT` (StatusCode, ApprovedAtUtc), `admin.CurationReview` (ReviewedAtUtc)

### TRIGGER 3 (tr_NFT_CreateAuction):
- 📝 **INSERT:** `auction.Auction`, `audit.EmailOutbox`, `ops.Status` (si no existe)
- 🔍 **SELECT:** `nft.NFT`, `core.UserEmail`, `auction.AuctionSettings`, `core.UserRole`

---

## 🔐 Estados del Sistema

### Estados de NFT (`nft.NFT.StatusCode`):
```
PENDING → APPROVED → (Subasta creada)
   ↓
REJECTED (FIN)
```

### Estados de Curación (`admin.CurationReview.DecisionCode`):
```
PENDING → APPROVED / REJECTED
```

### Estados de Subasta (`auction.Auction.StatusCode`):
```
ACTIVE → (Proceso de finalización - Fase 3)
```

### Estados de Email (`audit.EmailOutbox.StatusCode`):
```
PENDING → SENT / FAILED
```

---

## ⚙️ Configuraciones del Sistema

### ops.Settings:
| SettingKey | Propósito | Usado en |
|------------|-----------|----------|
| `CURATION_RR_POS` | Posición actual del Round-Robin | TRIGGER 1 |

### ops.Status:
| Domain | Code | Descripción |
|--------|------|-------------|
| NFT | PENDING | NFT pendiente de aprobación |
| NFT | APPROVED | NFT aprobado y listo para subasta |
| NFT | REJECTED | NFT rechazado por curador |
| CURATION_DECISION | PENDING | Pendiente de revisión por curador |
| AUCTION | ACTIVE | Subasta activa |

---

## 🔄 Algoritmo Round-Robin (Asignación de Curadores)

### Funcionamiento:
```python
# Pseudocódigo
total_curadores = COUNT(curadores_activos)
posicion_actual = ops.Settings['CURATION_RR_POS']

for cada_nft in nuevos_nfts:
    indice_curador = ((posicion_actual + nft.RowNum - 1) % total_curadores) + 1
    asignar_curador(nft, curadores[indice_curador])

nueva_posicion = (posicion_actual + COUNT(nuevos_nfts)) % total_curadores
UPDATE ops.Settings SET SettingValue = nueva_posicion
```

### Ejemplo con 3 Curadores:
```
Curadores: [C1, C2, C3]
Posición inicial: 0

NFT1 → (0 + 1 - 1) % 3 + 1 = 1 → C1
NFT2 → (0 + 2 - 1) % 3 + 1 = 2 → C2
NFT3 → (0 + 3 - 1) % 3 + 1 = 3 → C3
NFT4 → (0 + 4 - 1) % 3 + 1 = 1 → C1

Nueva posición: (0 + 4) % 3 = 1
```

---

## 📧 Sistema de Notificaciones

### Tabla: audit.EmailOutbox
Todos los triggers insertan notificaciones en esta tabla para procesamiento asíncrono.

```sql
INSERT INTO audit.EmailOutbox (
    RecipientUserId,
    RecipientEmail,
    [Subject],
    [Body],
    StatusCode = 'PENDING'
)
```

### Tipos de Notificaciones:
1. **Confirmaciones** - Acciones exitosas
2. **Rechazos** - Validaciones fallidas
3. **Alertas** - Cambios de estado importantes
4. **Informativas** - Nuevas oportunidades

---

## 🛡️ Manejo de Errores

Todos los triggers implementan:

```sql
BEGIN TRY
    -- Lógica del trigger
END TRY
BEGIN CATCH
    -- Capturar error
    SET @ErrorMsg = N'Error en [trigger_name]: ' + ERROR_MESSAGE();
    
    -- Notificar al administrador
    INSERT INTO audit.EmailOutbox (
        RecipientUserId = NULL,
        RecipientEmail = 'admin@artecryptoauctions.com',
        [Subject] = N'Error en Sistema',
        [Body] = @ErrorMsg,
        StatusCode = 'PENDING'
    );
    
    -- Re-lanzar el error
    THROW;
END CATCH
```

---

## 📈 Métricas y Monitoreo

### Consultas Útiles:

```sql
-- NFTs por estado
SELECT StatusCode, COUNT(*) as Total
FROM nft.NFT
GROUP BY StatusCode;

-- Curadores y su carga de trabajo
SELECT 
    c.CuratorId,
    COUNT(*) as NFTs_Asignados,
    SUM(CASE WHEN DecisionCode = 'APPROVED' THEN 1 ELSE 0 END) as Aprobados,
    SUM(CASE WHEN DecisionCode = 'REJECTED' THEN 1 ELSE 0 END) as Rechazados
FROM admin.CurationReview c
GROUP BY c.CuratorId;

-- Subastas activas
SELECT COUNT(*) as Subastas_Activas
FROM auction.Auction
WHERE StatusCode = 'ACTIVE'
  AND SYSUTCDATETIME() BETWEEN StartAtUtc AND EndAtUtc;

-- Emails pendientes
SELECT COUNT(*) as Emails_Pendientes
FROM audit.EmailOutbox
WHERE StatusCode = 'PENDING';
```

---
