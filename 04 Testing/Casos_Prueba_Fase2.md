# CASOS DE PRUEBA - FASE 2
## Sistema de Triggers para Gestión de NFTs y Subastas
### Proyecto: ArteCryptoAuctions

---

## INFORMACIÓN GENERAL

**Proyecto:** ArteCryptoAuctions  
**Fase:** 2 - Implementación de Triggers  
**Versión:** 1.0  
**Fecha:** 2025-01-05  
**Base de Datos:** SQL Server  

---

## ALCANCE DE LAS PRUEBAS

Este documento describe los casos de prueba para validar el correcto funcionamiento de los tres triggers principales implementados en la Fase 2:

1. **TRIGGER 1:** tr_NFT_InsertFlow - Inserción y validación de NFTs
2. **TRIGGER 2:** tr_CurationReview_Decision - Procesamiento de decisiones de curación
3. **TRIGGER 3:** tr_NFT_CreateAuction - Creación automática de subastas

---

## CONFIGURACIÓN PREVIA

### Requisitos del Entorno

- Base de datos ArteCryptoAuctions creada y configurada
- Esquemas: nft, admin, auction, core, audit, ops
- Triggers implementados según archivo Triggers_Fase2_v1.sql
- Estados del sistema configurados en tabla ops.Status
- Roles configurados en tabla core.Role

### Datos de Prueba Necesarios

**Usuarios:**
- Mínimo 2 usuarios con rol ARTIST (RoleId = 2)
- Mínimo 2 usuarios con rol CURATOR (RoleId = 3)
- Mínimo 2 usuarios con rol BIDDER (RoleId = 4)
- 1 usuario sin rol asignado (para pruebas de validación)

**Configuración:**
- Registro en nft.NFTSettings con límites técnicos
- Registro en auction.AuctionSettings con configuración de subastas
- Emails primarios configurados para todos los usuarios

---

## TRIGGER 1: tr_NFT_InsertFlow

### Descripción
Trigger de tipo INSTEAD OF INSERT en la tabla nft.NFT que valida y procesa la inserción de nuevos NFTs, asigna curadores mediante algoritmo Round-Robin y genera notificaciones.

---

### CP-T1-001: Inserción Exitosa de NFT con Datos Válidos

**Objetivo:** Verificar que un NFT con datos válidos se inserta correctamente y se asigna un curador.

**Precondiciones:**
- Usuario con rol ARTIST existe
- Usuario tiene email primario configurado
- Existen curadores disponibles (rol CURATOR)
- Configuración NFTSettings existe

**Datos de Entrada:**
```sql
ArtistId: [ID de usuario con rol ARTIST]
SettingsID: 1
Name: 'Obra Digital Abstracta'
Description: 'Composición digital de arte abstracto'
ContentType: 'image/png'
FileSizeBytes: 2048000
WidthPx: 1920
HeightPx: 1080
SuggestedPriceETH: 0.5
StatusCode: 'PENDING'
```

**Pasos de Ejecución:**
1. Limpiar tabla audit.EmailOutbox
2. Ejecutar INSERT en nft.NFT con los datos especificados
3. Consultar tabla nft.NFT para verificar inserción
4. Consultar tabla admin.CurationReview para verificar asignación de curador
5. Consultar tabla audit.EmailOutbox para verificar notificaciones

**Resultados Esperados:**
- NFT insertado en tabla nft.NFT con StatusCode = 'PENDING'
- HashCode generado automáticamente (64 caracteres hexadecimales)
- Registro creado en admin.CurationReview con DecisionCode = 'PENDING'
- CuratorId asignado mediante Round-Robin
- 2 registros en audit.EmailOutbox:
  - Email al artista: Asunto contiene "NFT Aceptado"
  - Email al curador: Asunto contiene "Nuevo NFT para Revisión"

**Criterios de Aceptación:**
- El NFT existe en la base de datos
- El curador asignado tiene rol CURATOR
- Los emails contienen información correcta del NFT

---

### CP-T1-002: Rechazo por Usuario sin Rol ARTIST

**Objetivo:** Verificar que el sistema rechaza NFTs de usuarios sin el rol ARTIST.

**Precondiciones:**
- Usuario existe pero NO tiene rol ARTIST asignado
- Usuario tiene email primario configurado

**Datos de Entrada:**
```sql
ArtistId: [ID de usuario SIN rol ARTIST]
SettingsID: 1
Name: 'Intento de NFT Sin Permiso'
Description: 'Usuario sin rol de artista'
ContentType: 'image/png'
FileSizeBytes: 2048000
WidthPx: 1920
HeightPx: 1080
SuggestedPriceETH: 0.3
StatusCode: 'PENDING'
```

**Pasos de Ejecución:**
1. Limpiar tabla audit.EmailOutbox
2. Ejecutar INSERT en nft.NFT con los datos especificados
3. Consultar tabla nft.NFT para verificar que NO se insertó
4. Consultar tabla audit.EmailOutbox para verificar notificación de rechazo

**Resultados Esperados:**
- NFT NO insertado en tabla nft.NFT
- NO se crea registro en admin.CurationReview
- 1 registro en audit.EmailOutbox:
  - Destinatario: Usuario que intentó crear el NFT
  - Asunto: "NFT Rechazado - Rol Inválido"
  - Cuerpo: Indica que el usuario no posee el rol de Artista

**Criterios de Aceptación:**
- La tabla nft.NFT no contiene el NFT rechazado
- El usuario recibe notificación clara del motivo del rechazo

