#!/usr/bin/env python3
"""
Extract a generated image from a Codex CLI session rollout.

Codex CLI's `imagegen` tool does not write a standalone PNG to disk. Instead,
the generated image is embedded in the session rollout JSONL file under
`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` as a base64-encoded payload.

This script scans one or more session JSONL files, finds the base64 blob whose
header matches a known image format (PNG, JPEG, or WebP), decodes it, and
writes the result to the caller-specified output path. When multiple image
payloads are present (e.g. image-to-image where the session contains both the
reference image and the generated output), the largest blob is selected — the
generated output is always at native resolution and larger than the user's
reference.

Usage:
    extract_image.py <out_path> <sessions_list_file>

Arguments:
    out_path            Absolute path to write the decoded image to.
    sessions_list_file  Path to a text file containing one session-rollout
                        path per line. Every listed file is scanned.

Exit codes:
    0  success; decoded image written to out_path.
    1  no image payload found across the listed session files.
"""

from __future__ import annotations

import base64
import json
import pathlib
import re
import sys

# Magic prefixes of the base64-encoded image formats Codex may emit.
# These correspond to the raw byte headers:
#   PNG  \x89 P N G \r \n \x1a \n   → base64 starts "iVBORw0KGgo"
#   JPEG \xFF \xD8 \xFF             → base64 starts "/9j/"
#   WebP R I F F . . . . W E B P    → base64 starts "UklGR"
IMAGE_MAGIC_PREFIXES: dict[str, str] = {
    "iVBORw0KGgo": "png",
    "/9j/": "jpg",
    "UklGR": "webp",
}

# A base64 blob shorter than this is almost certainly not an image. The
# threshold keeps us well clear of matching accidental long identifiers while
# still admitting small thumbnails.
MIN_BLOB_LENGTH = 200

# Matches any quoted string composed entirely of base64 characters. The
# character class intentionally excludes the data-URI prefix characters
# (`:`, `/`, `;`, `,`), so data-URI fields in the JSONL never match — this
# prevents us from accidentally grabbing a user-provided reference image that
# was embedded as `"data:image/png;base64,..."`. Codex stores the generated
# output as a pure base64 string (no data-URI wrapper), which is what we want.
BASE64_BLOB_PATTERN = re.compile(r'"([A-Za-z0-9+/=]{' + str(MIN_BLOB_LENGTH) + r',})"')


def find_best_image_blob(session_paths: list[pathlib.Path]) -> tuple[str, str] | None:
    """Scan the given session files and return the largest image payload.

    Returns a (base64_string, extension) tuple, or None if no image payload
    was found across all files.
    """
    best: tuple[str, str, int] | None = None  # (blob, ext, length)
    for session_path in session_paths:
        try:
            text = session_path.read_text(errors="replace")
        except OSError:
            continue
        for line in text.splitlines():
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            flat = json.dumps(obj)
            for match in BASE64_BLOB_PATTERN.finditer(flat):
                blob = match.group(1)
                for magic, ext in IMAGE_MAGIC_PREFIXES.items():
                    if blob.startswith(magic):
                        if best is None or len(blob) > best[2]:
                            best = (blob, ext, len(blob))
                        break
    if best is None:
        return None
    return best[0], best[1]


# Image file extensions we're willing to write. The caller may not specify an
# arbitrary extension — this prevents the script from being misused to drop
# executable or config files to the output path.
ALLOWED_OUTPUT_EXTENSIONS: frozenset[str] = frozenset({".png", ".jpg", ".jpeg", ".webp"})

# System directory prefixes the output path must never resolve under. The
# resolved (absolute, symlink-followed) output path is checked against these
# before we open the file for writing.
FORBIDDEN_OUTPUT_PREFIXES: tuple[str, ...] = (
    "/bin", "/boot", "/dev", "/etc", "/lib", "/proc",
    "/sbin", "/sys", "/usr", "/System", "/Library",
    "/var/root", "/var/log", "/var/db",
)


def validate_output_path(raw_out: str) -> pathlib.Path:
    """Validate and canonicalise the caller-supplied output path.

    Rejects:
      - paths whose extension is not a known image format
      - paths that resolve (absolute, symlink-followed) under a system dir

    Returns the resolved absolute path on success; raises ValueError otherwise.
    `Path.resolve()` already follows symlinks, so an attacker-planted symlink
    pointing at `/etc/passwd` gets normalised to `/etc/passwd` before the
    forbidden-prefix check runs.
    """
    candidate = pathlib.Path(raw_out)
    ext = candidate.suffix.lower()
    if ext not in ALLOWED_OUTPUT_EXTENSIONS:
        raise ValueError(
            f"output path must end in one of {sorted(ALLOWED_OUTPUT_EXTENSIONS)}; got {ext!r}"
        )

    # Resolve to an absolute path, following symlinks where they exist. If the
    # target file doesn't exist yet, resolve still canonicalises its parents.
    resolved = candidate.expanduser().resolve()
    resolved_str = str(resolved)

    # On macOS, `/etc`, `/var`, `/tmp`, and some others are symlinks into
    # `/private/…`; compute the non-`/private` view so a forbidden prefix like
    # `/etc` matches a resolved path of `/private/etc/foo.png`.
    alt_str = (
        resolved_str[len("/private"):] if resolved_str.startswith("/private/") else None
    )

    def _is_under_forbidden(path_str: str) -> bool:
        return any(
            path_str == f or path_str.startswith(f + "/")
            for f in FORBIDDEN_OUTPUT_PREFIXES
        )

    if _is_under_forbidden(resolved_str) or (alt_str and _is_under_forbidden(alt_str)):
        raise ValueError(f"refusing to write under a system directory: {resolved}")

    return resolved


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(
            "usage: extract_image.py <out_path> <sessions_list_file>",
            file=sys.stderr,
        )
        return 2

    try:
        out_path = validate_output_path(argv[1])
    except ValueError as err:
        print(f"invalid --out path: {err}", file=sys.stderr)
        return 2

    sessions_list_path = pathlib.Path(argv[2])

    session_paths = [
        pathlib.Path(line)
        for line in sessions_list_path.read_text().splitlines()
        if line.strip()
    ]

    result = find_best_image_blob(session_paths)
    if result is None:
        print("IMAGE_NOT_FOUND_IN_SESSION", file=sys.stderr)
        return 1

    blob, _ext = result
    # Safe to decode: the blob was captured by a strict [A-Za-z0-9+/=] regex
    # above, so base64.b64decode cannot trigger anything except producing
    # bytes. The output path was validated by validate_output_path().
    image_bytes = base64.b64decode(blob)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(image_bytes)
    print(out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
