-- Trigger Ingreso NFT --
create or alter trigger IngresaNFT on nft.NFT after insert
as

declare @IDNFT int
declare @HashCode int
declare @RepeatHash bit = 0

select @IDNFT = NFTId, @HashCode = HashCode
from inserted

if exists (
select 1
from nft.NFT
where HashCode = @HashCode
)
	begin
		set @RepeatHash = 1
	end

if @RepeatHash = 0
	begin
		insert into admin.CurationReview (ReviewId,NFTId,StartedAtUtc)
		values (1,@IDNFT,GETDATE())
	end

-- Trigger Ingreso NFT --

-- Trigger Ingreso de Review --
CREATE OR ALTER TRIGGER Review 
ON admin.CurationReview 
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Solo procesar si se actualizó el DecisionCode
    IF UPDATE(DecisionCode)
    BEGIN
        DECLARE @DecisionCode VARCHAR(30)
        DECLARE @NFT BIGINT
        DECLARE @IDCurator BIGINT

        -- Obtener datos de la fila actualizada
        SELECT @DecisionCode = DecisionCode, @NFT = NFTId, @IDCurator = CuratorId
        FROM inserted

        -- Verificar que la decisión no sea PENDING (solo procesar APPROVED/REJECTED)
        IF (@DecisionCode IN ('APPROVED', 'REJECTED'))
        BEGIN
            DECLARE @UserEmail VARCHAR(100)
            DECLARE @UserID BIGINT

            IF (@DecisionCode = 'APPROVED')
            BEGIN
                UPDATE nft.NFT
                SET StatusCode = 'APPROVED', ApprovedAtUtc = GETDATE()
                WHERE NFTId = @NFT

                -- Obtener email del artista
                SELECT @UserEmail = UE.Email, @UserID = U.UserId
                FROM core.[User] U
                INNER JOIN core.UserEmail UE ON U.UserId = UE.UserId
                INNER JOIN nft.NFT NFT ON NFT.ArtistId = U.UserId
                WHERE NFT.NFTId = @NFT

                INSERT INTO audit.EmailOutbox (RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode, CreatedAtUtc)
                VALUES (@UserID, @UserEmail, 'NFT Approved', 'Congratulations, your NFT has been approved for Auctions', 'PENDING', GETDATE())
            END
            ELSE
            BEGIN
                UPDATE nft.NFT
                SET StatusCode = 'REJECTED'
                WHERE NFTId = @NFT

                -- Obtener email del artista
                SELECT @UserEmail = UE.Email, @UserID = U.UserId
                FROM core.[User] U
                INNER JOIN core.UserEmail UE ON U.UserId = UE.UserId
                INNER JOIN nft.NFT NFT ON NFT.ArtistId = U.UserId
                WHERE NFT.NFTId = @NFT

                INSERT INTO audit.EmailOutbox (RecipientUserId, RecipientEmail, [Subject], [Body], StatusCode, CreatedAtUtc)
                VALUES (@UserID, @UserEmail, 'NFT Rejected', 'We are sorry, your NFT has been rejected', 'PENDING', GETDATE())
            END

            -- Actualizar ReviewedAtUtc si aún no está actualizado
            UPDATE admin.CurationReview
            SET ReviewedAtUtc = GETDATE()
            WHERE CuratorId = @IDCurator AND NFTId = @NFT
        END
    END
END
-- Trigger de ingreso de review --