---

### CP-T1-003: Rechazo por Usuario sin Email Primario

**Objetivo:** Verificar que el sistema rechaza NFTs de usuarios sin email primario configurado.

**Precondiciones:**
- Usuario con rol ARTIST existe
- Usuario NO tiene email primario (IsPrimary = 1) configurado

**Datos de Entrada:**
```sql
ArtistId: [ID de usuario con rol ARTIST pero sin email primario]
SettingsID: 1
Name: 'NFT Sin Email'
Description: 'Usuario sin email configurado'
ContentType: 'image/png'
FileSizeBytes: 2048000
WidthPx: 1920
HeightPx: 1080
SuggestedPriceETH: 0.4
StatusCode: 'PENDING'
```

**Pasos de Ejecución:**
1. Limpiar tabla audit.EmailOutbox
2. Ejecutar INSERT en nft.NFT con los datos especificados
3. Consultar tabla nft.NFT para verificar que NO se insertó
4. Consultar tabla audit.EmailOutbox

**Resultados Esperados:**
- NFT NO insertado en tabla nft.NFT
- NO se crea registro en admin.CurationReview
- 1 registro en audit.EmailOutbox:
  - RecipientUserId: ID del usuario
  - RecipientEmail: NULL
  - Asunto: "NFT Rechazado - Email Requerido"
  - Cuerpo: Indica que debe configurar un email primario

**Criterios de Aceptación:**
- El NFT no se inserta en la base de datos
- Se genera notificación aunque no haya email para enviar

---

### CP-T1-004: Rechazo por Dimensiones Inválidas (Ancho Excedido)

**Objetivo:** Verificar que el sistema rechaza NFTs con dimensiones fuera de los límites configurados.

**Precondiciones:**
- Usuario con rol ARTIST y email primario configurados
- NFTSettings con MaxWidthPx = 4096

**Datos de Entrada:**
```sql
ArtistId: [ID de usuario válido]
SettingsID: 1
Name: 'Imagen Muy Ancha'
Description: 'Excede el ancho máximo permitido'
ContentType: 'image/png'
FileSizeBytes: 2048000
WidthPx: 5000
HeightPx: 1080
SuggestedPriceETH: 0.5
StatusCode: 'PENDING'
```

**Pasos de Ejecución:**
1. Limpiar tabla audit.EmailOutbox
2. Ejecutar INSERT en nft.NFT con los datos especificados
3. Consultar tabla nft.NFT para verificar que NO se insertó
4. Consultar tabla audit.EmailOutbox para verificar notificación

**Resultados Esperados:**
- NFT NO insertado en tabla nft.NFT
- 1 registro en audit.EmailOutbox:
  - Asunto: "NFT Rechazado - Validación Técnica"
  - Cuerpo: Contiene "Ancho mayor al máximo permitido (4096px)"

**Criterios de Aceptación:**
- El NFT es rechazado antes de insertarse
- El mensaje de error especifica el límite exacto excedido

---

### CP-T1-005: Rechazo por Dimensiones Inválidas (Alto Menor al Mínimo)

**Objetivo:** Verificar que el sistema rechaza NFTs con altura menor al mínimo configurado.

**Precondiciones:**
- Usuario con rol ARTIST y email primario configurados
- NFTSettings con MinHeightPx = 512

**Datos de Entrada:**
```sql
ArtistId: [ID de usuario válido]
SettingsID: 1
Name: 'Imagen Muy Baja'
Description: 'Altura menor al mínimo'
ContentType: 'image/png'
FileSizeBytes: 2048000
WidthPx: 1920
HeightPx: 400
SuggestedPriceETH: 0.5
StatusCode: 'PENDING'
```

**Pasos de Ejecución:**
1. Limpiar tabla audit.EmailOutbox
2. Ejecutar INSERT en nft.NFT con los datos especificados
3. Consultar tabla nft.NFT para verificar que NO se insertó
4. Consultar tabla audit.EmailOutbox

**Resultados Esperados:**
- NFT NO insertado en tabla nft.NFT
- 1 registro en audit.EmailOutbox:
  - Asunto: "NFT Rechazado - Validación Técnica"
  - Cuerpo: Contiene "Alto menor al mínimo permitido (512px)"

**Criterios de Aceptación:**
- Validación de altura funciona correctamente
- Mensaje de error es específico y claro

---

### CP-T1-006: Rechazo por Tamaño de Archivo Excedido

**Objetivo:** Verificar que el sistema rechaza NFTs con tamaño de archivo mayor al límite.

**Precondiciones:**
- Usuario con rol ARTIST y email primario configurados
- NFTSettings con MaxFileSizeBytes = 10485760 (10 MB)

**Datos de Entrada:**
```sql
ArtistId: [ID de usuario válido]
SettingsID: 1
Name: 'Archivo Muy Grande'
Description: 'Excede el tamaño máximo'
ContentType: 'image/png'
FileSizeBytes: 15000000
WidthPx: 1920
HeightPx: 1080
SuggestedPriceETH: 0.5
StatusCode: 'PENDING'
```

**Pasos de Ejecución:**
1. Limpiar tabla audit.EmailOutbox
2. Ejecutar INSERT en nft.NFT con los datos especificados
3. Consultar tabla nft.NFT para verificar que NO se insertó
4. Consultar tabla audit.EmailOutbox

**Resultados Esperados:**
- NFT NO insertado en tabla nft.NFT
- 1 registro en audit.EmailOutbox:
  - Asunto: "NFT Rechazado - Validación Técnica"
  - Cuerpo: Contiene "Archivo muy grande (máximo: 10485760 bytes)"

