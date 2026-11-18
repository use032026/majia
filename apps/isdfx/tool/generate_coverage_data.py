#!/usr/bin/env python3
"""Build one versioned, offline catalogue from the archived official sources."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "data/sources"


def read(name):
    return json.loads((SOURCES / name).read_text(encoding="utf-8"))


def address(code, name, *, group="", group_name="", parent="", parent_name="",
            kind="code", current=True, name_en=None, source="", source_date=""):
    return dict(code=code, nameZh=name, nameEn=name_en or name,
                groupCode=group, groupNameZh=group_name, groupNameEn=group_name,
                parentCode=parent, parentNameZh=parent_name, parentNameEn=parent_name,
                kind=kind, current=current, sourceId=source, sourceDate=source_date)


def main():
    cn = read("cn/cn-mca-2025-fixture-regions.json")
    supplement = read("cn/cn-mca-current-20261105-supplement.json")
    exceptions = read("cn/cn-identity-prefix-exceptions.json")
    tree = read("cn/cn-mca-2025-mainland31-county-and-above.json")
    records = [r for r in cn["counties"] + cn["prefectureDirectReferences"]
               + supplement["records"] + exceptions["records"] if r["eligible"]]
    mainland = []
    for r in sorted(records, key=lambda r: r["code"]):
        mainland.append(address(
            r["code"], r["name"], group=r["provinceCode"],
            group_name=r["provinceName"],
            parent=r.get("parentCode") or r["provinceCode"],
            parent_name=r.get("parentName") or r["provinceName"],
            kind=r["type"], source=r.get("sourceId", "CN-XIONGAN-2023"),
            source_date=r.get("snapshotDate", r.get("sourceFetchDate", r.get("sourceDate", ""))),
        ))
    assert len(mainland) == 2851 and len({r["code"] for r in mainland}) == 2851
    assert len({r["groupCode"] for r in mainland}) == 31
    assert not any(r["code"] == "350527" for r in mainland)
    assert {"441900", "442000", "460400", "620200", "133100", "653132", "659013"} <= {r["code"] for r in mainland}

    tw = read("hk-mo-tw/tw-regions.json")
    tw_addresses = [address(r["prefix"], r["name_zh"], name_en=r["name_en"],
                            kind="current_region", source="TW-CURRENT-REGIONS")
                    for r in tw["current"]]
    tw_addresses += [address(r["prefix"], r["name_zh"], name_en=r["name_en"],
                             kind="historical_region", current=False,
                             source="TW-HISTORICAL-REGIONS")
                     for r in tw["additional_historical"]]
    assert len(tw_addresses) == 26 and sum(r["current"] for r in tw_addresses) == 22
    regional_rules = {r["region_key"]: r for r in read("hk-mo-tw/rules.json")["jurisdictions"]}

    vn = read("vn/vn-coverage.json")
    provinces = {r["adminCode"]: r for r in vn["currentProvinces34"]}
    vn_addresses = [address(
        r["code"], r["nameVi"], group=r["currentProvinceAdminCode"],
        group_name=provinces[r["currentProvinceAdminCode"]]["nameVi"],
        kind="published_legacy_birthplace_code", source=r["sourceId"],
    ) for r in vn["legacyBirthplaces63"]]
    assert len(vn_addresses) == 63 and len(provinces) == 34
    assert len({r["code"] for r in vn_addresses}) == 63
    assert next(r for r in vn_addresses if r["code"] == "024")["groupCode"] == "24"

    data = {
        "schemaVersion": 1, "asOf": "2026-11-05", "version": "coverage-20261105-v1",
        "mainland": {
            "addresses": mainland,
            "provinces": [{"code": r["code"], "nameZh": r["name"], "nameEn": r["name"]}
                          for r in tree["records"] if r["type"] == "province"],
            "counts": {"provinceCount": 31, "annualCountyEntries": 2845,
                       "currentCountySupplement": 2, "eligibleCountyEntries": 2846,
                       "prefectureReferences": 4, "reportedIdentityExceptions": 1,
                       "totalCandidates": 2851},
            "baselineDate": "2025-12-31", "supplementFetchedAt": "2026-11-05",
            "supplementEffectiveDateUnknown": True,
            "sources": [
                {"title": "民政部 · 行政区划代码年度公布及官方导航", "url": cn["sourceUrl"]},
                {"title": "GB 11643-1999 · 官方托管标准全文", "url": "https://zjw.beijing.gov.cn/Portals/0/zhuanti/fazhan/%E8%BA%AB%E4%BB%BD%E8%AF%81GB11643-1999.pdf"},
                {"title": "雄安新区 · 新生儿身份号码133100编码报道", "url": "https://www.xiongan.gov.cn/2023-11/01/c_1212295926.htm"},
            ],
        },
        "hk": {"rules": regional_rules["HK"], "sources": [
            {"title": "香港政府 · 公开客户端IsHKID算法", "url": "https://booking.covidvaccine.gov.hk/forms/assets/js/application_mo.js"},
            {"title": "香港入境事务处 · 身份证资料说明", "url": "https://www.immd.gov.hk/pdforms/rop133.pdf"},
        ]},
        "mo": {"rules": regional_rules["MO"], "sources": [
            {"title": "澳门 · 第41/2023号行政法规及第23/2002号整合文本", "url": "https://bo.dsaj.gov.mo/bo/i/2023/45/regadm41_cn.asp?printer=1"},
        ]},
        "tw": {"addresses": tw_addresses, "rules": regional_rules["TW"], "sources": [
            {"title": "宜兰市户政 · 身分证编号地区代码", "url": tw["current_source_url"]},
            {"title": "台中太平户政 · 历史26地区编号", "url": tw["historical_source_url"]},
            {"title": "政府公报 · 国民身分证统一编号检查方法（附件6，PDF第179页）", "url": "https://gazette2.nat.gov.tw/EG_FileManager/eguploadpub/eg029234/ch04/type2/gov30/num6/images/Eg01.pdf"},
        ]},
        "vn": {
            "addresses": vn_addresses, "currentProvinces": vn["currentProvinces34"],
            "rules": vn["rules"], "legalStatus": vn["legalStatus"],
            "sources": [{"title": r["id"], "url": r["url"]} for r in vn["sources"]],
            "currentProvinceCount": 34, "publishedBirthplaceCodeCount": 63,
            "newIssuanceConformity": "not_established",
        },
    }
    canonical = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    digest = "sha256:" + hashlib.sha256(canonical.encode()).hexdigest()
    (ROOT / "data").mkdir(exist_ok=True)
    (ROOT / "data/coverage_snapshot.json").write_text(
        json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + "\n")
    # JSON object/array literals are valid const Dart values. Escape interpolation.
    dart_literal = canonical.replace("$", r"\$")
    (ROOT / "lib/domain/coverage_data.g.dart").write_text(
        "// Generated by tool/generate_coverage_data.py. Do not hand edit.\n"
        "import 'dart:convert';\n\n"
        f"const coverageDataHash = '{digest}';\n"
        f"const Map<String, dynamic> coverageSnapshot = {dart_literal};\n"
        "String get coverageSnapshotCanonical => jsonEncode(coverageSnapshot);\n")
    dart = shutil.which("dart")
    if dart:
        subprocess.run([dart, "format", str(ROOT / "lib/domain/coverage_data.g.dart")],
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(json.dumps({"dataHash": digest, "mainlandCandidates": len(mainland),
                      "mainlandProvinces": 31, "taiwanCurrent": 22,
                      "taiwanHistoricalExtra": 4, "vietnamCurrent": 34,
                      "vietnamBirthplaceCodes": 63}, ensure_ascii=False))


if __name__ == "__main__":
    main()
