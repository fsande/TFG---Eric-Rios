"""
Data collectors that group ``Result`` objects from ``Run`` instances into
structures suitable for the trace builders.
"""
from collections import defaultdict

from .classifier import classify, tier_sort_key
from .models import Result, Run


def collect_heightmap(
    runs: list[Run],
) -> tuple[list[str], dict[str, dict[str, Result]], dict[str, Result]]:
    """
    Collect heightmap substep results and the per-run heightmap_generation total.

    Returns:
    - ``substeps``: ordered substep name list (alphabetical).
    - ``data``: ``data[substep][run_label] → Result``.
    - ``totals``: ``totals[run_label] → Result`` for the ``heightmap_generation`` metric.
    """
    data: dict[str, dict[str, Result]] = defaultdict(dict)
    totals: dict[str, Result] = {}
    for run in runs:
        for r in run.results:
            g, m = classify(r.metric_name)
            if g == "heightmap_substep":
                data[m.group(1)][run.label] = r
            elif g == "heightmap_total":
                totals[run.label] = r
    return sorted(data), data, totals


def collect_async(
    runs: list[Run],
) -> tuple[
    list[str],
    dict[str, dict[str, Result]],
    dict[str, dict[str, Result]],
    dict[str, dict[str, Result]],
    dict[str, dict[str, Result]],
]:
    """
    Collect async loading results grouped by concurrency tier.

    Returns ``(tiers, wall, thru, latency, speedup)`` where each dict is
    ``[tier_or_key][run_label] → Result``.
    """
    wall:    dict[str, dict[str, Result]] = defaultdict(dict)
    thru:    dict[str, dict[str, Result]] = defaultdict(dict)
    latency: dict[str, dict[str, Result]] = defaultdict(dict)
    speedup: dict[str, dict[str, Result]] = defaultdict(dict)
    for run in runs:
        for r in run.results:
            g, m = classify(r.metric_name)
            if g == "async_wall_time":
                wall[m.group(1)][run.label] = r
            elif g == "async_throughput":
                thru[m.group(1)][run.label] = r
            elif g == "async_latency":
                latency[m.group(1)][run.label] = r
            elif g == "async_speedup":
                speedup[m.group(1)][run.label] = r
    tiers = sorted(set(wall) | set(thru) | set(latency), key=tier_sort_key)
    return tiers, wall, thru, latency, speedup


def collect_cache(
    runs: list[Run],
) -> tuple[list[str], dict[str, dict[str, Result]], dict[str, dict[str, Result]]]:
    """
    Collect cache results, separating ms timing from the MB memory metric.

    Returns ``(timing_keys, timing, memory)`` where both dicts are
    ``[key][run_label] → Result``.
    """
    timing: dict[str, dict[str, Result]] = defaultdict(dict)
    memory: dict[str, dict[str, Result]] = defaultdict(dict)
    for run in runs:
        for r in run.results:
            g, m = classify(r.metric_name)
            if g == "cache_timing":
                timing[m.group(1)][run.label] = r
            elif g == "cache_memory":
                memory["memory"][run.label] = r
    return sorted(timing), timing, memory


def collect_simple(
    runs: list[Run],
    target_groups: set[str],
    key_extractor,
) -> tuple[list[str], dict[str, dict[str, Result]]]:
    """
    Collect results for any set of group keys into a flat keyed structure.

    ``key_extractor(group, match)`` returns a string key or ``None`` to skip.
    Returns ``(sorted_keys, data)`` where ``data[key][run_label] → Result``.
    """
    data: dict[str, dict[str, Result]] = defaultdict(dict)
    for run in runs:
        for r in run.results:
            g, m = classify(r.metric_name)
            if g in target_groups:
                key = key_extractor(g, m)
                if key:
                    data[key][run.label] = r
    return sorted(data), data