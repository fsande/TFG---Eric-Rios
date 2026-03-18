"""
Metric name classification and async tier label helpers.

Metric names are matched against ordered regex patterns to determine which
chart group they belong to. The first matching pattern wins. Unknown names fall
through to the ``"other"`` group and are silently ignored by the renderer.
"""
import re
from .config import GROUPING_OVERRIDES

_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"^chunk_substep_(.+)_lod(\d+)$"),       "chunk_substep"),
    (re.compile(r"^chunk_gen_lod(\d+)$"),                 "chunk_total"),
    (re.compile(r"^array_mesh_build_lod(\d+)$"),          "chunk_array_mesh"),
    (re.compile(r"^(?:vertex|triangle)_count_lod(\d+)$"), "chunk_count"),
    (re.compile(r"^async_wall_time_(.+)$"),               "async_wall_time"),
    (re.compile(r"^async_chunk_latency_(.+)$"),           "async_latency"),
    (re.compile(r"^async_throughput_(.+)$"),              "async_throughput"),
    (re.compile(r"^async_speedup_(.+)$"),                 "async_speedup"),
    (re.compile(r"^(heightmap_generation)$"),             "pipeline_stage"),
    (re.compile(r"^pipeline_stage_(.+)$"),                "pipeline_stage"),
    (re.compile(r"^pipeline_total$"),                     "pipeline_total"),
    (re.compile(r"^prop_placement_(.+)$"),                "prop_placement"),
    (re.compile(r"^prop_instance_count_(.+)$"),           "prop_instance_count"),
    (re.compile(r"^cache_memory$"),                       "cache_memory"),
    (re.compile(r"^cache_(.+)$"),                         "cache_timing"),
]


def classify(metric_name: str) -> tuple[str, re.Match | None]:
    """
    Return ``(group_key, regex_match)`` for a metric name.

    Checks ``GROUPING_OVERRIDES`` first. Falls back to pattern matching,
    then to ``("other", None)`` for unrecognised names.
    """
    override = GROUPING_OVERRIDES.get(metric_name)
    if override:
        return override, None
    for pattern, group in _PATTERNS:
        m = pattern.match(metric_name)
        if m:
            return group, m
    return "other", None


def tier_label(raw: str) -> str:
    """
    Convert an internal async tier key to a human-readable label.

    Examples::
        "sequential"        → "sequential"
        "configured_5"      → "concurrent (5)"
        "hw_ceiling_28"     → "hw ceiling (28)"
        "hw_vs_sequential"  → "hw vs sequential"
    """
    if raw == "sequential":
        return "sequential"
    m = re.match(r"configured_(\d+)", raw)
    if m:
        return f"concurrent ({m.group(1)})"
    m = re.match(r"hw_ceiling_(\d+)", raw)
    if m:
        return f"hw ceiling ({m.group(1)})"
    # Generic fallback: underscores → spaces (covers "hw_vs_sequential" etc.)
    return raw.replace("_", " ")


def tier_sort_key(raw: str) -> int:
    """Return a sort index so tiers appear in sequential → configured → hw order."""
    if raw == "sequential":
        return 0
    if raw.startswith("configured"):
        return 1
    return 2