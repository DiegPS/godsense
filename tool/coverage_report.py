"""Merge real LCOV runs and report uncovered/unmeasured application sources."""

import argparse
import glob
import json
import re
from pathlib import Path


def directives_only(path):
    # Conservative recognition of barrel files: unknown syntax stays visible
    # as unmeasured. Never strip inline/block comments out of string literals.
    source = "\n".join(line for line in path.read_text(encoding="utf-8-sig").splitlines()
                       if line.strip() and not line.lstrip().startswith("//"))
    directive = r'''(?:import|export)\s+(?:'[^'\\\n]+'|"[^"\\\n]+")(?:(?:\s+as\s+\w+)|(?:\s+(?:show|hide)\s+[\w,\s]+))*\s*;'''
    return bool(source.strip()) and re.fullmatch(rf"(?:\s*{directive})+\s*", source) is not None


def interfaces_only(path):
    source = "\n".join(line for line in path.read_text(encoding="utf-8-sig").splitlines()
                       if line.strip() and not line.lstrip().startswith("//"))
    directive = r'''(?:import|export)\s+(?:'[^'\\\n]+'|"[^"\\\n]+")(?:(?:\s+as\s+\w+)|(?:\s+(?:show|hide)\s+[\w,\s]+))*\s*;'''
    source = re.sub(rf"^\s*(?:{directive}\s*)+", "", source)
    interface = r"abstract\s+interface\s+class\s+\w+\s*\{([^{}]*)\}"
    declarations = list(re.finditer(interface, source))
    if not declarations or re.sub(interface, "", source).strip():
        return False
    method = r"[\w.<>,?\s]+\s+\w+\s*\([^{};=]*\)\s*;"
    return all(re.fullmatch(rf"(?:\s*{method})*\s*", declaration[1]) is not None
               for declaration in declarations)


def collect(paths, root):
    coverage = {}
    for path in paths:
        source = None
        for line in Path(path).read_text(encoding="utf-8-sig").splitlines():
            if line.startswith("SF:"):
                candidate = Path(line[3:].replace("\\", "/"))
                absolute = candidate if candidate.is_absolute() else root / candidate
                try:
                    source = absolute.resolve().relative_to(root).as_posix()
                except ValueError:
                    source = None
                if source is not None and not source.startswith("lib/"):
                    source = None
            elif source and line.startswith("DA:"):
                number, hits, *_ = line[3:].split(",")
                rows = coverage.setdefault(source, {})
                number = int(number)
                rows[number] = rows.get(number, False) or int(hits) > 0
    sources = [p for p in (root / "lib").rglob("*.dart") if not p.name.endswith((".g.dart", ".freezed.dart"))]
    files = []
    for path in sorted(sources):
        name = path.relative_to(root).as_posix()
        rows = coverage.get(name, {})
        files.append({
            "path": name,
            "measured": bool(rows),
            "directives_only": not rows and directives_only(path),
            "interfaces_only": not rows and interfaces_only(path),
            "covered": sum(rows.values()),
            "total": len(rows),
            "missing": sorted(n for n, hit in rows.items() if not hit),
        })
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lcov", nargs="+", help="LCOV files or glob patterns")
    parser.add_argument("--minimum", type=float, default=100)
    parser.add_argument("--output", default="build/testing/coverage-report.json")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    options = parser.parse_args()
    root = Path(options.root).resolve()
    inputs = sorted({p for pattern in options.lcov for p in glob.glob(pattern, recursive=True)})
    if not inputs:
        parser.error("No LCOV input matched; refusing an empty coverage report")
    files = collect(inputs, root)
    covered = sum(row["covered"] for row in files)
    total = sum(row["total"] for row in files)
    percentage = covered * 100 / total if total else 0
    unmeasured = [row["path"] for row in files if not row["measured"] and not row["directives_only"] and not row["interfaces_only"]]
    result = {
        "inputs": inputs,
        "scope": "lib/**/*.dart; excludes generated *.g.dart and *.freezed.dart only",
        "covered": covered,
        "total_measured_lines": total,
        "measured_line_percent": round(percentage, 4),
        "unmeasured_files": unmeasured,
        "non_executable_barrel_files": [row["path"] for row in files if row["directives_only"]],
        "non_executable_interface_files": [row["path"] for row in files if row["interfaces_only"]],
        "target": options.minimum,
        "target_met": bool(total) and percentage >= options.minimum and not unmeasured,
        "files": files,
    }
    destination = root / options.output
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Measured line coverage: {covered}/{total} ({percentage:.2f}%)")
    print(f"Unmeasured source files: {len(unmeasured)}; target: {options.minimum:g}%")
    for row in sorted(files, key=lambda row: len(row["missing"]), reverse=True)[:20]:
        print(f"{len(row['missing']):4d} missing / {row['total']:4d}: {row['path']}")
    print(f"Report: {destination}")
    raise SystemExit(0 if result["target_met"] else 1)


if __name__ == "__main__":
    main()
