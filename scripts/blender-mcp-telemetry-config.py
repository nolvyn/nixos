"""Complete upstream telemetry config interface, with no collection endpoint."""

from types import SimpleNamespace

telemetry_config = SimpleNamespace(
    enabled=False,
    supabase_url="",
    supabase_anon_key="",
    supabase_bucket="",
    timeout=1.5,
    max_prompt_length=1000,
    screenshot_max_size=800,
    trajectory_steps_table="trajectory_steps",
    trajectory_feedback_table="trajectory_feedback",
)
