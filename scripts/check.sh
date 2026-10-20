#!/usr/bin/env bash
# Runs all automated checks. Usage (from repo root, Git Bash):  bash scripts/check.sh
set -u
cd "$(dirname "$0")/.."

find_tool() {
	if command -v "$1" >/dev/null 2>&1; then command -v "$1"; return; fi
	for dir in "$LOCALAPPDATA/Programs/luau" "$LOCALAPPDATA/Programs/rojo"; do
		if [ -x "$dir/$1.exe" ]; then echo "$dir/$1.exe"; return; fi
	done
	echo ""
}

LUAU=$(find_tool luau)
ANALYZE=$(find_tool luau-analyze)
COMPILE=$(find_tool luau-compile)
ROJO=$(find_tool rojo)
status=0

echo "== Syntax (luau-compile) =="
if [ -n "$COMPILE" ]; then
	count=0
	while IFS= read -r f; do
		count=$((count + 1))
		"$COMPILE" --null "$f" >/dev/null 2>&1 || { "$COMPILE" --null "$f"; status=1; }
	done < <(find src tests -name '*.luau')
	echo "$count files checked"
else
	echo "luau-compile not found (skipped)"
fi

echo "== Type check of pure modules (luau-analyze) =="
if [ -n "$ANALYZE" ]; then
	"$ANALYZE" src/shared/Types.luau src/shared/Config/*.luau src/shared/Data/*.luau \
		src/shared/Progression/*.luau src/shared/Combat/*.luau src/shared/PlayerData/*.luau \
		src/shared/Visual/KaijuGait.luau tests/*.luau \
		&& echo "ok" || status=1
else
	echo "luau-analyze not found (skipped)"
fi

echo "== Unit tests (luau) =="
if [ -n "$LUAU" ]; then
	"$LUAU" tests/run.luau || status=1
else
	echo "luau not found (skipped)"
fi

echo "== Rojo build =="
if [ -n "$ROJO" ]; then
	mkdir -p build
	"$ROJO" build default.project.json -o build/KaijuPark.rbxl || status=1
else
	echo "rojo not found (skipped)"
fi

exit $status
