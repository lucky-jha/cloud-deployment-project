FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .

RUN pip install --no-cache-dir  --user -r requirements.txt

#stage 2 we are using here multi-stage build

FROM python:3.12-slim

#installing curl
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

#create non root user
RUN useradd -m  -u 1000 appuser

WORKDIR /app

COPY --from=builder /root/.local /home/appuser/.local

COPY app.py ./
COPY db.py        ./
COPY templates/   ./templates/
COPY static/      ./static/

# Ensure appuser owns the app dir (for potential runtime writes)
RUN chown -R appuser:appuser /app

# Set PATH so user-installed packages are found
ENV PATH="/home/appuser/.local/bin:$PATH"   
ENV PORT=5000
ENV APP_VERSION=dev
ENV BUILD_SHA=unknown
ENV AWS_REGION=ap-south-1

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=20s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]