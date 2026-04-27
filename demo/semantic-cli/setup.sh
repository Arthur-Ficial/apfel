

#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Semantic CLI Layer Setup (optional, non-invasive)
#
#
# What this does:
# - Installs local embedding deps (user scope)
# - Writes a lightweight embedder (Python)
# - Adds zsh functions for intent routing + suggestions
# - Hooks into ZLE safely (no key overrides)
# - Installs apfel-* command symlinks for demo scripts
#
# What this does NOT do:
# - Does not modify core apfel installation
# - Does not require sudo
# - Does not block your shell
#
# Reversible:
# - Remove ~/.zsh/apfel and ~/.zsh/functions/apfel_*.zsh
# - Remove loader lines from ~/.zshrc if desired
# ─────────────────────────────────────────────────────────────

echo "→ Installing Python deps (user scope)"
python3 -m pip install --user --upgrade pip >/dev/null
python3 -m pip install --user sentence-transformers numpy >/dev/null

BASE="$HOME/.zsh/apfel"
FUNC_DIR="$HOME/.zsh/functions"
mkdir -p "$BASE" "$FUNC_DIR"

# ─────────────────────────────────────────────────────────────
# Install apfel demo commands as apfel-* symlinks (optional convenience)
# ─────────────────────────────────────────────────────────────

echo "→ Installing apfel-* demo command symlinks"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

for d in cmd explain gitsum mac-narrator naming oneliner port wtd; do
  ln -sf "$DEMO_DIR/$d" "$BIN_DIR/apfel-$d"
done

# Ensure ~/.local/bin is on PATH (non-modular assumption: append to ~/.zshrc)
if ! grep -q '\.local/bin' "$HOME/.zshrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

# ─────────────────────────────────────────────────────────────
# Embedder (local, fast, no network)
# - Stores vectors + recency + frequency
# - Cosine similarity for ranking
# ─────────────────────────────────────────────────────────────

echo "→ Writing embedder"
cat > "$BASE/embedder.py" << 'PY'
import json, time, sys
from pathlib import Path
from sentence_transformers import SentenceTransformer
import numpy as np

INDEX = Path.home() / ".zsh/apfel/index.json"
_model = None

def model():
    global _model
    if _model is None:
        _model = SentenceTransformer("all-MiniLM-L6-v2")
    return _model

def load():
    if INDEX.exists():
        return json.loads(INDEX.read_text())
    return {}

def save(data):
    INDEX.parent.mkdir(parents=True, exist_ok=True)
    INDEX.write_text(json.dumps(data))

def embed(text):
    return model().encode(text).tolist()

def cosine(a, b):
    a = np.array(a); b = np.array(b)
    return float(np.dot(a,b)/(np.linalg.norm(a)*np.linalg.norm(b)+1e-9))

def update(cmd):
    data = load()
    prev = data.get(cmd, {})
    data[cmd] = {
        "vec": embed(cmd),
        "ts": time.time(),
        "count": prev.get("count", 0) + 1
    }
    # cap size to avoid unbounded growth
    if len(data) > 2000:
        items = sorted(data.items(), key=lambda kv: kv[1].get("ts", 0), reverse=True)
        data = dict(items[:2000])
    save(data)

def query(q):
    data = load()
    if not data:
        return
    qv = embed(q)
    now = time.time()
    scored = []
    for cmd, meta in data.items():
        sim = cosine(qv, meta["vec"]) 
        age = now - meta["ts"]
        recency = max(0.0, 1.0 - age/86400.0)  # ~1 day window
        freq = meta["count"]
        score = sim*5.0 + recency*2.0 + freq*0.5
        scored.append((score, cmd))
    scored.sort(reverse=True)
    for _, cmd in scored[:5]:
        print(cmd)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(0)
    mode = sys.argv[1]
    text = " ".join(sys.argv[2:])
    if mode == "update": update(text)
    elif mode == "query": query(text)
PY

# ─────────────────────────────────────────────────────────────
# Intent routing (language → canonical apfel-* command)
# ─────────────────────────────────────────────────────────────

echo "→ Writing intent router"
cat > "$FUNC_DIR/apfel_intents.zsh" << 'ZSH'
typeset -gA APFEL_INTENT_TO_CMD=(
  explain apfel-explain
  summarize apfel-gitsum
  gitsum apfel-gitsum
  cmd apfel-cmd
  port apfel-port
  oneliner apfel-oneliner
  naming apfel-naming
  wtd apfel-wtd
  mac-narrator apfel-mac-narrator
)

