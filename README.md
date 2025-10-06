# 🎨 ArteCryptoAuctions - Sistema de Subastas NFT

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2016+-CC2927?logo=microsoft-sql-server)](https://www.microsoft.com/sql-server)
[![Python](https://img.shields.io/badge/Python-3.8+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-Academic-blue.svg)](LICENSE)

> Sistema de gestión de subastas de NFTs con curación automatizada, desarrollado para el curso de Bases de Datos II - 2025

---

## 📋 Tabla de Contenidos

- [Descripción del Proyecto](#-descripción-del-proyecto)
- [Estructura del Repositorio](#-estructura-del-repositorio)
- [Inicio Rápido](#-inicio-rápido)
- [Características Principales](#-características-principales)
- [Tecnologías Utilizadas](#-tecnologías-utilizadas)
- [Equipo de Desarrollo](#-equipo-de-desarrollo)

---

## 📖 Descripción del Proyecto

**ArteCryptoAuctions** es una plataforma de subastas de NFTs que implementa un flujo completo desde la creación del NFT hasta la subasta final, incluyendo:

- ✅ Validación automática de NFTs
- 👥 Sistema de curación con asignación round-robin
- 💰 Gestión de subastas y ofertas en tiempo real
- 📧 Sistema de notificaciones por email
- 🔐 Control de roles y permisos
- 💳 Gestión de billeteras y transacciones en ETH

---

## 📁 Estructura del Repositorio

```
ProyectoBD2_2025/
│
├── 📂 00 Documentacion/          # Documentación del proyecto
│   ├── 📄 Proyecto BD II - 2025.pdf
│   ├── 📄 Analisis conceptual.docx
│   ├── 📄 ESQUEMAS_Y_TABLAS.md
│   ├── 📄 REFERENCIA_RAPIDA.txt
│   └── 📄 Anexos y análisis técnicos
│
├── 📂 01 Diagramas/               # Diagramas y diseños visuales
│   ├── 🖼️ DigramaER_Mermaid.png
│   ├── 📐 Proyecto.drawio
│   └── 🖼️ Capturas del modelo
│
├── 📂 02 DDLs/                    # Scripts de definición de base de datos
│   ├── 📜 DDL_v6.sql                    (Versión actual - simplificada)
│   ├── 📜 DDL_v6_SSMS.sql               (Versión SSMS completa)
│   ├── 📜 Consulta_Esquemas_Tablas.sql  (Herramienta de consulta)
│   └── 📂 Versiones_Anteriores/
│       └── 📜 DDL_v1 a v5
│
├── 📂 03 Triggers/                # Triggers del sistema
│   ├── 📜 Triggers_Consolidados_v1.sql       (4 triggers principales)
│   ├── 📜 Triggers_Consolidados_v1_FIXED.sql (Versión corregida)
│   └── 📂 Versiones_Anteriores/
│       └── 📜 Versiones de desarrollo
│
├── 📂 04Testing/                  # Scripts de pruebas y validación
│   ├── 📄 README_Testing.md
│   ├── 📄 INICIO_RAPIDO.md
│   ├── 📜 Test_Triggers.sql              (Suite automatizada)
│   ├── 📜 Test_Triggers_Manual.sql       (Pruebas paso a paso)
│   └── 📜 Consultas_Monitoreo.sql        (11 secciones de monitoreo)
│
├── 📂 05 Data Gen/                # Generador de datos de prueba
│   ├── 🐍 datagen_main.py
│   ├── 🐍 datagen.py
│   ├── 📄 README.md
│   └── 📂 Outputs/
│       └── 📜 datos_generados_v1.sql
│
├── 📂 06 Utilidades/              # Scripts auxiliares
│   ├── 📜 ScriptToDeleteThings.sql
│   └── 📜 Modificar_configuracion_plataforma.sql
│
├── 📂 07 BackUps/                 # Respaldos de la base de datos
│   └── 💾 ArteCryptoAuctions.bak
│
└── 📂 Fases - Entregables/        # Entregas por fase del proyecto
    └── 📦 Documentación de entregas
```

---

## 📂 Descripción Detallada de Carpetas

### 📚 00 Documentacion

**Propósito:** Almacena toda la documentación técnica y conceptual del proyecto.

**Contenido:**
- **Proyecto BD II - 2025.pdf**: Especificaciones del proyecto
- **Analisis conceptual.docx**: Análisis del modelo de datos
- **ESQUEMAS_Y_TABLAS.md**: Guía completa de esquemas y tablas
- **REFERENCIA_RAPIDA.txt**: Referencia rápida de tablas por esquema
- **Anexos PDF**: Justificación de tablas y atributos

**Cuándo usar:**
- Para entender el modelo de datos
- Para consultar qué tabla pertenece a qué esquema
- Para revisar la justificación de decisiones de diseño

---

### 🎨 01 Diagramas

**Propósito:** Contiene todos los diagramas visuales del proyecto.

**Contenido:**
- **DigramaER_Mermaid.png**: Diagrama Entidad-Relación
- **Proyecto.drawio**: Archivo editable del diagrama
- **Capturas**: Imágenes del modelo

**Cuándo usar:**
- Para visualizar la estructura de la base de datos
- Para presentaciones del proyecto
- Para editar el modelo ER

---

### 🗄️ 02 DDLs

**Propósito:** Scripts de Data Definition Language para crear la base de datos.

**Contenido:**
- **DDL_v6.sql**: ⭐ Versión actual simplificada y legible
- **DDL_v6_SSMS.sql**: Versión generada por SSMS (completa)
- **Consulta_Esquemas_Tablas.sql**: Herramienta para consultar estructura
- **Versiones_Anteriores/**: Historial de versiones (v1-v5)

**Estructura de la BD:**
- 7 esquemas: `admin`, `auction`, `audit`, `core`, `finance`, `nft`, `ops`
- 16 tablas principales
- Constraints, índices y relaciones completas

**Cuándo usar:**
- Para crear la base de datos desde cero
- Para consultar la estructura actual
- Para revisar cambios entre versiones

**Cómo usar:**
```sql
-- Ejecutar en SQL Server Management Studio
USE master;
GO
-- Ejecutar DDL_v6.sql
```

---

### ⚡ 03 Triggers

**Propósito:** Lógica de negocio implementada mediante triggers.

**Contenido:**
- **Triggers_Consolidados_v1.sql**: ⭐ 4 triggers principales
  1. `tr_NFT_InsertFlow` - Validación e inserción de NFTs
  2. `tr_CurationReview_Decision` - Procesamiento de decisiones
  3. `tr_NFT_CreateAuction` - Creación automática de subastas
  4. `tr_Bid_Validation` - Validación de ofertas

**Características:**
- ✅ Validaciones automáticas
- 📧 Sistema de notificaciones
- 🔄 Asignación round-robin de curadores
- 🛡️ Manejo de errores robusto

**Cuándo usar:**
- Después de crear la base de datos con el DDL
- Para actualizar la lógica de negocio
- Para revisar el flujo de trabajo

**Cómo usar:**
```sql
-- Ejecutar después del DDL
USE ArteCryptoAuctions;
GO
-- Ejecutar Triggers_Consolidados_v1.sql
```

---

### 🧪 04Testing

**Propósito:** Scripts para probar y validar el funcionamiento del sistema.

**Contenido:**
- **README_Testing.md**: Guía completa de testing
- **INICIO_RAPIDO.md**: Guía de inicio rápido
- **Test_Triggers.sql**: Suite automatizada con 15+ casos de prueba
- **Test_Triggers_Manual.sql**: Pruebas interactivas paso a paso
- **Consultas_Monitoreo.sql**: 11 secciones de consultas de monitoreo

**Casos de prueba incluidos:**
- ✅ Inserción de NFTs válidos
- ❌ Validaciones de errores
- 👥 Asignación de curadores
- 💰 Flujo de subastas
- 📧 Sistema de notificaciones

**Cuándo usar:**
- Después de instalar triggers
- Para verificar que todo funciona correctamente
- Para debugging y troubleshooting

**Cómo usar:**
```sql
-- Opción 1: Suite automatizada
USE ArteCryptoAuctions;
GO
-- Ejecutar Test_Triggers.sql

-- Opción 2: Pruebas manuales
-- Ejecutar Test_Triggers_Manual.sql paso a paso
```

---

### 🐍 05 Data Gen

**Propósito:** Generador de datos de prueba en Python.

**Contenido:**
- **datagen_main.py**: Script principal
- **datagen.py**: Módulo de generación
- **README.md**: Documentación del generador
- **Outputs/**: Archivos SQL generados

**Características:**
- 80 nombres y 72 apellidos
- Generación de usuarios, roles, NFTs
- Datos realistas para testing
- Configurable y extensible

**Cuándo usar:**
- Para poblar la base de datos con datos de prueba
- Para generar escenarios de testing
- Para demos y presentaciones

**Cómo usar:**
```bash
cd "05 Data Gen"
python datagen_main.py

# Luego ejecutar el SQL generado en SSMS
```

---

### 🔧 06 Utilidades

**Propósito:** Scripts auxiliares para mantenimiento y configuración.

**Contenido:**
- **ScriptToDeleteThings.sql**: Limpieza de datos
- **Modificar_configuracion_plataforma.sql**: Ajustes de configuración

**Cuándo usar:**
- Para limpiar datos de prueba
- Para modificar configuraciones del sistema
- Para mantenimiento de la base de datos

---

### 💾 07 BackUps

**Propósito:** Respaldos de la base de datos.

**Contenido:**
- **ArteCryptoAuctions.bak**: Backup completo de la BD

**Cuándo usar:**
- Para restaurar la base de datos
- Para migrar entre servidores
- Como punto de recuperación

**Cómo usar:**
```sql
-- Restaurar backup en SSMS
RESTORE DATABASE ArteCryptoAuctions
FROM DISK = 'ruta\ArteCryptoAuctions.bak'
WITH REPLACE;
```

---

### 📦 Fases - Entregables

**Propósito:** Documentación de entregas por fase del proyecto.

**Contenido:**
- Documentos de entrega por fase
- Archivos históricos del proyecto

---

## 🚀 Inicio Rápido

### Prerrequisitos

- SQL Server 2016 o superior
- SQL Server Management Studio (SSMS)
- Python 3.8+ (opcional, para generador de datos)

### Instalación

1. **Crear la base de datos:**
   ```sql
   -- Ejecutar: 02 DDLs/DDL_v6.sql
   ```

2. **Instalar triggers:**
   ```sql
   -- Ejecutar: 03 Triggers/Triggers_Consolidados_v1.sql
   ```

3. **Generar datos de prueba:**
   ```bash
   cd "05 Data Gen"
   python datagen_main.py
   # Ejecutar el SQL generado
   ```

4. **Ejecutar pruebas:**
   ```sql
   -- Ejecutar: 04Testing/Test_Triggers.sql
   ```

### Verificación

```sql
-- Verificar estructura
SELECT * FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA IN ('admin','auction','audit','core','finance','nft','ops');

-- Verificar triggers
SELECT name, type_desc FROM sys.triggers WHERE is_disabled = 0;

-- Verificar datos
SELECT COUNT(*) FROM core.User;
SELECT COUNT(*) FROM nft.NFT;
```

---

## ✨ Características Principales

### 🎯 Flujo Completo NFT → Subasta

```
1. Artista crea NFT
   ↓
2. Validaciones automáticas (dimensiones, tamaño, formato)
   ↓
3. Asignación automática a curador (round-robin)
   ↓
4. Curador revisa y decide (APPROVED/REJECTED)
   ↓
5. Si APPROVED → Subasta se crea automáticamente
   ↓
6. Usuarios pueden ofertar
   ↓
7. Sistema actualiza líder y notifica
```

### 🔐 Sistema de Roles

- **ADMIN**: Administración del sistema
- **ARTIST**: Creación de NFTs
- **CURATOR**: Revisión y aprobación de NFTs
- **BIDDER**: Participación en subastas

### 📧 Sistema de Notificaciones

- Notificación al artista (NFT aceptado/rechazado)
- Notificación al curador (nuevo NFT asignado)
- Notificación de subasta iniciada
- Notificación de nueva oferta
- Notificación de oferta superada

### 💰 Gestión Financiera

- Billeteras en ETH
- Reserva de fondos para ofertas
- Libro mayor de transacciones
- Validación de saldos

---

## 🛠️ Tecnologías Utilizadas

- **Base de Datos**: SQL Server 2016+
- **Lenguaje**: T-SQL
- **Generación de Datos**: Python 3.8+
- **Control de Versiones**: Git
- **Documentación**: Markdown

---

## 📊 Esquemas de la Base de Datos

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

Para más detalles, consulta: `00 Documentacion/ESQUEMAS_Y_TABLAS.md`

---

## 📝 Documentación Adicional

- **Guía de Esquemas**: `00 Documentacion/ESQUEMAS_Y_TABLAS.md`
- **Referencia Rápida**: `00 Documentacion/REFERENCIA_RAPIDA.txt`
- **Guía de Testing**: `04Testing/README_Testing.md`
- **Inicio Rápido Testing**: `04Testing/INICIO_RAPIDO.md`
- **Generador de Datos**: `05 Data Gen/README.md`

---

## 👥 Equipo de Desarrollo

Proyecto desarrollado para el curso de **Bases de Datos II - 2025**

---

## 📄 Licencia

Este proyecto es de uso académico para el curso de Bases de Datos II.

---

## 🔗 Enlaces Útiles

- [Documentación SQL Server](https://docs.microsoft.com/sql/)
- [T-SQL Reference](https://docs.microsoft.com/sql/t-sql/)
- [Triggers en SQL Server](https://docs.microsoft.com/sql/relational-databases/triggers/)

---

## 📞 Soporte

Para preguntas o problemas:
1. Revisa la documentación en `00 Documentacion/`
2. Consulta los scripts de testing en `04Testing/`
3. Revisa los ejemplos en `05 Data Gen/`

---

**Última actualización**: Enero 2025  
**Versión**: 6.0  
**Estado**: ✅ Producción

---

<div align="center">
  <strong>🎨 ArteCryptoAuctions - Sistema de Subastas NFT</strong>
  <br>
  <em>Bases de Datos II - 2025</em>
</div>
