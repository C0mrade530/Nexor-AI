"""Tinkoff (T-Bank) integration endpoints — CSV import, investment tracking."""

from fastapi import APIRouter, File, UploadFile
from pydantic import BaseModel

from app.services.tinkoff import tinkoff_service

router = APIRouter(prefix="/tinkoff", tags=["tinkoff"])


class TinkoffInvestRequest(BaseModel):
    token: str
    user_id: str = "demo-user"


@router.post("/import/csv")
async def import_csv_statement(
    file: UploadFile = File(...),
    user_id: str = "demo-user",
):
    """Import Tinkoff bank statement CSV.

    How to export from Tinkoff:
    1. Open Tinkoff app or web
    2. Go to account → History → Export
    3. Choose CSV format
    4. Upload the file here
    """
    content = await file.read()

    # Try multiple encodings
    csv_text = None
    for encoding in ("utf-8", "cp1251", "windows-1251", "latin-1"):
        try:
            csv_text = content.decode(encoding)
            break
        except UnicodeDecodeError:
            continue

    if not csv_text:
        return {"error": "Could not decode file. Try saving as UTF-8."}

    result = await tinkoff_service.import_csv_statement(user_id, csv_text)
    return result


@router.post("/import/text")
async def import_text_statement(
    user_id: str = "demo-user",
    csv_content: str = "",
):
    """Import CSV statement as raw text (for testing)."""
    if not csv_content:
        return {"error": "No CSV content provided"}
    return await tinkoff_service.import_csv_statement(user_id, csv_content)


@router.post("/invest/portfolio")
async def get_invest_portfolio(req: TinkoffInvestRequest):
    """Get investment portfolio from Tinkoff Invest.

    Token: get from https://www.tbank.ru/invest/settings/api/
    """
    return await tinkoff_service.get_invest_portfolio(req.token)


@router.post("/invest/operations")
async def get_invest_operations(req: TinkoffInvestRequest, days: int = 30):
    """Get recent investment operations from Tinkoff Invest."""
    return await tinkoff_service.get_invest_operations(req.token, days=days)
