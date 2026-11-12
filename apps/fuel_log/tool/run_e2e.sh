#!/usr/bin/env bash
# End-to-end test on the Linux desktop build under a virtual display.
# Leaves test-artifacts/e2e/{result.json,civic.csv,civic.pdf,civic.txt,checksums.txt,run.log}.
set -euo pipefail
cd "$(dirname "$0")/.."
export TZ=America/New_York
ART="$PWD/test-artifacts/e2e"
rm -rf "$ART" && mkdir -p "$ART"
xvfb-run -a flutter test integration_test/app_e2e_test.dart -d linux \
  --dart-define=ARTIFACT_DIR="$ART" 2>&1 | tee "$ART/run.log"
pdftotext -layout "$ART/civic.pdf" "$ART/civic.txt"
grep -q '606.24' "$ART/civic.txt" || { echo "PDF is missing the total cost"; exit 1; }
(cd "$ART" && sha256sum civic.csv > checksums.txt)
# The build as it ships today (Pro free until billing is live, privacy link).
mkdir -p "$ART/free_build"
xvfb-run -a flutter test integration_test/free_build_e2e_test.dart -d linux \
  --dart-define=ARTIFACT_DIR="$ART/free_build" 2>&1 | tee "$ART/free_build/run.log"
python3 -c "import json,sys;d=json.load(open('$ART/free_build/result.json'));print('free build checks passed:',sum(c['pass'] for c in d['checks']),'/',len(d['checks']));sys.exit(0 if d['passed'] else 1)"
python3 -c "import json,sys;d=json.load(open('$ART/result.json'));print('checks passed:',sum(c['pass'] for c in d['checks']),'/',len(d['checks']));sys.exit(0 if d['passed'] else 1)"
