#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/ime-paths.sh"

DOMAIN="${BILINE_DEFAULTS_DOMAIN:-$DEV_BUNDLE_ID}"
DEFAULT_REGION="cn-hangzhou"
DEFAULT_ENDPOINT="https://mt.cn-hangzhou.aliyuncs.com"
CREDENTIAL_FILE="${BILINE_CREDENTIAL_FILE:-$HOME/Library/Containers/$DOMAIN/Data/Library/Application Support/BilineIME/alibaba-credentials.json}"

usage() {
  cat <<EOF
usage: $0 [configure|status|clear]

configure  Prompt for Alibaba Cloud AccessKey values and store them locally.
status     Print provider and credential presence without revealing secrets.
clear      Remove Biline Alibaba credentials and provider defaults.

Environment:
  BILINE_DEFAULTS_DOMAIN  Defaults domain to configure. Defaults to dev IME.
  BILINE_CREDENTIAL_FILE  Credential file path. Defaults to the IME container.
EOF
}

read_secret() {
  local prompt="$1"
  local value=""
  printf "%s" "$prompt" >&2
  IFS= read -rs value
  printf "\n" >&2
  printf "%s" "$value"
}

read_plain_default() {
  local prompt="$1"
  local fallback="$2"
  local value=""
  printf "%s [%s]: " "$prompt" "$fallback" >&2
  IFS= read -r value
  if [[ -z "$value" ]]; then
    printf "%s" "$fallback"
  else
    printf "%s" "$value"
  fi
}

defaults_value() {
  local key="$1"
  defaults read "$DOMAIN" "$key" 2>/dev/null || true
}

credential_file_lengths() {
  if [[ ! -f "$CREDENTIAL_FILE" ]]; then
    echo "credential_file=missing"
    return
  fi
  python3 - "$CREDENTIAL_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception:
    print("credential_file=unreadable")
    raise SystemExit(0)

access_key_id = str(data.get("accessKeyId", ""))
access_key_secret = str(data.get("accessKeySecret", ""))
print(f"credential_file={path}")
print(f"credential_file_accessKeyId={len(access_key_id) if access_key_id else 'missing'}")
print(f"credential_file_accessKeySecret={len(access_key_secret) if access_key_secret else 'missing'}")
PY
}

configure() {
  local access_key_id access_key_secret region endpoint
  access_key_id="$(read_secret "Alibaba AccessKey ID: ")"
  access_key_secret="$(read_secret "Alibaba AccessKey Secret: ")"
  region="$(read_plain_default "Alibaba region" "$DEFAULT_REGION")"
  endpoint="$(read_plain_default "Alibaba endpoint" "$DEFAULT_ENDPOINT")"

  if [[ -z "$access_key_id" || -z "$access_key_secret" ]]; then
    echo "AccessKey ID and secret are required." >&2
    exit 1
  fi

  install -d -m 700 "$(dirname "$CREDENTIAL_FILE")"
  printf '%s\0%s\0%s\0%s' "$access_key_id" "$access_key_secret" "$region" "$endpoint" \
    | python3 -c '
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
access_key_id, access_key_secret, region, endpoint = [
    item.decode() for item in sys.stdin.buffer.read().split(b"\0")
]
path.write_text(json.dumps({
    "accessKeyId": access_key_id,
    "accessKeySecret": access_key_secret,
    "regionId": region,
    "endpoint": endpoint,
}, separators=(",", ":")))
' "$CREDENTIAL_FILE"
  chmod 600 "$CREDENTIAL_FILE"
  unset access_key_id access_key_secret

  defaults write "$DOMAIN" BilineTranslationProvider aliyun
  defaults write "$DOMAIN" BilineAlibabaRegionId "$region"
  defaults write "$DOMAIN" BilineAlibabaEndpoint "$endpoint"
  killall cfprefsd >/dev/null 2>&1 || true

  echo "Alibaba translation provider configured for $DOMAIN."
  status
}

status() {
  local provider region endpoint
  provider="$(defaults_value BilineTranslationProvider)"
  region="$(defaults_value BilineAlibabaRegionId)"
  endpoint="$(defaults_value BilineAlibabaEndpoint)"

  echo "domain=$DOMAIN"
  echo "provider=${provider:-<missing>}"
  echo "region=${region:-<missing>}"
  echo "endpoint=${endpoint:-<missing>}"
  credential_file_lengths
}

clear() {
  rm -f "$CREDENTIAL_FILE" >/dev/null 2>&1 || true
  defaults delete "$DOMAIN" BilineTranslationProvider >/dev/null 2>&1 || true
  defaults delete "$DOMAIN" BilineAlibabaRegionId >/dev/null 2>&1 || true
  defaults delete "$DOMAIN" BilineAlibabaEndpoint >/dev/null 2>&1 || true
  killall cfprefsd >/dev/null 2>&1 || true
  echo "Alibaba translation provider credentials cleared for $DOMAIN."
}

COMMAND="${1:-status}"
case "$COMMAND" in
  configure)
    configure
    ;;
  status)
    status
    ;;
  clear)
    clear
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
