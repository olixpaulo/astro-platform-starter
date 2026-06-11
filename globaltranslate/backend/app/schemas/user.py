from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    full_name: str
    role: str
    is_active: bool
    is_verified: bool
    preferred_source_lang: str
    preferred_target_lang: str
    avatar_url: str | None
    created_at: datetime


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, max_length=255)
    preferred_source_lang: str | None = Field(default=None, max_length=10)
    preferred_target_lang: str | None = Field(default=None, max_length=10)
    avatar_url: str | None = Field(default=None, max_length=512)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)
