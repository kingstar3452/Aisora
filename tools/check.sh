#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
python3 -m unittest discover -s tests -p 'test_*.py' -v
node --test tests/*.test.cjs
for script in browser-controller/extension/*.js; do node --check "$script"; done
mkdir -p .local
touch .local/.gdignore
# Godot occasionally exits zero after a GDScript parse error: inspect the log too.
./tools/run_godot.sh --headless --editor --import > .local/import.log 2>&1
cat .local/import.log
if grep -Eq 'SCRIPT ERROR|^ERROR:' .local/import.log; then exit 1; fi
./tools/run_godot.sh --headless --script res://tests/test_companion.gd > .local/godot-tests.log 2>&1
cat .local/godot-tests.log
if grep -Eq 'SCRIPT ERROR|^ERROR:|^FAIL:' .local/godot-tests.log; then exit 1; fi
grep -Eq 'AISORA TESTS: [1-9][0-9]* checks; 0 failures' .local/godot-tests.log
./tools/run_godot.sh --headless --script res://tests/test_phase2.gd > .local/phase2-tests.log 2>&1
cat .local/phase2-tests.log
if grep -Eq 'SCRIPT ERROR|^ERROR:|^FAIL:' .local/phase2-tests.log; then exit 1; fi
grep -Eq 'PHASE 2 TESTS: [1-9][0-9]* checks; 0 failures' .local/phase2-tests.log
python3 tests/live_bridge_smoke.py
