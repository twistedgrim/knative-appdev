#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

MODE="port8081"
ACTION="start"
BACKGROUND="false"

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-knative-dev}"
LOCAL_PORT="${LOCAL_PORT:-8081}"
AUTO_TIMEOUT_SECONDS="${AUTO_TIMEOUT_SECONDS:-20}"

PF_PID_FILE="${PF_PID_FILE:-/tmp/knative-localhost-portforward.pid}"
PF_LOG_FILE="${PF_LOG_FILE:-/tmp/knative-localhost-portforward.log}"
TUNNEL_PID_FILE="${TUNNEL_PID_FILE:-/tmp/minikube-tunnel.pid}"
TUNNEL_LOG_FILE="${TUNNEL_LOG_FILE:-/tmp/minikube-tunnel.log}"
MODE_FILE="${MODE_FILE:-/tmp/knative-expose-mode}"

usage() {
  cat <<USAGE
Usage:
  scripts/expose-knative.sh [--mode port8081|port80|auto] [--start|--stop|--status] [--background]

Examples:
  scripts/expose-knative.sh --mode port8081 --start
  scripts/expose-knative.sh --mode port8081 --start --background
  scripts/expose-knative.sh --mode port80 --start --background
  scripts/expose-knative.sh --mode auto --start --background
  scripts/expose-knative.sh --mode auto --stop
USAGE
}

log() {
  echo "[expose-knative] $*"
}

have_tty() {
  [[ -t 0 ]]
}

is_port80_process_running() {
  pgrep -f "minikube tunnel -p ${MINIKUBE_PROFILE}" >/dev/null 2>&1 || pgrep -f "minikube tunnel" >/dev/null 2>&1
}

run_tunnel_cleanup() {
  # Cleanup orphaned routes/tunnel state even when no process is alive.
  # Use a shell-native timeout so cleanup cannot hang indefinitely.
  run_cleanup_cmd() {
    "$@" >/dev/null 2>&1 &
    local cmd_pid=$!
    local waited=0
    local limit=8
    while kill -0 "${cmd_pid}" >/dev/null 2>&1; do
      if [[ "${waited}" -ge "${limit}" ]]; then
        kill "${cmd_pid}" >/dev/null 2>&1 || true
        wait "${cmd_pid}" >/dev/null 2>&1 || true
        return 124
      fi
      sleep 1
      waited=$((waited + 1))
    done
    wait "${cmd_pid}" >/dev/null 2>&1 || true
    return 0
  }

  if sudo -n true >/dev/null 2>&1; then
    run_cleanup_cmd sudo minikube tunnel -p "${MINIKUBE_PROFILE}" --cleanup || true
    return 0
  fi

  if have_tty; then
    log "Requesting sudo credentials for tunnel cleanup"
    if sudo -v; then
      run_cleanup_cmd sudo minikube tunnel -p "${MINIKUBE_PROFILE}" --cleanup || true
      return 0
    fi
  fi

  # Fall back to non-sudo attempt (may still work in some environments).
  run_cleanup_cmd minikube tunnel -p "${MINIKUBE_PROFILE}" --cleanup || true
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        MODE="${2:-}"
        shift 2
        ;;
      --start)
        ACTION="start"
        shift
        ;;
      --stop)
        ACTION="stop"
        shift
        ;;
      --status)
        ACTION="status"
        shift
        ;;
      --background)
        BACKGROUND="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ "${MODE}" != "port8081" && "${MODE}" != "port80" && "${MODE}" != "auto" ]]; then
    echo "Invalid mode: ${MODE}"
    usage
    exit 1
  fi
}

apply_localhost_domain() {
  kubectl apply -f manifests/networking/knative-localhost-domain.yaml >/dev/null
}

is_pid_running() {
  local pid_file="$1"
  if [[ ! -f "${pid_file}" ]]; then
    return 1
  fi
  local pid
  pid="$(cat "${pid_file}")"
  ps -p "${pid}" >/dev/null 2>&1
}

