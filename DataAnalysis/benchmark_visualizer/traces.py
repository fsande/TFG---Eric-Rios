"""
Plotly trace builders.

All public functions return lists of traces ready to be added to a figure.
Stacking vs side-by-side layout is controlled via ``offsetgroup`` on each
trace; the figure must be created with ``barmode="stack"``.
"""
import plotly.graph_objects as go

from .collectors import (
    collect_async,
    collect_chunk,
    collect_prop_instances,
    collect_simple,
)
from .config import RUN_PALETTE, SUBSTEP_COLORS
from .classifier import tier_label
from .models import Run

# Colors for the mesh-complexity (vertex/triangle count) chart.
_MESH_COUNT_COLORS: dict[str, str] = {
    "vertices":  "#4C9BE8",
    "triangles": "#E8834C",
}


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def _bar(
    x: list,
    y: list,
    err_lo: list[float],
    err_hi: list[float],
    hover: list[str],
    name: str,
    color: str,
    offset_group: str,
    legend_group: str,
    show_legend: bool = True,
    error_visible: bool = True,
) -> go.Bar:
    """
    Create a single bar trace with optional CI95 error bands and hover stats.

    Traces sharing the same ``offset_group`` stack; different groups appear
    side by side at the same x-position. Traces sharing the same
    ``legend_group`` are toggled together by a single legend click.
    Pass ``error_visible=False`` for deterministic count metrics that carry
    no meaningful variance.
    """
    return go.Bar(
        x=x,
        y=y,
        name=name,
        marker_color=color,
        error_y=dict(
            type="data",
            symmetric=False,
            array=err_hi,
            arrayminus=err_lo,
            visible=error_visible,
            color="rgba(255,255,255,0.30)",
            thickness=1.5,
            width=4,
        ),
        hovertext=hover,
        hoverinfo="text",
        legendgroup=legend_group,
        showlegend=show_legend,
        offsetgroup=offset_group,
    )


def _tier_bars(
    store: dict,
    keys: list[str],
    labels: list[str],
    run_label: str,
    run_suffix: str,
) -> tuple[list[float], list[float], list[float], list[str]]:
    """
    Extract means, CI95 error components, and hover strings for a set of
    keyed Result objects belonging to one run.
    """
    means, los, his, hovers = [], [], [], []
    for key, label in zip(keys, labels):
        r = store.get(key, {}).get(run_label)
        means.append(r.mean    if r else 0.0)
        los.append(r.err_lo    if r else 0.0)
        his.append(r.err_hi    if r else 0.0)
        hovers.append(r.hover(f"{label}{run_suffix}") if r else "no data")
    return means, los, his, hovers


# ---------------------------------------------------------------------------
# Chunk generation
# ---------------------------------------------------------------------------

def build_chunk_traces(runs: list[Run]) -> list:
    """
    Build stacked bar traces for chunk-generation substeps by LOD level,
    plus a diamond scatter overlay showing the ``chunk_gen_lod*`` measured
    total for each run and LOD.
    """
    lods, substeps, data, totals, _ = collect_chunk(runs)
    if not lods:
        return []

    lod_labels = [f"LOD {l}" for l in lods]
    multi = len(runs) > 1
    seen: set[str] = set()
    traces: list = []

    # ── Stacked substep bars ────────────────────────────────────────────────
    for run in runs:
        for substep in substeps:
            color = SUBSTEP_COLORS.get(substep, "#aaaaaa")
            means, los, his, hovers = [], [], [], []
            for lod in lods:
                r = data[lod].get(substep, {}).get(run.label)
                lod_label = f"LOD {lod}"
                hover_label = f"{substep} @ {lod_label}" + (f" [{run.label}]" if multi else "")
                means.append(r.mean   if r else 0.0)
                los.append(r.err_lo   if r else 0.0)
                his.append(r.err_hi   if r else 0.0)
                hovers.append(r.hover(hover_label) if r else f"<b>{hover_label}</b><br>no data")
            legend_name = substep if not multi else f"{substep} [{run.label}]"
            show = substep not in seen or multi
            seen.add(substep)
            traces.append(_bar(
                x=lod_labels, y=means, err_lo=los, err_hi=his, hover=hovers,
                name=legend_name,
                color=color,
                offset_group=run.label,
                legend_group=f"substep_{substep}",
                show_legend=show,
            ))

    # ── Scatter overlay: chunk_gen_lod* measured total ──────────────────────
    for run_idx, run in enumerate(runs):
        ys, hovers = [], []
        for lod in lods:
            r = totals.get(lod, {}).get(run.label)
            ys.append(r.mean if r else None)
            lod_label = f"LOD {lod}"
            hover_label = f"chunk total @ {lod_label}" + (f" [{run.label}]" if multi else "")
            hovers.append(r.hover(hover_label) if r else "no data")

        total_name = "chunk total" if not multi else f"chunk total [{run.label}]"
        traces.append(go.Scatter(
            x=lod_labels,
            y=ys,
            mode="markers",
            name=total_name,
            marker=dict(
                symbol="diamond",
                size=11,
                color="rgba(255,255,255,0.92)",
                line=dict(color=RUN_PALETTE[run_idx % len(RUN_PALETTE)], width=2),
            ),
            hovertext=hovers,
            hoverinfo="text",
            legendgroup=f"chunk_total_{run.label}",
            showlegend=True,
            offsetgroup=run.label,
        ))

    return traces


