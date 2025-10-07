# 🚀 Guía de Inicio Rápido - Testing de Triggers

## 📦 Archivos Disponibles

| Archivo | Propósito | Cuándo Usar |
|---------|-----------|-------------|
| `Triggers_Consolidados_v1.sql` | Código fuente de los triggers | Crear/actualizar triggers |
| `Test_Triggers.sql` | Pruebas automatizadas completas | Testing exhaustivo |
| `Test_Triggers_Manual.sql` | Pruebas paso a paso interactivas | Aprendizaje y debugging |
| `Consultas_Monitoreo.sql` | Consultas de verificación | Monitoreo del sistema |
| `README_Testing.md` | Documentación completa | Referencia detallada |
| `INICIO_RAPIDO.md` | Esta guía | Empezar rápidamente |

## ⚡ Inicio Rápido (5 minutos)

### Paso 1: Instalar los Triggers (1 min)

```sql
-- En SSMS, abrir y ejecutar:
Triggers_Consolidados_v1.sql
```

✅ **Resultado esperado:** Mensaje "TRIGGERS CONSOLIDADOS CREADOS EXITOSAMENTE"

---

### Paso 2: Ejecutar Pruebas Automáticas (2 min)

```sql
-- En SSMS, abrir y ejecutar:
Test_Triggers.sql
```

✅ **Resultado esperado:** 
- Múltiples mensajes con ✓ (éxito)
- Algunas validaciones con ✗ (comportamiento esperado)
- Resumen final con estadísticas

---

### Paso 3: Verificar Resultados (2 min)

```sql
-- En SSMS, abrir y ejecutar secciones de:
Consultas_Monitoreo.sql
```

✅ **Resultado esperado:** Tablas con datos de prueba

---

## 🎯 Flujos de Trabajo Recomendados

### 🔰 Para Aprender (Primera Vez)

1. **Leer** `README_Testing.md` (10 min)
2. **Ejecutar** `Test_Triggers_Manual.sql` paso a paso (15 min)
3. **Observar** resultados después de cada paso
4. **Experimentar** modificando valores

### 🧪 Para Testing Completo

1. **Ejecutar** `Test_Triggers.sql` completo
2. **Revisar** output en Messages
3. **Verificar** con `Consultas_Monitoreo.sql`
4. **Documentar** resultados con capturas

### 🐛 Para Debugging

1. **Ejecutar** `Test_Triggers_Manual.sql` hasta el paso con problema
2. **Usar** `Consultas_Monitoreo.sql` para investigar
3. **Modificar** trigger en `Triggers_Consolidados_v1.sql`
4. **Re-ejecutar** pruebas

### 📊 Para Presentación/Proyecto

1. **Ejecutar** `Test_Triggers.sql` completo
2. **Capturar** pantallas de:
   - Ejecución exitosa
   - Consultas de monitoreo (secciones 2, 4, 5, 8)
   - Tabla de emails generados
3. **Incluir** en documentación del proyecto

---

## 📋 Checklist de Verificación

Después de ejecutar las pruebas, verifica:

### ✅ Trigger 1: Inserción de NFT
- [ ] NFTs insertados correctamente
- [ ] Curadores asignados (Round-Robin)
- [ ] Emails enviados a artista y curador
- [ ] Validaciones funcionando (rol, dimensiones)

### ✅ Trigger 2: Decisión del Curador
- [ ] Estado del NFT actualizado (APPROVED/REJECTED)
- [ ] Fecha de revisión registrada
- [ ] Emails enviados según decisión

### ✅ Trigger 3: Creación de Subasta
- [ ] Subasta creada automáticamente al aprobar
- [ ] Configuración correcta (precio, duración)
- [ ] Emails a artista y bidders

### ✅ Trigger 4: Validación de Ofertas
- [ ] Ofertas válidas aceptadas
- [ ] Ofertas inválidas rechazadas
- [ ] Precio y líder actualizados
- [ ] Emails a todos los involucrados

---

## 🎬 Ejemplo de Sesión Completa

