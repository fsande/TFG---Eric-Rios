"""
Figure assembly: builds the full Plotly HTML report from one or more ``Run`` objects.
"""
import plotly.graph_objects as go
from plotly.subplots import make_subplots

from .classifier import classify
from .collectors import collect_cache, collect_simple
from .models import Run
from .traces import build_async_traces, build_heightmap_traces, build_simple_traces


def build_figure(runs: list[Run]) -> go.Figure:
    """
    Assemble a multi-section Plotly figure from one or more benchmark runs.

    Sections are included only when the corresponding metric groups are present.
    Full-width rows use ``colspan=2``; paired rows split equally.
    Raises ``ValueError`` if no recognisable benchmark data is found.
    """
    groups: set[str] = set()
    for run in runs:
        for r in run.results:
            g, _ = classify(r.metric_name)
            groups.add(g)

    has_chunk = "chunk_total" in groups
    has_heightmap = "heightmap_substep" in groups or "heightmap_total" in groups
    has_async = "async_wall_time" in groups
    has_pipeline = "pipeline_stage" in groups or "pipeline_total" in groups
    has_cache = "cache_timing" in groups or "cache_memory" in groups
    has_props = "prop_placement" in groups

    # (left_title, right_title, row_type, full_width)
    row_plan: list[tuple[str, str, str, bool]] = []
    if has_chunk:
        row_plan.append(("Chunk Generation — by LOD", "", "chunk", True))
    if has_heightmap:
        row_plan.append(("Heightmap Generation", "", "heightmap", True))
    if has_async:
        row_plan.append((
            "Async Loading — Wall Time (ms)", "Async Loading — Throughput (chunks/sec)",
            "async_top", False,
        ))
        row_plan.append((
            "Async Loading — Chunk Latency (ms)", "Async Loading — Speedup (×)",
            "async_bottom", False,
        ))
    if has_pipeline:
        row_plan.append(("Pipeline Timing", "", "pipeline", True))
    if has_cache:
        row_plan.append(("Cache Timing (ms)", "Cache Memory (MB)", "cache", False))
    if has_props:
        row_plan.append(("Prop Placement Timing", "", "props", True))
    if not row_plan:
        raise ValueError("No recognisable benchmark data in the provided files.")

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

    _async_cache: list | None = None
    def _get_async() -> tuple:
        nonlocal _async_cache
        if _async_cache is None:
            _async_cache = list(build_async_traces(runs))
        return tuple(_async_cache)

    for row_idx, (_, _, row_type, _) in enumerate(row_plan, start=1):
        _populate_row(fig, row_idx, row_type, runs, _get_async)

    fig.update_layout(**_layout(runs, len(row_plan)))
    for annotation in fig.layout.annotations:
        annotation.font = dict(size=13, color="#ccccdd")
    return fig


def _populate_row(fig, row_idx, row_type, runs, get_async) -> None:
    if row_type == "chunk":
        keys, data = collect_simple(
            runs, {"chunk_total"}, lambda g, m: f"LOD {m.group(1)}"
        )
        for trace in build_simple_traces(keys, data, runs, "chunk gen"):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)

    elif row_type == "heightmap":
        for trace in build_heightmap_traces(runs):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)

    elif row_type == "async_top":
        wall_t, thru_t, _, _ = get_async()
        for trace in wall_t:
            fig.add_trace(trace, row=row_idx, col=1)
        for trace in thru_t:
            fig.add_trace(trace, row=row_idx, col=2)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)
        fig.update_yaxes(title_text="chunks/sec", row=row_idx, col=2)

    elif row_type == "async_bottom":
        _, _, lat_t, spd_t = get_async()
        for trace in lat_t:
            fig.add_trace(trace, row=row_idx, col=1)
        for trace in spd_t:
            fig.add_trace(trace, row=row_idx, col=2)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)
        fig.update_yaxes(title_text="×", row=row_idx, col=2)

    elif row_type == "pipeline":
        keys, data = collect_simple(
            runs,
            {"pipeline_stage", "pipeline_total"},
            lambda g, m: "total" if g == "pipeline_total" else m.group(1),
        )
        if "total" in keys:
            keys = ["total"] + [k for k in keys if k != "total"]
        for trace in build_simple_traces(keys, data, runs, "pipeline"):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)

    elif row_type == "cache":
        timing_keys, timing, memory = collect_cache(runs)
        for trace in build_simple_traces(timing_keys, timing, runs, "cache"):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)
        for trace in build_simple_traces(sorted(memory), memory, runs, "memory"):
            fig.add_trace(trace, row=row_idx, col=2)
        fig.update_yaxes(title_text="MB", row=row_idx, col=2)

    elif row_type == "props":
        keys, data = collect_simple(
            runs, {"prop_placement"}, lambda g, m: m.group(1)
        )
        _, instance_data = collect_simple(
            runs, {"prop_instance_count"}, lambda g, m: m.group(1)
        )
        extra_hover: dict[str, dict[str, str]] = {}
        for rule_id, run_data in instance_data.items():
            extra_hover[rule_id] = {
                run_label: f"instances — mean: {r.mean:.0f} [CI95: {r.ci95_lower:.0f}–{r.ci95_upper:.0f}]"
                for run_label, r in run_data.items()
            }
        for trace in build_simple_traces(keys, data, runs, "prop", extra_hover=extra_hover):
            fig.add_trace(trace, row=row_idx, col=1)
        fig.update_yaxes(title_text="ms", row=row_idx, col=1)


def _layout(runs: list[Run], n_rows: int) -> dict:
    env_lines = []
    for run in runs:
        e = run.environment
        parts = [p for p in [e.get("cpu_name"), e.get("gpu_name"), e.get("engine_version")] if p]
        if parts:
            env_lines.append(f"<b>{run.label}</b>: {' · '.join(parts)}")
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
            x=1.02, y=1.0,
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