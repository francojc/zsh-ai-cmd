# zsh-ai-cmd

Natural language to shell commands. Type what you want, press `Ctrl+Z`, get the command.

## Install

Requires `curl`, `jq`, and an [Anthropic API key](https://console.anthropic.com/).

```sh
# Clone
git clone https://github.com/yourusername/zsh-ai-cmd ~/.zsh-ai-cmd

# Add to .zshrc
source ~/.zsh-ai-cmd/zsh-ai-cmd.plugin.zsh

# Set API key (pick one)
export ANTHROPIC_API_KEY='sk-ant-...'
# or macOS Keychain
security add-generic-password -s 'anthropic-api-key' -a "$USER" -w 'sk-ant-...'
```

## Usage

Type a description, press `Ctrl+Z`:

```
find large files modified this week  ->  command find . -type f -mtime -7 -size +10M -exec ls -lh {} \;
```

The command replaces your input. Press Enter to run, or edit first.

## Configuration

```sh
ZSH_AI_CMD_KEY='^z'                          # Trigger key (default: Ctrl+Z)
ZSH_AI_CMD_MODEL='claude-haiku-4-5-20251001' # Model
ZSH_AI_CMD_DEBUG=false                       # Log to /tmp/zsh-ai-cmd.log
```
