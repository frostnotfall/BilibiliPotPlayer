(() => {
  'use strict';

  const pageType = () => {
    if (location.hostname !== 'www.bilibili.com') return '';
    if (/^\/video\/(?:BV[\w]+|av\d+)(?:\/|$)/i.test(location.pathname)) return 'ugc';
    if (/^\/bangumi\/play\/(?:ss|ep)\d+(?:\/|$)/.test(location.pathname)) return 'pgc';
    return '';
  };
  if (!pageType()) return;
  window.bilibiliVideoComments?.destroy();

  function disableBilibiliAutoPlay() {
    const el = document.querySelector('input.bui-switch-input[aria-label*="自动开播"]');
    if (!el) {
      return false;
    }
    if (el.checked) {
      el.click();
    }
    return true;
  }
  function pauseBilibiliVideo(doc = document) {
    for (const video of doc.querySelectorAll('video')) {
      if (!video.paused && !video.ended) {
        video.pause();
        return true;
      }
    }
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
      if (open) {
        danmaku.close();
      }
      return true;
    }
    // 兼容旧版播放器：通过官方复选框关闭，不改写其 checked 属性。
    const input = document.querySelector('.bpx-player-dm-switch input.bui-switch-input');
    if (!input || input.disabled || typeof input.checked !== 'boolean') return false;
    if (input.checked) {
      input.click();
    }
    return true;
  }
  // 初始化时依次执行一次；不拦截后续手动播放，也不在布局更新时重复暂停。
  disableBilibiliAutoPlay();
  pauseBilibiliVideo();
  let danmakuInitialized = disableBilibiliDanmaku();

  const attr = 'data-bilibili-video-comments';
  const html = document.documentElement;
  const previous = html.getAttribute(attr);
  // 所有普通 DOM 样式均受此属性约束；不修改原站主题设置。
  const ugc = `html[${attr}="ugc"]`;
  const pgc = `html[${attr}="pgc"]`;
  const scope = `:is(${ugc}, ${pgc})`;
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
    ${ugc} :is(#app, .video-container-v1, .video-container-v1 .left-container) {
      width: 100% !important; min-width: 0 !important; max-width: none !important;
      margin: 0 !important; padding: 0 !important; box-sizing: border-box !important;
    }
    ${ugc} .video-container-v1 { display: block !important; }
    ${ugc} .fixed-sidenav-storage { display: none !important; }
    ${ugc} :is(.video-container-v1 .right-container, .video-info-container,
      .video-desc-container, .video-tag-container, .video-ai-assistant,
      .left-container .ad-report, .left-container #slide_ad, .video-page-special-card-small) {
      display: none !important;
    }
    ${ugc} :is(.video-toolbar-container, #comment, #commentapp) {
      margin-left: 8px !important; margin-right: 8px !important;
      width: auto !important; min-width: 0 !important;
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
    ${ugc} :is(.video-toolbar-left, .video-toolbar-right) > * {
      flex: 0 0 auto !important; margin-right: 0 !important;
    }

    /* PGC：解除播放器高度占位，信息区留在官方父容器内。 */
    ${pgc} :is(.home-container, .main-container, .plp-l) {
      width: 100% !important; min-width: 0 !important; max-width: none !important;
      margin: 0 !important; padding: 0 !important; box-sizing: border-box !important;
    }
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
    ${pgc} [class*="moreTool_popupWrap"] {
      min-width: 0 !important; max-width: 100% !important;
    }
    ${pgc} [class*="mediainfo_mediaRight"] { min-width: 0; }
    ${pgc} [class*="mediainfo_bottomBar"] { flex-wrap: wrap; gap: 8px; }
    ${pgc} #comment-module { padding-top: 18px !important; }

    /* 共用播放器：初始化已暂停一次，此处只压缩不可见画面。 */
    ${scope} :is(#playerWrap, #bilibili-player-wrap, #bilibili-player,
      .bpx-docker, .bpx-player-container, .bpx-player-primary-area,
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
    ${scope} :is(.bpx-player-dm-root, .bpx-player-dm-wrap, .bpx-player-dm-input) {
      min-width: 0 !important; max-width: 100% !important;
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
  const shadowCSS = {
    /* 头像左移 20px 后，所有原先 80px 的内容缩进统一减为 60px。 */
    'bili-comments': `
      #reply-commentbox bili-comment-box {
        padding-left: var(--bilibili-video-comments-content-inset) !important;
      }
      #limit-mask-tip {
        margin-left: var(--bilibili-video-comments-content-inset) !important;
        width: calc(100% - var(--bilibili-video-comments-content-inset)) !important;
      }
    `,
    'bili-comment-renderer': `
      #user-avatar { left: 0 !important; }
      #body { padding-left: var(--bilibili-video-comments-content-inset) !important; }
    `,
    'bili-comment-thread-renderer': `
      #div { margin-left: var(--bilibili-video-comments-content-inset) !important; }
    `,
    'bili-comment-replies-renderer': `
      #expander { padding-left: var(--bilibili-video-comments-content-inset) !important; }
    `,
    'bili-comments-header-renderer': `
      #disabled-commentbox #user-avatar {
        justify-content: flex-start !important;
        width: var(--bilibili-video-comments-content-inset) !important;
      }
    `,
    'bili-comment-action-buttons-renderer': `
      :host { flex-wrap: wrap !important; gap: 2px 12px; }
      :host > * { margin-left: 0 !important; }
      #more { margin-left: auto !important; margin-right: 0 !important; }
    `,
    'bili-comment-box': `
      #user-avatar {
        justify-content: flex-start !important;
        width: var(--bilibili-video-comments-content-inset) !important;
      }
      #comment-area {
        min-width: 0;
        width: calc(100% - var(--bilibili-video-comments-content-inset)) !important;
      }
      #footer { flex-wrap: wrap; gap: 6px 0; }
    `,
    'bili-comment-user-info': `
      #info { flex-wrap: wrap; max-width: 100%; }
      #user-name { overflow-wrap: anywhere; min-width: 0; }
    `,
    'bili-comment-goods-card': ':host { min-width: 0 !important; max-width: 100% !important; }',
  };
  // 遍历这些开放组件边界，不修改 attachShadow 或官方组件原型。
  const tags = ['bili-comments-bottom-fixed-wrapper', 'bili-comment-reply-renderer',
    ...Object.keys(shadowCSS)];
  const selector = tags.join(',');
  const roots = new Map();
  const style = document.createElement('style');
  style.dataset.bilibiliVideoCommentsStyle = '';
  style.textContent = css;
  html.append(style);
  let stopped = false;
  let frame = 0;

  const observer = new MutationObserver(schedule);
  function schedule() {
    if (!stopped && !frame) frame = requestAnimationFrame(sync);
  }
  function visit(root) {
    for (const host of root.querySelectorAll(selector)) {
      const shadow = host.shadowRoot;
      if (!shadow) continue;
      if (!roots.has(shadow)) {
        let localStyle = null;
        if (shadowCSS[host.localName]) {
          localStyle = document.createElement('style');
          localStyle.textContent = shadowCSS[host.localName];
          shadow.append(localStyle);
        }
        roots.set(shadow, localStyle);
        observer.observe(shadow, { childList: true, subtree: true });
      } else {
        const localStyle = roots.get(shadow);
        if (localStyle && localStyle.parentNode !== shadow) shadow.append(localStyle);
      }
      visit(shadow);
    }
  }
  function sync() {
    frame = 0;
    if (stopped) return;
    const type = pageType();
    // 只等首次可用；成功后不在 DOM 更新或手动重新开启时重复关闭。
    if (type && !danmakuInitialized) danmakuInitialized = disableBilibiliDanmaku();
    if (type) html.setAttribute(attr, type);
    else if (previous === null) html.removeAttribute(attr);
    else html.setAttribute(attr, previous);
    let detached = false;
    for (const [root, localStyle] of roots) {
      if (!type || !root.host.isConnected) {
        localStyle?.remove();
        roots.delete(root);
        detached = true;
      }
    }
    if (detached) {
      observer.disconnect();
      observer.observe(html, { childList: true, subtree: true });
      for (const root of roots.keys()) observer.observe(root, { childList: true, subtree: true });
    }
    if (type) visit(document);
  }
  observer.observe(html, { childList: true, subtree: true });
  window.addEventListener('popstate', schedule);
  // 已在 DOM 中但还未升级的组件，定义完成后再检查，不使用轮询。
  for (const tag of tags) customElements.whenDefined(tag).then(schedule);
  const controller = {
    destroy() {
      if (stopped) return;
      stopped = true;
      cancelAnimationFrame(frame);
      observer.disconnect();
      window.removeEventListener('popstate', schedule);
      for (const localStyle of roots.values()) localStyle?.remove();
      roots.clear();
      style.remove();
      if (previous === null) html.removeAttribute(attr);
      else html.setAttribute(attr, previous);
      if (window.bilibiliVideoComments === controller) delete window.bilibiliVideoComments;
    },
  };
  window.bilibiliVideoComments = controller;
  sync();
})();