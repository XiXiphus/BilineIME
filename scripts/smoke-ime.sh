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
LAST_FAILURE_KIND=""
LAST_FAILURE_DETAIL=""

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

host_focus_snapshot() {
  osascript <<'EOF' 2>/dev/null
tell application "System Events"
  set frontProcessName to ""
  try
    set frontProcessName to name of first application process whose frontmost is true
  end try

  if frontProcessName is not "TextEdit" then
    return frontProcessName & "|<none>|<none>"
  end if

  tell process "TextEdit"
    set focusedElement to missing value
    try
      set focusedElement to value of attribute "AXFocusedUIElement"
    end try

    if focusedElement is missing value then
      return "TextEdit|<missing>|<missing>"
    end if

    set roleText to "<missing>"
    set descText to "<missing>"
    try
      set roleText to value of attribute "AXRole" of focusedElement as text
    end try
    try
      set descText to value of attribute "AXDescription" of focusedElement as text
    end try

    return frontProcessName & "|" & roleText & "|" & descText
  end tell
end tell
EOF
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
  "$PRESS_KEY" escape --mode system-events >/dev/null 2>&1 || true
  "$PRESS_KEY" escape --mode system-events >/dev/null 2>&1 || true
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
  [[ -f "$SYSTEM_LOG_FILE" ]] || return 1

  local last_failure=""
  local last_recovery=""
  local biline_lines=""

  biline_lines="$(grep -F 'BilineIMEDev[' "$SYSTEM_LOG_FILE" || true)"

  last_failure="$(
    printf '%s\n' "$biline_lines" \
      | rg 'deny\(1\) mach-register|could not register|\[IMKServer _createConnection\]: \*Failed\*' \
      | tail -n 1 \
      | cut -c 1-23 \
      || true
  )"

  last_recovery="$(
    printf '%s\n' "$biline_lines" \
      | rg 'SMOKE .*isComposing=true|First handled key|First composing snapshot|First candidate panel render|InputMethodKit\) Setting marked text' \
      | tail -n 1 \
      | cut -c 1-23 \
      || true
  )"

  [[ -n "$last_failure" ]] || return 1
  [[ -z "$last_recovery" ]] && return 0
  [[ "$last_failure" > "$last_recovery" ]]
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

write_system_snapshot() {
  log show --last 90s --style compact --predicate 'process == "BilineIMEDev" OR eventMessage CONTAINS[c] "IMKServer" OR eventMessage CONTAINS[c] "InputMethodKit" OR eventMessage CONTAINS[c] "mach-register" OR eventMessage CONTAINS[c] "could not register" OR eventMessage CONTAINS[c] "First handled key" OR eventMessage CONTAINS[c] "First composing snapshot" OR eventMessage CONTAINS[c] "First candidate panel render" OR eventMessage CONTAINS[c] "Missing anchor"' >"$SYSTEM_LOG_FILE" 2>/dev/null || true
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

  case "$key" in
    rawInput|compositionMode|isComposing|candidateCount|selectedCandidate|activeLayer|selectedRow|selectedColumn)
      LAST_FAILURE_KIND="ime-not-composing"
      LAST_FAILURE_DETAIL="expected_${key}=${expected} actual=${actual:-<missing>}"
      ;;
    *)
      LAST_FAILURE_KIND="probe-mismatch"
      LAST_FAILURE_DETAIL="expected_${key}=${expected} actual=${actual:-<missing>}"
      ;;
  esac
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

  LAST_FAILURE_KIND="commit-mismatch"
  LAST_FAILURE_DETAIL="expected_host=${expected} actual=${actual}"
  echo "expected host text [$expected], got [${actual}]" >&2
  return 1
}

