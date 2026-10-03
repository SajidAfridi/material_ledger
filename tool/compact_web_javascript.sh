#!/usr/bin/env bash
set -euo pipefail
# Parse/print only: no compression transforms, identifier or property mangling.
# This removes redundant whitespace and ASCII escapes emitted by dart2js while
# retaining runtime names, deferred-module contracts and license comments.
artifact="${1:-build/web/main.dart.js}"
test -s "$artifact"
output="${artifact}.compact.js"
trap 'rm -f "$output" "${output}.map"' EXIT
args=(--format comments=some)
if [[ -f "${artifact}.map" ]]; then
  args+=(--source-map "content=${artifact}.map,filename=main.dart.js,url=main.dart.js.map")
fi
npx --yes terser@5.51.2 "$artifact" "${args[@]}" --output "$output"
node --check "$output"
if [[ -f "${artifact}.map" ]]; then
  test -s "${output}.map"
  mv "${output}.map" "${artifact}.map"
fi
mv "$output" "$artifact"