**Criterios de Aceptación:**
- Validación de tamaño de archivo funciona
- El límite se comunica claramente en bytes

---

### CP-T1-007: Rechazo por Ausencia de Curadores

**Objetivo:** Verificar el comportamiento cuando no hay curadores disponibles en el sistema.

**Precondiciones:**
- Usuario con rol ARTIST y email primario configurados
- NO existen usuarios con rol CURATOR en el sistema

**Datos de Entrada:**
```sql
ArtistId: [ID de usuario válido]
SettingsID: 1
Name: 'NFT Sin Curadores'
Description: 'Sistema sin curadores disponibles'
ContentType: 'image/png'
FileSizeBytes: 2048000
WidthPx: 1920
HeightPx: 1080
SuggestedPriceETH: 0.5
StatusCode: 'PENDING'
```

**Pasos de Ejecución:**
1. Eliminar todos los registros de core.UserRole donde RoleId = 3
2. Limpiar tabla audit.EmailOutbox
3. Ejecutar INSERT en nft.NFT con los datos especificados
4. Consultar tabla nft.NFT
5. Consultar tabla audit.EmailOutbox

**Resultados Esperados:**
- NFT NO insertado en tabla nft.NFT
- 1 registro en audit.EmailOutbox:
  - Asunto: "NFT en Espera - Sin Curadores"
  - Cuerpo: Indica que no hay curadores disponibles y será asignado cuando haya uno

**Criterios de Aceptación:**
- El sistema maneja gracefully la ausencia de curadores
- El artista es notificado de la situación

---

### CP-T1-008: Inserción Múltiple con Distribución Round-Robin

**Objetivo:** Verificar que el algoritmo Round-Robin distribuye equitativamente los NFTs entre curadores.

**Precondiciones:**
- Usuario con rol ARTIST y email primario configurados
- Existen exactamente 2 curadores en el sistema
- Posición Round-Robin inicial conocida

**Datos de Entrada:**
```sql
-- Insertar 4 NFTs en una sola operación
INSERT INTO nft.NFT (ArtistId, SettingsID, Name, ...)
VALUES
  ([ArtistId], 1, 'NFT RR 1', ...),
  ([ArtistId], 1, 'NFT RR 2', ...),
  ([ArtistId], 1, 'NFT RR 3', ...),
  ([ArtistId], 1, 'NFT RR 4', ...);
```

**Pasos de Ejecución:**
1. Verificar cantidad de curadores disponibles
2. Registrar posición Round-Robin inicial (ops.Settings)
3. Ejecutar INSERT múltiple de 4 NFTs
4. Consultar admin.CurationReview para ver asignaciones
5. Verificar nueva posición Round-Robin

**Resultados Esperados:**
- 4 NFTs insertados correctamente
- Con 2 curadores, distribución esperada:
  - Curador 1: 2 NFTs
  - Curador 2: 2 NFTs
- Posición Round-Robin actualizada: (posición_inicial + 4) % 2
- 8 emails generados (4 a artista + 4 a curadores)

**Criterios de Aceptación:**
- Distribución equitativa entre curadores
- Posición Round-Robin se actualiza correctamente
- Cada curador recibe notificación de sus asignaciones

---

### CP-T1-009: Generación de HashCode Único

**Objetivo:** Verificar que cada NFT recibe un HashCode único generado automáticamente.

**Precondiciones:**
- Usuario con rol ARTIST y email primario configurados

**Datos de Entrada:**
```sql
-- Insertar 3 NFTs idénticos en contenido
INSERT INTO nft.NFT (ArtistId, SettingsID, Name, ...)
VALUES
  ([ArtistId], 1, 'NFT Duplicado', ...),
  ([ArtistId], 1, 'NFT Duplicado', ...),
  ([ArtistId], 1, 'NFT Duplicado', ...);
```

**Pasos de Ejecución:**
1. Ejecutar INSERT de 3 NFTs con datos idénticos
2. Consultar tabla nft.NFT para obtener los HashCode generados
3. Verificar longitud y formato de HashCode
4. Verificar unicidad de HashCode

**Resultados Esperados:**
- 3 NFTs insertados correctamente
- Cada NFT tiene un HashCode diferente
- HashCode tiene exactamente 64 caracteres
- HashCode contiene solo caracteres hexadecimales (0-9, A-F)
- HashCode generado con algoritmo SHA2_256

**Criterios de Aceptación:**
- No existen HashCode duplicados
- Formato de HashCode es consistente
- HashCode es generado automáticamente sin intervención del usuario

---

## TRIGGER 2: tr_CurationReview_Decision

### Descripción
Trigger de tipo AFTER UPDATE en la tabla admin.CurationReview que procesa las decisiones de los curadores (APPROVED/REJECTED) y actualiza el estado del NFT correspondiente.

---

### CP-T2-001: Aprobación Exitosa de NFT

**Objetivo:** Verificar que al aprobar un NFT, su estado cambia a APPROVED y se generan las notificaciones correspondientes.

**Precondiciones:**
- NFT existe con StatusCode = 'PENDING'
- Registro en admin.CurationReview con DecisionCode = 'PENDING'
- Curador asignado tiene rol CURATOR

**Datos de Entrada:**
```sql
UPDATE admin.CurationReview
SET DecisionCode = 'APPROVED',
    ReviewedAtUtc = SYSUTCDATETIME(),
    Comment = 'Obra de excelente calidad artística'
WHERE ReviewId = [ID del registro de revisión];
```