stop_port8081() {
  if is_pid_running "${PF_PID_FILE}"; then
    kill "$(cat "${PF_PID_FILE}")" >/dev/null 2>&1 || true
    sleep 1
  fi
  rm -f "${PF_PID_FILE}"

  local pids
  pids="$(lsof -ti tcp:${LOCAL_PORT} -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    for pid in ${pids}; do
      kill "${pid}" >/dev/null 2>&1 || true
    done
  fi

  if [[ -f "${MODE_FILE}" ]] && [[ "$(cat "${MODE_FILE}")" == "port8081" ]]; then
    rm -f "${MODE_FILE}"
  fi
}

start_port8081_fg() {
  apply_localhost_domain
  log "Starting localhost:${LOCAL_PORT} port-forward (foreground)"
  log "Press Ctrl+C to stop"
  kubectl -n kourier-system port-forward svc/kourier "${LOCAL_PORT}:80"
}

start_port8081_bg() {
  if is_pid_running "${PF_PID_FILE}"; then
    log "port8081 already running (pid=$(cat "${PF_PID_FILE}"))"
    return 0
  fi

  apply_localhost_domain

  nohup kubectl -n kourier-system port-forward svc/kourier "${LOCAL_PORT}:80" >"${PF_LOG_FILE}" 2>&1 < /dev/null &
  local pid=$!
  echo "${pid}" > "${PF_PID_FILE}"

  for _ in $(seq 1 20); do
    if ! ps -p "${pid}" >/dev/null 2>&1; then
      log "port8081 forward exited early"
      tail -n 40 "${PF_LOG_FILE}" || true
      return 1
    fi
    if lsof -nP -iTCP:"${LOCAL_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "port8081" > "${MODE_FILE}"
      log "port8081 ready on localhost:${LOCAL_PORT}"
      return 0
    fi
    sleep 1
  done

  log "port8081 forward readiness timed out"
  return 1
}

stop_port80() {
  local used_sudo="false"

  if is_pid_running "${TUNNEL_PID_FILE}"; then
    kill "$(cat "${TUNNEL_PID_FILE}")" >/dev/null 2>&1 || true
    sleep 1
  fi
  rm -f "${TUNNEL_PID_FILE}"

  pkill -f "minikube tunnel -p ${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
  pkill -f "minikube tunnel" >/dev/null 2>&1 || true

  # Handle privileged tunnel helpers/processes created under sudo/root.
  if is_port80_process_running; then
    if sudo -n true >/dev/null 2>&1; then
      sudo pkill -f "minikube tunnel -p ${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
      sudo pkill -f "minikube tunnel" >/dev/null 2>&1 || true
      used_sudo="true"
    else
      log "Requesting sudo credentials to stop privileged tunnel processes"
      if sudo -v; then
        sudo pkill -f "minikube tunnel -p ${MINIKUBE_PROFILE}" >/dev/null 2>&1 || true
        sudo pkill -f "minikube tunnel" >/dev/null 2>&1 || true
        used_sudo="true"
      fi
    fi
  fi

  run_tunnel_cleanup

  if is_port80_process_running; then
    if [[ "${used_sudo}" != "true" ]]; then
      log "port80 process still appears active."
      log "Run in an interactive terminal and approve sudo prompt:"
      log "  ./scripts/expose-knative.sh --mode port80 --stop"
      log "If still active, run:"
      log "  sudo pkill -f 'minikube tunnel -p ${MINIKUBE_PROFILE}'"
      log "  sudo minikube tunnel -p ${MINIKUBE_PROFILE} --cleanup"
    fi
    return 1
  fi

  if [[ -f "${MODE_FILE}" ]] && [[ "$(cat "${MODE_FILE}")" == "port80" ]]; then
    rm -f "${MODE_FILE}"
  fi
}

