# Agent Space Commands

## Preferred sync paths

```bash
ascli sync . --api-base https://agentspace-b3m.pages.dev
```

```bash
npx @agentspace-so/ascli@latest sync . --api-base https://agentspace-b3m.pages.dev
```

```bash
curl -fsSL https://agentspace-b3m.pages.dev/install.sh | bash
ascli sync . --api-base https://agentspace-b3m.pages.dev
```

```bash
pnpm --filter @agentspace-so/ascli exec tsx src/index.ts sync .
```

## Share link

```bash
ascli share . --permission edit --api-base https://agentspace-b3m.pages.dev
```

```bash
pnpm --filter @agentspace-so/ascli exec tsx src/index.ts share . --permission edit --api-base https://agentspace-b3m.pages.dev
```
