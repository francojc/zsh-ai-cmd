# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

zsh-ai-cmd is a zsh plugin that translates natural language to shell commands using LLM APIs. User types a description, presses `Ctrl+Z`, and sees the suggestion as ghost text. Tab accepts, typing dismisses.

## Architecture

The main plugin lives in @zsh-ai-cmd.plugin.zsh with provider implementations in `providers/`.

### Supported Providers

 | Provider   | File                      | Default Model               | API Key Env Var     | Custom Endpoint Var           |
 | ---------- | ------                    | ---------------             | -----------------   | -------------------           |
 | Anthropic  | `providers/anthropic.zsh` | `claude-haiku-4-5-20251001` | `ANTHROPIC_API_KEY` |                               |
 | OpenAI     | `providers/openai.zsh`    | `gpt-5.2-2025-12-11`        | `OPENAI_API_KEY`    | `ZSH_AI_CMD_OPENAI_BASE_URL`  |
 | Gemini     | `providers/gemini.zsh`    | `gemini-3-flash-preview`    | `GEMINI_API_KEY`    |                               |
 | DeepSeek   | `providers/deepseek.zsh`  | `deepseek-chat`             | `DEEPSEEK_API_KEY`  |                               |
 | Ollama     | `providers/ollama.zsh`    | `mistral-small`             | (none - local)      | `ZSH_AI_CMD_OLLAMA_HOST`      |
 | Copilot    | `providers/copilot.zsh`   | `gpt-4o`                    | (none - local)      | `ZSH_AI_CMD_COPILOT_HOST`     |

Set provider via `ZSH_AI_CMD_PROVIDER='openai'` (default: `anthropic`).

Override any provider's model with `ZSH_AI_CMD_<PROVIDER>_MODEL`, e.g.:

```sh
ZSH_AI_CMD_OPENAI_MODEL='gpt-4o'
ZSH_AI_CMD_GEMINI_MODEL='gemini-2.5-flash'
```

The legacy `ZSH_AI_CMD_MODEL` variable maps to `ZSH_AI_CMD_ANTHROPIC_MODEL` for backwards compatibility.

**Note:** Copilot requires [copilot-api](https://github.com/ericc-ch/copilot-api) to be running. Install and start with `npx copilot-api start`.

### API Key Retrieval

Keys are retrieved in this order:

1. Environment variables (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.)
2. Custom command (`ZSH_AI_CMD_API_KEY_COMMAND` with `${provider}` expansion) -- if configured
3. macOS Keychain (`ZSH_AI_CMD_KEYCHAIN_NAME`)

**Example custom command**:

```sh
export ZSH_AI_CMD_API_KEY_COMMAND='secret-tool lookup service ${provider}'
```

### Provider Implementation

Each provider file exports two functions:

- `_zsh_ai_cmd_<provider>_call "$input" "$prompt"` -- Makes API call, prints command to stdout
- `_zsh_ai_cmd_<provider>_key_error` -- Prints setup instructions when API key missing

The system prompt is shared across providers via `$_ZSH_AI_CMD_PROMPT` from `prompt.zsh`.

### Structured Output by Provider

Providers differ in how they extract the command from API responses:

- **Anthropic, OpenAI, Gemini**: strict JSON schema (`json_schema` response format)
- **DeepSeek**: `json_object` mode only (no schema); relies on prompt-based format instructions
- **Ollama**: `format` parameter with JSON schema (since Ollama v0.5)
- **Copilot**: no structured output support; falls back to plain text parsing with JSON fallback

When adding a new provider, decide which structured output tier it supports and follow the closest existing implementation.

## Testing

```sh
# API response validation (default: anthropic)
./test-api.sh
./test-api.sh --provider openai
./test-api.sh --provider gemini
./test-api.sh --provider ollama
./test-api.sh --provider deepseek
./test-api.sh --provider copilot

# API key retrieval tests
./test-api-key-command.sh

# Sanitization tests
./test-sanitize.sh
```

Manual testing:

```sh
source ./zsh-ai-cmd.plugin.zsh
# Type natural language, press Ctrl+Z
list files modified today<Ctrl+Z>
```

Enable debug logging:

```sh
ZSH_AI_CMD_DEBUG=true
tail -f ${ZSH_AI_CMD_LOG:-/tmp/zsh-ai-cmd.log}
```

## Code Conventions

- Uses `command` prefix (e.g., `command curl`, `command jq`) to bypass user aliases
- All configuration via `typeset -g` globals with `ZSH_AI_CMD_` prefix
- Internal functions/variables use `_zsh_ai_cmd_` or `_ZSH_AI_CMD_` prefix
- Pure zsh where possible; external deps limited to `curl`, `jq`, `security` (macOS)

## ZLE Widget Constraints

When modifying the spinner or UI code:

- `zle -R` forces redraw within widget context
- `zle -M` shows messages in minibuffer
- Background jobs need `NO_NOTIFY NO_MONITOR` to suppress job control noise
- `read -t 0.1` provides non-blocking sleep without external deps

**Dormant/Active State Machine:**

The plugin uses a state machine to avoid conflicts with other plugins (like zsh-autosuggestions):

- **Dormant** (default): Only `Ctrl+Z` trigger bound. Tab/right-arrow work normally.
- **Active** (after Ctrl+Z shows suggestion): Tab/right-arrow temporarily bound to accept. Uses `zle-line-pre-redraw` hook to detect buffer changes.
- **Deactivate** (on accept/dismiss): Restore original bindings, clear state.

This design avoids permanent widget wrapping, so other plugins' `self-insert` wrappers see buffer changes normally. The idempotency guard at the top prevents double-loading if the plugin is sourced multiple times.

## Release Process

Follows semver (`vMAJOR.MINOR.PATCH`). Version tracked in `VERSION` file, `CHANGELOG.md`, and git tags (source of truth).

Bump with `claude /versioning bump MAJOR|MINOR|PATCH`, or update `VERSION` and `CHANGELOG.md` manually. Tag with annotated tags: `git tag -a v0.2.0 -m "Release v0.2.0"`.

Run all test scripts before releasing.
