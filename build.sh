#!/usr/bin/env bash

set -eo pipefail

log() {
  echo >&2 "$*"
}

panic() {
  log "$@"
  exit 1
}

print_usage() {
  set +x
  script_name="$(basename "${BASH_SOURCE[0]}")"
  log "Usage: ${script_name} [-c] [-s] [-h]

Options:
  -c        Clean up temporary stuff
  -s        Serve locally after building
  -h, -?    Print this help and exit
"
}

# ENTRY POINT

# cd to repository root
cd "$(dirname "$(readlink -f -- "$0")")"

assets_dir="./assets"
output_dir="./out"
wasm_exec_url="https://raw.githubusercontent.com/golang/go/go1.18.3/misc/wasm/wasm_exec.js"
task_clean=0
task_serve=0
while getopts csh? opt; do
  case ${opt} in
  c)
    task_clean=1
    ;;
  s)
    task_serve=1
    ;;
  h | \?)
    print_usage
    exit
    ;;
  esac
done
shift $((OPTIND - 1))

if [[ ${task_clean} -gt 0 ]]; then
  log "Cleaning up workspace"
  go clean
  rm -rf "${output_dir}"
fi

# lint go code
go vet

# build wasm
mkdir -p "${output_dir}"
GOARCH="wasm" GOOS="js" go build -o "${output_dir}"/main.wasm

# bundle wasm exec util
if [[ ! -f "${assets_dir}"/wasm_exec.js ]]; then
  curl --location --output "${assets_dir}"/wasm_exec.js --create-dirs --silent ${wasm_exec_url}
fi
# bundle static assets
cp --recursive "${assets_dir}"/* "${output_dir}"
# bundle license
cp "LICENSE" "${output_dir}"

if [[ ${task_serve} -gt 0 ]]; then
  log "Serving at: http://127.0.0.1:8080/"
  docker run -it --rm -p 127.0.0.1:8080:80 -v "${PWD}"/${output_dir}:/usr/share/caddy caddy:2-alpine
fi
