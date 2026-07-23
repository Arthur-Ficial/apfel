#!/usr/bin/env python3
"""Remote MCP server fixture that floods the client with an unbounded response.

apfel caps a single remote-MCP response at 10 MB (maxRemoteMCPResponseBytes in
Sources/MCPClient.swift) to stop a malicious or compromised remote server from
exhausting client memory. This fixture answers the `initialize` handshake with a
response that streams forever (no Content-Length, connection never closed), so:

  * With the streaming cap, apfel aborts the read at 10 MB and exits non-zero at
    startup within a couple of seconds.
  * Without it (buffering the whole body before checking size), apfel never
    returns - the per-request idle timeout never fires while bytes keep
    arriving - so the client hangs until its caller times out. That is the
    regression this fixture is designed to catch.

The stream is throttled (~50 MB/s) and capped at a hard ceiling so a regressed
client cannot make this fixture allocate without bound; the ceiling is far above
the 10 MB cap, so a correct client still aborts long before it is reached.

Usage: python3 oversize_remote_mcp_server.py --port 8765
"""

import argparse
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

CHUNK = b"A" * (1024 * 1024)          # 1 MB
THROTTLE_SECONDS = 0.05               # ~20 MB/s - bounds a regressed client's blast radius
# Hard stop so the fixture never allocates truly without bound. Set high enough
# that at the throttled rate it cannot be reached inside a caller's timeout
# window (~20 MB/s x ~12 s << 1 GB), so a buffering (regressed) client is still
# mid-stream - and thus hangs - when its caller gives up, rather than seeing the
# stream complete and rejecting on a post-hoc size check (a false pass).
CEILING_BYTES = 1024 * 1024 * 1024


def make_handler(path):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.0"  # no Content-Length -> body delimited by close

        def log_message(self, fmt, *args):
            print(f"  oversize-mcp: {fmt % args}", file=sys.stderr)

        def do_POST(self):
            if self.path != path:
                self.send_response(404)
                self.end_headers()
                return
            length = int(self.headers.get("Content-Length", 0))
            if length:
                self.rfile.read(length)

            # Start a never-completing JSON response and keep streaming filler.
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            written = 0
            try:
                self.wfile.write(b'{"jsonrpc":"2.0","id":0,"result":"')
                while written < CEILING_BYTES:
                    self.wfile.write(CHUNK)
                    written += len(CHUNK)
                    time.sleep(THROTTLE_SECONDS)
                print("  reached ceiling without client abort", file=sys.stderr)
            except (BrokenPipeError, ConnectionResetError):
                # Expected: a correct client aborts the read at the 10 MB cap.
                print(f"  client aborted after ~{written // (1024 * 1024)} MB (cap fired)",
                      file=sys.stderr)

        def do_DELETE(self):
            self.send_response(200)
            self.end_headers()

    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    print(f"oversize-mcp listening on http://127.0.0.1:{args.port}/mcp", file=sys.stderr)
    HTTPServer(("127.0.0.1", args.port), make_handler("/mcp")).serve_forever()


if __name__ == "__main__":
    main()
