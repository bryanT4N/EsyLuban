"""一次性迁移工具：把上游集中式 __tables__.xlsx 的表定义改写为自包含格式。

⚠ 当前不可用，已被禁用。三个已知缺陷：

  1. main() 缩进错误，整段 xlsx 迁移逻辑是不可达代码，直接运行会 NameError。
  2. ensure_export_row() 插入 ##export 行后没有同步位移合并区间，
     导致所有依赖合并单元格的写法（多行嵌套 *field、多级标题）错位一行。
     这曾被 SheetLoadUtil 里一个对称的偏移错误抵消，因而长期无人察觉；
     该错误已于 2026-07 修复，抵消不复存在 —— 现在这个 bug 会直接暴露。
  3. 更严重：insert_rows(1) 后，落进陈旧合并区间的单元格会被 openpyxl
     写成 MergedCell 占位，**值被永久删除**。被删的恰好是字段名/类型名
     这类标题格。已在 examples 里造成 5 处损伤（20 个单元格），
     以上游 luban_examples@879f5c5 为基准逐单元格审计后已补回。

修复它需要：修正缩进、把 continue 之后的逻辑移到正确位置、插行后手工
位移全部合并区间（先快照、unmerge、insert、按新坐标 merge）、保存前
校验每个合并区左上角非空，并补一个「造带合并的表 → 迁移 → 断言值与
合并都正确」的测试。

在此之前不要用它迁移任何工程。要解除禁用，删除下方的 sys.exit 并
自行承担风险。
"""
import csv
import json
import os
import pathlib
import sys
from datetime import datetime
import xml.etree.ElementTree as ET

from openpyxl import load_workbook

# 拒绝执行优于文档警告：注释救不了直接双击运行的人。
if __name__ == "__main__":
    sys.stderr.write(
        "\n[DISABLED] migrate_xlsx.py 当前不可用。\n"
        "  它会在插入 ##export 行时错位合并区间，并永久删除落进旧合并区的单元格值。\n"
        "  详见本文件顶部说明。修复前请勿用于任何工程。\n\n")
    raise SystemExit(2)


ROOT = os.environ.get("LUBAN_ROOT", r"C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban")
ARCHIVE_DIR = os.path.join(ROOT, "TestOutputs", "migration_20260122")
os.makedirs(ARCHIVE_DIR, exist_ok=True)
REPORT_PATH = os.path.join(ARCHIVE_DIR, "migration_report.json")

TABLE_FIELDS_ORDER = [
    "full_name",
    "value_type",
    "index",
    "mode",
    "group",
    "comment",
    "read_schema_from_file",
    "input",
    "output",
    "tags",
]


def split_file_and_sheet(url: str):
    if "@" not in url:
        return url, None
    sheet_sep = url.find("@")
    last_path_sep = url.rfind("/", 0, sheet_sep)
    if last_path_sep >= 0:
        file_path = url[: last_path_sep + 1] + url[sheet_sep + 1 :]
        sheet_name = url[last_path_sep + 1 : sheet_sep]
        return file_path, sheet_name
    return url[sheet_sep + 1 :], url[:sheet_sep]


def norm_path(p: str):
    return os.path.normpath(p).replace("\\", "/")


def compose_meta(record: dict):
    pairs = []
    for key in TABLE_FIELDS_ORDER:
        value = record.get(key, "")
        if value is None:
            value = ""
        value = str(value).strip()
        if not value:
            continue
        value = value.replace("\\", "\\\\").replace("\"", "\\\"")
        pairs.append(f'{key}="{value}"')
    return " & ".join(pairs)


