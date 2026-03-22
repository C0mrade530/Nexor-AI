"""Finance tracker endpoints — transactions, spending analysis, debt strategy."""

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.finance import finance_service

router = APIRouter(prefix="/finance", tags=["finance"])


class TransactionsRequest(BaseModel):
    user_id: str = "demo-user"
    transactions: list[dict]


class FinanceProfileRequest(BaseModel):
    user_id: str = "demo-user"
    monthly_income: float | None = None
    currency: str = "RUB"
    debts: list[dict] | None = None
    savings_goal: dict | None = None
    financial_goals: list[str] | None = None


@router.post("/transactions")
async def add_transactions(req: TransactionsRequest):
    """Add bank transactions (from manual input or bank statement import)."""
    return await finance_service.add_transactions(req.user_id, req.transactions)


@router.get("/transactions")
async def get_transactions(
    user_id: str = "demo-user",
    month: str | None = None,
    category: str | None = None,
    limit: int = 100,
):
    """Get transactions with optional filters."""
    txs = await finance_service.get_transactions(user_id, month=month, category=category, limit=limit)
    return {"transactions": txs, "total": len(txs)}


@router.post("/profile")
async def set_finance_profile(req: FinanceProfileRequest):
    """Set financial profile (income, debts, goals)."""
    profile = req.model_dump(exclude={"user_id"}, exclude_none=True)
    return await finance_service.set_profile(req.user_id, profile)


@router.get("/profile")
async def get_finance_profile(user_id: str = "demo-user"):
    """Get financial profile."""
    return await finance_service.get_profile(user_id)


@router.get("/summary")
async def get_monthly_summary(user_id: str = "demo-user", month: str | None = None):
    """Quick monthly spending summary (no AI, just numbers)."""
    return await finance_service.get_monthly_summary(user_id, month=month)


@router.post("/analyze")
async def analyze_spending(user_id: str = "demo-user", month: str | None = None):
    """AI-powered spending analysis with savings opportunities and debt strategy.

    Uses Claude to analyze transactions and provide actionable financial advice.
    """
    return await finance_service.analyze_spending(user_id, month=month)
