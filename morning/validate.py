"""校验 wardrobe-v1 清单。

JSON Schema 负责字段形状。本模块补上 schema 表达不了的两条：
cos_keys 路径里的 id 必须等于父记录 id；套装 item_ids 必须指向同一份清单里的单品。
这里只读 JSON 文本，不打开任何对象，也不访问网络。
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from typing import Any

from morning.paths import MORNING_SCHEMA, WARDROBE_SCHEMA

try:
    from jsonschema import Draft202012Validator
except ImportError as exc:  # pragma: no cover - 环境缺依赖时的入口提示
    raise SystemExit(
        "缺少依赖 jsonschema。在仓库根目录执行：python -m pip install -r requirements.txt"
    ) from exc

_ITEM_KEY = re.compile(
    r"^wardrobe/v1/items/([a-z0-9][a-z0-9_-]{0,63})/[a-z0-9][a-z0-9_-]{0,63}\.[a-z0-9]{1,8}$"
)
_OUTFIT_KEY = re.compile(
    r"^wardrobe/v1/outfits/([a-z0-9][a-z0-9_-]{0,63})/[a-z0-9][a-z0-9_-]{0,63}\.[a-z0-9]{1,8}$"
)


class InputError(Exception):
    """读取清单、天气或事件文件失败。message 可直接写进 error 字段。"""

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


def load_json(path: Path) -> Any:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise InputError(f"无法读取 {path}：{exc.strerror or exc}") from exc
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise InputError(f"无法解析 JSON {path}：第 {exc.lineno} 行：{exc.msg}") from exc


@lru_cache(maxsize=1)
def wardrobe_schema() -> dict[str, Any]:
    return json.loads(WARDROBE_SCHEMA.read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def morning_schema() -> dict[str, Any]:
    return json.loads(MORNING_SCHEMA.read_text(encoding="utf-8"))


def schema_error_lines(doc: Any, schema: dict[str, Any]) -> list[str]:
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(doc), key=lambda err: (list(err.absolute_path), err.message))
    lines: list[str] = []
    for err in errors:
        loc = "/".join(str(part) for part in err.absolute_path) or "(根)"
        lines.append(f"schema {loc}：{err.message}")
    if len(lines) > 12:
        hidden = len(lines) - 12
        lines = lines[:12]
        lines.append(f"另有 {hidden} 条 schema 错误未列出")
    return lines


def _cos_key_errors(keys: Any, *, parent_id: str, kind: str, owner: str) -> list[str]:
    if not isinstance(keys, list):
        return []
    pattern = _ITEM_KEY if kind == "items" else _OUTFIT_KEY
    errors: list[str] = []
    seen: set[str] = set()
    for index, entry in enumerate(keys):
        if not isinstance(entry, dict):
            continue
        key = entry.get("key")
        if not isinstance(key, str):
            if "url" in entry and "sha256" not in entry:
                errors.append(f"{owner} 的 cos_keys[{index}] 只有 URL，没有 key 与 sha256")
            continue
        if key in seen:
            errors.append(f"{owner} 的 cos_keys[{index}] 重复 key「{key}」")
        seen.add(key)
        match = pattern.fullmatch(key)
        if match is None:
            errors.append(
                f"{owner} 的 cos_keys[{index}].key「{key}」不在 wardrobe/v1/{kind}/{{id}}/ 下"
            )
            continue
        segment = match.group(1)
        if segment != parent_id:
            errors.append(
                f"{owner} 的 cos_keys[{index}].key「{key}」路径 id「{segment}」不等于父 id「{parent_id}」"
            )
        if "sha256" not in entry:
            errors.append(f"{owner} 的 cos_keys[{index}] 缺少 sha256")
    return errors


def cross_field_errors(doc: Any) -> list[str]:
    """键内 id＝父 id，且每条 outfit.item_ids 都能在 items 里找到。"""
    if not isinstance(doc, dict):
        return []
    errors: list[str] = []
    items = doc.get("items")
    known: list[str] = []
    seen_items: set[str] = set()
    if isinstance(items, list):
        for index, item in enumerate(items):
            if not isinstance(item, dict):
                continue
            item_id = item.get("id")
            if isinstance(item_id, str):
                if item_id in seen_items:
                    errors.append(f"单品 id 重复：「{item_id}」（items[{index}]）")
                seen_items.add(item_id)
                known.append(item_id)
                errors.extend(
                    _cos_key_errors(
                        item.get("cos_keys"),
                        parent_id=item_id,
                        kind="items",
                        owner=f"单品 {item_id}",
                    )
                )
    known_set = set(known)
    outfits = doc.get("outfits")
    seen_outfits: set[str] = set()
    if isinstance(outfits, list):
        for index, outfit in enumerate(outfits):
            if not isinstance(outfit, dict):
                continue
            outfit_id = outfit.get("id")
            if not isinstance(outfit_id, str):
                continue
            if outfit_id in seen_outfits:
                errors.append(f"套装 id 重复：「{outfit_id}」（outfits[{index}]）")
            seen_outfits.add(outfit_id)
            item_ids = outfit.get("item_ids")
            if isinstance(item_ids, list):
                for ref in item_ids:
                    if isinstance(ref, str) and ref not in known_set:
                        errors.append(f"套装 {outfit_id} 的 item_ids 含未知单品「{ref}」")
            errors.extend(
                _cos_key_errors(
                    outfit.get("cos_keys"),
                    parent_id=outfit_id,
                    kind="outfits",
                    owner=f"套装 {outfit_id}",
                )
            )
    return errors


def index_errors(doc: Any) -> list[str]:
    errors = schema_error_lines(doc, wardrobe_schema())
    errors.extend(cross_field_errors(doc))
    return errors


def format_index_errors(errors: list[str]) -> str:
    return "清单校验失败：" + "；".join(errors) + "。"


def morning_errors(doc: Any) -> list[str]:
    return schema_error_lines(doc, morning_schema())
