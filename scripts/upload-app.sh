#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
SERVICE_NAME="${SERVICE_NAME:-sample-webapp}"
NAMESPACE="${NAMESPACE:-demo-apps}"
APP_DIR="${APP_DIR:-samples/webapp}"
POLL_SECONDS="${POLL_SECONDS:-2}"
MAX_POLLS="${MAX_POLLS:-180}"
SKIP_HEALTHCHECK="${SKIP_HEALTHCHECK:-false}"
WAIT_FOR_RESULT="${WAIT_FOR_RESULT:-true}"

usage() {
  cat <<EOF
Usage: scripts/upload-app.sh [options]

Options:
  --api-url URL          Upload API base URL (default: ${API_URL})
  --service NAME         Knative service name (default: ${SERVICE_NAME})
  --namespace NAME       Target namespace (default: ${NAMESPACE})
  --app-dir PATH         App directory to bundle (default: ${APP_DIR})
  --poll-seconds N       Poll interval seconds (default: ${POLL_SECONDS})
  --max-polls N          Max poll attempts (default: ${MAX_POLLS})
  --skip-healthcheck     Skip API /healthz probe
  --no-wait              Return after upload acceptance without polling
  -h, --help             Show this help

Env vars:
  API_URL, SERVICE_NAME, NAMESPACE, APP_DIR, POLL_SECONDS, MAX_POLLS
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --api-url)
        API_URL="${2:?missing value for --api-url}"
        shift 2
        ;;
      --service)
        SERVICE_NAME="${2:?missing value for --service}"
        shift 2
        ;;
      --namespace)
        NAMESPACE="${2:?missing value for --namespace}"
        shift 2
        ;;
      --app-dir)
        APP_DIR="${2:?missing value for --app-dir}"
        shift 2
        ;;
      --poll-seconds)
        POLL_SECONDS="${2:?missing value for --poll-seconds}"
        shift 2
        ;;
      --max-polls)
        MAX_POLLS="${2:?missing value for --max-polls}"
        shift 2
        ;;
      --skip-healthcheck)
        SKIP_HEALTHCHECK="true"
        shift
        ;;
      --no-wait)
        WAIT_FOR_RESULT="false"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[upload-app] unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

json_get() {
  local json="$1"
  local key="$2"

  if command -v jq >/dev/null 2>&1; then
    echo "${json}" | jq -r --arg k "${key}" '.[$k] // empty'
    return 0
  fi

  # Fallback parser for simple flat JSON keys.
  echo "${json}" | sed -n "s/.*\"${key}\":\"\\([^\"]*\\)\".*/\\1/p"
}

require_tools() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "[upload-app] curl is required"
    exit 1
  fi
  if ! command -v tar >/dev/null 2>&1; then
    echo "[upload-app] tar is required"
    exit 1
  fi
}

healthcheck() {
  if [[ "${SKIP_HEALTHCHECK}" == "true" ]]; then
    return 0
  fi

  if ! curl -fsS "${API_URL}/healthz" >/dev/null 2>&1; then
    echo "[upload-app] API health check failed at ${API_URL}/healthz"
    echo "[upload-app] start API first (example): cd src/upload-api && go run ."
    exit 1
  fi
}

main() {
  parse_args "$@"
  require_tools

  if [[ ! -d "${APP_DIR}" ]]; then
    echo "[upload-app] app directory not found: ${APP_DIR}"
    exit 1
  fi

  if [[ ! -f "${APP_DIR}/Dockerfile" ]]; then
    echo "[upload-app] warning: Dockerfile not found in ${APP_DIR}; build may fail"
  fi

  healthcheck

  local tmp_dir bundle_path response deploy_id
  tmp_dir="$(mktemp -d)"
  bundle_path="${tmp_dir}/${SERVICE_NAME}.tar.gz"
  trap 'rm -rf "${tmp_dir}"' EXIT

  tar -czf "${bundle_path}" -C "${APP_DIR}" .

  echo "[upload-app] Uploading ${APP_DIR} to ${API_URL}/deploy"
  response="$(curl -sf -X POST "${API_URL}/deploy" \
    -F "bundle=@${bundle_path}" \
    -F "service=${SERVICE_NAME}" \
    -F "namespace=${NAMESPACE}")"

  deploy_id="$(json_get "${response}" "id")"
  if [[ -z "${deploy_id}" ]]; then
    echo "[upload-app] failed to parse deployment id from response:"
    echo "${response}"
    exit 1
  fi

  echo "${response}"
  echo "[upload-app] Deployment id: ${deploy_id}"

  if [[ "${WAIT_FOR_RESULT}" != "true" ]]; then
    echo "[upload-app] upload accepted; skipping status polling (--no-wait)"
    exit 0
  fi

  local status_json status revision logs_hint service_name namespace
  for _ in $(seq 1 "${MAX_POLLS}"); do
    if ! status_json="$(curl -s "${API_URL}/status/${deploy_id}")"; then
      echo "[upload-app] status endpoint not reachable yet; retrying"
      sleep "${POLL_SECONDS}"
      continue
    fi

    status="$(json_get "${status_json}" "status")"
    if [[ -z "${status}" ]]; then
      echo "[upload-app] status payload not ready yet; retrying"
      sleep "${POLL_SECONDS}"
      continue
    fi

    echo "[upload-app] status=${status}"
    if [[ "${status}" == "READY" || "${status}" == "FAILED" ]]; then
      service_name="$(json_get "${status_json}" "serviceName")"
      namespace="$(json_get "${status_json}" "namespace")"
      revision="$(json_get "${status_json}" "revision")"
      logs_hint="$(json_get "${status_json}" "logsHint")"

      echo "${status_json}"
      [[ -n "${service_name}" ]] && echo "[upload-app] service=${service_name}"
      [[ -n "${namespace}" ]] && echo "[upload-app] namespace=${namespace}"
      [[ -n "${revision}" ]] && echo "[upload-app] revision=${revision}"
      [[ -n "${logs_hint}" ]] && echo "[upload-app] logs=${logs_hint}"
      if [[ -n "${service_name}" && -n "${namespace}" ]]; then
        echo "[upload-app] url_hint=http://${service_name}.${namespace}.localhost:8081"
      fi

      if [[ "${status}" == "FAILED" ]]; then
        exit 1
      fi
      exit 0
    fi
    sleep "${POLL_SECONDS}"
  done

  echo "[upload-app] timed out waiting for terminal deployment state after $((MAX_POLLS * POLL_SECONDS))s"
  exit 1
}

main "$@"
