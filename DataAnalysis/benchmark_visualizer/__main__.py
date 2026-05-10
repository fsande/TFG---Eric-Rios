"""
CLI entry point. Run as::

    python -m benchmark_visualizer results.json [results2.json ...]

Outputs ``benchmark_report.html`` in the current directory.
"""

import sys
from pathlib import Path

from .config import OUTPUT_PATH
from .figure import build_figure
from .models import Run


def main() -> None:
    """Parse CLI arguments, load runs, build and write the HTML report."""
    if len(sys.argv) < 2:
        print("Usage: python -m benchmark_visualizer file.json [file2.json ...]")
        sys.exit(1)
    runs: list[Run] = []
    for arg in sys.argv[1:]:
        path = Path(arg)
        if not path.exists():
            print(f"Warning: {path} not found, skipping.")
            continue
        run = Run.from_file(path)
        runs.append(run)
        print(f"Loaded  {path.name}  ({len(run.results)} metrics)")
    if not runs:
        print("No valid files loaded.")
        sys.exit(1)
    print(f"\nBuilding report for {len(runs)} run(s)…")
    fig = build_figure(runs)
    out = Path(OUTPUT_PATH)
    fig.write_html(out, include_plotlyjs="cdn")
    print(f"Written → {out.resolve()}")


if __name__ == "__main__":
    main()
