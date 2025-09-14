-- ArteCrypto • Reset / Drop Script (v1)
-- SQL Server — borrar por separado: toda la BD, todas las tablas, o solo los datos
-- Seguro, parametrizable, escalable (soporta nuevos esquemas/tablas sin tocar el script)
-- Fecha: 2025-09-12

/****************************************************************************************
USO RÁPIDO
-----------------------------------------------------------------------------------------
1) Elegir acción en @ACTION:
   - 'DROP_DATABASE'  : elimina la base de datos completa (mata conexiones activas).
   - 'DROP_TABLES'    : elimina todas las tablas del/los esquema(s) objetivo(s); deja la BD.
   - 'DELETE_DATA'    : borra todos los datos de las tablas objetivo(s); conserva estructura.

2) (Opcional) Limitar por esquemas agregándolos a #TARGET_SCHEMAS.
3) @IncludeCatalogs=1 para incluir catálogos (ops.Status, ops.Settings) al DROP/TRUNCATE.
4) @IUnderstand=1 para confirmar ejecución (protección anti-accidente).
-----------------------------------------------------------------------------------------
NOTAS:
- Para DELETE_DATA: se deshabilitan FKs y triggers, se hace DELETE y (opcional) RESEED de IDENTITY.
- Para DROP_TABLES: se dropean primero las FKs (entrantes y salientes) y luego las tablas.
- Todo dinámico a partir de sys.schemas/sys.tables/sys.foreign_keys.
*****************************************************************************************/

DECLARE @ACTION           NVARCHAR(20) = 'DROP_DATABASE';  -- 'DROP_DATABASE' | 'DROP_TABLES' | 'DELETE_DATA'
DECLARE @DATABASE_NAME    SYSNAME      = DB_NAME();      -- Cambia si vas a dropear otra BD
DECLARE @IUnderstand      BIT          = 1;              -- PON EN 1 PARA PERMITIR LA ACCIÓN
DECLARE @IncludeCatalogs  BIT          = 0;              -- Incluir ops.Status/ops.Settings (0=recomendado)
DECLARE @DoReseedIdentity BIT          = 1;              -- Reseed IDENTITY a 0 tras DELETE

PRINT '==== ArteCrypto Reset/Drop Script ====';
PRINT 'DB: ' + @DATABASE_NAME + ' | Action: ' + @ACTION + ' |1 IncludeCatalogs=' + CAST(@IncludeCatalogs AS NVARCHAR(10));

IF @IUnderstand <> 1
BEGIN
  RAISERROR('Protección activada. Establece @IUnderstand=1 para continuar.', 16, 1);
  RETURN;
END

/* ----------------------------------------------
   SCOPE: esquemas objetivo (vacío = todos los user schemas)
---------------------------------------------- */
IF OBJECT_ID('tempdb..#TARGET_SCHEMAS') IS NOT NULL DROP TABLE #TARGET_SCHEMAS;
CREATE TABLE #TARGET_SCHEMAS(name SYSNAME PRIMARY KEY);
-- INSERT INTO #TARGET_SCHEMAS(name) VALUES ('core'),('nft'),('auction'),('finance'),('admin'),('ops'),('audit');
-- Si no insertas nada, se aplicará a TODOS los esquemas de usuario.

/* ----------------------------------------------
   PROTEGIDOS (por defecto no se borran en DELETE/DROP a menos que @IncludeCatalogs=1)
---------------------------------------------- */
IF OBJECT_ID('tempdb..#PROTECTED') IS NOT NULL DROP TABLE #PROTECTED;
CREATE TABLE #PROTECTED(schema_name SYSNAME, table_name SYSNAME, PRIMARY KEY(schema_name, table_name));
INSERT INTO #PROTECTED(schema_name, table_name)
VALUES ('ops','Status'), ('ops','Settings');

/* ----------------------------------------------
   Resolver tablas objetivo  (VERSIÓN CORREGIDA)
---------------------------------------------- */
IF OBJECT_ID('tempdb..#TABLAS') IS NOT NULL DROP TABLE #TABLAS;

SELECT
  s.name AS schema_name,
  t.name AS table_name,
  t.object_id,
  t.create_date,
  t.modify_date
