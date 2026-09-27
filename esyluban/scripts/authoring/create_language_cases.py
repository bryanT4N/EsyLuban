"""Regenerate the multi-language regression corpora.

examples/languages/        one project with l10n.languages=zh,en: map / singleton / list
                           tables with a variant_en overlay, an English-only table, a text
                           table with its own variant_en, and a table no overlay touches.
                           PerLanguageText/ (per_language_text.conf) keeps one text table per
                           language instead of one column per language.
examples/negatives_hard/   the language cases of the must-fail corpus, one data folder and
                           one conf each (the other cases there are not touched).

Every string the regression looks for is ASCII and none contains another, so
run_full_tests_example.bat can tell "the default row" from "the English row" with findstr.

Running it again only rewrites spreadsheets whose cells changed and deletes the ones it no
longer generates. openpyxl stamps the save time into every file, so rewriting all of them
would show the whole corpus as modified in git.

    python esyluban/scripts/authoring/create_language_cases.py
"""
import json
from pathlib import Path

import openpyxl

EXAMPLES = Path(__file__).resolve().parents[2] / "examples"

# spreadsheets this run produced, and the folders it owns (anything else in them is stale)
GENERATED = set()
OWNED_DIRS = []


def cells(wb):
    # an empty string is written as a blank cell and reads back as None
    return [(ws.title, [[None if v == "" else v for v in row] for row in ws.iter_rows(values_only=True)])
            for ws in wb.worksheets]


def book(path, b1, header, types, rows, sheet="Sheet1"):
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = sheet
    ws["A1"] = "##export"
    if b1:
        ws["B1"] = b1
    ws.append(["##var"] + header)
    ws.append(["##type"] + types)
    for row in rows:
        ws.append([None] + row)
    GENERATED.add(path.resolve())
    if path.exists() and cells(openpyxl.load_workbook(path)) == cells(wb):
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    wb.save(path)


def prune_stale():
    for directory in OWNED_DIRS:
        for path in directory.rglob("*.xlsx"):
            if path.resolve() not in GENERATED:
                path.unlink()


def b1(full_name, extra=""):
    meta = f'full_name="{full_name}" & read_schema_from_file="true"'
    return meta + (f" & {extra}" if extra else "")


def conf(path, data_dir, xargs, context_menu=None):
    content = {
        "groups": [{"names": ["c"], "default": True}],
        "schemaFiles": [],
        "dataDir": data_dir,
        "targets": [{"name": "all", "manager": "Tables", "groups": ["c"], "topModule": "cfg"}],
        "xargs": xargs,
    }
    if context_menu:
        content["contextMenu"] = context_menu
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(content, indent=2) + "\n", encoding="utf-8")


def languages_corpus():
    root = EXAMPLES / "languages"
    data = root / "DataTables"
    OWNED_DIRS.append(data)

    item = b1("demo.TbItem")
    header, types = ["id", "name"], ["int", "string"]
    book(data / "item/items.xlsx", item, header, types, [[1, "sword"], [2, "shield"]])
    book(data / "item/variant_en/items.xlsx", item, header, types, [[2, "buckler-en"], [9001, "lantern-en"]])

    motd = b1("demo.TbMotd", 'mode="one"')
    book(data / "cfg/motd.xlsx", motd, ["text"], ["string"], [["welcome"]])
    book(data / "cfg/variant_en/motd.xlsx", motd, ["text"], ["string"], [["hello-en"]])

    news = b1("demo.TbNews", 'mode="list"')
    book(data / "news/news.xlsx", news, ["title"], ["string"], [["news-a"], ["news-b"]])
    book(data / "news/variant_en/news.xlsx", news, ["title"], ["string"], [["headline-en"]])

    event = b1("demo.TbEvent")
    book(data / "event/event.xlsx", event, ["id", "reward"], ["int", "string"], [])
    book(data / "event/variant_en/event.xlsx", event, ["id", "reward"], ["int", "string"], [[1, "event-en"]])

    # the English row refers to an item only English has: validation must see the merged table
    drop = b1("demo.TbDrop")
    book(data / "drop/drops.xlsx", drop, ["id", "item"], ["int", "int#ref=demo.TbItem"], [[1, 1]])
    book(data / "drop/variant_en/drops.xlsx", drop, ["id", "item"], ["int", "int#ref=demo.TbItem"], [[1, 9001]])

    named = b1("demo.TbNamed")
    book(data / "named/named.xlsx", named, ["id", "title"], ["int", "text"], [[1, "/sword"], [2, "/shield"]])
    book(data / "named/variant_en/named.xlsx", named, ["id", "title"], ["int", "text"], [[3, "/lantern"]])

    texts = (["key", "zh", "en"], ["string", "string", "string"])
    book(data / "l10n/texts.xlsx", None, *texts,
         [["/sword", "text-sword-zh", "text-sword-en"], ["/shield", "text-shield-zh", "text-shield-en"]])
    book(data / "l10n/variant_en/texts.xlsx", None, *texts,
         [["/shield", "", "special-shield-en"], ["/lantern", "", "text-lantern-en"]])

    book(data / "other/other.xlsx", b1("demo.TbOther"), header, types, [[1, "other"]])

    conf(root / "Tools/Luban/luban.conf", "../../DataTables", [
        "outputDataDir=../../TestOutputs/data",
        "outputCodeDir=../../TestOutputs/code",
        "l10n.languages=zh,en",
        "l10n.provider=default",
        "l10n.textFile.path=../../DataTables/l10n/texts.xlsx",
        "l10n.textFile.keyFieldName=key",
        "l10n.convertTextKeyToValue=1",
    ], {"data": {"targets": ["all"], "dataTarget": "json",
                 "outputDataDir": {"all": "../../TestOutputs/contextmenu"}}})