def build_autoimport_meta(file_path: str, data_dir: str):
    if not data_dir:
        return None
    base_name = os.path.splitext(os.path.basename(file_path))[0]
    if not base_name.startswith("#"):
        return None
    raw = base_name[1:]
    if "-" in raw:
        raw = raw.split("-", 1)[0]
    if not raw:
        return None
    if "." in raw:
        raw_namespace, raw_name = raw.rsplit(".", 1)
    else:
        raw_namespace, raw_name = "", raw
    rel = os.path.relpath(file_path, data_dir).replace("\\", "/")
    ns_from_path = os.path.dirname(rel).replace("/", ".").replace("\\", ".")
    ns_from_path = "" if ns_from_path == "." else ns_from_path
    ns = ".".join([p for p in [ns_from_path, raw_namespace] if p])
    table_name = f"Tb{raw_name}"
    if ns:
        full_name = f"{ns}.{table_name}"
        value_type = f"{ns}.{raw_name}"
    else:
        full_name = table_name
        value_type = raw_name
    record = {
        "full_name": full_name,
        "value_type": value_type,
        "index": "",
        "mode": "map",
        "group": "",
        "comment": "",
        "read_schema_from_file": "true",
        "input": rel,
        "output": "",
        "tags": "",
    }
    return compose_meta(record)


def is_excel_file(path: str):
    lower = path.lower()
    return lower.endswith(".xlsx") or lower.endswith(".xls") or lower.endswith(".xlsm") or lower.endswith(".csv")


def parse_tables_xlsx(tables_path: str):
    wb = load_workbook(tables_path, data_only=True)
    table_defs = []
    for ws in wb.worksheets:
        header_row_idx = None
        for r in range(1, ws.max_row + 1):
            v = ws.cell(r, 1).value
            if isinstance(v, str) and v.strip().lower() == "##var":
                header_row_idx = r
                break
        if header_row_idx is None:
            continue
        headers = []
        for c in range(1, ws.max_column + 1):
            v = ws.cell(header_row_idx, c).value
            headers.append((v or "").strip() if isinstance(v, str) else (v or ""))
        data_start = header_row_idx + 1
        while data_start <= ws.max_row:
            first = ws.cell(data_start, 1).value
            if isinstance(first, str) and first.strip().startswith("##"):
                data_start += 1
                continue
            break
        for r in range(data_start, ws.max_row + 1):
            first = ws.cell(r, 1).value
            if isinstance(first, str) and first.strip().startswith("##"):
                break
            row_vals = {}
            empty = True
            for c, h in enumerate(headers, start=1):
                if not h:
                    continue
                v = ws.cell(r, c).value
                if v is None:
                    v = ""
                if isinstance(v, str):
                    v = v.strip()
                row_vals[h] = v
                if str(v).strip():
                    empty = False
            if empty:
                continue
            table_defs.append(row_vals)
    return table_defs


def build_meta_map():
    table_meta = {}
    table_meta_anysheet = {}
    unresolved = []
    tables_files = []
    for dirpath, _, filenames in os.walk(ROOT):
        if "bin" in pathlib.Path(dirpath).parts or "obj" in pathlib.Path(dirpath).parts:
            continue
        for name in filenames:
            if name.lower() == "__tables__.xlsx":
                tables_files.append(os.path.join(dirpath, name))
    tables_files.sort()

    for tables_path in tables_files:
        data_dir = os.path.dirname(tables_path)
        for record in parse_tables_xlsx(tables_path):
            input_raw = str(record.get("input", "") or "").strip()
            full_name = str(record.get("full_name", "") or "").strip()
            if not full_name:
                continue
            meta_str = compose_meta(record)
            inputs = [s.strip() for s in input_raw.split(",") if s.strip()]
            excel_inputs = []
            for inp in inputs:
                file_part, sheet_part = split_file_and_sheet(norm_path(inp))
                abs_path = os.path.join(data_dir, file_part)
                if is_excel_file(file_part):
                    excel_inputs.append((os.path.normpath(abs_path), sheet_part))
            if not excel_inputs:
                unresolved.append({"table": full_name, "input": input_raw, "source": tables_path})
                continue
            target = excel_inputs[0]
            if target[1] is None:
                table_meta_anysheet.setdefault(target[0], []).append({"meta": meta_str, "table": full_name, "source": tables_path})
            else:
                table_meta.setdefault(target, []).append({"meta": meta_str, "table": full_name, "source": tables_path})
    return table_meta, table_meta_anysheet, unresolved


def has_header(ws):
    for r in range(1, min(ws.max_row, 6) + 1):
        v = ws.cell(r, 1).value
        if isinstance(v, str) and v.strip().lower().startswith("##export"):
            continue
        if isinstance(v, str) and v.strip().startswith("##"):
            return True
    return False


