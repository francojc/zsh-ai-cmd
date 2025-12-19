# providers/openai.zsh - OpenAI API provider
# Uses JSON mode for structured output (less strict than Anthropic's schema)

typeset -g ZSH_AI_CMD_OPENAI_MODEL=${ZSH_AI_CMD_OPENAI_MODEL:-'gpt-5-mini'}

_zsh_ai_cmd_openai_call() {
  local input=$1
  local prompt=$2

  # Append JSON format instruction to system prompt
  local json_prompt="$prompt

IMPORTANT: Respond with valid JSON only. Format: {\"command\": \"your shell command here\"}"

  local payload
  payload=$(command jq -nc \
    --arg model "$ZSH_AI_CMD_OPENAI_MODEL" \
    --arg system "$json_prompt" \
    --arg content "$input" \
    '{
      model: $model,
      max_tokens: 256,
      messages: [
        {role: "system", content: $system},
        {role: "user", content: $content}
      ],
      response_format: {type: "json_object"}
    }')

  local response
  response=$(command curl -sS --max-time 30 "https://api.openai.com/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$payload" 2>/dev/null)

  # Debug log
  if [[ $ZSH_AI_CMD_DEBUG == true ]]; then
    {
      print -- "=== $(date '+%Y-%m-%d %H:%M:%S') [openai] ==="
      print -- "--- REQUEST ---"
      command jq . <<< "$payload"
      print -- "--- RESPONSE ---"
      command jq . <<< "$response"
      print ""
    } >>$ZSH_AI_CMD_LOG
  fi

  # Extract command from response
  print -r -- "$response" | command jq -re '.choices[0].message.content | fromjson | .command // empty' 2>/dev/null
}

_zsh_ai_cmd_openai_key_error() {
  print -u2 ""
  print -u2 "zsh-ai-cmd: OPENAI_API_KEY not found"
  print -u2 ""
  print -u2 "Set it via environment variable:"
  print -u2 "  export OPENAI_API_KEY='sk-...'"
  print -u2 ""
  print -u2 "Or store in macOS Keychain:"
  print -u2 "  security add-generic-password -s 'openai-api-key' -a '\$USER' -w 'sk-...'"
}
