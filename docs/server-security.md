# Server Security

apfel's HTTP server (`--serve`) runs on localhost by default and is designed for local development and on-device inference. This document explains the security settings and how to configure them for your specific use case.

## How it works

The `Origin` HTTP header is the key. Browsers automatically attach it to cross-origin requests. Non-browser tools (curl, Python SDK, shell scripts) don't.

```
Browser on evil.com -> fetch("http://localhost:11434/v1/chat/completions")
                       ^^ Browser adds: Origin: http://evil.com
                       ^^ apfel sees foreign origin -> 403 Forbidden

curl http://localhost:11434/v1/chat/completions
     ^^ No Origin header sent
     ^^ apfel sees no Origin -> allowed (backward compatible)
```

This single check protects against browser-based attacks while keeping all non-browser workflows unchanged.

---

## Default behavior

```bash
apfel --serve
```

```
apfel server v0.6.23
├ endpoint: http://127.0.0.1:11434
├ cors:     disabled
├ origin:   localhost only (http://127.0.0.1, http://localhost, http://[::1])
├ token:    none
└ ready
```

**What works:**

```bash
# curl - no Origin header, always works
curl http://localhost:11434/v1/models
# => 200 OK

# Python SDK - no Origin header, always works
python3 -c "
from openai import OpenAI
c = OpenAI(base_url='http://localhost:11434/v1', api_key='ignored')
print(c.models.list().data[0].id)
"
# => apple-foundationmodel

# Browser JavaScript from localhost - allowed
# fetch("http://localhost:11434/v1/models") from http://localhost:3000
# => 200 OK, Access-Control-Allow-Origin: http://localhost:3000
```

**What's blocked:**

```bash
# Browser JavaScript from a foreign site
curl -H "Origin: http://evil.com" http://localhost:11434/v1/models
# => 403 Forbidden
# => {"error":{"message":"Origin 'http://evil.com' is not allowed.","type":"forbidden"}}

# Subdomain attacks (http://localhost.evil.com != http://localhost)
curl -H "Origin: http://localhost.evil.com" http://localhost:11434/v1/models
# => 403 Forbidden
```

**What this means:** Out of the box, your server is protected from cross-site attacks. curl, SDKs, and scripts work unchanged. Local browser apps can send requests and read simple GET responses. For full browser support (POST, custom headers), add `--cors`.

---

## Security flags reference

### `--cors` - Enable CORS for browser clients

Enables full CORS support: the server responds to OPTIONS preflight requests with the necessary `Access-Control-Allow-*` headers so browsers can make POST requests and send custom headers (like `Authorization`).

```bash
apfel --serve --cors
```

```
├ cors:     enabled
├ origin:   localhost only (http://127.0.0.1, http://localhost, http://[::1])
```

**What changes:**

```bash
# OPTIONS preflight now returns full CORS headers
curl -X OPTIONS -D - http://localhost:11434/v1/chat/completions -o /dev/null
# => 204 No Content
# => Access-Control-Allow-Origin: http://localhost:3000  (if Origin sent)
# => Access-Control-Allow-Methods: GET, POST, OPTIONS
# => Access-Control-Allow-Headers: Content-Type, Authorization
# => Access-Control-Max-Age: 86400

# Browser POST requests now work from localhost
# fetch("http://localhost:11434/v1/chat/completions", {
#   method: "POST",
#   headers: {"Content-Type": "application/json"},
#   body: JSON.stringify({model: "apple-foundationmodel", messages: [...]})
# })
# => Works from http://localhost:* origins
```

**What stays the same:**

```bash
# Foreign origins still blocked
curl -H "Origin: http://evil.com" http://localhost:11434/v1/models
# => 403 Forbidden (--cors does NOT disable origin checking)
```

**Key insight:** `--cors` enables browser communication, but does NOT weaken the origin check. Foreign sites are still blocked.

**When to use:** Your local web app needs to make `fetch()` calls to apfel. Without `--cors`, browsers block POST requests and requests with custom headers like `Authorization`.

