(() => {
  'use strict';
  if (!/^\/(?:blanc\/)?\d+\/?$/.test(location.pathname)) return;
  window.bilibiliLiveChat?.destroy();

  function pauseVideo(doc = document) {
    doc.querySelector('video')?.pause();
    for (const iframe of doc.querySelectorAll('iframe')) {
      let child;
      try { child = iframe.contentDocument; } catch { continue; }
      if (child) pauseVideo(child);
    }
  }
  pauseVideo();

  // 页面升级时，只需在这里补充新的弹出层根选择器。
  const popups = [
    '.common-popup-wrap', '.gift-sender-panel', '.gift-panel-box',
    '.danmaku-menu', '.fansmedal-popover-wrap', '.blive-tooltip',
    '#head-info-vm .more-panel', '#head-info-vm .room-manage-panel',
    '#head-info-vm .head-share-qr-popover', '#game-id',
    '.side-bar-cntr:has(> .side-bar-toggle)', '#sidebar-vm .side-bar-popup-cntr',
    '[role="dialog"]', '[role="tooltip"]',
  ].join(',');

  // 不移动或克隆 Vue 节点；保留父容器尺寸，供原生面板和播放器测量。
  const style = document.createElement('style');
  style.id = 'bilibili-live-chat-style';
  style.textContent = `
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
      & .side-bar-cntr:has(> .side-bar-toggle) {
        display: block !important; position: fixed !important;
        top: 50dvh !important;
        left: auto !important; right: 8px !important; bottom: auto !important;
        box-sizing: content-box !important;
        transform: translateY(-50%) !important; transition: none !important;
        pointer-events: auto !important; background: #222; border-radius: 8px;
        & > .side-bar-toggle {
          position: absolute; right: 100%; top: 50%; transform: translateY(-50%);
          width: 16px; height: 40px; padding: 0; box-sizing: border-box;
          border: 1px solid #ffffff60; border-right: 0; border-radius: 6px 0 0 6px;
          background: #333; color: #fff; font: bold 20px/38px sans-serif;
          box-shadow: 0 1px 4px #0006; cursor: pointer; user-select: none;
        }
        &.collapsed {
          width: 0 !important; height: 40px !important; padding: 0 !important;
          border: 0 !important; background: transparent !important;
          & > :not(.side-bar-toggle) { display: none !important; }
        }
      }

      & .player-and-aside-area {
        position: fixed !important; inset: 0 !important;
        display: block !important; pointer-events: none;
        width: 100% !important;
        height: 100dvh !important;
        min-width: 0 !important; margin: 0 !important;
        padding: 0 !important; gap: 0 !important;
        background: #101010; overflow: visible !important;
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
        margin: 0 !important; overflow: visible !important; z-index: 10 !important;
      }
      & #rank-list-vm, & #chat-control-panel-vm { flex-shrink: 0 !important; }
      & #aside-area-vm .chat-history-panel {
        flex: 1 1 0 !important; min-height: 0 !important;
        overflow: visible !important;
      }
      & #chat-history-list { overflow: auto !important; overscroll-behavior: contain; }
      & #chat-items { overflow-wrap: anywhere; }
      & #gift-screen-animation-vm { overflow: visible !important; pointer-events: none; }

      /* 视频画面与业务层是兄弟节点：保留业务注入层和官方动画遮罩。 */
      & .player-section {
        position: absolute !important; inset: 0 0 var(--blc-gift-height, 84px) !important;
        width: 100% !important; height: auto !important;
        min-width: 0 !important; min-height: 0 !important;
        background: transparent !important; overflow: visible !important;
        pointer-events: none !important; z-index: 20 !important;
      }
      & #live-player > :not(.web-player-inject-wrap):not(#animation-mask-wrapper) { display: none !important; }
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
    }
  `;
  document.head.append(style);
  document.documentElement.setAttribute('data-bilibili-live-chat', '');

  const root = document.documentElement;
  const dimensions = ['--blc-head-height', '--blc-gift-height', '--blc-pk-scale'];
  const oldDimensions = dimensions.map(name => [root.style.getPropertyValue(name), root.style.getPropertyPriority(name)]);
  let measured = [];
  const sizes = new ResizeObserver(schedule);
  const sidebars = new Map();
  function syncSidebars() {
    for (const [el, state] of sidebars) {
      if (!el.isConnected || !el.matches('.side-bar-cntr')) {
        state.destroy(); sidebars.delete(el);
      } else if (state.handle.parentElement !== el) el.append(state.handle);
    }
    for (const el of document.querySelectorAll('.side-bar-cntr')) {
      if (sidebars.has(el)) continue;
      const collapsed = el.classList.contains('collapsed');
      const handle = document.createElement('button');
      handle.type = 'button'; handle.className = 'side-bar-toggle';
      handle.title = '点击展开或收起';
      function toggle() {
        const open = !el.classList.toggle('collapsed');
        handle.textContent = open ? '<' : '>';
        handle.setAttribute('aria-label', open ? '收起侧栏' : '展开侧栏');
        schedule();
      }
      handle.onclick = toggle;
      sidebars.set(el, { handle, destroy() {
        handle.remove(); el.classList.toggle('collapsed', collapsed);
      } });
      el.classList.remove('collapsed'); el.append(handle); toggle();
    }
  }
  function measure() {
    let availableHeight = innerHeight;
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
        root.style.setProperty(dimensions[index], value);
      }
    });
    const scale = String(Math.max(0, Math.min(1, root.clientWidth / 700, availableHeight / 410)));
    if (root.style.getPropertyValue(dimensions[2]) !== scale) root.style.setProperty(dimensions[2], scale);
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
  let frame = 0;
  function fitPopups() {
    frame = 0;
    syncSidebars();
    measure();
    for (const [el, saved] of shifted) {
      if (!el.isConnected || !el.matches(popups)) {
        restoreTranslate(el, saved);
        shifted.delete(el);
      }
    }
    for (const el of document.querySelectorAll(popups)) {
      if (el.parentElement?.closest(popups)) continue;
      const box = el.getBoundingClientRect(), handle = sidebars.get(el)?.handle.getBoundingClientRect();
      // 侧栏把手在主体左侧；收起后宽度为零，仍按可见把手修正边界。
      const rect = handle ? {
        left: handle.left, top: Math.min(box.top, handle.top),
        width: Math.max(box.right, handle.right) - handle.left, height: Math.max(box.height, handle.height),
      } : box;
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
      el.style.setProperty('translate', `calc(${baseX} + ${x}px) calc(${baseY} + ${y}px) ${baseZ}`, 'important');
    }
  }
  function schedule() { if (!frame) frame = requestAnimationFrame(fitPopups); }
  function restoreTranslate(el, saved) {
    if (saved.value) el.style.setProperty('translate', saved.value, saved.priority);
    else el.style.removeProperty('translate');
  }
  const animationLayers = '#businessContainerElement .pk-animation-box,#player-effect-vm,#gift-screen-animation-vm,#animation-mask-wrapper';
  const observer = new MutationObserver(records => {
    // 动画帧的 style/class 更新无需重测弹窗；节点增删和弹窗变化仍正常处理。
    if (records.some(({ type, target }) => type === 'childList' || !target.closest(animationLayers) || target.closest(popups))) schedule();
  });
  observer.observe(document.body, {
    childList: true, subtree: true, attributes: true,
    attributeFilter: ['style', 'class', 'hidden'],
  });
  window.addEventListener('resize', schedule);
  window.addEventListener('scroll', schedule, true);
  document.addEventListener('pointerover', schedule, true);
  document.addEventListener('focusin', schedule, true);
  syncSidebars();
  measure();
  schedule();
  window.bilibiliLiveChat = {
    destroy() {
      observer.disconnect();
      sizes.disconnect();
      cancelAnimationFrame(frame);
      window.removeEventListener('resize', schedule);
      window.removeEventListener('scroll', schedule, true);
      document.removeEventListener('pointerover', schedule, true);
      document.removeEventListener('focusin', schedule, true);
      for (const [el, saved] of shifted) restoreTranslate(el, saved);
      for (const state of sidebars.values()) state.destroy();
      sidebars.clear();
      dimensions.forEach((name, i) => {
        if (oldDimensions[i][0]) root.style.setProperty(name, ...oldDimensions[i]);
        else root.style.removeProperty(name);
      });
      style.remove();
      document.documentElement.removeAttribute('data-bilibili-live-chat');
      delete window.bilibiliLiveChat;
      window.dispatchEvent(new Event('resize'));
    },
  };
  // 让按窗口大小计算位置的原生面板重新测量。
  window.dispatchEvent(new Event('resize'));
})();
