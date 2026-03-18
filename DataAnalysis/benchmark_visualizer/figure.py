"""
Figure assembly: builds the full Plotly HTML report from one or more ``Run`` objects.
"""
import plotly.graph_objects as go
from plotly.subplots import make_subplots

from .collectors import collect_cache, collect_prop_instances, collect_simple
from .models import Run
from .traces import (
    build_async_traces,
    build_chunk_mesh_traces,
    build_chunk_traces,
    build_simple_traces,
)


def build_figure(runs: list[Run]) -> go.Figure:
    """
    Assemble a multi-section Plotly figure from one or more benchmark runs.

    Sections are included only when the corresponding category is present in
    the data.  Full-width rows (chunk generation, mesh complexity, pipeline,
    props) use ``colspan=2``; paired rows (async wall/throughput, async
    latency/speedup, cache timing/memory) split the column width equally.

    The async section always occupies two rows so that all four metric
    families (wall time, throughput, chunk latency, speedup) are visible
    without crowding.

    Raises ``ValueError`` if no recognisable benchmark data is found.
    """
    cats = {r.category for run in runs for r in run.results}
    has_chunk    = "chunk_generation" in cats
    has_async    = "async_loading"    in cats
    has_pipeline = "pipeline"         in cats
    has_cache    = "cache"            in cats
    has_props    = "prop_placement"   in cats

    # ── Row plan ─────────────────────────────────────────────────────────────
    # Each entry: (left_title, right_title, row_type, full_width)
    row_plan: list[tuple[str, str, str, bool]] = []

    if has_chunk:
        row_plan.append((
            "Chunk Generation \u2014 stacked substeps by LOD",
            "", "chunk", True,
        ))
        row_plan.append((
            "Chunk Mesh Complexity \u2014 vertices & triangles per LOD",
            "", "chunk_mesh", True,
        ))

    if has_async:
        row_plan.append((
            "Async Loading \u2014 Wall Time (ms)",
            "Async Loading \u2014 Throughput (chunks/sec)",
            "async_top", False,
        ))
        row_plan.append((
            "Async Loading \u2014 Chunk Latency (ms)",
            "Async Loading \u2014 Speedup (\u00d7)",
            "async_bottom", False,
        ))

    if has_pipeline:
        row_plan.append(("Pipeline Timing", "", "pipeline", True))

    if has_cache:
        # Timing metrics (ms) on the left, memory (MB) on the right.
        row_plan.append(("Cache Timing (ms)", "Cache Memory (MB)", "cache", False))

    if has_props:
        row_plan.append(("Prop Placement Timing", "", "props", True))

    if not row_plan:
        raise ValueError("No recognisable benchmark data in the provided files.")

    # ── Subplot grid ─────────────────────────────────────────────────────────
    specs: list[list] = []
    subplot_titles: list[str] = []
    for t1, t2, _, full_width in row_plan:
        if full_width:
            specs.append([{"colspan": 2}, None])
            subplot_titles.append(t1)
        else:
            specs.append([{}, {}])
            subplot_titles += [t1, t2]

    fig = make_subplots(
        rows=len(row_plan),
        cols=2,
        specs=specs,
        subplot_titles=subplot_titles,
        vertical_spacing=0.08,
        horizontal_spacing=0.07,
    )

    # Pre-compute async traces once; both async rows consume subsets of the
    # same four lists rather than calling the collector twice.
    _async: list | None = None

    def _get_async() -> tuple:
        nonlocal _async
        if _async is None:
            _async = list(build_async_traces(runs))
        return tuple(_async)  # (wall, thru, latency, speedup)

    for row_idx, (_, _, row_type, _) in enumerate(row_plan, start=1):
        _populate_row(fig, row_idx, row_type, runs, _get_async)

    fig.update_layout(**_layout(runs, len(row_plan)))
    for annotation in fig.layout.annotations:
        annotation.font = dict(size=13, color="#ccccdd")
    return fig


