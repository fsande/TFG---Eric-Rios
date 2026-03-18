"""
benchmark_viz — terrain benchmark visualizer package.

Typical usage::

    from benchmark_viz.models import Run
    from benchmark_viz.figure import build_figure
    from pathlib import Path

    runs = [Run.from_file(p) for p in paths]
    fig  = build_figure(runs)
    fig.write_html("report.html", include_plotlyjs="cdn")
"""
