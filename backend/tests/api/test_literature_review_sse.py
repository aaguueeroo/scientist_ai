"""Unit tests for literature-review SSE delta streaming."""

from __future__ import annotations

import json

from app.api.literature_review import _final_review_data_from_qc, _stream_review_events
from app.schemas.literature_qc import LiteratureQCResult, NoveltyLabel, Reference, SourceTier


def _ref(title: str, url: str) -> Reference:
    return Reference(
        title=title,
        url=url,
        why_relevant="Why.",
        tier=SourceTier.TIER_1_PEER_REVIEWED,
        verified=True,
        verification_url=url,
        confidence="high",
    )


def _parse_sse_chunks(stream: bytes) -> list[dict[str, object]]:
    """Extract JSON payloads from `data: {...}\\n\\n` chunks."""
    text = stream.decode("utf-8")
    out: list[dict[str, object]] = []
    for block in text.split("\n\n"):
        block = block.strip()
        if not block.startswith("data: "):
            continue
        payload = json.loads(block[6:])
        out.append(payload)
    return out


def test_stream_emits_one_source_per_event_sequentially() -> None:
    qc = LiteratureQCResult(
        novelty=NoveltyLabel.NOT_FOUND,
        references=[
            _ref("A", "https://example.com/a"),
            _ref("B", "https://example.com/b"),
            _ref("C", "https://example.com/c"),
        ],
        confidence="high",
        tier_0_drops=0,
    )
    chunks = b"".join(
        _stream_review_events(qc=qc, literature_review_id="lr-test")
    )
    events = _parse_sse_chunks(chunks)
    assert len(events) == 3
    for i, env in enumerate(events):
        assert env["event"] == "review_update"
        data = env["data"]
        assert isinstance(data, dict)
        assert data["expected_total_sources"] == 3
        assert data["source_index"] == i + 1
        assert len(data["sources"]) == 1
        assert data["sources"][0]["title"] == ("A", "B", "C")[i]
        assert data["is_final"] == (i == 2)
        assert data["literature_review_id"] == "lr-test"


def test_final_snapshot_has_all_sources_for_get_replay() -> None:
    qc = LiteratureQCResult(
        novelty=NoveltyLabel.NOT_FOUND,
        references=[
            _ref("A", "https://example.com/a"),
            _ref("B", "https://example.com/b"),
        ],
        confidence="high",
        tier_0_drops=0,
    )
    data = _final_review_data_from_qc(qc, "lr-snap")
    assert data["is_final"] is True
    assert data["expected_total_sources"] == 2
    assert len(data["sources"]) == 2
    assert data["sources"][0]["title"] == "A"
    assert data["sources"][1]["title"] == "B"
    assert data["literature_review_id"] == "lr-snap"
    assert "source_index" not in data


def test_stream_zero_sources_single_event_with_id() -> None:
    qc = LiteratureQCResult(
        novelty=NoveltyLabel.NOT_FOUND,
        references=[],
        confidence="low",
        tier_0_drops=0,
    )
    chunks = b"".join(
        _stream_review_events(qc=qc, literature_review_id="lr-empty")
    )
    events = _parse_sse_chunks(chunks)
    assert len(events) == 1
    data = events[0]["data"]
    assert data["is_final"] is True
    assert data["expected_total_sources"] == 0
    assert data["sources"] == []
    assert "source_index" not in data
    assert data["literature_review_id"] == "lr-empty"
