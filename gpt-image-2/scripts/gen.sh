#!/usr/bin/env bash
# Generate an image via Codex CLI's imagegen tool, reusing the user's
# ChatGPT subscription session. Supports text-to-image and image-to-image.
#
# Implementation note: on codex-cli 0.111.0 the `imagegen` tool does NOT
# write a PNG file to disk. The generated image is embedded as base64 inside
# the session rollout jsonl under ~/.codex/sessions/YYYY/MM/DD/. This script
# captures the new session file created by the run and decodes the image
# out of it. Flags: `--enable image_generation` turns the under-development
# tool on; `--ephemeral` is intentionally NOT passed so the session is
# persisted and we can read it back.
#
# Usage:
#   gen.sh --prompt "<text>" --out <path.png> [--ref <image>]... [--timeout-sec N]
#
# Exit codes:
#   0 success (path printed on stdout)
#   2 bad args
#   3 required CLI missing (codex / python3)
#   4 reference image not found
#   5 codex exec failed
#   6 no new session file detected
#   7 image payload not found in session file (imagegen likely did not run)

set -euo pipefail

PROMPT=""
OUT=""
REF_IMAGES=()
TIMEOUT_SEC=300

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)      PROMPT="$2"; shift 2 ;;
    --out)         OUT="$2"; shift 2 ;;
    --ref)         REF_IMAGES+=("$2"); shift 2 ;;
    --timeout-sec) TIMEOUT_SEC="$2"; shift 2 ;;
    -h|--help)     sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$PROMPT" ]] && { echo "Missing --prompt" >&2; exit 2; }
[[ -z "$OUT" ]]    && { echo "Missing --out" >&2; exit 2; }

command -v codex >/dev/null 2>&1 || {
  echo "codex CLI not found. Install Codex CLI and run 'codex login' first." >&2
  exit 3
}
command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 3; }

SESSIONS_ROOT="$HOME/.codex/sessions"
mkdir -p "$SESSIONS_ROOT"

before="$(mktemp)"; after="$(mktemp)"
stdout_log="$(mktemp)"; stderr_log="$(mktemp)"
trap 'rm -f "$before" "$after" "$stdout_log" "$stderr_log"' EXIT

find "$SESSIONS_ROOT" -type f -name 'rollout-*.jsonl' -print 2>/dev/null | sort > "$before" || true

# Intentionally NOT using --ephemeral: we need the session rollout on disk.
args=(exec --skip-git-repo-check --sandbox read-only --color never --enable image_generation)
if [[ ${#REF_IMAGES[@]} -gt 0 ]]; then
  for img in "${REF_IMAGES[@]}"; do
    [[ -f "$img" ]] || { echo "Reference image not found: $img" >&2; exit 4; }
    args+=(-i "$img")
  done
fi

instruction="Use the imagegen tool to generate the image for the following request."
if [[ ${#REF_IMAGES[@]} -gt 0 ]]; then
  instruction+=" Use the attached image(s) as visual reference / input for image-to-image."
fi
instruction+=$'\nRequirements: generate the image directly, return only the image, no explanation.\n\nRequest:\n'"$PROMPT"

# `-i` is a variadic flag (<FILE>...), so passing the prompt as the trailing
# positional would be consumed as another image file. Feed the prompt via
# stdin instead (codex exec reads from stdin when no prompt positional is
# given).

TO=""
if   command -v timeout  >/dev/null 2>&1; then TO="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout"
fi

set +e
if [[ -n "$TO" ]]; then
  printf '%s' "$instruction" | "$TO" "$TIMEOUT_SEC" codex "${args[@]}" >"$stdout_log" 2>"$stderr_log"
else
  printf '%s' "$instruction" | codex "${args[@]}" >"$stdout_log" 2>"$stderr_log"
fi
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  echo "codex exec failed (exit=$rc). stderr tail:" >&2
  tail -n 40 "$stderr_log" >&2 || true
  exit 5
fi

find "$SESSIONS_ROOT" -type f -name 'rollout-*.jsonl' -print 2>/dev/null | sort > "$after" || true

# Collect ALL new session files. A single `codex exec` call can spawn more
# than one session rollout (e.g. when the imagegen tool runs in a sub-turn),
# so we must scan every new one rather than blindly picking the last.
new_sessions_file="$(mktemp)"
trap 'rm -f "$before" "$after" "$stdout_log" "$stderr_log" "$new_sessions_file"' EXIT
comm -13 "$before" "$after" > "$new_sessions_file" || true

if [[ ! -s "$new_sessions_file" ]]; then
  echo "No new session rollout file under $SESSIONS_ROOT" >&2
  tail -n 40 "$stderr_log" >&2 || true
  exit 6
fi

# Extract the image. Iterate over all new session files; in each, find the
# LAST large base64 blob whose header matches a known image format. Prefer
# the largest such blob across all sessions (the generated image is the
# high-resolution output; text-to-image has a single blob; image-to-image
# has at most two — the reference input and the generated output — and the
# output is the larger one when the model produces at native Image-2 res).
set +e
python3 - "$OUT" "$new_sessions_file" <<'PY'
import base64, json, pathlib, re, sys

out_path = pathlib.Path(sys.argv[1])
session_list_path = pathlib.Path(sys.argv[2])
session_paths = [pathlib.Path(p) for p in session_list_path.read_text().splitlines() if p.strip()]

MAGIC = {
    "iVBORw0KGgo": "png",   # PNG header
    "/9j/":        "jpg",   # JPEG SOI
    "UklGR":       "webp",  # RIFF....WEBP
}

best = None  # (blob, ext, source_path)
for session_path in session_paths:
    try:
        text = session_path.read_text(errors="replace")
    except Exception:
        continue
    for line in text.splitlines():
        try:
            obj = json.loads(line)
        except Exception:
            continue
        flat = json.dumps(obj)
        for m in re.finditer(r'"([A-Za-z0-9+/=]{500,})"', flat):
            blob = m.group(1)
            for magic, ext in MAGIC.items():
                if blob.startswith(magic):
                    if best is None or len(blob) > len(best[0]):
                        best = (blob, ext, session_path)
                    break

if best is None:
    print("IMAGE_NOT_FOUND_IN_SESSION", file=sys.stderr)
    sys.exit(7)

data = base64.b64decode(best[0])
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_bytes(data)
print(out_path)
PY
py_rc=$?
set -e

if [[ $py_rc -ne 0 ]]; then
  echo "Image payload not found in any new session file" >&2
  echo "(imagegen likely did not run; stderr tail:)" >&2
  tail -n 30 "$stderr_log" >&2 || true
  exit 7
fi
