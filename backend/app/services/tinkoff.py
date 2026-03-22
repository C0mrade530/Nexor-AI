"""Tinkoff (T-Bank) integration — transaction import and investment tracking.

Supports:
1. CSV/Excel bank statement import (for personal accounts — no API available)
2. Tinkoff Invest API for investment portfolio tracking
3. Auto-categorization of transactions via AI

Note: T-Bank does not provide Open API for personal (retail) accounts.
The business API (developer.tbank.ru) is for юрлица/ИП only.
For personal finance, we parse exported CSV bank statements.
"""

import csv
import io
import json
import logging
import uuid
from datetime import datetime

import httpx

from app.core.config import settings
from app.services.ai_pipeline import ai_pipeline
from app.services.finance import finance_service

logger = logging.getLogger(__name__)

# Category mapping for Tinkoff MCC codes / descriptions
TINKOFF_CATEGORY_MAP = {
    "Супермаркеты": "groceries",
    "Фастфуд": "food_delivery",
    "Рестораны": "restaurants",
    "Такси": "taxi",
    "Транспорт": "transport",
    "Топливо": "fuel",
    "Одежда и обувь": "shopping",
    "Красота и здоровье": "health",
    "Аптеки": "pharmacy",
    "Развлечения": "entertainment",
    "Образование": "education",
    "Связь и телеком": "subscriptions",
    "Комиссии": "fees",
    "Переводы": "transfers",
    "Наличные": "cash",
    "ЖКХ": "utilities",
    "Маркетплейсы": "shopping",
    "Книги": "education",
    "Спорт": "sport",
    "Путешествия": "travel",
    "Авиабилеты": "travel",
    "Отели": "travel",
}

CATEGORIZATION_PROMPT = """\
Categorize these bank transactions into categories. For each transaction,
determine the most appropriate category from this list:
groceries, food_delivery, restaurants, taxi, transport, fuel, shopping,
health, pharmacy, entertainment, education, subscriptions, fees, transfers,
cash, utilities, sport, travel, rent, salary, freelance, investment, other.

Return a JSON array with the same number of elements, each being just
the category string. Be brief.
"""