---

### `--allowed-origins <origins>` - Add custom allowed origins

Add specific origins to the default localhost allowlist. This is **additive** - localhost origins are always included.

```bash
apfel --serve --cors --allowed-origins "http://myapp.local:8080"
```

```
├ cors:     enabled
├ origin:   localhost only (http://127.0.0.1, http://localhost, http://[::1], http://myapp.local:8080)
```

**What changes:**

```bash
# Custom origin now allowed
curl -H "Origin: http://myapp.local:8080" http://localhost:11434/v1/models
# => 200 OK
# => Access-Control-Allow-Origin: http://myapp.local:8080
# => Vary: Origin

# Default localhost origins still work
curl -H "Origin: http://localhost:3000" http://localhost:11434/v1/models
# => 200 OK

# Other origins still blocked
curl -H "Origin: http://evil.com" http://localhost:11434/v1/models
# => 403 Forbidden

# No Origin header still works (curl, SDKs)
curl http://localhost:11434/v1/models
# => 200 OK
```

**Multiple origins:**

```bash
apfel --serve --cors --allowed-origins "http://localhost:3000,http://localhost:5173"
```

**How matching works:**

| Origin in request | Pattern in list | Match? | Why |
|---|---|---|---|
| `http://localhost` | `http://localhost` | Yes | Exact match |
| `http://localhost:3000` | `http://localhost` | Yes | Port variant (default list matches all localhost ports) |
| `http://localhost:5173` | `http://localhost` | Yes | Port variant |
| `https://localhost` | `http://localhost` | Yes | HTTPS variant |
| `http://localhost.evil.com` | `http://localhost` | **No** | Subdomain attack - not a port suffix |
| `http://127.0.0.2` | `http://127.0.0.1` | **No** | Different IP |
| `http://myapp.local:8080` | `http://myapp.local:8080` | Yes | Exact match |
| `http://myapp.local:9090` | `http://myapp.local:8080` | Yes | Port variant |

---

### `--no-origin-check` - Disable origin checking

Disables the `Origin` header check entirely. Any origin is allowed.

```bash
apfel --serve --no-origin-check
```

```
├ cors:     disabled
├ origin:   disabled (all origins allowed)
```

**What changes:**

```bash
# Foreign origins now allowed
curl -H "Origin: http://evil.com" http://localhost:11434/v1/models
# => 200 OK
# => Access-Control-Allow-Origin: *

# All requests get wildcard CORS header
curl -H "Origin: http://anything.com" http://localhost:11434/v1/models
# => 200 OK
# => Access-Control-Allow-Origin: *
```

**Important:** When origin checking is disabled, the server automatically adds `Access-Control-Allow-Origin: *` to all responses so browsers can actually use the endpoint. However, without `--cors`, OPTIONS preflight requests don't include `Allow-Methods`/`Allow-Headers`, so browser POST requests may still fail.

**For full browser access from any origin, use `--footgun` instead** (which combines `--no-origin-check` with `--cors`).

**When to use:** Trusted networks where you know who's connecting, but you don't need full browser CORS support.

---

### `--token <secret>` - Require Bearer token authentication

Adds a second layer of security: every request must include a Bearer token. Works independently of origin checking.

```bash
apfel --serve --token "my-secret-token"
```

```
├ origin:   localhost only (http://127.0.0.1, http://localhost, http://[::1])
├ token:    required
```

**What changes:**

```bash
# Without token - 401 Unauthorized
curl http://localhost:11434/v1/models
# => 401 Unauthorized
# => WWW-Authenticate: Bearer
# => {"error":{"message":"Invalid or missing Bearer token.","type":"authentication_error"}}

# Wrong token - 401 Unauthorized
curl -H "Authorization: Bearer wrong-token" http://localhost:11434/v1/models
# => 401 Unauthorized

# Correct token - 200 OK
curl -H "Authorization: Bearer my-secret-token" http://localhost:11434/v1/models
# => 200 OK

# On loopback binds, /health remains public for monitoring convenience
curl http://localhost:11434/health
# => 200 OK (no token needed)

# Python SDK - pass token as api_key
python3 -c "
from openai import OpenAI
c = OpenAI(base_url='http://localhost:11434/v1', api_key='my-secret-token')
print(c.models.list().data[0].id)
"
# => apple-foundationmodel
```

