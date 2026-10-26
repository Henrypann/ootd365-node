"""本机晨间命令行。标准输出一份 JSON，并写入 data/morning/{日期}.json。"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from morning.inputs import load_excludes, load_weather, normalize_condition
from morning.paths import DEFAULT_EVENTS, DEFAULT_INDEX, DEFAULT_WEATHER, morning_output
from morning.pick import failure, recommend
from morning.validate import InputError, format_index_errors, index_errors, load_json, morning_errors
from morning.write import dumps, write_atomic

_SEASONS = ("spring", "summer", "autumn", "winter")


def _parse_date(value: str) -> str:
    from datetime import datetime

    try:
        datetime.strptime(value, "%Y-%m-%d")
    except ValueError as exc:
        raise argparse.ArgumentTypeError("日期须为 YYYY-MM-DD") from exc
    return value


def _parse_now(value: str) -> str:
    from datetime import datetime

    try:
        datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc:
        raise argparse.ArgumentTypeError("generated_at 须为 YYYY-MM-DDTHH:MM:SSZ") from exc
    return value


def _parse_temp(value: str) -> float:
    try:
        number = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("气温必须是数字") from exc
    if not math.isfinite(number) or not -80 <= number <= 60:
        raise argparse.ArgumentTypeError("气温必须在 -80 到 60 之间")
    return number


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m morning",
        description=(
            "本机晨间穿搭（V0 刀 2）。按清单规则回答今天穿什么。"
            "不在树莓派 5 上跑模型，不读取图片字节，不访问网络。"
        ),
    )
    parser.add_argument(
        "--index",
        type=Path,
        default=DEFAULT_INDEX,
        help=f"衣橱清单 JSON，默认 {DEFAULT_INDEX}",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="输出 JSON 路径，默认 data/morning/{日期}.json",
    )
    parser.add_argument("--date", type=_parse_date, default=None, help="推荐所针对的本地日期 YYYY-MM-DD")
    parser.add_argument(
        "--now",
        type=_parse_now,
        default=None,
        help="写入 generated_at 的 UTC 时间，格式 YYYY-MM-DDTHH:MM:SSZ",
    )
    parser.add_argument("--season", choices=_SEASONS, default=None, help="只保留 season 含该值的单品")
    parser.add_argument("--temp-c", type=_parse_temp, default=None, help="气温（摄氏度）。不访问天气接口")
    parser.add_argument(
        "--condition",
        default=None,
        help="天气状况英文单词，如 clear、snow。不接受自由句子",
    )
    weather = parser.add_mutually_exclusive_group()
    weather.add_argument("--weather", type=Path, default=None, help="本机天气缓存 JSON。不存在则失败")
    weather.add_argument("--no-weather", action="store_true", help="忽略默认的 data/weather.json")
    events = parser.add_mutually_exclusive_group()
    events.add_argument("--events", type=Path, default=None, help="事件规则 JSON。不存在则失败")
    events.add_argument("--no-events", action="store_true", help="忽略默认的 data/wardrobe-events.json")
    parser.add_argument(
        "--llm",
        action="store_true",
        help="保留开关。V0 默认关闭；传入则拒绝，不读密钥，不调用模型",
    )
    return parser


def _today() -> str:
    from datetime import datetime

    return datetime.now().astimezone().date().isoformat()


def _utcnow() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _resolve(path: Path) -> Path:
    if path.is_absolute():
        return path
    return Path.cwd() / path


def _emit(doc: dict, out: Path) -> int:
    problems = morning_errors(doc)
    if problems and "error" not in doc:
        sys.stderr.write("输出不符合晨间契约，已改为错误结果：" + "；".join(problems) + "\n")
        doc = failure(doc["date"], doc["generated_at"], "内部错误：输出不符合晨间契约，已拒绝写出。")
        problems = morning_errors(doc)
    payload = dumps(doc)
    sys.stdout.write(payload)
    sys.stdout.flush()
    if problems:
        sys.stderr.write("输出不符合晨间契约：" + "；".join(problems) + "\n")
        return 1
    try:
        write_atomic(out, payload)
    except OSError as exc:
        sys.stderr.write(f"无法写出 {out}：{exc.strerror or exc}\n")
        return 1
    return 0


def _finish(doc: dict, out: Path, *, code_if_error: int = 1) -> int:
    status = _emit(doc, out)
    if status != 0:
        return status
    if "error" in doc:
        return code_if_error
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    date = args.date or _today()
    generated_at = args.now or _utcnow()
    out = _resolve(args.out) if args.out is not None else morning_output(date)

    if args.llm:
        doc = failure(
            date,
            generated_at,
            "V0 不调用语言模型。未读取密钥，未发起网络请求。请去掉 --llm，只用规则选衣。",
        )
        return _finish(doc, out, code_if_error=2)

    if args.condition is not None:
        try:
            args.condition = normalize_condition(args.condition)
        except InputError as exc:
            return _finish(failure(date, generated_at, exc.message), out)

    index_path = args.index if args.index.is_absolute() else _resolve(args.index)
    if not index_path.is_file():
        return _finish(failure(date, generated_at, f"找不到衣橱清单：{index_path}"), out)

    try:
        index = load_json(index_path)
    except InputError as exc:
        return _finish(failure(date, generated_at, exc.message), out)

    errors = index_errors(index)
    if errors:
        return _finish(failure(date, generated_at, format_index_errors(errors)), out)

    temp_c = args.temp_c
    condition = args.condition
    season = args.season
    season_source = "命令行" if season is not None else None
    try:
        if args.weather is not None:
            weather_path = _resolve(args.weather)
            if not weather_path.is_file():
                raise InputError(f"找不到天气缓存：{weather_path}")
            file_temp, file_condition, file_season = load_weather(weather_path)
        elif not args.no_weather and DEFAULT_WEATHER.is_file():
            file_temp, file_condition, file_season = load_weather(DEFAULT_WEATHER)
        else:
            file_temp = file_condition = file_season = None
        if temp_c is None:
            temp_c = file_temp
        if condition is None:
            condition = file_condition
        if season is None and file_season is not None:
            season = file_season
            season_source = "天气缓存"
    except InputError as exc:
        return _finish(failure(date, generated_at, exc.message), out)

    events_state = "absent"
    excludes: list[str] = []
    try:
        if args.no_events:
            events_state = "ignored"
        elif args.events is not None:
            events_path = _resolve(args.events)
            if not events_path.is_file():
                raise InputError(f"找不到事件文件：{events_path}")
            excludes = load_excludes(events_path)
            events_state = "used"
        elif DEFAULT_EVENTS.is_file():
            excludes = load_excludes(DEFAULT_EVENTS)
            events_state = "used"
    except InputError as exc:
        return _finish(failure(date, generated_at, exc.message), out)

    doc = recommend(
        index,
        date=date,
        generated_at=generated_at,
        season=season,
        season_source=season_source,
        temp_c=temp_c,
        condition=condition,
        excludes=excludes,
        events_state=events_state,
    )
    return _finish(doc, out)
