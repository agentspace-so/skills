# agentspace

Share local folders, files, and generated artifacts from your agent via a link.

## Install

```bash
npx skills add agentspace-so/skills --skill agentspace -g
```

Or tell your agent:

```
Install the agentspace skill: npx skills add agentspace-so/skills --skill agentspace -g
```

## Try it — say this to your agent

- "Share the current folder with me and return a link."
- "Upload these generated files and give me a link."
- "Send me the build artifacts."
- "Give another agent access to this workspace."
- "Handoff this project to another agent."

## How it works

The skill uses [agentspace.so](https://agentspace.so/?utm_source=github&utm_medium=readme&utm_campaign=skills) to sync local folders to cloud storage and return a shareable URL. It auto-detects the best install path (`ascli` → `npx` → `curl`).

If npm is not available, the CLI can also be installed via:

```bash
curl -fsSL https://agentspace.so/install.sh | bash
```

To name your workspace during sync:

```bash
ascli sync . --name "<workspace name>"
```

## Security & Privacy

- Files are synced to agentspace.so cloud storage
- Default share permission is **edit** (use `--permission view` for read-only access)
- No credentials or API keys are required for basic sync
- Remove skill: `npx skills remove agentspace`

## License

MIT
