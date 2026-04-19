#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_SOURCE_ID="io.github.xixiphus.inputmethod.BilineIME.dev.pinyin"
TEXTEDIT_BUNDLE_ID="com.apple.TextEdit"
APP_PROCESS="BilineIMEDev"
PRESS_KEY="$ROOT_DIR/press-macos-key.swift"
SMOKE_DEFAULTS_DOMAIN="io.github.xixiphus.inputmethod.BilineIME.dev"
OUTPUT_ROOT="${SMOKE_OUTPUT_ROOT:-/tmp/biline-ime-smoke/$(date +%Y%m%d-%H%M%S)-$$}"
RIME_SMOKE_USER_DIR="$OUTPUT_ROOT/rime-user"
SUMMARY_FILE="$OUTPUT_ROOT/summary.txt"
PREPARE_FILE="$OUTPUT_ROOT/prepare.txt"
HOST_FILE="$OUTPUT_ROOT/host.txt"
INPUT_SOURCE_FILE="$OUTPUT_ROOT/input-source.txt"
TELEMETRY_FILE="$OUTPUT_ROOT/telemetry.log"
SYSTEM_LOG_FILE="$OUTPUT_ROOT/system.log"
OBSERVE_FILE="$OUTPUT_ROOT/observe.txt"
LOCK_DIR="/tmp/biline-ime-smoke.lock"
STOP_FILE="/tmp/biline-ime-smoke.stop"

CURRENT_MODE=""
CURRENT_PROBE=""
CURRENT_PROBE_DIR=""
FAILED_PROBES=0
TOTAL_PROBES=0
TELEMETRY_STREAM_PID=""
SYSTEM_STREAM_PID=""
PROBE_TELEMETRY_OFFSET=0

mkdir -p "$OUTPUT_ROOT"

