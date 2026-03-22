"""API tests for LifeOS backend."""

from datetime import datetime

import pytest
from fastapi.testclient import TestClient

from app.core import store
from app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_store():
    """Clear in-memory store between tests."""
    from app.services import health, finance, notifications, zapier
    store.sessions.clear()
    store.chunks.clear()
    store.events.clear()
    store.daily_summaries.clear()
    store.mentor_feedback.clear()
    store.calendar_tokens.clear()
    health.health_data.clear()
    health.health_goals.clear()
    finance.transactions.clear()
    finance.finance_profiles.clear()
    notifications.device_tokens.clear()
    notifications.notification_preferences.clear()
    notifications.notification_history.clear()
    notifications.scheduled_notifications.clear()
    zapier.webhooks.clear()
    zapier.webhook_log.clear()
    yield
    store.sessions.clear()
    store.chunks.clear()
    store.events.clear()
    store.daily_summaries.clear()
    store.mentor_feedback.clear()
    store.calendar_tokens.clear()


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "LifeOS" in response.json()["name"]


def test_create_session():
    response = client.post(
        "/api/v1/audio/sessions",
        json={
            "source": "iphone_app",
            "consent_mode": "private",
            "started_at": datetime.utcnow().isoformat(),
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "recording"
    assert data["source"] == "iphone_app"
    assert "id" in data
    return data["id"]


def test_list_sessions():
    # Create a session first
    test_create_session()
    response = client.get("/api/v1/audio/sessions")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 1


def test_list_events_empty():
    response = client.get("/api/v1/events")
    assert response.status_code == 200
    data = response.json()
    assert data["events"] == []
    assert data["total"] == 0


def test_list_events_with_data():
    # Seed an event
    store.events["test-1"] = {
        "id": "test-1",
        "event_type": "idea",
        "title": "Test idea",
        "summary": "A test idea",
        "started_at": "2024-01-01T10:00:00",
        "tags": ["test"],
    }
    response = client.get("/api/v1/events")
    assert response.status_code == 200
    assert response.json()["total"] == 1


def test_filter_events_by_type():
    store.events["m1"] = {
        "id": "m1", "event_type": "meeting", "title": "Meeting",
        "summary": "A meeting", "started_at": "2024-01-01T10:00:00",
    }
    store.events["i1"] = {
        "id": "i1", "event_type": "idea", "title": "Idea",
        "summary": "An idea", "started_at": "2024-01-01T11:00:00",
    }
    response = client.get("/api/v1/events?event_type=meeting")
    assert response.json()["total"] == 1
    assert response.json()["events"][0]["event_type"] == "meeting"


def test_list_ideas():
    store.events["i1"] = {
        "id": "i1", "event_type": "idea", "title": "Idea",
        "summary": "An idea", "started_at": "2024-01-01T10:00:00",
    }
    response = client.get("/api/v1/events/ideas")
    assert response.status_code == 200
    assert response.json()["total"] == 1


def test_list_meetings():
    store.events["m1"] = {
        "id": "m1", "event_type": "meeting", "title": "Meeting",
        "summary": "A meeting", "started_at": "2024-01-01T10:00:00",
    }
    response = client.get("/api/v1/events/meetings")
    assert response.status_code == 200
    assert response.json()["total"] == 1


def test_list_tasks():
    store.events["t1"] = {
        "id": "t1", "event_type": "task", "title": "Task",
        "summary": "A task", "started_at": "2024-01-01T10:00:00",
        "action_items": [{"task": "Do something", "assignee": "me"}],
    }
    response = client.get("/api/v1/events/tasks")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert data["action_items"][0]["task"] == "Do something"


def test_get_event():
    store.events["e1"] = {
        "id": "e1", "event_type": "idea", "title": "Test",
        "summary": "Test event", "started_at": "2024-01-01T10:00:00",
    }
    response = client.get("/api/v1/events/e1")
    assert response.status_code == 200
    assert response.json()["id"] == "e1"


def test_get_event_not_found():
    response = client.get("/api/v1/events/nonexistent")
    assert response.status_code == 404


def test_delete_event():
    store.events["del1"] = {
        "id": "del1", "event_type": "idea", "title": "Delete me",
        "summary": "...", "started_at": "2024-01-01T10:00:00",
    }
    response = client.delete("/api/v1/events/del1")
    assert response.status_code == 200
    assert "del1" not in store.events


def test_delete_session():
    sid = test_create_session()
    response = client.delete(f"/api/v1/audio/sessions/{sid}")
    assert response.status_code == 200
    assert sid not in store.sessions


def test_daily_summaries_empty():
    response = client.get("/api/v1/events/summaries/daily")
    assert response.status_code == 200
    assert response.json() == []


def test_search_requires_query():
    response = client.get("/api/v1/search")
    assert response.status_code == 422


def test_list_commitments():
    store.events["c1"] = {
        "id": "c1", "event_type": "meeting", "title": "Meeting",
        "summary": "A meeting", "started_at": "2024-01-01T10:00:00",
        "commitments": [{"promise": "Send report", "to_whom": "Alice", "deadline": "Friday"}],
    }
    response = client.get("/api/v1/events/commitments")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert data["commitments"][0]["promise"] == "Send report"


def test_list_follow_ups():
    store.events["f1"] = {
        "id": "f1", "event_type": "meeting", "title": "Call",
        "summary": "A call", "started_at": "2024-01-01T10:00:00",
        "follow_ups": [{"action": "Check status", "whom": "Bob", "by_when": "Monday"}],
    }
    response = client.get("/api/v1/events/follow-ups")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert data["follow_ups"][0]["action"] == "Check status"


def test_calendar_status():
    response = client.get("/api/v1/calendar/status")
    assert response.status_code == 200
    assert response.json()["connected"] is False


def test_calendar_connect():
    response = client.post(
        "/api/v1/calendar/connect",
        json={"access_token": "test-token", "user_id": "demo-user"},
    )
    assert response.status_code == 200
    assert response.json()["status"] == "connected"

    status = client.get("/api/v1/calendar/status")
    assert status.json()["connected"] is True


def test_calendar_disconnect():
    store.calendar_tokens["demo-user"] = {"access_token": "test"}
    response = client.delete("/api/v1/calendar/disconnect")
    assert response.status_code == 200

    status = client.get("/api/v1/calendar/status")
    assert status.json()["connected"] is False


def test_mentor_not_found():
    response = client.get("/api/v1/process/mentor/2024-01-01")
    assert response.status_code == 404


def test_plaud_status_disconnected():
    response = client.get("/api/v1/plaud/status")
    assert response.status_code == 200
    assert response.json()["connected"] is False


def test_plaud_recordings_not_connected():
    response = client.get("/api/v1/plaud/recordings")
    assert response.status_code == 401


def test_plaud_disconnect():
    store.calendar_tokens["demo-user"] = {"plaud_token": "test", "plaud_region": "us"}
    response = client.delete("/api/v1/plaud/disconnect")
    assert response.status_code == 200

    status = client.get("/api/v1/plaud/status")
    assert status.json()["connected"] is False


def test_meeting_analysis_not_found():
    response = client.get("/api/v1/events/meetings/nonexistent/analysis")
    assert response.status_code == 404


def test_meeting_analysis_not_meeting():
    store.events["idea1"] = {
        "id": "idea1", "event_type": "idea", "title": "Idea",
        "summary": "An idea", "started_at": "2024-01-01T10:00:00",
    }
    response = client.get("/api/v1/events/meetings/idea1/analysis")
    assert response.status_code == 400


# ==================== HEALTH ====================

def test_health_today_empty():
    response = client.get("/api/v1/health/today")
    assert response.status_code == 200
    assert response.json()["available"] is False


def test_health_sync_and_today():
    response = client.post("/api/v1/health/sync", json={
        "date": "2026-03-22",
        "sleep": {"total_hours": 7.5, "quality_score": 82},
        "activity": {"steps": 9200, "active_minutes": 45, "active_calories": 380},
        "heart": {"resting_hr": 60, "hrv": 48},
        "workouts": [{"type": "running", "duration_minutes": 30, "calories": 280}],
    })
    assert response.status_code == 200
    assert response.json()["status"] == "synced"

    today = client.get("/api/v1/health/today")
    data = today.json()
    assert data["available"] is True
    assert data["steps"] == 9200


def test_health_goals():
    response = client.post("/api/v1/health/goals", json={
        "sleep_hours": 8,
        "steps": 10000,
        "active_minutes": 60,
    })
    assert response.status_code == 200

    goals = client.get("/api/v1/health/goals")
    assert goals.json()["sleep_hours"] == 8


def test_health_trends_empty():
    response = client.get("/api/v1/health/trends")
    assert response.status_code == 200
    assert response.json()["available"] is False


def test_health_progress_no_data():
    response = client.get("/api/v1/health/progress")
    assert response.status_code == 200
    assert response.json()["available"] is False


# ==================== FINANCE ====================

def test_finance_add_transactions():
    response = client.post("/api/v1/finance/transactions", json={
        "transactions": [
            {"date": "2026-03-22", "description": "Яндекс.Еда", "amount": -1250, "category": "food_delivery"},
            {"date": "2026-03-22", "description": "Зарплата", "amount": 350000, "category": "salary"},
        ]
    })
    assert response.status_code == 200
    assert response.json()["added"] == 2


def test_finance_get_transactions():
    from app.services.finance import transactions
    transactions["demo-user"] = [
        {"id": "t1", "date": "2026-03-22", "description": "Test", "amount": -500, "category": "food", "account": ""},
    ]
    response = client.get("/api/v1/finance/transactions")
    assert response.status_code == 200
    assert response.json()["total"] == 1


def test_finance_summary():
    from app.services.finance import transactions
    transactions["demo-user"] = [
        {"id": "t1", "date": "2026-03-22", "description": "Salary", "amount": 100000, "category": "salary", "account": ""},
        {"id": "t2", "date": "2026-03-22", "description": "Food", "amount": -5000, "category": "food", "account": ""},
        {"id": "t3", "date": "2026-03-22", "description": "Taxi", "amount": -1000, "category": "transport", "account": ""},
    ]
    response = client.get("/api/v1/finance/summary?month=2026-03")
    assert response.status_code == 200
    data = response.json()
    assert data["income"] == 100000
    assert data["expenses"] == 6000


def test_finance_profile():
    response = client.post("/api/v1/finance/profile", json={
        "monthly_income": 350000,
        "currency": "RUB",
        "debts": [{"name": "Кредитка", "balance": 120000, "rate": 29.9}],
    })
    assert response.status_code == 200

    profile = client.get("/api/v1/finance/profile")
    assert profile.json()["monthly_income"] == 350000


# ==================== NOTIFICATIONS ====================

def test_notification_register_device():
    response = client.post("/api/v1/notifications/register", json={
        "device_token": "abc123",
        "platform": "ios",
    })
    assert response.status_code == 200
    assert response.json()["registered"] is True


def test_notification_preferences():
    response = client.post("/api/v1/notifications/preferences", json={
        "daily_summary_reminder": True,
        "daily_summary_time": "21:00",
        "commitment_reminders": True,
    })
    assert response.status_code == 200

    prefs = client.get("/api/v1/notifications/preferences")
    assert prefs.json()["daily_summary_reminder"] is True


def test_notification_send():
    from app.services.notifications import device_tokens
    device_tokens["demo-user"] = ["token123"]

    response = client.post("/api/v1/notifications/send", json={
        "title": "Test",
        "body": "Hello",
        "category": "test",
    })
    assert response.status_code == 200
    assert response.json()["delivered"] is True


def test_notification_history():
    response = client.get("/api/v1/notifications/history")
    assert response.status_code == 200


def test_notification_check_reminders():
    response = client.post("/api/v1/notifications/check-reminders")
    assert response.status_code == 200


# ==================== WEBHOOKS (ZAPIER) ====================

def test_webhook_list_triggers():
    response = client.get("/api/v1/webhooks/triggers")
    assert response.status_code == 200
    triggers = response.json()["triggers"]
    assert "recording_processed" in triggers
    assert "daily_summary_generated" in triggers


def test_webhook_register():
    response = client.post("/api/v1/webhooks/register", json={
        "webhook_url": "https://hooks.zapier.com/test/123",
        "triggers": ["recording_processed", "new_task"],
        "name": "My Zapier Zap",
    })
    assert response.status_code == 200
    assert response.json()["name"] == "My Zapier Zap"
    assert response.json()["active"] is True


def test_webhook_list():
    from app.services.zapier import webhooks
    webhooks["demo-user"] = [{
        "id": "wh1", "user_id": "demo-user", "name": "Test",
        "url": "https://example.com", "triggers": ["new_task"],
        "active": True, "deliveries": 0, "last_delivery": None,
    }]
    response = client.get("/api/v1/webhooks/list")
    assert response.status_code == 200
    assert response.json()["total"] == 1


def test_webhook_delete():
    from app.services.zapier import webhooks
    webhooks["demo-user"] = [{"id": "wh1", "user_id": "demo-user"}]
    response = client.delete("/api/v1/webhooks/wh1")
    assert response.status_code == 200


def test_webhook_toggle():
    from app.services.zapier import webhooks
    webhooks["demo-user"] = [{
        "id": "wh1", "user_id": "demo-user", "name": "Test",
        "url": "https://example.com", "triggers": ["new_task"],
        "active": True,
    }]
    response = client.post("/api/v1/webhooks/toggle", json={
        "webhook_id": "wh1",
        "active": False,
    })
    assert response.status_code == 200
    assert response.json()["active"] is False


def test_webhook_delivery_log():
    response = client.get("/api/v1/webhooks/log")
    assert response.status_code == 200
    assert response.json()["total"] == 0
