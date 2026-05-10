"""
Data collectors that group ``Result`` objects from one or more ``Run`` instances
into structures suitable for the trace builders.
"""
from collections import defaultdict

from .classifier import classify, tier_sort_key
from .models import Result, Run


def collect_chunk(
    runs: list[Run],
) -> tuple[
    list[int],
    list[str],
    dict[int, dict[str, dict[str, Result]]],
    dict[int, dict[str, Result]],
    dict[int, dict[str, dict[str, Result]]],
]:
    """
    Collect chunk-generation results grouped by LOD level.

    Returns a tuple of:
    - ``lods``: sorted list of LOD integers present in the data.
    - ``substeps``: ordered list of substep names (known order first, then
      alphabetical for any extras).
    - ``data``: ``data[lod][substep][run_label] → Result`` for timed substeps.
    - ``totals``: ``totals[lod][run_label] → Result`` for ``chunk_gen_lod*``
      total-time metrics (used as scatter overlays).
    - ``counts``: ``counts[lod][kind][run_label] → Result`` where *kind* is
      ``"vertices"`` or ``"triangles"``.
    """
    data: dict[int, dict[str, dict[str, Result]]] = defaultdict(lambda: defaultdict(dict))
    totals: dict[int, dict[str, Result]] = defaultdict(dict)
    counts: dict[int, dict[str, dict[str, Result]]] = defaultdict(lambda: defaultdict(dict))
    for run in runs:
        for r in run.results:
            g, m = classify(r.metric_name)
            if g == "chunk_substep":
                data[int(m.group(2))][m.group(1)][run.label] = r
            elif g == "chunk_array_mesh":
                data[int(m.group(1))]["array_mesh_build"][run.label] = r
            elif g == "chunk_total":
                totals[int(m.group(1))][run.label] = r
            elif g == "chunk_count":
                lod = int(m.group(1))
                kind = "vertices" if r.metric_name.startswith("vertex") else "triangles"
                counts[lod][kind][run.label] = r
    lods = sorted(set(data) | set(totals) | set(counts))
    all_substeps = {s for lod in lods for s in data.get(lod, {})}
    known_order = ["height_grid", "mesh_build", "volumes", "normals", "tangents", "array_mesh_build"]
    substeps = [s for s in known_order if s in all_substeps]
    substeps += sorted(all_substeps - set(known_order))
    return lods, substeps, data, totals, counts


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

    Returns a tuple of:
    - ``tiers``: tier keys sorted sequential → configured → hw-ceiling.
      Shared across wall, throughput, and latency metrics.
    - ``wall``: ``wall[tier][run_label] → Result`` for wall-time metrics.
    - ``thru``: ``thru[tier][run_label] → Result`` for throughput metrics.
    - ``latency``: ``latency[tier][run_label] → Result`` for per-chunk
      latency distribution metrics.
    - ``speedup``: ``speedup[key][run_label] → Result`` for speedup scalars
      (uses its own key space, e.g. ``"hw_vs_sequential"``).
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
) -> tuple[
    list[str],
    dict[str, dict[str, Result]],
    dict[str, dict[str, Result]],
]:
    """
    Collect cache results, separating ms-based timing from the MB memory metric.

    Returns:
    - ``timing_keys``: sorted list of timing keys
      (e.g. ``["cold_gen", "warm_hit"]``).
    - ``timing``: ``timing[key][run_label] → Result`` for ms-based metrics.
    - ``memory``: ``memory["memory"][run_label] → Result`` for the MB metric.
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


def collect_prop_instances(
    runs: list[Run],
) -> dict[str, dict[str, Result]]:
    """
    Collect prop instance count results keyed by rule id.

    Returns ``data[rule_id][run_label] → Result``.
    """
    data: dict[str, dict[str, Result]] = defaultdict(dict)
    for run in runs:
        for r in run.results:
            g, m = classify(r.metric_name)
            if g == "prop_instance_count":
                data[m.group(1)][run.label] = r
    return dict(data)


def collect_simple(
    runs: list[Run],
    target_groups: set[str],
    key_extractor,
) -> tuple[list[str], dict[str, dict[str, Result]]]:
    """
    Collect results for any set of group keys into a flat keyed structure.

    ``key_extractor`` is called as ``key_extractor(group, match)`` and should
    return a string key, or ``None`` to skip the result.

    Returns:
    - ``keys``: sorted list of string keys.
    - ``data``: ``data[key][run_label] → Result``.
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