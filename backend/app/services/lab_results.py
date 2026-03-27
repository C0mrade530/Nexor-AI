"""Lab results service — upload, parse, store, and AI-analyze blood tests and biomarkers.

Supports:
- Manual entry of individual biomarkers
- Photo/PDF upload with AI extraction (text sent from iOS OCR)
- Text paste from lab report
- Trend tracking across multiple tests over time
- AI analysis with health recommendations
"""

import json
import logging
import uuid
from datetime import datetime

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

# In-memory lab store
lab_results: dict[str, list[dict]] = {}  # {user_id: [lab_record, ...]}

# Reference ranges for common biomarkers
REFERENCE_RANGES = {
    # Blood count
    "hemoglobin": {"unit": "g/L", "male": [130, 170], "female": [120, 150], "default": [120, 170]},
    "rbc": {"unit": "×10¹²/L", "male": [4.5, 5.5], "female": [3.8, 5.1], "default": [3.8, 5.5]},
    "wbc": {"unit": "×10⁹/L", "default": [4.0, 9.0]},
    "platelets": {"unit": "×10⁹/L", "default": [150, 400]},
    "hematocrit": {"unit": "%", "male": [40, 54], "female": [36, 48], "default": [36, 54]},

    # Metabolic
    "glucose": {"unit": "mmol/L", "default": [3.9, 5.8]},
    "insulin": {"unit": "mU/L", "default": [2.6, 24.9]},
    "hba1c": {"unit": "%", "default": [4.0, 5.6]},

    # Lipids
    "total_cholesterol": {"unit": "mmol/L", "default": [3.0, 5.2]},
    "ldl": {"unit": "mmol/L", "default": [0, 3.0]},
    "hdl": {"unit": "mmol/L", "male": [1.0, 100], "female": [1.2, 100], "default": [1.0, 100]},
    "triglycerides": {"unit": "mmol/L", "default": [0, 1.7]},

    # Liver
    "alt": {"unit": "U/L", "default": [0, 41]},
    "ast": {"unit": "U/L", "default": [0, 40]},
    "bilirubin": {"unit": "µmol/L", "default": [3.4, 20.5]},

    # Kidney
    "creatinine": {"unit": "µmol/L", "male": [62, 106], "female": [44, 80], "default": [44, 106]},
    "urea": {"unit": "mmol/L", "default": [2.5, 8.3]},
    "gfr": {"unit": "mL/min", "default": [90, 200]},

    # Thyroid
    "tsh": {"unit": "mIU/L", "default": [0.4, 4.0]},
    "t3_free": {"unit": "pmol/L", "default": [3.1, 6.8]},
    "t4_free": {"unit": "pmol/L", "default": [12, 22]},

    # Vitamins & minerals
    "vitamin_d": {"unit": "ng/mL", "default": [30, 100]},
    "vitamin_b12": {"unit": "pg/mL", "default": [200, 900]},
    "iron": {"unit": "µmol/L", "male": [11, 28], "female": [9, 21], "default": [9, 28]},
    "ferritin": {"unit": "ng/mL", "male": [20, 250], "female": [10, 120], "default": [10, 250]},
    "magnesium": {"unit": "mmol/L", "default": [0.66, 1.07]},
    "zinc": {"unit": "µmol/L", "default": [11, 23]},

    # Hormones
    "testosterone": {"unit": "nmol/L", "male": [8.6, 29], "female": [0.3, 1.7], "default": [0.3, 29]},
    "cortisol": {"unit": "nmol/L", "default": [170, 536]},
    "dhea_s": {"unit": "µmol/L", "male": [2.2, 15.2], "female": [1.8, 9.7], "default": [1.8, 15.2]},

    # Inflammation
    "crp": {"unit": "mg/L", "default": [0, 5]},
    "esr": {"unit": "mm/h", "male": [0, 15], "female": [0, 20], "default": [0, 20]},

    # Other
    "omega3_index": {"unit": "%", "default": [8, 100]},
    "homocysteine": {"unit": "µmol/L", "default": [5, 15]},
}

