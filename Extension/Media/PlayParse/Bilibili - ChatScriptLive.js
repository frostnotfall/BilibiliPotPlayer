// 版本：1.1.30

(() => {
  'use strict';
  // 与 BroadcastListScript 一样由 WebView2 在文档创建时注入；子框架不安装聊天布局。
  if (window !== window.top) return;
  window.__bilibiliLiveChatStartup?.abort();
  const startup = new AbortController();
  window.__bilibiliLiveChatStartup = startup;
  function start() {
    startup.abort();
    if (window.__bilibiliLiveChatStartup === startup) delete window.__bilibiliLiveChatStartup;
    mount();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once:true, signal:startup.signal });
  else start();

  function mount() {
  if (location.hostname !== 'live.bilibili.com' || !/^\/(?:blanc\/)?\d+\/?$/.test(location.pathname)) return;
  window.bilibiliLiveChat?.destroy();
  // 宽窗口保留原站布局；窄窗口才接管聊天区、侧栏及浮层。
  const narrowLayout = matchMedia('(width < 1000px)');

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
  function createMediaMenu({getTarget, openPage, play, openNew, openExternal, addNext, addLast, idPrefix = 'bilibili-vod'}) {
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
      dialogHost = document.createElement('div'); dialogHost.id = idPrefix + '-external-dialog';
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
      host = document.createElement('div'); host.id = idPrefix + '-media-menu';
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

  function createAnchorNavigation() {
    const events = new AbortController();
    const webview = window.chrome?.webview;
    const originalOpen = window.open;
    const modified = event => event.ctrlKey || event.metaKey || event.shiftKey || event.altKey;
    function target(event) {
      const button = event.target instanceof Element ? event.target.closest('.anchor-info-card .anchor-btn') : null;
      if (!button?.closest('#interactive-play-vm')) return null;
      const label = button.textContent.replace(/\s/g, '').toLowerCase();
      if (!['去ta直播间', '去ta空间'].includes(label)) return null;
      const card = button.closest('.anchor-info-card');
      // 官方按钮没有 href；读取当前卡片的 props，避免模拟点击或请求关注接口。
      const info = card.__vue__?.anchorCardInfo || card.__vue__?.$props?.anchorCardInfo
        || card.__vueParentComponent?.props?.anchorCardInfo;
      const room = label === '去ta直播间';
      const id = String((room ? info?.room_id : info?.uid) ?? '');
      let url = /^\d+$/.test(id) && /[1-9]/.test(id)
        ? `https://${room ? 'live' : 'space'}.bilibili.com/${id}${room ? '' : '/'}` : null;
      if (!url) {
        const link = button.matches('a[href]') ? button : button.querySelector('a[href]');
        const parsed = urlOf(link?.href);
        if (parsed?.hostname === `${room ? 'live' : 'space'}.bilibili.com` && /^\/\d+\/?$/.test(parsed.pathname)) url = parsed.href;
      }
      return url ? {anchor:button, url, kind:room ? 'media' : 'page', playlist:!room} : null;
    }
    function command({url}, action) {
      const uri = playerCommandUri(url, action);
      if (uri) Reflect.apply(originalOpen, window, [uri, '_blank']);
    }
    function play(value) {
      if (typeof webview?.postMessage === 'function') webview.postMessage({type:'potPlayer.video-click', url:value.url});
      else command(value, 'current');
    }
    const menu = createMediaMenu({
      getTarget:target, idPrefix:'bilibili-live', play,
      openPage:({url}) => location.assign(url),
      openNew:value => command(value, 'new'),
      addNext:value => command(value, 'insert'), addLast:value => command(value, 'add'),
      openExternal:({url}) => Reflect.apply(originalOpen, window, [url, '_blank', 'noopener']),
    });
    window.addEventListener('mousedown', event => {
      if (event.isTrusted && event.button === 1 && !modified(event) && target(event)) {
        event.preventDefault(); event.stopImmediatePropagation();
      }
    }, {capture:true, passive:false, signal:events.signal});
    function click(event) {
      if (!event.isTrusted || event.defaultPrevented || modified(event)
        || !(event.type === 'click' && event.button === 0 || event.type === 'auxclick' && event.button === 1)) return;
      const value = target(event);
      if (!value) return;
      event.preventDefault(); event.stopImmediatePropagation(); menu.close();
      if (event.button === 1) command(value, 'new');
      else if (value.kind === 'media') play(value);
      else location.assign(value.url);
    }
    for (const type of ['click', 'auxclick']) window.addEventListener(type, click, {capture:true, passive:false, signal:events.signal});
    return {destroy() { events.abort(); menu.destroy(); }};
  }
  const anchorNavigation = createAnchorNavigation();

  function createPkPlayback() {
    // 判断组件是否挂载，不看可被用户收起的彩色条；惩罚阶段也保持播放。
    const pkModules = [
      '#universal-pk-vm .universal-pk-bar-box', '#universal-pk-vm .multi-play-pk-box',
      '#universal-pk-vm .universal-pk-relay-pk', '#universal-pk-vm .universal-pk-chat-room-six-vs-six-pk',
      '#awesome-pk-vm.awesome-pk-box-show', '#pk-vm .pk-progress-bar',
    ].join(',');
    const attempts = new WeakMap(), mutedVideos = new Map();
    let state = 'idle', settlingAt = 0, stopped = false;

    function documents(doc = document, result = []) {
      result.push(doc);
      for (const iframe of doc.querySelectorAll('iframe')) {
        try { if (iframe.contentDocument) documents(iframe.contentDocument, result); } catch {}
      }
      return result;
    }
    function pause(video, player) {
      if (video.paused) return;
      // 原生 video.pause() 不会启动官方播放器的停流流程。
      try { if (player?.getVideoEl?.() === video) player.pause(); } catch {}
      if (!video.paused) video.pause();
    }
    function update() {
      if (stopped) return;
      if (!narrowLayout.matches) {
        for (const [video, muted] of mutedVideos) video.muted = muted;
        mutedVideos.clear(); state = 'idle';
        return;
      }
      const docs = documents(), now = Date.now();
      const cards = docs.flatMap(doc => [...doc.querySelectorAll('.anchor-overlay-card')]);
      const active = docs.some(doc => doc.querySelector(pkModules)) ||
        cards.some(el => Number(el.getAttribute('data-ispking')) > 0);
      if (active) {
        state = 'pk';
      } else if (cards.length) {
        // PK 结束后可能继续连麦；保持播放，直到官方移除信息卡。
        state = 'linked';
      } else if (state === 'pk' || state === 'linked') {
        state = 'settling'; settlingAt = now;
      } else if (state === 'settling' && now - settlingAt >= 500) {
        state = 'idle';
      }
      for (const doc of docs) {
        // 只控制直播视频，避免暂停 PK 动画和礼物特效中的 MP4。
        for (const video of doc.querySelectorAll('#live-player > video')) {
          let player;
          try {
            const api = doc.defaultView?.EmbedPlayer?.instance || doc.defaultView?.$P2PLivePlayer;
            if (api?.getVideoEl?.() === video) player = api;
          } catch {}
          // 暂停到官方停流之间也要追缓冲，防止提前排入迟到的 SEI 更新。
          try {
            const ranges = video.buffered, index = ranges.length - 1;
            if (!video.seeking && index >= 0 && ranges.end(index) - video.currentTime > 5) {
              video.currentTime = Math.max(ranges.start(index), ranges.end(index) - 2);
            }
          } catch {}
          if (state === 'idle') {
            pause(video, player);
          } else {
            if (!mutedVideos.has(video)) mutedVideos.set(video, video.muted);
            video.muted = true;
            const attempt = attempts.get(video);
            if (!video.paused || attempt?.pending || (attempt && now - attempt.at < 2000)) continue;
            const next = { at: now, pending: true };
            attempts.set(video, next);
            try { Promise.resolve(player?.play()).catch(() => {}); } catch {}
            video.play().then(() => {
              if (!stopped && narrowLayout.matches && state === 'idle') pause(video, player);
            }).catch(() => {}).finally(() => { next.pending = false; });
          }
        }
      }
    }
    const timer = setInterval(update, 500);
    update();
    return {
      get state() { return state; },
      refresh: update,
      destroy() {
        stopped = true; clearInterval(timer);
        for (const [video, muted] of mutedVideos) video.muted = muted;
        mutedVideos.clear();
      },
    };
  }
  const playback = createPkPlayback();

  // 原生 PK 贡献榜直接挂在播放器下，不在业务注入层中。
  const pkRankFrame = '#live-player > iframe[src*="app_name=ranks_pro"]';
  const toolbarPopups = '.common-popup-wrap:is(.danmakuPreference,.effectBlock,.blockSetting)';
  // 页面升级时，只需在这里补充新的弹出层根选择器。
  const popups = [
    pkRankFrame,
    '.common-popup-wrap', '.gift-sender-panel', '.gift-panel-box',
    '.danmaku-menu', '.fansmedal-popover-wrap', '.blive-tooltip', '.anchor-info-card',
    '#head-info-vm .more-panel', '#head-info-vm .room-manage-panel',
    '#head-info-vm .head-share-qr-popover', '#game-id',
    '#sidebar-vm .side-bar-popup-cntr',
    '.recharge-store-box > .cntr',
    '[role="dialog"]', '[role="tooltip"]',
  ].join(',');

  // 不移动或克隆 Vue 节点；保留父容器尺寸，供原生面板和播放器测量。
  const style = document.createElement('style');
  style.id = 'bilibili-live-chat-style';
  style.textContent = `
    @media (width < 1000px) {
    html[data-bilibili-live-chat] {
      min-width: 0 !important; height: 100% !important; overflow: hidden !important;
      & body {
        margin: 0 !important; min-width: 0 !important; height: 100% !important;
        overflow: hidden !important;
      }
      & .live-room-app, & .app-content, & .app-body {
        width: 100% !important; height: 100% !important;
        min-width: 0 !important; min-height: 0 !important;
        margin: 0 !important; padding: 0 !important;
        transform: none !important; overflow: visible !important;
      }
      & .link-navbar-ctnr, & #room-background-vm, & #sections-vm,
      & .link-footer,
      & .aside-area-toggle-btn, & #toogle-right-btn { display: none !important; }

      & #sidebar-vm {
        display: block !important; position: fixed !important; inset: 0 !important;
        width: auto !important; height: auto !important; contain: none !important;
        pointer-events: none !important; overflow: visible !important; z-index: 1000 !important;
      }
      & #sidebar-vm .side-bar-popup-cntr { pointer-events: auto; }
      & .side-bar-cntr[data-blc-sidebar-panel] {
        display: block !important; position: fixed !important; top: 50dvh !important;
        left: auto !important; right: 0 !important; bottom: auto !important;
        box-sizing: content-box !important; transform: translateY(-50%) !important;
        clip-path: inset(-100vmax 0 -100vmax -100vmax);
        /* 关闭原生高度过渡；仅在点击时临时播放横向揭示动画。 */
        transition: none !important;
        pointer-events: auto !important;
        &.collapsed {
          width: 0 !important; height: 40px !important; padding: 0 !important;
          border: 0 !important; background: transparent !important; box-shadow: none !important;
          & > * { display: none !important; }
        }
      }
      & .blc-sidebar-toggle {
        position: fixed; right: 0; top: 50dvh; transform: translateY(-50%);
        clip-path: inset(-100vmax 0 -100vmax -100vmax);
        width: 16px; height: 40px; padding: 0; box-sizing: border-box; margin: 0;
        border: 1px solid var(--Ga2); border-right: 0; border-radius: 6px 0 0 6px;
        background: var(--bg1_float); color: var(--text2); font: bold 20px/38px sans-serif;
        box-shadow: 0 1px 4px #0006; cursor: pointer; user-select: none;
        pointer-events: auto; z-index: 1001;
      }

      & .player-and-aside-area {
        position: fixed !important; inset: 0 !important;
        display: block !important; pointer-events: none;
        width: 100% !important;
        height: 100dvh !important;
        min-width: 0 !important; margin: 0 !important;
        padding: 0 !important; gap: 0 !important;
        overflow: visible !important;
      }
      & #player-ctnr {
        position: absolute !important; inset: 0 !important;
        width: 100% !important; height: 100% !important;
        z-index: auto !important; pointer-events: none;
      }
      & .fullscreen-container-paddingbox {
        position: absolute !important;
        inset: var(--blc-head-height, 60px) 0 0 !important;
        width: 100% !important; height: auto !important; padding: 0 !important;
      }
      & #fullscreen-container {
        display: block !important; position: absolute !important; inset: 0 !important;
        width: 100% !important; height: 100% !important;
        background: transparent !important; overflow: visible !important;
      }
      /* 新版“更多礼物”使用 container-tool 抽屉，必须保留并覆盖在聊天区上。 */
      & #fullscreen-container > .container-tool-paddingbox {
        display: none !important; position: absolute !important;
        inset: auto 0 var(--blc-gift-height, 84px) auto !important;
        width: min(376px, 100%) !important;
        height: min(520px, calc(100% - var(--blc-gift-height, 84px))) !important;
        padding: 0 !important; overflow: visible !important;
        pointer-events: none !important; z-index: 50 !important;
      }
      & #fullscreen-container.tool-open > .container-tool-paddingbox {
        display: block !important;
      }
      & #fullscreen-container #container-tool {
        width: 100% !important; height: 100% !important;
        transform: none !important; overflow: visible !important;
        pointer-events: none !important;
      }
      & #container-tool > * { pointer-events: auto !important; }
      & #container-tool .gift-row { flex-wrap: wrap; flex-shrink: 0; }
      & #container-tool .more-gifts-panel-tabs > .tabs-section { flex: 1; min-width: 0; }
      & #container-tool .more-gifts-panel-tabs > .right-section { flex: 0 0 auto; }
      & #player-ctnr > :not(#head-info-vm):not(.fullscreen-container-paddingbox) {
        position: absolute !important; top: 0; left: 0;
      }
      /* 小橙车提示卡需要接收点击，并位于聊天区上方；保留官方关闭事件。 */
      & #shop-popover-vm { pointer-events: auto !important; z-index: 40 !important; }
      /* 头部统一布局：头像固定；主播按内容占位；动态模块获得剩余空间；设置不收缩。 */
      & #head-info-vm {
        display: flex !important; align-items: center;
        position: relative !important; pointer-events: auto;
        width: 100% !important; height: auto !important; min-height: 60px;
        min-width: 0 !important; padding: 8px 12px !important;
        box-sizing: border-box; z-index: 30 !important; overflow: visible !important;

        & > .avatar { flex: 0 0 40px; width: 40px !important; height: 40px !important; }
        & > .rows-ctnr { flex: 1 !important; width: auto !important; min-width: 0 !important; }
        & .normal-row-ctnr {
          display: flex; align-items: center; flex-wrap: nowrap !important; gap: 8px;

          & > .left-anchor-section {
            flex: 0 1 auto !important; width: auto !important; min-width: 0;
            & > .content {
              flex: 0 1 auto !important; width: auto !important; min-width: 0; max-width: none !important;
            }
            & .room-owner-username {
              width: auto !important; max-width: none !important; overflow: visible !important;
              text-overflow: clip !important; white-space: normal !important; overflow-wrap: anywhere;
              /* 原站会截短文本；title 保留全名，原链接及事件继续使用。 */
              &[title]:not([title=""]) {
                font-size: 0 !important;
                &::after { content: attr(title); font-size: 14px; line-height: 16px; }
              }
            }
            & > .follow-ctnr { flex-shrink: 0; margin-left: 8px; }
          }
          & > .right-section {
            /* Vue 根据该容器的剩余宽度筛选模块，不能按当前可见内容收缩。 */
            flex: 1 1 0 !important; margin-left: auto; flex-wrap: nowrap; gap: 6px;
            width: auto !important; min-width: 0 !important; max-width: none !important;
            & > .right-dynamic-modules {
              width: auto !important; min-width: 0 !important; max-width: none !important;
              flex-wrap: nowrap; overflow: hidden;
            }
          }
          & > .right-fixed-modules { flex: 0 0 auto; }
        }
      }

      & #aside-area-vm {
        position: absolute !important;
        inset: var(--blc-head-height, 60px) 0 var(--blc-gift-height, 84px) !important;
        pointer-events: auto;
        display: flex !important; flex-direction: column !important;
        width: 100% !important; height: auto !important;
        min-width: 0 !important; min-height: 0 !important;
        margin: 0 !important; overflow: visible !important; z-index: auto !important;
      }
      /* 释放特效的父层限制；其他聊天模块仍在播放器业务层（20）下方。 */
      & #aside-area-vm > :not(#gift-screen-animation-vm) {
        z-index: 10 !important;
        /* 用户菜单沿用原生定位与显示逻辑，打开时仅释放聊天区的层叠限制。 */
        &.chat-history-panel:has(> .danmaku-menu) { z-index: auto !important; }
      }
      & #aside-area-vm > .chat-history-panel { z-index: 9 !important; }
      & #aside-area-vm > #chat-control-panel-vm { z-index: 11 !important; }
      & #aside-area-vm > #rank-list-vm { z-index: 12 !important; }
      & #rank-list-vm, & #chat-control-panel-vm { flex-shrink: 0 !important; }
      /* 只调整名字最大宽度；保留原生条目排列、头像位置与对齐方式。 */
      & #rank-list-vm .top3-name {
        max-width: max(0px, calc((100vw - 64px) / 3 - 29px)) !important;
      }
      & #rank-list-vm .top3-name-2 {
        max-width: max(0px, calc((100vw - 52px) / 2 - 29px)) !important;
      }
      & #rank-list-vm .top3-name-1 {
        max-width: max(0px, calc(100vw - 69px)) !important;
      }
      & #aside-area-vm .chat-history-panel {
        flex: 1 1 0 !important; min-height: 0 !important;
        overflow: visible !important;
      }
      /* 菜单延伸到礼物栏（60）时也可点击；不改原生位置、尺寸和交互。 */
      & .chat-history-panel > .danmaku-menu { z-index: 61 !important; }
      & #chat-history-list { overflow: auto !important; overscroll-behavior: contain; }
      & #chat-items { overflow-wrap: anywhere; }
      & #gift-screen-animation-vm {
        overflow: visible !important; pointer-events: none !important; z-index: 25 !important;
      }
      /* 只让打开的操作区弹窗和 PK 榜进入顶层，保留原生 DOM 与事件。 */
      & [data-blc-top-popup] {
        position: fixed !important; margin: 0 !important;
        inset: var(--blc-popup-top) auto auto var(--blc-popup-left) !important;
        width: var(--blc-popup-width) !important; color: inherit;
      }
      /* 左侧菜单以工具栏上边缘为底边；内容加载后高度变化仍沿用原生向上展开。 */
      & #chat-control-panel-vm ${toolbarPopups}[data-blc-top-popup] {
        top: auto !important; bottom: calc(100dvh - var(--blc-popup-bottom-edge)) !important;
        height: auto;
      }
      & #chat-control-panel-vm .like-btn[data-blc-top-popup] { border: 0; padding: 0; background-color: transparent; }
      & [data-blc-top-popup]::backdrop { background: transparent; pointer-events: none; }
      & ${pkRankFrame} {
        pointer-events: auto !important;
        position: fixed !important; inset: 50% auto auto 50% !important; margin: 0 !important;
        width: min(400px, calc(100vw - 16px)) !important;
        height: min(375px, calc(100dvh - 16px)) !important;
      }

      /* 视频画面与业务层是兄弟节点：保留业务注入层和官方动画遮罩。 */
      & .player-section {
        position: absolute !important; inset: 0 0 var(--blc-gift-height, 84px) !important;
        width: 100% !important; height: auto !important;
        min-width: 0 !important; min-height: 0 !important;
        background: transparent !important; overflow: visible !important;
        pointer-events: none !important; z-index: 20 !important;
      }
      & #live-player > :not(.web-player-inject-wrap):not(#animation-mask-wrapper):not(iframe[src*="app_name=ranks_pro"]) { display: none !important; }
      & #live-player, & #live-player-ctnr, & .web-player-inject-wrap,
      & #businessContainerElement, & #player-effect-vm {
        width: 100% !important; height: 100% !important;
        background: transparent !important; overflow: visible !important;
        pointer-events: none !important;
      }
      & #businessContainerElement > :is(#universal-pk-vm, #pk-vm, #awesome-pk-vm) {
        max-width: 100%;
      }
      & #player-effect-vm { position: absolute !important; inset: 0 !important; }
      & #businessContainerElement .pk-animation-box {
        /* 官方动画画布为 700×410，等比缩放容器，保留内部画布尺寸。 */
        pointer-events: none !important;
        transform: translate(-50%, -50%) scale(var(--blc-pk-scale, 1)) !important;
      }
      /* 原生资料卡事件绑在整个连麦画面；仅名字区域接收并冒泡原点击。 */
      & #interactive-play-vm {
        top: var(--blc-grid-area-top, 0px) !important;
        height: var(--blc-grid-area-height, 100%) !important;
        bottom: auto !important;
      }
      & #interactive-play-vm > .grid-template[data-blc-grid] { top: 0 !important; height: 100% !important; }
      & #interactive-play-vm [data-blc-grid-cell] {
        top: var(--blc-grid-top) !important; height: var(--blc-grid-height) !important;
      }
      & #interactive-play-vm :is(.grid-template, .grid-item, .grid-item-cell) { pointer-events: none !important; }
      & #interactive-play-vm :is(.anchor-nickname, .anchor-voice, .pk-number, .anchor-info-card, .relay-capsulev2) {
        pointer-events: auto !important;
      }

      & #fullscreen-container #gift-control-vm {
        position: absolute !important; inset: auto 0 0 !important; pointer-events: auto;
        display: flex !important; align-items: center;
        width: 100% !important; height: auto !important; min-width: 0 !important;
        min-height: 84px !important; padding: 0 !important;
        /* 原生悬停浮层挂在礼物栏内，整个礼物栏必须高于抽屉（50）。 */
        overflow: visible !important; z-index: 60 !important;
      }
      & #gift-control-vm > .left-part-ctnr {
        width: auto !important; height: auto !important; flex-shrink: 0;
      }
      & #gift-control-vm > .gift-panel {
        position: relative !important; inset: auto !important;
        display: flex !important; align-items: center; justify-content: flex-end;
        flex: 1;
        width: 100% !important; min-width: 0 !important; height: auto !important;
      }
      & #gift-control-vm > .z-gift-sender-panel {
        position: absolute !important; top: 0; left: 0; width: 100%;
      }
      & #gift-control-vm .gift-presets-wrap { min-width: 0; flex: 1; height: auto !important; }
      & #gift-control-vm .gift-presets,
      & #gift-control-vm .gift-section.gift-list {
        display: flex !important; width: 100% !important; height: auto !important;
        align-items: center; justify-content: flex-end;
      }
      & #gift-control-vm .gift-list > .base-panel {
        display: flex !important; flex-wrap: wrap; justify-content: flex-end;
        width: auto !important; height: auto !important; min-width: 0; flex: 1;
      }
      & #gift-control-vm .more-gift-section,
      & #gift-control-vm .gift-panel > .right-section { flex-shrink: 0; }
      & #gift-control-vm .gift-item { flex-shrink: 0; }
      & :is(${popups}) {
        box-sizing: border-box;
        max-width: calc(100vw - 16px) !important;
        max-height: calc(100dvh - 16px) !important;
      }
      /* 互动玩法独立挂在 body；复用边界修正，保留原生拖动和展开状态。 */
      & #game-id > div, & #game-id > div > div, & #game-id iframe {
        max-width: 100%; max-height: calc(100dvh - 16px);
      }
      & #game-id iframe { max-height: calc(100dvh - 61px); }
      /* 保留官方浮层的溢出方式；透明的悬停连接区不应撑出滚动条。 */
      & .gift-sender-panel::before, & .gift-sender-panel::after { width: 100% !important; }

      /* 充值卡片使用原生表单与事件；缩窄卡片，内容过高时只滚动表单。 */
      & .recharge-store-box > .cntr {
        display: flex !important; flex-direction: column;
        position: fixed !important; inset: 50% auto auto 50% !important;
        transform: translate(-50%, -50%) !important;
        width: min(440px, calc(100vw - 16px)) !important; height: auto !important;
        max-height: calc(100dvh - 16px) !important; margin: 0 !important;
        min-width: 0 !important; box-sizing: border-box;
        & > .tab-box { flex: 0 0 auto; width: 100% !important; height: 44px !important; }
        & > .tab-box > .list { display: flex; width: 100% !important; height: 44px !important; }
        & > .tab-box .item {
          flex: 1; min-width: 0; width: auto !important; height: 44px !important;
          top: 0 !important; line-height: 44px !important;
        }
        & > .tab-box .item-cntr {
          /* 原生斜切背景的层级为 1，文字需位于装饰层上方。 */
          position: relative !important; inset: auto !important; z-index: 2;
          display: block; transform: none !important;
          font-size: 16px !important; padding: 0 24px 0 8px; white-space: nowrap;
        }
        & > .close { top: 12px !important; right: 8px !important; z-index: 2; }
        & > .store-content {
          flex: 0 1 auto; min-height: 0; width: 100% !important; height: auto !important;
          overflow: auto !important; overscroll-behavior: contain;
        }
        & > .wechat-buy {
          position: relative !important; inset: auto !important; flex: 0 0 auto;
          width: auto !important; height: 32px !important; margin: 0 12px;
        }
        & .gold-seed-store, & .silver-seed-store {
          width: 100% !important; height: auto !important; overflow: visible !important;
        }
        & .sub-tab-box { display: block !important; width: 100% !important; height: auto !important; }
        & .sub-tab-box > .list { display: flex; width: 100% !important; height: auto !important; }
        & .sub-tab-box .item { flex: 1; width: auto !important; height: 40px !important; line-height: 40px; }
        & .gold-seed-store > .content, & .silver-seed-store > .content {
          display: block !important; width: 100% !important; height: auto !important;
        }
        /* 购买与 B 币兑换按内容撑高，避免固定高度产生多余滚动条。 */
        & .buy-gold-seed-store, & .gold-seed-store .gold-exchange-store {
          height: auto !important; min-height: 0 !important;
        }
        & .gold-seed-store .gold-exchange-store .btn-box { margin-bottom: 0 !important; }
        & .content-cntr { width: auto !important; height: auto !important; padding: 12px !important; }
        /* 协议是充值表单最后一项，不再叠加表单行与内容容器的底部留白。 */
        & .content-cntr:has(.buy-gold-seed-store),
        & .buy-gold-seed-store .recharge-form > dd:last-child { padding-bottom: 0 !important; }
        & .recharge-form { display: block; width: 100% !important; height: auto !important; }
        & .recharge-form > dt {
          display: block !important; width: auto !important; height: auto !important;
          margin: 0 0 6px !important; line-height: 20px; text-align: left !important;
          &:empty { display: none !important; }
        }
        & .recharge-form > dd {
          display: block !important; width: 100% !important; height: auto !important;
          min-width: 0; margin: 0 !important; padding: 0 0 12px !important; box-sizing: border-box;
        }
        & .balance-value { width: auto !important; max-width: 40%; margin-right: 24px; }
        & .fast-amount-list { width: 100% !important; height: auto !important; }
        & .select-list {
          display: grid !important; grid-template-columns: repeat(auto-fit, minmax(min(100%, 96px), 1fr));
          gap: 8px; width: 100% !important; height: auto !important;
        }
        & .select-list > .item { width: auto !important; min-width: 0; margin: 0 !important; box-sizing: border-box; }
        & .select-list > .free-amount { grid-column: 1 / -1; width: 100% !important; }
        & .ipt-free-amount { width: 100% !important; min-width: 0 !important; padding-right: 64px; box-sizing: border-box; }
        & .ipt-number { max-width: calc(100% - 48px); min-width: 0; box-sizing: border-box; }
        & .recharge-rule {
          width: auto !important; height: auto !important; white-space: normal !important;
          overflow-wrap: anywhere; line-height: 20px;
        }
        & .pay-method-box > .content { width: 100% !important; margin: 12px 0 0 !important; }
        & .qrcode-box { width: 100% !important; height: auto !important; margin: 0 !important; }
        & .qrcode-box .tip { height: auto !important; white-space: normal; overflow-wrap: anywhere; line-height: 20px; }
        & .user-protocol {
          display: block !important; width: 100% !important; height: auto !important;
          margin: 0 !important; white-space: normal; overflow-wrap: anywhere; line-height: 22px;
          & > .ic-agree { display: inline-block; vertical-align: middle; }
          & > .clickable, & > .protocol { display: inline; }
        }
      }
    }
    }
  `;
  document.head.append(style);

  const root = document.documentElement;
  const dimensions = ['--blc-head-height', '--blc-gift-height', '--blc-pk-scale', '--blc-grid-area-top', '--blc-grid-area-height'];
  const oldDimensions = dimensions.map(name => [root.style.getPropertyValue(name), root.style.getPropertyPriority(name)]);
  let narrow = false;
  let measured = [];
  const MEASURE = 1, SIDEBARS = 2, POPUPS = 4, DISCOVER = 8, ALL = 15;
  let dirty = ALL, stopped = false;
  let popupCandidates = new Set();
  const sizes = new ResizeObserver(() => schedule(MEASURE | POPUPS));
  const gridSelector = '#interactive-play-vm > .grid-template';
  const gridCells = new Map(), grids = new Set();
  function restoreGridCell(el, saved) {
    ['--blc-grid-top', '--blc-grid-height'].forEach((name, i) => {
      if (saved[i][0]) el.style.setProperty(name, ...saved[i]);
      else el.style.removeProperty(name);
    });
    el.removeAttribute('data-blc-grid-cell');
  }
  function syncInteractiveGrid() {
    const active = new Set(), activeGrids = new Set();
    for (const grid of document.querySelectorAll(gridSelector)) {
      const nativeHeight = /^\d*\.?\d+px$/.test(grid.style.height) ? parseFloat(grid.style.height) : 0;
      if (!nativeHeight) continue;
      activeGrids.add(grid); grids.add(grid);
      if (!grid.hasAttribute('data-blc-grid')) grid.setAttribute('data-blc-grid', '');
      for (const el of grid.children) {
        if (!el.matches('.grid-item') || !/^\d*\.?\d+px$/.test(el.style.height) || !/^-?\d*\.?\d+px$/.test(el.style.top)) continue;
        active.add(el);
        const names = ['--blc-grid-top', '--blc-grid-height'];
        if (!gridCells.has(el)) gridCells.set(el, names.map(name => [el.style.getPropertyValue(name), el.style.getPropertyPriority(name)]));
        [el.style.top, el.style.height].forEach((value, i) => {
          const percent = `${parseFloat(value) / nativeHeight * 100}%`;
          if (el.style.getPropertyValue(names[i]) !== percent) el.style.setProperty(names[i], percent);
        });
        if (!el.hasAttribute('data-blc-grid-cell')) el.setAttribute('data-blc-grid-cell', '');
      }
    }
    for (const grid of grids) if (!activeGrids.has(grid)) { grid.removeAttribute('data-blc-grid'); grids.delete(grid); }
    for (const [el, saved] of gridCells) if (!active.has(el)) { restoreGridCell(el, saved); gridCells.delete(el); }
  }
  const sidebars = new Map();
  function syncSidebars() {
    for (const [el, state] of sidebars) {
      if (!el.isConnected || !el.matches('.side-bar-cntr')) {
        state.destroy(); sidebars.delete(el);
      } else if (state.handle.previousElementSibling !== el) el.after(state.handle);
    }
    for (const el of document.querySelectorAll('.side-bar-cntr')) {
      if (sidebars.has(el)) continue;
      const collapsed = el.classList.contains('collapsed');
      const oldRight = [el.style.getPropertyValue('right'), el.style.getPropertyPriority('right')];
      const handle = document.createElement('button');
      handle.type = 'button'; handle.className = 'side-bar-toggle blc-sidebar-toggle';
      handle.title = '点击展开或收起';
      el.after(handle); el.setAttribute('data-blc-sidebar-panel', '');
      let open = false, animations = [];
      function layout() {
        const list = document.getElementById('chat-history-list');
        // clientWidth 已排除滚动条；直接贴齐实际内容区，不再叠加最小宽度或留白。
        const contentRight = list?.getClientRects().length
          ? list.getBoundingClientRect().left + list.clientLeft + list.clientWidth : root.clientWidth;
        const inset = Math.max(0, root.clientWidth - contentRight);
        const right = `${inset}px`, handleRight = `${inset + (open ? el.getBoundingClientRect().width : 0)}px`;
        if (el.style.right !== right) el.style.setProperty('right', right, 'important');
        if (handle.style.right !== handleRight) handle.style.right = handleRight;
      }
      function label() {
        handle.textContent = open ? '<' : '>';
        handle.setAttribute('aria-label', open ? '收起侧栏' : '展开侧栏');
        handle.setAttribute('aria-expanded', String(open));
      }
      function toggle() {
        const closedClip = 'inset(-8px 0 -8px 100%)', openClip = 'inset(-8px 0 -8px -8px)';
        const fromPanel = el.classList.contains('collapsed') ? closedClip : getComputedStyle(el).clipPath;
        const fromHandle = getComputedStyle(handle).right;
        animations.forEach(animation => animation.cancel()); animations = [];
        open = !open; el.classList.remove('collapsed');
        layout(); label();
        if (!el.animate || matchMedia('(prefers-reduced-motion: reduce)').matches) {
          el.classList.toggle('collapsed', !open); return;
        }
        const options = {duration: 180, easing: 'ease-out'};
        const panelAnimation = el.animate([{clipPath: fromPanel === 'none' ? openClip : fromPanel},
          {clipPath: open ? openClip : closedClip}], options);
        const handleAnimation = handle.animate([{right: fromHandle}, {right: handle.style.right}], options);
        animations = [panelAnimation, handleAnimation];
        panelAnimation.onfinish = () => { el.classList.toggle('collapsed', !open); animations = []; };
      }
      handle.onclick = toggle;
      sidebars.set(el, { handle, layout, destroy() {
        animations.forEach(animation => animation.cancel());
        sizes.unobserve(el);
        handle.remove();
        if (oldRight[0]) el.style.setProperty('right', ...oldRight);
        else el.style.removeProperty('right');
        el.removeAttribute('data-blc-sidebar-panel'); el.classList.toggle('collapsed', collapsed);
      } });
      el.classList.add('collapsed'); sizes.observe(el); layout(); label();
    }
  }
  function measure() {
    let availableHeight = innerHeight;
    const updates = [];
    ['head-info-vm', 'gift-control-vm'].forEach((id, index) => {
      const el = document.getElementById(id);
      if (measured[index] !== el) {
        if (measured[index]) sizes.unobserve(measured[index]);
        if (el) sizes.observe(el);
        measured[index] = el;
      }
      const height = el?.getBoundingClientRect().height;
      availableHeight -= height ?? (index === 0 ? 60 : 84);
      const value = height == null ? '' : `${height}px`;
      if (value && root.style.getPropertyValue(dimensions[index]) !== value) {
        updates.push([dimensions[index], value]);
      }
    });
    const scale = String(Math.max(0, Math.min(1, root.clientWidth / 700, availableHeight / 410)));
    if (root.style.getPropertyValue(dimensions[2]) !== scale) updates.push([dimensions[2], scale]);
    const history = document.querySelector('#aside-area-vm .chat-history-panel');
    const player = document.getElementById('businessContainerElement');
    [history, player, document.getElementById('chat-history-list')].forEach((el, i) => {
      if (measured[i + 2] !== el) {
        if (measured[i + 2]) sizes.unobserve(measured[i + 2]);
        if (el) sizes.observe(el);
        measured[i + 2] = el;
      }
    });
    const chatBox = history?.getBoundingClientRect(), playerBox = player?.getBoundingClientRect();
    const area = chatBox && playerBox && chatBox.height > 0
      ? [`${chatBox.top - playerBox.top}px`, `${chatBox.height}px`] : ['', ''];
    area.forEach((value, i) => {
      if (root.style.getPropertyValue(dimensions[i + 3]) !== value) updates.push([dimensions[i + 3], value]);
    });
    for (const [name, value] of updates) root.style.setProperty(name, value);
    syncInteractiveGrid();
    for (const state of sidebars.values()) state.layout();
  }
  const translateParts = value => value === 'none' ? ['0px', '0px'] : value.match(/calc\([^)]*\)|\S+/g);
  function pixels(value = '0px', size) {
    if (value === '0') return 0;
    const expression = value.startsWith('calc(') ? value.slice(5, -1) : value;
    const terms = /([+-]?)\s*(\d*\.?\d+(?:e[+-]?\d+)?)\s*(px|%)/gi;
    // 计算样式归一为 px/%；其他表达式保留原生定位，避免写入无效位移。
    if (expression.replace(terms, '').replace(/[+\-\s]/g, '')) return NaN;
    return [...expression.matchAll(terms)].reduce((sum, [, sign, amount, unit]) =>
      sum + (sign === '-' ? -1 : 1) * Number(amount) * (unit === '%' ? size / 100 : 1), 0);
  }
  // 只修正越界距离，保留原生 transform（定位、过渡、动画）。
  const shifted = new Map();
  const raised = new Map();
  // 左右两侧操作菜单共用顶层处理；保持原生 transform、transform-origin 与动画类。
  const topPopups = `${pkRankFrame},#chat-control-panel-vm :is(${toolbarPopups},.common-popup-wrap.emoticons,.common-popup-wrap.superChat,.like-btn .common-popup-wrap,.like-btn.not-clicked:hover)`;
  function lowerPopup(el, saved) {
    try { el.hidePopover(); } catch {}
    el.removeAttribute('popover'); el.removeAttribute('data-blc-top-popup');
    saved.styles.forEach(([name, value, priority]) => {
      if (value) el.style.setProperty(name, value, priority);
      else el.style.removeProperty(name);
    });
    saved.placeholder?.remove();
    raised.delete(el);
  }
  function syncTopPopups() {
    const visible = new Set([...document.querySelectorAll(topPopups)].filter(el =>
      el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden'));
    for (const [el, saved] of raised) if (!visible.has(el)) lowerPopup(el, saved);
    for (const el of visible) {
      let saved = raised.get(el);
      if (!saved) {
        if (!el.showPopover || el.hasAttribute('popover')) continue;
        const rect = el.getBoundingClientRect(), css = getComputedStyle(el), translate = translateParts(css.translate);
        // 使用原生布局坐标，避免把进入动画的 transform 位移再补偿一次。
        const parent = el.offsetParent, origin = css.position === 'absolute' && parent?.getBoundingClientRect();
        const left = origin ? origin.left + parent.clientLeft - parent.scrollLeft + parseFloat(css.left) + parseFloat(css.marginLeft) : NaN;
        const top = origin ? origin.top + parent.clientTop - parent.scrollTop + parseFloat(css.top) + parseFloat(css.marginTop) : NaN;
        // 点赞提示是按钮的伪元素；保留按钮占位，避免临时提升时挤动其他图标。
        let placeholder;
        if (el.matches('.like-btn')) {
          placeholder = document.createElement('span');
          placeholder.style.cssText = `display:inline-block;width:${css.width};height:${css.height};margin:${css.margin};flex-shrink:0`;
          el.before(placeholder);
        }
        saved = {
          anchorEl: placeholder || el.parentElement, placeholder,
          width: css.width,
          left: Number.isFinite(left) ? left : rect.left - pixels(translate[0], rect.width),
          top: Number.isFinite(top) ? top : rect.top - pixels(translate[1], rect.height),
          bottomEdge: el.matches(toolbarPopups) && origin
            ? origin.top + parent.clientTop + parent.clientHeight - parent.scrollTop - parseFloat(css.bottom) - parseFloat(css.marginBottom) : NaN,
          styles: ['--blc-popup-left', '--blc-popup-top', '--blc-popup-width', '--blc-popup-bottom-edge'].map(name =>
            [name, el.style.getPropertyValue(name), el.style.getPropertyPriority(name)]),
        };
        el.style.setProperty('--blc-popup-width', css.width);
        raised.set(el, saved);
        el.setAttribute('data-blc-top-popup', ''); el.setAttribute('popover', 'manual');
        saved.anchor = saved.anchorEl.getBoundingClientRect();
      }
      const anchor = saved.anchorEl.getBoundingClientRect();
      saved.left += anchor.left - saved.anchor.left; saved.top += anchor.bottom - saved.anchor.bottom;
      saved.bottomEdge += anchor.bottom - saved.anchor.bottom;
      saved.anchor = anchor;
      const width = el.matches('.bottom-left') ? `${saved.anchorEl.clientWidth}px` : saved.width;
      if (el.style.getPropertyValue('--blc-popup-width') !== width) el.style.setProperty('--blc-popup-width', width);
      const left = `${saved.left}px`, top = `${saved.top}px`;
      if (el.style.getPropertyValue('--blc-popup-left') !== left) el.style.setProperty('--blc-popup-left', left);
      if (el.style.getPropertyValue('--blc-popup-top') !== top) el.style.setProperty('--blc-popup-top', top);
      if (Number.isFinite(saved.bottomEdge)) {
        const bottomEdge = `${saved.bottomEdge}px`;
        if (el.style.getPropertyValue('--blc-popup-bottom-edge') !== bottomEdge) el.style.setProperty('--blc-popup-bottom-edge', bottomEdge);
      }
      if (!el.matches(':popover-open')) {
        try { el.showPopover(); } catch { lowerPopup(el, saved); }
      }
    }
  }
  let frame = 0;
  function fitPopups() {
    frame = 0;
    if (stopped) return;
    if (narrow !== narrowLayout.matches) {
      narrow = narrowLayout.matches;
      playback.refresh();
      if (narrow) { root.setAttribute('data-bilibili-live-chat', ''); dirty = ALL; }
      else { root.removeAttribute('data-bilibili-live-chat'); clearLayout(); }
    }
    if (!narrow) { dirty = 0; return; }
    const work = dirty; dirty = 0;
    if (work & SIDEBARS) syncSidebars();
    if (work & MEASURE) measure();
    if (!(work & POPUPS)) return;
    if (work & DISCOVER) popupCandidates = new Set(document.querySelectorAll(popups));
    syncTopPopups();
    const updates = [];
    for (const [el, saved] of shifted) {
      if (!el.isConnected || !el.matches(popups)) {
        restoreTranslate(el, saved);
        shifted.delete(el);
      }
    }
    for (const el of popupCandidates) {
      if (!el.isConnected || !el.matches(popups)) { popupCandidates.delete(el); continue; }
      if (el.parentElement?.closest(popups)) continue;
      const box = el.getBoundingClientRect(), rect = box;
      if (!rect.width || !rect.height || getComputedStyle(el).visibility === 'hidden') continue;
      const saved = shifted.get(el) || {
        value: el.style.getPropertyValue('translate'),
        priority: el.style.getPropertyPriority('translate'), x: 0, y: 0,
        base: translateParts(getComputedStyle(el).translate),
      };
      // 原站 transition: all 会过渡 translate；用当前值反算，避免边界修正漂移。
      const current = translateParts(getComputedStyle(el).translate);
      const left = rect.left - pixels(current[0], box.width) + pixels(saved.base[0], box.width);
      const top = rect.top - pixels(current[1], box.height) + pixels(saved.base[1], box.height);
      if (!Number.isFinite(left) || !Number.isFinite(top)) continue;
      const x = Math.min(Math.max(left, 8), Math.max(8, root.clientWidth - rect.width - 8)) - left;
      const y = Math.min(Math.max(top, 8), Math.max(8, innerHeight - rect.height - 8)) - top;
      if (Math.abs(x - saved.x) < 0.5 && Math.abs(y - saved.y) < 0.5) continue;
      Object.assign(saved, { x, y });
      shifted.set(el, saved);
      const [baseX, baseY = '0px', baseZ = ''] = saved.base;
      updates.push([el, `calc(${baseX} + ${x}px) calc(${baseY} + ${y}px) ${baseZ}`]);
    }
    for (const [el, value] of updates) el.style.setProperty('translate', value, 'important');
  }
  function schedule(parts = ALL) {
    if (stopped) return;
    dirty |= typeof parts === 'number' ? parts : ALL;
    if (!frame) frame = requestAnimationFrame(fitPopups);
  }
  function restoreTranslate(el, saved) {
    if (saved.value) el.style.setProperty('translate', saved.value, saved.priority);
    else el.style.removeProperty('translate');
  }
  function clearLayout() {
    sizes.disconnect(); measured = [];
    for (const grid of grids) grid.removeAttribute('data-blc-grid');
    for (const [el, saved] of gridCells) restoreGridCell(el, saved);
    grids.clear(); gridCells.clear();
    for (const [el, saved] of raised) lowerPopup(el, saved);
    for (const [el, saved] of shifted) restoreTranslate(el, saved);
    for (const state of sidebars.values()) state.destroy();
    sidebars.clear(); popupCandidates.clear(); shifted.clear(); raised.clear();
    dimensions.forEach((name, i) => {
      if (oldDimensions[i][0]) root.style.setProperty(name, ...oldDimensions[i]);
      else root.style.removeProperty(name);
    });
  }
  const animationLayers = '#businessContainerElement .pk-animation-box,#player-effect-vm,#gift-screen-animation-vm,#animation-mask-wrapper';
  const layoutRoots = `#head-info-vm,#gift-control-vm,.side-bar-cntr,#aside-area-vm,.chat-history-panel,#chat-history-list,#businessContainerElement,#interactive-play-vm,${gridSelector}`;
  const relevantNodes = `${layoutRoots},${popups}`;
  const observer = new MutationObserver(records => {
    if (!narrowLayout.matches) return;
    let work = 0;
    for (const {type, target, addedNodes, removedNodes} of records) {
      if (target.closest?.('#head-info-vm,#gift-control-vm')) work |= MEASURE | POPUPS;
      if (target.matches?.(`${gridSelector},${gridSelector} > .grid-item`)
        || type === 'childList' && target.matches?.('#aside-area-vm,#interactive-play-vm')) work |= MEASURE | POPUPS;
      // 贡献榜移除后不再匹配带父级的选择器，仍需释放顶层状态。
      if (type === 'childList' && target.matches?.('#live-player')) work |= DISCOVER | POPUPS;
      if (target.closest?.('.side-bar-cntr')) work |= SIDEBARS | POPUPS;
      if (target.closest?.(popups) || target.closest?.('#chat-control-panel-vm')) work |= POPUPS;
      if (target.matches?.(popups) && !popupCandidates.has(target)) work |= DISCOVER | POPUPS;
      if (type === 'childList') {
        for (const node of [...addedNodes, ...removedNodes]) {
          if (node.nodeType === 1 && (node.matches(relevantNodes) || node.querySelector(relevantNodes))) work |= ALL;
        }
      } else if (!target.closest?.(animationLayers) && popupCandidates.size) {
        // An ancestor can hide or move an existing popup without changing the popup itself.
        if ([...popupCandidates].some(popup => target.contains(popup))) work |= POPUPS;
      }
    }
    if (work) schedule(work);
  });
  observer.observe(document.body, {
    childList: true, subtree: true, attributes: true,
    attributeFilter: ['style', 'class', 'hidden', 'src'],
  });
  window.addEventListener('resize', schedule);
  narrowLayout.addEventListener('change', schedule);
  const schedulePopups = () => schedule(POPUPS);
  const onPopupPointer = event => {
    if (event.target.closest?.(`${popups},#chat-control-panel-vm,#head-info-vm,#gift-control-vm`)) schedule(POPUPS);
  };
  window.addEventListener('scroll', schedulePopups, true);
  document.addEventListener('pointerover', onPopupPointer, true);
  document.addEventListener('pointerout', onPopupPointer, true);
  document.addEventListener('focusin', onPopupPointer, true);
  fitPopups();
  window.bilibiliLiveChat = {
    get videoState() { return playback.state; },
    destroy() {
      if (stopped) return;
      stopped = true;
      avatarNavigation.destroy();
      anchorNavigation.destroy();
      playback.destroy();
      observer.disconnect();
      clearLayout();
      cancelAnimationFrame(frame);
      window.removeEventListener('resize', schedule);
      narrowLayout.removeEventListener('change', schedule);
      window.removeEventListener('scroll', schedulePopups, true);
      document.removeEventListener('pointerover', onPopupPointer, true);
      document.removeEventListener('pointerout', onPopupPointer, true);
      document.removeEventListener('focusin', onPopupPointer, true);
      style.remove();
      document.documentElement.removeAttribute('data-bilibili-live-chat');
      delete window.bilibiliLiveChat;
      window.dispatchEvent(new Event('resize'));
    },
  };
  // 让按窗口大小计算位置的原生面板重新测量。
  window.dispatchEvent(new Event('resize'));
  }
})();