**Pasos de Ejecución:**
1. Identificar un NFT en estado PENDING
2. Obtener ReviewId correspondiente
3. Limpiar tabla audit.EmailOutbox
4. Ejecutar UPDATE para aprobar
5. Consultar nft.NFT para verificar cambio de estado
6. Consultar audit.EmailOutbox para verificar notificaciones

**Resultados Esperados:**
- nft.NFT.StatusCode cambia de 'PENDING' a 'APPROVED'
- nft.NFT.ApprovedAtUtc se registra con timestamp actual
- admin.CurationReview.ReviewedAtUtc se actualiza si era NULL
- 2 registros en audit.EmailOutbox:
  - Email al artista: Asunto "NFT Aprobado"
  - Email al curador: Asunto "Decisión Procesada"
- Trigger 3 se activa automáticamente (crear subasta)

**Criterios de Aceptación:**
- Estado del NFT actualizado correctamente
- Timestamps registrados apropiadamente
- Notificaciones contienen información correcta del NFT

---

### CP-T2-002: Rechazo de NFT

**Objetivo:** Verificar que al rechazar un NFT, su estado cambia a REJECTED y NO se crea subasta.

**Precondiciones:**
- NFT existe con StatusCode = 'PENDING'
- Registro en admin.CurationReview con DecisionCode = 'PENDING'

**Datos de Entrada:**
```sql
UPDATE admin.CurationReview
SET DecisionCode = 'REJECTED',
    ReviewedAtUtc = SYSUTCDATETIME(),
    Comment = 'No cumple con los estándares de calidad requeridos'
WHERE ReviewId = [ID del registro de revisión];
```

**Pasos de Ejecución:**
1. Identificar un NFT en estado PENDING
2. Obtener ReviewId correspondiente
3. Limpiar tabla audit.EmailOutbox
4. Ejecutar UPDATE para rechazar
5. Consultar nft.NFT para verificar cambio de estado
6. Consultar auction.Auction para verificar que NO se creó subasta
7. Consultar audit.EmailOutbox

**Resultados Esperados:**
- nft.NFT.StatusCode cambia de 'PENDING' a 'REJECTED'
- nft.NFT.ApprovedAtUtc permanece NULL
- NO se crea registro en auction.Auction
- 2 registros en audit.EmailOutbox:
  - Email al artista: Asunto "NFT No Aprobado"
  - Email al curador: Asunto "Decisión Procesada"
- Trigger 3 NO se activa

**Criterios de Aceptación:**
- Estado del NFT es REJECTED
- No se genera subasta para NFT rechazado
- Artista recibe notificación clara del rechazo

---

### CP-T2-003: Actualización sin Cambio de Decisión

**Objetivo:** Verificar que el trigger NO se ejecuta si DecisionCode no cambia.

**Precondiciones:**
- Registro en admin.CurationReview con DecisionCode = 'PENDING'

**Datos de Entrada:**
```sql
UPDATE admin.CurationReview
SET Comment = 'Comentario actualizado'
WHERE ReviewId = [ID del registro de revisión];
```

**Pasos de Ejecución:**
1. Identificar un registro de revisión
2. Limpiar tabla audit.EmailOutbox
3. Ejecutar UPDATE solo del campo Comment
4. Consultar audit.EmailOutbox

**Resultados Esperados:**
- Campo Comment actualizado correctamente
- NO se generan registros en audit.EmailOutbox
- Estado del NFT permanece sin cambios
- Trigger NO ejecuta su lógica principal

**Criterios de Aceptación:**
- El trigger solo se activa cuando DecisionCode cambia
- Actualizaciones de otros campos no disparan el trigger

---

### CP-T2-004: Cambio de PENDING a APPROVED con ReviewedAtUtc NULL

**Objetivo:** Verificar que el trigger actualiza ReviewedAtUtc automáticamente si es NULL.

**Precondiciones:**
- Registro en admin.CurationReview con DecisionCode = 'PENDING' y ReviewedAtUtc = NULL

**Datos de Entrada:**
```sql
UPDATE admin.CurationReview
SET DecisionCode = 'APPROVED'
WHERE ReviewId = [ID del registro de revisión];
-- Nota: NO se proporciona ReviewedAtUtc
```

**Pasos de Ejecución:**
1. Identificar un registro con ReviewedAtUtc = NULL
2. Ejecutar UPDATE solo de DecisionCode
3. Consultar admin.CurationReview para verificar ReviewedAtUtc

**Resultados Esperados:**
- DecisionCode cambia a 'APPROVED'
- ReviewedAtUtc se actualiza automáticamente con SYSUTCDATETIME()
- ReviewedAtUtc NO es NULL después del UPDATE

**Criterios de Aceptación:**
- El trigger completa el timestamp si no fue proporcionado
- El timestamp refleja el momento de la decisión

---

### CP-T2-005: Múltiples Decisiones Simultáneas

**Objetivo:** Verificar que el trigger procesa correctamente múltiples decisiones en una sola operación.

**Precondiciones:**
- Existen 3 NFTs con StatusCode = 'PENDING'
- Cada uno tiene registro en admin.CurationReview con DecisionCode = 'PENDING'

**Datos de Entrada:**
```sql
UPDATE admin.CurationReview
SET DecisionCode = 'APPROVED',
    ReviewedAtUtc = SYSUTCDATETIME()
WHERE ReviewId IN ([ReviewId1], [ReviewId2], [ReviewId3]);
```