LAB_ANALYSIS_PROMPT = """\
You are a health analytics AI for Nexor. Analyze the user's lab results like a \
top functional medicine doctor (think Peter Attia, Andrew Huberman approach).

Given the lab results with reference ranges, provide a JSON response:

1. overall_status — "optimal" / "good" / "attention_needed" / "concern"
2. summary — 2-3 sentence overview of the results
3. highlights — [{biomarker, value, unit, status("optimal"/"normal"/"borderline"/"out_of_range"), \
insight, recommendation}] — for each notable result
4. risk_factors — [{area, risk_level(1-5), explanation, action}] — potential health risks
5. optimization — [{category, current_status, suggestion, expected_impact, priority(1-5)}] — \
how to optimize even normal values
6. supplement_suggestions — [{supplement, reason, dosage, timing}] — based on results
7. lifestyle_adjustments — [{area, observation, change, why}]
8. retesting — [{biomarker, when, why}] — what to retest and when
9. connections_to_daily_life — how these results connect to the user's energy, sleep, performance

IMPORTANT:
- Reference actual values and ranges
- Distinguish between "in range" and "optimal" (functional medicine ranges are tighter)
- Consider biomarker interactions (e.g., iron + ferritin + B12 together)
- Be specific with supplement dosages
- Write in the user's language (Russian if data is in Russian)
"""


