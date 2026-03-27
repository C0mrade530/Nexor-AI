"""Lab results API — upload, view, analyze blood tests and biomarkers."""

from fastapi import APIRouter, UploadFile, File
from pydantic import BaseModel

from app.services.lab_results import lab_results_service

router = APIRouter(prefix="/labs", tags=["labs"])


class LabResultsRequest(BaseModel):
    user_id: str = "demo-user"
    date: str | None = None
    lab_name: str | None = None
    test_type: str = "blood_test"
    biomarkers: dict = {}
    gender: str = "default"
    notes: str | None = None


class LabTextRequest(BaseModel):
    user_id: str = "demo-user"
    text: str
    date: str | None = None


@router.post("/results")
async def add_lab_results(req: LabResultsRequest):
    """Add lab results with manual biomarker entry.

    Example biomarkers: {"hemoglobin": 145, "glucose": 5.2, "vitamin_d": 38}
    """
    data = req.model_dump(exclude_none=True)
    return await lab_results_service.add_results(req.user_id, data)


@router.post("/parse")
async def parse_lab_text(req: LabTextRequest):
    """Parse lab results from pasted text (supports Russian lab reports).

    Paste the text from your lab report — AI will extract biomarkers automatically.
    """
    return await lab_results_service.parse_text(req.user_id, req.text, req.date)


@router.get("/results")
async def get_lab_results(user_id: str = "demo-user", limit: int = 10):
    """Get all lab results for user, newest first."""
    return await lab_results_service.get_results(user_id, limit=limit)


@router.get("/results/{result_id}")
async def get_lab_result(result_id: str, user_id: str = "demo-user"):
    """Get a specific lab result by ID."""
    result = await lab_results_service.get_result(user_id, result_id)
    if not result:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Lab result not found")
    return result


@router.delete("/results/{result_id}")
async def delete_lab_result(result_id: str, user_id: str = "demo-user"):
    """Delete a lab result."""
    return await lab_results_service.delete_result(user_id, result_id)


@router.get("/trends/{biomarker}")
async def get_biomarker_trend(biomarker: str, user_id: str = "demo-user"):
    """Get trend for a specific biomarker across all tests.

    Example: /labs/trends/vitamin_d
    """
    return await lab_results_service.get_biomarker_trends(user_id, biomarker)


@router.post("/analyze")
async def analyze_lab_results(user_id: str = "demo-user", result_id: str | None = None):
    """AI analysis of lab results — functional medicine approach.

    If result_id is provided, analyzes that specific test.
    Otherwise analyzes the latest 3 results for trends.
    """
    return await lab_results_service.analyze_results(user_id, result_id)


@router.get("/references")
async def get_reference_ranges():
    """Get all known biomarker reference ranges."""
    return await lab_results_service.get_reference_ranges()
