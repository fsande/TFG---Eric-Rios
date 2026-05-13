import re
from .config import GROUPING_OVERRIDES

_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"^chunk_gen_lod(\d+)$"),                 "chunk_total"),
    (re.compile(r"^async_wall_time_(.+)$"),               "async_wall_time"),
    (re.compile(r"^async_chunk_latency_(.+)$"),           "async_latency"),
    (re.compile(r"^async_throughput_(.+)$"),              "async_throughput"),
    (re.compile(r"^async_speedup_(.+)$"),                 "async_speedup"),
    (re.compile(r"^heightmap_substep_(.+)$"),             "heightmap_substep"),
    (re.compile(r"^heightmap_generation$"),               "heightmap_total"),
    (re.compile(r"^pipeline_(?:stage|agent)_(.+)$"),      "pipeline_stage"),
    (re.compile(r"^pipeline_total$"),                     "pipeline_total"),
    (re.compile(r"^prop_placement_(.+)$"),                "prop_placement"),
    (re.compile(r"^prop_instance_count_(.+)$"),           "prop_instance_count"),
    (re.compile(r"^cache_memory$"),                       "cache_memory"),
    (re.compile(r"^cache_(.+)$"),                         "cache_timing"),
]


def classify(metric_name: str) -> tuple[str, re.Match | None]:
    override = GROUPING_OVERRIDES.get(metric_name)
    if override:
        return override, None
    for pattern, group in _PATTERNS:
        m = pattern.match(metric_name)
        if m:
            return group, m
    return "other", None


def tier_label(raw: str) -> str:
    if raw == "sequential":
        return "sequential"
    m = re.match(r"configured_(\d+)", raw)
    if m:
        return f"concurrent ({m.group(1)})"
    m = re.match(r"hw_ceiling_(\d+)", raw)
    if m:
        return f"hw ceiling ({m.group(1)})"
    return raw.replace("_", " ")


def tier_sort_key(raw: str) -> int:
    if raw == "sequential":
        return 0
    if raw.startswith("configured"):
        return 1
    return 2