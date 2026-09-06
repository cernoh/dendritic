# _leet-login.py
# stdlib-only helper behind `:DendriticLeetLogin`.
# Reads LeetCode session cookies over the Chromium DevTools Protocol:
# the Lua side launches Brave/Chromium with `--remote-debugging-port`
# and polls `extract --port PORT` until the user has logged in, then
# `Network.getAllCookies` returns plaintext values (no keyring/AES).
# SQLite reads do NOT work: Brave encrypts its Cookies store (empty
# `value` column, bytes in `encrypted_value`), verified against the
# live profile. No third-party packages: HTTP + WebSocket are spoken
# with socket/http.client from the standard library.
# Packaged by modules/features/nvf/default.nix via
# pkgs.writers.writePython3Bin as `dendritic-leet-login`.
"""Extract LeetCode cookies via Chromium DevTools Protocol."""

import argparse
import base64
import http.client
import json
import os
import socket
import struct
import sys

WANT = ("LEETCODE_SESSION", "csrftoken")


def targets(host, port):
    """Return the /json/list targets of the debugging endpoint."""
    con = http.client.HTTPConnection(host, port, timeout=10)
    try:
        con.request("GET", "/json/list")
        resp = con.getresponse()
        if resp.status != 200:
            return None
        try:
            return json.loads(resp.read().decode("utf-8"))
        except ValueError:
            return None
    except OSError:
        return None
    finally:
        con.close()


def ws_connect(host, port, path):
    """Perform a client WebSocket handshake, return the socket."""
    sock = socket.create_connection((host, port), timeout=10)
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    sock.sendall(
        (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        ).encode("ascii")
    )
    resp = b""
    while b"\r\n\r\n" not in resp:
        chunk = sock.recv(4096)
        if not chunk:
            raise OSError("handshake closed")
        resp += chunk
    if b"101" not in resp.split(b"\r\n", 1)[0]:
        raise OSError("handshake refused")
    return sock


def ws_send(sock, obj):
    """Send one masked text frame."""
    data = json.dumps(obj).encode("utf-8")
    mask = os.urandom(4)
    if len(data) < 126:
        sock.sendall(bytes([0x81, 0x80 | len(data)]) + mask)
    else:
        sock.sendall(
            struct.pack("!BBH", 0x81, 0x80 | 126, len(data))
            + mask
        )
    sock.sendall(
        bytes(b ^ mask[i % 4] for i, b in enumerate(data))
    )


def recv_exact(sock, n):
    """Read exactly n bytes or raise."""
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise OSError("websocket closed")
        buf += chunk
    return buf


def ws_recv(sock):
    """Read one message, answering pings, following continuations."""
    parts = []
    while True:
        head = recv_exact(sock, 2)
        fin = head[0] & 0x80
        op = head[0] & 0x0F
        length = head[1] & 0x7F
        if length == 126:
            length = struct.unpack("!H", recv_exact(sock, 2))[0]
        elif length == 127:
            length = struct.unpack("!Q", recv_exact(sock, 8))[0]
        if head[1] & 0x80:
            recv_exact(sock, 4)  # server frames are unmasked
        payload = recv_exact(sock, length) if length else b""
        if op == 0x9:  # ping -> pong
            sock.sendall(bytes([0x8A, 0x00]))
            continue
        if op == 0x8:
            raise OSError("closed by peer")
        parts.append(payload)
        if fin:
            return b"".join(parts).decode("utf-8")


def cdp(host, port, ws_path, method, params=None, ident=1):
    """Send one CDP command, skip events until its response arrives."""
    sock = ws_connect(host, port, ws_path)
    try:
        ws_send(sock, {"id": ident, "method": method,
                       "params": params or {}})
        while True:
            try:
                msg = json.loads(ws_recv(sock))
            except ValueError:
                continue
            if msg.get("id") == ident:
                if "error" in msg:
                    raise OSError(str(msg["error"]))
                return msg.get("result", {})
    finally:
        sock.close()


def ws_path_for(page_url, port):
    """Turn a debugger URL into the request path for this port."""
    return page_url.split(f":{port}", 1)[-1]


def extract(host, port):
    """Return 'LEETCODE_SESSION=..; csrftoken=..' or None."""
    try:
        items = targets(host, port)
    except OSError:
        return None
    if not items:
        return None
    page = next((t for t in items if t.get("type") == "page"
                 and t.get("webSocketDebuggerUrl")), None)
    if page is None:
        return None
    path = ws_path_for(page["webSocketDebuggerUrl"], port)
    try:
        cdp(host, port, path, "Network.enable")
        res = cdp(host, port, path, "Network.getAllCookies",
                  ident=2)
    except OSError:
        return None
    got = {c["name"]: c["value"] for c in res.get("cookies", [])
           if c.get("domain", "").endswith("leetcode.com")}
    if all(k in got and got[k] for k in WANT):
        session = got["LEETCODE_SESSION"]
        csrf = got["csrftoken"]
        return f"LEETCODE_SESSION={session}; csrftoken={csrf}"
    return None


def main(argv=None):
    """CLI entry point; 0 with the cookie on stdout, 1 when absent."""
    parser = argparse.ArgumentParser(
        description="Extract LeetCode cookies over CDP.")
    parser.add_argument("command", choices=("extract",))
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args(argv)
    if args.command == "extract":
        cookie = extract(args.host, args.port)
        if cookie is None:
            return 1
        sys.stdout.write(cookie + "\n")
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