**Pasos de Ejecución:**
1. Identificar 3 registros de revisión pendientes
2. Limpiar tabla audit.EmailOutbox
3. Ejecutar UPDATE múltiple
4. Consultar nft.NFT para verificar estados
5. Consultar audit.EmailOutbox

**Resultados Esperados:**
- 3 NFTs cambian a StatusCode = 'APPROVED'
- 6 registros en audit.EmailOutbox (2 por cada NFT)
- Cada NFT tiene su ApprovedAtUtc registrado
- Trigger 3 se activa para cada NFT aprobado

**Criterios de Aceptación:**
- El trigger procesa correctamente operaciones por lotes
- Todas las notificaciones se generan apropiadamente

---

### CP-T2-006: Intento de Cambio de APPROVED a PENDING

**Objetivo:** Verificar que el trigger solo procesa cambios desde PENDING.

**Precondiciones:**
- Registro en admin.CurationReview con DecisionCode = 'APPROVED'

**Datos de Entrada:**
```sql
UPDATE admin.CurationReview
SET DecisionCode = 'PENDING'
WHERE ReviewId = [ID del registro ya aprobado];
```

**Pasos de Ejecución:**
1. Identificar un registro ya aprobado
2. Limpiar tabla audit.EmailOutbox
3. Ejecutar UPDATE para cambiar a PENDING
4. Consultar nft.NFT para verificar estado
5. Consultar audit.EmailOutbox

**Resultados Esperados:**
- DecisionCode cambia a 'PENDING' en admin.CurationReview
- Estado del NFT NO cambia (permanece APPROVED)
- NO se generan nuevos registros en audit.EmailOutbox
- Trigger NO ejecuta su lógica principal

**Criterios de Aceptación:**
- El trigger solo procesa transiciones válidas (PENDING → APPROVED/REJECTED)
- Estados ya procesados no se revierten

---

## TRIGGER 3: tr_NFT_CreateAuction

### Descripción
Trigger de tipo AFTER UPDATE en la tabla nft.NFT que crea automáticamente una subasta cuando un NFT cambia a estado APPROVED.

---

### CP-T3-001: Creación Exitosa de Subasta

**Objetivo:** Verificar que al aprobar un NFT se crea automáticamente una subasta activa.

**Precondiciones:**
- NFT existe con StatusCode = 'PENDING'
- Registro en auction.AuctionSettings existe
- Usuarios con rol BIDDER existen

**Datos de Entrada:**
```sql
-- Ejecutado por Trigger 2
UPDATE nft.NFT
SET StatusCode = 'APPROVED',
    ApprovedAtUtc = SYSUTCDATETIME()
WHERE NFTId = [ID del NFT];
```

**Pasos de Ejecución:**
1. Aprobar un NFT (mediante Trigger 2)
2. Limpiar tabla audit.EmailOutbox antes de la aprobación
3. Consultar auction.Auction para verificar creación
4. Consultar audit.EmailOutbox para verificar notificaciones

**Resultados Esperados:**
- 1 registro creado en auction.Auction con:
  - NFTId: ID del NFT aprobado
  - StatusCode: 'ACTIVE'
  - StartAtUtc: Timestamp actual (inicio inmediato)
  - EndAtUtc: StartAtUtc + DefaultAuctionHours (72 horas por defecto)
  - StartingPriceETH: SuggestedPriceETH del NFT o BasePriceETH
  - CurrentPriceETH: Igual a StartingPriceETH
  - CurrentLeaderId: NULL (sin ofertas aún)
- Múltiples registros en audit.EmailOutbox:
  - 1 email al artista: Asunto "Subasta Iniciada"
  - N emails a bidders: Asunto "Nueva Subasta Disponible"

**Criterios de Aceptación:**
- Subasta creada con configuración correcta
- Precio inicial basado en sugerencia del artista o configuración
- Todos los bidders son notificados

---

### CP-T3-002: Uso de SuggestedPriceETH como Precio Inicial

**Objetivo:** Verificar que si el NFT tiene SuggestedPriceETH, se usa como precio inicial de la subasta.

**Precondiciones:**
- NFT con SuggestedPriceETH = 0.75
- auction.AuctionSettings con BasePriceETH = 0.01

**Datos de Entrada:**
```sql
-- NFT con precio sugerido
SuggestedPriceETH: 0.75
```

**Pasos de Ejecución:**
1. Aprobar NFT con SuggestedPriceETH = 0.75
2. Consultar auction.Auction creado

**Resultados Esperados:**
- StartingPriceETH = 0.75
- CurrentPriceETH = 0.75
- BasePriceETH NO se utiliza

**Criterios de Aceptación:**
- Precio sugerido por artista tiene prioridad
- Precio se refleja correctamente en la subasta

---

### CP-T3-003: Uso de BasePriceETH cuando SuggestedPriceETH es NULL

**Objetivo:** Verificar que si el NFT no tiene precio sugerido, se usa BasePriceETH de la configuración.

**Precondiciones:**
- NFT con SuggestedPriceETH = NULL
- auction.AuctionSettings con BasePriceETH = 0.01

**Datos de Entrada:**
```sql
-- NFT sin precio sugerido
SuggestedPriceETH: NULL
```

**Pasos de Ejecución:**
1. Aprobar NFT sin SuggestedPriceETH
2. Consultar auction.Auction creado

**Resultados Esperados:**
- StartingPriceETH = 0.01 (BasePriceETH)
- CurrentPriceETH = 0.01

