"""确定性规则选衣。

只看清单里人填的 status、category、season、wear_count 和 id。
不读颜色，不读图片，不调用模型，不编造清单外的单品。
"""

from __future__ import annotations

from typing import Any

# 气温低于或等于该值视为冷天，有外搭则必须加一件。
COLD_MAX_C = 12
COLD_CONDITIONS = frozenset({"snow", "sleet", "freezing", "cold", "ice"})

_CATEGORY_ZH = {
    "top": "上装",
    "bottom": "下装",
    "outer": "外搭",
    "shoes": "鞋",
}
_PICK_ORDER = ("top", "bottom", "outer", "shoes")


def format_temp(value: float) -> str:
    if value.is_integer():
        return str(int(value))
    return f"{value:.4f}".rstrip("0").rstrip(".")


def is_cold(temp_c: float | None, condition: str | None) -> bool:
    if temp_c is not None and temp_c <= COLD_MAX_C:
        return True
    return condition in COLD_CONDITIONS


def _eligible(
    items: list[dict[str, Any]],
    *,
    excludes: set[str],
    season: str | None,
) -> list[dict[str, Any]]:
    chosen: list[dict[str, Any]] = []
    for item in items:
        if item.get("status") != "active":
            continue
        if item.get("id") in excludes:
            continue
        if season is not None and season not in item.get("season", []):
            continue
        chosen.append(item)
    return chosen


def _best(pool: list[dict[str, Any]]) -> dict[str, Any]:
    return min(pool, key=lambda item: (item["wear_count"], item["id"]))


def _missing_message(
    items: list[dict[str, Any]],
    category: str,
    *,
    excludes: set[str],
    season: str | None,
) -> str:
    label = _CATEGORY_ZH[category]
    active = [item for item in items if item.get("status") == "active" and item.get("category") == category]
    if not active:
        return f"没有 status=active 的{label}"
    kept = [item for item in active if item.get("id") not in excludes]
    if not kept:
        return f"事件排除后，没有可用的{label}"
    if season is not None and not any(season in item.get("season", []) for item in kept):
        return f"按季节 {season} 过滤后，没有可用的{label}"
    return f"没有可用的{label}"


def _season_reasons(season: str | None, season_source: str | None) -> list[str]:
    if season is None:
        return ["未提供季节，不过滤"]
    return [f"季节：{season}（{season_source}）"]


def _weather_reasons(
    temp_c: float | None,
    condition: str | None,
    *,
    cold: bool,
    outer_selected: bool,
) -> list[str]:
    if temp_c is None and condition is None:
        return ["未提供天气", "无天气，不因寒冷加外搭"]
    reasons: list[str] = []
    if temp_c is not None:
        reasons.append(f"气温：{format_temp(temp_c)}°C")
    if condition is not None:
        reasons.append(f"天气状况：{condition}")
    if cold:
        reasons.append("冷天加外搭" if outer_selected else "冷天无可用外搭")
    else:
        reasons.append("非冷天，不选外搭")
    return reasons


def _event_reasons(events_state: str, excludes: list[str]) -> list[str]:
    if events_state == "absent":
        return ["事件文件不存在，已跳过"]
    if events_state == "ignored":
        return ["已忽略事件规则"]
    if not excludes:
        return ["事件规则无排除"]
    return [f"事件排除：{item_id}" for item_id in sorted(excludes)]


def _copy_cos_keys(
    index: dict[str, Any],
    selected: list[dict[str, Any]],
    outfit_id: str | None,
) -> list[dict[str, str]]:
    copied: list[dict[str, str]] = []
    for item in selected:
        for entry in item["cos_keys"]:
            copied.append({"key": entry["key"], "sha256": entry["sha256"]})
    if outfit_id is not None:
        outfit = next(item for item in index.get("outfits") or [] if item["id"] == outfit_id)
        for entry in outfit["cos_keys"]:
            copied.append({"key": entry["key"], "sha256": entry["sha256"]})
    return copied


def _matching_outfit(index: dict[str, Any], selected_ids: list[str]) -> str | None:
    wanted = set(selected_ids)
    matches = [
        outfit
        for outfit in index.get("outfits") or []
        if set(outfit["item_ids"]) == wanted
    ]
    if not matches:
        return None
    matches.sort(key=lambda outfit: outfit["id"])
    return matches[0]["id"]


def recommend(
    index: dict[str, Any],
    *,
    date: str,
    generated_at: str,
    season: str | None,
    season_source: str | None,
    temp_c: float | None,
    condition: str | None,
    excludes: list[str],
    events_state: str,
) -> dict[str, Any]:
    items = list(index.get("items") or [])
    exclude_set = set(excludes)
    pool = _eligible(items, excludes=exclude_set, season=season)
    by_category: dict[str, list[dict[str, Any]]] = {name: [] for name in _PICK_ORDER}
    for item in pool:
        category = item.get("category")
        if category in by_category:
            by_category[category].append(item)

    missing: list[str] = []
    if not by_category["top"]:
        missing.append(_missing_message(items, "top", excludes=exclude_set, season=season))
    if not by_category["bottom"]:
        missing.append(_missing_message(items, "bottom", excludes=exclude_set, season=season))
    if missing:
        return failure(
            date,
            generated_at,
            "无法组成今天的衣服：" + "；".join(missing) + "。未编造任何单品或套装。",
        )

    cold = is_cold(temp_c, condition)
    selected = [_best(by_category["top"]), _best(by_category["bottom"])]
    if cold and by_category["outer"]:
        selected.append(_best(by_category["outer"]))
    if by_category["shoes"]:
        selected.append(_best(by_category["shoes"]))

    # 衣物在前、鞋在后：上装、下装、外搭、鞋。
    order = {name: pos for pos, name in enumerate(_PICK_ORDER)}
    selected.sort(key=lambda item: order[item["category"]])

    selected_ids = [item["id"] for item in selected]
    outfit_id = _matching_outfit(index, selected_ids)
    parts = [f"{_CATEGORY_ZH[item['category']]} {item['id']}" for item in selected]
    reasons = [
        "只选 status=active",
        "需要上装和下装",
        "有鞋则选一双",
        "并列时取更低 wear_count",
        *_season_reasons(season, season_source),
        *_weather_reasons(
            temp_c,
            condition,
            cold=cold,
            outer_selected=any(item["category"] == "outer" for item in selected),
        ),
        "已选鞋" if any(item["category"] == "shoes" for item in selected) else "无可用鞋",
        *_event_reasons(events_state, excludes),
        f"命中清单套装 {outfit_id}" if outfit_id else "未命中已有套装",
    ]
    doc: dict[str, Any] = {
        "date": date,
        "text": "今天穿" + "、".join(parts) + "。",
        "item_ids": selected_ids,
    }
    if outfit_id is not None:
        doc["outfit_id"] = outfit_id
    doc["cos_keys"] = _copy_cos_keys(index, selected, outfit_id)
    doc["reason"] = reasons
    doc["generated_at"] = generated_at
    return doc


def failure(date: str, generated_at: str, message: str) -> dict[str, Any]:
    return {"date": date, "error": message, "generated_at": generated_at}
