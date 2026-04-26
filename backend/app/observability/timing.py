"""Debug-oriented duration logging (use when ``LOG_LEVEL=DEBUG``)."""

from __future__ import annotations

import time
from contextlib import contextmanager
from typing import Any, Iterator


@contextmanager
def debug_elapsed(
    log: Any,
    event: str,
    *,
    request_id: str | None = None,
    **static_fields: Any,
) -> Iterator[None]:
    """Emit ``log.debug`` with ``elapsed_ms`` after the block (only if DEBUG is on)."""

    t0 = time.perf_counter()
    try:
        yield
    finally:
        ms = int((time.perf_counter() - t0) * 1000)
        payload = {**static_fields, "elapsed_ms": ms}
        if request_id is not None:
            payload["request_id"] = request_id
        log.debug(event, **payload)


def truncate_preview(text: str, max_chars: int) -> str:
    """Single-line, length-capped string for log fields."""

    s = (text or "").replace("\n", " ").replace("\r", " ")
    if max_chars <= 0:
        return ""
    if len(s) <= max_chars:
        return s
    return f"{s[: max_chars - 3]}..."