**Criterios de Aceptación:**
- Configuración por defecto se aplica correctamente
- Subasta tiene precio inicial válido

---

### CP-T3-004: Duración de Subasta según Configuración

**Objetivo:** Verificar que la duración de la subasta se calcula según DefaultAuctionHours.

**Precondiciones:**
- auction.AuctionSettings con DefaultAuctionHours = 72

**Datos de Entrada:**
```sql
DefaultAuctionHours: 72
```

**Pasos de Ejecución:**
1. Registrar timestamp antes de aprobar NFT
2. Aprobar NFT
3. Consultar auction.Auction creado
4. Calcular diferencia entre EndAtUtc y StartAtUtc

**Resultados Esperados:**
- Diferencia entre EndAtUtc y StartAtUtc = 72 horas
- StartAtUtc aproximadamente igual al timestamp de aprobación
- EndAtUtc = StartAtUtc + 72 horas

**Criterios de Aceptación:**
- Duración calculada correctamente
- Fechas son consistentes y lógicas

---

### CP-T3-005: Prevención de Subastas Duplicadas

**Objetivo:** Verificar que no se crean subastas duplicadas para el mismo NFT.

**Precondiciones:**
- NFT aprobado con subasta ya creada

**Datos de Entrada:**
```sql
-- Intentar actualizar nuevamente el mismo NFT a APPROVED
UPDATE nft.NFT
SET StatusCode = 'APPROVED'
WHERE NFTId = [ID del NFT ya con subasta];
```

**Pasos de Ejecución:**
1. Aprobar un NFT (crea subasta)
2. Contar subastas para ese NFT
3. Ejecutar UPDATE nuevamente en el mismo NFT
4. Contar subastas nuevamente

**Resultados Esperados:**
- Solo existe 1 subasta para el NFT
- No se crea subasta duplicada
- Trigger verifica existencia antes de insertar

**Criterios de Aceptación:**
- Lógica de prevención de duplicados funciona
- Integridad de datos mantenida

---

### CP-T3-006: Notificación a Múltiples Bidders

**Objetivo:** Verificar que todos los usuarios con rol BIDDER reciben notificación de nueva subasta.

**Precondiciones:**
- Existen 5 usuarios con rol BIDDER
- Todos tienen email primario configurado

**Datos de Entrada:**
```sql
-- 5 usuarios con rol BIDDER activos
```

**Pasos de Ejecución:**
1. Contar usuarios con rol BIDDER
2. Limpiar tabla audit.EmailOutbox
3. Aprobar un NFT
4. Contar emails con asunto "Nueva Subasta Disponible"

**Resultados Esperados:**
- 5 registros en audit.EmailOutbox para bidders
- 1 registro adicional para el artista
- Total: 6 emails generados
- Cada bidder recibe información de la subasta

**Criterios de Aceptación:**
- Todos los bidders son notificados
- Emails contienen información completa de la subasta

---

### CP-T3-007: Contenido de Notificación al Artista

**Objetivo:** Verificar que el email al artista contiene toda la información relevante de la subasta.

**Precondiciones:**
- NFT aprobado genera subasta

**Datos de Entrada:**
```sql
-- NFT con datos conocidos
```

**Pasos de Ejecución:**
1. Aprobar NFT
2. Consultar email enviado al artista
3. Verificar contenido del campo Body

**Resultados Esperados:**
- Email contiene:
  - Nombre del NFT
  - ID de la subasta (AuctionId)
  - Precio inicial en ETH
  - Fecha y hora de inicio (UTC)
  - Fecha y hora de fin (UTC)
- Formato profesional y claro
- Sin errores de sintaxis

**Criterios de Aceptación:**
- Información completa y precisa
- Formato legible y profesional

---

### CP-T3-008: Manejo de Ausencia de Configuración de Subasta

**Objetivo:** Verificar el comportamiento cuando no existe configuración en auction.AuctionSettings.

**Precondiciones:**
- Tabla auction.AuctionSettings vacía o sin registros

**Datos de Entrada:**
```sql
-- Sin registros en auction.AuctionSettings
```

**Pasos de Ejecución:**
1. Eliminar registros de auction.AuctionSettings
2. Aprobar un NFT
3. Consultar auction.Auction creado

**Resultados Esperados:**
- Subasta creada con valores por defecto:
  - BasePriceETH = 0.01
  - DefaultAuctionHours = 72
- SettingsID puede ser NULL
- Subasta funcional con configuración por defecto

**Criterios de Aceptación:**
- Sistema maneja ausencia de configuración
- Valores por defecto son razonables

---

### CP-T3-009: Trigger No se Activa para NFT Rechazado

**Objetivo:** Verificar que el trigger NO crea subasta cuando un NFT es rechazado.

**Precondiciones:**
- NFT con StatusCode = 'PENDING'

**Datos de Entrada:**
```sql
UPDATE nft.NFT
SET StatusCode = 'REJECTED'
WHERE NFTId = [ID del NFT];
```

**Pasos de Ejecución:**
1. Cambiar NFT a REJECTED
2. Consultar auction.Auction para ese NFT

**Resultados Esperados:**
- NO se crea registro en auction.Auction
- Trigger NO se ejecuta
- Solo Trigger 2 procesa el cambio

**Criterios de Aceptación:**
- Trigger solo responde a StatusCode = 'APPROVED'
- NFTs rechazados no generan subastas

---

### CP-T3-010: Timestamp de Inicio Inmediato

**Objetivo:** Verificar que la subasta inicia inmediatamente al ser creada.

