#!/usr/bin/env python3
"""Generate a small, attributed PlotProof lesson pack from public data APIs."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import io
import json
import math
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterable


COUNTRIES = [
    ("AUS", "澳大利亚", "Australia"),
    ("BRA", "巴西", "Brazil"),
    ("CHN", "中国", "China"),
    ("DEU", "德国", "Germany"),
    ("FRA", "法国", "France"),
    ("GBR", "英国", "United Kingdom"),
    ("IND", "印度", "India"),
    ("JPN", "日本", "Japan"),
    ("KOR", "韩国", "South Korea"),
    ("MEX", "墨西哥", "Mexico"),
    ("USA", "美国", "United States"),
    ("ZAF", "南非", "South Africa"),
]
COUNTRY_NAMES = {code: (zh, en) for code, zh, en in COUNTRIES}
COUNTRY_CODES = [code for code, _, _ in COUNTRIES]
USER_AGENT = "PlotProof-Lesson-Generator/1.0 (+https://github.com/use032026/majia)"


def fetch_bytes(url: str, attempts: int = 3) -> bytes:
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=30) as response:
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status} for {url}")
                return response.read()
        except Exception as error:  # Network failures should preserve the old pack.
            last_error = error
            if attempt + 1 < attempts:
                time.sleep(2**attempt)
    raise RuntimeError(f"Could not fetch {url}: {last_error}")


def fetch_json(url: str) -> Any:
    return json.loads(fetch_bytes(url).decode("utf-8"))


def fetch_csv(url: str) -> list[dict[str, str]]:
    source = fetch_bytes(url).decode("utf-8-sig")
    return list(csv.DictReader(io.StringIO(source)))


def owid_url(slug: str, time_range: str) -> str:
    countries = "~".join(COUNTRY_CODES)
    query = urllib.parse.urlencode(
        {
            "csvType": "filtered",
            "tab": "chart",
            "time": time_range,
            "country": countries,
        }
    )
    return f"https://ourworldindata.org/grapher/{slug}.csv?{query}"


def world_bank_url(indicator: str, start_year: int, end_year: int) -> str:
    countries = ";".join(COUNTRY_CODES)
    return (
        f"https://api.worldbank.org/v2/country/{countries}/indicator/{indicator}"
        f"?date={start_year}:{end_year}&format=json&per_page=1000"
    )


def localized(zh: str, en: str) -> dict[str, str]:
    return {"zh": zh, "en": en}


def source(
    name: str, url: str, license_name: str, attribution: str
) -> dict[str, str]:
    return {
        "name": name,
        "url": url,
        "license": license_name,
        "attribution": attribution,
    }


def lesson(
    *,
    lesson_id: str,
    revision: str,
    kind: str,
    mode: str,
    title: dict[str, str],
    subtitle: dict[str, str],
    claim: dict[str, str],
    prompt: dict[str, str],
    correct_verdict: str,
    explanation: dict[str, str],
    checklist: list[dict[str, str]],
    misconception: dict[str, str],
    values: list[float],
    parameters: dict[str, float],
    lesson_source: dict[str, str],
) -> dict[str, Any]:
    return {
        "id": lesson_id,
        "revision": revision,
        "kind": kind,
        "mode": mode,
        "title": title,
        "subtitle": subtitle,
        "claim": claim,
        "prompt": prompt,
        "correctVerdict": correct_verdict,
        "explanation": explanation,
        "checklist": checklist,
        "misconception": misconception,
        "values": values,
        "parameters": parameters,
        "source": lesson_source,
    }


def rows_by_year(
    rows: Iterable[dict[str, str]], value_column: str
) -> dict[int, dict[str, float]]:
    result: dict[int, dict[str, float]] = {}
    for row in rows:
        code = row.get("Code", "")
        year = row.get("Year", "")
        value = row.get(value_column, "")
        if code not in COUNTRY_NAMES or not year or not value:
            continue
        result.setdefault(int(year), {})[code] = float(value)
    return result


def world_bank_rows(indicator: str, start_year: int, end_year: int) -> tuple[
    dict[int, dict[str, float]], str, str
]:
    url = world_bank_url(indicator, start_year, end_year)
    payload = fetch_json(url)
    if not isinstance(payload, list) or len(payload) != 2 or not payload[1]:
        raise RuntimeError(f"World Bank returned no data for {indicator}")
    result: dict[int, dict[str, float]] = {}
    indicator_name = indicator
    for item in payload[1]:
        value = item.get("value")
        code = item.get("countryiso3code")
        if value is None or code not in COUNTRY_NAMES:
            continue
        year = int(item["date"])
        result.setdefault(year, {})[code] = float(value)
        indicator_name = item.get("indicator", {}).get("value", indicator_name)
    return result, indicator_name, url


def latest_year_with(values: dict[int, dict[str, float]], minimum: int) -> int:
    for year in sorted(values, reverse=True):
        if len(values[year]) >= minimum:
            return year
    raise RuntimeError("No year contains enough comparable observations")


def select_close_pair(values: dict[str, float], rotation: int) -> tuple[str, str]:
    candidates: list[tuple[float, str, str]] = []
    codes = sorted(values)
    for index, first in enumerate(codes):
        for second in codes[index + 1 :]:
            low_code, high_code = sorted(
                (first, second), key=lambda code: values[code]
            )
            low = values[low_code]
            high = values[high_code]
            relative_gap = (high - low) / max(abs(high), 1)
            if 0.002 <= relative_gap <= 0.08:
                candidates.append((relative_gap, low_code, high_code))
    if not candidates:
        raise RuntimeError("No suitable close-value pair was found")
    candidates.sort()
    _, low_code, high_code = candidates[rotation % min(8, len(candidates))]
    return low_code, high_code


def axis_parameters(low: float, high: float, maximum: float) -> dict[str, float]:
    gap = high - low
    initial = max(0.0, math.floor(low - max(3.0, gap * 2)))
    slider_maximum = max(initial, math.floor(low - 0.5))
    return {
        "initial": float(initial),
        "fair": 0.0,
        "min": 0.0,
        "max": float(slider_maximum),
        "axisMaximum": float(maximum),
    }


def correlation(points: list[tuple[float, float]]) -> float:
    x_mean = sum(point[0] for point in points) / len(points)
    y_mean = sum(point[1] for point in points) / len(points)
    numerator = sum((x - x_mean) * (y - y_mean) for x, y in points)
    x_squares = sum((x - x_mean) ** 2 for x, _ in points)
    y_squares = sum((y - y_mean) ** 2 for _, y in points)
    denominator = math.sqrt(x_squares * y_squares)
    if denominator == 0:
        raise RuntimeError("Correlation points have zero variance")
    return numerator / denominator


def rotate_codes(codes: list[str], rotation: int, count: int = 9) -> list[str]:
    ordered = [code for code in COUNTRY_CODES if code in codes]
    offset = rotation % len(ordered)
    return (ordered[offset:] + ordered[:offset])[:count]


def leverage_last(
    points_by_code: dict[str, tuple[float, float]], rotation: int
) -> tuple[list[str], float, float]:
    selected = rotate_codes(list(points_by_code), rotation)
    points = [points_by_code[code] for code in selected]
    all_correlation = correlation(points)
    best_code = max(
        selected,
        key=lambda code: abs(
            all_correlation
            - correlation(
                [points_by_code[item] for item in selected if item != code]
            )
        ),
    )
    ordered = [code for code in selected if code != best_code] + [best_code]
    without_correlation = correlation(
        [points_by_code[code] for code in ordered[:-1]]
    )
    return ordered, all_correlation, without_correlation


def build_owid_axis(revision: str, rotation: int) -> dict[str, Any]:
    slug = "life-expectancy"
    csv_url = owid_url(slug, "latest")
    rows = fetch_csv(csv_url)
    by_year = rows_by_year(rows, "Life expectancy")
    year = latest_year_with(by_year, 8)
    low_code, high_code = select_close_pair(by_year[year], rotation)
    low = round(by_year[year][low_code], 1)
    high = round(by_year[year][high_code], 1)
    low_zh, low_en = COUNTRY_NAMES[low_code]
    high_zh, high_en = COUNTRY_NAMES[high_code]
    parameters = axis_parameters(low, high, 100)
    amplification = 100 / (100 - parameters["initial"])
    metadata = fetch_json(
        f"https://ourworldindata.org/grapher/{slug}.metadata.json"
    )
    citation = metadata.get("chart", {}).get("citation", "Our World in Data")
    return lesson(
        lesson_id=f"remote-owid-axis-{revision.lower()}",
        revision=revision,
        kind="axis",
        mode="axisBaseline",
        title=localized("真实数据，也会被尺度放大", "Real data, amplified scale"),
        subtitle=localized("坐标轴 · 本周公开数据", "Axes · public data this week"),
        claim=localized(
            f"{year} 年，{high_zh}的预期寿命远高于{low_zh}",
            f"In {year}, life expectancy in {high_en} is far higher than in {low_en}",
        ),
        prompt=localized(
            "截断纵轴后的柱高公平支持“远高于”吗？",
            'Does the cropped bar height fairly support "far higher"?',
        ),
        correct_verdict="misleading",
        explanation=localized(
            f"公开数据分别约为 {low:.1f} 与 {high:.1f} 年，相差 {high-low:.1f} 年。当前截断范围把视觉差异放大约 {amplification:.1f} 倍；数据真实不等于呈现方式自动公平。",
            f"The public values are about {low:.1f} and {high:.1f} years, a gap of {high-low:.1f} years. The cropped range amplifies the visual difference about {amplification:.1f} times; real data does not automatically make a presentation fair.",
        ),
        checklist=[
            localized("核对纵轴起点和完整量程", "Check the baseline and full scale"),
            localized("把形容词与实际差值对照", "Compare the wording with the numeric gap"),
        ],
        misconception=localized(
            "因为数据真实就忽略了呈现尺度",
            "Assume real data guarantees a fair scale",
        ),
        values=[low, high],
        parameters=parameters,
        lesson_source=source(
            "Our World in Data",
            f"https://ourworldindata.org/grapher/{slug}",
            "CC BY 4.0; underlying provider terms apply",
            f"Our World in Data; {citation}",
        ),
    )


def build_world_bank_axis(
    revision: str, rotation: int, current_year: int
) -> dict[str, Any]:
    configs = [
        ("IT.NET.USER.ZS", "互联网使用率", "internet use", 100.0),
        ("SP.URB.TOTL.IN.ZS", "城镇人口占比", "urban population share", 100.0),
        ("SP.DYN.LE00.IN", "出生时预期寿命", "life expectancy at birth", 100.0),
    ]
    indicator, indicator_zh, indicator_en, maximum = configs[rotation % len(configs)]
    by_year, indicator_name, api_url = world_bank_rows(
        indicator, current_year - 7, current_year
    )
    year = latest_year_with(by_year, 8)
    low_code, high_code = select_close_pair(by_year[year], rotation // len(configs))
    low = round(by_year[year][low_code], 1)
    high = round(by_year[year][high_code], 1)
    low_zh, low_en = COUNTRY_NAMES[low_code]
    high_zh, high_en = COUNTRY_NAMES[high_code]
    parameters = axis_parameters(low, high, maximum)
    amplification = maximum / (maximum - parameters["initial"])
    return lesson(
        lesson_id=f"remote-world-bank-axis-{revision.lower()}",
        revision=revision,
        kind="axis",
        mode="axisBaseline",
        title=localized("小差值，大柱高", "Small gap, tall bars"),
        subtitle=localized("坐标轴 · 世界银行数据", "Axes · World Bank data"),
        claim=localized(
            f"{year} 年，{high_zh}的{indicator_zh}显著高于{low_zh}",
            f"In {year}, {indicator_en} in {high_en} is dramatically higher than in {low_en}",
        ),
        prompt=localized(
            "当前纵轴是否把差值讲得过头？",
            "Does the current axis overstate the difference?",
        ),
        correct_verdict="misleading",
        explanation=localized(
            f"两项公开数据约为 {low:.1f} 和 {high:.1f}，实际差值 {high-low:.1f}。截断范围使视觉差异约放大 {amplification:.1f} 倍，因此“显著高于”超过了图中数值能支持的程度。",
            f"The public values are about {low:.1f} and {high:.1f}, a gap of {high-low:.1f}. The cropped range amplifies the visual difference about {amplification:.1f} times, so “dramatically higher” goes beyond what the values support.",
        ),
        checklist=[
            localized("先读数值，再比较柱高", "Read the values before comparing bar height"),
            localized("检查来源年份和指标单位", "Check the source year and indicator unit"),
        ],
        misconception=localized(
            "把截断后的柱高当成实际比例",
            "Treat cropped bar height as the real proportion",
        ),
        values=[low, high],
        parameters=parameters,
        lesson_source=source(
            "World Bank",
            api_url,
            "CC BY 4.0",
            f"World Bank, World Development Indicators: {indicator_name}",
        ),
    )


def build_owid_correlation(
    revision: str, rotation: int, current_year: int
) -> dict[str, Any]:
    life_slug = "life-expectancy"
    gdp_slug = "gdp-per-capita-worldbank"
    time_range = f"{current_year - 8}..latest"
    life_rows = rows_by_year(
        fetch_csv(owid_url(life_slug, time_range)), "Life expectancy"
    )
    gdp_rows = rows_by_year(
        fetch_csv(owid_url(gdp_slug, time_range)), "GDP per capita"
    )
    common: dict[int, dict[str, tuple[float, float]]] = {}
    for year in set(life_rows) & set(gdp_rows):
        codes = set(life_rows[year]) & set(gdp_rows[year])
        common[year] = {
            code: (gdp_rows[year][code] / 1000, life_rows[year][code])
            for code in codes
        }
    year = latest_year_with(common, 8)
    ordered, all_r, without_r = leverage_last(common[year], rotation)
    values = [
        round(value, 3)
        for code in ordered
        for value in common[year][code]
    ]
    metadata = fetch_json(
        f"https://ourworldindata.org/grapher/{life_slug}.metadata.json"
    )
    citation = metadata.get("chart", {}).get("citation", "Our World in Data")
    return lesson(
        lesson_id=f"remote-owid-correlation-{revision.lower()}",
        revision=revision,
        kind="correlation",
        mode="correlationOutlier",
        title=localized("收入与寿命的散点", "Income and longevity scatter"),
        subtitle=localized("相关性 · 本周公开数据", "Correlation · public data this week"),
        claim=localized(
            f"{year} 年这些国家中，收入越高，寿命就越稳定地增长",
            f"Across these countries in {year}, higher income consistently means longer life",
        ),
        prompt=localized(
            "一个相关系数足以支持“稳定”吗？",
            "Is one correlation coefficient enough to claim consistency?",
        ),
        correct_verdict="needsContext",
        explanation=localized(
            f"当前样本的相关系数约为 {all_r:.2f}；移除最敏感的数据点后约为 {without_r:.2f}。相关性还受国家选择、年份、遗漏变量和指标定义影响，不能只用一个系数概括。",
            f"The correlation is about {all_r:.2f}; without the most influential point it is about {without_r:.2f}. Country selection, year, omitted variables, and indicator definitions still matter, so one coefficient is not enough.",
        ),
        checklist=[
            localized("比较包含与排除敏感点的结果", "Compare results with and without the influential point"),
            localized("核对样本选择与遗漏变量", "Check sample selection and omitted variables"),
        ],
        misconception=localized(
            "把一个相关系数当成稳定规律",
            "Treat one correlation coefficient as a stable rule",
        ),
        values=values,
        parameters={"initial": 1.0, "fair": 0.0, "min": 0.0, "max": 1.0},
        lesson_source=source(
            "Our World in Data",
            f"https://ourworldindata.org/grapher/{life_slug}",
            "CC BY 4.0; underlying provider terms apply",
            f"Our World in Data; life expectancy: {citation}; GDP per capita: World Bank via OWID",
        ),
    )


def build_world_bank_correlation(
    revision: str, rotation: int, current_year: int
) -> dict[str, Any]:
    configs = [
        (
            "NY.GDP.PCAP.PP.CD",
            "IT.NET.USER.ZS",
            1000.0,
            "人均收入与互联网使用率",
            "income per person and internet use",
        ),
        (
            "SP.URB.TOTL.IN.ZS",
            "IT.NET.USER.ZS",
            1.0,
            "城镇人口占比与互联网使用率",
            "urban population share and internet use",
        ),
    ]
    x_indicator, y_indicator, x_scale, labels_zh, labels_en = configs[
        rotation % len(configs)
    ]
    x_rows, x_name, x_url = world_bank_rows(
        x_indicator, current_year - 7, current_year
    )
    y_rows, y_name, _ = world_bank_rows(
        y_indicator, current_year - 7, current_year
    )
    common: dict[int, dict[str, tuple[float, float]]] = {}
    for year in set(x_rows) & set(y_rows):
        codes = set(x_rows[year]) & set(y_rows[year])
        common[year] = {
            code: (x_rows[year][code] / x_scale, y_rows[year][code])
            for code in codes
        }
    year = latest_year_with(common, 8)
    ordered, all_r, without_r = leverage_last(common[year], rotation)
    values = [
        round(value, 3)
        for code in ordered
        for value in common[year][code]
    ]
    return lesson(
        lesson_id=f"remote-world-bank-correlation-{revision.lower()}",
        revision=revision,
        kind="correlation",
        mode="correlationOutlier",
        title=localized("同向变化不是完整解释", "Moving together is not the full story"),
        subtitle=localized("相关性 · 世界银行数据", "Correlation · World Bank data"),
        claim=localized(
            f"{year} 年样本证明了{labels_zh}存在稳定关系",
            f"The {year} sample proves a stable relationship between {labels_en}",
        ),
        prompt=localized(
            "当前散点和相关系数足以称为“证明”吗？",
            'Are this scatter and coefficient enough to call it "proof"?',
        ),
        correct_verdict="needsContext",
        explanation=localized(
            f"当前相关系数约为 {all_r:.2f}，移除最敏感点后约为 {without_r:.2f}。即使方向没有改变，横截面相关仍不能说明机制、时间顺序或因果。",
            f"The correlation is about {all_r:.2f}, and about {without_r:.2f} without the most influential point. Even if the direction remains, cross-sectional correlation does not establish mechanism, timing, or causation.",
        ),
        checklist=[
            localized("查看散点而不是只读 r", "Inspect the points instead of reading r alone"),
            localized("区分相关、预测与因果", "Separate association, prediction, and causation"),
        ],
        misconception=localized(
            "把横截面相关称为因果证明",
            "Call cross-sectional correlation causal proof",
        ),
        values=values,
        parameters={"initial": 1.0, "fair": 0.0, "min": 0.0, "max": 1.0},
        lesson_source=source(
            "World Bank",
            x_url,
            "CC BY 4.0",
            f"World Bank, World Development Indicators: {x_name}; {y_name}",
        ),
    )


def build_pack(now: dt.datetime) -> dict[str, Any]:
    iso_year, iso_week, _ = now.isocalendar()
    revision = f"{iso_year}-W{iso_week:02d}"
    rotation = iso_year * 53 + iso_week
    lessons = [
        build_owid_axis(revision, rotation),
        build_world_bank_axis(revision, rotation, now.year),
        build_owid_correlation(revision, rotation, now.year),
        build_world_bank_correlation(revision, rotation, now.year),
    ]
    canonical = json.dumps(
        lessons, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return {
        "schemaVersion": 1,
        "revision": revision,
        "generatedAt": now.astimezone(dt.timezone.utc).isoformat().replace(
            "+00:00", "Z"
        ),
        "contentSha256": hashlib.sha256(canonical).hexdigest(),
        "lessons": lessons,
    }


def validate_pack(pack: dict[str, Any]) -> None:
    if pack.get("schemaVersion") != 1:
        raise ValueError("unsupported schema version")
    revision = pack.get("revision")
    lessons = pack.get("lessons")
    if not isinstance(revision, str) or not revision:
        raise ValueError("missing pack revision")
    if not isinstance(lessons, list) or not 1 <= len(lessons) <= 8:
        raise ValueError("lesson count is outside the supported range")
    canonical = json.dumps(
        lessons, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    if hashlib.sha256(canonical).hexdigest() != pack.get("contentSha256"):
        raise ValueError("content checksum mismatch")

    identifiers: set[str] = set()
    for item in lessons:
        lesson_id = item.get("id")
        if (
            not isinstance(lesson_id, str)
            or not lesson_id.startswith("remote-")
            or lesson_id in identifiers
        ):
            raise ValueError(f"invalid or duplicate lesson id: {lesson_id}")
        identifiers.add(lesson_id)
        if item.get("revision") != revision:
            raise ValueError(f"revision mismatch: {lesson_id}")
        kind = item.get("kind")
        mode = item.get("mode")
        if kind == "axis":
            if mode not in {"axisBaseline", "axisPrecision"}:
                raise ValueError(f"unsupported axis mode: {lesson_id}")
        elif kind == "correlation":
            if mode != "correlationOutlier":
                raise ValueError(f"unsupported correlation mode: {lesson_id}")
        else:
            raise ValueError(f"unsupported remote lesson kind: {lesson_id}")

        for field in ("title", "subtitle", "claim", "prompt", "explanation", "misconception"):
            value = item.get(field)
            if not isinstance(value, dict) or not value.get("zh") or not value.get("en"):
                raise ValueError(f"missing localized {field}: {lesson_id}")
        checklist = item.get("checklist")
        if not isinstance(checklist, list) or not 2 <= len(checklist) <= 4:
            raise ValueError(f"invalid checklist: {lesson_id}")
        lesson_source = item.get("source")
        source_url = lesson_source.get("url") if isinstance(lesson_source, dict) else None
        if not isinstance(source_url, str) or not source_url.startswith("https://"):
            raise ValueError(f"invalid source URL: {lesson_id}")

        values = item.get("values")
        parameters = item.get("parameters")
        if (
            not isinstance(values, list)
            or not values
            or any(not isinstance(value, (int, float)) or not math.isfinite(value) for value in values)
            or not isinstance(parameters, dict)
        ):
            raise ValueError(f"invalid numeric payload: {lesson_id}")
        minimum = parameters.get("min")
        initial = parameters.get("initial")
        fair = parameters.get("fair")
        maximum = parameters.get("max")
        if not all(isinstance(value, (int, float)) for value in (minimum, initial, fair, maximum)):
            raise ValueError(f"invalid parameters: {lesson_id}")
        if not (minimum <= initial <= maximum and minimum <= fair <= maximum):
            raise ValueError(f"parameters are outside their range: {lesson_id}")
        if kind == "axis":
            axis_maximum = parameters.get("axisMaximum")
            if (
                len(values) != 2
                or not isinstance(axis_maximum, (int, float))
                or not 0 <= values[0] < values[1] <= axis_maximum
                or maximum >= values[0]
            ):
                raise ValueError(f"invalid axis lesson: {lesson_id}")
        elif len(values) < 6 or len(values) % 2:
            raise ValueError(f"invalid correlation lesson: {lesson_id}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("content/lesson_pack.json"),
    )
    arguments = parser.parse_args()
    pack = build_pack(dt.datetime.now(dt.timezone.utc))
    validate_pack(pack)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(pack, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"wrote {arguments.output} revision={pack['revision']} "
        f"lessons={len(pack['lessons'])} sha256={pack['contentSha256']}"
    )


if __name__ == "__main__":
    main()
