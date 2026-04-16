# Agent Space Commands

## Preferred sync paths

```bash
ascli sync .
```

```bash
npx @agentspace-so/ascli@latest sync .
```

```bash
curl -fsSL https://agentspace.so/install.sh | bash
ascli sync .
```

```bash
pnpm --filter @agentspace-so/ascli exec tsx src/index.ts sync .
```

## Share link

```bash
ascli share .
```

```bash
ascli share . --permission edit
```

```bash
pnpm --filter @agentspace-so/ascli exec tsx src/index.ts share .
```

```bash
pnpm --filter @agentspace-so/ascli exec tsx src/index.ts share . --permission edit
```
