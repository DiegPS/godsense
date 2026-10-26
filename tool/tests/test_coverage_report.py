import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "coverage_report.py"
SPEC = importlib.util.spec_from_file_location("coverage_report", SCRIPT)
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)


class CoverageReportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="godsense-coverage-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        (self.root / "lib").mkdir()
        (self.root / "lib" / "app.dart").write_text("void main() {}\n", encoding="utf-8")

    def lcov(self, name, text):
        path = self.root / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_merges_hits_without_double_counting_lines(self):
        first = self.lcov("a.info", "SF:lib/app.dart\nDA:1,0\nDA:2,1\nend_of_record\n")
        second = self.lcov("b.info", "SF:lib/app.dart\nDA:1,3\nDA:2,0\nend_of_record\n")
        result = REPORT.collect([first, second], self.root)
        self.assertEqual(result[0]["covered"], 2)
        self.assertEqual(result[0]["total"], 2)
        self.assertEqual(result[0]["missing"], [])

    def test_retains_missing_sources_and_rejects_paths_outside_project(self):
        (self.root / "lib" / "untested.dart").write_text("void missing() {}", encoding="utf-8")
        data = self.lcov("a.info", "SF:../escape.dart\nDA:1,1\nend_of_record\nSF:lib/app.dart\nDA:1,0\nend_of_record\n")
        result = REPORT.collect([data], self.root)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["missing"], [1])
        self.assertFalse(result[1]["measured"])

    def test_allows_absolute_source_paths_and_exempts_only_generated_sources(self):
        (self.root / "lib" / "generated.g.dart").write_text("generated", encoding="utf-8")
        data = self.lcov("a.info", f"SF:{self.root / 'lib' / 'app.dart'}\nDA:1,1\nend_of_record\n")
        result = REPORT.collect([data], self.root)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["covered"], 1)

    def test_cli_fails_100_percent_target_and_writes_truthful_report(self):
        data = self.lcov("a.info", "SF:lib/app.dart\nDA:1,1\nDA:2,0\nend_of_record\n")
        process = subprocess.run([sys.executable, str(SCRIPT), str(data), "--root", str(self.root)], capture_output=True)
        self.assertEqual(process.returncode, 1)
        result = json.loads((self.root / "build/testing/coverage-report.json").read_text(encoding="utf-8"))
        self.assertEqual(result["measured_line_percent"], 50)
        self.assertFalse(result["target_met"])

    def test_export_only_barrels_have_no_executable_lines_but_still_appear(self):
        (self.root / "lib/barrel.dart").write_text("// public API\nexport 'app.dart' show main;\n", encoding="utf-8")
        data = self.lcov("a.info", "SF:lib/app.dart\nDA:1,1\nend_of_record\n")
        rows = REPORT.collect([data], self.root)
        self.assertTrue(rows[1]["directives_only"])
        process = subprocess.run([sys.executable, str(SCRIPT), str(data), "--root", str(self.root)], capture_output=True)
        self.assertEqual(process.returncode, 0)
        result = json.loads((self.root / "build/testing/coverage-report.json").read_text(encoding="utf-8"))
        self.assertEqual(result["non_executable_barrel_files"], ["lib/barrel.dart"])

    def test_barrel_detection_cannot_hide_declarations_or_strings_containing_comments(self):
        file = self.root / "lib/app.dart"
        for source in ["void main() {}", "export 'other.dart'; void main() {}", "const text = '''\n// comment\nexport 'other.dart';\n''';", "abstract interface class Untested { void run(); }"]:
            file.write_text(source, encoding="utf-8")
            self.assertFalse(REPORT.directives_only(file), source)

    def test_pure_interface_contracts_remain_in_inventory_without_fabricated_hits(self):
        (self.root / "lib/contract.dart").write_text("import 'app.dart';\nabstract interface class Repository { Future<void> save(String data); Future<String?> load(); }", encoding="utf-8")
        data = self.lcov("a.info", "SF:lib/app.dart\nDA:1,1\nend_of_record\n")
        rows = REPORT.collect([data], self.root)
        self.assertTrue(rows[1]["interfaces_only"])
        self.assertEqual(rows[1]["total"], 0)
        self.assertEqual(rows[1]["covered"], 0)
        process = subprocess.run([sys.executable, str(SCRIPT), str(data), "--root", str(self.root)], capture_output=True)
        self.assertEqual(process.returncode, 0)
        result = json.loads((self.root / "build/testing/coverage-report.json").read_text(encoding="utf-8"))
        self.assertEqual(result["non_executable_interface_files"], ["lib/contract.dart"])

    def test_interface_recognition_cannot_hide_executable_members(self):
        path = self.root / "lib/app.dart"
        for source in [
            "abstract interface class X { int answer() => 42; }",
            "abstract interface class X { static final value = run(); }",
            "abstract interface class X { void run(); } void main() {}",
            "abstract interface class X { factory X() = Concrete; }",
            "const text = 'abstract interface class X { void run(); }';",
            "abstract interface class X { void run([String value = 'default']); }",
        ]:
            path.write_text(source, encoding="utf-8")
            self.assertFalse(REPORT.interfaces_only(path), source)


if __name__ == "__main__":
    unittest.main()
