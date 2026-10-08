(() => {
  'use strict';

  const pageType = () => {
    if (location.hostname !== 'www.bilibili.com') return '';
    if (/^\/video\/(?:BV[\w]+|av\d+)(?:\/|$)/i.test(location.pathname)) return 'ugc';
    if (/^\/bangumi\/play\/(?:ss|ep)\d+(?:\/|$)/.test(location.pathname)) return 'pgc';
    return '';
  };
  if (!pageType()) return;
  let previousShortcuts = window.bilibiliVideoComments?.destroy() || {};
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

  function disableBilibiliAutoPlay() {
    const el = document.querySelector('input.bui-switch-input[aria-label*="自动开播"]');
    if (el?.checked) el.click();
  }
  function pauseBilibiliVideo(doc = document) {
    const video = [...doc.querySelectorAll('video')].find(video => !video.paused && !video.ended);
    if (video) { video.pause(); return true; }
    for (const iframe of doc.querySelectorAll('iframe')) {
      try {
        if (iframe.contentDocument && pauseBilibiliVideo(iframe.contentDocument)) return true;
      } catch { /* 跨域 iframe 无法读取，继续检查其他 iframe。 */ }
    }
    return false;
  }
  function disableBilibiliDanmaku() {
    // 新版官方接口直接设为关闭，兼容三态开关，避免点击后只切到精简弹幕。
    const danmaku = window.player?.danmaku;
    if (typeof danmaku?.isOpen === 'function' && typeof danmaku.close === 'function') {
      if (danmaku.isDisabled?.()) return false;
      const open = danmaku.isOpen();
      if (typeof open !== 'boolean') return false;
      if (open) danmaku.close();
      return true;
    }
    // 兼容旧版播放器：通过官方复选框关闭，不改写其 checked 属性。
    const input = document.querySelector('.bpx-player-dm-switch input.bui-switch-input');
    if (!input || input.disabled || typeof input.checked !== 'boolean') return false;
    if (input.checked) input.click();
    return true;
  }
  // 初始化时依次执行一次；不拦截后续手动播放，也不在布局更新时重复暂停。
  disableBilibiliAutoPlay();
  pauseBilibiliVideo();
  let danmakuInitialized = disableBilibiliDanmaku();

  // 时间定位链接保留显示；先于 PotPlayer 点击模块阻止官方跳转/播放。
  listen('click auxclick', event => {
    if (!pageType() || !event.composedPath().some(node => node.matches?.('[data-type="seek"]'))) return;
    event.preventDefault();
    event.stopImmediatePropagation();
  }, { capture: true, passive: false });

  // 点击功能随布局实例安装/卸载；普通浏览器中不改变跳转。
  function installPotPlayerClick() {
    const webview = window.chrome?.webview;
    if (typeof webview?.postMessage !== 'function') return { prepare() {}, destroy() {} };
    const originalOpen = window.open;
    const clickScope = '.video-tag-container, #bgm-entry #musicApp .videoList :is(.coverWrap, .videoTitle)';
    const playbackScope = 'bili-comments, .bb-comment, .video-desc-container';
    let click = null;
    let timer = 0;
    const shortLinks = new Map();

    function prepare(root) {
      if (root === document) {
        for (const content of root.querySelectorAll(playbackScope)) prepare(content);
        return;
      }
      for (const anchor of root.querySelectorAll('a[href]')) {
        let url;
        try { url = new URL(anchor.getAttribute('href'), location.href).href; } catch { continue; }
        if (!/^https?:\/\/b23\.tv\/[a-z\d]+\/?(?:[?#].*)?$/i.test(url) || shortLinks.has(url)) continue;
        // 简介和评论共用解析与缓存；禁用框架脚本，避免目标页自动播放。
        const iframe = document.createElement('iframe');
        const entry = { url: '', cancel() {} };
        shortLinks.set(url, entry);
        iframe.hidden = true;
        iframe.setAttribute('sandbox', 'allow-same-origin');
        const timeout = setTimeout(() => entry.cancel(), 8000);
        entry.cancel = () => {
          clearTimeout(timeout);
          iframe.onload = null;
          iframe.remove();
          entry.cancel = () => {};
        };
        iframe.onload = () => {
          try { entry.url = supportedUrl(iframe.contentDocument?.URL, true); } catch { /* 非同源目标保留原链接。 */ }
          entry.cancel();
        };
        iframe.src = url;
        document.body.append(iframe);
      }
    }

    function supportedUrl(value, playbackOnly = false) {
      if (!value) return '';
      try {
        const u = new URL(value, location.href);
        if (!['https:', 'http:'].includes(u.protocol)) return '';
        const host = u.hostname.toLowerCase();
        const path = u.pathname;
        if (host === 'b23.tv') return shortLinks.get(u.href)?.url || '';
        if (playbackOnly) return host === 'live.bilibili.com' && /^\/(?:blanc\/)?\d+\/?$/.test(path)
          || host === 'www.bilibili.com' && /^\/(?:video\/(?:BV[a-z\d]+|av\d+)|bangumi\/play\/(?:ep|ss)\d+)(?:\/|$)/i.test(path)
          ? u.href : '';
        if (['t.bilibili.com', 'search.bilibili.com', 'live.bilibili.com'].includes(host)
          || (host === 'space.bilibili.com' && /^\/\d+(?:\/|$)/.test(path))
          || (host === 'link.bilibili.com' && path.includes('/user-center/follow'))) return u.href;
        if (host !== 'www.bilibili.com') return '';
        return path === '/' || /^\/v\/popular\/(?:all|weekly|history|rank)(?:\/|$)/.test(path)
          || /^\/(?:watchlater|history)(?:\/|$)/.test(path)
          || path.includes('/medialist/detail/ml')
          || /^\/audio\/(?:am|au)\d+(?:\/|$)/i.test(path)
          || /^\/bangumi\/(?:media\/md|play\/(?:ep|ss))\d+(?:\/|$)/i.test(path)
          || /^\/video\/(?:BV[a-z\d]+|av\d+)(?:\/|$)/i.test(path) ? u.href : '';
      } catch { return ''; }
    }

    function send(url) {
      if (click?.sent === url) return true;
      try {
        webview.postMessage({ type: 'potPlayer.video-click', url });
        if (click) click.sent = url;
        return true;
      } catch { return false; }
    }

    function onClick(event) {
      clearTimeout(timer);
      click = null;
      if (!pageType() || !event.isTrusted || ![0, 1].includes(event.button)) return;
      const path = event.composedPath();
      // 事件路径可读取开放 Shadow DOM 内的链接，不局限于 retarget 后的 target。
      const anchor = path.find(node => node.matches?.('a[href]'));
      const inScope = path.some(node => node.matches?.(clickScope));
      // 评论和简介只接管明确带 href 的播放链接，不启用 window.open 后备处理。
      if (!inScope && !path.some(node => node.matches?.(playbackScope))) return;
      const url = supportedUrl(anchor?.getAttribute('href'), !inScope);
      if (url) {
        if (send(url)) {
          event.preventDefault();
          event.stopImmediatePropagation();
        }
        return;
      }
      // 无 href 时保留官方处理器，由其 window.open 提供实际目标地址。
      if (inScope) {
        click = { sent: '' };
        timer = setTimeout(() => { click = null; }, 0);
      }
    }

    function open(...args) {
      const url = click && pageType() && supportedUrl(args[0]);
      if (url && send(url)) return null;
      return Reflect.apply(originalOpen, this, args);
    }

    window.open = open;
    listen('click auxclick', onClick, { capture: true, passive: false });
    return { prepare, destroy() {
      clearTimeout(timer);
      click = null;
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
  // 整个弹幕容器作为弹出框；内部切换菜单时不再依赖屏蔽区域的显隐。
  const panelAttr = 'data-bilibili-video-comments-panel';
  const panel = `${scope}[${panelAttr}] #danmukuBox`;
  const panelSide = `${scope}[${panelAttr}]:has(#danmukuBox .bui-collapse-wrap:not(.bui-collapse-wrap-folded)) :is(.right-container, .plp-r-wrap)`;
  const panelPath = ':is(.right-container-inner, .video-pod-above-modules, .video-pod-above-modules__inner, .plp-r)';
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
    ${scope} :is(#biliMainHeader, #bili-header-container, .bili-header,
      .bili-mini-header, .header-v3, .international-header,
      .float-nav, .fixed-sidenav, .footer, .special-cover) { display: none !important; }

    /* UGC：保留播放器壳和操作/评论节点，去掉两栏布局及额外信息。 */
    ${ugc} :is(#app, .video-container-v1, .video-container-v1 .left-container) { ${pageSize} }
    ${ugc} .video-container-v1 { display: block !important; }
    ${ugc} .fixed-sidenav-storage { display: none !important; }
    ${ugc} .video-container-v1 .right-container { display: none !important; }
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
    ${ugc} .video-toolbar-left {
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
    ${ugc} :is(.video-toolbar-left, .video-toolbar-right) > * { flex: 0 0 auto !important; margin-right: 0 !important; }

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
    ${pgc} :is(.home-container, .main-container, .plp-l) { ${pageSize} }
    ${pgc} .plp-layout { display: block !important; }
    ${pgc} .plp-left-wrap {
      box-sizing: border-box !important; width: 100% !important;
      min-width: 0 !important; padding: 0 8px !important;
    }
    ${pgc} .plp-l { position: static !important; }
    ${pgc} .player-left-components { margin: 0 !important; }
    ${pgc} :is(.plp-r-wrap, [class*="navTools_floatNav"],
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
    ${scope} .bpx-player-sending-area { display: block !important; }
    ${scope} :is(.bpx-player-sending-bar, [class*="NanoPlayer_nonoPlayerSendingBar__"]) {
      box-sizing: border-box !important; height: auto !important; min-height: 46px;
      padding: 8px 12px !important; gap: 8px; flex-wrap: wrap !important;
    }
    ${scope} :is(.bpx-player-sending-bar-left, [class*="NanoPlayer_nonoPlayerSendingBarLeft"]) {
      flex: 0 1 auto !important; width: auto !important; margin: 0 !important;
    }
    ${scope} :is(.bpx-player-sending-bar-right, [class*="NanoPlayer_nonoPlayerSendingBarRight"]) {
      flex: 1 1 280px !important; width: auto !important; min-width: 0 !important;
      height: auto !important;
    }
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

    /* 恢复通往 #danmukuBox 的路径，其他推荐内容保持隐藏。 */
    ${panelSide}, ${panelSide} ${panelPath} { display: contents !important; }
    ${panelSide} > :not(:has(#danmukuBox)),
    ${panelSide} ${panelPath} > :not(#danmukuBox):not(:has(#danmukuBox)) { display: none !important; }
    ${panel} {
      ${panelSize(350, 'vw')} margin: 0 !important;
      box-sizing: border-box !important; z-index: 1002;
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
      ${scope} :is(.bpx-player-sending-bar-right,
        [class*="NanoPlayer_nonoPlayerSendingBarRight"]) { flex-basis: 100% !important; }
    }
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
      #disabled-commentbox #user-avatar { justify-content: flex-start !important; width: ${commentInset} !important; }
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
  const profileProperties = ['--bilibili-video-comments-profile-left', '--bilibili-video-comments-profile-top'];
  function observe(root) {
    observer.observe(root, { childList: true, subtree: true });
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
  let responsiveRoute = '';
  const responsiveTargets = new Map();
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
    const panel = document.querySelector('#danmukuBox');
    if (!panel) return;
    const path = event.composedPath();
    if (path.some(node => node.matches?.('.bpx-player-dm-setting-left-block-add'))) {
      html.setAttribute(panelAttr, '');
      return; // 后续官方处理器会选择屏蔽设定并展开容器。
    }
    if (html.getAttribute(panelAttr) === null || path.includes(panel)
      || path.some(node => node.matches?.('.bpx-player-dm-setting'))) return;
    html.removeAttribute(panelAttr);
    // 不取消外部点击；通过官方折叠控件同步其状态，之后仍可重新打开。
    if (!panel.querySelector('.bui-collapse-wrap-folded')) panel.querySelector('.bui-collapse-arrow')?.click();
  }
  function notifyOfficialResize() {
    if (stopped || resizeFrame) return;
    // 等 CSS 布局完成，再让官方按新的容器宽度计算按钮与标签。
    resizeFrame = requestAnimationFrame(() => {
      resizeFrame = 0;
      if (!stopped) window.dispatchEvent(new Event('resize'));
    });
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
    if (records.some(({ target }) => !target.closest?.('#danmukuBox'))) schedule();
  });
  function schedule() {
    if (!stopped && !frame) frame = requestAnimationFrame(sync);
  }
  function visit(root, inComments = false) {
    inComments ||= root.host?.localName === 'bili-comments';
    if (root === document || inComments && root.host?.localName === 'bili-rich-text') potPlayerClick.prepare(root);
    for (const host of root.querySelectorAll(selector)) {
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
    syncPlayerShortcuts(type);
    if (type && !restoreMediaShortcuts) restoreMediaShortcuts = disableMediaShortcuts();
    else if (!type && restoreMediaShortcuts) {
      previousShortcuts = { ...previousShortcuts, ...restoreMediaShortcuts() };
      restoreMediaShortcuts = null;
    }
    if (!type || !document.querySelector('#danmukuBox')) html.removeAttribute(panelAttr);
    // 只等首次可用；成功后不在 DOM 更新或手动重新开启时重复关闭。
    if (type && !danmakuInitialized) danmakuInitialized = disableBilibiliDanmaku();
    setScope(type || previous);
    const detached = [...roots.keys()].filter(root => !type || !root.host.isConnected);
    detached.forEach(removeRoot);
    if (detached.length) {
      observer.disconnect();
      observe(html);
      for (const root of roots.keys()) observe(root);
    }
    if (type) visit(document);
    syncResponsiveLayout(type);
  }
  observe(html);
  listen('popstate resize', schedule);
  listen('click', onDanmakuPanelClick, { capture: true });
  listen('keydown keyup', onMediaKey, { capture: true, passive: false });
  // 已在 DOM 中但还未升级的组件，定义完成后再检查，不使用轮询。
  for (const tag of tags) customElements.whenDefined(tag).then(schedule);
  const controller = {
    destroy() {
      if (stopped) return;
      stopped = true;
      const shortcuts = { ...restorePlayerShortcuts(), ...restoreMediaShortcuts?.() };
      potPlayerClick.destroy();
      cancelAnimationFrame(frame);
      cancelAnimationFrame(resizeFrame);
      sizeObserver.disconnect();
      responsiveTargets.clear();
      observer.disconnect();
      for (const dispose of disposers) dispose();
      html.removeAttribute(panelAttr);
      for (const root of roots.keys()) removeRoot(root);
      style.remove();
      setScope();
      if (window.bilibiliVideoComments === controller) delete window.bilibiliVideoComments;
      return shortcuts;
    },
  };
  window.bilibiliVideoComments = controller;
  sync();
})();