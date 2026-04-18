#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_SOURCE_ID="io.github.xixiphus.inputmethod.BilineIME.dev.pinyin"
TEXTEDIT_BUNDLE_ID="com.apple.TextEdit"
PRESS_KEY="$ROOT_DIR/press-macos-key.swift"
SMOKE_DEFAULTS_DOMAIN="io.github.xixiphus.inputmethod.BilineIME.dev"
OUTPUT_ROOT="${SMOKE_OUTPUT_ROOT:-/tmp/biline-ime-smoke/$(date +%Y%m%d-%H%M%S)-$$}"
LOG_FILE="$OUTPUT_ROOT/smoke.log"
SUMMARY_FILE="$OUTPUT_ROOT/summary.txt"
PREPARE_FILE="$OUTPUT_ROOT/prepare.txt"
LOCK_DIR="/tmp/biline-ime-smoke.lock"

TOTAL_CASES=0
FAILED_CASES=0
CURRENT_CASE=""
CURRENT_CASE_DIR=""
CURRENT_LOG_OFFSET=0
LOG_STREAM_PID=""

mkdir -p "$OUTPUT_ROOT"

cleanup() {
  if [[ -n "${LOG_STREAM_PID:-}" ]]; then
    kill "$LOG_STREAM_PID" >/dev/null 2>&1 || true
    wait "$LOG_STREAM_PID" >/dev/null 2>&1 || true
  fi
  if [[ -d "$LOCK_DIR" ]]; then
    rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

acquire_lock() {
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Another IME smoke run is already active: $LOCK_DIR" >&2
    exit 1
  fi
}

print_prepare_result() {
  local status="$1"
  local current_source="$2"
  {
    echo "status=$status"
    echo "current_source=$current_source"
    echo "target_source=$TARGET_SOURCE_ID"
    echo "output=$OUTPUT_ROOT"
  } | tee "$PREPARE_FILE"
}

current_input_source() {
  "$ROOT_DIR/select-input-source.sh" current 2>/dev/null || true
}

assert_input_source() {
  local current
  current="$(current_input_source)"
  if [[ "$current" != "$TARGET_SOURCE_ID" ]]; then
    echo "Expected input source $TARGET_SOURCE_ID, got $current" >&2
    return 1
  fi
}

prepare_input_source() {
  defaults write "$SMOKE_DEFAULTS_DOMAIN" SmokePreviewDelayMs -int 800 >/dev/null 2>&1 || true
  defaults write "$SMOKE_DEFAULTS_DOMAIN" SmokePreviewDebounceMs -int 100 >/dev/null 2>&1 || true
  activate_textedit
  "$ROOT_DIR/select-input-source.sh" select "$TARGET_SOURCE_ID" >/dev/null || true
  local current
  current="$(current_input_source)"
  if [[ "$current" != "$TARGET_SOURCE_ID" ]]; then
    print_prepare_result "not-ready" "$current"
    cat <<EOF >&2
IME smoke precheck failed.
Current input source is [$current], not [$TARGET_SOURCE_ID].
Resolve system authorization or input-source selection first, then rerun:
  ./scripts/smoke-ime.sh prepare
EOF
    exit 1
  fi
  print_prepare_result "ready" "$current"
}

activate_textedit() {
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

ensure_textedit_input_source() {
  activate_textedit
  "$ROOT_DIR/select-input-source.sh" select "$TARGET_SOURCE_ID" >/dev/null || true
  assert_input_source
}

focus_text_view() {
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

focus_after_first_character() {
  focus_text_view
  smoke_key right
}

clear_composition() {
  "$PRESS_KEY" escape --activate "$TEXTEDIT_BUNDLE_ID" >/dev/null 2>&1 || true
  "$PRESS_KEY" escape --activate "$TEXTEDIT_BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 0.2
}

clear_document() {
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

set_document_text() {
  local text="$1"
  activate_textedit
  osascript - "$text" <<'EOF' >/dev/null
on run argv
  tell application id "com.apple.TextEdit"
    set text of front document to item 1 of argv
  end tell
end run
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

display_count() {
  swift -e 'import AppKit; print(NSScreen.screens.count)'
}

capture_displays() {
  local prefix="$1"
  local count
  count="$(display_count 2>/dev/null || printf '1')"
  local index
  for ((index = 1; index <= count; index++)); do
    screencapture -x -D "$index" "${prefix}-display${index}.png" >/dev/null 2>&1 || true
  done
}

start_log_stream() {
  : >"$LOG_FILE"
  log stream --style compact --predicate 'process == "BilineIMEDev" AND category == "smoke"' >"$LOG_FILE" 2>&1 &
  LOG_STREAM_PID=$!
  sleep 1
}

smoke_key() {
  "$PRESS_KEY" "$@" --activate "$TEXTEDIT_BUNDLE_ID" --system-events
  sleep 0.2
}

smoke_key_fast() {
  "$PRESS_KEY" "$@" --activate "$TEXTEDIT_BUNDLE_ID" --system-events
  sleep 0.02
}

smoke_repeat_key() {
  local count="$1"
  shift
  local index
  for ((index = 0; index < count; index++)); do
    smoke_key "$@"
  done
}

smoke_type_word() {
  local word="$1"
  local index
  for ((index = 0; index < ${#word}; index++)); do
    smoke_key "${word:index:1}"
  done
}

mark_case_log_offset() {
  if [[ -f "$LOG_FILE" ]]; then
    CURRENT_LOG_OFFSET="$(wc -l < "$LOG_FILE" | tr -d ' ')"
  else
    CURRENT_LOG_OFFSET=0
  fi
}

latest_smoke_line() {
  if [[ ! -f "$LOG_FILE" ]]; then
    return 1
  fi
  tail -n +"$((CURRENT_LOG_OFFSET + 1))" "$LOG_FILE" | rg 'SMOKE ' | tail -n 1
}

smoke_field() {
  local key="$1"
  local line
  line="$(latest_smoke_line || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi
  printf '%s\n' "$line" | tr ' ' '\n' | rg "^${key}=" | tail -n 1 | cut -d= -f2-
}

expect_smoke_field() {
  local key="$1"
  local expected="$2"
  local attempts="${3:-30}"
  local actual=""
  local index

  for ((index = 0; index < attempts; index++)); do
    actual="$(smoke_field "$key" || true)"
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

write_case_metadata() {
  {
    echo "case=$CURRENT_CASE"
    echo "input_source=$(current_input_source)"
    echo "host_text=$(read_host_text)"
    echo "latest_smoke=$(latest_smoke_line || true)"
  } >"$CURRENT_CASE_DIR/metadata.txt"
}

begin_case() {
  CURRENT_CASE="$1"
  CURRENT_CASE_DIR="$OUTPUT_ROOT/$CURRENT_CASE"
  mkdir -p "$CURRENT_CASE_DIR"
  ensure_textedit_input_source
  clear_document
  mark_case_log_offset
}

run_case() {
  local name="$1"
  TOTAL_CASES=$((TOTAL_CASES + 1))
  begin_case "$name"
  if "$name"; then
    printf 'PASS %s\n' "$name" | tee -a "$SUMMARY_FILE"
  else
    FAILED_CASES=$((FAILED_CASES + 1))
    write_case_metadata
    capture_displays "$CURRENT_CASE_DIR/failure"
    printf 'FAIL %s\n' "$name" | tee -a "$SUMMARY_FILE"
  fi
}

case_browse_expand_equal() {
  smoke_key s
  smoke_key h
  smoke_key i
  expect_smoke_field compositionMode candidateCompact || return 1
  smoke_key equal
  expect_smoke_field compositionMode candidateExpanded || return 1
  expect_smoke_field selectedRow 1 || return 1
  expect_smoke_field rawInput shi || return 1
}

case_browse_collapse_minus() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key equal
  smoke_key minus
  expect_smoke_field compositionMode candidateExpanded || return 1
  expect_smoke_field selectedRow 0 || return 1
  smoke_key minus
  expect_smoke_field compositionMode candidateCompact || return 1
  expect_smoke_field selectedRow 0 || return 1
  expect_smoke_field selectedColumn 0 || return 1
}

case_left_right_move_columns() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key right
  expect_smoke_field selectedColumn 1 || return 1
  smoke_key left
  expect_smoke_field selectedColumn 0 || return 1
}

case_up_down_browse_rows() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key down
  expect_smoke_field compositionMode candidateExpanded || return 1
  expect_smoke_field selectedRow 1 || return 1
  smoke_key up
  expect_smoke_field compositionMode candidateExpanded || return 1
  expect_smoke_field selectedRow 0 || return 1
}

case_literal_underscore_stays_in_preedit() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key minus --shift
  expect_smoke_field compositionMode rawBufferOnly || return 1
  expect_smoke_field rawInput 'shi_' || return 1
  expect_smoke_field displayRawInput 'shi＿' || return 1
}

case_literal_percent_stays_in_preedit() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key 5 --shift
  expect_smoke_field compositionMode rawBufferOnly || return 1
  expect_smoke_field rawInput 'shi%' || return 1
  expect_smoke_field displayRawInput 'shi％' || return 1
}

case_literal_parentheses_use_chinese_punctuation() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key 9 --shift
  smoke_key 0 --shift
  expect_smoke_field compositionMode rawBufferOnly || return 1
  expect_smoke_field rawInput 'shi()' || return 1
  expect_smoke_field displayRawInput 'shi（）' || return 1
}

case_comma_commits_chinese_punctuation() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key comma
  expect_host_text '是，' || return 1
  expect_smoke_field isComposing false || return 1
}

case_raw_buffer_symbols_accumulate() {
  smoke_key n
  smoke_key i
  smoke_repeat_key 4 minus
  smoke_repeat_key 4 equal
  smoke_key equal --shift
  expect_smoke_field compositionMode rawBufferOnly || return 1
  expect_smoke_field rawInput 'ni----====+' || return 1
  expect_smoke_field displayRawInput 'ni－－－－＝＝＝＝＋' || return 1
}

case_backspace_restores_candidates() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key minus --shift
  expect_smoke_field compositionMode rawBufferOnly || return 1
  smoke_key backspace
  expect_smoke_field compositionMode candidateCompact || return 1
  expect_smoke_field rawInput 'shi' || return 1
}

case_backspace_returns_to_host_after_empty() {
  set_document_text "X"
  focus_after_first_character
  smoke_key s
  expect_smoke_field rawInput 's' || return 1
  smoke_key backspace
  expect_smoke_field rawInput '<empty>' || return 1
  expect_host_text 'X' || return 1
  smoke_key backspace
  expect_host_text '' || return 1
}

case_space_commits_chinese() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key space
  expect_host_text '是' || return 1
}

