# Agent Space Commands

## Preferred sync paths

```bash
ascli sync . --api-base https://agentspace.so
```

```bash
npx @agentspace-so/ascli@latest sync . --api-base https://agentspace.so
```

```bash
curl -fsSL https://agentspace.so/install.sh | bash
ascli sync . --api-base https://agentspace.so
```

```bash
pnpm --filter @agentspace-so/ascli exec tsx src/index.ts sync .
```

## Share link

```bash
ascli share . --permission edit --api-base https://agentspace.so
```

```bash
pnpm --filter @agentspace-so/ascli exec tsx src/index.ts share . --permission edit --api-base https://agentspace.so
```
