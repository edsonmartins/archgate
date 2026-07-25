from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any


class Status(str, Enum):
    PASS = "PASS"
    FAIL = "FAIL"
    WARN = "WARN"
    SKIP = "SKIP"
    INFO = "INFO"


@dataclass
class CheckResult:
    id: str
    category: str
    title: str
    status: Status
    detail: str = ""
    duration_ms: int = 0
    evidence: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["status"] = self.status.value
        return d


@dataclass
class Report:
    started_at: str
    finished_at: str = ""
    environment: dict[str, str] = field(default_factory=dict)
    checks: list[CheckResult] = field(default_factory=list)
    summary: dict[str, int] = field(default_factory=dict)

    def finalize(self) -> None:
        self.finished_at = datetime.now(timezone.utc).isoformat()
        counts: dict[str, int] = {s.value: 0 for s in Status}
        for c in self.checks:
            counts[c.status.value] = counts.get(c.status.value, 0) + 1
        self.summary = counts

    def to_dict(self) -> dict[str, Any]:
        return {
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "environment": self.environment,
            "summary": self.summary,
            "checks": [c.to_dict() for c in self.checks],
        }

    @property
    def ok(self) -> bool:
        """True if no FAIL (WARN/SKIP allowed)."""
        return self.summary.get(Status.FAIL.value, 0) == 0