case_return_commits_chinese() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key return
  expect_host_text '是' || return 1
}

case_digit_select_commits_second_candidate() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key 2
  expect_host_text '时' || return 1
}

case_escape_cancels_composition() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key escape
  expect_host_text '' || return 1
  expect_smoke_field isComposing false || return 1
}

case_shift_tab_persists_across_browse() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key tab --shift
  expect_smoke_field activeLayer english || return 1
  smoke_key equal
  expect_smoke_field compositionMode candidateExpanded || return 1
  expect_smoke_field activeLayer english || return 1
  smoke_key right
  expect_smoke_field selectedColumn 1 || return 1
  expect_smoke_field activeLayer english || return 1
}

case_shift_tab_is_noop_in_raw_buffer_only() {
  smoke_key s
  smoke_key h
  smoke_key i
  smoke_key minus --shift
  expect_smoke_field compositionMode rawBufferOnly || return 1
  expect_smoke_field activeLayer chinese || return 1
  smoke_key tab --shift
  expect_smoke_field compositionMode rawBufferOnly || return 1
  expect_smoke_field activeLayer chinese || return 1
  expect_host_text 'shi＿' || return 1
}

case_phrase_candidate_commits_full_english() {
  smoke_type_word haopingguo
  smoke_key_fast tab --shift
  sleep 1.2
  expect_smoke_field activeLayer english || return 1
  smoke_key space
  expect_host_text 'good apple' || return 1
  expect_smoke_field isComposing false || return 1
}