class TinkoffService:
    """Handles Tinkoff bank data import and investment tracking."""

    # MARK: - CSV Import

    async def import_csv_statement(
        self,
        user_id: str,
        csv_content: str,
    ) -> dict:
        """Parse Tinkoff CSV bank statement and import transactions.

        Tinkoff CSV format (typical columns):
        Дата операции, Дата платежа, Номер карты, Статус, Сумма операции,
        Валюта операции, Сумма платежа, Валюта платежа, Кэшбэк,
        Категория, MCC, Описание
        """
        transactions = []
        errors = []

        try:
            reader = csv.DictReader(io.StringIO(csv_content), delimiter=";")

            for i, row in enumerate(reader):
                try:
                    tx = self._parse_tinkoff_row(row)
                    if tx:
                        transactions.append(tx)
                except Exception as e:
                    errors.append({"row": i, "error": str(e)})

        except Exception as e:
            # Try comma-separated
            try:
                reader = csv.DictReader(io.StringIO(csv_content), delimiter=",")
                for i, row in enumerate(reader):
                    try:
                        tx = self._parse_tinkoff_row(row)
                        if tx:
                            transactions.append(tx)
                    except Exception as e2:
                        errors.append({"row": i, "error": str(e2)})
            except Exception:
                return {"error": f"Failed to parse CSV: {e}", "imported": 0}

        if not transactions:
            return {"error": "No transactions found in CSV", "imported": 0}

        # Auto-categorize uncategorized transactions
        uncategorized = [t for t in transactions if t.get("category") == "uncategorized"]
        if uncategorized:
            await self._auto_categorize(uncategorized)

        # Import to finance service
        result = await finance_service.add_transactions(user_id, transactions)

        return {
            "imported": result.get("added", 0),
            "total_in_file": len(transactions),
            "errors": len(errors),
            "error_details": errors[:5],
        }

    def _parse_tinkoff_row(self, row: dict) -> dict | None:
        """Parse a single row from Tinkoff CSV statement."""
        # Try different column name variations
        date = (
            row.get("Дата операции")
            or row.get("Дата платежа")
            or row.get("date")
            or ""
        )
        description = (
            row.get("Описание")
            or row.get("description")
            or ""
        )
        amount_str = (
            row.get("Сумма платежа")
            or row.get("Сумма операции")
            or row.get("amount")
            or "0"
        )
        category_ru = row.get("Категория") or row.get("category") or ""
        status = row.get("Статус") or row.get("status") or "OK"

        # Skip failed transactions
        if status and status.upper() not in ("OK", "ВЫПОЛНЕНА", ""):
            return None

        # Parse amount
        amount_str = amount_str.replace(",", ".").replace(" ", "").replace("\xa0", "")
        try:
            amount = float(amount_str)
        except ValueError:
            return None

        # Skip zero amounts
        if amount == 0:
            return None

        # Parse date (DD.MM.YYYY HH:MM:SS or DD.MM.YYYY)
        parsed_date = ""
        for fmt in ("%d.%m.%Y %H:%M:%S", "%d.%m.%Y", "%Y-%m-%d", "%Y-%m-%dT%H:%M:%S"):
            try:
                dt = datetime.strptime(date.strip(), fmt)
                parsed_date = dt.strftime("%Y-%m-%d")
                break
            except ValueError:
                continue

        if not parsed_date:
            parsed_date = datetime.utcnow().strftime("%Y-%m-%d")

        # Map category
        category = TINKOFF_CATEGORY_MAP.get(category_ru, "uncategorized")

        return {
            "date": parsed_date,
            "description": description.strip(),
            "amount": amount,
            "category": category,
            "account": "Tinkoff",
            "original_category": category_ru,
        }

    async def _auto_categorize(self, transactions: list[dict]) -> None:
        """Use AI to categorize uncategorized transactions."""
        descriptions = [t.get("description", "") for t in transactions[:50]]
        try:
            text = await ai_pipeline._call_claude(
                CATEGORIZATION_PROMPT,
                json.dumps(descriptions, ensure_ascii=False),
                max_tokens=1024,
            )
            categories = ai_pipeline._parse_json_response(text)
            if isinstance(categories, list):
                for i, cat in enumerate(categories):
                    if i < len(transactions) and isinstance(cat, str):
                        transactions[i]["category"] = cat
        except Exception as e:
            logger.warning(f"Auto-categorization failed: {e}")

    # MARK: - Tinkoff Invest API

    async def get_invest_portfolio(self, token: str) -> dict:
        """Get investment portfolio from Tinkoff Invest API.

        Token: Tinkoff Invest API token from https://www.tbank.ru/invest/settings/api/
        """
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Get accounts
                accounts_resp = await client.post(
                    "https://invest-public-api.tinkoff.ru/rest/tinkoff.public.invest.api.contract.v1.UsersService/GetAccounts",
                    json={},
                    headers=headers,
                )
                accounts_data = accounts_resp.json()
                accounts = accounts_data.get("accounts", [])

                if not accounts:
                    return {"error": "No investment accounts found"}

                # Get portfolio for first account
                account_id = accounts[0].get("id", "")
                portfolio_resp = await client.post(
                    "https://invest-public-api.tinkoff.ru/rest/tinkoff.public.invest.api.contract.v1.OperationsService/GetPortfolio",
                    json={"accountId": account_id, "currency": "RUB"},
                    headers=headers,
                )
                portfolio = portfolio_resp.json()

                return {
                    "account_id": account_id,
                    "account_name": accounts[0].get("name", ""),
                    "portfolio": portfolio,
                    "accounts_count": len(accounts),
                }

        except Exception as e:
            logger.error(f"Tinkoff Invest API error: {e}")
            return {"error": str(e)}

    async def get_invest_operations(
        self,
        token: str,
        days: int = 30,
    ) -> dict:
        """Get recent investment operations from Tinkoff Invest."""
        from datetime import timedelta

        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        now = datetime.utcnow()
        from_date = (now - timedelta(days=days)).strftime("%Y-%m-%dT00:00:00Z")
        to_date = now.strftime("%Y-%m-%dT23:59:59Z")

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Get accounts first
                accounts_resp = await client.post(
                    "https://invest-public-api.tinkoff.ru/rest/tinkoff.public.invest.api.contract.v1.UsersService/GetAccounts",
                    json={},
                    headers=headers,
                )
                accounts = accounts_resp.json().get("accounts", [])

                if not accounts:
                    return {"error": "No accounts"}

                account_id = accounts[0].get("id", "")

                ops_resp = await client.post(
                    "https://invest-public-api.tinkoff.ru/rest/tinkoff.public.invest.api.contract.v1.OperationsService/GetOperationsByCursor",
                    json={
                        "accountId": account_id,
                        "from": from_date,
                        "to": to_date,
                        "limit": 100,
                        "operationTypes": [],
                        "withoutCommissions": False,
                        "withoutTrades": False,
                        "withoutOvernights": True,
                    },
                    headers=headers,
                )
                operations = ops_resp.json()

                return {
                    "account_id": account_id,
                    "period_days": days,
                    "operations": operations.get("items", []),
                    "total": len(operations.get("items", [])),
                }

        except Exception as e:
            return {"error": str(e)}


tinkoff_service = TinkoffService()
