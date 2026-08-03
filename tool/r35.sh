#!/usr/bin/env bash
set -euo pipefail

# Canonical Yorks V1 R35 launcher. Keep every R35 define in this one place so
# Chrome, web release and Android release builds cannot drift into a mixed V7
# configuration. Legacy V7 flags are intentionally absent.

usage() {
  cat <<'USAGE'
Usage: ./tool/r35.sh <run|build-web|build-apk> [additional Flutter arguments]

Examples:
  ./tool/r35.sh run
  ./tool/r35.sh build-web
  ./tool/r35.sh build-apk
USAGE
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 64
fi

command="$1"
shift

supabase_url="${SUPABASE_URL:-https://czykuksmlwswjsgotrpo.supabase.co}"
supabase_key="${SUPABASE_ANON_KEY:-sb_publishable_10ZCSxRXuNhS6x-hYOudpg_hMK3VtY6}"

r35_defines=(
  "--dart-define=SUPABASE_URL=${supabase_url}"
  "--dart-define=SUPABASE_ANON_KEY=${supabase_key}"
  '--dart-define=YORKS_V1_FOUNDATION=true'
  '--dart-define=YORKS_V1_PROJECTS=true'
  '--dart-define=YORKS_V1_BOQ=true'
  '--dart-define=YORKS_V1_EXCEL=true'
  '--dart-define=YORKS_V1_REQUESTS=true'
  '--dart-define=YORKS_V1_ARRANGEMENT=true'
  '--dart-define=YORKS_V1_LOGISTICS=true'
  '--dart-define=YORKS_V1_RETURNS_DOCUMENTS=true'
  '--dart-define=YORKS_V1_DOCUMENTS=true'
  '--dart-define=use_arabic=true'
)

case "$command" in
  run)
    exec flutter run -d chrome "${r35_defines[@]}" "$@"
    ;;
  build-web)
    exec flutter build web --release "${r35_defines[@]}" "$@"
    ;;
  build-apk)
    exec flutter build apk --release "${r35_defines[@]}" "$@"
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