case_phrase_candidate_commits_full_chinese() {
  smoke_type_word haopingguo
  smoke_key space
  expect_host_text '好苹果' || return 1
  expect_smoke_field isComposing false || return 1
}

case_prefix_candidate_partial_commits_english_and_keeps_tail() {
  smoke_type_word haopingguo
  smoke_key_fast tab --shift
  sleep 1.2
  smoke_key right
  expect_smoke_field selectedColumn 1 || return 1
  smoke_key space
  expect_smoke_field rawInput pingguo || return 1
  expect_smoke_field compositionMode candidateCompact || return 1
  expect_smoke_field activeLayer english || return 1
  expect_host_text 'goodpingguo' || return 1
}

case_prefix_candidate_partial_commits_chinese_and_keeps_tail() {
  smoke_type_word haopingguo
  smoke_key right
  expect_smoke_field selectedColumn 1 || return 1
  smoke_key space
  expect_smoke_field rawInput pingguo || return 1
  expect_smoke_field compositionMode candidateCompact || return 1
  expect_smoke_field activeLayer chinese || return 1
  expect_host_text '好pingguo' || return 1
}

case_prefix_candidate_partial_commit_backspace_only_edits_tail() {
  smoke_type_word haopingguo
  smoke_key_fast tab --shift
  sleep 1.2
  smoke_key right
  expect_smoke_field selectedColumn 1 || return 1
  smoke_key space
  expect_smoke_field rawInput pingguo || return 1
  smoke_key backspace
  expect_smoke_field rawInput pinggu || return 1
  expect_smoke_field activeLayer english || return 1
  expect_host_text 'goodpinggu' || return 1
}

