// @version      1.0.51

(() => {
  'use strict';
  // 与 BroadcastListScript 一样由 WebView2 在文档创建时注入；子框架不安装评论布局。
  if (window !== window.top) return;
  window.__bilibiliVideoCommentsStartup?.abort();
  const startup = new AbortController();
  window.__bilibiliVideoCommentsStartup = startup;
  function start() {
    startup.abort();
    if (window.__bilibiliVideoCommentsStartup === startup) delete window.__bilibiliVideoCommentsStartup;
    mount();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once:true, signal:startup.signal });
  else start();

  function mount() {
  const playbackScope = 'bili-comments, .bb-comment, .video-desc-container';

  const pageType = () => {
    if (location.hostname !== 'www.bilibili.com') return '';
    if (/^\/video\/(?:BV[\w]+|av\d+)(?:\/|$)/i.test(location.pathname)) return 'ugc';
    if (/^\/bangumi\/play\/(?:ss|ep)\d+(?:\/|$)/.test(location.pathname)) return 'pgc';
    return '';
  };
  if (!pageType()) return;
  let previousShortcuts = window.bilibiliVideoComments?.destroy() || {};

  // AVATAR_NAVIGATION_START
  // 页面导航由页面脚本负责；BroadcastListScript 只接收通用 ignoreUrl 规则。
  function createAvatarNavigation() {
    const events = new AbortController();
    let api = null, restoreIgnore = () => {}, active = null, timer = 0, restoreOpen = () => {};
    function destination(value) {
      try {
        const url = new URL(value, location.href);
        return ['http:', 'https:'].includes(url.protocol) && (url.hostname === 'space.bilibili.com' && /^\/\d+\/?$/.test(url.pathname)
          || url.hostname === 'link.bilibili.com' && url.pathname === '/p/center/index'
            && /^#\/?user-center\/my-info(?:\/|$)/.test(url.hash)) ? url : null;
      } catch { return null; }
    }
    function control(node) {
      const link = node instanceof Element ? node.closest('a') : null;
      return link && (link.closest('.header-avatar-wrap') && (link.matches('.header-entry-mini,.header-entry-avatar') || link.querySelector('.bili-avatar'))
        || link.closest('.link-navbar') && (link.querySelector('.user-avatar')
          || link.closest('.user-panel-ctnr,.user-panel') && link.textContent.trim() === '主站空间')
        || link.closest('.mini-header,.international-header') && link.querySelector('.i-face,.i_face')
        || link.closest('.charity-header') && link.matches('.user') && link.querySelector('.face')) ? link : null;
    }
    function isLink(link) { return Boolean(control(link) && link.hasAttribute('href') && destination(link.href)); }
    function ignored(url) {
      if (!destination(url.href)) return false;
      return Boolean(active) || Array.from(document.querySelectorAll(
        '.header-avatar-wrap a[href],.link-navbar a[href],.mini-header a[href],.international-header a[href],.charity-header a[href]'))
        .some(link => isLink(link) && link.href === url.href);
    }
    function sync() {
      const next = window.__potPlayerBilibiliClick;
      if (next === api) return;
      restoreIgnore(); api = next;
      restoreIgnore = typeof api?.ignoreUrl === 'function' ? api.ignoreUrl(ignored) : () => {};
    }
    function clear() {
      clearTimeout(timer); timer = 0; active = null;
      restoreOpen(); restoreOpen = () => {};
    }
    function onClick(event) {
      sync(); clear();
      if (!event.isTrusted || event.button !== 0) return;
      const link = control(event.target);
      if (!link) return;
      const modified = event.ctrlKey || event.metaKey || event.shiftKey || event.altKey;
      if (isLink(link)) {
        if (!modified) { event.preventDefault(); event.stopImmediatePropagation(); location.assign(link.href); }
        return;
      }
      // 无 href 的直播卡片保留原生处理器，只在本次点击内转换其 window.open。
      if (link.hasAttribute('href')) return;
      active = link;
      const originalOpen = window.open;
      function open(...args) {
        const url = destination(args[0]);
        if (active === link && url && !modified) { location.assign(url.href); return null; }
        return Reflect.apply(originalOpen, this, args);
      }
      window.open = open;
      restoreOpen = () => { if (window.open === open) window.open = originalOpen; };
      timer = setTimeout(clear, 0);
    }
    window.addEventListener('pointerdown', sync, { capture:true, signal:events.signal });
    window.addEventListener('keydown', sync, { capture:true, signal:events.signal });
    window.addEventListener('click', onClick, { capture:true, signal:events.signal });
    sync();
    const poll = setInterval(sync, 500);
    return { isLink, destroy() { events.abort(); clearInterval(poll); clear(); restoreIgnore(); } };
  }
  const avatarNavigation = createAvatarNavigation();
  // AVATAR_NAVIGATION_END
  const disposers = [];
  function listen(types, handler, options) {
    for (const type of types.split(' ')) {
      window.addEventListener(type, handler, options);
      disposers.push(() => window.removeEventListener(type, handler, options));
    }
  }
  function addStyle(root, css) {
    const style = document.createElement('style');
    style.textContent = css;
    root.append(style);
    return style;
  }

  function waitForInitialPlayer() {
    const events = new AbortController(), docs = new Set();
    let videoDone = false, switchDone = false, ended = false, pending = 0;
    const changes = new MutationObserver(scheduleInitial);
    const route = location.href;
    const timeout = setTimeout(stop, 10000);
    function stop() {
      ended = true; clearTimeout(timeout); cancelAnimationFrame(pending);
      changes.disconnect(); events.abort(); docs.clear();
    }
    function scheduleInitial() {
      if (!ended && !pending) pending = requestAnimationFrame(check);
    }
    function checkDocument(doc) {
      if (!docs.has(doc)) {
        docs.add(doc); changes.observe(doc, {childList:true, subtree:true});
        for (const type of ['load', 'play', 'loadeddata'])
          doc.addEventListener(type, scheduleInitial, {capture:true, signal:events.signal});
      }
      if (!switchDone) {
        const input = doc.querySelector('input.bui-switch-input[aria-label*="自动开播"]');
        if (input) { switchDone = true; if (input.checked) input.click(); }
      }
      if (!videoDone) {
        const video = [...doc.querySelectorAll('video')].find(node => !node.ended && (!node.paused || node.readyState >= 2));
        if (video) { videoDone = true; if (!video.paused) video.pause(); }
      }
      for (const iframe of doc.querySelectorAll('iframe')) {
        try { if (iframe.contentDocument) checkDocument(iframe.contentDocument); } catch {}
      }
    }
    function check() {
      pending = 0;
      if (ended) return;
      if (route !== location.href) { stop(); return; }
      checkDocument(document);
      if (videoDone && switchDone) stop();
    }
    // 用户开始交互即结束初始化等待，避免把后续手动播放当作自动播放。
    const onUserInput = event => { if (event.isTrusted) stop(); };
    for (const type of ['pointerdown', 'keydown'])
      window.addEventListener(type, onUserInput, {capture:true, signal:events.signal});
    check();
    return stop;
  }
  disposers.push(waitForInitialPlayer());

  // WebView 内的时间跳转交给宿主；普通浏览器仍屏蔽官方播放器跳转。
  listen('click auxclick dblclick', event => {
    if (!pageType()) return;
    const path = event.composedPath();
    const seek = path.find(node => node.matches?.('[data-type="seek"]'));
    const time = path.find(node => node.matches?.('.dm-info-time'));
    // 官方时间 span 禁用指针命中，实际由整行的 dblclick 触发 seek；单击选中仍保留。
    const row = event.type === 'dblclick' && path.find(node => node.matches?.('#danmukuBox .dm-info-row'));
    if (!seek && !time && !row) return;
    if (typeof window.chrome?.webview?.postMessage === 'function'
      && (seek && event.type !== 'dblclick' && path.some(node => node.matches?.(playbackScope))
        || (time || row) && path.some(node => node.matches?.('#danmukuBox')))) return;
    event.preventDefault();
    event.stopImmediatePropagation();
  }, { capture: true, passive: false });
  // MEDIA_MENU_START
  const scopes = [{"id":"HomePage","host":"www.bilibili.com","paths":["/","/index.html","/c/douga","/c/game","/c/kichiku","/c/music","/c/dance","/c/cinephile","/c/ent","/c/knowledge","/c/tech","/c/information","/c/food","/c/shortplay","/c/car","/c/fashion","/c/sports","/c/animal","/c/vlog","/c/painting","/c/ai","/c/home","/c/outdoors","/c/gym","/c/handmake","/c/travel","/c/rural","/c/parenting","/c/health","/c/emotion","/c/life_joy","/c/life_experience"]},{"id":"LiveHome","host":"live.bilibili.com","paths":["/","/all"],"protocols":["https:"]},{"id":"LiveArea","host":"live.bilibili.com","paths":["/p/eden/area-tags"]},{"id":"Feed","host":"t.bilibili.com","pathPattern":"^/.*$"},{"id":"History","host":"www.bilibili.com","paths":["/history"]},{"id":"Watchlater","host":"www.bilibili.com","paths":["/watchlater/list"]},{"id":"Follow","host":"link.bilibili.com","paths":["/p/center/index"],"hashPattern":"^#/user-center/follow/1/?(?:\\?.*)?$"},{"id":"Space","host":"space.bilibili.com","pathPattern":"^/\\d+(?:/(?:dynamic|upload(?:/(?:video|opus))?|lists|bangumi)|/(?:favlist|fav)(?:/.*)?)?/?$"},{"id":"Search","host":"search.bilibili.com","paths":["/all","/video","/bangumi","/pgc","/live","/article","/upuser"]},{"id":"Popular","host":"www.bilibili.com","paths":["/v/popular/all","/v/popular/weekly","/v/popular/history","/v/popular/rank/all","/v/popular/rank/anime","/v/popular/rank/bangumi","/v/popular/rank/guochuang","/v/popular/rank/documentary","/v/popular/rank/movie","/v/popular/rank/tv","/v/popular/rank/variety","/v/popular/rank/douga","/v/popular/rank/game","/v/popular/rank/kichiku","/v/popular/rank/music","/v/popular/rank/dance","/v/popular/rank/cinephile","/v/popular/rank/ent","/v/popular/rank/knowledge","/v/popular/rank/tech","/v/popular/rank/food","/v/popular/rank/car","/v/popular/rank/fashion","/v/popular/rank/sports","/v/popular/rank/animal","/v/popular/music"]},{"id":"Anime","host":"www.bilibili.com","paths":["/anime","/guochuang","/anime/timeline","/anime/index","/guochuang/timeline","/guochuang/index"]},{"id":"PGC","host":"www.bilibili.com","paths":["/movie","/tv","/variety","/documentary"]},{"id":"Charity","host":"love.bilibili.com","paths":["/"]},{"id":"UHD","host":"www.bilibili.com","paths":["/blackboard/era/Vp41b8bsU9Wkog3X.html","/blackboard/era/LqwJ5qsaKiEE0yj8.html"]},{"id":"Podcast","host":"www.bilibili.com","paths":["/blackboard/era/jpyPhRRrMn3fmZ2B.html","/blackboard/era/V9NZUSEYujbTPmT0.html"]},{"id":"Music","host":"music.bilibili.com","paths":["/pc/music-center","/pc/music-detail","/pc/rank","/h5/rank"]},{"id":"Article","host":"www.bilibili.com","paths":["/read/home","/opus"],"pathPattern":"^/(?:opus/\\d+|read/cv\\d+)/?$"}];
  function urlOf(value, base = location.href) {
    if (typeof value !== 'string' || !value.trim()) return null;
    try {
      const url = new URL(value, base);
      return ['http:', 'https:'].includes(url.protocol) ? url : null;
    } catch { return null; }
  }

  // 与 BroadcastListScript 的适配页面列表保持一致，决定页面菜单的类型。
  function pageId(value) {
    const url = value instanceof URL ? value : urlOf(value);
    if (!url || !['http:', 'https:'].includes(url.protocol)) return null;
    const path = url.pathname.replace(/\/$/, '') || '/';
    for (const scope of scopes) {
      if (url.hostname !== scope.host) continue;
      if (scope.protocols && !scope.protocols.includes(url.protocol)) continue;
      if (scope.hashPattern && !new RegExp(scope.hashPattern).test(url.hash)) continue;
      if (scope.paths?.includes(path) || scope.pathPattern && new RegExp(scope.pathPattern).test(url.pathname)) return scope.id;
    }
    return null;
  }
  const isPageUrl = value => Boolean(pageId(value));
  // PlayitemParse support only; playlist-only URLs must not get the video menu.
  function isPlayitemUrl(value) {
    const url = value instanceof URL ? value : urlOf(value);
    if (!url || !['http:', 'https:'].includes(url.protocol)) return false;
    const path = url.pathname;
    if (url.hostname === 'live.bilibili.com') return /^\/\d+\/?$/.test(path);
    if (url.hostname !== 'www.bilibili.com') return false;
    return /^\/video\/(?:BV[a-z\d]+|av\d+)\/?$/i.test(path)
      || /^\/bangumi\/(?:media\/md|play\/(?:ep|ss))\d+\/?$/i.test(path)
      || /^\/audio\/au\d+\/?$/i.test(path);
  }
  const isShortUrl = value => urlOf(value)?.hostname === 'b23.tv';
  // Playback/playlist support is independent of the pages this script can lay out.
  // Mirrors the supplied BilibiliPotPlayer parser branches, excluding gettid().
  // Match real hosts and path boundaries rather than substrings in another URL.
  function isPlaylistUrl(value) {
    const url = value instanceof URL ? value : urlOf(value);
    if (!url || !['http:', 'https:'].includes(url.protocol)) return false;
    const path = url.pathname;
    if (['t.bilibili.com','search.bilibili.com','live.bilibili.com'].includes(url.hostname)) return true;
    if (url.hostname === 'space.bilibili.com') return /^\/\d+(?:\/|$)/.test(path);
    if (url.hostname === 'link.bilibili.com') return /\/user-center\/follow(?:\/|$)/.test(path + url.hash);
    if (url.hostname !== 'www.bilibili.com') return false;
    return path === '/'
      || /^\/v\/popular\/(?:all|weekly|history|rank)(?:\/|$)/.test(path)
      || /^\/list\//.test(path)
      || /^\/(?:watchlater|history)(?:\/|$)/.test(path)
      || /^\/medialist\/detail\/ml\d+\/?$/i.test(path)
      || /^\/audio\/am\d+\/?$/i.test(path)
      || /^\/bangumi\/(?:media\/md|play\/(?:ep|ss))\d+\/?$/i.test(path)
      || /^\/video\/(?:BV[a-z\d]+|av\d+)\/?$/i.test(path);
  }
  const isPlayerUrl = value => isPlayitemUrl(value) || isPlaylistUrl(value);
  // PotPlayer internally splits the URI's trailing CLI switches even when the
  // Windows protocol registration passes the whole URI as one quoted argument.
  function playerCommandUri(value, command, seconds) {
    const url = urlOf(value);
    if (!url || !isPlayerUrl(url) || !['current', 'new', 'insert', 'add'].includes(command)) return '';
    let uri = 'potplayer://' + url.href + (command === 'new' ? ' /new' : ' /current');
    if (['insert', 'add'].includes(command)) uri += ' /' + command;
    if (seconds !== undefined) {
      const ms = Math.round(seconds * 1000);
      if (!Number.isSafeInteger(ms) || ms < 0) return '';
      const pad = value => String(value).padStart(2, '0');
      uri += ` /seek=${pad(Math.floor(ms / 3600000))}:${pad(Math.floor(ms / 60000) % 60)}:${pad(Math.floor(ms / 1000) % 60)}.${String(ms % 1000).padStart(3, '0')}`;
    }
    return uri;
  }

  const mediaMenuCSS = `
    :host {
      all: initial; position: fixed; z-index: 2147483647;
      --menu-bg: #fff; --menu-text: #18191c; --menu-muted: #74787d;
      --menu-border: #e3e5e7; --menu-hover: #f1f3f5; --menu-shadow: #0002;
      color-scheme: light;
    }
    :host([data-theme="dark"]) {
      --menu-bg: #242628; --menu-text: #f1f2f3; --menu-muted: #a1a6ac;
      --menu-border: #45484c; --menu-hover: #363a3e; --menu-shadow: #0007;
      color-scheme: dark;
    }
    [role="menu"] {
      box-sizing: border-box; display: flex; flex-direction: column;
      width: max-content; max-width: calc(100vw - 12px);
      max-height: calc(100vh - 12px); overflow: auto; padding: 4px;
      border: 1px solid var(--menu-border); border-radius: 7px;
      background: var(--menu-bg); color: var(--menu-text);
      box-shadow: 0 4px 16px var(--menu-shadow); font: 12px/1.5 system-ui, sans-serif;
    }
    button {
      all: unset; box-sizing: border-box; display: flex; align-items: center; gap: 8px;
      min-height: 27px; padding: 4px 7px; border-radius: 4px; cursor: default;
    }
    button:hover, button:focus-visible { background: var(--menu-hover); }
    button:focus-visible { outline: 1px solid #00aeec; outline-offset: -1px; }
    .icon { display: flex; flex: 0 0 16px; width: 16px; height: 16px; }
    svg, img { display: block; width: 16px; height: 16px; }
    .label { min-width: 0; overflow-wrap: anywhere; }
    .hint { color: var(--menu-muted); font-size: 11px; }
    [role="separator"] { height: 1px; flex-shrink: 0; margin: 4px 5px; background: var(--menu-border); }
    .copy-status { padding: 0 7px; color: var(--menu-muted); font-size: 11px; }
    .copy-status:empty { display: none; }
    dialog {
      box-sizing: border-box; width: max-content; max-width: calc(100vw - 24px);
      max-height: calc(100vh - 24px); overflow: auto; padding: 10px 16px;
      border: 2px solid var(--menu-border); border-radius: 8px;
      background: var(--menu-bg); color: var(--menu-text);
      box-shadow: 0 4px 24px var(--menu-shadow); font: 14px/1.6 system-ui, sans-serif;
    }
    dialog::backdrop { background: #0006; }
    dialog p { margin: 0 0 10px; overflow-wrap: anywhere; }
    .dialog-actions { display: flex; justify-content: center; gap: 30px; }
    .dialog-actions button {
      justify-content: center; width: 90px; min-width: 0; min-height: 28px;
      border: 2px solid var(--menu-border); cursor: pointer;
    }
    @media (pointer: coarse) {
      .dialog-actions button { min-height: 44px; }
    }
  `;
  // 菜单样式、图标和交互移植自 BroadcastListScript/src/common/media-menu。
  const icons = {
    bilibili:`<img src="data:image/x-icon;base64,AAABAAEAICAAAAEAIACoEAAAFgAAACgAAAAgAAAAQAAAAAEAIAAAAAAAABAAABMLAAATCwAAAAAAAAAAAAD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A1qEAANahAADWoQAG1qEAb9ahAMvWoQD01qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD01qEAy9ahAG/WoQAG1qEAANahAADWoQAA1qEAG9ahAM/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahANDWoQAb1qEAANahAAfWoQDQ1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahANHWoQAH1qEAbtahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAG7WoQDH1qEA/9ahAP/WoQD/1qEAtdahABjWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahABvWoQC11qEA/9ahAP/WoQD/1qEAx9ahAPnWoQD/1qEA/9ahAP/WoQAZ1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahABjWoQD/1qEA/9ahAP/WoQDz1qEA/9ahAP/WoQD/1qEA/9ahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEAANahAADWoQAA1qEAANahAErWoQDn1qEA5NahAErWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAErWoQDn1qEA5NahAErWoQAA1qEAANahAADWoQAA1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQAA1qEAANahAADWoQAA1qEA5tahAP/WoQD/1qEA59ahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEA5tahAP/WoQD/1qEA59ahAADWoQAA1qEAANahAADWoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAADWoQAA1qEAANahAADWoQD/1qEA/9ahAP/WoQD/1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQD/1qEA/9ahAP/WoQD/1qEAANahAADWoQAA1qEAANahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEAANahAADWoQAA1qEAANahAP/WoQD/1qEA/9ahAP/WoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAP/WoQD/1qEA/9ahAP/WoQAA1qEAANahAADWoQAA1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQAA1qEAANahAADWoQAA1qEA5tahAP/WoQD/1qEA5tahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEA5tahAP/WoQD/1qEA5tahAADWoQAA1qEAANahAADWoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAADWoQAA1qEAANahAADWoQBJ1qEA5tahAObWoQBJ1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQBJ1qEA5tahAObWoQBJ1qEAANahAADWoQAA1qEAANahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQD/1qEA/9ahAP/WoQD/1qEA+dahAP/WoQD/1qEA/9ahABnWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAGdahAP/WoQD/1qEA/9ahAPjWoQDH1qEA/9ahAP/WoQD/1qEAttahABnWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahABnWoQC21qEA/9ahAP/WoQD/1qEAx9ahAG3WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQBt1qEABtahAM/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA0NahAAfWoQAA1qEAG9ahAM/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAM/WoQAb1qEAANahAADWoQAA1qEABtahAG7WoQDH1qEA89ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA/9ahAP/WoQD/1qEA89ahAMfWoQBu1qEABtahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEADtahAMXWoQD/1qEA/9ahAP/WoQD/1qEAxdahAA/WoQAA1qEAANahAADWoQAA1qEADtahAMXWoQD/1qEA/9ahAP/WoQD/1qEAxdahAA/WoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAAbWoQDF1qEA/9ahAP/WoQD/1qEA/9ahAMXWoQAP1qEAANahAADWoQAA1qEAANahAADWoQAA1qEADtahAMXWoQD/1qEA/9ahAP/WoQD/1qEAxdahAAbWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAYtahAP/WoQD/1qEA/9ahAP/WoQDF1qEADtahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEADtahAMXWoQD/1qEA/9ahAP/WoQD/1qEAY9ahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQBf1qEA/9ahAP/WoQD/1qEAxdahAA7WoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEADtahAMXWoQD/1qEA/9ahAP/WoQBf1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAATWoQCg1qEA6tahAKjWoQAO1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEAANahAADWoQAA1qEADtahAKjWoQDr1qEAoNahAATWoQAA1qEAANahAADWoQAA1qEAAP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A///////////AAAADgAAAAQAAAAAAAAAAA///wAf//+AP///wD///8A////AP///wDw/w8A8P8PAPD/DwDw/w8A8P8PAPD/DwD///8A////AH///gA///wAAAAAAAAAAAgAAAAcAAAAP8A8A/+AfgH/gP8B/4H/gf+D/8H/////8=" width="16" height="16" alt="" />`,
    player:`<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAGxSURBVDhPjZO7L0RREMZXoxCN/a4gUeiERKJSqxSi4e/RKYWIiIpCJRqliLBIPMcj+7Ae13sJGW+7yy6LYXb3rnNvCF8yOTe5M785c2bGxwSfKSbUMqGbCVtMSDHhlQkHTBhkQpPLOR/gnMVM6GVC5jFkyVPUkvROzp6jlsTDljDhgwmjTChzAfLBUw9BFIJ+M/VhQogJ5SagzwxORiy53UT29AIMyIQDqNNrmw6XK365Ph6QvZkKuVlHtgQvRBMwoVUBPVqz+fMgUCaq5/i+2Evtcrrgl4eQJantbx+9HRMmFRD1ZtibzgEcXcfGZXeuXi5X/ZLc+vZjQloBae/1vADVWyYpsUinnC3XFDp0tQZRwMt/AKpU4lDO15slEXYD7L9KeMs8yUmkS+xApdxuoPAWOmQK6I97HtE2AFr/zmxDrn6jrfoWTAgooJEJ7yYgtuCX5P2G2IttP3ZA7S7Xxg5nkIbNQboPWtmM6uQNVNO2M2GeCUUOoIQJS/8Z5XzwEROqvctUyoQRXRhdHDOzfify4607w4Qq1zKZ0pVlwhATLrRNTFm7YsIYE1pczl/6BGPfkAuxnOXwAAAAAElFTkSuQmCC" width="16" height="16" alt="" />`,
    playlist:`<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAEHSURBVDhPlZIxL0NhFIZr9CP4CUfSxGCwiNitGkTjN5isFsxmjTdMJCxaI0lnFrU0MYgY25hIex85tJ97P3pz75N823mf8+bkq5iom7g0sWViqlIWE28mGL2miZl4JhcPzgmWL4Kkb2K7cBsPrV3DMIGTDsyflWzjw5stAs99WG+WaBMLHG9z/Jhp0zIxG2e/+U8wptuDWtQmzucKnEECRw9BkphYLCVwrrpB4G+1sKD3ATt3ITg0sf/noJMEty+wdB7CTyYWMsExseD9E3bbma2HJqbjXMAHN0aC9ius/P7IyVvT+HD1FOo3P1/axMDEQe7WNCbuUxfuFNqaxgMmGib2Cm9N8QXQeLETIuHdxQAAAABJRU5ErkJggg==" width="16" height="16" alt="" />`,
    browser:'<svg viewBox="0 0 20 20" fill="none" stroke="#3199dc" stroke-width="1.4"><circle cx="10" cy="10" r="8"/><ellipse cx="10" cy="10" rx="3.7" ry="8"/><path d="M2 10h16M3.5 5.5h13M3.5 14.5h13"/></svg>',
  };

  function pageTheme(media) {
    const navigation = document.getElementById('broadcast-navigation');
    if (['dark','light'].includes(navigation?.dataset.theme)) return navigation.dataset.theme;
    const html = document.documentElement;
    const sheet = document.querySelector('link#__css-map__')?.getAttribute('href') || '';
    const marker = (html.getAttribute('data-theme') || html.getAttribute('lab-style') || '').toLowerCase();
    if (sheet.includes('/dark.css')) return 'dark';
    if (sheet.includes('/light.css')) return 'light';
    if (html.classList.contains('bili_dark') || marker.includes('dark')) return 'dark';
    if (marker.includes('light')) return 'light';
    const scheme = getComputedStyle(html).colorScheme;
    return ['dark','light'].includes(scheme) ? scheme : media.matches ? 'dark' : 'light';
  }

  async function copyLink(value) {
    try {
      if (navigator.clipboard?.writeText) { await navigator.clipboard.writeText(value); return; }
    } catch { /* Older/permission-limited WebViews can still allow native copy. */ }
    let focused = document.activeElement;
    while (focused?.shadowRoot?.activeElement) focused = focused.shadowRoot.activeElement;
    const selection = getSelection();
    const ranges = selection ? Array.from({length:selection.rangeCount}, (_, i) => selection.getRangeAt(i).cloneRange()) : [];
    const input = document.createElement('textarea'); input.value = value; input.readOnly = true;
    input.style.cssText = 'position:fixed;left:-10000px;top:0;'; document.body.append(input);
    try { input.select(); if (!document.execCommand('copy')) throw new Error('Copy denied'); }
    finally {
      input.remove(); if (focused?.isConnected) focused.focus({preventScroll:true});
      if (selection) { selection.removeAllRanges(); for (const range of ranges) selection.addRange(range); }
    }
  }

  // One delegated listener covers dynamic cards and open shadow roots. The owner
  // supplies the same link eligibility and playback rules as its normal clicks.
  function createMediaMenu({getTarget, openPage, play, openNew, openExternal, addNext, addLast}) {
    const events = new AbortController();
    const media = matchMedia('(prefers-color-scheme: dark)');
    let host = null, previousFocus = null, menuEvents = null, themeObserver = null, stopped = false;
    const scrollPositions = new Map();
    let dialogHost = null, dialogEvents = null, dialogFocus = null;
    function syncTheme() {
      if (!host && !dialogHost) return;
      const theme = pageTheme(media);
      for (const element of [host, dialogHost]) if (element && element.dataset.theme !== theme) element.dataset.theme = theme;
    }
    function watchTheme() {
      themeObserver?.disconnect();
      themeObserver = new MutationObserver(syncTheme);
      themeObserver.observe(document.documentElement, {attributes:true, attributeFilter:['class','style','data-theme','lab-style']});
      if (document.head) themeObserver.observe(document.head, {childList:true, subtree:true, attributes:true, attributeFilter:['href']});
      const navigation = document.getElementById('broadcast-navigation');
      if (navigation) themeObserver.observe(navigation, {attributes:true, attributeFilter:['data-theme']});
      syncTheme();
    }
    function releaseTheme() {
      if (host || dialogHost) return;
      themeObserver?.disconnect(); themeObserver = null;
    }
    function close(restoreFocus = false) {
      const focused = host?.shadowRoot?.activeElement;
      menuEvents?.abort(); menuEvents = null;
      host?.remove(); host = null;
      scrollPositions.clear();
      releaseTheme();
      if (restoreFocus && focused && previousFocus?.isConnected) previousFocus.focus({preventScroll:true});
      previousFocus = null;
    }
    function closeDialog(restoreFocus = false) {
      dialogEvents?.abort(); dialogEvents = null;
      dialogHost?.shadowRoot.querySelector('dialog')?.close();
      dialogHost?.remove(); dialogHost = null;
      releaseTheme();
      if (restoreFocus && dialogFocus?.isConnected) dialogFocus.focus({preventScroll:true});
      dialogFocus = null;
    }
    function confirmExternal(url) {
      if (stopped || !document.body) return false;
      // A single modal consumes duplicate site handlers for the same click.
      if (dialogHost) return true;
      close(true);
      dialogFocus = document.activeElement;
      dialogHost = document.createElement('div'); dialogHost.id = 'bilibili-vod-external-dialog';
      const root = dialogHost.attachShadow({mode:'open'});
      const style = document.createElement('style'); style.textContent = mediaMenuCSS;
      const dialog = document.createElement('dialog'); dialog.setAttribute('aria-labelledby','external-question');
      const message = document.createElement('p'); message.id = 'external-question';
      message.textContent = '不支持此页面，是否从外置浏览器打开？';
      const actions = document.createElement('div'); actions.className = 'dialog-actions';
      dialogEvents = new AbortController();
      for (const [label, accepted] of [['是',true],['否',false]]) {
        const button = document.createElement('button'); button.type = 'button'; button.textContent = label;
        button.addEventListener('click', event => {
          if (!event.isTrusted || event.button !== 0) return;
          event.preventDefault(); event.stopPropagation(); closeDialog(true);
          if (accepted) openExternal({url});
        }, {signal:dialogEvents.signal});
        actions.append(button);
      }
      dialog.addEventListener('cancel', event => {event.preventDefault(); closeDialog(true);}, {signal:dialogEvents.signal});
      // Prevent page click handlers (including the window.open wrapper) from
      // interpreting dialog buttons as another navigation request.
      root.addEventListener('click', event => event.stopPropagation(), {signal:dialogEvents.signal});
      dialog.append(message,actions); root.append(style,dialog); document.body.append(dialogHost); watchTheme();
      try { dialog.showModal(); return true; }
      catch { closeDialog(true); return false; }
    }
    function itemsFor(target) {
      if (target.kind === 'seek') return [
        {label:'使用当前进程播放(精准空降)', hint:'(鼠标左键)', icon:'player', action:play},
        {label:'新开一个进程播放', icon:'player', action:openNew},
        {label:'新开一个进程播放(精准空降)', hint:'(鼠标中键)', icon:'player', action:value => openNew({...value, precise:true})}, null,
        {label:'从外部浏览器打开', icon:'browser', action:openExternal},
        {label:'从外部浏览器打开(精准空降)', icon:'browser', action:value => openExternal({...value, url:value.preciseUrl})}, null,
        {label:'复制链接地址', copy:true},
        {label:'复制链接地址(精准空降)', copy:true, precise:true},
      ];
      if (target.kind === 'native') return [
        {label:'不支持当前页面，从外置浏览器打开', action:openExternal},
      ];
      const external = {label:'从外部浏览器打开', icon:'browser', action:openExternal};
      const copy = {label:'复制链接地址', copy:true};
      if (target.kind === 'page') {
        const items = [
          {label:'在当前标签页打开该页面', hint:'(鼠标左键)', icon:'bilibili', action:openPage}, external,
        ];
        if (target.playlist) items.push(
          {label:'播放该页面内视频', icon:'player', action:play},
          {label:'新开一个进程播放该页面内视频', hint:'(鼠标中键)', icon:'player', action:openNew}, null,
          {label:'将该页面内视频添加到默认播放列表（下一个）', icon:'playlist', action:addNext},
          {label:'将该页面内视频添加到默认播放列表（末尾）', icon:'playlist', action:addLast},
        );
        return [...items, null, copy];
      }
      return [
        {label:'使用当前进程播放', hint:'(鼠标左键)', icon:'player', action:play},
        {label:'新开一个进程播放', hint:'(鼠标中键)', icon:'player', action:openNew}, external, null,
        {label:'添加到默认播放列表（下一个）', icon:'playlist', action:addNext},
        {label:'添加到默认播放列表（末尾）', icon:'playlist', action:addLast}, null, copy,
      ];
    }
    function onContextMenu(event) {
      if (stopped || !event.isTrusted || event.defaultPrevented || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      close();
      const target = getTarget(event);
      if (!target || !document.body || dialogHost) return;
      event.preventDefault(); event.stopImmediatePropagation();
      // Only scrolling an ancestor moves the menu's target. Native live banners
      // also scroll their own overflow-hidden contents during animation; those
      // unrelated events must not dismiss another card's menu. Snapshot offsets
      // to ignore scroll-into-view events already queued before contextmenu.
      const path = event.composedPath();
      // composedPath also includes ancestors outside an open shadow root.
      for (const node of new Set([...path.slice(path.indexOf(target.anchor) + 1), document.scrollingElement])) {
        if (node instanceof Element && node !== target.anchor) scrollPositions.set(node, [node.scrollLeft, node.scrollTop]);
      }
      previousFocus = document.activeElement;
      menuEvents = new AbortController();
      host = document.createElement('div'); host.id = 'bilibili-vod-media-menu';
      const root = host.attachShadow({mode:'open'});
      const style = document.createElement('style'); style.textContent = mediaMenuCSS;
      const menu = document.createElement('div'); menu.setAttribute('role','menu'); menu.setAttribute('aria-label','媒体打开方式');
      const status = document.createElement('div'); status.className = 'copy-status'; status.setAttribute('role','status');
      function place() {
        const bounds = host.getBoundingClientRect(), anchorBounds = target.anchor.getBoundingClientRect();
        const x = event.clientX || anchorBounds.left, y = event.clientY || anchorBounds.bottom;
        host.style.left = Math.max(6, Math.min(x, innerWidth - bounds.width - 6)) + 'px';
        host.style.top = Math.max(6, Math.min(y, innerHeight - bounds.height - 6)) + 'px';
      }
      const buttons = [];
      for (const item of itemsFor(target)) {
        if (!item) { const separator = document.createElement('div'); separator.setAttribute('role','separator'); menu.append(separator); continue; }
        const button = document.createElement('button'); button.type = 'button'; button.setAttribute('role','menuitem');
        button.setAttribute('aria-label', item.label + (item.hint || ''));
        const image = document.createElement('span'); image.className = 'icon'; image.setAttribute('aria-hidden','true'); image.innerHTML = icons[item.icon] || '';
        const label = document.createElement('span'); label.className = 'label'; label.textContent = item.label;
        if (item.hint) { const hint = document.createElement('span'); hint.className = 'hint'; hint.textContent = item.hint; label.append(hint); }
        button.append(image,label);
        button.addEventListener('click', async event => {
          if (!event.isTrusted || event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
          event.preventDefault(); event.stopPropagation();
          if (item.copy) {
            const current = host;
            try { await copyLink(item.precise ? target.preciseUrl : target.url); if (host === current) close(true); }
            catch { if (host === current) { status.textContent = '复制失败，请重试'; place(); } }
          } else { close(true); item.action(target); }
        }, {signal:menuEvents.signal});
        menu.append(button); buttons.push(button);
      }
      menu.append(status); root.append(style,menu); document.body.append(host); watchTheme();
      place();
      root.addEventListener('keydown', event => {
        if (event.key === 'Escape') {event.preventDefault(); close(true);}
        else if (event.key === 'Tab') close();
        else if (['ArrowDown','ArrowUp','Home','End'].includes(event.key)) {
          event.preventDefault();
          const index = buttons.indexOf(root.activeElement);
          buttons[event.key === 'Home' ? 0 : event.key === 'End' ? buttons.length - 1 : (index + (event.key === 'ArrowDown' ? 1 : -1) + buttons.length) % buttons.length].focus();
        }
      }, {signal:menuEvents.signal});
      buttons[0].focus({preventScroll:true});
    }
    window.addEventListener('contextmenu', onContextMenu, {capture:true, signal:events.signal});
    document.addEventListener('pointerdown', event => {if (host && !event.composedPath().includes(host)) close();}, {capture:true, signal:events.signal});
    document.addEventListener('scroll', event => {
      if (!host || event.composedPath().includes(host)) return;
      const node = event.target === document ? document.scrollingElement : event.target;
      const position = scrollPositions.get(node);
      if (!position || node.scrollLeft === position[0] && node.scrollTop === position[1]) return;
      close();
    }, {capture:true, signal:events.signal});
    window.addEventListener('resize', () => close(), {signal:events.signal});
    window.addEventListener('blur', () => close(), {signal:events.signal});
    media.addEventListener('change', syncTheme, {signal:events.signal});
    return {confirmExternal, close() {close(); closeDialog();}, destroy() {if (stopped) return; stopped = true; events.abort(); close(); closeDialog();}};
  }
  // MEDIA_MENU_END

  // 点击功能随布局实例安装/卸载；普通浏览器中不改变跳转。
  function installPotPlayerClick() {
    const webview = window.chrome?.webview;
    if (typeof webview?.postMessage !== 'function') return { prepare() {}, close() {}, destroy() {} };
    const originalOpen = window.open;
    const clickScope = '.video-tag-container, #bgm-entry #musicApp .videoList :is(.coverWrap, .videoTitle)';
    let click = null;
    let timer = 0;
    const shortLinks = new Map();
    const shortQueue = [];
    const SHORT_CONCURRENCY = 4, SHORT_CACHE_LIMIT = 128;
    const SHORT_SUCCESS_TTL = 600000, SHORT_FAILURE_TTL = 15000;
    let shortActive = 0;

    function clearClick() {
      clearTimeout(timer);
      timer = 0;
      click = null;
    }

    async function resolveMenuUrl(url) {
      if (!isShortUrl(url)) return url;
      return prepareLink(url, true);
    }

    function seekTarget(path, rowSeek = false) {
      const row = path.find(node => node.matches?.('#danmukuBox .dm-info-row'));
      const time = path.find(node => node.matches?.('#danmukuBox .dm-info-time'))
        || (rowSeek ? row?.querySelector('.dm-info-time') : null);
      if (!time && !path.some(node => node.matches?.(playbackScope))) return null;
      const anchor = time || path.find(node => node.matches?.('[data-type="seek"]'));
      // 弹幕行没有 data-video-time，只有官方显示的 mm:ss / hh:mm:ss。
      const parts = time?.textContent.trim().match(/^(?:(\d+):)?(\d+):([0-5]\d(?:\.\d+)?)$/);
      const value = time ? parts && (!parts[1] || Number(parts[2]) < 60)
        ? String(Number(parts[1] || 0) * 3600 + Number(parts[2]) * 60 + Number(parts[3])) : null
        : anchor?.getAttribute('data-video-time');
      // 简介/评论优先使用官方秒数；弹幕时间列则已转换为秒数。
      if (value == null || !value.trim()) return null;
      const seconds = Number(value);
      if (!Number.isFinite(seconds) || seconds < 0 || !Number.isSafeInteger(Math.round(seconds * 1000))) return null;
      const current = new URL(location.href);
      const url = new URL(current.origin + current.pathname);
      if (pageType() === 'ugc') {
        // -1 表示未指定分P，使用当前页面的 p；显式分P优先使用官方属性。
        const partValue = time ? '-1' : anchor.getAttribute('data-video-part');
        const part = partValue == null || !partValue.trim()
          ? Number(anchor.textContent.trim().match(/^(\d+)#/)?.[1] || -1) : Number(partValue);
        const targetPart = part === -1 ? Number(current.searchParams.get('p') || 1) : part;
        if (!Number.isSafeInteger(targetPart) || targetPart <= 0) return null;
        if (targetPart !== 1) url.searchParams.set('p', String(targetPart));
      }
      const precise = new URL(url);
      precise.searchParams.set('t', String(seconds));
      return {anchor, url:url.href, preciseUrl:precise.href, seconds, kind:'seek', playbackOnly:true};
    }

    function menuTarget(event) {
      if (!pageType()) return null;
      const path = event.composedPath();
      const seek = seekTarget(path);
      if (seek) return seek;
      if (path.some(node => node.matches?.('[data-type="seek"], .dm-info-time, input, textarea, [contenteditable="true"]'))) return null;
      const anchor = path.find(node => node.matches?.('a[href]'));
      if (!anchor || anchor.hasAttribute('download') || avatarNavigation.isLink(anchor)) return null;
      const url = urlOf(anchor.getAttribute('href'))?.href;
      if (!url || anchor.getAttribute('href').trim().startsWith('#')) return null;
      const resolved = shortLinks.get(url)?.url || url;
      const playbackOnly = path.some(node => node.matches?.(clickScope) || node.matches?.(playbackScope));
      const kind = isPlayitemUrl(resolved) || isShortUrl(resolved) ? 'media' : !playbackOnly && isPageUrl(resolved) ? 'page' : 'native';
      return {anchor, url, kind, playbackOnly, playlist:!playbackOnly && isPlaylistUrl(resolved)};
    }

    let destroyed = false;
    function external(url) {
      clearClick();
      Reflect.apply(originalOpen, window, [url, '_blank', 'noopener']);
    }
    async function menuPlay(target) {
      if (target.kind === 'seek') {
        clearClick();
        if (destroyed || !pageType()) return;
        // 宿主直接定位当前播放项；不重新打开视频，也不经过系统协议入口。
        try { webview.postMessage({ type:'potPlayer.seek', seek:target.seconds }); } catch {}
        return;
      }
      const {url, playbackOnly} = target;
      clearClick();
      const resolved = await resolveMenuUrl(url);
      if (destroyed || !pageType()) return;
      if (!(playbackOnly ? isPlayitemUrl(resolved) : isPlayerUrl(resolved)) || !send(resolved)) mediaMenu.confirmExternal(resolved || url);
    }
    async function menuCommand({url, kind, playbackOnly, precise, seconds}, command) {
      clearClick();
      // 时间节点已生成完整视频 URL，保持在用户点击的同步调用栈中打开协议链接。
      const resolved = kind === 'seek' ? url : await resolveMenuUrl(url);
      if (destroyed || !pageType()) return;
      const uri = (!playbackOnly || isPlayitemUrl(resolved)) && playerCommandUri(resolved, command, precise ? seconds : undefined);
      // _blank 经系统协议入口解析完整命令；_self 的内部媒体打开路径不处理相同的 /seek。
      if (uri) Reflect.apply(originalOpen, window, [uri, '_blank']);
      else mediaMenu.confirmExternal(resolved || url);
    }
    const mediaMenu = createMediaMenu({
      getTarget:menuTarget,
      openPage({url}) { clearClick(); location.assign(url); },
      play:menuPlay,
      openNew:target => menuCommand(target, 'new'),
      addNext:target => menuCommand(target, 'insert'),
      addLast:target => menuCommand(target, 'add'),
      openExternal:({url}) => external(url),
    });
    listen('popstate', () => mediaMenu.close());

    function prepare(root) {
      if (root === document) {
        for (const content of root.querySelectorAll(playbackScope)) prepare(content);
        return;
      }
      // Frame fallback is lazy: scanning a long comment list must not load target pages.
      if (typeof window.__potPlayerBilibiliClick?.resolveUrl !== 'function') return;
      const anchors = [...(root.matches?.('a[href]') ? [root] : []), ...root.querySelectorAll('a[href]')];
      for (const anchor of anchors) {
        const url = urlOf(anchor.getAttribute('href'))?.href;
        if (url) prepareLink(url);
      }
    }

    function prepareLink(url, priority = false) {
      if (destroyed || !/^https?:\/\/b23\.tv\/[a-z\d]+\/?(?:[?#].*)?$/i.test(url)) return Promise.resolve('');
      let entry = shortLinks.get(url);
      if (entry && entry.expires <= Date.now()) { shortLinks.delete(url); entry = null; }
      if (entry) {
        shortLinks.delete(url); shortLinks.set(url, entry);
        if (priority && entry.queued) {
          shortQueue.splice(shortQueue.indexOf(entry), 1); shortQueue.unshift(entry);
        }
        return entry.promise;
      }
      if (shortLinks.size >= SHORT_CACHE_LIMIT) {
        const victim = [...shortLinks].find(([, value]) => !value.active && (!value.queued || priority));
        if (!victim) return Promise.resolve('');
        victim[1].cancel(); shortLinks.delete(victim[0]);
      }
      let finish;
      entry = { key:url, url:'', queued:true, active:false, expires:Infinity,
        promise:new Promise(resolve => { finish = resolve; }), cancel() { complete(''); } };
      let timer = 0, iframe = null, done = false;
      function complete(value) {
        if (done) return;
        done = true; clearTimeout(timer);
        if (iframe) { iframe.onload = null; iframe.remove(); }
        if (entry.queued) shortQueue.splice(shortQueue.indexOf(entry), 1);
        if (entry.active) shortActive--;
        entry.active = entry.queued = false;
        const resolved = urlOf(value)?.href;
        entry.url = resolved && !isShortUrl(resolved) ? resolved : '';
        entry.expires = Date.now() + (entry.url ? SHORT_SUCCESS_TTL : SHORT_FAILURE_TTL);
        finish(entry.url);
        // Defer pumping so eviction and destroy finish updating their collections first.
        queueMicrotask(pumpShortLinks);
      }
      entry.start = () => {
        entry.queued = false; entry.active = true; shortActive++;
        timer = setTimeout(() => complete(''), 8000);
        const resolver = window.__potPlayerBilibiliClick;
        if (typeof resolver?.resolveUrl === 'function') {
          Promise.resolve().then(() => resolver.resolveUrl(url)).then(complete, () => complete(''));
        } else {
          iframe = document.createElement('iframe'); iframe.hidden = true;
          iframe.setAttribute('sandbox', 'allow-same-origin');
          iframe.onload = () => {
            let value = '';
            try { value = iframe.contentDocument?.URL || ''; } catch {}
            complete(value);
          };
          iframe.src = url; document.body.append(iframe);
        }
      };
      shortLinks.set(url, entry);
      if (priority) shortQueue.unshift(entry); else shortQueue.push(entry);
      pumpShortLinks();
      return entry.promise;
    }
    function pumpShortLinks() {
      while (!destroyed && shortActive < SHORT_CONCURRENCY && shortQueue.length) {
        const entry = shortQueue.shift();
        try { entry.start(); } catch { entry.cancel(); }
      }
    }

    function send(url) {
      try {
        webview.postMessage({ type: 'potPlayer.video-click', url });
        return true;
      } catch { return false; }
    }

    function dispatch(url, state) {
      if (destroyed || !pageType() || state.route !== location.href) return;
      if (state.sent.has(url)) return;
      state.sent.add(url);
      if (state.middle) { menuCommand({url, playbackOnly:true}, 'new'); return; }
      // 简介、评论和标签只播放 PlayitemParse 支持的单项媒体；其他页面先确认外部打开。
      if (!isPlayitemUrl(url) || !send(url)) mediaMenu.confirmExternal(url);
    }

    function handle(value, state) {
      const url = urlOf(value)?.href;
      if (!url) return false;
      if (!isShortUrl(url)) dispatch(url, state);
      else if (!state.pending.has(url)) {
        state.pending.add(url);
        resolveMenuUrl(url).then(resolved => dispatch(resolved || url, state));
      }
      return true;
    }

    function onClick(event) {
      clearClick();
      if (!pageType() || !event.isTrusted || ![0, 1].includes(event.button)) return;
      if (event.button === 1 && (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.defaultPrevented)) return;
      const path = event.composedPath();
      const time = path.some(node => node.matches?.('#danmukuBox .dm-info-time'));
      const row = path.some(node => node.matches?.('#danmukuBox .dm-info-row'));
      if (event.type === 'dblclick' && !row) return;
      if (time || event.type === 'dblclick' && row
        || path.some(node => node.matches?.('[data-type="seek"]')) && path.some(node => node.matches?.(playbackScope))) {
        event.preventDefault();
        event.stopImmediatePropagation();
        // 时间的双击已由 click 定位；内容/整行保留官方的双击手势。
        if (event.type === 'dblclick' && time) return;
        const target = seekTarget(path, event.type === 'dblclick');
        if (target) {
          if (event.button === 1) menuCommand({...target, precise:true}, 'new');
          else menuPlay(target);
        }
        return;
      }
      // 中键与右键菜单使用相同的目标和命令，覆盖推荐区、UP 主等简介/评论以外的链接。
      // 在 window 捕获阶段消费事件，阻止 document 公共桥及 WebView 的外部打开默认动作。
      if (event.button === 1) {
        const target = menuTarget(event);
        if (target && (target.kind === 'media' || target.kind === 'page' && target.playlist)) {
          event.preventDefault();
          event.stopImmediatePropagation();
          menuCommand(target, 'new');
          return;
        }
      }
      // 事件路径可读取开放 Shadow DOM 内的链接，不局限于 retarget 后的 target。
      const anchor = path.find(node => node.matches?.('a[href]'));
      const inScope = path.some(node => node.matches?.(clickScope));
      if (!inScope && !path.some(node => node.matches?.(playbackScope))) return;
      if (anchor?.hasAttribute('download') || avatarNavigation.isLink(anchor)) return;
      const href = anchor?.getAttribute('href');
      if (href?.trim().startsWith('#')) return;
      const state = {sent:new Set(), pending:new Set(), middle:event.button === 1, route:location.href};
      if (urlOf(href)) {
        event.preventDefault();
        event.stopImmediatePropagation();
        handle(href, state);
        return;
      }
      // 无 href 时保留官方处理器，由其 window.open 提供实际目标地址。
      if (inScope || anchor) {
        click = state;
        timer = setTimeout(() => { click = null; }, 0);
      }
    }

    function open(...args) {
      // 原站组件会探测/创建空白窗口；WebView 的外部打开入口不能处理 about:。
      // 返回标准的“未创建窗口”结果，保留稍后再看等组件自己的处理器和反馈。
      if (pageType() && (args[0] == null || !String(args[0]).trim()
        || /^about:blank(?:[?#].*)?$/i.test(String(args[0]).trim()))) return null;
      if (click && pageType() && handle(args[0], click)) return null;
      return Reflect.apply(originalOpen, this, args);
    }

    window.open = open;
    listen('mousedown', event => {
      if (!pageType() || !event.isTrusted || event.button !== 1 || !seekTarget(event.composedPath())) return;
      // 官方时间节点没有 href；可滚动页面上的中键默认会启动自动滚屏，吞掉 auxclick。
      // 先取消该默认动作，再由 auxclick 统一执行一次新进程精准空降。
      event.preventDefault();
      event.stopImmediatePropagation();
    }, { capture: true, passive: false });
    listen('click auxclick dblclick', onClick, { capture: true, passive: false });
    return { prepare, close:mediaMenu.close, destroy() {
      destroyed = true;
      mediaMenu.destroy();
      clearClick();
      for (const entry of shortLinks.values()) entry.cancel();
      shortLinks.clear();
      if (window.open === open) window.open = originalOpen;
    } };
  }
  const potPlayerClick = installPotPlayerClick();

  const attr = 'data-bilibili-video-comments';
  const html = document.documentElement;
  const previous = html.getAttribute(attr);
  function setScope(type = previous) {
    if (type === null) html.removeAttribute(attr);
    else html.setAttribute(attr, type);
  }
  // 所有普通 DOM 样式均受此属性约束；不修改原站主题设置。
  const ugc = `html[${attr}="ugc"]`;
  const pgc = `html[${attr}="pgc"]`;
  const scope = `:is(${ugc}, ${pgc})`;
  const sidebarAttr = 'data-bilibili-video-comments-sidebar';
  const recommendAttr = 'data-bilibili-video-comments-recommendations';
  const sidebar = `${scope} [${sidebarAttr}]`;
  // 弹幕列表、屏蔽设定和高级弹幕共用上层布局内的同一个官方容器。
  const panel = `${sidebar}[${sidebarAttr}="open"] #danmukuBox:has(.bui-collapse-wrap:not(.bui-collapse-wrap-folded))`;
  // 复用声明片段，保留每条规则的选择器、优先级和顺序。
  const pageSize = `
    width: 100% !important; min-width: 0 !important; max-width: none !important;
    margin: 0 !important; padding: 0 !important; box-sizing: border-box !important;
  `;
  const panelSize = (width, unit = '%') => `
    position: fixed !important; inset: 8px 8px auto auto !important;
    width: min(${width}px, calc(100${unit} - 16px)) !important;
    height: calc(100vh - 16px) !important; height: calc(100dvh - 16px) !important;
    min-width: 0 !important; min-height: 0 !important;
  `;
  const panelContent = `
    display: flex; flex-direction: column;
    width: 100% !important; height: 100% !important; min-width: 0 !important; min-height: 0 !important;
  `;
  const panelScroll = `
    flex: 1 1 auto !important; height: auto !important; min-width: 0 !important; min-height: 0 !important;
    overflow: auto !important; scrollbar-width: thin;
  `;
  const css = `
    ${scope} {
      min-width: 0 !important;
      scrollbar-width: thin !important;
      --bilibili-video-comments-content-inset: 60px !important;
      --bili-comments-font-size-title: 20px !important;
      --bili-comments-font-size-count: 13px !important;
      --bili-comments-font-size-sort: 13px !important;
      --bili-comments-font-size-name: 13px !important;
      --bili-comments-font-size-content: 16px !important;
      --bili-comments-line-height-content: 25px !important;
      --bili-comments-avatar-size: scale(0.83333333) !important;
    }
    /* 读取官方主题样式链接；href 切换时 CSS 自动更新，不覆盖页面配色。 */
    ${scope}:has(link#__css-map__[href*="/light.css"]) { color-scheme: light !important; }
    ${scope}:has(link#__css-map__[href*="/dark.css"]) { color-scheme: dark !important; }
    ${scope} body {
      /* 让实际可用宽度扣除竖向滚动条，不用固定最小宽度撑开页面。 */
      min-width: 0 !important; width: auto !important; margin: 0 !important;
    }
    ${scope} #danmukuBox .dm-info-time { pointer-events: auto !important; cursor: pointer; }
    ${scope} :is(#biliMainHeader, #bili-header-container, .bili-header,
      .bili-mini-header, .header-v3, .international-header,
      .float-nav, .fixed-sidenav, .footer, .special-cover) { display: none !important; }

    /* UGC：保留播放器壳和操作/评论节点，去掉两栏布局及额外信息。 */
    ${ugc} :is(#app, .video-container-v1, .video-container-v1 .left-container) { ${pageSize} }
    ${ugc} .video-container-v1 { display: flex !important; flex-direction: column !important; align-items: stretch !important; }
    /* 保留官方客服和返回顶部的显隐、动画及事件；底部跟随实际评论发送栏。 */
    ${ugc} .fixed-sidenav-storage {
      display: flex !important; flex-direction: column; gap: 6px;
      position: fixed !important; inset: auto 2px calc(var(--bilibili-video-comments-bottom-bar, 0px) + 2px) auto !important;
      width: 40px !important; height: auto !important;
      margin: 0 !important; padding: 0 !important; transform: none !important; z-index: 1000;
    }
    ${ugc} .fixed-sidenav-storage .mini-player-window { display: none !important; }
    ${ugc} .fixed-sidenav-storage :is(.customer-service, .back-to-top) { margin: 0 !important; }
    ${ugc} .video-container-v1 .right-container:not([${sidebarAttr}]) { display: none !important; }
    ${ugc} :is(.video-info-container,
      .video-ai-assistant,
      .left-container .ad-report, .left-container #slide_ad, .video-page-special-card-small) { display: none !important; }
    ${ugc} :is(.video-toolbar-container, .video-desc-container, .video-tag-container, #comment, #commentapp) {
      margin-left: 8px !important; margin-right: 8px !important;
      width: auto !important; min-width: 0 !important;
    }
    ${ugc} :is(.video-desc-container, .video-tag-container) {
      max-width: calc(100% - 16px) !important;
      box-sizing: border-box !important; overflow-wrap: anywhere;
    }
    ${ugc} .video-toolbar-container {
      display: flex !important; align-items: center; flex-wrap: wrap !important;
      height: auto !important; min-height: 40px; padding: 12px 0 !important; gap: 6px 12px;
    }
    ${ugc} :is(.video-toolbar-left, .video-toolbar-left-main) {
      display: flex !important; align-items: center; flex: 1 1 auto !important;
      width: auto !important; max-width: 100% !important; margin: 0 !important;
      min-width: 0 !important; height: auto !important; min-height: 0 !important;
      flex-wrap: wrap !important; gap: 6px 12px;
    }
    ${ugc} .video-toolbar-right {
      position: static !important; inset: auto !important; transform: none !important;
      display: flex !important; align-items: center; flex: 0 1 auto !important;
      width: auto !important; min-width: 0 !important; height: auto !important;
      max-width: 100% !important; min-height: 0 !important;
      margin-left: auto !important; flex-wrap: wrap !important; gap: 6px 8px;
    }
    ${ugc} :is(.video-toolbar-left, .video-toolbar-left-main, .video-toolbar-right) > * { flex: 0 0 auto !important; margin-right: 0 !important; }

    /* 整张分享卡片等比缩小，独立 scale / translate 保留官方 Popper 的 transform 定位。 */
    ${ugc} .video-share-popover {
      width: max-content !important; max-width: none !important;
      transform-origin: top left !important;
      scale: var(--bilibili-video-comments-share-scale, 1) !important;
      translate: var(--bilibili-video-comments-share-shift, 0px) 0 !important;
    }

    /* 举报保持原字号；弹窗和同源 iframe 一起适配可用宽高。 */
    ${scope} .bili-dialog-bomb:has(> .appeal-box) {
      width: min(600px, calc(100% - 16px)) !important;
      min-width: 0 !important; margin: 0 !important;
    }
    ${scope} .appeal-box:has(> iframe[name="appeal"]) {
      width: 100% !important;
      height: min(560px, calc(100vh - 16px)) !important;
      height: min(560px, calc(100dvh - 16px)) !important;
      min-width: 0 !important; min-height: 0 !important;
    }
    ${scope} .appeal-box > iframe[name="appeal"] {
      display: block; width: 100% !important; height: 100% !important; border: 0;
    }

    /* 音乐挂载节点关闭时为空；只给实际打开的官方面板设置窗口尺寸。 */
    ${ugc} #bgm-entry:empty { display: none !important; }
    ${ugc} #bgm-entry:has(> #musicApp.musicPcDetailPlayer) { ${panelSize(640)} box-sizing: border-box !important; margin: 0 !important; }
    ${ugc} #bgm-entry > #musicApp.musicPcDetailPlayer { ${panelContent} }
    ${ugc} #bgm-entry > #musicApp.musicPcDetailPlayer > .mainWarp { ${panelScroll} }

    /* 笔记不再依赖已压缩的播放器高度；显隐和关闭仍由官方控制。 */
    ${ugc} .note-pc {
      ${panelSize(640)}
      max-width: none !important; max-height: none !important;
      box-sizing: border-box !important; margin: 0 !important;
    }
    ${ugc} .note-pc .note-container { ${panelContent} box-sizing: border-box !important; }
    ${ugc} .note-pc .note-header { flex: 0 0 auto !important; }
    ${ugc} .note-pc .note-content { ${panelScroll} }

    /* PGC：解除播放器高度占位，信息区留在官方父容器内。 */
    ${pgc} :is(.home-container, .main-container, .plp-player, .plp-l) { ${pageSize} }
    ${pgc} .plp-layout { display: flex !important; flex-direction: column !important; align-items: stretch !important; }
    ${pgc} .plp-left-wrap {
      box-sizing: border-box !important; width: 100% !important;
      min-width: 0 !important; padding: 0 8px !important;
    }
    ${pgc} .plp-l { position: static !important; }
    ${pgc} .player-left-components { margin: 0 !important; }
    ${pgc} .plp-r-wrap:not([${sidebarAttr}]) { display: none !important; }
    ${pgc} :is([class*="navTools_floatNav"],
      [class*="operation_operation_module"]) { display: none !important; }
    ${pgc} .toolbar {
      height: auto !important; padding: 12px 0 !important;
      min-height: 40px; gap: 8px; flex-wrap: wrap;
    }
    ${pgc} .toolbar-left { display: flex; flex-wrap: wrap; gap: 8px 22px; min-width: 0; }
    ${pgc} .toolbar-left > span { margin: 0 !important; padding: 0 !important; }
    ${pgc} .toolbar-right { margin-left: auto; }
    /* 官方更多菜单挂在 body 的 portal 中；保留其垂直定位及事件。 */
    ${pgc} body > div:has(> [class*="moreTool_popupWrap"]) {
      left: auto !important; right: 8px !important;
      width: max-content !important; max-width: calc(100% - 16px) !important;
    }
    ${pgc} [class*="moreTool_popupWrap"] { min-width: 0 !important; max-width: 100% !important; }
    ${pgc} [class*="mediainfo_mediaRight"] { min-width: 0; }
    ${pgc} [class*="mediainfo_bottomBar"] { flex-wrap: wrap; gap: 8px; }
    ${pgc} #comment-module { padding-top: 18px !important; }

    /* 细条只占 18px；内容固定在视口上层，独立滚动，不挤动简介和评论。 */
    ${sidebar} {
      ${pageSize} display: block !important; order: -1 !important;
      position: sticky !important; inset: 0 auto auto !important; transform: none !important;
      height: 18px !important; min-height: 18px !important; z-index: 1001;
      flex: 0 0 auto !important; pointer-events: auto !important;
    }
    ${sidebar} > .bilibili-video-comments-sidebar-toggle {
      display: flex !important; align-items: center; justify-content: center;
      width: 100%; height: 18px; padding: 0; margin: 0; box-sizing: border-box;
      border: 1px solid var(--brand_blue, #00aeec);
      background: var(--bg2, #f1f2f3); color: var(--brand_blue, #00aeec); cursor: pointer;
    }
    ${sidebar}[${sidebarAttr}="closed"] > :not(.bilibili-video-comments-sidebar-toggle) { display: none !important; }
    ${sidebar}[${sidebarAttr}="open"] > :is(.right-container-inner, .plp-r) {
      ${pageSize} display: block !important; position: fixed !important;
      inset: 18px 0 auto !important; width: auto !important;
      height: auto !important; max-height: calc(100vh - 18px) !important;
      max-height: calc(100dvh - 18px) !important; padding: 8px !important;
      transform: none !important; overflow: auto !important;
      overscroll-behavior: contain; scrollbar-width: thin;
      background: var(--bg1, #fff); color: var(--text1, #18191c);
      border-bottom: 1px solid var(--line_regular, #e3e5e7);
      box-shadow: 0 8px 24px #0003;
    }
    ${sidebar} :is(.video-pod-above-modules, .video-pod-above-modules__inner, .rcmd-tab, .recommend-list-v1) {
      min-width: 0 !important; max-width: 100% !important; box-sizing: border-box !important;
    }
    ${scope} .bilibili-video-comments-recommend-toggle {
      display: flex; align-items: center; justify-content: space-between;
      width: 100%; height: 44px; padding: 0 16px; margin: 8px 0 0; box-sizing: border-box;
      border: 0; border-radius: 6px; background: var(--graph_bg_regular, var(--bg2, #f1f2f3));
      color: var(--text1, #18191c); font: inherit; font-size: 14px;
      text-align: left; cursor: pointer;
    }
    ${scope} :is(.bilibili-video-comments-sidebar-toggle, .bilibili-video-comments-recommend-toggle)::after {
      content: ''; width: 6px; height: 6px; border: solid currentColor; border-width: 0 1.5px 1.5px 0;
      transform: translateY(-2px) rotate(45deg); flex: 0 0 auto;
    }
    ${scope} :is(.bilibili-video-comments-sidebar-toggle, .bilibili-video-comments-recommend-toggle)[aria-expanded="true"]::after {
      transform: translateY(2px) rotate(225deg);
    }
    ${scope} :is(.bilibili-video-comments-sidebar-toggle, .bilibili-video-comments-recommend-toggle):focus-visible {
      outline: 2px solid var(--brand_blue, #00aeec); outline-offset: -2px;
    }
    ${scope} [${recommendAttr}="closed"] { display: none !important; }
    ${scope} [${recommendAttr}="closed"] ~ .rec-footer { display: none !important; }
    ${scope} [${recommendAttr}] {
      width: 100% !important; min-width: 0 !important; max-width: 100% !important;
      margin-top: 0 !important; box-sizing: border-box !important;
    }
    ${scope} [${recommendAttr}] > [class*="recommend_title"] { display: none !important; }

    /* 共用播放器：初始化已暂停一次，此处只压缩不可见画面。 */
    ${scope} :is(#playerWrap, #bilibili-player-wrap, #bilibili-player,
      .bpx-docker:not(.bpx-docker-minor), .bpx-player-container, .bpx-player-primary-area,
      [class*="video_playerInner"], [class*="NanoPlayer_nanoDocker"],
      [class*="NanoPlayer_nonoPlayerContainer"], [class*="NanoPlayer_nonoPlayerPrimaryArea"]) {
      box-sizing: border-box !important;
      width: 100% !important; min-width: 0 !important; max-width: 100% !important;
      height: auto !important; min-height: 0 !important; max-height: none !important;
      padding-top: 0 !important; padding-bottom: 0 !important;
      position: relative !important; inset: auto !important;
    }
    ${scope} :is(.bpx-player-video-area, [class*="NanoPlayer_nonoPlayerVideoArea"]) {
      flex: 0 0 0 !important; height: 0 !important; min-height: 0 !important;
      visibility: hidden !important; overflow: hidden !important;
    }
    /* 官方滚动逻辑会内联隐藏发送区；窄屏布局始终保留弹幕栏。 */
    ${scope} .bpx-player-sending-area { display: block !important; width: 100% !important; }
    /* 观看人数和弹幕设置铺满整行，发送输入区与显示开关不再占位。 */
    ${scope} :is(.bpx-player-sending-bar, [class*="NanoPlayer_nonoPlayerSendingBar__"]) {
      display: flex !important; width: 100% !important; min-width: 0 !important;
      box-sizing: border-box !important; height: auto !important; min-height: 46px;
      padding: 8px 12px !important; gap: 8px; flex-wrap: nowrap !important;
    }
    ${scope} :is(.bpx-player-sending-bar-left, [class*="NanoPlayer_nonoPlayerSendingBarLeft"]) {
      flex: 0 1 auto !important; width: auto !important; margin: 0 !important;
    }
    ${scope} :is(.bpx-player-sending-bar-right, [class*="NanoPlayer_nonoPlayerSendingBarRight"]) {
      flex: 1 1 0 !important; width: auto !important; min-width: 0 !important;
      height: auto !important;
    }
    /* 保留设置按钮，隐藏弹幕打开/关闭按钮。 */
    ${scope} :is(.bpx-player-video-inputbar, .bpx-player-dm-switch) { display: none !important; }
    ${scope} .bpx-player-sending-bar .bpx-player-video-info {
      flex: 1 1 0 !important; width: auto !important; min-width: 0 !important;
      margin: 0 !important; overflow: hidden; white-space: nowrap; text-overflow: ellipsis;
    }
    ${scope} .bpx-player-dm-root { flex: 0 0 auto !important; }
    ${scope} :is(.bpx-player-dm-root, .bpx-player-dm-wrap, .bpx-player-dm-input) { min-width: 0 !important; max-width: 100% !important; }
    /* 原弹幕浮层向上覆盖视频；改为锚定发送栏下方，显隐仍由官方控制。 */
    ${scope} .bpx-player-dm-setting { position: static !important; }
    ${scope} .bpx-player-dm-setting-wrap {
      inset: 100% auto auto 8px !important;
      width: min(320px, calc(100vw - 16px)) !important;
      height: min(366px, calc(100vh - 110px)) !important;
      height: min(366px, calc(100dvh - 110px)) !important;
    }
    ${scope} .bpx-player-dm-setting-box {
      /* 保留底部锚点，切换较矮的高级面板时鼠标仍在官方悬浮区域内。 */
      position: absolute !important; inset: auto auto 0 0 !important;
      box-sizing: border-box !important; width: 100% !important;
      max-height: calc(100vh - 110px) !important;
      max-height: calc(100dvh - 110px) !important;
      /* 高级设置在同一轨道横向滑入；保持原本的横向裁切，只允许纵向滚动。 */
      overflow-x: hidden !important; overflow-y: auto !important; scrollbar-width: thin;
    }

    /* 菜单切换始终在同一面板内，展开后约束高度，避免内容穿透到主页面。 */
    ${panel} {
      position: relative !important; inset: auto !important; margin: 0 !important;
      width: 100% !important; min-width: 0 !important;
      height: min(560px, calc(100vh - 58px)) !important;
      height: min(560px, calc(100dvh - 58px)) !important;
      box-sizing: border-box !important; overflow: hidden;
      background: var(--bg1, #fff); border-radius: 6px;
    }
    ${panel} :is(.danmaku-wrap, .bpx-docker-minor,
      .bpx-player-auxiliary, .bpx-player-collapse,
      .bpx-player-collapse > .bui-area, .bui-collapse-wrap) {
      display: flex !important; flex-direction: column;
      width: 100% !important; height: 100% !important; min-height: 0 !important;
    }
    ${panel} .bui-collapse-header { flex: 0 0 44px; height: 44px !important; }
    ${panel} .bui-collapse-body {
      flex: 1 1 auto; min-height: 0 !important; height: auto !important;
    }
    ${panel} .bpx-player-wraplist { height: 100% !important; min-height: 0 !important; }
    ${panel} .bpx-player-dm > :is(.bpx-player-dm-wrap, .bpx-player-dm-wrap-child) {
      /* 官方表头 32px、底栏 31px、间距 8px；仅修正列表视口高度。 */
      height: calc(100% - 71px) !important; min-height: 0 !important;
    }
    ${scope} bili-comments { display: block; width: 100%; min-width: 0; }
    /* 旧版普通 DOM 评论入口；新版组件由下方局部样式处理。 */
    ${scope} .bb-comment :is(.text, .reply-content) { overflow-wrap: anywhere; }
    ${scope} .bb-comment .info { display: flex; flex-wrap: wrap; gap: 4px 12px; }

    /* 官方图片组件带固定尺寸，外层缩小时同步缩放内部，完整保留封面。 */
    ${pgc} [class*="mediainfo_mediaCover"] :is(picture, img),
    ${pgc} [class*="mediainfo_mediaCover"] > * {
      display: block !important; width: 100% !important; height: 100% !important;
      object-fit: contain !important;
    }

    @media (max-width: 700px) {
      ${pgc} [class*="mediainfo_mediaCover"] {
        width: 112px !important; height: 150px !important; margin-right: 12px !important;
      }
      ${pgc} [class*="mediainfo_mediaToolbar"] {
        position: static !important; flex-wrap: wrap; gap: 6px;
        order: -1; margin-bottom: 10px;
      }
      ${pgc} [class*="mediainfo_mediaTitle"] { padding-right: 0 !important; }
      ${pgc} [class*="mediainfo_mediaDesc"] {
        font-size: 13px !important; height: auto !important; min-height: 18px;
      }
    }
  `;

  // 举报表单在同源 iframe 中；用实际列宽重排选项，不缩放文字或控件。
  const appealCSS = `
    html, body { width: 100%; height: 100%; min-width: 0 !important; margin: 0; overflow: hidden; }
    .web-app {
      display: flex !important; flex-direction: column;
      width: 100% !important; height: 100% !important; min-width: 0; min-height: 0;
      padding: 0 !important; box-sizing: border-box;
      --header-height: 48px !important;
    }
    .web-app > .header {
      position: relative !important; flex: 0 0 48px; height: 48px !important;
      width: 100% !important; padding: 0 clamp(12px, 3vw, 24px) !important; box-sizing: border-box;
    }
    .web-app > .body {
      flex: 1 1 auto; width: 100% !important; height: auto !important; min-height: 0;
      padding: 0 clamp(12px, 3vw, 24px) 12px !important; box-sizing: border-box;
      overflow: auto !important; overscroll-behavior: contain; scrollbar-width: thin;
    }
    .web-tags-section .tags-area {
      display: grid !important;
      grid-template-columns: repeat(auto-fit, minmax(min(170px, 100%), 1fr));
      gap: 4px 12px; margin-top: 8px !important;
    }
    .tags-area > .web-tag {
      width: auto !important; height: auto !important; min-width: 0;
      margin: 0 !important; padding: 8px 0 !important; align-items: flex-start;
    }
    .web-tag .text-info { min-width: 0; }
    .web-tag :is(.name, .extra) {
      white-space: normal !important; overflow-wrap: anywhere;
      overflow: visible !important; text-overflow: clip !important;
    }
    .tags-area > .tools { grid-column: 1 / -1; width: 100% !important; min-width: 0; box-sizing: border-box; }
    .tools :is(.tool-item, .web-textarea, .web-image-uploader) { min-width: 0; max-width: 100%; box-sizing: border-box; }
    .tools .tool-item { margin-top: 12px !important; }
    .tools textarea { width: 100% !important; min-width: 0; box-sizing: border-box; }
    .discipline-tips { padding: 12px 0 !important; }
    .discipline-tips .link { white-space: normal; overflow-wrap: anywhere; }
    .web-app > .footer {
      position: static !important; flex: 0 0 auto; width: 100% !important; height: auto !important;
      display: flex; flex-wrap: wrap; align-items: center; gap: 10px 12px;
      padding: 12px clamp(12px, 3vw, 24px) !important; box-sizing: border-box;
    }
    .footer .extra-actions { min-width: 0; flex: 1 1 160px; }
    .footer .extra-actions:empty { display: none; }
    .footer .operations { display: flex; flex: 0 0 auto; margin-left: auto; gap: 12px; }
    .footer .operation-btn { width: clamp(76px, 17vw, 100px) !important; margin: 0 !important; }
  `;

  // 仅补足公共 CSS 变量无法覆盖的窄屏规则；不强制展开官方隐藏节点。
  const commentInset = 'var(--bilibili-video-comments-content-inset)';
  const shadowCSS = {
    /* 头像左移 20px 后，所有原先 80px 的内容缩进统一减为 60px。 */
    'bili-comments': `
      #reply-commentbox bili-comment-box { padding-left: ${commentInset} !important; }
      #limit-mask-tip { margin-left: ${commentInset} !important; width: calc(100% - ${commentInset}) !important; }
    `,
    'bili-comment-renderer': `
      #user-avatar { left: 0 !important; }
      #body { padding-left: ${commentInset} !important; }
    `,
    'bili-comment-thread-renderer': `#div { margin-left: ${commentInset} !important; }`,
    'bili-comment-replies-renderer': `#expander { padding-left: ${commentInset} !important; }`,
    'bili-comments-header-renderer': `
      #vote { min-width: 0; max-width: 100%; }
      #disabled-commentbox #user-avatar { justify-content: flex-start !important; width: ${commentInset} !important; }
    `,
    'bili-comments-vote-card': `
      :host { display: block !important; min-width: 0 !important; max-width: 100% !important; }
      /* 与评论头部一起适配；宽度不足时信息和选项换行，不裁切投票内容。 */
      #card { height: auto !important; min-height: 80px; flex-wrap: wrap !important; gap: 12px 16px; }
      #info { flex: 1 1 160px !important; min-width: 0 !important; }
      #title span, .option-info { min-width: 0 !important; overflow-wrap: anywhere; }
      #desc { flex-wrap: wrap !important; }
      #duel {
        flex: 1 1 260px !important; width: auto !important; min-width: 0 !important;
        margin-left: 0 !important; height: auto !important; min-height: 40px;
      }
      #duel .option {
        box-sizing: border-box !important; min-width: 0 !important;
        height: auto !important; min-height: 40px; flex-shrink: 1 !important;
        /* 保留官方 --option-width，投票后的结果比例仍由组件控制。 */
      }
    `,
    'bili-comment-action-buttons-renderer': `
      :host { flex-wrap: wrap !important; gap: 2px 12px; }
      :host > * { margin-left: 0 !important; }
      #more { margin-left: auto !important; margin-right: 0 !important; }
    `,
    'bili-comment-box': `
      #user-avatar { justify-content: flex-start !important; width: ${commentInset} !important; }
      #comment-area { min-width: 0; width: calc(100% - ${commentInset}) !important; }
      #footer { flex-wrap: wrap; gap: 6px 0; }
    `,
    'bili-comment-user-info': `
      #info { flex-wrap: wrap; max-width: 100%; }
      #user-name { overflow-wrap: anywhere; min-width: 0; }
    `,
    'bili-comment-goods-card': ':host { min-width: 0 !important; max-width: 100% !important; }',
    'bili-user-profile': `
      :host {
        left: var(--bilibili-video-comments-profile-left, 8px) !important;
        top: var(--bilibili-video-comments-profile-top, 8px) !important;
        bottom: auto !important;
        max-width: calc(100% - 16px) !important;
        max-height: calc(100vh - 16px) !important;
        max-height: calc(100dvh - 16px) !important;
        overflow: auto; scrollbar-width: thin;
      }
      #bg { width: 100% !important; }
    `,
  };
  // 遍历这些开放组件边界，不修改 attachShadow 或官方组件原型。
  const tags = ['bili-comments-bottom-fixed-wrapper', 'bili-comment-reply-renderer', 'bili-rich-text',
    ...Object.keys(shadowCSS)];
  const selector = tags.join(',');
  const roots = new Map();
  const bottomBars = new Set();
  const bottomBarProperty = '--bilibili-video-comments-bottom-bar';
  const previousBottomBar = [html.style.getPropertyValue(bottomBarProperty), html.style.getPropertyPriority(bottomBarProperty)];
  const bottomBarObserver = new ResizeObserver(() => schedule());
  const bottomBarSelector = '.bili-comments-bottom-fixed-wrapper, bili-comments-bottom-fixed-wrapper';
  function watchBottomBar(bar) {
    if (!bottomBars.has(bar)) { bottomBars.add(bar); bottomBarObserver.observe(bar); }
  }
  function syncBottomBar(type) {
    for (const bar of bottomBars) if (!type || !bar.isConnected) {
      bottomBarObserver.unobserve(bar); bottomBars.delete(bar);
    }
    let height = 0;
    for (const bar of bottomBars) {
      observer.observe(bar, { attributes: true, attributeFilter: ['style', 'class'] });
      const rect = bar.getBoundingClientRect(), css = getComputedStyle(bar);
      if (css.position === 'fixed' && css.visibility !== 'hidden' && css.opacity !== '0'
        && rect.width && rect.height && rect.bottom > 0 && rect.top < window.innerHeight)
        height = Math.max(height, window.innerHeight - rect.top);
    }
    if (type) {
      const value = `${height}px`;
      if (html.style.getPropertyValue(bottomBarProperty) !== value) html.style.setProperty(bottomBarProperty, value);
    } else if (previousBottomBar[0]) html.style.setProperty(bottomBarProperty, ...previousBottomBar);
    else html.style.removeProperty(bottomBarProperty);
  }
  const profileProperties = ['--bilibili-video-comments-profile-left', '--bilibili-video-comments-profile-top'];
  function observe(root) {
    observer.observe(root, { childList: true, subtree: true, attributes:true, attributeFilter:['href'] });
    if (root.host?.localName === 'bili-user-profile')
      observer.observe(root.host, { attributes: true, attributeFilter: ['style'] });
  }
  function removeRoot(root) {
    const { style, position } = roots.get(root);
    style?.remove();
    position?.forEach(([value, priority], i) => {
      const key = profileProperties[i];
      if (value) root.host.style.setProperty(key, value, priority);
      else root.host.style.removeProperty(key);
    });
    roots.delete(root);
  }
  function fitProfile(host) {
    const { width, height } = host.getBoundingClientRect();
    if (!width || !height) return;
    const left = parseFloat(host.style.left) || 0;
    const top = host.style.top ? parseFloat(host.style.top)
      : window.innerHeight - (parseFloat(host.style.bottom) || 0) - height;
    const clamp = (value, size, limit) => Math.max(8, Math.min(value, limit - size - 8));
    const positions = [clamp(left, width, html.clientWidth), clamp(top, height, window.innerHeight)];
    positions.forEach((value, i) => {
      const key = profileProperties[i], next = `${value}px`;
      if (host.style.getPropertyValue(key) !== next) host.style.setProperty(key, next);
    });
  }
  const style = addStyle(html, css);
  style.dataset.bilibiliVideoCommentsStyle = '';
  let stopped = false;
  let frame = 0;
  let resizeFrame = 0;
  let scanAll = true, pruneRoots = false, scannedRoute = '';
  const dirtyScopes = new Set(), dirtyProfiles = new Set(), damagedStyles = new Set();
  let responsiveRoute = '';
  const responsiveTargets = new Map();
  const appealFrames = new Map();
  function syncAppealFrames(type) {
    const frames = new Set(type ? document.querySelectorAll('.appeal-box > iframe[name="appeal"]') : []);
    for (const [iframe, state] of appealFrames) {
      if (frames.has(iframe)) continue;
      iframe.removeEventListener('load', state.load);
      state.style?.remove();
      appealFrames.delete(iframe);
    }
    for (const iframe of frames) {
      if (!appealFrames.has(iframe)) {
        const state = { style: null, load() {
          let doc;
          try { doc = iframe.contentDocument; } catch { return; }
          if (!doc?.head) return;
          if (state.style?.ownerDocument !== doc) {
            state.style?.remove();
            state.style = addStyle(doc.head, appealCSS);
          } else if (!state.style.isConnected) doc.head.append(state.style);
        } };
        appealFrames.set(iframe, state);
        iframe.addEventListener('load', state.load);
      }
      appealFrames.get(iframe).load();
    }
  }
  const sharePanels = new Map();
  const shareProperties = ['--bilibili-video-comments-share-scale', '--bilibili-video-comments-share-shift'];
  function syncSharePanels(type) {
    const panels = new Set(type === 'ugc' ? document.querySelectorAll('.video-share-popover') : []);
    for (const [panel, values] of sharePanels) {
      if (panels.has(panel)) continue;
      values.forEach(([value, priority], i) => {
        if (value) panel.style.setProperty(shareProperties[i], value, priority);
        else panel.style.removeProperty(shareProperties[i]);
      });
      sharePanels.delete(panel);
    }
    for (const panel of panels) {
      if (!sharePanels.has(panel)) sharePanels.set(panel, shareProperties.map(key =>
        [panel.style.getPropertyValue(key), panel.style.getPropertyPriority(key)]));
      // 官方显隐和 Popper 定位变化后再适配；重复写入相同值会引发无效的观察回调。
      observer.observe(panel, { attributes: true, attributeFilter: ['style', 'class'] });
      const width = parseFloat(getComputedStyle(panel).width);
      if (!panel.getClientRects().length || !width) continue;
      const available = Math.max(1, html.clientWidth - 16);
      const scale = String(Math.min(1, available / width));
      if (panel.style.getPropertyValue(shareProperties[0]) !== scale)
        panel.style.setProperty(shareProperties[0], scale);
      const rect = panel.getBoundingClientRect();
      const shift = parseFloat(panel.style.getPropertyValue(shareProperties[1])) || 0;
      const left = Math.max(8, Math.min(rect.left - shift, html.clientWidth - rect.width - 8));
      if (Math.abs(left - rect.left) > 0.1)
        panel.style.setProperty(shareProperties[1], `${shift + left - rect.left}px`);
    }
  }
  let shortcutPlayer = null;
  let restorePlayerShortcuts = () => {};
  function syncPlayerShortcuts(type) {
    const player = type && typeof window.player?.toggleFeature === 'function' ? window.player : null;
    if (player === shortcutPlayer) return;
    previousShortcuts = { ...previousShortcuts, ...restorePlayerShortcuts() };
    shortcutPlayer = player;
    restorePlayerShortcuts = () => {};
    if (!player) return;
    const toggle = player.toggleFeature;
    let officialShortcut = previousShortcuts.player === player ? previousShortcuts.shortcut : false;
    function guardedToggle(features) {
      if (features && Object.prototype.hasOwnProperty.call(features, 'shortcut')) officialShortcut = features.shortcut;
      return toggle.call(this, pageType() ? { ...features, shortcut: true } : features);
    }
    // 官方总开关：覆盖所有播放器快捷键；保留官方对其他功能的设置。
    player.toggleFeature = guardedToggle;
    toggle.call(player, { shortcut: true });
    restorePlayerShortcuts = () => {
      if (player.toggleFeature !== guardedToggle) return;
      player.toggleFeature = toggle;
      toggle.call(player, { shortcut: officialShortcut });
      return { player, shortcut: officialShortcut };
    };
  }
  function disableMediaShortcuts() {
    const session = window.navigator?.mediaSession;
    if (typeof session?.setActionHandler !== 'function') return () => {};
    const set = session.setActionHandler;
    const handlers = new Map(previousShortcuts.session === session ? previousShortcuts.handlers : []);
    const actions = ['play', 'pause', 'stop', 'seekbackward', 'seekforward', 'seekto', 'previoustrack', 'nexttrack'];
    function guardedSet(action, handler) {
      if (!actions.includes(action)) return set.call(this, action, handler);
      handlers.set(action, handler);
      return set.call(this, action, details => { if (!pageType()) handler?.(details); });
    }
    // 媒体键可能绕过 DOM 键盘事件，需同时屏蔽浏览器媒体控制通道。
    for (const action of actions) {
      try { guardedSet.call(session, action, handlers.get(action) || null); } catch { /* 浏览器可能不支持该媒体动作。 */ }
    }
    session.setActionHandler = guardedSet;
    return () => {
      if (session.setActionHandler !== guardedSet) return;
      session.setActionHandler = set;
      for (const [action, handler] of handlers) {
        try { set.call(session, action, handler); } catch { /* 同上。 */ }
      }
      return { session, handlers };
    };
  }
  let restoreMediaShortcuts = null;
  function onMediaKey(event) {
    if (!pageType() || !/^(?:Media|AudioVolume)/.test(event.key)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
  }
  function onDanmakuPanelClick(event) {
    if (!pageType() || (typeof event.button === 'number' && event.button !== 0)) return;
    if (!event.composedPath().some(node => node.matches?.('.bpx-player-dm-setting-left-block-add'))) return;
    const panel = document.querySelector('#danmukuBox');
    const side = panel?.closest(`[${sidebarAttr}]`), state = sidebarPanels.get(side);
    if (!state) return;
    setLayoutOpen(side, state, true);
    // 后续官方处理器仍负责选择屏蔽设定；不再把同一节点改成另一个浮窗。
    const content = side.querySelector('.right-container-inner, .plp-r');
    if (content) content.scrollTop = 0;
    notifyOfficialResize();
  }
  function notifyOfficialResize() {
    if (stopped || resizeFrame) return;
    // 等 CSS 布局完成，再让官方按新的容器宽度计算按钮与标签。
    resizeFrame = requestAnimationFrame(() => {
      resizeFrame = 0;
      if (!stopped) window.dispatchEvent(new Event('resize'));
    });
  }
  const sidebarPanels = new Map(), recommendationPanels = new Map();
  let layoutRoute = '', layoutId = 0;
  function setLayoutOpen(node, state, open) {
    node.setAttribute(state.attr, open ? 'open' : 'closed');
    state.button.setAttribute('aria-expanded', String(open));
    if (state.attr === sidebarAttr) {
      state.button.setAttribute('aria-label', open ? '收起视频侧栏' : '展开视频侧栏');
      state.button.title = open ? '收起视频侧栏' : '展开视频侧栏';
    }
  }
  function removeLayoutPanel(node, state) {
    state.button.removeEventListener('click', state.click);
    state.button.remove();
    node.removeAttribute(state.attr);
    if (state.id === null) node.removeAttribute('id');
    else if (state.id === '') node.id = '';
  }
  function syncSidebarLayout(type) {
    const route = type ? location.pathname + (location.search || '') : '';
    const routeChanged = layoutRoute !== route;
    layoutRoute = route;
    const sides = new Set(type ? document.querySelectorAll(type === 'ugc'
      ? '.video-container-v1 .right-container' : '.plp-layout .plp-r-wrap') : []);
    const recommendations = new Set();
    for (const side of sides) for (const node of side.querySelectorAll(type === 'ugc'
      ? '.rec-list' : '[class*="recommend_wrap"]')) recommendations.add(node);
    for (const [panels, nodes, key] of [[sidebarPanels, sides, sidebarAttr],
      [recommendationPanels, recommendations, recommendAttr]]) {
      for (const [node, state] of panels) {
        if (nodes.has(node)) continue;
        removeLayoutPanel(node, state);
        panels.delete(node);
      }
      for (const node of nodes) {
        let state = panels.get(node);
        if (!state) {
          const button = document.createElement('button');
          button.type = 'button';
          button.className = key === sidebarAttr ? 'bilibili-video-comments-sidebar-toggle'
            : 'bilibili-video-comments-recommend-toggle';
          if (key === recommendAttr) button.textContent = '相关推荐';
          state = { button, attr:key, id:node.getAttribute('id'), click() {
            setLayoutOpen(node, state, node.getAttribute(key) !== 'open');
            notifyOfficialResize();
          } };
          if (!node.id) node.id = `bilibili-video-comments-layout-${++layoutId}`;
          button.setAttribute('aria-controls', node.id);
          button.addEventListener('click', state.click);
          panels.set(node, state);
          setLayoutOpen(node, state, false);
        } else if (routeChanged) setLayoutOpen(node, state, false);
        // 官方异步重绘可能移除注入按钮；仅恢复按钮，不移动官方节点。
        if (key === sidebarAttr) {
          if (node.firstChild !== state.button) node.prepend(state.button);
        } else if (node.previousSibling !== state.button) node.before(state.button);
      }
    }
  }
  function dismissSidebar(event) {
    if (event.type === 'keydown' && event.key !== 'Escape') return;
    const path = event.type === 'click' ? event.composedPath() : [];
    for (const [side, state] of sidebarPanels) {
      if (side.getAttribute(sidebarAttr) !== 'open' || path.includes(side)
        || path.some(node => node.matches?.('.bpx-player-dm-setting'))) continue;
      setLayoutOpen(side, state, false);
    }
  }
  const sizeObserver = new ResizeObserver(entries => {
    for (const { target, contentRect } of entries) {
      if (responsiveTargets.has(target) && responsiveTargets.get(target) !== contentRect.width) {
        responsiveTargets.set(target, contentRect.width);
        notifyOfficialResize();
      }
    }
  });
  function syncResponsiveLayout(type) {
    const targets = new Set(type === 'ugc'
      ? document.querySelectorAll('.video-toolbar-container, .video-tag-container') : []);
    let added = false;
    for (const target of responsiveTargets.keys()) {
      if (!targets.has(target)) {
        sizeObserver.unobserve(target);
        responsiveTargets.delete(target);
      }
    }
    for (const target of targets) {
      if (!responsiveTargets.has(target)) {
        responsiveTargets.set(target, null);
        sizeObserver.observe(target);
        added = true;
      }
    }
    const route = type === 'ugc' ? location.pathname + (location.search || '') : '';
    if (responsiveRoute !== route) {
      responsiveRoute = route;
      if (targets.size && !added) notifyOfficialResize();
    }
  }

  // 弹幕长列表由官方管理，内部更新不需要重新遍历评论组件。
  const observer = new MutationObserver(records => {
    let changed = false;
    for (const {type, target, addedNodes, removedNodes} of records) {
      if (target.closest?.('#danmukuBox')) continue;
      changed = true;
      if (type === 'attributes') {
        if (target.localName === 'bili-user-profile') dirtyProfiles.add(target);
        if (target.matches?.('a[href]')) dirtyScopes.add(target);
        continue;
      }
      if ([...removedNodes].some(node => node.nodeType === 1 && node.localName !== 'style')) pruneRoots = true;
      const localStyle = roots.get(target)?.style;
      if (localStyle && localStyle.parentNode !== target) damagedStyles.add(target);
      for (const node of addedNodes) if (node.nodeType === 1 && node.localName !== 'style') dirtyScopes.add(node);
    }
    if (changed) schedule();
  });
  function schedule() {
    if (!stopped && !frame) frame = requestAnimationFrame(sync);
  }
  function visit(root, inComments = false) {
    inComments ||= root.host?.localName === 'bili-comments';
    if (root.matches?.(bottomBarSelector)) watchBottomBar(root);
    if (root === document || root.host?.localName === 'bili-comments-header-renderer'
      || root.getRootNode?.().host?.localName === 'bili-comments-header-renderer')
      for (const bar of root.querySelectorAll(bottomBarSelector)) watchBottomBar(bar);
    if (root === document || inComments || root.closest?.(playbackScope)) potPlayerClick.prepare(root);
    const hosts = [...(root.matches?.(selector) ? [root] : []), ...root.querySelectorAll(selector)];
    for (const host of hosts) {
      const shadow = host.shadowRoot;
      if (!shadow) continue;
      if (!roots.has(shadow)) {
        roots.set(shadow, {
          style: shadowCSS[host.localName] ? addStyle(shadow, shadowCSS[host.localName]) : null,
          position: host.localName === 'bili-user-profile'
            ? profileProperties.map(key => [host.style.getPropertyValue(key), host.style.getPropertyPriority(key)]) : null,
        });
        observe(shadow);
      }
      const localStyle = roots.get(shadow).style;
      if (localStyle && localStyle.parentNode !== shadow) shadow.append(localStyle);
      visit(shadow, inComments);
      if (host.localName === 'bili-user-profile') fitProfile(host);
    }
  }
  function sync() {
    frame = 0;
    if (stopped) return;
    const type = pageType();
    if (scannedRoute !== location.href) { scannedRoute = location.href; scanAll = true; pruneRoots = true; }
    if (!type) potPlayerClick.close();
    syncPlayerShortcuts(type);
    if (type && !restoreMediaShortcuts) restoreMediaShortcuts = disableMediaShortcuts();
    else if (!type && restoreMediaShortcuts) {
      previousShortcuts = { ...previousShortcuts, ...restoreMediaShortcuts() };
      restoreMediaShortcuts = null;
    }
    setScope(type || previous);
    syncSidebarLayout(type);
    const detached = pruneRoots || !type ? [...roots.keys()].filter(root => !type || !root.host.isConnected) : [];
    pruneRoots = false;
    detached.forEach(removeRoot);
    if (detached.length) {
      observer.disconnect();
      observe(html);
      for (const root of roots.keys()) observe(root);
    }
    if (type) {
      if (scanAll) visit(document);
      else {
        for (const scope of dirtyScopes) {
          if (!scope.isConnected) continue;
          // A newly inserted subtree may already live inside a comment shadow root.
          let parent = scope, inComments = false;
          while (parent) {
            if (parent.localName === 'bili-comments') { inComments = true; break; }
            parent = parent.getRootNode?.().host;
          }
          let ancestor = scope.parentNode;
          while (ancestor && !dirtyScopes.has(ancestor)) ancestor = ancestor.parentNode;
          if (!ancestor) visit(scope, inComments);
        }
      }
      for (const root of damagedStyles) {
        const localStyle = roots.get(root)?.style;
        if (root.host.isConnected && localStyle && localStyle.parentNode !== root) root.append(localStyle);
      }
      for (const host of dirtyProfiles) if (host.isConnected) fitProfile(host);
    }
    scanAll = false; dirtyScopes.clear(); dirtyProfiles.clear(); damagedStyles.clear();
    syncAppealFrames(type);
    syncSharePanels(type);
    syncResponsiveLayout(type);
    syncBottomBar(type);
  }
  observe(html);
  listen('popstate', () => { scanAll = true; pruneRoots = true; schedule(); });
  listen('resize', () => {
    for (const root of roots.keys()) if (root.host.localName === 'bili-user-profile') dirtyProfiles.add(root.host);
    schedule();
  });
  listen('click', onDanmakuPanelClick, { capture: true });
  listen('click keydown', dismissSidebar, { capture: true });
  listen('keydown keyup', onMediaKey, { capture: true, passive: false });
  // 已在 DOM 中但还未升级的组件，定义完成后再检查，不使用轮询。
  for (const tag of tags) customElements.whenDefined(tag).then(() => { if (!stopped) { scanAll = true; schedule(); } });
  const controller = {
    destroy() {
      avatarNavigation.destroy();
      if (stopped) return;
      stopped = true;
      const shortcuts = { ...restorePlayerShortcuts(), ...restoreMediaShortcuts?.() };
      potPlayerClick.destroy();
      cancelAnimationFrame(frame);
      cancelAnimationFrame(resizeFrame);
      sizeObserver.disconnect();
      bottomBarObserver.disconnect();
      responsiveTargets.clear();
      observer.disconnect();
      dirtyScopes.clear(); dirtyProfiles.clear(); damagedStyles.clear();
      syncSidebarLayout('');
      syncAppealFrames('');
      syncSharePanels('');
      syncBottomBar('');
      for (const dispose of disposers) dispose();
      for (const root of roots.keys()) removeRoot(root);
      style.remove();
      setScope();
      if (window.bilibiliVideoComments === controller) delete window.bilibiliVideoComments;
      return shortcuts;
    },
  };
  window.bilibiliVideoComments = controller;
  sync();
  }
})();