expect_host_text_stable() {
  local expected="$1"
  local duration_ms="${2:-1200}"
  local interval_ms=100
  local checks=$((duration_ms / interval_ms))
  local actual=""
  local index

  for ((index = 0; index < checks; index++)); do
    actual="$(read_host_text)"
    if [[ "$actual" != "$expected" ]]; then
      LAST_FAILURE_KIND="commit-mismatch"
      LAST_FAILURE_DETAIL="expected_stable_host=${expected} actual=${actual}"
      echo "expected stable host text [$expected], got [${actual}]" >&2
      return 1
    fi
    sleep 0.1
  done
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
  : >"$TELEMETRY_FILE"
  write_system_snapshot
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
  local attempts=0
  while true; do
    if ! is_target_input_source_active; then
      LAST_FAILURE_KIND="input-source-not-ready"
      LAST_FAILURE_DETAIL="current_source=$(current_input_source)"
      echo "Current input source is [$(current_input_source)], not [$TARGET_SOURCE_ID]." >&2
      return 1
    fi
    if ! is_app_running; then
      LAST_FAILURE_KIND="ime-not-running"
      LAST_FAILURE_DETAIL="process=$APP_PROCESS"
      echo "$APP_PROCESS is not running." >&2
      return 1
    fi
    local snapshot=""
    snapshot="$(host_focus_snapshot || true)"
    local front_process="${snapshot%%|*}"
    local rest="${snapshot#*|}"
    local focused_role="${rest%%|*}"
    local focused_desc="${rest#*|}"
    if [[ "$front_process" == "TextEdit" && "$focused_role" == "AXTextArea" ]]; then
      return 0
    fi

    attempts=$((attempts + 1))
    if [[ $attempts -ge 2 ]]; then
      LAST_FAILURE_KIND="host-not-ready"
      LAST_FAILURE_DETAIL="front_process=${front_process:-<missing>} focused_role=${focused_role:-<missing>} focused_desc=${focused_desc:-<missing>}"
      echo "TextEdit input focus is not ready: ${LAST_FAILURE_DETAIL}" >&2
      return 1
    fi

    activate_textedit
    focus_text_view
    sleep 0.2
  done
}

capture_probe_state() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  write_host_text
  write_input_source
  cp "$HOST_FILE" "$target_dir/host.txt"
  cp "$INPUT_SOURCE_FILE" "$target_dir/input-source.txt"
  printf '%s\n' "$(latest_telemetry_line || true)" >"$target_dir/last-telemetry.txt"
  cp "$SYSTEM_LOG_FILE" "$target_dir/system.log" 2>/dev/null || true
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
    echo "failure_kind=${LAST_FAILURE_KIND:-<none>}"
    echo "failure_detail=${LAST_FAILURE_DETAIL:-<none>}"
    echo "evidence=$CURRENT_PROBE_DIR"
  } >"$target"
}

smoke_key() {
  assert_not_stopped
  assert_probe_ready || return 1
  "$PRESS_KEY" "$@" --mode cg-event || return 1
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
  LAST_FAILURE_KIND=""
  LAST_FAILURE_DETAIL=""
  clear_document
  activate_textedit
  focus_text_view
  assert_probe_ready
  mark_probe_offsets
}

