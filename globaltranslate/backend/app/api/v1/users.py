from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.core.security import hash_password, verify_password
from app.schemas.auth import MessageResponse
from app.schemas.user import ChangePasswordRequest, UserOut, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
async def get_me(user: CurrentUser):
    return user


@router.patch("/me", response_model=UserOut)
async def update_me(payload: UserUpdate, user: CurrentUser, db: DbSession):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return user


@router.post("/me/change-password", response_model=MessageResponse)
async def change_password(payload: ChangePasswordRequest, user: CurrentUser, db: DbSession):
    if not verify_password(payload.current_password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Senha atual incorreta")
    user.hashed_password = hash_password(payload.new_password)
    await db.commit()
    return MessageResponse(message="Senha alterada com sucesso")


@router.delete("/me", response_model=MessageResponse)
async def delete_me(user: CurrentUser, db: DbSession):
    await db.delete(user)
    await db.commit()
    return MessageResponse(message="Conta eliminada")
