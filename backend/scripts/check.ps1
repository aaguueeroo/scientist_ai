# backend/scripts/check.ps1
#
# Canonical "all checks" command for the AI Scientist backend. Runs the
# four-command quality gate in the documented order and aborts on the
# first non-zero exit so a failing pytest is never masked by a passing
# linter.
#
# Usage (from anywhere):
#     pwsh backend/scripts/check.ps1
#
# Documented commands (in order):
#   1. pytest -q              -- full backend suite, offline against cassettes
#   2. ruff format backend    -- formatter (write-mode)
#   3. ruff check backend     -- lint
#   4. mypy --strict backend  -- static types
#
# The script runs each command from inside the backend directory so the
# repository's `pyproject.toml` (mypy / ruff / pytest config, including
# the tavily-python untyped-module override) is picked up correctly. The
# target is therefore `.` at runtime, but the documented form
# (`ruff format backend`, `mypy --strict backend`, ...) is what a user
# would type from the repo root and is preserved verbatim above.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendRoot = Split-Path -Parent $scriptDir
Push-Location $backendRoot
try {
    Write-Host "=== check.ps1: pytest -q ==="
    uv run pytest -q
    if ($LASTEXITCODE -ne 0) { throw "pytest failed (exit $LASTEXITCODE)" }

    Write-Host "=== check.ps1: ruff format backend ==="
    uv run ruff format .
    if ($LASTEXITCODE -ne 0) { throw "ruff format failed (exit $LASTEXITCODE)" }

    Write-Host "=== check.ps1: ruff check backend ==="
    uv run ruff check .
    if ($LASTEXITCODE -ne 0) { throw "ruff check failed (exit $LASTEXITCODE)" }

    Write-Host "=== check.ps1: mypy --strict backend ==="
    uv run mypy --strict .
    if ($LASTEXITCODE -ne 0) { throw "mypy failed (exit $LASTEXITCODE)" }

    Write-Host "=== check.ps1: all checks passed ==="
}
finally {
    Pop-Location
}
