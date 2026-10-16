from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.shelf import Shelf, ShelfList
from app.services.shelf_builder import build_home_shelves

router = APIRouter(prefix="/shelves", tags=["shelves"])


@router.get("/home", response_model=ShelfList)
async def home_shelves(db: AsyncSession = Depends(get_db)):
    items = await build_home_shelves(db)
    return ShelfList(shelves=[Shelf(**s) for s in items])
