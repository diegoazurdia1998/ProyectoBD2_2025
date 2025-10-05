# 🧪 Guía de Pruebas para Triggers - ArteCryptoAuctions

## 📋 Descripción

Este documento describe cómo ejecutar las pruebas para los 4 triggers implementados en el sistema de subastas de NFTs.

## 🎯 Triggers a Probar

1. **`nft.tr_NFT_InsertFlow`** - Validación e inserción de NFTs con asignación de curador
2. **`admin.tr_CurationReview_Decision`** - Procesamiento de decisiones de curación
3. **`nft.tr_NFT_CreateAuction`** - Creación automática de subastas
4. **`auction.tr_Bid_Validation`** - Validación y procesamiento de ofertas

## 📁 Archivos

- **`Triggers_Consolidados_v1.sql`** - Código fuente de los triggers
- **`Test_Triggers.sql`** - Script de pruebas automatizadas
- **`README_Testing.md`** - Este documento

## 🚀 Cómo Ejecutar las Pruebas

### Opción 1: Ejecución Completa (Recomendado)

```sql
-- En SQL Server Management Studio (SSMS):
-- 1. Abrir el archivo Test_Triggers.sql
-- 2. Asegurarse de estar conectado a la base de datos correcta
-- 3. Presionar F5 o hacer clic en "Execute"
```

### Opción 2: Ejecución por Secciones

Puedes ejecutar las pruebas sección por sección seleccionando el código y presionando F5:

1. **Configuración Inicial** (líneas 1-200)
2. **Prueba 1: Inserción de NFT** (líneas 201-350)
3. **Prueba 2: Decisión del Curador** (líneas 351-450)
4. **Prueba 3: Creación de Subasta** (líneas 451-520)
5. **Prueba 4: Validación de Ofertas** (líneas 521-650)
6. **Resumen** (líneas 651-fin)

## 📊 Casos de Prueba Incluidos

### ✅ Prueba 1: Inserción de NFT (`tr_NFT_InsertFlow`)

| Test | Descripción | Resultado Esperado |
|------|-------------|-------------------|
| 1.1 | Inserción exitosa con artista válido | ✓ NFT insertado, curador asignado, emails enviados |
| 1.2 | Usuario sin rol ARTIST | ✗ Rechazo con email de notificación |
| 1.3 | Dimensiones inválidas | ✗ Rechazo con email explicativo |
| 1.4 | Inserción múltiple (Round-Robin) | ✓ Distribución equitativa entre curadores |

**Validaciones verificadas:**
- ✓ Usuario tiene rol ARTIST
- ✓ Email primario existe
- ✓ Dimensiones dentro de rango (NFTSettings)
- ✓ Tamaño de archivo válido
- ✓ Asignación Round-Robin de curadores
- ✓ Generación de HashCode único
- ✓ Notificaciones a artista y curador

### ✅ Prueba 2: Decisión del Curador (`tr_CurationReview_Decision`)

| Test | Descripción | Resultado Esperado |
|------|-------------|-------------------|
| 2.1 | Aprobar NFT | ✓ Estado → APPROVED, email al artista |
| 2.2 | Rechazar NFT | ✓ Estado → REJECTED, email al artista |

**Validaciones verificadas:**
- ✓ Actualización de estado del NFT
- ✓ Registro de fecha de revisión
- ✓ Notificaciones apropiadas según decisión
- ✓ Notificación al curador de decisión procesada

### ✅ Prueba 3: Creación de Subasta (`tr_NFT_CreateAuction`)

| Test | Descripción | Resultado Esperado |
|------|-------------|-------------------|
| 3.1 | NFT aprobado → Subasta | ✓ Subasta creada automáticamente |

**Validaciones verificadas:**
- ✓ Subasta creada al aprobar NFT
- ✓ Configuración correcta (precio, duración)
- ✓ Estado ACTIVE
- ✓ Notificación al artista
- ✓ Notificación a todos los BIDDERS

### ✅ Prueba 4: Validación de Ofertas (`tr_Bid_Validation`)

| Test | Descripción | Resultado Esperado |
|------|-------------|-------------------|
| 4.1 | Oferta válida | ✓ Oferta aceptada, precio actualizado |
| 4.2 | Oferta menor al precio actual | ✗ Rechazo con email |
| 4.3 | Múltiples ofertas | ✓ Líder actualizado, notificación al anterior |

**Validaciones verificadas:**
- ✓ Subasta existe y está activa
- ✓ Oferta mayor al precio actual
- ✓ Artista no puede ofertar en su propia subasta
- ✓ Actualización de CurrentPriceETH
- ✓ Actualización de CurrentLeaderId
- ✓ Notificación al nuevo líder
- ✓ Notificación al líder anterior
- ✓ Notificación al artista

## 📈 Interpretación de Resultados

### Símbolos de Estado

- **✓** = Prueba exitosa
- **✗** = Prueba fallida (comportamiento esperado en validaciones)
- **ERROR** = Error inesperado (requiere investigación)

### Ejemplo de Salida Exitosa

