"""
Plotly trace builders.

Stacking vs side-by-side layout is controlled via ``offsetgroup``; the figure
must use ``barmode="stack"``.
"""
import plotly.colors
import plotly.graph_objects as go

from .classifier import tier_label
from .collectors import collect_async, collect_heightmap
from .models import Run

_RUN_PALETTE: list[str] = plotly.colors.qualitative.Plotly
_SUBSTEP_PALETTE: list[str] = plotly.colors.qualitative.Bold


def _bar(
    x, y,
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
    return go.Bar(
        x=x, y=y,
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
    means, los, his, hovers = [], [], [], []
    for key, label in zip(keys, labels):
        r = store.get(key, {}).get(run_label)
        means.append(r.mean if r else 0.0)
        los.append(r.err_lo if r else 0.0)
        his.append(r.err_hi if r else 0.0)
        hovers.append(r.hover(f"{label}{run_suffix}") if r else "no data")
    return means, los, his, hovers


def build_heightmap_traces(runs: list[Run]) -> list:
    """
    Build stacked bar traces for heightmap substeps (one column per run),
    plus a diamond scatter overlay for the ``heightmap_generation`` measured total.

    The total is shown as an overlay only — its value is not included in the
    stacked bars.
    """
    substeps, data, totals = collect_heightmap(runs)
    if not substeps and not totals:
        return []
    run_labels = [run.label for run in runs]
    multi = len(runs) > 1
    traces: list = []
    for substep_idx, substep in enumerate(substeps):
        color = _SUBSTEP_PALETTE[substep_idx % len(_SUBSTEP_PALETTE)]
        means, los, his, hovers = [], [], [], []
        for run in runs:
            r = data[substep].get(run.label)
            label = f"{substep}" + (f" [{run.label}]" if multi else "")
            means.append(r.mean if r else 0.0)
            los.append(r.err_lo if r else 0.0)
            his.append(r.err_hi if r else 0.0)
            hovers.append(r.hover(label) if r else f"<b>{label}</b><br>no data")
        traces.append(_bar(
            x=run_labels, y=means, err_lo=los, err_hi=his, hover=hovers,
            name=substep,
            color=color,
            offset_group="heightmap",
            legend_group=f"heightmap_substep_{substep}",
            show_legend=True,
        ))
    total_ys, total_hovers = [], []
    for run in runs:
        r = totals.get(run.label)
        total_ys.append(r.mean if r else None)
        label = "heightmap total" + (f" [{run.label}]" if multi else "")
        total_hovers.append(r.hover(label) if r else "no data")
    traces.append(go.Scatter(
        x=run_labels,
        y=total_ys,
        mode="markers",
        name="heightmap total",
        marker=dict(
            symbol="diamond",
            size=11,
            color="rgba(255,255,255,0.92)",
            line=dict(color="#ffffff", width=2),
        ),
        hovertext=total_hovers,
        hoverinfo="text",
        legendgroup="heightmap_total",
        showlegend=True,
        offsetgroup="heightmap",
    ))
    return traces


def build_async_traces(
    runs: list[Run],
) -> tuple[list[go.Bar], list[go.Bar], list[go.Bar], list[go.Bar]]:
    """
    Build bar traces for all four async loading metric families.

    Returns ``(wall_traces, throughput_traces, latency_traces, speedup_traces)``.
    All four share the same ``legendgroup`` per run so toggling a run in the
    legend hides it across all subplots simultaneously.
    """
    tiers, wall, thru, latency, speedup = collect_async(runs)
    multi = len(runs) > 1
    tier_labels = [tier_label(t) for t in tiers]
    speedup_keys = sorted(speedup)
    speedup_labels = [tier_label(k) for k in speedup_keys]
    wall_traces: list[go.Bar] = []
    thru_traces: list[go.Bar] = []
    lat_traces: list[go.Bar] = []
    spd_traces: list[go.Bar] = []
    for run_idx, run in enumerate(runs):
        color = _RUN_PALETTE[run_idx % len(_RUN_PALETTE)]
        run_suffix = f" [{run.label}]" if multi else ""
        lg = f"run_{run.label}"
        run_name = run.label if multi else "value"
        w_m, w_lo, w_hi, w_h = _tier_bars(wall,    tiers,        tier_labels,    run.label, run_suffix)
        t_m, t_lo, t_hi, t_h = _tier_bars(thru,    tiers,        tier_labels,    run.label, run_suffix)
        l_m, l_lo, l_hi, l_h = _tier_bars(latency, tiers,        tier_labels,    run.label, run_suffix)
        s_m, s_lo, s_hi, s_h = _tier_bars(speedup, speedup_keys, speedup_labels, run.label, run_suffix)
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


def build_simple_traces(
    keys: list[str],
    data: dict[str, dict[str, "Result"]],
    runs: list[Run],
    section_name: str,
    extra_hover: dict[str, dict[str, str]] | None = None,
) -> list[go.Bar]:
    """
    Build one bar trace per run for a flat keyed dataset.

    Used for pipeline stages, cache metrics, prop placement, and chunk LOD
    totals, where each key maps directly to an x-axis label.

    ``extra_hover`` is an optional ``key → run_label → html_snippet`` mapping
    appended to matching hover tooltips.
    """
    multi = len(runs) > 1
    traces: list[go.Bar] = []
    for run_idx, run in enumerate(runs):
        means, los, his, hovers = [], [], [], []
        for k in keys:
            r = data.get(k, {}).get(run.label)
            run_suffix = f" [{run.label}]" if multi else ""
            means.append(r.mean if r else 0.0)
            los.append(r.err_lo if r else 0.0)
            his.append(r.err_hi if r else 0.0)
            base_hover = r.hover(f"{k}{run_suffix}") if r else f"no data for {k}"
            if extra_hover and k in extra_hover and run.label in extra_hover[k]:
                base_hover += f"<br>{extra_hover[k][run.label]}"
            hovers.append(base_hover)
        traces.append(_bar(
            x=keys, y=means, err_lo=los, err_hi=his, hover=hovers,
            name=run.label if multi else section_name,
            color=_RUN_PALETTE[run_idx % len(_RUN_PALETTE)],
            offset_group=run.label,
            legend_group=f"run_{run.label}",
            show_legend=True,
        ))
    return traces