-- Ajusta reglas según tus claves reales
CREATE OR ALTER PROCEDURE ops.sp_Setting_Set
  @SettingKey   SYSNAME,
  @SettingValue NVARCHAR(200)
AS
BEGIN
  SET NOCOUNT ON;

  -- Validaciones por clave (ejemplos):
  IF @SettingKey = 'DefaultAuctionHours'
  BEGIN
    IF TRY_CONVERT(INT, @SettingValue) IS NULL OR TRY_CONVERT(INT, @SettingValue) <= 0
      THROW 50001, 'DefaultAuctionHours debe ser un entero > 0', 1;
  END

  IF @SettingKey = 'BasePriceETH'
  BEGIN
    IF TRY_CONVERT(DECIMAL(38,18), @SettingValue) IS NULL
      THROW 50002, 'BasePriceETH debe ser decimal', 1;
  END

  IF @SettingKey = 'MinBidIncrementPct'
  BEGIN
    IF TRY_CONVERT(DECIMAL(9,4), @SettingValue) IS NULL OR TRY_CONVERT(DECIMAL(9,4), @SettingValue) < 0
      THROW 50003, 'MinBidIncrementPct debe ser decimal >= 0', 1;
  END

  BEGIN TRAN;
    IF EXISTS (SELECT 1 FROM ops.Settings WITH (UPDLOCK, HOLDLOCK) WHERE SettingKey = @SettingKey)
      UPDATE ops.Settings
         SET SettingValue = @SettingValue, UpdatedAtUtc = SYSUTCDATETIME()
       WHERE SettingKey = @SettingKey;
    ELSE
      INSERT INTO ops.Settings(SettingKey, SettingValue)
      VALUES (@SettingKey, @SettingValue);
  COMMIT;
END
GO

-- Ejemplos de uso:
EXEC ops.sp_Setting_Set @SettingKey='DefaultAuctionHours', @SettingValue='76';
EXEC ops.sp_Setting_Set @SettingKey='BasePriceETH',       @SettingValue='0.2';
EXEC ops.sp_Setting_Set @SettingKey='MinBidIncrementPct', @SettingValue='8';
