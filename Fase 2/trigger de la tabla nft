use ArteCryptoAuctions;
go

create or alter trigger nft.tr_NFT_InsertFlow
on nft.NFT
instead of insert
as
begin
  set nocount on;

  -------------------------------------------------------------------
  -- 0) Normalizar batch a una tabla variable
  -------------------------------------------------------------------
  declare @I table(
    NFTId            bigint null,
    ArtistId         bigint not null,
    SettingsID       int    not null,
    CurrentOwnerId   bigint null,
    [Name]           nvarchar(160) not null,
    [Description]    nvarchar(max) null,
    ContentType      nvarchar(100) not null,
    HashCode         char(64) null, -- se ignora el entrante; se autogenera
    FileSizeBytes    bigint null,
    WidthPx          int    null,
    HeightPx         int    null,
    SuggestedPriceETH decimal(38,18) null,
    StatusCode       varchar(30) not null,
    CreatedAtUtc     datetime2(3) not null,
    ApprovedAtUtc    datetime2(3) null
  );

  insert into @I
  select i.NFTId, i.ArtistId, i.SettingsID, i.CurrentOwnerId,
         i.[Name], i.[Description], i.ContentType, i.HashCode,
         i.FileSizeBytes, i.WidthPx, i.HeightPx, i.SuggestedPriceETH,
         i.StatusCode, i.CreatedAtUtc, i.ApprovedAtUtc
  from inserted i;

  -------------------------------------------------------------------
  -- 1) Validaci�n de rol ARTIST (RoleId = 2)
  -------------------------------------------------------------------
  if exists (
      select 1
      from @I x
      left join core.UserRole ur
        on ur.UserId = x.ArtistId and ur.RoleId = 2
      where ur.UserId is null
  )
  begin
    insert into audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
    select distinct x.ArtistId,
           left((select top 1 ue.Email from core.UserEmail ue
                 where ue.UserId=x.ArtistId and ue.IsPrimary=1 order by ue.EmailId), 100),
           left(N'NFT rechazado por el sistema', 200),
           N'Su NFT no pudo ser aceptado: el usuario no posee el rol de Artista (RoleId=2).',
           'PENDING'
    from @I x;
    return; -- no insertamos en nft.NFT
  end;

  -------------------------------------------------------------------
  -- 2) Validaciones t�cnicas contra dbo.NFTSettings(SettingsID)
  -------------------------------------------------------------------
  declare @S table(
    RowId int identity(1,1),
    ArtistId bigint, SettingsID int,
    [Name] nvarchar(160),
    WidthPx int, HeightPx int, FileSizeBytes bigint,
    MinWidthPx int, MaxWidthPx int,
    MinHeigntPx int, MaxHeightPx int,
    MinFileSizeBytes bigint, MaxFileSizeBytes bigint,
    SettingsExists bit
  );

  insert into @S(ArtistId,SettingsID,[Name],WidthPx,HeightPx,FileSizeBytes,
                 MinWidthPx,MaxWidthPx,MinHeigntPx,MaxHeightPx,MinFileSizeBytes,MaxFileSizeBytes,SettingsExists)
  select x.ArtistId, x.SettingsID, x.[Name], x.WidthPx, x.HeightPx, x.FileSizeBytes,
         s.MinWidthPx, s.MaxWidthPx, s.MinHeigntPx, s.MaxHeightPx, s.MinFileSizeBytes, s.MaxFileSizeBytes,
         case when s.SettingsID is null then 0 else 1 end
  from @I x
  left join dbo.NFTSettings s on s.SettingsID = x.SettingsID;

  if exists (
      select 1 from @S
      where SettingsExists=0
         or (MinWidthPx is null and MaxWidthPx is null
             and MinHeigntPx is null and MaxHeightPx is null
             and MinFileSizeBytes is null and MaxFileSizeBytes is null)
  )
  begin
    insert into audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
    select distinct s.ArtistId,
           left((select top 1 ue.Email from core.UserEmail ue
                 where ue.UserId=s.ArtistId and ue.IsPrimary=1 order by ue.EmailId), 100),
           left(N'NFT rechazado por el sistema', 200),
           N'Su NFT no pudo ser aceptado: configuraci�n de NFTSettings inexistente o sin rangos definidos.',
           'PENDING'
    from @S s;
    return;
  end;

  if exists (
      select 1 from @S
      where (MinWidthPx is not null and WidthPx is not null and WidthPx < MinWidthPx)
         or (MaxWidthPx is not null and WidthPx is not null and WidthPx > MaxWidthPx)
         or ((MinWidthPx is not null or MaxWidthPx is not null) and WidthPx is null)
         or (MinHeigntPx is not null and HeightPx is not null and HeightPx < MinHeigntPx)
         or (MaxHeightPx is not null and HeightPx is not null and HeightPx > MaxHeightPx)
         or ((MinHeigntPx is not null or MaxHeightPx is not null) and HeightPx is null)
         or (MinFileSizeBytes is not null and FileSizeBytes is not null and FileSizeBytes < MinFileSizeBytes)
         or (MaxFileSizeBytes is not null and FileSizeBytes is not null and FileSizeBytes > MaxFileSizeBytes)
         or ((MinFileSizeBytes is not null or MaxFileSizeBytes is not null) and FileSizeBytes is null)
  )
  begin
    insert into audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
    select distinct s.ArtistId,
           left((select top 1 ue.Email from core.UserEmail ue
                 where ue.UserId=s.ArtistId and ue.IsPrimary=1 order by ue.EmailId), 100),
           left(N'NFT rechazado por el sistema', 200),
           N'Su NFT no pudo ser aceptado: uno o m�s valores (Width/Height/FileSize) est�n fuera de rango.',
           'PENDING'
    from @S s;
    return;
  end;

  -------------------------------------------------------------------
  -- 3) Verificar email primario del artista (requisito para notificar)
  -------------------------------------------------------------------
  if exists (
      select 1
      from @I x
      left join core.UserEmail ue on ue.UserId=x.ArtistId and ue.IsPrimary=1
      where ue.EmailId is null
  )
  begin
    insert into audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
    select distinct x.ArtistId, null,
           left(N'NFT rechazado por el sistema', 200),
           N'Su NFT no pudo ser aceptado: el artista no posee email primario (IsPrimary=1).',
           'PENDING'
    from @I x;
    return;
  end;

  -------------------------------------------------------------------
  -- 4) ACEPTADO: Insert real en nft.NFT y capturar NFTId generado
  --     * HashCode se AUTOGENERA y se recorta al tama�o real de la columna
  -------------------------------------------------------------------
  declare @NewNFT table(NFTId bigint, ArtistId bigint, [Name] nvarchar(160));

  insert into nft.NFT
    (ArtistId, SettingsID, CurrentOwnerId, [Name], [Description],
     ContentType, HashCode, FileSizeBytes, WidthPx, HeightPx,
     SuggestedPriceETH, StatusCode, CreatedAtUtc, ApprovedAtUtc)
  output inserted.NFTId, inserted.ArtistId, inserted.[Name] into @NewNFT(NFTId,ArtistId,[Name])
  select
         x.ArtistId,
         x.SettingsID,
         x.CurrentOwnerId,
         left(x.[Name],160),
         x.[Description],
         left(x.ContentType,100),
         left(
           convert(varchar(64),
             hashbytes('SHA2_256',
                 cast(newid() as varbinary(16))
               + cast(x.ArtistId as varbinary(8))
               + cast(sysutcdatetime() as varbinary(16))
               + crypt_gen_random(16)
             ), 2
           ),
           col_length('nft.NFT','HashCode')
         ) as HashCode,
         x.FileSizeBytes,
         x.WidthPx,
         x.HeightPx,
         x.SuggestedPriceETH,
         left(x.StatusCode,30),
         x.CreatedAtUtc,
         x.ApprovedAtUtc
  from @I x;

  -- correo al artista (aceptado y enviado a curadur�a)
  insert into audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
  select n.ArtistId,
         left(ue.Email,100),
         left(N'NFT aceptado por el sistema',200),
         N'Tu NFT "' + coalesce(n.[Name],N'(sin nombre)') + N'" ha sido aceptado y enviado a curadur�a.',
         'PENDING'
  from @NewNFT n
  join core.UserEmail ue on ue.UserId=n.ArtistId and ue.IsPrimary=1;

  -------------------------------------------------------------------
  -- 5) Asignaci�n round-robin a Curador (RoleId=3) + CurationReview(PENDING)
  -------------------------------------------------------------------
  if not exists (select 1 from ops.Status where Domain='CURATION_DECISION' and Code='PENDING')
  begin
    insert into ops.Status(Domain,Code,Description)
    values('CURATION_DECISION','PENDING','pendiente de revisi�n');
  end;

  declare @Curators table (Idx int identity(1,1), CuratorId bigint);
  insert into @Curators(CuratorId)
  select distinct ur.UserId
  from core.UserRole ur
  where ur.RoleId = 3
  order by ur.UserId;

  if (select count(*) from @Curators)=0
  begin
    insert into audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
    select n.ArtistId,
           left(ue.Email,100),
           left(N'Curadur�a no disponible',200),
           N'Tu NFT fue aceptado, pero a�n no hay curadores disponibles. Se asignar� en cuanto exista uno.',
           'PENDING'
    from @NewNFT n
    join core.UserEmail ue on ue.UserId=n.ArtistId and ue.IsPrimary=1;
    return;
  end;

  -- puntero round-robin en ops.Settings
  declare @pos int;
  select @pos = try_cast(SettingValue as int)
  from ops.Settings with (updlock, holdlock)
  where SettingKey='CURATION_RR_POS';

  if @pos is null
  begin
    if exists (select 1 from ops.Settings where SettingKey='CURATION_RR_POS')
      update ops.Settings set SettingValue='0', UpdatedAtUtc=sysutcdatetime() where SettingKey='CURATION_RR_POS';
    else
      insert into ops.Settings(SettingKey,SettingValue) values('CURATION_RR_POS','0');
    set @pos = 0;
  end;

  declare @curCount int = (select count(*) from @Curators);

  -- construir asignaciones y materializarlas para reuso
  declare @Assign table(
    NFTId bigint,
    ArtistId bigint,
    [Name] nvarchar(160),
    CurIdx int
  );

  ;with L as (
    select n.NFTId, n.ArtistId, n.[Name],
           row_number() over(order by n.NFTId) as rn
    from @NewNFT n
  ),
  CTEAssign as (
    select L.NFTId, L.ArtistId, L.[Name],
           ((@pos + L.rn - 1) % @curCount) + 1 as CurIdx
    from L
  )
  insert into @Assign(NFTId, ArtistId, [Name], CurIdx)
  select NFTId, ArtistId, [Name], CurIdx
  from CTEAssign;

  -- 1) crear la review PENDING
  insert into admin.CurationReview(NFTId, CuratorId, DecisionCode)
  select A.NFTId, C.CuratorId, 'PENDING'
  from @Assign A
  join @Curators C on C.Idx = A.CurIdx;

  -- 2) email al curador asignado
  insert into audit.EmailOutbox(RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode)
  select C.CuratorId,
         left((select top 1 ue.Email
               from core.UserEmail ue
               where ue.UserId=C.CuratorId and ue.IsPrimary=1
               order by ue.EmailId), 100),
         left(N'Nuevo NFT para revisi�n',200),
         N'Debes revisar el NFT #' + convert(nvarchar(20), A.NFTId) +
         N' del artista #' + convert(nvarchar(20), A.ArtistId) +
         N' ("' + coalesce(A.[Name],N'(sin nombre)') + N'").',
         'PENDING'
  from @Assign A
  join @Curators C on C.Idx = A.CurIdx;

  -- avanzar puntero
  declare @n int = (select count(*) from @NewNFT);
  update ops.Settings
    set SettingValue = convert(nvarchar(50), ((@pos + @n) % @curCount)),
        UpdatedAtUtc = sysutcdatetime()
  where SettingKey='CURATION_RR_POS';
end
go
