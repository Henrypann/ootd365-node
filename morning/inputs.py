"""可选的本机天气缓存与事件排除。

不访问网络。文件不存在时由调用方决定跳过。字段未在衣橱 schema 里扩展。
"""

from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any

from morning.validate import InputError, load_json

_CONDITION = re.compile(r"^[A-Za-z][A-Za-z0-9_-]{0,31}$")
_ITEM_ID = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
_SEASONS = frozenset({"spring", "summer", "autumn", "winter"})
_WEATHER_KEYS = frozenset({"temp_c", "condition", "season"})
_EVENT_KEYS = frozenset({"exclude_item_ids"})


def _as_temp(value: Any) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise InputError("天气缓存的 temp_c 必须是数字")
    number = float(value)
    if not math.isfinite(number) or not -80 <= number <= 60:
        raise InputError("天气缓存的 temp_c 必须在 -80 到 60 之间")
    return number


def normalize_condition(value: Any) -> str:
    if not isinstance(value, str) or _CONDITION.fullmatch(value) is None:
        raise InputError("天气状况只允许字母、数字、下划线和连字符")
    return value.lower()


def _as_season(value: Any) -> str:
    if not isinstance(value, str) or value not in _SEASONS:
        raise InputError("季节只允许 spring、summer、autumn、winter")
    return value


def load_weather(path: Path) -> tuple[float | None, str | None, str | None]:
    doc = load_json(path)
    if not isinstance(doc, dict):
        raise InputError("天气缓存必须是 JSON 对象")
    extra = sorted(set(doc) - _WEATHER_KEYS)
    if extra:
        raise InputError("天气缓存含未支持字段：" + "、".join(extra))
    temp = _as_temp(doc["temp_c"]) if "temp_c" in doc else None
    condition = normalize_condition(doc["condition"]) if "condition" in doc else None
    season = _as_season(doc["season"]) if "season" in doc else None
    return temp, condition, season


def load_excludes(path: Path) -> list[str]:
    doc = load_json(path)
    if not isinstance(doc, dict):
        raise InputError("事件文件必须是 JSON 对象")
    extra = sorted(set(doc) - _EVENT_KEYS)
    if extra:
        raise InputError("事件文件含未支持字段：" + "、".join(extra))
    raw = doc.get("exclude_item_ids", [])
    if not isinstance(raw, list):
        raise InputError("事件文件的 exclude_item_ids 必须是数组")
    excludes: list[str] = []
    seen: set[str] = set()
    for entry in raw:
        if not isinstance(entry, str) or _ITEM_ID.fullmatch(entry) is None:
            raise InputError("事件文件的 exclude_item_ids 含非法 id")
        if entry not in seen:
            seen.add(entry)
            excludes.append(entry)
    return excludes