def per_language_text():
    """One text table per language instead of one column per language: the default text table
    has only a zh column and English keeps its whole table in variant_en."""
    root = EXAMPLES / "languages"
    data = root / "PerLanguageText"
    OWNED_DIRS.append(data)
    book(data / "named/named.xlsx", b1("demo.TbNamed"), ["id", "title"], ["int", "text"], [[1, "/sword"]])
    book(data / "l10n/texts.xlsx", None, ["key", "zh"], ["string", "string"], [["/sword", "per-sword-zh"]])
    book(data / "l10n/variant_en/texts.xlsx", None, ["key", "en"], ["string", "string"], [["/sword", "per-sword-en"]])
    conf(root / "Tools/Luban/per_language_text.conf", "../../PerLanguageText", [
        "outputDataDir=../../TestOutputs/per_language_text",
        "l10n.languages=zh,en",
        "l10n.provider=default",
        "l10n.textFile.path=../../PerLanguageText/l10n/texts.xlsx",
        "l10n.textFile.keyFieldName=key",
        "l10n.convertTextKeyToValue=1",
    ])


def negative(name, files, languages="zh,en"):
    root = EXAMPLES / "negatives_hard"
    OWNED_DIRS.append(root / "DataTables" / name)
    for relative, meta, rows in files:
        book(root / "DataTables" / name / relative, meta, ["id", "name"], ["int", "string"], rows)
    xargs = [f"outputDataDir=../../TestOutputs/{name}"]
    if languages:
        xargs.append(f"l10n.languages={languages}")
    conf(root / "Tools/Luban" / f"{name}.conf", f"../../DataTables/{name}", xargs)


def negatives():
    t = b1("hard.TbT")
    negative("variant_dup", [("t.xlsx", t, [[1, "a"]]), ("variant_en/t.xlsx", t, [[1, "b"], [1, "c"]])])
    negative("variant_mismatch", [("t.xlsx", t, [[1, "a"]]), ("variant_en/t.xlsx", b1("hard.TbT", 'mode="list"'), [[1, "b"]])])
    negative("no_default", [("t.xlsx", t, [[1, "a"]]), ("variant_en/other.xlsx", b1("hard.TbOther"), [[1, "b"]])])
    negative("undeclared_language", [("t.xlsx", t, [[1, "a"]]), ("variant_fr/t.xlsx", t, [[1, "b"]])])
    negative("nested", [("t.xlsx", t, [[1, "a"]]), ("variant_en/variant_ja/t.xlsx", t, [[1, "b"]])], "zh,en,ja")
    negative("default_language", [("t.xlsx", t, [[1, "a"]]), ("variant_zh/t.xlsx", t, [[1, "b"]])])
    negative("duplicate_language", [("t.xlsx", t, [[1, "a"]])], "zh,en,zh")
    # without l10n.languages a variant_ folder is an ordinary folder, so its copy collides with the default
    negative("forgot_languages", [("t.xlsx", t, [[1, "a"]]), ("variant_en/t.xlsx", t, [[1, "b"]])], None)

    # only the English run fails validation; --strict has to fail the whole export
    root = EXAMPLES / "negatives_hard"
    data = root / "DataTables" / "strict_en"
    OWNED_DIRS.append(data)
    drop = b1("hard.TbDrop")
    book(data / "items.xlsx", b1("hard.TbItem"), ["id", "name"], ["int", "string"], [[1, "a"]])
    book(data / "drops.xlsx", drop, ["id", "item"], ["int", "int#ref=hard.TbItem"], [[1, 1]])
    book(data / "variant_en/drops.xlsx", drop, ["id", "item"], ["int", "int#ref=hard.TbItem"], [[1, 777]])
    conf(root / "Tools/Luban/strict_en.conf", "../../DataTables/strict_en",
         ["outputDataDir=../../TestOutputs/strict_en", "l10n.languages=zh,en"])


if __name__ == "__main__":
    languages_corpus()
    per_language_text()
    negatives()
    prune_stale()
    print("ok")
