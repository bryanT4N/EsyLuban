import argparse
from pathlib import Path

import openpyxl


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a minimal EsyLuban table template.")
    parser.add_argument("--output", required=True, help="Output .xlsx path")
    parser.add_argument("--full-name", required=True, help="table full_name, e.g. test.TbExample")
    parser.add_argument("--value-type", required=True, help="table value_type, e.g. test.ExampleBean")
    parser.add_argument("--index", default="id", help="index field name (default: id)")
    parser.add_argument("--mode", default="map", help="mode: map/one/list (default: map)")
    parser.add_argument("--field", action="append", default=[], help="field spec name:type (repeatable)")
    args = parser.parse_args()

    output_path = Path(args.output)
    if output_path.suffix.lower() != ".xlsx":
        raise SystemExit("output must be .xlsx")

    fields = []
    for spec in args.field:
        if ":" not in spec:
            raise SystemExit(f"invalid --field '{spec}', expected name:type")
        name, ftype = spec.split(":", 1)
        fields.append((name.strip(), ftype.strip()))

    if not fields:
        fields = [(args.index, "int"), ("name", "string")]

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Sheet1"

    meta = (
        f'full_name="{args.full_name}" & value_type="{args.value_type}" '
        f'& index="{args.index}" & mode="{args.mode}" & read_schema_from_file="false"'
    )
    ws.cell(1, 1).value = "##export"
    ws.cell(1, 2).value = meta

    ws.cell(2, 1).value = "##var"
    ws.cell(3, 1).value = "##type"

    for idx, (name, ftype) in enumerate(fields, start=2):
        ws.cell(2, idx).value = name
        ws.cell(3, idx).value = ftype

    output_path.parent.mkdir(parents=True, exist_ok=True)
    wb.save(output_path)
    print(f"template created: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
