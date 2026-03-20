FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY pyproject.toml .
RUN pip install --no-cache-dir .

# Copy application
COPY app/ app/

# Create storage dirs
RUN mkdir -p audio_storage chroma_data

EXPOSE 8000

# Startup: init DB tables then run server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