```
=====================================================================================
PRUEBA 1: TRIGGER tr_NFT_InsertFlow (Inserción de NFT)
=====================================================================================

--- Test 1.1: Inserción exitosa de NFT con artista válido ---
✓ NFT insertado correctamente
✓ NFT encontrado en la tabla nft.NFT
✓ Registro de curación creado
✓ Emails generados: 2 (esperados: 2 - artista + curador)
```

## 🔍 Verificación Manual Adicional

Después de ejecutar las pruebas, puedes verificar manualmente:

### 1. Verificar NFTs Creados
```sql
SELECT 
    NFTId,
    ArtistId,
    [Name],
    StatusCode,
    CreatedAtUtc,
    ApprovedAtUtc
FROM nft.NFT
ORDER BY NFTId;
```

### 2. Verificar Asignación de Curadores
```sql
SELECT 
    cr.ReviewId,
    cr.NFTId,
    n.[Name] as NFTName,
    cr.CuratorId,
    u.FullName as CuratorName,
    cr.DecisionCode,
    cr.StartedAtUtc,
    cr.ReviewedAtUtc
FROM admin.CurationReview cr
JOIN nft.NFT n ON n.NFTId = cr.NFTId
JOIN core.[User] u ON u.UserId = cr.CuratorId
ORDER BY cr.ReviewId;
```

### 3. Verificar Subastas Creadas
```sql
SELECT 
    a.AuctionId,
    a.NFTId,
    n.[Name] as NFTName,
    a.StartingPriceETH,
    a.CurrentPriceETH,
    a.CurrentLeaderId,
    u.FullName as CurrentLeader,
    a.StatusCode,
    a.StartAtUtc,
    a.EndAtUtc
FROM auction.Auction a
JOIN nft.NFT n ON n.NFTId = a.NFTId
LEFT JOIN core.[User] u ON u.UserId = a.CurrentLeaderId
ORDER BY a.AuctionId;
```

### 4. Verificar Ofertas
```sql
SELECT 
    b.BidId,
    b.AuctionId,
    b.BidderId,
    u.FullName as BidderName,
    b.AmountETH,
    b.PlacedAtUtc
FROM auction.Bid b
JOIN core.[User] u ON u.UserId = b.BidderId
ORDER BY b.AuctionId, b.PlacedAtUtc;
```

### 5. Verificar Emails Generados
```sql
SELECT 
    EmailId,
    RecipientUserId,
    RecipientEmail,
    [Subject],
    LEFT([Body], 100) as BodyPreview,
    StatusCode,
    CreatedAtUtc
FROM audit.EmailOutbox
ORDER BY CreatedAtUtc DESC;
```

## 🐛 Solución de Problemas

### Error: "Cannot insert duplicate key"
**Causa:** Datos de prueba anteriores no limpiados  
**Solución:** Ejecutar la sección de limpieza del script

### Error: "Foreign key constraint"
**Causa:** Orden incorrecto de eliminación de datos  
**Solución:** El script ya maneja esto, pero si persiste, eliminar manualmente en orden inverso

### Error: "Trigger not found"
**Causa:** Triggers no creados  
**Solución:** Ejecutar primero `Triggers_Consolidados_v1.sql`

### No se generan emails
**Causa:** Estados no existen en ops.Status  
**Solución:** El script crea los estados automáticamente, verificar tabla ops.Status

## 📝 Notas Importantes

1. **Limpieza de Datos:** El script limpia automáticamente datos de pruebas anteriores
2. **Datos de Prueba:** Se crean usuarios, roles y configuraciones necesarias
3. **Transacciones:** Las pruebas NO usan transacciones, los datos quedan en la BD
4. **Producción:** NO ejecutar en base de datos de producción

## 🎓 Para el Proyecto de Clase

### Documentación Requerida

Para tu proyecto de BD2, incluye:

1. ✅ **Código de Triggers** (`Triggers_Consolidados_v1.sql`)
2. ✅ **Script de Pruebas** (`Test_Triggers.sql`)
3. ✅ **Capturas de Pantalla** de la ejecución exitosa
4. ✅ **Resultados de Consultas** de verificación
5. ✅ **Este README** explicando las pruebas

### Capturas Recomendadas

1. Ejecución completa del script de pruebas
2. Tabla de NFTs con diferentes estados
3. Tabla de CurationReview mostrando asignaciones
4. Tabla de Auction con subastas activas
5. Tabla de Bid con ofertas
6. Tabla de EmailOutbox con notificaciones

## 🔄 Flujo Completo Probado

```
1. Artista inserta NFT
   ↓
2. Trigger valida y asigna curador (Round-Robin)
   ↓
3. Curador revisa y aprueba/rechaza
   ↓
4. Si APPROVED → Trigger crea subasta automáticamente
   ↓
5. Oferentes hacen bids
   ↓
6. Trigger valida ofertas y actualiza líder
   ↓
7. Notificaciones en cada paso
```

## 📞 Contacto

Si encuentras problemas o tienes preguntas sobre las pruebas, consulta con tu equipo o profesor.

---

**Última actualización:** 2025-01-05  
**Versión:** 1.0  
**Autor:** Equipo ProyectoBD2_2025
