"""Finance tracker — bank transaction analysis, spending advice, debt strategy.

Receives transaction data (manual input or bank statement import) and uses
Claude to provide spending insights, savings recommendations, and debt payoff strategies.
"""

import json
import logging
import uuid
from datetime import datetime

from app.core.config import settings
from app.services.ai_pipeline import ai_pipeline

logger = logging.getLogger(__name__)

# In-memory finance stores
transactions: dict[str, list[dict]] = {}  # {user_id: [transaction, ...]}
finance_profiles: dict[str, dict] = {}    # {user_id: {income, debts, goals}}


FINANCE_ANALYSIS_PROMPT = """\
You are a world-class personal finance advisor for Nexor. You combine the wisdom of:
- Dave Ramsey (debt snowball, baby steps, gazelle intensity)
- Ramit Sethi (conscious spending, big wins, automation)
- Morgan Housel (Psychology of Money — patience, compounding, enough)
- Ray Dalio (principles-based investing, diversification)

Given the user's financial data (transactions, income, debts, goals), provide a JSON analysis:

1. spending_summary — {
     total_spent: number,
     by_category: [{category, amount, percent_of_total, vs_last_month}],
     top_3_expenses: [{description, amount, category, date}]
   }
2. insights — [{observation, impact, recommendation, urgency(1-5)}]
   - Identify wasteful spending patterns
   - Find subscriptions that could be cancelled
   - Spot unusual transactions
3. savings_opportunities — [{area, current_spending, suggested_saving, monthly_savings, annual_impact}]
4. debt_strategy — {
     total_debt: number,
     recommended_method: "snowball" | "avalanche",
     payoff_plan: [{debt_name, balance, rate, min_payment, recommended_payment, payoff_months}],
     total_interest_saved: number,
     debt_free_date: string
   }
5. budget_recommendation — {
     income: number,
     needs_50: {amount, categories: [{name, budget}]},
     wants_30: {amount, categories: [{name, budget}]},
     savings_20: {amount, allocation: [{name, amount}]}
   }
6. action_items — [{action, priority, potential_savings, deadline}]
7. financial_health_score — 1-100 with reasoning
8. one_thing — the single most impactful change to make this month

Be specific with numbers. Reference actual transactions. Write in the user's language.
Be honest but encouraging — every financial situation can improve.
"""


class FinanceService:
    """Manages financial data and AI-powered money insights."""

    async def add_transactions(
        self,
        user_id: str,
        new_transactions: list[dict],
    ) -> dict:
        """Add bank transactions.

        Each transaction:
        {
            "date": "2026-03-22",
            "description": "Яндекс.Еда",
            "amount": -1250.00,  # negative = expense, positive = income
            "category": "food_delivery",
            "account": "Tinkoff"
        }
        """
        transactions.setdefault(user_id, [])

        added = []
        for tx in new_transactions:
            record = {
                "id": str(uuid.uuid4()),
                "user_id": user_id,
                "date": tx.get("date", datetime.utcnow().strftime("%Y-%m-%d")),
                "description": tx.get("description", ""),
                "amount": tx.get("amount", 0),
                "category": tx.get("category", "uncategorized"),
                "account": tx.get("account", ""),
                "created_at": datetime.utcnow().isoformat(),
            }
            transactions[user_id].append(record)
            added.append(record)

        return {"added": len(added), "total": len(transactions[user_id])}

    async def get_transactions(
        self,
        user_id: str,
        month: str | None = None,
        category: str | None = None,
        limit: int = 100,
    ) -> list[dict]:
        """Get transactions with optional filters."""
        txs = transactions.get(user_id, [])

        if month:
            txs = [t for t in txs if t["date"].startswith(month)]
        if category:
            txs = [t for t in txs if t["category"] == category]

        txs = sorted(txs, key=lambda t: t["date"], reverse=True)
        return txs[:limit]

    async def set_profile(self, user_id: str, profile: dict) -> dict:
        """Set financial profile.

        {
            "monthly_income": 350000,
            "currency": "RUB",
            "debts": [
                {"name": "Ипотека", "balance": 4500000, "rate": 12.5, "min_payment": 45000},
                {"name": "Кредитка Тинькофф", "balance": 120000, "rate": 29.9, "min_payment": 6000}
            ],
            "savings_goal": {"target": 1000000, "current": 250000, "purpose": "Подушка безопасности"},
            "financial_goals": ["Закрыть кредитку за 6 мес", "Накопить на отпуск 200к"]
        }
        """
        finance_profiles[user_id] = {
            "user_id": user_id,
            "updated_at": datetime.utcnow().isoformat(),
            **profile,
        }
        return finance_profiles[user_id]

    async def get_profile(self, user_id: str) -> dict:
        return finance_profiles.get(user_id, {})

    async def analyze_spending(self, user_id: str, month: str | None = None) -> dict:
        """Run AI analysis on spending patterns.

        Returns structured spending insights, savings opportunities, and debt strategy.
        """
        if not month:
            month = datetime.utcnow().strftime("%Y-%m")

        txs = await self.get_transactions(user_id, month=month, limit=500)
        profile = await self.get_profile(user_id)

        if not txs:
            return {"error": "No transactions found for this period"}

        # Build context for Claude
        context = {
            "month": month,
            "transactions": txs,
            "profile": profile,
            "total_income": sum(t["amount"] for t in txs if t["amount"] > 0),
            "total_expenses": sum(abs(t["amount"]) for t in txs if t["amount"] < 0),
            "transaction_count": len(txs),
        }

        context_text = json.dumps(context, ensure_ascii=False, indent=2)
        text = await ai_pipeline._call_claude(
            FINANCE_ANALYSIS_PROMPT,
            f"Financial data:\n{context_text}",
            max_tokens=8192,
        )
        result = ai_pipeline._parse_json_response(text)

        if isinstance(result, dict):
            result["month"] = month
            result["analyzed_at"] = datetime.utcnow().isoformat()

        return result

    async def get_monthly_summary(self, user_id: str, month: str | None = None) -> dict:
        """Quick monthly spending summary without AI analysis."""
        if not month:
            month = datetime.utcnow().strftime("%Y-%m")

        txs = await self.get_transactions(user_id, month=month, limit=1000)

        income = sum(t["amount"] for t in txs if t["amount"] > 0)
        expenses = sum(abs(t["amount"]) for t in txs if t["amount"] < 0)

        # Group by category
        by_category: dict[str, float] = {}
        for t in txs:
            if t["amount"] < 0:
                cat = t["category"]
                by_category[cat] = by_category.get(cat, 0) + abs(t["amount"])

        categories = sorted(
            [{"category": k, "amount": v} for k, v in by_category.items()],
            key=lambda x: x["amount"],
            reverse=True,
        )

        return {
            "month": month,
            "income": income,
            "expenses": expenses,
            "net": income - expenses,
            "savings_rate": round((income - expenses) / income * 100, 1) if income > 0 else 0,
            "by_category": categories,
            "transaction_count": len(txs),
        }


finance_service = FinanceService()
