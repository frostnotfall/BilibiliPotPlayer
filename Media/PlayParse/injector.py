import json, os, threading, time, urllib.request
from urllib.parse import urlparse
import websocket

CDP_SERVERS = ["http://127.0.0.1:9222", "http://[::1]:9222"]
CDP_ORIGIN = "http://localhost:9222"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPT_LIVE = os.path.join(BASE_DIR, "Bilibili - ChatScriptLive.js")
SCRIPT_VOD = os.path.join(BASE_DIR, "Bilibili - ChatScriptVod.js")
INJECT_DELAY = 1.5
RECONNECT_DELAY = 2.0

HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def get_json(url):
    with HTTP.open(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=2) as r:
        return json.loads(r.read().decode())

def classify(url):
    p = urlparse(url)
    host, path = (p.hostname or "").lower(), p.path.rstrip("/")
    if host == "live.bilibili.com" and path.startswith("/blanc/"): return "live"
    if host == "www.bilibili.com" and path.startswith("/video/BV"): return "vod"
    if host == "www.bilibili.com" and path.startswith("/bangumi/play/ep"): return "vod"
    return None

def read_script(kind):
    path = SCRIPT_LIVE if kind == "live" else SCRIPT_VOD
    with open(path, "r", encoding="utf-8") as f: return f.read()

class CDP:
    def __init__(self, server, ws_url):
        self.server, self.ws_url = server, ws_url
        self.ws, self.running, self.cid = None, False, 0
        self.send_lock, self.pending_lock = threading.Lock(), threading.Lock()
        self.pending, self.urls, self.injected = {}, {}, set()

    def command(self, method, params=None, session=None, timeout=5):
        self.cid += 1
        cid, event = self.cid, threading.Event()
        with self.pending_lock: self.pending[cid] = [event, None]

        msg = {"id": cid, "method": method}
        if params is not None: msg["params"] = params
        if session: msg["sessionId"] = session

        try:
            with self.send_lock: self.ws.send(json.dumps(msg))
            if not event.wait(timeout): raise TimeoutError(method)
            response = self.pending[cid][1]
            if not response: raise RuntimeError(f"No response: {method}")
            if "error" in response: raise RuntimeError(response["error"])
            return response.get("result", {})
        finally:
            with self.pending_lock: self.pending.pop(cid, None)

    def target(self, info):
        tid, t, url = info.get("targetId", ""), info.get("type", ""), info.get("url", "")
        if not tid or t != "page": return

        old = self.urls.get(tid)
        if old != url:
            self.urls[tid] = url
            self.injected = {x for x in self.injected if x[0] != tid}

        kind = classify(url)
        key = (tid, url)
        if not kind or key in self.injected: return

        self.injected.add(key)
        print(f"[MATCH] type={kind} url={url}")
        threading.Thread(target=self.inject, args=(tid, url, kind), daemon=True).start()

    def inject(self, tid, url, kind):
        try:
            time.sleep(INJECT_DELAY)
            if self.urls.get(tid) != url: return

            info = self.command("Target.getTargetInfo", {"targetId": tid}).get("targetInfo", {})
            if info.get("url") != url: return

            session = self.command("Target.attachToTarget", {"targetId": tid, "flatten": True}).get("sessionId")
            if not session: raise RuntimeError("No sessionId")

            try:
                result = self.command("Runtime.evaluate", {
                    "expression": read_script(kind),
                    "awaitPromise": True,
                    "returnByValue": True
                }, session)

                if "exceptionDetails" in result: raise RuntimeError(result["exceptionDetails"])
            finally:
                try: self.command("Target.detachFromTarget", {"sessionId": session}, timeout=2)
                except Exception: pass

            print(f"[OK] type={kind} url={url}")

        except Exception as e:
            self.injected.discard((tid, url))
            print(f"[ERROR] url={url} error={e}")

    def receive(self):
        try:
            while self.running:
                raw = self.ws.recv()
                if not raw: break
                msg = json.loads(raw)

                cid = msg.get("id")
                if cid is not None:
                    with self.pending_lock:
                        pending = self.pending.get(cid)
                        if pending:
                            pending[1] = msg
                            pending[0].set()
                    continue

                method, params = msg.get("method"), msg.get("params", {})
                if method in ("Target.targetCreated", "Target.targetInfoChanged"):
                    self.target(params.get("targetInfo", {}))
                elif method == "Target.targetDestroyed":
                    tid = params.get("targetId")
                    self.urls.pop(tid, None)
                    self.injected = {x for x in self.injected if x[0] != tid}
        except Exception:
            pass
        finally:
            self.running = False
            with self.pending_lock:
                for event, _ in self.pending.values(): event.set()

    def run(self):
        self.ws = websocket.create_connection(self.ws_url, timeout=5, origin=CDP_ORIGIN, http_proxy_host=None)
        self.ws.settimeout(None)
        self.running = True

        threading.Thread(target=self.receive, daemon=True).start()

        self.command("Target.setDiscoverTargets", {"discover": True})
        for info in self.command("Target.getTargets").get("targetInfos", []): self.target(info)

        while self.running: time.sleep(1)

    def close(self):
        self.running = False
        if self.ws:
            try: self.ws.close()
            except Exception: pass

def monitor(server):
    while True:
        client = None
        try:
            ws_url = get_json(f"{server}/json/version").get("webSocketDebuggerUrl")
            if not ws_url: raise RuntimeError()
            client = CDP(server, ws_url)
            client.run()
        except Exception:
            pass
        finally:
            if client: client.close()
        time.sleep(RECONNECT_DELAY)

def main():
    print(f"Live JS:   {SCRIPT_LIVE}")
    print(f"Vod JS:    {SCRIPT_VOD}")
    print(f"CDP:       {CDP_SERVERS[0]}")
    for server in CDP_SERVERS[1:]: print(f"           {server}")

    for server in CDP_SERVERS:
        threading.Thread(target=monitor, args=(server,), daemon=True).start()

    try:
        while True: time.sleep(3600)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()