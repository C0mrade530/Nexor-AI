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
    store.sessions.clear()
    store.chunks.clear()
    store.events.clear()
    store.daily_summaries.clear()
    yield
    store.sessions.clear()
    store.chunks.clear()
    store.events.clear()
    store.daily_summaries.clear()


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