**Security note:** When using `--token` (not `--token-auto`), the secret is NOT printed in the startup banner. Only `token: required` is shown.

**Health note:** When you bind to a non-loopback address such as `0.0.0.0` and enable `--token`, `/health` now requires the same Bearer token by default. Use `--public-health` only if you intentionally want unauthenticated monitoring on that network-exposed bind.

**Debug note:** Request log endpoints (`/v1/logs`, `/v1/logs/stats`) are only exposed when the server starts with `--debug`. When they are enabled, they still follow the same origin and token checks as the rest of the API.

**When to use:** Shared machines, multi-user environments, or any setup where you want to control who can use the model.

---

### `--token-auto` - Generate a random token

Like `--token` but auto-generates a UUID and prints it on startup so you can copy it.

```bash
apfel --serve --token-auto
```

```
├ token:    required
├ token: E259FD6E-1220-49CA-95CE-66D14BB7FD4B
└ ready
```

The generated token is printed in the banner. Share it with authorized users or scripts:

```bash
# Use the printed token
curl -H "Authorization: Bearer E259FD6E-1220-49CA-95CE-66D14BB7FD4B" http://localhost:11434/v1/models
# => 200 OK
```

---

### `APFEL_TOKEN` environment variable

Set the token via environment variable. Useful for scripts and systemd services.

```bash
export APFEL_TOKEN="my-secret-token"
apfel --serve
# Banner shows: token: required (secret not echoed)
```

The `--token` flag overrides `APFEL_TOKEN`. The `--token-auto` flag overrides both (generates a new random one).

---

### `--footgun` - Disable all protections

The shooting-yourself-in-the-foot-at-some-point-in-the-future option. Combines `--no-origin-check` and `--cors` to disable all security.

```bash
apfel --serve --footgun
```

```
├ cors:     enabled
├ origin:   disabled (all origins allowed)
├ WARNING: --footgun mode - no origin check + CORS enabled
├ Any website can access this server and read responses!
└ ready
```

**What this means:**

```bash
# Any website can make requests
curl -H "Origin: http://evil.com" http://localhost:11434/v1/models
# => 200 OK
# => Access-Control-Allow-Origin: *

# Full CORS preflight works for any origin
curl -X OPTIONS -H "Origin: http://evil.com" http://localhost:11434/v1/chat/completions -D - -o /dev/null
# => 204 No Content
# => Access-Control-Allow-Origin: *
# => Access-Control-Allow-Methods: GET, POST, OPTIONS
# => Access-Control-Allow-Headers: Content-Type, Authorization
```

**Equivalent to:** `--no-origin-check --cors`

**When to use:** Quick demos, testing, or environments where you explicitly want zero restrictions and understand the risk.

---

## Check order

The middleware checks in this order. The first failing check stops the request:

```
Request arrives
    |
    v
1. Is it OPTIONS? --> Yes --> Return preflight (with CORS headers if --cors)
    |
    No
    v
2. Origin check enabled? --> Yes --> Is Origin allowed?
    |                                    |
    |                               No --> 403 Forbidden
    |
    v
3. Token required? --> Yes --> Is /health on loopback/public-health? --> Yes --> Skip token check
    |                              |
    |                         No --> Valid token?
    |                                    |
    |                               No --> 401 Unauthorized
    |
    v
4. Debug endpoint gating (`/v1/logs*` requires `--debug`)
    |
    |                         No --> 404 Not Found
    |
    v
5. Route handler (your actual request)
    |
    v
6. Add CORS headers to response (if applicable)
    |
    v
Response sent
```