**Precondiciones:**
- NFT listo para aprobar

**Datos de Entrada:**
```sql
-- Aprobar NFT
```

**Pasos de Ejecución:**
1. Registrar timestamp actual antes de aprobar
2. Aprobar NFT
3. Consultar StartAtUtc de la subasta creada
4. Comparar timestamps

**Resultados Esperados:**
- StartAtUtc es aproximadamente igual al timestamp de aprobación
- Diferencia menor a 1 segundo
- Subasta está inmediatamente disponible para ofertas

**Criterios de Aceptación:**
- No hay retraso en el inicio de la subasta
- StartAtUtc refleja el momento de creación

---

## MATRIZ DE TRAZABILIDAD

### Cobertura de Requisitos por Trigger

| Trigger | Casos de Prueba | Casos Éxito | Casos Fallo | Total |
|---------|-----------------|-------------|-------------|-------|
| TRIGGER 1 | CP-T1-001 a CP-T1-009 | 3 | 6 | 9 |
| TRIGGER 2 | CP-T2-001 a CP-T2-006 | 3 | 3 | 6 |
| TRIGGER 3 | CP-T3-001 a CP-T3-010 | 7 | 3 | 10 |
| **TOTAL** | **25 casos** | **13** | **12** | **25** |

---

## VALIDACIONES CUBIERTAS

### TRIGGER 1: tr_NFT_InsertFlow

**Validaciones de Éxito:**
- Inserción con datos válidos
- Asignación de curador Round-Robin
- Generación de HashCode único

**Validaciones de Fallo:**
- Usuario sin rol ARTIST
- Usuario sin email primario
- Dimensiones inválidas (ancho, alto)
- Tamaño de archivo excedido
- Ausencia de curadores
- Configuración NFTSettings inexistente

### TRIGGER 2: tr_CurationReview_Decision

**Validaciones de Éxito:**
- Aprobación de NFT
- Actualización de timestamps
- Procesamiento por lotes

**Validaciones de Fallo:**
- Rechazo de NFT
- Cambios sin modificar DecisionCode
- Transiciones inválidas de estado

### TRIGGER 3: tr_NFT_CreateAuction

**Validaciones de Éxito:**
- Creación de subasta activa
- Uso de precio sugerido
- Uso de precio base por defecto
- Cálculo de duración
- Notificaciones múltiples
- Inicio inmediato

**Validaciones de Fallo:**
- Prevención de duplicados
- No activación para NFT rechazado
- Manejo de configuración ausente

---

## DATOS DE PRUEBA REQUERIDOS

### Usuarios

```sql
-- Artistas (mínimo 2)
INSERT INTO core.[User](FullName, CreatedAtUtc) 
VALUES
  ('Carlos Artista', SYSUTCDATETIME()),
  ('María Pintora', SYSUTCDATETIME());

-- Usuario sin rol (para pruebas de validación)
INSERT INTO core.[User](FullName, CreatedAtUtc) 
VALUES ('Juan Sin Rol', SYSUTCDATETIME());

-- Curadores (mínimo 2)
INSERT INTO core.[User](FullName, CreatedAtUtc) 
VALUES
  ('Ana Curadora', SYSUTCDATETIME()),
  ('Pedro Curador', SYSUTCDATETIME());

-- Oferentes (mínimo 3)
INSERT INTO core.[User](FullName, CreatedAtUtc) 
VALUES
  ('Luis Comprador', SYSUTCDATETIME()),
  ('Sofia Coleccionista', SYSUTCDATETIME()),
  ('Diego Inversor', SYSUTCDATETIME());
```

### Roles

```sql
-- Asignar roles
INSERT INTO core.UserRole(UserId, RoleId) 
VALUES
  ([ArtistId1], 2),  -- ARTIST
  ([ArtistId2], 2),  -- ARTIST
  ([CuratorId1], 3), -- CURATOR
  ([CuratorId2], 3), -- CURATOR
  ([BidderId1], 4),  -- BIDDER
  ([BidderId2], 4),  -- BIDDER
  ([BidderId3], 4);  -- BIDDER
```

### Emails

```sql
-- Configurar emails primarios
INSERT INTO core.UserEmail(UserId, Email, IsPrimary, StatusCode)
VALUES
  ([ArtistId1], 'carlos.artista@test.com', 1, 'ACTIVE'),
  ([ArtistId2], 'maria.pintora@test.com', 1, 'ACTIVE'),
  ([CuratorId1], 'ana.curadora@test.com', 1, 'ACTIVE'),
  ([CuratorId2], 'pedro.curador@test.com', 1, 'ACTIVE'),
  ([BidderId1], 'luis.comprador@test.com', 1, 'ACTIVE'),
  ([BidderId2], 'sofia.coleccionista@test.com', 1, 'ACTIVE'),
  ([BidderId3], 'diego.inversor@test.com', 1, 'ACTIVE');
```

### Configuración

```sql
-- NFT Settings
INSERT INTO nft.NFTSettings(
  SettingsID, MaxWidthPx, MinWidthPx, MaxHeightPx, 
  MinHeigntPx, MaxFileSizeBytes, MinFileSizeBytes, CreatedAtUtc
)
VALUES(1, 4096, 512, 4096, 512, 10485760, 10240, SYSUTCDATETIME());

-- Auction Settings
INSERT INTO auction.AuctionSettings(
  SettingsID, CompanyName, BasePriceETH, 
  DefaultAuctionHours, MinBidIncrementPct
)
VALUES(1, 'ArteCryptoAuctions', 0.01, 72, 5);
```