class LabResultsService:
    """Manages lab results — upload, storage, analysis, trends."""

    async def add_results(
        self,
        user_id: str,
        data: dict,
    ) -> dict:
        """Add lab results from manual entry or parsed text."""
        record = {
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "date": data.get("date", datetime.utcnow().strftime("%Y-%m-%d")),
            "lab_name": data.get("lab_name", ""),
            "test_type": data.get("test_type", "blood_test"),
            "biomarkers": data.get("biomarkers", {}),
            "raw_text": data.get("raw_text"),
            "notes": data.get("notes"),
            "created_at": datetime.utcnow().isoformat(),
        }

        # Annotate each biomarker with reference range and status
        gender = data.get("gender", "default")
        annotated = {}
        for key, value in record["biomarkers"].items():
            key_lower = key.lower().replace(" ", "_")
            ref = REFERENCE_RANGES.get(key_lower, {})
            range_key = gender if gender in ref else "default"
            ref_range = ref.get(range_key, ref.get("default"))
            unit = ref.get("unit", "")

            status = "unknown"
            if ref_range and isinstance(value, (int, float)):
                low, high = ref_range
                if low * 1.1 <= value <= high * 0.9:
                    status = "optimal"
                elif low <= value <= high:
                    status = "normal"
                elif low * 0.9 <= value or value <= high * 1.1:
                    status = "borderline"
                else:
                    status = "out_of_range"

            annotated[key_lower] = {
                "name": key,
                "value": value,
                "unit": unit,
                "reference_range": ref_range,
                "status": status,
            }

        record["biomarkers"] = annotated

        lab_results.setdefault(user_id, [])
        lab_results[user_id].append(record)

        # Count statuses
        statuses = [b["status"] for b in annotated.values()]
        out_of_range = statuses.count("out_of_range")
        borderline = statuses.count("borderline")

        return {
            "id": record["id"],
            "date": record["date"],
            "biomarkers_count": len(annotated),
            "out_of_range": out_of_range,
            "borderline": borderline,
            "optimal": statuses.count("optimal"),
            "normal": statuses.count("normal"),
        }

    async def parse_text(
        self,
        user_id: str,
        text: str,
        date: str | None = None,
    ) -> dict:
        """Parse lab results from pasted text using AI."""
        base_url = settings.anthropic_base_url.rstrip("/")
        api_key = settings.get_anthropic_key()
        model = settings.default_llm_model

        system = (
            "You are a lab result parser. Extract biomarker names and values from the text.\n"
            "Return a JSON object with:\n"
            '- "lab_name": the lab name if mentioned\n'
            '- "date": the date if mentioned (YYYY-MM-DD format)\n'
            '- "biomarkers": {normalized_name: numeric_value, ...}\n\n'
            "Normalize names to English snake_case matching these known biomarkers:\n"
            f"{', '.join(REFERENCE_RANGES.keys())}\n\n"
            "For Russian names: гемоглобин→hemoglobin, глюкоза→glucose, "
            "холестерин общий→total_cholesterol, ЛПНП→ldl, ЛПВП→hdl, "
            "триглицериды→triglycerides, АЛТ→alt, АСТ→ast, билирубин→bilirubin, "
            "креатинин→creatinine, мочевина→urea, ТТГ→tsh, Т3 свободный→t3_free, "
            "Т4 свободный→t4_free, витамин D→vitamin_d, витамин B12→vitamin_b12, "
            "железо→iron, ферритин→ferritin, тестостерон→testosterone, кортизол→cortisol, "
            "СРБ→crp, СОЭ→esr, гомоцистеин→homocysteine, гликированный гемоглобин→hba1c.\n"
            "Extract ONLY numeric values. Skip non-numeric entries."
        )

        url = f"{base_url}/messages"
        payload = {
            "model": model,
            "max_tokens": 2048,
            "system": system,
            "messages": [{"role": "user", "content": text}],
        }
        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()

        content = data.get("content", [])
        response_text = content[0].get("text", "") if content else ""

        # Parse JSON from response
        try:
            response_text = response_text.strip()
            if response_text.startswith("```"):
                lines = response_text.split("\n")
                json_lines = []
                in_block = False
                for line in lines:
                    if line.startswith("```") and not in_block:
                        in_block = True
                        continue
                    elif line.startswith("```") and in_block:
                        break
                    elif in_block:
                        json_lines.append(line)
                response_text = "\n".join(json_lines)
            parsed = json.loads(response_text)
        except json.JSONDecodeError:
            return {"error": "Failed to parse lab results from text", "raw": response_text}

        # Add parsed results
        result_data = {
            "date": date or parsed.get("date", datetime.utcnow().strftime("%Y-%m-%d")),
            "lab_name": parsed.get("lab_name", ""),
            "biomarkers": parsed.get("biomarkers", {}),
            "raw_text": text,
        }

        return await self.add_results(user_id, result_data)

    async def get_results(
        self,
        user_id: str,
        limit: int = 10,
    ) -> dict:
        """Get all lab results for user."""
        records = lab_results.get(user_id, [])
        records = sorted(records, key=lambda r: r["date"], reverse=True)
        return {
            "results": records[:limit],
            "total": len(records),
        }

    async def get_result(self, user_id: str, result_id: str) -> dict | None:
        """Get a specific lab result."""
        for r in lab_results.get(user_id, []):
            if r["id"] == result_id:
                return r
        return None

    async def delete_result(self, user_id: str, result_id: str) -> dict:
        """Delete a lab result."""
        records = lab_results.get(user_id, [])
        lab_results[user_id] = [r for r in records if r["id"] != result_id]
        return {"deleted": True}

    async def get_biomarker_trends(
        self,
        user_id: str,
        biomarker: str,
    ) -> dict:
        """Get trend for a specific biomarker across all tests."""
        records = lab_results.get(user_id, [])
        records = sorted(records, key=lambda r: r["date"])

        points = []
        for r in records:
            bm = r.get("biomarkers", {}).get(biomarker)
            if bm:
                points.append({
                    "date": r["date"],
                    "value": bm["value"],
                    "status": bm["status"],
                })

        ref = REFERENCE_RANGES.get(biomarker, {})
        ref_range = ref.get("default")

        return {
            "biomarker": biomarker,
            "unit": ref.get("unit", ""),
            "reference_range": ref_range,
            "points": points,
            "total_tests": len(points),
        }

    async def analyze_results(
        self,
        user_id: str,
        result_id: str | None = None,
    ) -> dict:
        """AI analysis of lab results."""
        if result_id:
            record = await self.get_result(user_id, result_id)
            if not record:
                return {"error": "Result not found"}
            records_to_analyze = [record]
        else:
            records = lab_results.get(user_id, [])
            records_to_analyze = sorted(records, key=lambda r: r["date"], reverse=True)[:3]

        if not records_to_analyze:
            return {"error": "No lab results to analyze"}

        context = json.dumps(records_to_analyze, ensure_ascii=False, indent=2, default=str)

        base_url = settings.anthropic_base_url.rstrip("/")
        api_key = settings.get_anthropic_key()
        model = settings.default_llm_model

        url = f"{base_url}/messages"
        payload = {
            "model": model,
            "max_tokens": 4096,
            "system": LAB_ANALYSIS_PROMPT,
            "messages": [{"role": "user", "content": f"Lab results:\n{context}"}],
        }
        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }

        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()

        content = data.get("content", [])
        response_text = content[0].get("text", "") if content else ""

        try:
            response_text = response_text.strip()
            if response_text.startswith("```"):
                lines = response_text.split("\n")
                json_lines = []
                in_block = False
                for line in lines:
                    if line.startswith("```") and not in_block:
                        in_block = True
                        continue
                    elif line.startswith("```") and in_block:
                        break
                    elif in_block:
                        json_lines.append(line)
                response_text = "\n".join(json_lines)
            return json.loads(response_text)
        except json.JSONDecodeError:
            return {"raw_analysis": response_text}

    async def get_reference_ranges(self) -> dict:
        """Get all known reference ranges."""
        return {"ranges": REFERENCE_RANGES}


lab_results_service = LabResultsService()
