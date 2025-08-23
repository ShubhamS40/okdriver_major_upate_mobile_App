FROM python:3.10-slim

WORKDIR /app

# Install required system dependencies for OpenCV & Mediapipe
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirement.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirement.txt

# Ensure uvicorn is available (in case it's not in requirement.txt)
RUN pip install --no-cache-dir uvicorn

# Copy application code
COPY . .

EXPOSE 8000

# Start FastAPI app with uvicorn
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
