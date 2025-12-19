# providers/ollama.zsh - Ollama local inference provider
# No API key required, runs locally. No native JSON mode - uses prompt engineering.

typeset -g ZSH_AI_CMD_OLLAMA_MODEL=${ZSH_AI_CMD_OLLAMA_MODEL:-'mistral-small'}
typeset -g ZSH_AI_CMD_OLLAMA_HOST=${ZSH_AI_CMD_OLLAMA_HOST:-'localhost:11434'}

_zsh_ai_cmd_ollama_call() {
  local input=$1
  local prompt=$2

  # Append strict JSON format instruction (no native JSON mode in Ollama)
  local json_prompt="$prompt

CRITICAL: Respond with ONLY valid JSON. No text before or after.
Format: {\"command\": \"your shell command here\"}
Example: {\"command\": \"ls -la\"}"

  local payload
  payload=$(command jq -nc \
    --arg model "$ZSH_AI_CMD_OLLAMA_MODEL" \
    --arg system "$json_prompt" \
    --arg content "$input" \
    '{
      model: $model,
      messages: [
        {role: "system", content: $system},
        {role: "user", content: $content}
      ],
      stream: false
    }')

  local response
  response=$(command curl -sS --max-time 60 "http://${ZSH_AI_CMD_OLLAMA_HOST}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null)

  # Debug log
  if [[ $ZSH_AI_CMD_DEBUG == true ]]; then
    {
      print -- "=== $(date '+%Y-%m-%d %H:%M:%S') [ollama] ==="
      print -- "--- REQUEST ---"
      command jq . <<< "$payload"
      print -- "--- RESPONSE ---"
      command jq . <<< "$response"
      print ""
    } >>$ZSH_AI_CMD_LOG
  fi

  # Extract command - Ollama puts response in .message.content
  local content
  content=$(print -r -- "$response" | command jq -re '.message.content // empty' 2>/dev/null)
  [[ -z $content ]] && return 1

  # Parse JSON from content (may have extra text, try to extract JSON)
  print -r -- "$content" | command jq -re '.command // empty' 2>/dev/null && return 0

  # Fallback: try to find JSON in response (some models add explanation text)
  local json_match
  json_match=$(print -r -- "$content" | command grep -oE '\{[^}]+\}' | head -1)
  [[ -n $json_match ]] && print -r -- "$json_match" | command jq -re '.command // empty' 2>/dev/null
}

_zsh_ai_cmd_ollama_key_error() {
  # Ollama doesn't need a key, but the server must be running
  print -u2 ""
  print -u2 "zsh-ai-cmd: Cannot connect to Ollama at ${ZSH_AI_CMD_OLLAMA_HOST}"
  print -u2 ""
  print -u2 "Make sure Ollama is installed and running:"
  print -u2 "  brew install ollama"
  print -u2 "  ollama serve"
  print -u2 ""
  print -u2 "Or set a custom host:"
  print -u2 "  export ZSH_AI_CMD_OLLAMA_HOST='192.168.1.100:11434'"
}

# Check if Ollama is available (used for validation)
_zsh_ai_cmd_ollama_available() {
  command curl -sS --max-time 2 "http://${ZSH_AI_CMD_OLLAMA_HOST}/api/tags" >/dev/null 2>&1
}
