"""把推荐 JSON 原子写入目标路径，避免留下空文件。"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


def dumps(doc: dict[str, Any]) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def write_atomic(path: Path, payload: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(payload, encoding="utf-8")
    os.replace(temporary, path)
