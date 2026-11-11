#!/usr/bin/env python3
"""Direct-dial HTTP proxy that squats a dead proxy port.

Why: DingTalk caches its proxy (classically 127.0.0.1:7890) at startup. When the
real proxy is off, every upload dies with:

    [HTTP55]space.dingtalk.com...Failed to connect to 127.0.0.1 port 7890
    after 2027 ms: Connection refused

This relay listens on that port and dials every target directly (no upstream
forwarding), so DingTalk's uploads start working again without restarting it
(which would lose the half-filled form).

Usage:
    python direct_proxy.py                # 127.0.0.1:7890
    python direct_proxy.py --port 10809
    python direct_proxy.py --host 127.0.0.1 --port 7890 --verbose

Handles CONNECT (https) and absolute-form requests (http).
"""
from __future__ import annotations

import argparse
import asyncio
from urllib.parse import urlsplit

VERBOSE = False


def log(*parts: object) -> None:
    if VERBOSE:
        print(*parts, flush=True)


async def pipe(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    try:
        while True:
            data = await reader.read(65536)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except Exception:  # noqa: BLE001 - one half closing is normal
        pass
    finally:
        try:
            writer.close()
        except Exception:  # noqa: BLE001
            pass


async def handle(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    try:
        head = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 20)
    except Exception:  # noqa: BLE001
        writer.close()
        return

    try:
        method, target = head.split(b"\r\n")[0].decode("latin1").split()[:2]
    except Exception:  # noqa: BLE001
        writer.close()
        return

    if method.upper() == "CONNECT":
        host, _, port_s = target.partition(":")
        port = int(port_s or 443)
        try:
            r2, w2 = await asyncio.wait_for(asyncio.open_connection(host, port), 20)
        except Exception as exc:  # noqa: BLE001
            log("CONNECT fail", target, exc)
            writer.write(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
            await writer.drain()
            writer.close()
            return
        writer.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        await writer.drain()
        await asyncio.gather(pipe(reader, w2), pipe(r2, writer))
        return

    url = urlsplit(target)
    if not url.hostname:
        writer.write(b"HTTP/1.1 400 Bad Request\r\n\r\n")
        await writer.drain()
        writer.close()
        return

    port = url.port or 80
    path = (url.path or "/") + (("?" + url.query) if url.query else "")
    try:
        r2, w2 = await asyncio.wait_for(asyncio.open_connection(url.hostname, port), 20)
    except Exception as exc:  # noqa: BLE001
        log("GET fail", target, exc)
        writer.write(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
        await writer.drain()
        writer.close()
        return

    rest = head[head.find(b"\r\n") + 2 :]
    w2.write(method.encode() + b" " + path.encode() + b" HTTP/1.1\r\n" + rest)
    await w2.drain()
    await asyncio.gather(pipe(reader, w2), pipe(r2, writer))


async def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=7890)
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    global VERBOSE
    VERBOSE = args.verbose

    server = await asyncio.start_server(handle, args.host, args.port)
    print(f"direct proxy listening on {args.host}:{args.port}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