port80_ready() {
  local lb_ip
  lb_ip="$(kubectl -n kourier-system get svc kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  if [[ "${lb_ip}" != "127.0.0.1" ]]; then
    return 1
  fi

  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 2 -H 'Host: probe.localhost' http://127.0.0.1 || true)"
  [[ "${code}" != "000" ]]
}

start_port80_fg() {
  apply_localhost_domain
  log "Starting minikube tunnel (foreground)"
  log "sudo may be requested for ports 80/443"
  log "Press Ctrl+C to stop"
  minikube tunnel -p "${MINIKUBE_PROFILE}" 2>&1 | tee "${TUNNEL_LOG_FILE}"
}

start_port80_bg() {
  if is_pid_running "${TUNNEL_PID_FILE}" && port80_ready; then
    log "port80 tunnel already running (pid=$(cat "${TUNNEL_PID_FILE}"))"
    return 0
  fi

  apply_localhost_domain
  log "Requesting sudo credentials for privileged ports"
  sudo -v

  nohup minikube tunnel -p "${MINIKUBE_PROFILE}" >"${TUNNEL_LOG_FILE}" 2>&1 < /dev/null &
  local pid=$!
  echo "${pid}" > "${TUNNEL_PID_FILE}"

  for _ in $(seq 1 "${AUTO_TIMEOUT_SECONDS}"); do
    if ! ps -p "${pid}" >/dev/null 2>&1; then
      log "port80 tunnel exited early"
      tail -n 40 "${TUNNEL_LOG_FILE}" || true
      return 1
    fi
    if port80_ready; then
      echo "port80" > "${MODE_FILE}"
      log "port80 ready (clean URLs without port suffix)"
      return 0
    fi
    sleep 1
  done

  log "port80 tunnel timed out after ${AUTO_TIMEOUT_SECONDS}s"
  log "Try foreground mode to inspect live tunnel output: ./scripts/expose-knative.sh --mode port80 --start"
  return 1
}

start_auto_bg() {
  if start_port80_bg; then
    return 0
  fi

  log "Falling back to port8081 mode"
  stop_port80
  start_port8081_bg
}

show_status() {
  local mode="unknown"
  if [[ -f "${MODE_FILE}" ]]; then
    mode="$(cat "${MODE_FILE}")"
  fi

  echo "mode=${mode}"
  if is_pid_running "${PF_PID_FILE}"; then
    echo "port8081=running pid=$(cat "${PF_PID_FILE}")"
  else
    echo "port8081=stopped"
  fi

  if is_pid_running "${TUNNEL_PID_FILE}"; then
    echo "port80=running pid=$(cat "${TUNNEL_PID_FILE}")"
  elif is_port80_process_running; then
    echo "port80=running pid=unknown"
  else
    echo "port80=stopped"
  fi
}

main() {
  parse_args "$@"

  case "${ACTION}" in
    status)
      show_status
      ;;
    stop)
      local stop_failed="false"
      case "${MODE}" in
        port8081)
          stop_port8081
          ;;
        port80)
          stop_port80 || stop_failed="true"
          ;;
        auto)
          stop_port80 || stop_failed="true"
          stop_port8081
          rm -f "${MODE_FILE}"
          ;;
      esac
      if [[ "${stop_failed}" == "true" ]]; then
        log "Stop was partially successful for mode=${MODE}"
        exit 1
      fi
      log "Stopped mode=${MODE}"
      ;;
    start)
      case "${MODE}" in
        port8081)
          if [[ "${BACKGROUND}" == "true" ]]; then
            start_port8081_bg
          else
            start_port8081_fg
          fi
          ;;
        port80)
          if [[ "${BACKGROUND}" == "true" ]]; then
            start_port80_bg
          else
            start_port80_fg
          fi
          ;;
        auto)
          # auto mode is intended to be non-blocking
          start_auto_bg
          ;;
      esac
      ;;
  esac
}

main "$@"
