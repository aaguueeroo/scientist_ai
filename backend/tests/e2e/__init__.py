"""End-to-end tests driving `POST /generate-plan` with the four sample hypotheses.

The plan calls for `pytest-recording` cassettes; in this environment we
ship an offline-equivalent fixture that monkeypatches the `build_*`
factories in `app.api.deps` to return deterministic fakes pre-loaded
with realistic, schema-compliant outputs. That gives us the same
contract guarantee as a vcrpy cassette: the test runs offline, against
fixed bytes, with no live network calls.

A `pytest.mark.live` re-record path remains available for future runs
that want to use real OpenAI / Tavily / supplier endpoints; those tests
are gated off by default in line with the plan's cassette-discipline
rules.
"""