cleanup() {
  rm -f "$STOP_FILE" >/dev/null 2>&1 || true

  if [[ -n "${TELEMETRY_STREAM_PID:-}" ]]; then
    kill "$TELEMETRY_STREAM_PID" >/dev/null 2>&1 || true
    wait "$TELEMETRY_STREAM_PID" >/dev/null 2>&1 || true
  fi

  if [[ -n "${SYSTEM_STREAM_PID:-}" ]]; then
    kill "$SYSTEM_STREAM_PID" >/dev/null 2>&1 || true
    wait "$SYSTEM_STREAM_PID" >/dev/null 2>&1 || true
  fi

  if [[ -d "$LOCK_DIR" ]]; then
    rm -f "$LOCK_DIR"/mode "$LOCK_DIR"/output "$LOCK_DIR"/pid >/dev/null 2>&1 || true
    rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

request_stop() {
  touch "$STOP_FILE" >/dev/null 2>&1 || true
}

trap request_stop INT TERM

print_control_hint() {
  cat <<EOF
SMOKE control:
  mode     : ${CURRENT_MODE:-idle}
  output   : $OUTPUT_ROOT
  stop-file: $STOP_FILE
  stop-cmd : ./scripts/smoke-ime.sh stop
  status   : ./scripts/smoke-ime.sh status
  interrupt: Ctrl-C
EOF
}

assert_not_stopped() {
  if [[ -f "$STOP_FILE" ]]; then
    record_stop_state
    echo "IME smoke stopped by user request." >&2
    exit 130
  fi
}

acquire_lock() {
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Another IME smoke run is already active: $LOCK_DIR" >&2
    exit 1
  fi

  printf '%s\n' "$$" >"$LOCK_DIR/pid"
  printf '%s\n' "$OUTPUT_ROOT" >"$LOCK_DIR/output"
  printf '%s\n' "${CURRENT_MODE:-unknown}" >"$LOCK_DIR/mode"
}

refresh_lock_mode() {
  if [[ -d "$LOCK_DIR" ]]; then
    printf '%s\n' "${CURRENT_MODE:-unknown}" >"$LOCK_DIR/mode"
  fi
}

current_input_source() {
  "$ROOT_DIR/select-input-source.sh" current 2>/dev/null || true
}

display_count() {
  swift -e 'import AppKit; print(NSScreen.screens.count)'
}

capture_displays() {
  assert_not_stopped
  local target_dir="$1"
  mkdir -p "$target_dir"

  local count
  count="$(display_count 2>/dev/null || printf '1')"
  local index
  for ((index = 1; index <= count; index++)); do
    screencapture -x -D "$index" "$target_dir/display${index}.png" >/dev/null 2>&1 || true
  done
}

activate_textedit() {
  assert_not_stopped
  osascript <<'EOF' >/dev/null
tell application id "com.apple.TextEdit"
  activate
  if (count of documents) is 0 then
    make new document
  end if
end tell
EOF
  sleep 0.2
}

focus_text_view() {
  assert_not_stopped
  osascript <<'EOF' >/dev/null
tell application "System Events"
  tell process "TextEdit"
    set frontmost to true
    tell front window
      click text area 1 of scroll area 1
    end tell
  end tell
end tell
EOF
  sleep 0.2
}

clear_composition() {
  "$PRESS_KEY" escape --system-events >/dev/null 2>&1 || true
  "$PRESS_KEY" escape --system-events >/dev/null 2>&1 || true
  sleep 0.2
}

clear_document() {
  assert_not_stopped
  activate_textedit
  focus_text_view
  clear_composition
  osascript <<'EOF' >/dev/null
tell application id "com.apple.TextEdit"
  set text of front document to ""
end tell
EOF
  focus_text_view
  sleep 0.2
}

read_host_text() {
  osascript <<'EOF'
tell application id "com.apple.TextEdit"
  if (count of documents) is 0 then
    return ""
  end if
  return text of front document
end tell
EOF
}

write_host_text() {
  read_host_text >"$HOST_FILE"
}

write_input_source() {
  current_input_source >"$INPUT_SOURCE_FILE"
}

is_target_input_source_active() {
  [[ "$(current_input_source)" == "$TARGET_SOURCE_ID" ]]
}

is_app_running() {
  pgrep -x "$APP_PROCESS" >/dev/null 2>&1
}

has_recent_imk_failure() {
  local lines
  lines="$(log show --last 90s --style compact --predicate 'process == "BilineIMEDev" OR eventMessage CONTAINS[c] "IMKServer" OR eventMessage CONTAINS[c] "mach-register" OR eventMessage CONTAINS[c] "could not register"' 2>/dev/null || true)"
  printf '%s\n' "$lines" | rg -q 'deny\(1\) mach-register|could not register|\[IMKServer _createConnection\]: \*Failed\*'
}

latest_telemetry_line() {
  if [[ ! -f "$TELEMETRY_FILE" ]]; then
    return 1
  fi
  tail -n +"$((PROBE_TELEMETRY_OFFSET + 1))" "$TELEMETRY_FILE" | rg 'SMOKE ' | tail -n 1
}

latest_telemetry_field() {
  local key="$1"
  local line
  line="$(latest_telemetry_line || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi
  printf '%s\n' "$line" | tr ' ' '\n' | rg "^${key}=" | tail -n 1 | cut -d= -f2-
}

mark_probe_offsets() {
  if [[ -f "$TELEMETRY_FILE" ]]; then
    PROBE_TELEMETRY_OFFSET="$(wc -l < "$TELEMETRY_FILE" | tr -d ' ')"
  else
    PROBE_TELEMETRY_OFFSET=0
  fi
}

start_log_streams() {
  : >"$TELEMETRY_FILE"
  : >"$SYSTEM_LOG_FILE"

  log stream --style compact --predicate 'process == "BilineIMEDev" AND category == "smoke"' >"$TELEMETRY_FILE" 2>&1 &
  TELEMETRY_STREAM_PID=$!

  log stream --style compact --predicate 'process == "BilineIMEDev" OR eventMessage CONTAINS[c] "IMKServer" OR eventMessage CONTAINS[c] "InputMethodKit" OR eventMessage CONTAINS[c] "mach-register" OR eventMessage CONTAINS[c] "could not register" OR eventMessage CONTAINS[c] "First handled key" OR eventMessage CONTAINS[c] "First composing snapshot" OR eventMessage CONTAINS[c] "First candidate panel render" OR eventMessage CONTAINS[c] "Missing anchor"' >"$SYSTEM_LOG_FILE" 2>&1 &
  SYSTEM_STREAM_PID=$!

  sleep 1
}

expect_field() {
  local key="$1"
  local expected="$2"
  local attempts="${3:-20}"
  local actual=""
  local index

  for ((index = 0; index < attempts; index++)); do
    actual="$(latest_telemetry_field "$key" || true)"
    if [[ "$actual" == "$expected" ]]; then
      return 0
    fi
    sleep 0.1
  done

  echo "expected telemetry ${key}=${expected}, got ${actual:-<missing>}" >&2
  return 1
}

expect_host_text() {
  local expected="$1"
  local attempts="${2:-20}"
  local actual=""
  local index

  for ((index = 0; index < attempts; index++)); do
    actual="$(read_host_text)"
    if [[ "$actual" == "$expected" ]]; then
      return 0
    fi
    sleep 0.1
  done

  echo "expected host text [$expected], got [${actual}]" >&2
  return 1
}

write_prepare_result() {
  local status="$1"
  local current_source="$2"
  local app_running="$3"
  local recent_failure="$4"
  {
    echo "status=$status"
    echo "mode=prepare"
    echo "current_source=$current_source"
    echo "target_source=$TARGET_SOURCE_ID"
    echo "app_running=$app_running"
    echo "recent_imk_failure=$recent_failure"
    echo "output=$OUTPUT_ROOT"
  } | tee "$PREPARE_FILE"
}

prepare_environment() {
  assert_not_stopped
  defaults write "$SMOKE_DEFAULTS_DOMAIN" SmokePreviewDelayMs -int 800 >/dev/null 2>&1 || true
  defaults write "$SMOKE_DEFAULTS_DOMAIN" SmokePreviewDebounceMs -int 100 >/dev/null 2>&1 || true
  defaults write "$SMOKE_DEFAULTS_DOMAIN" SmokeRimeUserDataDir -string "$RIME_SMOKE_USER_DIR" >/dev/null 2>&1 || true
  defaults write "$SMOKE_DEFAULTS_DOMAIN" SmokeRimeResetUserData -bool true >/dev/null 2>&1 || true

  activate_textedit
  write_input_source
  write_host_text
  capture_displays "$OUTPUT_ROOT"

  local current_source=""; current_source="$(current_input_source)"
  local app_running="0"
  local recent_failure="0"

  if is_app_running; then
    app_running="1"
  fi

  if has_recent_imk_failure; then
    recent_failure="1"
  fi

  if [[ "$current_source" == "$TARGET_SOURCE_ID" && "$app_running" == "1" && "$recent_failure" == "0" ]]; then
    write_prepare_result "ready" "$current_source" "$app_running" "$recent_failure"
    return 0
  fi

  write_prepare_result "not-ready" "$current_source" "$app_running" "$recent_failure"
  cat <<EOF >&2
IME smoke precheck failed.
Switch TextEdit to BilineIME Dev manually and ensure the IME is actually active, then rerun:
  ./scripts/smoke-ime.sh prepare
EOF
  return 1
}

assert_probe_ready() {
  assert_not_stopped
  activate_textedit
  if ! is_target_input_source_active; then
    echo "Current input source is [$(current_input_source)], not [$TARGET_SOURCE_ID]." >&2
    return 1
  fi
  if ! is_app_running; then
    echo "$APP_PROCESS is not running." >&2
    return 1
  fi
  return 0
}

capture_probe_state() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  write_host_text
  write_input_source
  cp "$HOST_FILE" "$target_dir/host.txt"
  cp "$INPUT_SOURCE_FILE" "$target_dir/input-source.txt"
  printf '%s\n' "$(latest_telemetry_line || true)" >"$target_dir/last-telemetry.txt"
  capture_displays "$target_dir"
}

