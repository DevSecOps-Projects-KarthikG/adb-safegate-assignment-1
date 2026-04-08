# =============================================================================
# ADB SAFEGATE – Secure Python Hello World Dockerfile
# =============================================================================
# Security Best Practices Applied:
#   1. Multi-stage build        – build tools never reach production image
#   2. Minimal base image       – python:3.11-slim reduces attack surface
#   3. Explicit version pin     – prevents supply chain drift
#   4. Non-root user UID 10001  – least privilege enforced
#   5. No pip cache             – no stale/vulnerable cached packages
#   6. Minimal file copy        – only runtime files in final image
#   7. Non-privileged port 5000 – ports < 1024 require root
#   8. Health check built-in    – Kubernetes liveness/readiness probes
#   9. Exec form CMD            – correct signal handling, no shell wrapper
#
# Reference: https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html
# =============================================================================

# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Copy requirements first – maximises Docker layer caching
COPY requirements.txt .

# Install dependencies into isolated prefix – clean copy to production stage
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: Production Image ─────────────────────────────────────────────────
FROM python:3.11-slim

# ── Labels ────────────────────────────────────────────────────────────────────
LABEL maintainer="Kartik Gundu"
LABEL org.opencontainers.image.title="ADB SAFEGATE Hello App"
LABEL org.opencontainers.image.description="Secure Python Hello World – DevOps Engineer Assignment"
LABEL org.opencontainers.image.version="1.0.0"

# ── Security: non-root user ───────────────────────────────────────────────────
# UID 10001 chosen to avoid conflict with system accounts (1–999)
# --no-create-home: no home directory needed
# --shell /bin/false: prevents interactive login
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup --no-create-home --shell /bin/false appuser

WORKDIR /app

# Copy compiled dependencies from builder stage only
COPY --from=builder /install /usr/local

# Copy only the application file needed at runtime
COPY app.py .

# Set correct ownership before dropping privileges
RUN chown -R appuser:appgroup /app

# Drop to non-root user
USER appuser

# Non-privileged port – does not require root
EXPOSE 5000

# Health check – Kubernetes uses this for liveness and readiness probes
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Exec form – no shell wrapper, signals propagate correctly to Python process
CMD ["python", "app.py"]
