"""第二刀：样本推荐、读取方校验失败，以及输出契约。"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from copy import deepcopy
from io import StringIO
from pathlib import Path
from contextlib import redirect_stderr, redirect_stdout

from morning.cli import main
from morning.paths import ROOT
from morning.validate import (
    cross_field_errors,
    index_errors,
    morning_errors,
    schema_error_lines,
    wardrobe_schema,
)

SAMPLE = ROOT / "examples" / "wardrobe-v1.sample.json"
FIXTURES = ROOT / "tests" / "fixtures"
DATE = "2026-10-26"
NOW = "2026-10-26T00:30:00Z"
SHA = "ab" * 32

SAMPLE_REASONS = [
    "只选 status=active",
    "需要上装和下装",
    "有鞋则选一双",
    "并列时取更低 wear_count",
    "未提供季节，不过滤",
    "未提供天气",
    "无天气，不因寒冷加外搭",
    "已选鞋",
    "事件文件不存在，已跳过",
    "命中清单套装 demo_outfit_monday",
]
SAMPLE_IDS = [
    "demo_item_navy_tee",
    "demo_item_grey_trousers",
    "demo_item_white_sneakers",
]
SAMPLE_TEXT = (
    "今天穿上装 demo_item_navy_tee、下装 demo_item_grey_trousers、鞋 demo_item_white_sneakers。"
)


def make_item(
    item_id: str,
    category: str,
    wear: int = 0,
    season: list[str] | None = None,
    status: str = "active",
    sha: str = SHA,
) -> dict:
    return {
        "id": item_id,
        "category": category,
        "season": ["spring", "summer", "autumn", "winter"] if season is None else season,
        "color": "navy",
        "acquired_at": "1999-01-01",
        "wear_count": wear,
        "wash_count": 0,
        "status": status,
        "cos_keys": [
            {
                "key": f"wardrobe/v1/items/{item_id}/front.jpg",
                "sha256": sha,
            }
        ],
        "updated_at": "2026-01-15T08:00:00Z",
    }


def make_outfit(outfit_id: str, item_ids: list[str], sha: str = "cd" * 32) -> dict:
    return {
        "id": outfit_id,
        "item_ids": item_ids,
        "cos_keys": [
            {
                "key": f"wardrobe/v1/outfits/{outfit_id}/board.jpg",
                "sha256": sha,
            }
        ],
    }


class MorningTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write_index(self, doc: dict, name: str = "wardrobe.json") -> Path:
        path = self.tmp / name
        path.write_text(json.dumps(doc), encoding="utf-8")
        return path

    def run_cli(
        self,
        index: Path,
        extra: list[str] | None = None,
        out: Path | None = None,
    ) -> tuple[int, dict, str, str]:
        destination = out or (self.tmp / "out.json")
        argv = [
            "--index",
            str(index),
            "--out",
            str(destination),
            "--date",
            DATE,
            "--now",
            NOW,
            *(extra or []),
        ]
        stdout = StringIO()
        stderr = StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            code = main(argv)
        raw = stdout.getvalue()
        self.assertTrue(raw.endswith("\n"), raw)
        doc = json.loads(raw)
        self.assertEqual(destination.read_text(encoding="utf-8"), raw)
        self.assertGreater(destination.stat().st_size, 0)
        return code, doc, stderr.getvalue(), raw

    def test_sample_index_passes_reader(self) -> None:
        doc = json.loads(SAMPLE.read_text(encoding="utf-8"))
        self.assertEqual(index_errors(doc), [])

    def test_sample_recommendation_matches_contract(self) -> None:
        before = hashlib.sha256(SAMPLE.read_bytes()).hexdigest()
        code, doc, err, raw = self.run_cli(SAMPLE)
        self.assertEqual(hashlib.sha256(SAMPLE.read_bytes()).hexdigest(), before)
        self.assertEqual(err, "")
        self.assertEqual(code, 0)
        self.assertEqual(doc["date"], DATE)
        self.assertEqual(doc["generated_at"], NOW)
        self.assertEqual(doc["text"], SAMPLE_TEXT)
        self.assertEqual(doc["item_ids"], SAMPLE_IDS)
        self.assertEqual(doc["outfit_id"], "demo_outfit_monday")
        self.assertEqual(doc["reason"], SAMPLE_REASONS)
        self.assertEqual(
            list(doc),
            ["date", "text", "item_ids", "outfit_id", "cos_keys", "reason", "generated_at"],
        )
        index = json.loads(SAMPLE.read_text(encoding="utf-8"))
        by_id = {item["id"]: item for item in index["items"]}
        expected_keys = []
        for item_id in SAMPLE_IDS:
            for entry in by_id[item_id]["cos_keys"]:
                expected_keys.append({"key": entry["key"], "sha256": entry["sha256"]})
        for entry in index["outfits"][0]["cos_keys"]:
            expected_keys.append({"key": entry["key"], "sha256": entry["sha256"]})
        self.assertEqual(doc["cos_keys"], expected_keys)
        for entry in doc["cos_keys"]:
            self.assertEqual(set(entry), {"key", "sha256"})
        serialized = json.dumps(doc, ensure_ascii=False)
        self.assertNotIn("demo_item_black_coat", serialized)
        self.assertNotIn("demo_item_canvas_belt", serialized)
        self.assertNotIn("eeeeeeee", serialized)
        prose = doc["text"] + "\n" + "\n".join(doc["reason"])
        for banned in ("看起来", "颜色", "配色", "好看", "looks like", "color match"):
            self.assertNotIn(banned, prose)
        self.assertNotIn("\\u4eca", raw)
        self.assertEqual(morning_errors(doc), [])
        again, _, _, raw_again = self.run_cli(SAMPLE)
        self.assertEqual(again, 0)
        self.assertEqual(raw_again, raw)

    def test_module_entrypoint_writes_dated_file(self) -> None:
        destination = ROOT / "data" / "morning" / f"{DATE}.json"
        if destination.exists():
            destination.unlink()
        env = os.environ.copy()
        env["PYTHONUTF8"] = "1"
        try:
            proc = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "morning",
                    "--index",
                    "examples/wardrobe-v1.sample.json",
                    "--date",
                    DATE,
                    "--now",
                    NOW,
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertTrue(destination.is_file())
            self.assertEqual(proc.stdout, destination.read_text(encoding="utf-8"))
            doc = json.loads(proc.stdout)
            self.assertEqual(doc["text"], SAMPLE_TEXT)
            self.assertEqual(doc["item_ids"], SAMPLE_IDS)
            self.assertNotIn("item_ids", doc.get("error", ""))
        finally:
            if destination.exists():
                destination.unlink()
            temporary = destination.with_name(destination.name + ".tmp")
            if temporary.exists():
                temporary.unlink()

    def test_invalid_fixtures_fail_without_inventing(self) -> None:
        cases = [
            ("bad-item-cos-key-id.json", ["不等于父 id", "demo_item_navy_tee", "demo_item_grey_trousers"]),
            ("bad-outfit-cos-key-id.json", ["不等于父 id", "demo_outfit_monday", "demo_outfit_other"]),
            ("bad-outfit-item-ref.json", ["未知单品", "demo_item_missing"]),
            ("bad-extra-field.json", ["kind"]),
            ("bad-url-only.json", ["URL", "sha256"]),
        ]
        schema_only_ok = {
            "bad-item-cos-key-id.json",
            "bad-outfit-cos-key-id.json",
            "bad-outfit-item-ref.json",
        }
        for name, needles in cases:
            with self.subTest(name=name):
                path = FIXTURES / name
                loaded = json.loads(path.read_text(encoding="utf-8"))
                if name in schema_only_ok:
                    self.assertEqual(schema_error_lines(loaded, wardrobe_schema()), [])
                    self.assertTrue(cross_field_errors(loaded))
                code, doc, _, _ = self.run_cli(path)
                self.assertEqual(code, 1)
                self.assertEqual(list(doc), ["date", "error", "generated_at"])
                for needle in needles:
                    self.assertIn(needle, doc["error"])

    def test_duplicate_key_and_duplicate_item_id(self) -> None:
        key = "wardrobe/v1/items/demo_item_navy_tee/demo_asset_front.jpg"
        doc = {
            "schema_version": "wardrobe-v1",
            "items": [
                {
                    "id": "demo_item_navy_tee",
                    "category": "top",
                    "season": ["summer"],
                    "color": "navy",
                    "wear_count": 1,
                    "wash_count": 0,
                    "status": "active",
                    "cos_keys": [
                        {"key": key, "sha256": "a" * 64},
                        {"key": key, "sha256": "b" * 64},
                    ],
                    "updated_at": "2026-01-15T08:00:00Z",
                }
            ],
        }
        self.assertEqual(schema_error_lines(doc, wardrobe_schema()), [])
        self.assertTrue(any("重复 key" in line for line in cross_field_errors(doc)))
        code, failure, _, _ = self.run_cli(self.write_index(doc))
        self.assertEqual(code, 1)
        self.assertIn("重复 key", failure["error"])

        duplicated = json.loads(SAMPLE.read_text(encoding="utf-8"))
        duplicated["items"].append(deepcopy(duplicated["items"][0]))
        code, failure, _, _ = self.run_cli(self.write_index(duplicated, "dup.json"))
        self.assertEqual(code, 1)
        self.assertIn("单品 id 重复", failure["error"])

    def test_empty_index_and_season_do_not_invent(self) -> None:
        code, doc, _, _ = self.run_cli(
            self.write_index({"schema_version": "wardrobe-v1", "items": []}),
            extra=["--no-weather", "--no-events"],
        )
        self.assertEqual(code, 1)
        self.assertIn("没有 status=active 的上装", doc["error"])
        self.assertIn("没有 status=active 的下装", doc["error"])
        self.assertIn("未编造", doc["error"])
        self.assertNotIn("item_ids", doc)

        code, doc, _, _ = self.run_cli(SAMPLE, extra=["--season", "summer", "--no-weather", "--no-events"])
        self.assertEqual(code, 1)
        self.assertIn("按季节 summer 过滤后，没有可用的下装", doc["error"])
        self.assertIn("未编造", doc["error"])
        self.assertNotIn("item_ids", doc)
        self.assertNotIn("demo_item_grey_trousers", doc["error"])

    def test_wear_count_and_empty_season(self) -> None:
        tie = {
            "schema_version": "wardrobe-v1",
            "items": [
                make_item("demo_top_b", "top", wear=2),
                make_item("demo_top_a", "top", wear=2),
                make_item("demo_bottom_a", "bottom", wear=1),
            ],
        }
        code, doc, _, _ = self.run_cli(
            self.write_index(tie, "tie.json"),
            extra=["--no-weather", "--no-events"],
        )
        self.assertEqual(code, 0)
        self.assertEqual(doc["item_ids"], ["demo_top_a", "demo_bottom_a"])
        prose = doc["text"] + "\n".join(doc["reason"])
        self.assertNotIn("navy", prose)
        self.assertNotIn("1999", prose)

        lower = {
            "schema_version": "wardrobe-v1",
            "items": [
                make_item("demo_top_a", "top", wear=5),
                make_item("demo_top_m", "top", wear=0),
                make_item("demo_bottom_a", "bottom", wear=1),
            ],
        }
        _, doc, _, _ = self.run_cli(
            self.write_index(lower, "lower.json"),
            extra=["--no-weather", "--no-events"],
        )
        self.assertEqual(doc["item_ids"][0], "demo_top_m")

        unknown = {
            "schema_version": "wardrobe-v1",
            "items": [
                make_item("demo_top_blank", "top", wear=0, season=[]),
                make_item("demo_top_summer", "top", wear=9, season=["summer"]),
                make_item("demo_bottom_summer", "bottom", wear=1, season=["summer"]),
            ],
        }
        _, doc, _, _ = self.run_cli(
            self.write_index(unknown, "season.json"),
            extra=["--season", "summer", "--no-weather", "--no-events"],
        )
        self.assertEqual(doc["item_ids"], ["demo_top_summer", "demo_bottom_summer"])
        self.assertIn("季节：summer（命令行）", doc["reason"])

    def test_cold_outer_skips_retired_and_warm(self) -> None:
        cold = json.loads(SAMPLE.read_text(encoding="utf-8"))
        for item in cold["items"]:
            if item["id"] == "demo_item_black_coat":
                item["status"] = "active"
        path = self.write_index(cold, "cold.json")
        code, doc, _, _ = self.run_cli(path, extra=["--temp-c", "12", "--no-weather", "--no-events"])
        self.assertEqual(code, 0)
        self.assertEqual(
            doc["item_ids"],
            [
                "demo_item_navy_tee",
                "demo_item_grey_trousers",
                "demo_item_black_coat",
                "demo_item_white_sneakers",
            ],
        )
        self.assertNotIn("outfit_id", doc)
        self.assertIn("冷天加外搭", doc["reason"])
        self.assertIn("气温：12°C", doc["reason"])
        self.assertIn("未命中已有套装", doc["reason"])
        coat_key = "wardrobe/v1/items/demo_item_black_coat/demo_asset_front.jpg"
        self.assertIn(coat_key, [entry["key"] for entry in doc["cos_keys"]])
        self.assertNotIn(
            "wardrobe/v1/outfits/demo_outfit_monday/demo_asset_board.jpg",
            [entry["key"] for entry in doc["cos_keys"]],
        )

        _, warm, _, _ = self.run_cli(path, extra=["--temp-c", "12.1", "--no-weather", "--no-events"])
        self.assertNotIn("demo_item_black_coat", warm["item_ids"])
        self.assertEqual(warm["outfit_id"], "demo_outfit_monday")
        self.assertIn("非冷天，不选外搭", warm["reason"])
        self.assertIn("气温：12.1°C", warm["reason"])

        _, snow, _, _ = self.run_cli(
            path,
            extra=["--temp-c", "20", "--condition", "Snow", "--no-weather", "--no-events"],
        )
        self.assertIn("demo_item_black_coat", snow["item_ids"])
        self.assertIn("天气状况：snow", snow["reason"])

        _, rain, _, _ = self.run_cli(
            path,
            extra=["--temp-c", "20", "--condition", "rain", "--no-weather", "--no-events"],
        )
        self.assertNotIn("demo_item_black_coat", rain["item_ids"])

        original = SAMPLE
        _, no_outer, _, _ = self.run_cli(original, extra=["--temp-c", "5", "--no-weather", "--no-events"])
        self.assertNotIn("demo_item_black_coat", no_outer["item_ids"])
        self.assertIn("冷天无可用外搭", no_outer["reason"])
        self.assertEqual(no_outer["outfit_id"], "demo_outfit_monday")

    def test_events_weather_and_secrets_stay_out(self) -> None:
        code, doc, _, raw = self.run_cli(
            SAMPLE,
            extra=["--events", str(self.tmp / "missing-events.json"), "--no-weather"],
        )
        self.assertEqual(code, 1)
        self.assertIn("找不到事件文件", doc["error"])

        events = self.tmp / "events.json"
        events.write_text(json.dumps({"exclude_item_ids": ["demo_item_white_sneakers"]}), encoding="utf-8")
        code, doc, _, _ = self.run_cli(SAMPLE, extra=["--events", str(events), "--no-weather"])
        self.assertEqual(code, 0)
        self.assertNotIn("demo_item_white_sneakers", doc["item_ids"])
        self.assertNotIn("outfit_id", doc)
        self.assertIn("无可用鞋", doc["reason"])
        self.assertIn("事件排除：demo_item_white_sneakers", doc["reason"])
        self.assertIn("未命中已有套装", doc["reason"])

        empty = self.tmp / "empty-events.json"
        empty.write_text("{}", encoding="utf-8")
        _, doc, _, _ = self.run_cli(SAMPLE, extra=["--events", str(empty), "--no-weather"])
        self.assertIn("事件规则无排除", doc["reason"])
        self.assertEqual(doc["outfit_id"], "demo_outfit_monday")

        secret = self.tmp / "secret-weather.json"
        secret.write_text(
            json.dumps({"api_key": "super-secret-value", "temp_c": 8}),
            encoding="utf-8",
        )
        code, doc, err, raw = self.run_cli(SAMPLE, extra=["--weather", str(secret), "--no-events"])
        self.assertEqual(code, 1)
        self.assertIn("未支持字段", doc["error"])
        self.assertNotIn("super-secret-value", raw)
        self.assertNotIn("super-secret-value", err)
        self.assertNotIn("super-secret-value", doc["error"])

        code, doc, _, raw = self.run_cli(SAMPLE, extra=["--condition", "看起来很好", "--no-weather", "--no-events"])
        self.assertEqual(code, 1)
        self.assertNotIn("看起来", raw)
        self.assertIn("天气状况只允许", doc["error"])

        weather = self.tmp / "weather.json"
        weather.write_text(json.dumps({"temp_c": 8, "condition": "Clear"}), encoding="utf-8")
        index = {
            "schema_version": "wardrobe-v1",
            "items": [
                make_item("demo_top_a", "top"),
                make_item("demo_bottom_a", "bottom"),
                make_item("demo_outer_a", "outer", wear=4),
                make_item("demo_outer_b", "outer", wear=1),
                make_item("demo_shoes_a", "shoes", wear=3),
            ],
        }
        path = self.write_index(index, "layers.json")
        _, doc, _, _ = self.run_cli(path, extra=["--weather", str(weather), "--no-events"])
        self.assertEqual(doc["item_ids"], ["demo_top_a", "demo_bottom_a", "demo_outer_b", "demo_shoes_a"])
        self.assertIn("气温：8°C", doc["reason"])
        self.assertIn("天气状况：clear", doc["reason"])
        self.assertIn("冷天加外搭", doc["reason"])

        _, overridden, _, _ = self.run_cli(
            path,
            extra=["--weather", str(weather), "--temp-c", "21", "--condition", "clear", "--no-events"],
        )
        self.assertNotIn("demo_outer_b", overridden["item_ids"])
        self.assertIn("气温：21°C", overridden["reason"])
        self.assertIn("非冷天，不选外搭", overridden["reason"])

    def test_default_weather_file_can_be_ignored(self) -> None:
        from morning.paths import DEFAULT_WEATHER

        DEFAULT_WEATHER.parent.mkdir(parents=True, exist_ok=True)
        DEFAULT_WEATHER.write_text(json.dumps({"temp_c": 1, "condition": "snow"}), encoding="utf-8")
        try:
            _, cold, _, _ = self.run_cli(SAMPLE, extra=["--no-events"])
            self.assertIn("冷天无可用外搭", cold["reason"])
            _, skipped, _, _ = self.run_cli(SAMPLE, extra=["--no-weather", "--no-events"])
            self.assertIn("未提供天气", skipped["reason"])
            self.assertNotIn("demo_item_black_coat", skipped["item_ids"])
        finally:
            DEFAULT_WEATHER.unlink(missing_ok=True)

    def test_missing_index_llm_and_help(self) -> None:
        missing = self.tmp / "nope.json"
        code, doc, _, _ = self.run_cli(missing, extra=["--no-weather", "--no-events"])
        self.assertEqual(code, 1)
        self.assertIn("找不到衣橱清单", doc["error"])

        code, doc, _, raw = self.run_cli(SAMPLE, extra=["--llm", "--no-weather", "--no-events"])
        self.assertEqual(code, 2)
        self.assertIn("语言模型", doc["error"])
        self.assertNotIn("item_ids", doc)
        self.assertNotIn("http", raw)

        stdout = StringIO()
        with redirect_stdout(stdout):
            with self.assertRaises(SystemExit) as caught:
                main(["--help"])
        self.assertEqual(caught.exception.code, 0)
        self.assertIn("树莓派", stdout.getvalue())

    def test_output_schema_rejects_visual_url_and_score(self) -> None:
        base = {
            "date": DATE,
            "text": "今天穿上装 demo_item_navy_tee、下装 demo_item_grey_trousers。",
            "item_ids": ["demo_item_navy_tee", "demo_item_grey_trousers"],
            "cos_keys": [
                {
                    "key": "wardrobe/v1/items/demo_item_navy_tee/demo_asset_front.jpg",
                    "sha256": "a" * 64,
                }
            ],
            "reason": ["只选 status=active"],
            "generated_at": NOW,
        }
        self.assertEqual(morning_errors(base), [])
        visual_text = deepcopy(base)
        visual_text["text"] = "今天穿一件好看的。"
        self.assertTrue(morning_errors(visual_text))
        visual_reason = deepcopy(base)
        visual_reason["reason"] = ["看起来不错"]
        self.assertTrue(morning_errors(visual_reason))
        color_reason = deepcopy(base)
        color_reason["reason"] = ["颜色匹配"]
        self.assertTrue(morning_errors(color_reason))
        url_only = deepcopy(base)
        url_only["cos_keys"] = [{"url": "https://example.invalid/a.jpg"}]
        self.assertTrue(morning_errors(url_only))
        hashless = deepcopy(base)
        hashless["cos_keys"] = [
            {"key": "wardrobe/v1/items/demo_item_navy_tee/demo_asset_front.jpg"}
        ]
        self.assertTrue(morning_errors(hashless))
        scored = deepcopy(base)
        scored["score"] = 0.9
        self.assertTrue(morning_errors(scored))
        weather_card = deepcopy(base)
        weather_card["weather"] = {"temp_c": 1}
        self.assertTrue(morning_errors(weather_card))
        failure = {"date": DATE, "error": "不行", "generated_at": NOW}
        self.assertEqual(morning_errors(failure), [])
        invented = deepcopy(failure)
        invented["item_ids"] = ["demo_item_navy_tee"]
        self.assertTrue(morning_errors(invented))

    def test_lowest_outfit_id_and_empty_cos_keys(self) -> None:
        top = "demo_top_a"
        bottom = "demo_bottom_a"
        index = {
            "schema_version": "wardrobe-v1",
            "items": [
                make_item(top, "top", sha="a" * 64),
                make_item(bottom, "bottom", sha="b" * 64),
            ],
            "outfits": [
                make_outfit("demo_outfit_b", [top, bottom], sha="d" * 64),
                make_outfit("demo_outfit_a", [bottom, top], sha="c" * 64),
            ],
        }
        # 空 cos_keys 的单品仍可入选，且不另造缩略图。
        index["items"][0]["cos_keys"] = []
        index["items"][1]["cos_keys"] = []
        code, doc, _, _ = self.run_cli(
            self.write_index(index, "outfits.json"),
            extra=["--no-weather", "--no-events"],
        )
        self.assertEqual(code, 0)
        self.assertEqual(doc["outfit_id"], "demo_outfit_a")
        self.assertEqual(
            doc["cos_keys"],
            [
                {
                    "key": "wardrobe/v1/outfits/demo_outfit_a/board.jpg",
                    "sha256": "c" * 64,
                }
            ],
        )

    def test_package_does_not_reference_network_or_image_stacks(self) -> None:
        banned = (
            "urllib",
            "requests",
            "httpx",
            "openai",
            "socket",
            "Pillow",
            "cv2",
            "torch",
            "boto",
            "qcloud",
        )
        for path in (ROOT / "morning").glob("*.py"):
            text = path.read_text(encoding="utf-8")
            for word in banned:
                self.assertNotIn(word, text, f"{path.name} contains {word}")
            self.assertNotIn("http://", text)
            self.assertNotIn("https://", text)


if __name__ == "__main__":
    unittest.main()
