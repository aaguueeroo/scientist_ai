"""Storage layer: async SQLAlchemy engine + per-row repositories.

Step 35 wires the engine and session factory; later steps (36-38) add the
`PlanRow`/`FeedbackRow` models and the repos that read/write them.
"""