_apfel_route_to_command() {
  local buf="\$1"
  local lower="\${buf:l}"

  local intent=""
  case "\$lower" in
    *explain*) intent=explain ;;
    *summarize*|*summary*) intent=summarize ;;
    *port*|*listen*) intent=port ;;
    *cmd*|*command*) intent=cmd ;;
    *one*liner*) intent=oneliner ;;
    *name*|*naming*) intent=naming ;;
    *what*does*this*|*wtd*) intent=wtd ;;
    *narrate*|*mac*) intent=mac-narrator ;;
  esac

  local cmd="\${APFEL_INTENT_TO_CMD[\$intent]}"
  [[ -z "\$cmd" ]] && return 1

  local args="\${buf#apfel}"
  args="\${args# }"
  args="\${args#\${intent}}"
  args="\${args# }"

  print -r -- "\$cmd \$args"
}
ZSH

# ─────────────────────────────────────────────────────────────
# Smart suggestion layer (safe ZLE hooks, no overrides)
# ─────────────────────────────────────────────────────────────

echo "→ Writing smart suggestion layer"
cat > "$FUNC_DIR/apfel_smart.zsh" << 'ZSH'
APFEL_GLOBAL_HISTORY="\$HOME/.apfel_history"
[[ -f "\$APFEL_GLOBAL_HISTORY" ]] || : > "\$APFEL_GLOBAL_HISTORY"

# Capture usage + async embedding update
apfel() {
  command apfel "\$@"
  [[ -z "\$*" ]] && return
  local entry="apfel \$*"
  print -r -- "\$entry" >> "\$APFEL_GLOBAL_HISTORY"
  (python3 "\$HOME/.zsh/apfel/embedder.py" update "\$entry" >/dev/null 2>&1 &)
}

# Guard against unstable parse states
_apfel_safe_context() {
  [[ "\$BUFFER" == *\"* && "\$BUFFER" != *\"\"* ]] && return 1
  [[ "\$BUFFER" == *"|"* || "\$BUFFER" == *">"* || "\$BUFFER" == *"<"* ]] && return 1
  return 0
}

# Tiny cache to avoid frequent Python calls
_apfel_q_cache=""
_apfel_q_cache_t=0

_apfel_query_cache() {
  local now=\$EPOCHSECONDS
  (( now - _apfel_q_cache_t < 2 )) && return
  _apfel_q_cache="\$(python3 "\$HOME/.zsh/apfel/embedder.py" query "\$BUFFER" 2>/dev/null)"
  _apfel_q_cache_t=\$now
}

_apfel_smart_suggest() {
  local buffer="\$BUFFER"

  # Trigger on both apfel and apfel-* prefixes
  [[ "\$buffer" == apfel* || "\$buffer" == apfel-* ]] || { POSTDISPLAY=""; return }
  _apfel_safe_context || { POSTDISPLAY=""; return }

  # 1) Embedding-based candidate (cached)
  _apfel_query_cache
  local best
  best=\$(print -rl -- \$_apfel_q_cache | head -n 1)

  # 2) If language form, route to canonical command
  if [[ "\$best" == apfel\ * ]]; then
    local routed
    routed=\$(_apfel_route_to_command "\$best")
    [[ -n "\$routed" ]] && best="\$routed"
  fi

  # 3) Show suggestion suffix
  if [[ -n "\$best" && "\$best" != "\$buffer" ]]; then
    POSTDISPLAY="\${best#\$buffer}"
  else
    POSTDISPLAY=""
  fi
}

autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-pre-redraw _apfel_smart_suggest
add-zle-hook-widget line-init _apfel_smart_suggest

# Learn from direct apfel-* command usage too
preexec() {
  if [[ "\$1" == apfel-* ]]; then
    python3 "\$HOME/.zsh/apfel/embedder.py" update "\$1" >/dev/null 2>&1 &
  fi
}

# Optional nicety
setopt NO_BEEP
ZSH

# ─────────────────────────────────────────────────────────────
# Ensure loader in ~/.zshrc (idempotent)
# ─────────────────────────────────────────────────────────────

echo "→ Ensuring loader in ~/.zshrc"
if ! grep -q "~/.zsh/functions/.*\\.zsh" "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" << 'EOF'

# Load custom zsh functions (including apfel semantic layer)
for file in ~/.zsh/functions/*.zsh(N); do
  source "$file"
done
EOF
fi

# Ensure Python user bin is on PATH (append directly to ~/.zshrc)
if ! grep -q "Library/Python/3" "$HOME/.zshrc" 2>/dev/null; then
  echo 'export PATH="$HOME/Library/Python/3.9/bin:$PATH"' >> "$HOME/.zshrc"
fi

echo "→ Done. Restart shell: exec zsh"