def _populate_row(
    fig: go.Figure,
    row_idx: int,
    row_type: str,
    runs: list[Run],
    get_async,
) -> None:
    """Add traces and axis labels for a single subplot row."""

    # ── Chunk: stacked substeps + total scatter ───────────────────────────
    if row_type == "chunk":
        for trace in build_chunk_traces(runs):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)

    # ── Chunk mesh complexity: vertex & triangle counts ───────────────────
    elif row_type == "chunk_mesh":
        for trace in build_chunk_mesh_traces(runs):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(
            title_text="count",
            tickformat=",",
            row=row_idx, col=1,
        )

    # ── Async row 1: wall time | throughput ──────────────────────────────
    elif row_type == "async_top":
        wall_t, thru_t, _lat, _spd = get_async()
        for trace in wall_t:
            fig.add_trace(trace, row=row_idx, col=1)
        for trace in thru_t:
            fig.add_trace(trace, row=row_idx, col=2)
        fig.update_yaxes(title_text="ms",         row=row_idx, col=1)
        fig.update_yaxes(title_text="chunks/sec", row=row_idx, col=2)

    # ── Async row 2: chunk latency | speedup ─────────────────────────────
    elif row_type == "async_bottom":
        _wall, _thru, lat_t, spd_t = get_async()
        for trace in lat_t:
            fig.add_trace(trace, row=row_idx, col=1)
        for trace in spd_t:
            fig.add_trace(trace, row=row_idx, col=2)
        fig.update_yaxes(title_text="ms",       row=row_idx, col=1)
        fig.update_yaxes(title_text="\u00d7",   row=row_idx, col=2)

    # ── Pipeline: stages + total ─────────────────────────────────────────
    elif row_type == "pipeline":
        keys, data = collect_simple(
            runs,
            {"pipeline_stage", "pipeline_total"},
            lambda g, m: "total" if g == "pipeline_total" else m.group(1),
        )
        # Put the aggregate total first for visual reference.
        if "total" in keys:
            keys = ["total"] + [k for k in keys if k != "total"]
        for trace in build_simple_traces(keys, data, runs, "pipeline"):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)

    # ── Cache: timing (ms) left | memory (MB) right ──────────────────────
    elif row_type == "cache":
        timing_keys, timing, memory = collect_cache(runs)
        for trace in build_simple_traces(timing_keys, timing, runs, "cache"):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)

        mem_keys = sorted(memory)
        for trace in build_simple_traces(mem_keys, memory, runs, "memory"):
            fig.add_trace(trace, row=row_idx, col=2)
        fig.update_yaxes(title_text="MB", row=row_idx, col=2)

    # ── Prop placement: timing with instance counts in hover ─────────────
    elif row_type == "props":
        keys, data = collect_simple(
            runs, {"prop_placement"}, lambda g, m: m.group(1)
        )
        # Build per-rule instance-count strings to append to each hover.
        instances = collect_prop_instances(runs)
        extra_hover: dict[str, dict[str, str]] = {}
        for rule_id, run_data in instances.items():
            extra_hover[rule_id] = {}
            for run_label, r in run_data.items():
                extra_hover[rule_id][run_label] = (
                    f"instances \u2014 mean: {r.mean:.0f} "
                    f"[CI95: {r.ci95_lower:.0f}\u2013{r.ci95_upper:.0f}]"
                )
        for trace in build_simple_traces(keys, data, runs, "prop", extra_hover=extra_hover):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)


def _layout(runs: list[Run], n_rows: int) -> dict:
    """Return the ``update_layout`` kwargs dict for the full figure."""
    env_lines = []
    for run in runs:
        e = run.environment
        parts = [p for p in [e.get("cpu_name"), e.get("gpu_name"), e.get("engine_version")] if p]
        if parts:
            joined = " \u00b7 ".join(parts)
            env_lines.append(f"<b>{run.label}</b>: {joined}")
    title_text = "Terrain Benchmark Results"
    if env_lines:
        title_text += "<br><sup>" + " &nbsp;|&nbsp; ".join(env_lines) + "</sup>"
    return dict(
        title=dict(text=title_text, x=0.5, xanchor="center", font=dict(size=18)),
        barmode="stack",
        template="plotly_dark",
        height=420 * n_rows + 140,
        legend=dict(
            orientation="v",
            x=1.02,
            y=1.0,
            bgcolor="rgba(20,20,40,0.85)",
            bordercolor="rgba(255,255,255,0.15)",
            borderwidth=1,
            font=dict(size=11),
            itemclick="toggleothers",
        ),
        margin=dict(l=70, r=230, t=130, b=70),
        font=dict(family="'JetBrains Mono', 'Consolas', monospace", size=12),
        paper_bgcolor="#0f0f1a",
        plot_bgcolor="#161625",
        hoverlabel=dict(
            bgcolor="#1e1e35",
            bordercolor="#4C9BE8",
            font=dict(family="monospace", size=12),
        ),
    )