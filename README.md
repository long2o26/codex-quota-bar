# CodexQuotaBar

macOS menu bar widget for Codex quota.

It reads local Codex session logs from `~/.codex/sessions/**/*.jsonl` and shows remaining quota in two compact menu-bar rows:

- `5h`: primary window
- `7d`: secondary window
- color is based on the lower remaining value: green `>60`, orange `20...60`, red `<20`

Build:

```bash
./scripts/build.sh
open ./build/CodexQuotaBar.app
```

Check the parsed value without opening the menu bar app:

```bash
./build/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --print-once
```

Install as a login item:

```bash
./scripts/install.sh
```

Uninstall:

```bash
./scripts/uninstall.sh
```

The number only changes after Codex writes a new `token_count` event.
