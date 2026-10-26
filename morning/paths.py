"""仓库内路径。默认数据文件相对仓库根，不相对当前工作目录。"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

WARDROBE_SCHEMA = ROOT / "schema" / "wardrobe-v1.schema.json"
MORNING_SCHEMA = ROOT / "schema" / "morning-recommendation-v0.schema.json"

DEFAULT_INDEX = ROOT / "data" / "wardrobe-index.json"
DEFAULT_EVENTS = ROOT / "data" / "wardrobe-events.json"
DEFAULT_WEATHER = ROOT / "data" / "weather.json"


def morning_output(date: str) -> Path:
    return ROOT / "data" / "morning" / f"{date}.json"