---

## PROCEDIMIENTO DE EJECUCIÓN

### Preparación del Entorno

1. Ejecutar script DDL completo (DDL v6.sql)
2. Ejecutar script de Triggers (Triggers_Fase2_v1.sql)
3. Verificar que todos los triggers están creados
4. Insertar datos de prueba (usuarios, roles, emails, configuración)
5. Limpiar tablas de datos transaccionales

### Ejecución de Casos de Prueba

**Para cada caso de prueba:**

1. Leer precondiciones y verificar que se cumplen
2. Preparar datos de entrada específicos
3. Limpiar tabla audit.EmailOutbox si es necesario
4. Ejecutar la operación descrita en "Pasos de Ejecución"
5. Verificar resultados esperados mediante consultas SQL
6. Documentar resultado: EXITOSO / FALLIDO
7. Si falla, documentar causa y evidencia

### Consultas de Verificación Comunes

```sql
-- Verificar estado de NFT
SELECT NFTId, ArtistId, Name, StatusCode, ApprovedAtUtc
FROM nft.NFT
WHERE NFTId = [ID];

-- Verificar asignación de curador
SELECT cr.ReviewId, cr.NFTId, cr.CuratorId, cr.DecisionCode, u.FullName
FROM admin.CurationReview cr
JOIN core.[User] u ON u.UserId = cr.CuratorId
WHERE cr.NFTId = [ID];

-- Verificar subasta creada
SELECT AuctionId, NFTId, StartingPriceETH, CurrentPriceETH, 
       StatusCode, StartAtUtc, EndAtUtc
FROM auction.Auction
WHERE NFTId = [ID];

-- Verificar emails generados
SELECT RecipientUserId, RecipientEmail, Subject, 
       SUBSTRING(Body, 1, 100) as BodyPreview
FROM audit.EmailOutbox
ORDER BY EmailId DESC;

-- Verificar distribución Round-Robin
SELECT cr.CuratorId, u.FullName, COUNT(*) as NFTsAsignados
FROM admin.CurationReview cr
JOIN core.[User] u ON u.UserId = cr.CuratorId
GROUP BY cr.CuratorId, u.FullName;
```

---

## CRITERIOS DE ACEPTACIÓN GENERALES

### Para considerar las pruebas exitosas:

1. **Cobertura:** Todos los 25 casos de prueba ejecutados
2. **Éxito:** Mínimo 95% de casos pasan (24 de 25)
3. **Validaciones:** Todas las validaciones de fallo funcionan correctamente
4. **Notificaciones:** Emails generados con información correcta
5. **Integridad:** No se crean datos inconsistentes
6. **Performance:** Triggers ejecutan en tiempo razonable (menos de 2 segundos)
7. **Transacciones:** Rollback correcto en caso de error

---

## REGISTRO DE RESULTADOS

### Plantilla de Registro

```
CASO DE PRUEBA: [ID]
FECHA: [YYYY-MM-DD HH:MM:SS]
EJECUTADO POR: [Nombre]
RESULTADO: [EXITOSO / FALLIDO]

EVIDENCIA:
[Capturas de pantalla o resultados de consultas]

OBSERVACIONES:
[Cualquier nota relevante]

DEFECTOS ENCONTRADOS:
[Si aplica, descripción de problemas]
```

---

## MANEJO DE ERRORES

### Errores Esperados vs Inesperados

**Errores Esperados (Validaciones):**
- Usuario sin rol ARTIST
- Dimensiones inválidas
- Ofertas menores al precio actual
- Estos NO son defectos, son validaciones funcionando

**Errores Inesperados (Defectos):**
- Excepciones SQL no manejadas
- Datos inconsistentes después de trigger
- Emails no generados cuando deberían
- Estos SÍ son defectos que deben reportarse

### Procedimiento ante Defectos

1. Documentar el defecto con detalle
2. Incluir datos de entrada exactos
3. Capturar mensaje de error completo
4. Verificar estado de todas las tablas involucradas
5. Intentar reproducir el defecto
6. Reportar al equipo de desarrollo

---

## LIMPIEZA POST-PRUEBAS

### Script de Limpieza

```sql
-- Ejecutar en orden inverso de dependencias
DELETE FROM finance.FundsReservation;
DELETE FROM finance.Ledger;
DELETE FROM auction.Bid;
DELETE FROM auction.Auction;
DELETE FROM admin.CurationReview;
DELETE FROM nft.NFT;
DELETE FROM core.Wallet;
DELETE FROM core.UserEmail;
DELETE FROM core.UserRole;
DELETE FROM audit.EmailOutbox;
DELETE FROM core.[User];

-- Resetear posición Round-Robin
UPDATE ops.Settings
SET SettingValue = '0'
WHERE SettingKey = 'CURATION_RR_POS';

PRINT 'Limpieza completada';
```

---

## CONCLUSIONES

Este documento proporciona una cobertura completa de casos de prueba para los tres triggers principales de la Fase 2. La ejecución sistemática de estos casos garantiza:

- Validación exhaustiva de la lógica de negocio
- Verificación de manejo de errores
- Confirmación de integridad de datos
- Validación de notificaciones
- Prueba de algoritmos (Round-Robin)
- Verificación de flujos completos

La documentación formal y estructurada facilita la ejecución repetible de pruebas y proporciona evidencia clara del funcionamiento del sistema para evaluación académica.

---

**FIN DEL DOCUMENTO**