def build_chunk_mesh_traces(runs: list[Run]) -> list[go.Bar]:
    """
    Build grouped bar traces for vertex and triangle counts per LOD level.

    Vertices and triangles share the same x-axis positions but use different
    ``offsetgroup`` values so they appear side by side rather than stacked.
    Error bars are suppressed because these counts are deterministic.
    """
    _, _, _, _, counts = collect_chunk(runs)
    if not counts:
        return []

    lods = sorted(counts)
    lod_labels = [f"LOD {l}" for l in lods]
    multi = len(runs) > 1

    all_kinds = {k for lod in lods for k in counts[lod]}
    kind_order = ["vertices", "triangles"]
    kinds = [k for k in kind_order if k in all_kinds]
    kinds += sorted(all_kinds - set(kind_order))

    seen: set[str] = set()
    traces: list[go.Bar] = []
    for run in runs:
        for kind in kinds:
            ys, hovers = [], []
            for lod in lods:
                r = counts[lod].get(kind, {}).get(run.label)
                lod_label = f"LOD {lod}"
                hover_label = f"{kind} @ {lod_label}" + (f" [{run.label}]" if multi else "")
                ys.append(int(r.mean) if r else 0)
                hovers.append(
                    f"<b>{hover_label}</b><br>count: {int(r.mean):,}"
                    if r else f"<b>{hover_label}</b><br>no data"
                )
            legend_name = kind if not multi else f"{kind} [{run.label}]"
            show = kind not in seen or multi
            seen.add(kind)
            traces.append(_bar(
                x=lod_labels, y=ys,
                err_lo=[0.0] * len(lods),
                err_hi=[0.0] * len(lods),
                hover=hovers,
                name=legend_name,
                color=_MESH_COUNT_COLORS.get(kind, "#aaaaaa"),
                # Different offsetgroup per kind → side-by-side, not stacked.
                offset_group=f"{run.label}_{kind}",
                legend_group=f"mesh_{kind}",
                show_legend=show,
                error_visible=False,
            ))
    return traces


# ---------------------------------------------------------------------------
# Async loading
# ---------------------------------------------------------------------------