record_stop_state() {
  {
    echo "stopped=1"
    echo "mode=${CURRENT_MODE:-unknown}"
    echo "probe=${CURRENT_PROBE:-<none>}"
    echo "input_source=$(current_input_source)"
    echo "host_text=$(read_host_text)"
    echo "last_telemetry=$(latest_telemetry_line || true)"
    echo "output=$OUTPUT_ROOT"
  } >>"$SUMMARY_FILE"
}

write_probe_report() {
  local status="$1"
  local probe="$2"
  local target="$OUTPUT_ROOT/probe-$probe.txt"
  {
    echo "status=$status"
    echo "mode=${CURRENT_MODE}"
    echo "probe=$probe"
    echo "input_source=$(current_input_source)"
    echo "host_text=$(read_host_text)"
    echo "last_telemetry=$(latest_telemetry_line || true)"
    echo "evidence=$CURRENT_PROBE_DIR"
  } >"$target"
}

smoke_key() {
  assert_not_stopped
  assert_probe_ready
  focus_text_view
  "$PRESS_KEY" "$@" --system-events
  sleep 0.2
}

smoke_type_word() {
  local word="$1"
  local index
  for ((index = 0; index < ${#word}; index++)); do
    smoke_key "${word:index:1}"
  done
}

begin_probe() {
  assert_not_stopped
  CURRENT_PROBE="$1"
  CURRENT_PROBE_DIR="$OUTPUT_ROOT/$CURRENT_PROBE"
  mkdir -p "$CURRENT_PROBE_DIR"
  clear_document
  assert_probe_ready
  mark_probe_offsets
}

run_probe() {
  local probe="$1"
  TOTAL_PROBES=$((TOTAL_PROBES + 1))
  begin_probe "$probe"

  if "$probe"; then
    capture_probe_state "$CURRENT_PROBE_DIR"
    write_probe_report "pass" "$probe"
    printf 'PASS %s\n' "$probe" | tee -a "$SUMMARY_FILE"
  else
    FAILED_PROBES=$((FAILED_PROBES + 1))
    capture_probe_state "$CURRENT_PROBE_DIR"
    write_probe_report "fail" "$probe"
    printf 'FAIL %s\n' "$probe" | tee -a "$SUMMARY_FILE"
    return 1
  fi
}

probe_type_shi() {
  smoke_type_word shi
  expect_field rawInput shi || return 1
  expect_field isComposing true || return 1
}

probe_browse_equal() {
  smoke_type_word shi
  expect_field rawInput shi || return 1
  smoke_key equal
  expect_field compositionMode candidateExpanded || return 1
  expect_field selectedRow 1 || return 1
}

probe_browse_minus() {
  smoke_type_word shi
  smoke_key equal
  expect_field compositionMode candidateExpanded || return 1
  smoke_key minus
  expect_field compositionMode candidateExpanded || return 1
  expect_field selectedRow 0 || return 1
}

probe_comma_commit() {
  smoke_type_word shi
  smoke_key comma
  expect_host_text '是，' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_hao_ping_guo_chinese() {
  smoke_type_word haopingguo
  smoke_key space
  expect_host_text '好苹果' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_hao_ping_guo_english() {
  smoke_type_word haopingguo
  smoke_key tab --shift
  sleep 1.2
  expect_field activeLayer english || return 1
  smoke_key space
  expect_host_text 'good apple' || return 1
  expect_field isComposing false || return 1
}

probe_prefix_hao_english_tail() {
  smoke_type_word haopingguo
  smoke_key tab --shift
  sleep 1.2
  expect_field activeLayer english || return 1
  smoke_key right
  expect_field selectedColumn 1 || return 1
  smoke_key space
  expect_host_text 'good' || return 1
  expect_field rawInput pingguo || return 1
  expect_field activeLayer english || return 1
}

run_selected_probes() {
  local probes=(
    probe_type_shi
    probe_browse_equal
    probe_browse_minus
    probe_phrase_hao_ping_guo_chinese
    probe_phrase_hao_ping_guo_english
  )

  local probe
  for probe in "${probes[@]}"; do
    assert_not_stopped
    run_probe "$probe"
  done
}

observe_command() {
  CURRENT_MODE="observe"
  refresh_lock_mode
  print_control_hint
  prepare_environment
  start_log_streams
  : >"$OBSERVE_FILE"

  local sample=0
  while true; do
    assert_not_stopped
    sample=$((sample + 1))
    write_input_source
    write_host_text
    capture_displays "$OUTPUT_ROOT"
    {
      echo "sample=$sample"
      echo "timestamp=$(date '+%Y-%m-%d %H:%M:%S')"
      echo "input_source=$(current_input_source)"
      echo "host_text=$(read_host_text)"
      echo "last_telemetry=$(latest_telemetry_line || true)"
      echo "---"
    } >>"$OBSERVE_FILE"
    sleep 1
  done
}

prepare_command() {
  CURRENT_MODE="prepare"
  refresh_lock_mode
  rm -f "$STOP_FILE" >/dev/null 2>&1 || true
  print_control_hint
  : >"$SUMMARY_FILE"
  prepare_environment
}

probe_command() {
  local probe_name="$1"
  CURRENT_MODE="probe"
  refresh_lock_mode
  rm -f "$STOP_FILE" >/dev/null 2>&1 || true
  print_control_hint

  if ! declare -F "$probe_name" >/dev/null 2>&1; then
    echo "Unknown probe: $probe_name" >&2
    exit 1
  fi

  prepare_environment
  start_log_streams
  : >"$SUMMARY_FILE"
  run_probe "$probe_name"
  printf 'total=%d failed=%d output=%s\n' "$TOTAL_PROBES" "$FAILED_PROBES" "$OUTPUT_ROOT" | tee -a "$SUMMARY_FILE"
  [[ "$FAILED_PROBES" -eq 0 ]]
}

run_command() {
  CURRENT_MODE="run"
  refresh_lock_mode
  rm -f "$STOP_FILE" >/dev/null 2>&1 || true
  print_control_hint
  prepare_environment
  start_log_streams
  : >"$SUMMARY_FILE"
  run_selected_probes
  printf 'total=%d failed=%d output=%s\n' "$TOTAL_PROBES" "$FAILED_PROBES" "$OUTPUT_ROOT" | tee -a "$SUMMARY_FILE"
  [[ "$FAILED_PROBES" -eq 0 ]]
}

status_command() {
  if [[ -d "$LOCK_DIR" ]]; then
    echo "running"
    [[ -f "$LOCK_DIR/mode" ]] && echo "mode=$(cat "$LOCK_DIR/mode")"
    [[ -f "$LOCK_DIR/output" ]] && echo "output=$(cat "$LOCK_DIR/output")"
    [[ -f "$LOCK_DIR/pid" ]] && echo "pid=$(cat "$LOCK_DIR/pid")"
  else
    echo "idle"
  fi

  if [[ -f "$STOP_FILE" ]]; then
    echo "stop_requested=1"
  else
    echo "stop_requested=0"
  fi

  echo "stop_file=$STOP_FILE"
}

stop_command() {
  touch "$STOP_FILE"
  echo "stop_requested=1"
  echo "stop_file=$STOP_FILE"
}

main() {
  local command="${1:-run}"

  case "$command" in
    status)
      status_command
      return
      ;;
    stop)
      stop_command
      return
      ;;
  esac

  acquire_lock

  case "$command" in
    prepare)
      prepare_command
      ;;
    observe)
      observe_command
      ;;
    probe)
      if [[ $# -lt 2 ]]; then
        echo "usage: $0 probe <probe_name>" >&2
        exit 1
      fi
      probe_command "$2"
      ;;
    run)
      run_command
      ;;
    *)
      echo "usage: $0 [prepare|observe|probe <name>|run|status|stop]" >&2
      exit 1
      ;;
  esac
}

main "$@"