run_probe() {
  local probe_function="$1"
  local probe_alias="$2"
  TOTAL_PROBES=$((TOTAL_PROBES + 1))
  begin_probe "$probe_alias"

  if "$probe_function"; then
    capture_probe_state "$CURRENT_PROBE_DIR"
    write_probe_report "pass" "$probe_alias"
    printf 'PASS %s\n' "$probe_alias" | tee -a "$SUMMARY_FILE"
  else
    FAILED_PROBES=$((FAILED_PROBES + 1))
    capture_probe_state "$CURRENT_PROBE_DIR"
    write_probe_report "fail" "$probe_alias"
    printf 'FAIL %s\n' "$probe_alias" | tee -a "$SUMMARY_FILE"
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

probe_phrase_ni_hao_chinese() {
  smoke_type_word nihao
  smoke_key space
  expect_host_text '你好' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_ni_hao_english() {
  smoke_type_word nihao
  smoke_key tab --shift
  sleep 1.2
  expect_field activeLayer english || return 1
  smoke_key space
  expect_host_text 'hello' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_zhong_guo_chinese() {
  smoke_type_word zhongguo
  smoke_key space
  expect_host_text '中国' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_zhong_guo_english() {
  smoke_type_word zhongguo
  smoke_key tab --shift
  sleep 1.2
  expect_field activeLayer english || return 1
  smoke_key space
  expect_host_text 'China' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_wo_men_chinese() {
  smoke_type_word women
  smoke_key space
  expect_host_text '我们' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_shi_jie_chinese() {
  smoke_type_word shijie
  smoke_key space
  expect_host_text '世界' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_shi_jian_chinese() {
  smoke_type_word shijian
  smoke_key space
  expect_host_text '时间' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_shu_ru_fa_chinese() {
  smoke_type_word shurufa
  smoke_key space
  expect_host_text '输入法' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_shuang_yu_chinese() {
  smoke_type_word shuangyu
  smoke_key space
  expect_host_text '双语' || return 1
  expect_field isComposing false || return 1
}

probe_phrase_ce_shi_chinese() {
  smoke_type_word ceshi
  smoke_key space
  expect_host_text '测试' || return 1
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

probe_digit_select_zhegea_no_repeat() {
  smoke_type_word zhegea
  smoke_key 1
  local committed=""
  committed="$(read_host_text)"
  if [[ -z "$committed" ]]; then
    LAST_FAILURE_KIND="commit-mismatch"
    LAST_FAILURE_DETAIL="expected_non_empty_host_after_digit_select actual=<empty>"
    echo "expected non-empty host text after digit select, got empty" >&2
    return 1
  fi
  expect_field isComposing false || return 1
  expect_host_text_stable "$committed" 1500 || return 1
}

resolve_probe_function() {
  local alias="$1"
  case "$alias" in
    type-shi) echo "probe_type_shi" ;;
    browse-equal) echo "probe_browse_equal" ;;
    browse-minus) echo "probe_browse_minus" ;;
    comma-commit) echo "probe_comma_commit" ;;
    phrase-hao-ping-guo-chinese) echo "probe_phrase_hao_ping_guo_chinese" ;;
    phrase-hao-ping-guo-english) echo "probe_phrase_hao_ping_guo_english" ;;
    phrase-ni-hao-chinese) echo "probe_phrase_ni_hao_chinese" ;;
    phrase-ni-hao-english) echo "probe_phrase_ni_hao_english" ;;
    phrase-zhong-guo-chinese) echo "probe_phrase_zhong_guo_chinese" ;;
    phrase-zhong-guo-english) echo "probe_phrase_zhong_guo_english" ;;
    phrase-wo-men-chinese) echo "probe_phrase_wo_men_chinese" ;;
    phrase-shi-jie-chinese) echo "probe_phrase_shi_jie_chinese" ;;
    phrase-shi-jian-chinese) echo "probe_phrase_shi_jian_chinese" ;;
    phrase-shu-ru-fa-chinese) echo "probe_phrase_shu_ru_fa_chinese" ;;
    phrase-shuang-yu-chinese) echo "probe_phrase_shuang_yu_chinese" ;;
    phrase-ce-shi-chinese) echo "probe_phrase_ce_shi_chinese" ;;
    prefix-hao-english-tail) echo "probe_prefix_hao_english_tail" ;;
    digit-select-zhegea-no-repeat) echo "probe_digit_select_zhegea_no_repeat" ;;
    *) return 1 ;;
  esac
}

run_selected_probes() {
  local probes=(
    type-shi
    browse-equal
    browse-minus
    comma-commit
    phrase-ni-hao-chinese
    phrase-ni-hao-english
    phrase-zhong-guo-chinese
    phrase-zhong-guo-english
    phrase-wo-men-chinese
    phrase-shi-jie-chinese
    phrase-shi-jian-chinese
    phrase-hao-ping-guo-chinese
    phrase-hao-ping-guo-english
    phrase-shu-ru-fa-chinese
    phrase-shuang-yu-chinese
    phrase-ce-shi-chinese
    prefix-hao-english-tail
    digit-select-zhegea-no-repeat
  )

  local probe_alias probe_function
  for probe_alias in "${probes[@]}"; do
    assert_not_stopped
    probe_function="$(resolve_probe_function "$probe_alias")"
    if ! run_probe "$probe_function" "$probe_alias"; then
      :
    fi
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
  local probe_alias="$1"
  CURRENT_MODE="probe"
  refresh_lock_mode
  rm -f "$STOP_FILE" >/dev/null 2>&1 || true
  print_control_hint

  local probe_function=""
  if ! probe_function="$(resolve_probe_function "$probe_alias")"; then
    echo "Unknown probe: $probe_alias" >&2
    exit 1
  fi

  prepare_environment
  start_log_streams
  : >"$SUMMARY_FILE"
  run_probe "$probe_function" "$probe_alias"
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
