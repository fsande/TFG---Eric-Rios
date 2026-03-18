"""
Global constants and user-configurable overrides for the benchmark visualizer.
"""

GROUPING_OVERRIDES: dict[str, str] = {}
"""
Force a metric into a specific group key, or set to ``"exclude"`` to drop it.

Example::

    GROUPING_OVERRIDES = {
        "my_custom_metric": "pipeline",
        "noisy_metric":     "exclude",
    }
"""

SUBSTEP_COLORS: dict[str, str] = {
    "height_grid":      "#4C9BE8",
    "mesh_build":       "#E8834C",
    "volumes":          "#4CE8D4",
    "normals":          "#4CE87A",
    "tangents":         "#E8D44C",
    "array_mesh_build": "#C44CE8",
}
"""Consistent color per substep name, applied across all LOD levels and runs."""

RUN_PALETTE: list[str] = [
    "#4C9BE8", "#E8834C", "#4CE87A",
    "#E8D44C", "#C44CE8", "#E85C4C",
]
"""Colors cycled per benchmark run when multiple files are loaded."""

OUTPUT_PATH = "benchmark_report.html"
