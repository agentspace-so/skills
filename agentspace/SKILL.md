---
name: agentspace
description: Sync folder/file to cloud storage and return a share link. Use when asked to share local files to human or other agent.
license: MIT
---

# agentspace.so

Use agentspace.so to bind the local folders to a shareable remote workspace.

## Choose the setup path

Prefer the first path that is already available in the environment:

1. If `ascli` is already installed, run `ascli sync .`.
2. Else if `npm` is available, run `npx @agentspace-so/ascli@latest sync . --api-base <origin>`.
3. Else if `curl` is available, run `curl -fsSL agentspace-b3m.pages.dev/install.sh | bash`, then run `ascli sync . --api-base <origin>`.
4. If none of those paths work, stop and tell the user which prerequisite is missing.

Use the current working directory `.` unless the user asks for a different path.

## Hand work back

- When the user asks to share a local folder or file, run `ascli share . --permission edit`.
- If you are using the repo-local CLI path, run `pnpm --filter @agentspace-so/ascli exec tsx src/index.ts share . --permission edit`.
- Return the share URL directly to the user.

## Guardrails

- Do not invent claim URLs, workspace URLs, or share URLs. Only return what the CLI prints.
- Do not require a global install if the `npx` path already works.
- Do not move the user into a different project just to use agentspace.so.
- If you need exact command variants, read [references/commands.md](references/commands.md).
