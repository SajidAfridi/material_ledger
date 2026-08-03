#!/usr/bin/env bash
set -euo pipefail

# Canonical Yorks V1 R35 launcher. Keep every R35 define in this one place so
# Chrome, web release and Android release builds cannot drift into a mixed V7
# configuration. Legacy V7 flags are intentionally absent.

usage() {
  cat <<'USAGE'
Usage: ./tool/r35.sh <run|build-web|build-apk> [additional Flutter arguments]

Examples:
  cp tool/r35.env.example .r35.env
  # Edit .r35.env once with the explicit local/staging/production backend.
  ./tool/r35.sh run
  ./tool/r35.sh build-web
  R35_CONFIG_FILE=.r35.staging.env ./tool/r35.sh build-web
USAGE
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 64
fi

command="$1"
shift

# Configuration is deliberately explicit. A missing file is acceptable only
# when CI/operator environment variables already provide the complete pair.
# Never add a shared remote URL/key as a fallback here.
r35_config_file="${R35_CONFIG_FILE:-.r35.env}"
if [[ -f "$r35_config_file" ]]; then
  # This is an operator-owned, ignored key=value file. Its values are passed
  # only as Flutter dart-defines and are never committed or printed.
  # shellcheck disable=SC1090
  source "$r35_config_file"
fi

supabase_url="${SUPABASE_URL:-}"
supabase_key="${SUPABASE_ANON_KEY:-}"
r35_environment="${R35_ENVIRONMENT:-}"

if [[ -z "$r35_environment" ]]; then
  echo "R35_ENVIRONMENT must be local, staging, production, or ci." >&2
  exit 64
fi
case "$r35_environment" in
  local|staging|production|ci) ;;
  *)
    echo "R35_ENVIRONMENT must be local, staging, production, or ci." >&2
    exit 64
    ;;
esac
if [[ -z "$supabase_url" || -z "$supabase_key" ]]; then
  echo "Missing explicit Supabase configuration. Create .r35.env from" >&2
  echo "tool/r35.env.example or set SUPABASE_URL and SUPABASE_ANON_KEY." >&2
  exit 64
fi

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
