#!/usr/bin/env bash
# tests/bats/helpers/common.bash — shared setup for bats tests.
# Provides helpers for sourcing lib files in isolation and for spinning
# up a mock HTTP server.

# Path to the repo root
BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(dirname "$BATS_TEST_FILENAME")}"
TESTS_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

# Load all libs into the current shell for in-process testing.
load_libs() {
    # shellcheck source=lib/ui.sh
    source "$ROOT_DIR/lib/ui.sh"
    # shellcheck source=lib/config.sh
    source "$ROOT_DIR/lib/config.sh"
    # shellcheck source=lib/tags.sh
    source "$ROOT_DIR/lib/tags.sh"
    # shellcheck source=lib/git.sh
    source "$ROOT_DIR/lib/git.sh"
    # shellcheck source=lib/llm.sh
    source "$ROOT_DIR/lib/llm.sh"
    # shellcheck source=lib/prompt.sh
    source "$ROOT_DIR/lib/prompt.sh"
}

# Source only the UI lib (always needed for ui_* helpers and COLOR vars).
load_ui() {
    # shellcheck source=lib/ui.sh
    source "$ROOT_DIR/lib/ui.sh"
}

# Source only the tags lib (also pulls in ui).
load_tags() {
    load_ui
    # shellcheck source=lib/tags.sh
    source "$ROOT_DIR/lib/tags.sh"
}

# Source only the prompt lib (also pulls in ui).
load_prompt() {
    load_ui
    # shellcheck source=lib/prompt.sh
    source "$ROOT_DIR/lib/prompt.sh"
}

# Source only the config lib.
load_config() {
    load_ui
    # shellcheck source=lib/config.sh
    source "$ROOT_DIR/lib/config.sh"
}

# Start a tiny Python HTTP server that records every request body and
# returns a canned OpenAI-style response. Prints the chosen port.
mock_openai_start() {
    # Use a separate variable for the default JSON; bash's ${1:-X} expansion
    # misparses inner braces in X and strips them.
    local _default='{"choices":[{"message":{"role":"assistant","content":"feat: mock"}}]}'
    local response_json="${1:-$_default}"
    local capture_file="${2:-$BATS_TEST_TMPDIR/capture.json}"
    : > "$capture_file"

    MOCK_PY=$(mktemp --suffix=.py)
    cat > "$MOCK_PY" <<PYEOF
import http.server, json, sys, socketserver
CAPTURE = "$capture_file"
RESP = json.loads('''$response_json''')
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(n).decode()
        with open(CAPTURE, 'w') as f:
            f.write(body)
        data = json.dumps(RESP).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def log_message(self, *a, **kw): pass
socketserver.TCPServer.allow_reuse_address = True
port = int(sys.argv[1])
with socketserver.TCPServer(('127.0.0.1', port), H) as httpd:
    httpd.serve_forever()
PYEOF

    # Find a free port
    local port
    port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')

    python3 "$MOCK_PY" "$port" >/dev/null 2>&1 &
    MOCK_PID=$!
    echo "$MOCK_PID" > "$BATS_TEST_TMPDIR/mock.pid"
    echo "$port" > "$BATS_TEST_TMPDIR/mock.port"
    echo "$capture_file" > "$BATS_TEST_TMPDIR/mock.capture"
    # wait for server (POST works; GET returns 501 but that means it's listening)
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if curl -s -X POST "http://127.0.0.1:$port/ping" -d '{}' -o /dev/null -w "" --max-time 1 2>/dev/null; then
            break
        fi
        if (echo > "/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    echo "$port"
}

mock_stop() {
    if [[ -f "$BATS_TEST_TMPDIR/mock.pid" ]]; then
        kill "$(cat "$BATS_TEST_TMPDIR/mock.pid")" 2>/dev/null || true
        rm -f "$BATS_TEST_TMPDIR/mock.pid"
    fi
    if [[ -n "${MOCK_PY:-}" && -f "$MOCK_PY" ]]; then
        rm -f "$MOCK_PY"
    fi
}

# Make a fresh git repo in BATS_TEST_TMPDIR/repo and cd into it.
make_test_repo() {
    local d="$BATS_TEST_TMPDIR/repo"
    rm -rf "$d"
    mkdir -p "$d"
    cd "$d"
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name  "Test"
    echo "init" > a.txt
    git add a.txt
    git commit -qm "init"
    echo "$d"
}