INTO #TABLAS
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND (
      NOT EXISTS (SELECT 1 FROM #TARGET_SCHEMAS)
      OR s.name IN (SELECT name FROM #TARGET_SCHEMAS)
  )
  AND (
      @IncludeCatalogs = 1
      OR NOT EXISTS (
          SELECT 1
          FROM #PROTECTED p
          WHERE p.schema_name = s.name
            AND p.table_name = t.name
      )
  );

-- Para compatibilidad con versiones de SQL Server que no admiten tuplas en NOT IN
IF @@ROWCOUNT >= 0
BEGIN
  DELETE t
  FROM #TABLAS t
  WHERE @IncludeCatalogs = 0
    AND EXISTS (
      SELECT 1
      FROM #PROTECTED p
      WHERE p.schema_name = t.schema_name AND p.table_name = t.table_name
    );
END

/* =====================================================================
   ACCIÓN: DROP_DATABASE
===================================================================== */
IF @ACTION = 'DROP_DATABASE'
BEGIN
  IF DB_NAME() = @DATABASE_NAME
  BEGIN
    -- Cambiar contexto a master si es la BD actual
    PRINT 'Cambiando contexto a master...';
    EXEC ('USE master;');
  END

  DECLARE @sql NVARCHAR(MAX) = N'';
  IF EXISTS (SELECT 1 FROM sys.databases WHERE name=@DATABASE_NAME)
  BEGIN
    SET @sql = N'ALTER DATABASE ' + QUOTENAME(@DATABASE_NAME) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;'
             + N' DROP DATABASE ' + QUOTENAME(@DATABASE_NAME) + N';';
    PRINT '>> Eliminando base de datos ' + @DATABASE_NAME + ' ...';
    EXEC sp_executesql @sql;
    PRINT 'OK: Base de datos eliminada.';
  END
  ELSE
    PRINT 'La base de datos no existe: ' + @DATABASE_NAME;
  RETURN;
END

/* =====================================================================
   ACCIÓN: DROP_TABLES (dropear FKs y luego tablas)
===================================================================== */
IF @ACTION = 'DROP_TABLES'
BEGIN
  SET @sql = N'';

  -- 1) Drop FKs que apunten a o salgan de tablas objetivo
  ;WITH fk AS (
    SELECT fk.name AS fk_name,
           QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + '.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) AS parent_table,
           QUOTENAME(OBJECT_SCHEMA_NAME(fk.referenced_object_id)) + '.' + QUOTENAME(OBJECT_NAME(fk.referenced_object_id)) AS ref_table
    FROM sys.foreign_keys fk
    WHERE fk.is_ms_shipped = 0
      AND (
          fk.parent_object_id IN (SELECT object_id FROM #TABLAS)
       OR fk.referenced_object_id IN (SELECT object_id FROM #TABLAS)
      )
  )
  SELECT @sql = STRING_AGG('ALTER TABLE ' + parent_table + ' DROP CONSTRAINT ' + QUOTENAME(fk_name) + ';', CHAR(10))
  FROM fk;

  IF @sql IS NOT NULL AND LEN(@sql) > 0
  BEGIN
    PRINT '>> Eliminando claves foráneas...';
    EXEC sp_executesql @sql;
  END

  -- 2) Drop tablas (todas las objetivo)
  SET @sql = N'';
  SELECT @sql = STRING_AGG('DROP TABLE ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ';', CHAR(10))
  FROM #TABLAS;

  IF @sql IS NOT NULL AND LEN(@sql) > 0
  BEGIN
    PRINT '>> Eliminando tablas...';
    EXEC sp_executesql @sql;
  END

  PRINT 'OK: Tablas eliminadas.';
  RETURN;
END

/* =====================================================================
   ACCIÓN: DELETE_DATA (deshabilitar FKs/triggers, borrar, reseed, re‑habilitar)
===================================================================== */
IF @ACTION = 'DELETE_DATA'
BEGIN

  -- 0) Deshabilitar triggers y constraints
  PRINT '>> Deshabilitando constraints y triggers...';
  SELECT @sql = STRING_AGG('ALTER TABLE ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ' NOCHECK CONSTRAINT ALL;', CHAR(10))
  FROM #TABLAS;
  IF @sql IS NOT NULL EXEC sp_executesql @sql;

  SELECT @sql = STRING_AGG('DISABLE TRIGGER ALL ON ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ';', CHAR(10))
  FROM #TABLAS;
  IF @sql IS NOT NULL EXEC sp_executesql @sql;

  -- 1) Borrado de datos (DELETE) y reseed de identidades
  PRINT '>> Borrando datos...';
  SELECT @sql = STRING_AGG('DELETE FROM ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ';', CHAR(10))
  FROM #TABLAS;
  IF @sql IS NOT NULL EXEC sp_executesql @sql;

  IF @DoReseedIdentity = 1
  BEGIN
    PRINT '>> Reseed de IDENTITY a 0...';
    DECLARE @reseeds NVARCHAR(MAX) = N'';
    SELECT @reseeds = @reseeds +
      CASE WHEN c.is_identity = 1
           THEN 'BEGIN TRY DBCC CHECKIDENT(''' + QUOTENAME(t.schema_name) + '.' + QUOTENAME(t.table_name) + ''', RESEED, 0) WITH NO_INFOMSGS; END TRY BEGIN CATCH PRINT ''(WARN) Reseed falló en ' + QUOTENAME(t.schema_name) + '.' + QUOTENAME(t.table_name) + '''; END CATCH;' + CHAR(10)
           ELSE '' END
    FROM #TABLAS t
    JOIN sys.columns c ON c.object_id = t.object_id;
    IF LEN(@reseeds) > 0 EXEC sp_executesql @reseeds;
  END

  -- 2) Re‑habilitar triggers y constraints con verificación
  PRINT '>> Re‑habilitando triggers y constraints (WITH CHECK)...';
  SELECT @sql = STRING_AGG('ENABLE TRIGGER ALL ON ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ';', CHAR(10))
  FROM #TABLAS;
  IF @sql IS NOT NULL EXEC sp_executesql @sql;

  SELECT @sql = STRING_AGG('ALTER TABLE ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ' WITH CHECK CHECK CONSTRAINT ALL;', CHAR(10))
  FROM #TABLAS;
  IF @sql IS NOT NULL EXEC sp_executesql @sql;

  PRINT 'OK: Datos eliminados.';
  RETURN;
END

-- Acción desconocida
RAISERROR('Acción no reconocida. Usa DROP_DATABASE | DROP_TABLES | DELETE_DATA', 16, 1);
