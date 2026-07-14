#!/usr/bin/env sh
set -eu

RAW_BASE="https://raw.githubusercontent.com/TaqiyudinMiftah/agent-skills/main"
TARGET="."
TARGET_SET=0
FORCE=0

usage() {
  cat <<'EOF'
Usage: install.sh [target-directory] [--force]

Installs the Sol–Terra Codex workflow into a project.

Options:
  --force   Back up and replace an existing .codex/config.toml.
  -h, --help
            Show this help text.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ "$TARGET_SET" -eq 1 ]; then
        echo "Error: only one target directory may be supplied." >&2
        usage >&2
        exit 2
      fi
      TARGET=$1
      TARGET_SET=1
      ;;
  esac
  shift
done

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required." >&2
  exit 1
fi

mkdir -p "$TARGET"
TARGET=$(cd "$TARGET" && pwd)
mkdir -p "$TARGET/.codex/agents"

TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t sol-terra)
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

fetch() {
  f_remote_path=$1
  f_output_path=$2
  curl -fsSL "$RAW_BASE/$f_remote_path" -o "$f_output_path"
}

backup_file() {
  b_source_path=$1
  b_backup_path="$b_source_path.bak.$TIMESTAMP"
  b_counter=1
  while [ -e "$b_backup_path" ]; do
    b_backup_path="$b_source_path.bak.$TIMESTAMP.$b_counter"
    b_counter=$((b_counter + 1))
  done
  cp -p "$b_source_path" "$b_backup_path"
  printf '  backup: %s\n' "$b_backup_path"
}

install_or_update() {
  i_source_path=$1
  i_destination_path=$2
  i_label=$3

  if [ ! -e "$i_destination_path" ]; then
    cp "$i_source_path" "$i_destination_path"
    printf '  installed: %s\n' "$i_label"
    return
  fi

  if cmp -s "$i_source_path" "$i_destination_path"; then
    printf '  unchanged: %s\n' "$i_label"
    return
  fi

  backup_file "$i_destination_path"
  cp "$i_source_path" "$i_destination_path"
  printf '  updated: %s\n' "$i_label"
}

echo "Installing Sol–Terra workflow into: $TARGET"

# Merge the managed workflow block without removing existing project instructions.
AGENTS_TEMPLATE="$TMP_DIR/AGENTS.md"
fetch "template/AGENTS.md" "$AGENTS_TEMPLATE"
AGENTS_DEST="$TARGET/AGENTS.md"

if [ ! -e "$AGENTS_DEST" ]; then
  cp "$AGENTS_TEMPLATE" "$AGENTS_DEST"
  echo "  installed: AGENTS.md"
elif grep -q '^<!-- sol-terra-workflow:start -->$' "$AGENTS_DEST" && \
     grep -q '^<!-- sol-terra-workflow:end -->$' "$AGENTS_DEST"; then
  MERGED_AGENTS="$TMP_DIR/AGENTS.merged.md"
  awk -v replacement="$AGENTS_TEMPLATE" '
    BEGIN { in_managed = 0 }
    $0 == "<!-- sol-terra-workflow:start -->" {
      in_managed = 1
      while ((getline line < replacement) > 0) print line
      close(replacement)
      next
    }
    $0 == "<!-- sol-terra-workflow:end -->" {
      in_managed = 0
      next
    }
    !in_managed { print }
  ' "$AGENTS_DEST" > "$MERGED_AGENTS"
  install_or_update "$MERGED_AGENTS" "$AGENTS_DEST" "AGENTS.md managed block"
else
  backup_file "$AGENTS_DEST"
  {
    cat "$AGENTS_DEST"
    printf '\n\n'
    cat "$AGENTS_TEMPLATE"
  } > "$TMP_DIR/AGENTS.appended.md"
  cp "$TMP_DIR/AGENTS.appended.md" "$AGENTS_DEST"
  echo "  appended: Sol–Terra block in AGENTS.md"
fi

# Install the project config only when safe, unless the user explicitly forces replacement.
CONFIG_TEMPLATE="$TMP_DIR/config.toml"
fetch "template/.codex/config.toml" "$CONFIG_TEMPLATE"
CONFIG_DEST="$TARGET/.codex/config.toml"

if [ ! -e "$CONFIG_DEST" ]; then
  cp "$CONFIG_TEMPLATE" "$CONFIG_DEST"
  echo "  installed: .codex/config.toml"
elif [ "$FORCE" -eq 1 ]; then
  install_or_update "$CONFIG_TEMPLATE" "$CONFIG_DEST" ".codex/config.toml"
else
  echo "  preserved: .codex/config.toml (use --force to back up and replace)"
fi

# The custom agent has a unique path, so updates are safe after a backup.
AGENT_TEMPLATE="$TMP_DIR/terra-executor.toml"
fetch "template/.codex/agents/terra-executor.toml" "$AGENT_TEMPLATE"
install_or_update "$AGENT_TEMPLATE" "$TARGET/.codex/agents/terra-executor.toml" ".codex/agents/terra-executor.toml"

# Launchers explicitly choose Sol even when an existing project config was preserved.
cat > "$TARGET/codex-sol-terra" <<'EOF'
#!/usr/bin/env sh
set -eu
exec codex -m gpt-5.6-sol "$@"
EOF
chmod +x "$TARGET/codex-sol-terra"
echo "  installed: codex-sol-terra"

cat > "$TARGET/codex-sol-terra.ps1" <<'EOF'
& codex -m gpt-5.6-sol @args
exit $LASTEXITCODE
EOF
echo "  installed: codex-sol-terra.ps1"

cat <<EOF

Done.

Next steps:
  1. Review the installed files and any .bak.* backups.
  2. Start Codex from this project with: ./codex-sol-terra
  3. Trust the project when Codex asks, so project-scoped .codex files load.
  4. Use /agent inside Codex to inspect Terra's executor thread.
EOF
