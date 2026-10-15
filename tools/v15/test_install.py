"""Run the complete generated V15 installer in an Instance transaction adapter.

All existing source strings come from the supplied HABWAS place. Script bodies
are compiled inside inert wrappers; no attached gameplay code is executed.
"""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

from assemble import ROOT, REPO, FIXTURES, lua, payload, records


def main():
    installer = payload()
    output = Path(os.environ.get("V15_INSTALL_TEST_OUTPUT", str(Path(tempfile.gettempdir()) / "huss-v15-installer-tests")))
    output.mkdir(parents=True, exist_ok=True)
    fixtures = []
    for entry in FIXTURES:
        fixtures.append({"path": entry["path"], "class": entry["class"], "disabled": entry["disabled"], "source": (REPO / entry["source"]).read_text()})
    prefix = (ROOT.parent / "v12/mock_prefix.luau").read_text()
    prefix += "\nlocal ColorSequence={new=function(a,b) return {_kind='ColorSequence',A=a,B=b or a} end}\n"
    prefix += "\nlocal fixtureSources=" + lua(fixtures) + "\nlocal expectedEntries=" + lua(records()) + "\n"
    test = (ROOT / "tests/installer_cases.luau.in").read_text().replace("__INSTALLER__", installer)
    script = output / "installer_cases.luau"
    script.write_text(prefix + test)
    runner = os.environ.get("LUAU") or shutil.which("luau") or "/workspace/.cloud-tools/bin/luau"
    process = subprocess.run([runner, str(script)], capture_output=True, text=True)
    (output / "installer_cases.output").write_text(process.stdout + process.stderr)
    if process.returncode:
        raise SystemExit(process.stdout[-5000:] + process.stderr[-8000:])
    report = json.loads(next(x[len("INSTALL_REPORT "):] for x in process.stdout.splitlines() if x.startswith("INSTALL_REPORT ")))
    report["installer_sha256"] = hashlib.sha256(installer.encode()).hexdigest()
    report["fixture_manifest_sha256"] = hashlib.sha256((ROOT / "fixtures/scripts.json").read_bytes()).hexdigest()
    report["scope"] = "Actual complete generated installer, source-exact uploaded scripts, real lobby Plan/Apply, injected transaction failures. Deterministic Instance adapter; no native Studio rendering or network execution."
    (REPO / "Install-Polish-V15.validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key != "results"}, indent=2))


if __name__ == "__main__":
    main()