run_all_cases() {
  local cases=(
    case_browse_expand_equal
    case_browse_collapse_minus
    case_left_right_move_columns
    case_up_down_browse_rows
    case_literal_underscore_stays_in_preedit
    case_literal_percent_stays_in_preedit
    case_literal_parentheses_use_chinese_punctuation
    case_comma_commits_chinese_punctuation
    case_raw_buffer_symbols_accumulate
    case_backspace_restores_candidates
    case_backspace_returns_to_host_after_empty
    case_space_commits_chinese
    case_return_commits_chinese
    case_digit_select_commits_second_candidate
    case_escape_cancels_composition
    case_shift_tab_persists_across_browse
    case_shift_tab_is_noop_in_raw_buffer_only
    case_phrase_candidate_commits_full_english
    case_phrase_candidate_commits_full_chinese
    case_prefix_candidate_partial_commits_english_and_keeps_tail
    case_prefix_candidate_partial_commits_chinese_and_keeps_tail
    case_prefix_candidate_partial_commit_backspace_only_edits_tail
  )

  local case_name
  for case_name in "${cases[@]}"; do
    run_case "$case_name"
  done
}

run_single_case() {
  local case_name="$1"
  if ! declare -F "$case_name" >/dev/null 2>&1; then
    echo "Unknown case: $case_name" >&2
    exit 1
  fi
  run_case "$case_name"
}

prepare_command() {
  printf 'output=%s\n' "$OUTPUT_ROOT" >"$SUMMARY_FILE"
  prepare_input_source
  activate_textedit
}

run_command() {
  prepare_input_source
  activate_textedit
  start_log_stream
  run_all_cases
  printf 'total=%d failed=%d output=%s\n' "$TOTAL_CASES" "$FAILED_CASES" "$OUTPUT_ROOT" | tee -a "$SUMMARY_FILE"
  if [[ "$FAILED_CASES" -gt 0 ]]; then
    exit 1
  fi
}

case_command() {
  local case_name="$1"
  prepare_input_source
  activate_textedit
  start_log_stream
  run_single_case "$case_name"
  printf 'total=%d failed=%d output=%s\n' "$TOTAL_CASES" "$FAILED_CASES" "$OUTPUT_ROOT" | tee -a "$SUMMARY_FILE"
  if [[ "$FAILED_CASES" -gt 0 ]]; then
    exit 1
  fi
}

main() {
  local command="${1:-all}"
  acquire_lock
  case "$command" in
    prepare)
      prepare_command
      ;;
    run)
      run_command
      ;;
    case)
      if [[ $# -lt 2 ]]; then
        echo "usage: $0 case <case_name>" >&2
        exit 1
      fi
      case_command "$2"
      ;;
    all)
      prepare_command
      run_command
      ;;
    *)
      echo "usage: $0 [prepare|run|case <case_name>]" >&2
      exit 1
      ;;
  esac
}

main "$@"