```sql
-- ============================================
-- SESIÓN DE PRUEBA COMPLETA (10 minutos)
-- ============================================

-- 1. Instalar triggers (si no están instalados)
-- Ejecutar: Triggers_Consolidados_v1.sql

-- 2. Ejecutar pruebas automáticas
-- Ejecutar: Test_Triggers.sql

-- 3. Verificar resultados principales
USE ArteCryptoAuctions;

-- Ver NFTs creados
SELECT NFTId, [Name], StatusCode FROM nft.NFT;

-- Ver distribución de curadores
SELECT 
    u.FullName,
    COUNT(*) as NFTsAsignados
FROM admin.CurationReview cr
JOIN core.[User] u ON u.UserId = cr.CuratorId
GROUP BY u.FullName;

-- Ver subastas activas
SELECT 
    AuctionId,
    StartingPriceETH,
    CurrentPriceETH,
    StatusCode
FROM auction.Auction;

-- Ver ofertas
SELECT 
    b.BidId,
    u.FullName as Oferente,
    b.AmountETH
FROM auction.Bid b
JOIN core.[User] u ON u.UserId = b.BidderId
ORDER BY b.AmountETH DESC;

-- Ver emails generados
SELECT 
    [Subject],
    COUNT(*) as Cantidad
FROM audit.EmailOutbox
GROUP BY [Subject];
```

---

## 🔧 Comandos Útiles

### Limpiar Datos de Prueba

```sql
USE ArteCryptoAuctions;

DELETE FROM finance.FundsReservation;
DELETE FROM finance.Ledger;
DELETE FROM auction.Bid;
DELETE FROM auction.Auction;
DELETE FROM admin.CurationReview;
DELETE FROM nft.NFT;
DELETE FROM core.Wallet;
DELETE FROM core.UserEmail;
DELETE FROM core.UserRole;
DELETE FROM core.[User];
DELETE FROM audit.EmailOutbox;

PRINT 'Datos de prueba eliminados';
```

### Ver Triggers Instalados

```sql
SELECT 
    SCHEMA_NAME(schema_id) + '.' + name as TriggerName,
    OBJECT_NAME(parent_id) as TableName,
    type_desc,
    create_date,
    modify_date
FROM sys.triggers
WHERE is_ms_shipped = 0
ORDER BY SCHEMA_NAME(schema_id), name;
```

### Verificar Estados del Sistema

```sql
SELECT Domain, Code, Description
FROM ops.Status
ORDER BY Domain, Code;
```

---

## 📸 Capturas Recomendadas para el Proyecto

1. **Ejecución de Test_Triggers.sql**
   - Captura completa mostrando todos los ✓
   
2. **Flujo Completo (Consultas_Monitoreo.sql - Sección 2)**
   - Tabla mostrando NFT → Curación → Subasta → Ofertas

3. **Distribución de Curadores (Consultas_Monitoreo.sql - Sección 3)**
   - Tabla mostrando Round-Robin funcionando

4. **Actividad de Subastas (Consultas_Monitoreo.sql - Sección 4)**
   - Tabla con subastas activas y ofertas

5. **Emails Generados (Consultas_Monitoreo.sql - Sección 7)**
   - Tabla mostrando notificaciones por tipo

6. **Rendimiento de Artistas (Consultas_Monitoreo.sql - Sección 8)**
   - Tabla con estadísticas de artistas

---

## 🎓 Para tu Presentación

### Estructura Sugerida

1. **Introducción** (2 min)
   - Explicar el sistema de subastas NFT
   - Mostrar diagrama del flujo

2. **Demostración de Triggers** (5 min)
   - Ejecutar `Test_Triggers_Manual.sql` paso a paso
   - Mostrar resultados después de cada trigger

3. **Resultados y Métricas** (3 min)
   - Mostrar consultas de monitoreo
   - Destacar funcionalidades clave

4. **Conclusiones** (2 min)
   - Resumen de lo implementado
   - Beneficios del sistema

### Puntos Clave a Destacar

✨ **Automatización completa** del flujo NFT → Subasta
✨ **Validaciones robustas** en cada paso
✨ **Notificaciones automáticas** a todos los usuarios
✨ **Round-Robin** para distribución equitativa
✨ **Integridad de datos** garantizada

---

## 🆘 Solución Rápida de Problemas

| Problema | Solución |
|----------|----------|
| "Trigger not found" | Ejecutar `Triggers_Consolidados_v1.sql` |
| "Foreign key constraint" | Limpiar datos en orden correcto |
| "Cannot insert duplicate" | Limpiar datos de prueba |
| No se generan emails | Verificar tabla `ops.Status` |
| Curadores no asignados | Verificar que existan usuarios con RoleId = 3 |

---

## 📞 Siguiente Paso

**¿Listo para empezar?**

👉 Abre SSMS y ejecuta `Test_Triggers_Manual.sql` paso a paso

**¿Necesitas más detalles?**

👉 Lee `README_Testing.md` para documentación completa

**¿Quieres ver el código?**

👉 Revisa `Triggers_Consolidados_v1.sql` con comentarios detallados

---

**¡Éxito con tu proyecto de BD2! 🎉**
