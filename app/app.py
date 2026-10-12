"""
Three-tier Flask application.

Endpoints:
  GET /            → HTML dashboard (uses templates/index.html)
  GET /health      → JSON health for ALB (fast, no DB call)
  GET /version     → JSON build info
  GET /api/visits  → JSON — increments + returns visit counter from Postgres
  GET /db-test     → JSON — verifies DB connectivity and latency
"""

import os
import socket
import logging
from flask import Flask, jsonify, render_template, request

import db

# ---------------------------------------------------------------------------
# Logging — goes to stdout so Docker/CloudWatch captures it
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
app = Flask(__name__)


# Version info comes from env vars set at container startup
APP_VERSION = os.environ.get("APP_VERSION", "dev")
BUILD_SHA = os.environ.get("BUILD_SHA", "unknown")
AWS_REGION = os.environ.get("AWS_REGION", "unknown")

# Initialize DB tables when the module is imported.
# This runs once per gunicorn worker on container start — not just in local dev.
# If the DB isn't ready yet, init_db() retries internally, then gives up silently
# and lets the first real request trigger another attempt.
try:
    db.init_db()
except Exception as e:
    logger.warning(f"Startup DB init failed (will retry per request): {e}")


def instance_info():
    """Return info about the current container/instance."""
    hostname = socket.gethostname()
    try:
        # On EC2 the internal DNS name starts with 'ip-<dashed-ip>'
        # so we can derive the AZ from the instance metadata, but simpler:
        # just return the hostname and let the frontend show it.
        return {
            "hostname": hostname,
            "az": os.environ.get("AWS_AZ", "unknown"),
        }
    except Exception:
        return {"hostname": hostname, "az": "unknown"}


# ---------------------------------------------------------------------------
# Health — must be fast, no DB call. ALB health checks hit this every 30s.
# ---------------------------------------------------------------------------
@app.get("/health")
def health():
    return jsonify(status="healthy"), 200


# ---------------------------------------------------------------------------
# Version — build metadata for CI/CD demo
# ---------------------------------------------------------------------------
@app.get("/version")
def version():
    return jsonify(
        version=APP_VERSION,
        build=BUILD_SHA,
        region=AWS_REGION,
    )


# ---------------------------------------------------------------------------
# Home page — renders HTML template
# ---------------------------------------------------------------------------
@app.get("/")
def home():
    info = instance_info()
    return render_template(
        "index.html",
        hostname=info["hostname"],
        az=info["az"],
        version=APP_VERSION,
        build=BUILD_SHA,
        region=AWS_REGION,
    )


# ---------------------------------------------------------------------------
# API — visits counter (DB-backed)
# ---------------------------------------------------------------------------
@app.get("/api/visits")
def api_visits():
    """Increment and return the visit counter."""
    try:
        count = db.increment_and_get_visits()
        return jsonify(visits=count, source="postgres")
    except Exception as e:
        logger.exception("Failed to increment visits")
        return jsonify(error=str(e), source="postgres"), 500


@app.get("/api/visits/current")
def api_visits_current():
    """Read-only version — no increment. Useful for polling."""
    try:
        count = db.get_visit_count()
        return jsonify(visits=count, source="postgres")
    except Exception as e:
        logger.exception("Failed to read visits")
        return jsonify(error=str(e), source="postgres"), 500


# ---------------------------------------------------------------------------
# API — DB connectivity test
# ---------------------------------------------------------------------------
@app.get("/db-test")
def db_test():
    try:
        result = db.healthcheck()
        return jsonify(
            status="ok",
            db=result,
            host=os.environ.get("DB_HOST", "unknown"),
            database=os.environ.get("DB_NAME", "unknown"),
        )
    except Exception as e:
        logger.exception("DB test failed")
        return jsonify(status="error", error=str(e)), 500


# ---------------------------------------------------------------------------
# Global error handlers
# ---------------------------------------------------------------------------
@app.errorhandler(404)
def not_found(e):
    return jsonify(error="not found", path=request.path), 404


@app.errorhandler(500)
def server_error(e):
    return jsonify(error="internal server error"), 500


# ---------------------------------------------------------------------------
# Local dev entry point (production uses gunicorn, see Dockerfile CMD)
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    # Initialize DB tables on local dev startup
    try:
        db.init_db()
    except Exception as e:
        logger.warning(f"DB init on startup failed (will retry per request): {e}")

    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
