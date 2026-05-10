"""
benchmark_visualizer — terrain benchmark visualizer package.

Typical usage::

    from benchmark_visualizer.models import Run
    from benchmark_visualizer.figure import build_figure
    from pathlib import Path

    runs = [Run.from_file(p) for p in paths]
    fig  = build_figure(runs)
    fig.write_html("report.html", include_plotlyjs="cdn")
"""
