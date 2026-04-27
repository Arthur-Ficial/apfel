

#!/usr/bin/env python3
"""
Local embedding + retrieval service for the apfel semantic CLI layer.

- Uses sentence-transformers (all-MiniLM-L6-v2)
- Stores vectors + recency + frequency
- Provides update/query modes
- No network calls
"""

import json
import sys
import time
from pathlib import Path

import numpy as np
from sentence_transformers import SentenceTransformer

INDEX_PATH = Path.home() / ".zsh/apfel/index.json"

# Lazy-loaded model (fast after first load)
_model = None

def model():
    global _model
    if _model is None:
        _model = SentenceTransformer("all-MiniLM-L6-v2")
    return _model

# -----------------------------
# Storage helpers
# -----------------------------

def load():
    if INDEX_PATH.exists():
        try:
            return json.loads(INDEX_PATH.read_text())
        except Exception:
            return {}
    return {}


def save(data):
    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.write_text(json.dumps(data))


# -----------------------------
# Embedding + similarity
# -----------------------------

def embed(text):
    return model().encode(text).tolist()


def cosine(a, b):
    a = np.array(a)
    b = np.array(b)
    denom = (np.linalg.norm(a) * np.linalg.norm(b)) + 1e-9
    return float(np.dot(a, b) / denom)


# -----------------------------
# Core operations
# -----------------------------

def update(command: str):
    data = load()

    prev = data.get(command, {})

    data[command] = {
        "vec": embed(command),
        "ts": time.time(),
        "count": prev.get("count", 0) + 1,
    }

    # prevent unbounded growth
    if len(data) > 2000:
        items = sorted(
            data.items(),
            key=lambda kv: kv[1].get("ts", 0),
            reverse=True,
        )
        data = dict(items[:2000])

    save(data)


def query(text: str):
    data = load()
    if not data:
        return

    q_vec = embed(text)
    now = time.time()

    scored = []

    for cmd, meta in data.items():
        sim = cosine(q_vec, meta["vec"])

        age = now - meta["ts"]
        recency = max(0.0, 1.0 - age / 86400.0)  # ~1 day window

        freq = meta["count"]

        score = (sim * 5.0) + (recency * 2.0) + (freq * 0.5)

        scored.append((score, cmd))

    scored.sort(reverse=True)

    for _, cmd in scored[:5]:
        print(cmd)


# -----------------------------
# CLI entrypoint
# -----------------------------

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(0)

    mode = sys.argv[1]
    text = " ".join(sys.argv[2:])

    if mode == "update":
        update(text)
    elif mode == "query":
        query(text)