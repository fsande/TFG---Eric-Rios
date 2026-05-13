import json
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Result:
    """A single benchmark metric with its statistical summary and raw samples."""
    metric_name: str
    category: str
    mean: float
    ci95_lower: float
    ci95_upper: float
    samples: list[float]
    unit: str
    metadata: dict

    @property
    def err_lo(self) -> float:
        return max(0.0, self.mean - self.ci95_lower)

    @property
    def err_hi(self) -> float:
        return max(0.0, self.ci95_upper - self.mean)

    def hover(self, label: str) -> str:
        n = len(self.samples)
        if n <= 20:
            sample_str = ", ".join(f"{v:.2f}" for v in sorted(self.samples))
        else:
            sample_str = f"{n} samples · min {min(self.samples):.2f} · max {max(self.samples):.2f}"
        return (
            f"<b>{label}</b><br>"
            f"mean: {self.mean:.3f} {self.unit}<br>"
            f"CI95: [{self.ci95_lower:.3f}, {self.ci95_upper:.3f}]<br>"
            f"n={n} · {sample_str}"
        )


@dataclass
class Run:
    """A single benchmark execution loaded from a JSON file."""
    label: str
    results: list[Result] = field(default_factory=list)
    environment: dict = field(default_factory=dict)

    @classmethod
    def from_file(cls, path: Path) -> "Run":
        raw = json.loads(path.read_text())
        run = cls(label=path.stem, environment=raw.get("environment", {}))
        for r in raw.get("results", []):
            mean = r["mean"]
            run.results.append(Result(
                metric_name=r["metric_name"],
                category=r["category"],
                mean=mean,
                ci95_lower=r.get("ci95_lower", mean),
                ci95_upper=r.get("ci95_upper", mean),
                samples=r.get("samples", [mean]),
                unit=r.get("unit", ""),
                metadata=r.get("metadata", {}),
            ))
        return run