def load_luban_confs():
    confs = []
    for dirpath, _, filenames in os.walk(ROOT):
        if "bin" in pathlib.Path(dirpath).parts or "obj" in pathlib.Path(dirpath).parts:
            continue
        for name in filenames:
            if name.lower() == "luban.conf":
                conf_path = os.path.join(dirpath, name)
                try:
                    with open(conf_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    data_dir = data.get("dataDir", "")
                    if data_dir:
                        abs_data_dir = os.path.normpath(os.path.join(dirpath, data_dir))
                        confs.append({"conf_dir": os.path.normpath(dirpath), "data_dir": abs_data_dir})
                except Exception:
                    continue
    confs.sort(key=lambda x: len(x["conf_dir"]), reverse=True)
    return confs


def find_data_dir(confs, file_path):
    file_path = os.path.normpath(file_path)
    for c in confs:
        if file_path.startswith(c["data_dir"] + os.sep):
            return c["data_dir"]
        if file_path.startswith(c["conf_dir"] + os.sep):
            return c["data_dir"]
    return None


def collect_xml_excel_inputs(confs):
    xml_map = {}
    xml_anysheet = {}
    xml_dirs = set()
    for dirpath, _, filenames in os.walk(ROOT):
        if "bin" in pathlib.Path(dirpath).parts or "obj" in pathlib.Path(dirpath).parts:
            continue
        for name in filenames:
            if not name.lower().endswith(".xml"):
                continue
            full_path = os.path.join(dirpath, name)
            data_dir = find_data_dir(confs, full_path)
            if not data_dir:
                continue
            try:
                tree = ET.parse(full_path)
            except Exception:
                continue
            for elem in tree.iter():
                if elem.tag != "table":
                    continue
                input_raw = (elem.attrib.get("input") or "").strip()
                if not input_raw:
                    continue
                inputs = [s.strip() for s in input_raw.split(",") if s.strip()]
                for inp in inputs:
                    file_part, sheet_part = split_file_and_sheet(norm_path(inp))
                    abs_path = os.path.normpath(os.path.join(data_dir, file_part))
                    if os.path.isdir(abs_path):
                        xml_dirs.add(abs_path)
                        continue
                    if not is_excel_file(file_part):
                        continue
                    if sheet_part:
                        xml_map.setdefault((abs_path, sheet_part), []).append(full_path)
                    else:
                        xml_anysheet.setdefault(abs_path, []).append(full_path)
    return xml_map, xml_anysheet, xml_dirs


def ensure_export_row(ws, meta: str, export_flag: str):
    a1 = ws.cell(1, 1).value
    if isinstance(a1, str) and a1.strip().lower().startswith("##export"):
        ws.cell(1, 1).value = export_flag
        if meta is not None:
            ws.cell(1, 2).value = meta
        return
    ws.insert_rows(1)
    ws.cell(1, 1).value = export_flag
    if meta is not None:
        ws.cell(1, 2).value = meta


def migrate_csv(path: str, meta: str, export_flag: str):
    encodings = ["utf-8-sig", "utf-8", "gbk", "latin1"]
    rows = None
    for enc in encodings:
        try:
            with open(path, "r", encoding=enc, newline="") as f:
                rows = list(csv.reader(f))
            break
        except UnicodeDecodeError:
            continue
    if rows is None:
        raise UnicodeDecodeError("utf-8", b"", 0, 1, "unsupported encoding")
    new_header = [export_flag, meta or ""]
    if rows:
        first = rows[0][0].strip().lower() if rows[0] else ""
        if first.startswith("##export"):
            rows[0] = new_header + rows[0][2:]
        else:
            rows.insert(0, new_header)
    else:
        rows = [new_header]
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(rows)


def main():
    meta_map, meta_anysheet, unresolved = build_meta_map()
    confs = load_luban_confs()
    xml_map, xml_anysheet, xml_dirs = collect_xml_excel_inputs(confs)
    migrated = []
    export_false = []
    skipped = []

    for dirpath, _, filenames in os.walk(ROOT):
        if "bin" in pathlib.Path(dirpath).parts or "obj" in pathlib.Path(dirpath).parts:
            continue
        for name in filenames:
            lower = name.lower()
            if not (lower.endswith(".xlsx") or lower.endswith(".xlsm") or lower.endswith(".xls") or lower.endswith(".csv")):
                continue
            full_path = os.path.join(dirpath, name)
            rel_path = os.path.relpath(full_path, ROOT)
            data_dir = find_data_dir(confs, full_path)
            if lower.endswith(".csv"):
                file_key = os.path.normpath(full_path)
                candidates = [(k, v) for k, v in meta_map.items() if os.path.normpath(k[0]) == file_key]
                if candidates:
                    meta = candidates[0][1][0]["meta"]
                    migrate_csv(full_path, meta, "##export")
                    migrated.append({"file": rel_path, "sheet": None, "meta": meta})
                elif file_key in xml_anysheet or (file_key, None) in xml_map or any(file_key.startswith(d + os.sep) for d in xml_dirs):
                    migrate_csv(full_path, "", "##export")
                    migrated.append({"file": rel_path, "sheet": None, "meta": ""})
                else:
                    skipped.append({"file": rel_path, "reason": "no_meta"})
                continue
            wb = load_workbook(full_path)
            is_def_file = lower in ("__beans__.xlsx", "__enums__.xlsx")
        for ws in wb.worksheets:
            if ws.title.lower() in ("__beans__", "__enums__"):
                ensure_export_row(ws, None, "##export")
                migrated.append({"file": rel_path, "sheet": ws.title, "meta": ""})
                continue
                key = (os.path.normpath(full_path), ws.title)
                if key in meta_map:
                    meta = meta_map[key][0]["meta"]
                    ensure_export_row(ws, meta, "##export")
                    migrated.append({"file": rel_path, "sheet": ws.title, "meta": meta})
                elif build_autoimport_meta(full_path, data_dir) and has_header(ws):
                    meta = build_autoimport_meta(full_path, data_dir)
                    ensure_export_row(ws, meta, "##export")
                    migrated.append({"file": rel_path, "sheet": ws.title, "meta": meta})
                elif os.path.normpath(full_path) in meta_anysheet and has_header(ws):
                    meta = meta_anysheet[os.path.normpath(full_path)].pop(0)["meta"]
                    ensure_export_row(ws, meta, "##export")
                    migrated.append({"file": rel_path, "sheet": ws.title, "meta": meta})
                    if not meta_anysheet[os.path.normpath(full_path)]:
                        meta_anysheet.pop(os.path.normpath(full_path), None)
                elif key in xml_map and has_header(ws):
                    ensure_export_row(ws, "", "##export")
                    migrated.append({"file": rel_path, "sheet": ws.title, "meta": ""})
                elif os.path.normpath(full_path) in xml_anysheet and has_header(ws):
                    ensure_export_row(ws, "", "##export")
                    migrated.append({"file": rel_path, "sheet": ws.title, "meta": ""})
                elif any(os.path.normpath(full_path).startswith(d + os.sep) for d in xml_dirs) and has_header(ws):
                    ensure_export_row(ws, "", "##export")
                    migrated.append({"file": rel_path, "sheet": ws.title, "meta": ""})
                elif is_def_file:
                    ensure_export_row(ws, None, "##export")
                    migrated.append({"file": rel_path, "sheet": ws.title, "meta": ""})
                else:
                    a1 = ws.cell(1, 1).value
                    if isinstance(a1, str) and a1.strip().startswith("##"):
                        if isinstance(a1, str) and a1.strip().lower().startswith("##export") and not has_header(ws):
                            ensure_export_row(ws, None, "##export=false")
                            export_false.append({"file": rel_path, "sheet": ws.title})
                        else:
                            ensure_export_row(ws, None, "##export=false")
                            export_false.append({"file": rel_path, "sheet": ws.title})
                    else:
                        skipped.append({"file": rel_path, "sheet": ws.title, "reason": "no_header"})
            wb.save(full_path)

    report = {
        "timestamp": datetime.now().isoformat(),
        "migrated": migrated,
        "export_false": export_false,
        "skipped": skipped,
        "unresolved_tables": unresolved,
        "unassigned_anysheet": meta_anysheet,
        "xml_dirs": sorted(xml_dirs),
    }
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f"migrated:{len(migrated)} export_false:{len(export_false)} skipped:{len(skipped)} unresolved:{len(unresolved)}")


if __name__ == "__main__":
    main()
