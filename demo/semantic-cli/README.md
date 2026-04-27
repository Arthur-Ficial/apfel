# Semantic CLI Layer (Experimental)

Adds a semantic, learning-based suggestion layer on top of the apfel demo commands.

Maps natural language input to deterministic `apfel-*` commands that improve with use.

---

## 🚀 Installation

From the repo root:

```bash
cd demo/semantic-cli
chmod +x setup.sh
./setup.sh
exec zsh
```

This will:

- Install required Python dependencies (locally)
- Create `apfel-*` command symlinks
- Enable semantic suggestions in your shell

---

## 🧪 Quick test

Try:

```bash
apfel explain tcp handshake
```

Then type:

```bash
apfel expla
```

You should see a suggestion like:

```
apfel-explain tcp handshake
```

---

## 🧠 What it does

### Semantic suggestions

- Learns from your usage
- Suggests commands based on intent (not just prefix)

### Adaptive ranking

- Recency (recent commands rank higher)
- Frequency (frequent commands rank higher)
- Semantic similarity (meaning-based matching)

### Deterministic execution

All suggestions resolve to:

```bash
apfel-*
```

So accepting a suggestion always runs a real command.

---

## ⚙️ Architecture

```
User input
   ↓
Embedding (local model)
   ↓
Similarity ranking (recency + frequency)
   ↓
Intent routing
   ↓
apfel-* command
```

---

## 📦 Requirements

- zsh (default on macOS)
- Python 3
- No dependency on Oh My Zsh or other frameworks

---

## 🔁 Uninstall

To remove:

```bash
rm -rf ~/.zsh/apfel
rm -f ~/.zsh/functions/apfel_*.zsh
```

Then optionally remove the loader block from `~/.zshrc`.

---

## 🧭 Notes

- Optional layer
- Does not modify core apfel behavior

---

## 💡 Why this exists

This bridges the gap between:

- flexible natural language
- reliable CLI commands

Resulting in a:

> self-learning command interface