# load-config.sh — resolve .recall.yaml path by priority.
# Priority: $RECALL_CONFIG → ./.recall.yaml → ~/.recall.yaml → (empty: caller uses defaults)

load_config_path() {
  if [[ -n "${RECALL_CONFIG:-}" && -f "$RECALL_CONFIG" ]]; then
    echo "$RECALL_CONFIG"
    return 0
  fi
  if [[ -f "./.recall.yaml" ]]; then
    echo "$(pwd)/.recall.yaml"
    return 0
  fi
  if [[ -f "$HOME/.recall.yaml" ]]; then
    echo "$HOME/.recall.yaml"
    return 0
  fi
  echo ""
}