def build_async_traces(
    runs: list[Run],
) -> tuple[list[go.Bar], list[go.Bar], list[go.Bar], list[go.Bar]]:
    """
    Build bar traces for all four async loading metric families.

    Returns ``(wall_traces, throughput_traces, latency_traces, speedup_traces)``.

    Wall time, throughput, and chunk latency share a common set of tier
    x-axis labels (sequential, hw ceiling, etc.).  Speedup metrics use their
    own key space (e.g. ``"hw vs sequential"``) and are returned separately
    for placement in a different subplot column.

    All four trace lists share the same ``legendgroup`` per run, so toggling
    a run in the legend hides it across all four subplots simultaneously.
    """
    tiers, wall, thru, latency, speedup = collect_async(runs)
    multi = len(runs) > 1

    tier_labels   = [tier_label(t) for t in tiers]
    speedup_keys  = sorted(speedup.keys())
    speedup_labels = [tier_label(k) for k in speedup_keys]

    wall_traces: list[go.Bar] = []
    thru_traces: list[go.Bar] = []
    lat_traces:  list[go.Bar] = []
    spd_traces:  list[go.Bar] = []

    for run_idx, run in enumerate(runs):
        color      = RUN_PALETTE[run_idx % len(RUN_PALETTE)]
        run_suffix = f" [{run.label}]" if multi else ""
        lg         = f"run_{run.label}"

        w_m, w_lo, w_hi, w_h = _tier_bars(wall,    tiers,        tier_labels,    run.label, run_suffix)
        t_m, t_lo, t_hi, t_h = _tier_bars(thru,    tiers,        tier_labels,    run.label, run_suffix)
        l_m, l_lo, l_hi, l_h = _tier_bars(latency, tiers,        tier_labels,    run.label, run_suffix)
        s_m, s_lo, s_hi, s_h = _tier_bars(speedup, speedup_keys, speedup_labels, run.label, run_suffix)

        run_name = run.label if multi else "value"

        wall_traces.append(_bar(
            x=tier_labels, y=w_m, err_lo=w_lo, err_hi=w_hi, hover=w_h,
            name=run.label if multi else "wall time",
            color=color, offset_group=run.label, legend_group=lg, show_legend=True,
        ))
        thru_traces.append(_bar(
            x=tier_labels, y=t_m, err_lo=t_lo, err_hi=t_hi, hover=t_h,
            name=run_name, color=color, offset_group=run.label, legend_group=lg, show_legend=False,
        ))
        lat_traces.append(_bar(
            x=tier_labels, y=l_m, err_lo=l_lo, err_hi=l_hi, hover=l_h,
            name=run_name, color=color, offset_group=run.label, legend_group=lg, show_legend=False,
        ))
        spd_traces.append(_bar(
            x=speedup_labels, y=s_m, err_lo=s_lo, err_hi=s_hi, hover=s_h,
            name=run_name, color=color, offset_group=run.label, legend_group=lg, show_legend=False,
        ))

    return wall_traces, thru_traces, lat_traces, spd_traces


# ---------------------------------------------------------------------------
# Generic flat-keyed sections (pipeline, cache, props)
# ---------------------------------------------------------------------------

def build_simple_traces(
    keys: list[str],
    data: dict[str, dict[str, "Result"]],
    runs: list[Run],
    section_name: str,
    extra_hover: dict[str, dict[str, str]] | None = None,
) -> list[go.Bar]:
    """
    Build one bar trace per run for a flat keyed dataset.

    Used for pipeline stages, cache metrics, and prop placement rules, where
    there is no substep hierarchy — each key maps directly to an x-axis label.

    ``extra_hover`` is an optional mapping ``key → run_label → html_snippet``
    whose content is appended to the hover text for matching bars.  Pass
    prop instance-count strings here to surface them in the tooltip without
    cluttering the chart.
    """
    multi = len(runs) > 1
    traces: list[go.Bar] = []
    for run_idx, run in enumerate(runs):
        means, los, his, hovers = [], [], [], []
        for k in keys:
            r = data.get(k, {}).get(run.label)
            run_suffix = f" [{run.label}]" if multi else ""
            means.append(r.mean   if r else 0.0)
            los.append(r.err_lo   if r else 0.0)
            his.append(r.err_hi   if r else 0.0)
            base_hover = r.hover(f"{k}{run_suffix}") if r else f"no data for {k}"
            if extra_hover and k in extra_hover and run.label in extra_hover[k]:
                base_hover += f"<br>{extra_hover[k][run.label]}"
            hovers.append(base_hover)
        traces.append(_bar(
            x=keys, y=means, err_lo=los, err_hi=his, hover=hovers,
            name=run.label if multi else section_name,
            color=RUN_PALETTE[run_idx % len(RUN_PALETTE)],
            offset_group=run.label,
            legend_group=f"run_{run.label}",
            show_legend=True,
        ))
    return traces