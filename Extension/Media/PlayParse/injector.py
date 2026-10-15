import json, os, threading, time, urllib.request
import websocket

CDP_SERVERS = ["http://127.0.0.1:9222", "http://[::1]:9222"]
CDP_ORIGIN = "http://localhost:9222"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPT_LIVE = os.path.join(BASE_DIR, "Bilibili - ChatScriptLive.js")
SCRIPT_VOD = os.path.join(BASE_DIR, "Bilibili - ChatScriptVod.js")
WAIT_FOR_DOM_READY = True  # False 时改用下面的固定延迟。
INJECT_DELAY = 1.5  # 仅 WAIT_FOR_DOM_READY = False 时使用。
RECONNECT_DELAY = 2.0

HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def get_json(url):
    with HTTP.open(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=2) as r:
        return json.loads(r.read().decode())

def classify(url):
    if url.startswith("https://live.bilibili.com/blanc/"): return SCRIPT_LIVE
    if url.startswith(("https://www.bilibili.com/video/BV",
                       "https://www.bilibili.com/bangumi/play/ep")): return SCRIPT_VOD
    return None

def read_script(path):
    with open(path, "r", encoding="utf-8") as f: return f.read()

class CDP:
    def __init__(self, ws_url):
        self.ws_url = ws_url
        self.ws, self.running, self.cid = None, False, 0
        self.send_lock, self.pending_lock, self.state_lock = threading.Lock(), threading.Lock(), threading.RLock()
        self.pending, self.urls, self.sessions, self.session_targets = {}, {}, {}, {}
        self.connecting, self.generations = set(), {}
        self.dom_waiters = {}

    def command(self, method, params=None, session=None, timeout=5):
        event = threading.Event()
        with self.pending_lock:
            self.cid += 1
            cid = self.cid
            self.pending[cid] = [event, None]
        msg = {"id": cid, "method": method}
        if params is not None: msg["params"] = params
        if session: msg["sessionId"] = session
        try:
            with self.send_lock: self.ws.send(json.dumps(msg))
            if not event.wait(timeout): raise TimeoutError(method)
            with self.pending_lock: response = self.pending[cid][1]
            if not response: raise RuntimeError(f"No response: {method}")
            if "error" in response: raise RuntimeError(response["error"])
            return response.get("result", {})
        finally:
            with self.pending_lock: self.pending.pop(cid, None)

    def schedule(self, tid, url):
        script = classify(url)
        with self.state_lock:
            self.generations[tid] = self.generations.get(tid, 0) + 1
            generation = self.generations[tid]
            waiter = self.dom_waiters.pop(tid, None)
            if waiter: waiter[1].set()
        if not script: return
        print(f"[MATCH] script={script} url={url}")
        threading.Thread(target=self.inject, args=(tid, url, script, generation), daemon=True).start()

    def target(self, info):
        tid, t, url = info.get("targetId", ""), info.get("type", ""), info.get("url", "")
        if not tid or t != "page": return
        with self.state_lock:
            old = self.urls.get(tid)
            self.urls[tid] = url
            if old != url:
                waiter = self.dom_waiters.pop(tid, None)
                if waiter: waiter[1].set()
            if not classify(url): return
            if tid not in self.sessions:
                if tid in self.connecting: return
                self.connecting.add(tid)
                threading.Thread(target=self.attach, args=(tid,), daemon=True).start()
                return
        if old != url: self.schedule(tid, url)

    def attach(self, tid):
        session = None
        try:
            session = self.command("Target.attachToTarget", {"targetId": tid, "flatten": True}).get("sessionId")
            if not session: raise RuntimeError("No sessionId")
            with self.state_lock:
                if tid not in self.urls: return
                self.sessions[tid] = session
                self.session_targets[session] = tid
            self.command("Page.enable", session=session)
            # 监听主框架的文档导航（包括同 URL 刷新）。
            with self.state_lock: url = self.urls.get(tid, "")
            if classify(url): self.schedule(tid, url)
        except Exception as e:
            print(f"[ERROR] attach target={tid} error={e}")
            with self.state_lock:
                self.sessions.pop(tid, None)
                if session: self.session_targets.pop(session, None)
        finally:
            with self.state_lock: self.connecting.discard(tid)
            if session and self.sessions.get(tid) != session:
                try: self.command("Target.detachFromTarget", {"sessionId": session}, timeout=2)
                except Exception: pass

    def current(self, tid, url, session, generation):
        return (self.generations.get(tid) == generation and self.urls.get(tid) == url
                and self.sessions.get(tid) == session)

    def wait_for_dom(self, tid, url, session, generation):
        event = threading.Event()
        waiter = (generation, event)
        with self.state_lock:
            if not self.running or not self.current(tid, url, session, generation): return False
            # 先登记再查询，避免查询期间错过 DOMContentLoaded。
            self.dom_waiters[tid] = waiter
        try:
            result = self.command("Runtime.evaluate", {
                "expression": "document.readyState", "returnByValue": True
            }, session)
            if "exceptionDetails" in result: raise RuntimeError(result["exceptionDetails"])
            state = result.get("result", {}).get("value")
            if state not in ("loading", "interactive", "complete"):
                raise RuntimeError(f"Unexpected document.readyState: {state}")
            if state == "loading": event.wait()
            with self.state_lock:
                return self.running and self.current(tid, url, session, generation)
        finally:
            with self.state_lock:
                if self.dom_waiters.get(tid) == waiter: self.dom_waiters.pop(tid, None)

    def dom_ready(self, session):
        with self.state_lock:
            tid = self.session_targets.get(session)
            waiter = self.dom_waiters.get(tid)
            if waiter: waiter[1].set()

    def cancel_dom_waits(self):
        with self.state_lock:
            for _, event in self.dom_waiters.values(): event.set()
            self.dom_waiters.clear()

    def inject(self, tid, url, script, generation):
        try:
            if not WAIT_FOR_DOM_READY: time.sleep(INJECT_DELAY)
            with self.state_lock:
                if self.generations.get(tid) != generation or self.urls.get(tid) != url: return
                session = self.sessions.get(tid)
            if not session: return
            if WAIT_FOR_DOM_READY and not self.wait_for_dom(tid, url, session, generation): return
            info = self.command("Target.getTargetInfo", {"targetId": tid}).get("targetInfo", {})
            if info.get("url") != url: return
            with self.state_lock:
                if not self.current(tid, url, session, generation): return
            result = self.command("Runtime.evaluate", {
                "expression": read_script(script), "awaitPromise": True, "returnByValue": True
            }, session)
            if "exceptionDetails" in result: raise RuntimeError(result["exceptionDetails"])
            print(f"[OK] script={script} url={url}")
        except Exception as e:
            print(f"[ERROR] url={url} error={e}")

    def remove(self, tid):
        with self.state_lock:
            waiter = self.dom_waiters.pop(tid, None)
            if waiter: waiter[1].set()
            self.urls.pop(tid, None)
            self.generations.pop(tid, None)
            session = self.sessions.pop(tid, None)
            if session: self.session_targets.pop(session, None)
            self.connecting.discard(tid)

    def reconnect_target(self, tid):
        try: self.target(self.command("Target.getTargetInfo", {"targetId": tid}).get("targetInfo", {}))
        except Exception: pass

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
                    self.remove(params.get("targetId"))
                elif method == "Target.detachedFromTarget":
                    with self.state_lock: tid = self.session_targets.get(params.get("sessionId"))
                    if tid:
                        self.remove(tid)
                        threading.Thread(target=self.reconnect_target, args=(tid,), daemon=True).start()
                elif method == "Page.frameNavigated":
                    frame = params.get("frame", {})
                    if "parentId" in frame: continue
                    with self.state_lock:
                        tid = self.session_targets.get(msg.get("sessionId"))
                        if not tid: continue
                        url = frame.get("url", "")
                        self.urls[tid] = url
                    self.schedule(tid, url)
                elif method == "Page.domContentEventFired":
                    self.dom_ready(msg.get("sessionId"))
        except Exception as e:
            if self.running: print(f"[ERROR] receive error={e}")
        finally:
            self.running = False
            self.cancel_dom_waits()
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
        self.cancel_dom_waits()
        if self.ws:
            try: self.ws.close()
            except Exception: pass

def monitor(server):
    while True:
        client = None
        try:
            ws_url = get_json(f"{server}/json/version").get("webSocketDebuggerUrl")
            if not ws_url: raise RuntimeError()
            client = CDP(ws_url)
            client.run()
        except Exception:
            pass
        finally:
            if client: client.close()
        time.sleep(RECONNECT_DELAY)

def main():
    print(f"Live JS:   {SCRIPT_LIVE}")
    print(f"Vod JS:    {SCRIPT_VOD}")
    print(f"Inject:    {'DOM ready' if WAIT_FOR_DOM_READY else f'delay {INJECT_DELAY}s'}")
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
