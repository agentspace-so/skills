---
name: gpt-image-2
displayName: "🪞 GPT Image 2 — Image Generation via Your ChatGPT Subscription"
description: >
  Generate images with GPT Image 2 (ChatGPT Images 2.0) inside Claude Code,
  using your existing ChatGPT Plus or Pro subscription — no OpenAI API key,
  no per-image billing. Supports text-to-image, image-to-image editing,
  style transfer, and multi-reference composition via the local Codex CLI.
  Triggers on "gpt image 2", "gpt-image-2", "ChatGPT Images 2.0", "image 2",
  or any explicit ask to generate or edit an image through the user's
  ChatGPT plan.
emoji: "🪞"
license: MIT
---

# 🪞 GPT Image 2 — Image Generation via Your ChatGPT Subscription

Generate images with **GPT Image 2** (ChatGPT Images 2.0) inside Claude Code, using the ChatGPT Plus or Pro subscription you already pay for — **no OpenAI API key, no Fal / Replicate key, no per-image billing.**

Text-to-image, image-to-image editing, style transfer, and multi-reference composition. Runs entirely through the local `codex` CLI you're already logged into.

## Gallery

### Native text rendering (text-to-image)

![GPT Image 2 poster with legible typography](https://raw.githubusercontent.com/agentspace-so/skills/main/gpt-image-2/gallery/a-poster.png)

Every letter, the slash, the em-dash, and the italic tagline are **rendered, not hallucinated**. Legible in-image text is the one thing every other image model still stumbles on; Image 2 makes it the default.

### Style transfer (image-to-image)

![Lobster repainted as ukiyo-e woodblock print](https://raw.githubusercontent.com/agentspace-so/skills/main/gpt-image-2/gallery/d-ukiyoe.png)

A flat-color source icon repainted as a 1950s ukiyo-e woodblock print. Composition preserved, rendering swapped. The model even added a correct red chop reading **海老之圖** because it knew the genre's visual grammar.

### Two-step agent workflow — character consistency across calls

<p>
  <img alt="CLAW logo generated from text" src="https://raw.githubusercontent.com/agentspace-so/skills/main/gpt-image-2/gallery/c1-logo.png" width="45%">
  <img alt="Same logo placed on a heather-gray t-shirt" src="https://raw.githubusercontent.com/agentspace-so/skills/main/gpt-image-2/gallery/c2-tshirt.png" width="45%">
</p>

Step 1 generates a brand mark (text-to-image). Step 2 passes that output back in as `--ref` and places it on a t-shirt mockup (image-to-image). The lobster on the t-shirt is **the same lobster** — other tools would redraw a new one and break brand consistency. This is the payoff for running GPT Image 2 behind an agent.

## When to trigger

Trigger when the user explicitly asks for GPT Image 2 via their ChatGPT subscription, for example:

- "use GPT Image 2" / "use gpt-image-2" / "use ChatGPT Images 2.0"
- "use Image 2" / "image 2 this"
- "用 GPT Image 2 生图" / "用我的 ChatGPT 订阅生图"
- attached a reference image and asked to remix / edit / restyle it

Do **not** auto-trigger for a plain "generate an image" request if the user didn't specify this route. If they did specify it, do not silently fall back to HTML mockups, screenshots, or a different image model.

## Prerequisites

1. `codex` CLI installed — `brew install codex` or see [openai/codex](https://github.com/openai/codex).
2. Logged in with a ChatGPT plan that includes Image 2 — `codex login`.
3. `python3` on PATH (ships with macOS; `apt install python3` on Linux).

This skill does **not** grant image-generation capability on its own. It exposes the capability the user already has through their ChatGPT subscription.

## How to invoke

A single bash script handles everything: runs `codex exec` with the right flags, then decodes the generated image from the persisted session rollout.

**Text-to-image:**

```bash
bash scripts/gen.sh \
  --prompt "<user's raw prompt>" \
  --out <absolute/path/to/output.png>
```

**Image-to-image** (reference flag is repeatable for multi-reference composition):

```bash
bash scripts/gen.sh \
  --prompt "<user's raw prompt, e.g. 'repaint in watercolor'>" \
  --ref /absolute/path/to/reference.png \
  --out <absolute/path/to/output.png>
```

Optional: `--timeout-sec 300` (default 300).

## Default behavior

- **Pass the user's prompt through raw.** Do not translate, polish, or add style modifiers unless the user asked for it.
- **Choose the output path.** Default to `./image-<YYYYMMDD-HHMMSS>.png` in the current working directory if the user didn't specify.
- **Deliver the image.** After the script succeeds, display / attach the output file. Do not stop at "done, see path X".
- **Text-heavy layouts are fine.** Image 2 handles infographics and timeline prompts well. Do not preemptively warn just because a prompt has a lot of text.

## Exit codes

| code | meaning |
|------|---------|
| 0    | success — output path printed on stdout |
| 2    | bad args |
| 3    | `codex` or `python3` CLI missing |
| 4    | `--ref` file does not exist |
| 5    | `codex exec` failed (auth? network? model?) |
| 6    | no new session file detected |
| 7    | imagegen did not produce an image payload (feature not enabled, quota, or capability refused) |

On failure, name the layer in one sentence instead of dumping the full stderr at the user.

## How it works

The `codex` CLI reuses the logged-in ChatGPT session and exposes an `imagegen` tool (gated behind the `image_generation` feature flag). The script:

1. snapshots `~/.codex/sessions/` before the run
2. runs `codex exec --enable image_generation --sandbox read-only ...` (with `-i <file>` for each reference image)
3. diffs the sessions directory, scans every new rollout JSONL for a base64 image payload (PNG / JPEG / WebP magic-header match)
4. decodes the largest matching blob and writes it to `--out`

Two non-obvious flags other wrappers get wrong on codex-cli 0.111.0+:

- `--enable image_generation` is **required**; the feature is still under-development and off by default.
- `--ephemeral` **must not** be used — ephemeral sessions aren't persisted, so the image payload has nowhere to live.

## Hard constraints

- Do not switch routes without permission. If the user said "use GPT Image 2", do not substitute DALL·E, Midjourney, an HTML mockup, or a manual screenshot workflow.
- Do not rewrite the prompt unless asked.
- Do not imply this skill works without a local `codex` login and a valid ChatGPT subscription with image-generation entitlement.

## What this skill is not

Not a direct OpenAI API client. Not a capability grant — it depends on the user's working Codex CLI login. Not a multi-tenant service (one call per invocation; concurrent calls are serialized by the filesystem-snapshot diff).