This means:
- **Origin check runs before token check.** A foreign origin gets 403 even with a valid token.
- **`/health` stays public on loopback by default.** On token-protected non-loopback binds, it requires auth unless `--public-health` is set.
- **`/v1/logs` and `/v1/logs/stats` are debug-only.** They return 404 unless `--debug` is enabled.
- **OPTIONS preflight skips both checks.** Browsers need preflight to succeed before sending the real request.

---

## Common scenarios

### I'm building a local web app

Your React/Vite/Next.js dev server on `localhost:3000` needs to call apfel:

```bash
apfel --serve --cors --allowed-origins "http://localhost:3000"
```

Your JavaScript:

```javascript
const response = await fetch("http://localhost:11434/v1/chat/completions", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "apple-foundationmodel",
    messages: [{ role: "user", content: "Hello!" }]
  })
});
const data = await response.json();
```

### I'm using curl or the Python SDK

Just run the server. Nothing extra needed:

```bash
apfel --serve

# curl works as-is
curl -X POST http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"apple-foundationmodel","messages":[{"role":"user","content":"Hi"}]}'

# Python SDK works as-is
from openai import OpenAI
client = OpenAI(base_url="http://localhost:11434/v1", api_key="ignored")
```

### I want to share the server on my local network

Bind to all interfaces and add token auth:

```bash
apfel --serve --host 0.0.0.0 --token-auto
# Share the printed token with people on your network
```

Other machines connect with:

```bash
curl -H "Authorization: Bearer <token>" http://192.168.1.42:11434/v1/models
curl -H "Authorization: Bearer <token>" http://192.168.1.42:11434/health
```

If you really need unauthenticated health probes on that network-exposed bind:

```bash
apfel --serve --host 0.0.0.0 --token-auto --public-health
```

### I need multiple dev servers to access apfel

```bash
apfel --serve --cors --allowed-origins "http://localhost:3000,http://localhost:5173,http://localhost:8080"
```

### I want maximum security (locked down)

```bash
apfel --serve --cors --allowed-origins "http://localhost:3000" --token "$(openssl rand -hex 16)"
```

This gives you: origin restricted to one specific app + token auth required + CORS for that app only.

### Quick demo / hackathon

```bash
apfel --serve --footgun
# WARNING banner printed - you know what you're doing
```

---

## Flag interaction matrix

Every combination explained:

| Flags | Origin check | CORS headers | Preflight | Who can connect | Who can read responses |
|-------|-------------|-------------|-----------|-----------------|----------------------|
| *(default)* | localhost only | on allowed requests | 204, no CORS | curl, SDKs, localhost browsers | curl, SDKs, localhost (simple GET only) |
| `--cors` | localhost only | on allowed requests | 204 + full CORS | curl, SDKs, localhost browsers | curl, SDKs, localhost browsers (POST too) |
| `--no-origin-check` | disabled | `*` on all | 204, no full CORS | everyone | everyone (simple GET only) |
| `--footgun` | disabled | `*` on all | 204 + full CORS | everyone | everyone (POST too) |
| `--token X` | localhost only | on allowed requests | 204, no CORS | token holders only (loopback `/health` stays public) | token holders with localhost origin |
| `--cors --token X` | localhost only | on allowed requests | 204 + full CORS | token holders from localhost | token holders from localhost browsers |
| `--cors --allowed-origins X` | custom list | on allowed requests | 204 + full CORS | curl, SDKs, listed origins | curl, SDKs, listed origin browsers |
| `--footgun --token X` | disabled | `*` on all | 204 + full CORS | token holders from anywhere | token holders from any browser |

**Reading the table:**
- "Who can connect" = whose requests get a 200 response
- "Who can read responses" = whose browser JavaScript can read the response body (requires CORS headers)
- "simple GET only" = browsers can read GET responses but POST requires full CORS preflight (`--cors`)
