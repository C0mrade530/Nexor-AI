"""Basic API tests for LifeOS backend."""

from datetime import datetime

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


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
    return data["id"]


def test_list_sessions():
    response = client.get("/api/v1/audio/sessions")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_list_events():
    response = client.get("/api/v1/events")
    assert response.status_code == 200
    data = response.json()
    assert "events" in data
    assert "total" in data


def test_list_ideas():
    response = client.get("/api/v1/events/ideas")
    assert response.status_code == 200


def test_list_meetings():
    response = client.get("/api/v1/events/meetings")
    assert response.status_code == 200


def test_list_tasks():
    response = client.get("/api/v1/events/tasks")
    assert response.status_code == 200
    assert "action_items" in response.json()


def test_search_requires_query():
    response = client.get("/api/v1/search")
    assert response.status_code == 422  # missing required param


def test_daily_summaries():
    response = client.get("/api/v1/events/summaries/daily")
    assert response.status_code == 200
