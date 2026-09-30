(() => {
    'use strict';

    const TAG = '[BilibiliPotplayer/ChatScriptVod]';
    const SIDE_GAP = 8;
    const NARROW_MAX_WIDTH = 520;

    /*
     * ============================================================
     * 通用工具
     * ============================================================
     */

    function setImportantStyles(element, styles) {
        if (!element) return;

        for (const [property, value] of Object.entries(styles)) {
            element.style.setProperty(property, value, 'important');
        }
    }

    function addStyleOnce(id, css) {
        if (document.getElementById(id)) return;

        const style = document.createElement('style');
        style.id = id;
        style.textContent = css;
        document.head.appendChild(style);
    }

    /*
     * ============================================================
     * DOM 获取
     * ============================================================
     */

    function getUGCToolbox() {
        return document.querySelector('#arc_toolbar_report');
    }

    function getPGCToolbox() {
        return document.querySelector('.player-left-components > .toolbar');
    }

    function getUGCComment() {
        return document.querySelector('#commentapp > bili-comments');
    }

    function getPGCComment() {
        return document.querySelector('#comment-module #comment-body > bili-comments');
    }

    function getSendingArea() {
        return document.querySelector('.bpx-player-sending-area');
    }

    function getSendingBar() {
        return document.querySelector('.bpx-player-sending-bar');
    }

    /*
     * ============================================================
     * 基础功能
     * ============================================================
     */

    function disableBilibiliAutoPlay() {
        const el = document.querySelector(
            'input.bui-switch-input[aria-label*="自动开播"]'
        );

        if (!el) {
            console.log(TAG, '未找到自动开播开关');
            return false;
        }

        if (el.checked) {
            el.click();
            console.log(TAG, '已关闭自动开播');
        }

        return true;
    }

    function pauseBilibiliVideo() {
        for (const video of document.querySelectorAll('video')) {
            if (!video.paused && !video.ended) {
                video.pause();
                console.log(TAG, '已暂停正在播放的视频');
                return true;
            }
        }

        for (const iframe of document.querySelectorAll('iframe')) {
            try {
                const videos = iframe.contentDocument?.querySelectorAll('video');
                if (!videos) continue;

                for (const video of videos) {
                    if (!video.paused && !video.ended) {
                        video.pause();
                        console.log(TAG, '已暂停 iframe 中正在播放的视频');
                        return true;
                    }
                }
            } catch {
                continue;
            }
        }

        return false;
    }

    /*
     * ============================================================
     * 公共弹幕发送区
     * ============================================================
     */

    function setupSendingArea(sendingArea, sendingBar, toolbox) {
        if (!sendingArea || !sendingBar || !toolbox) {
            console.warn(TAG, '弹幕发送区域结构不完整');
            return false;
        }

        toolbox.parentElement.insertBefore(sendingArea, toolbox);

        setImportantStyles(sendingArea, {
            'margin-top': '8px',
            'margin-bottom': '0',
            border: '1px solid var(--line_regular, #2f3238)',
            'border-radius': '6px',
            overflow: 'hidden',
            'box-sizing': 'border-box'
        });

        toolbox.style.setProperty('margin-top', '8px', 'important');

        return true;
    }

    function applyCommonSendingLayout() {
        addStyleOnce(
            'bilibili-potplayer-common-sending-layout',
            `
            @media (max-width: ${NARROW_MAX_WIDTH}px) {
                .bpx-player-sending-area {
                    height: auto !important;
                    min-height: 0 !important;
                }

                .bpx-player-sending-bar {
                    display: grid !important;
                    grid-template-columns: minmax(0, 1fr) !important;
                    grid-template-rows: auto auto !important;
                    width: 100% !important;
                    min-width: 0 !important;
                    height: auto !important;
                    min-height: 0 !important;
                    padding: 0 !important;
                    box-sizing: border-box !important;
                }

                .bpx-player-video-info {
                    grid-column: 1 !important;
                    grid-row: 1 !important;
                    display: flex !important;
                    align-items: center !important;
                    position: static !important;
                    width: 100% !important;
                    min-width: 0 !important;
                    max-width: 100% !important;
                    height: auto !important;
                    min-height: 0 !important;
                    margin: 0 !important;
                    padding: 6px 12px 4px !important;
                    overflow: visible !important;
                    white-space: nowrap !important;
                    box-sizing: border-box !important;
                }

                .bpx-player-video-info-online,
                .bpx-player-video-info-dm {
                    flex: 0 0 auto !important;
                    position: static !important;
                    width: auto !important;
                    min-width: 0 !important;
                    height: auto !important;
                    margin: 0 !important;
                    padding: 0 !important;
                    line-height: 20px !important;
                    white-space: nowrap !important;
                }

                .bpx-player-video-info-divide {
                    display: block !important;
                    flex: 0 0 auto !important;
                    margin: 0 !important;
                    padding: 0 !important;
                    line-height: 20px !important;
                }

                .bpx-player-dm-root {
                    grid-column: 1 !important;
                    grid-row: 2 !important;
                    display: flex !important;
                    align-items: center !important;
                    position: static !important;
                    width: 100% !important;
                    min-width: 0 !important;
                    max-width: 100% !important;
                    height: auto !important;
                    min-height: 0 !important;
                    margin: 0 !important;
                    padding: 4px 8px 8px !important;
                    box-sizing: border-box !important;
                }

                .bpx-player-dm-switch,
                .bpx-player-dm-setting,
                .bpx-player-dm-btn-send {
                    flex: 0 0 auto !important;
                }

                .bpx-player-video-inputbar {
                    flex: 1 1 auto !important;
                    width: auto !important;
                    min-width: 0 !important;
                    max-width: none !important;
                }

                .bpx-player-video-inputbar-wrap {
                    display: flex !important;
                    width: 100% !important;
                    min-width: 0 !important;
                    max-width: 100% !important;
                    box-sizing: border-box !important;
                }

                .bpx-player-dm-input {
                    flex: 1 1 auto !important;
                    width: auto !important;
                    min-width: 0 !important;
                }
            }
            `
        );
    }

    /*
     * ============================================================
     * PGC 页面布局
     * ============================================================
     */

    function applyPGCFluidLayout() {
        addStyleOnce(
            'bilibili-potplayer-pgc-fluid-layout',
            `
            #__next,
            .home-container,
            .main-container,
            .plp-layout,
            .plp-player,
            .plp-left-wrap,
            .plp-l,
            .player-left-components {
                width: 100% !important;
                min-width: 0 !important;
                max-width: none !important;
                margin-left: 0 !important;
                margin-right: 0 !important;
                box-sizing: border-box !important;
            }

            #__next,
            .home-container,
            .main-container,
            .plp-layout {
                margin-top: 0 !important;
                margin-bottom: 0 !important;
                padding: 0 !important;
            }

            .main-container {
                position: static !important;
            }

            .plp-layout {
                display: block !important;
                grid-template-columns: none !important;
                grid-template-rows: none !important;
            }

            .bpx-player-sending-area,
            .player-left-components > .toolbar,
            #comment-module #comment-body > bili-comments {
                width: calc(100% - ${SIDE_GAP * 2}px) !important;
                min-width: 0 !important;
                max-width: calc(100% - ${SIDE_GAP * 2}px) !important;
                margin-left: ${SIDE_GAP}px !important;
                margin-right: ${SIDE_GAP}px !important;
                box-sizing: border-box !important;
            }

            #comment-module,
            #comment-body {
                width: 100% !important;
                min-width: 0 !important;
                max-width: none !important;
                margin: 0 !important;
                padding: 0 !important;
                box-sizing: border-box !important;
            }

            @media (max-width: ${NARROW_MAX_WIDTH}px) {
                .player-left-components > .toolbar {
                    display: grid !important;
                    grid-template-columns: repeat(4, minmax(0, 1fr)) !important;
                    grid-template-rows: auto auto !important;
                    column-gap: 0 !important;
                    row-gap: 4px !important;
                    align-items: center !important;
                    height: auto !important;
                    min-height: 0 !important;
                    padding: 6px 0 8px !important;
                    box-sizing: border-box !important;
                }

                .player-left-components > .toolbar .toolbar-left {
                    display: contents !important;
                }

                .player-left-components > .toolbar .toolbar-left > :nth-child(1) {
                    grid-column: 1 !important;
                    grid-row: 1 !important;
                }

                .player-left-components > .toolbar .toolbar-left > :nth-child(2) {
                    grid-column: 2 !important;
                    grid-row: 1 !important;
                }

                .player-left-components > .toolbar .toolbar-left > :nth-child(3) {
                    grid-column: 3 !important;
                    grid-row: 1 !important;
                }

                .player-left-components > .toolbar .toolbar-left > :nth-child(4) {
                    grid-column: 4 !important;
                    grid-row: 1 !important;
                }

                .player-left-components > .toolbar .toolbar-left > :nth-child(5) {
                    grid-column: 1 / span 2 !important;
                    grid-row: 2 !important;
                    justify-self: start !important;
                }

                .player-left-components > .toolbar .toolbar-right {
                    display: flex !important;
                    grid-column: 4 !important;
                    grid-row: 2 !important;
                    justify-self: end !important;
                    align-self: center !important;
                    width: auto !important;
                    height: auto !important;
                    margin: 0 !important;
                }

                .player-left-components > .toolbar .toolbar-left > *,
                .player-left-components > .toolbar .toolbar-right > * {
                    min-width: 0 !important;
                    margin-top: 0 !important;
                    margin-bottom: 0 !important;
                    white-space: nowrap !important;
                }
            }
            `
        );
    }

    /*
     * ============================================================
     * UGC 页面布局
     * ============================================================
     */

    function applyUGCFluidLayout() {
        addStyleOnce(
            'bilibili-potplayer-ugc-fluid-layout',
            `
            #mirror-vdcon,
            #mirror-vdcon > .left-container,
            #commentapp {
                width: 100% !important;
                min-width: 0 !important;
                max-width: none !important;
                margin-left: 0 !important;
                margin-right: 0 !important;
                box-sizing: border-box !important;
            }

            .bpx-player-sending-area,
            #arc_toolbar_report,
            #commentapp > bili-comments {
                width: calc(100% - ${SIDE_GAP * 2}px) !important;
                min-width: 0 !important;
                max-width: calc(100% - ${SIDE_GAP * 2}px) !important;
                margin-left: ${SIDE_GAP}px !important;
                margin-right: ${SIDE_GAP}px !important;
                box-sizing: border-box !important;
            }

            #arc_toolbar_report {
                height: auto !important;
            }

            #commentapp {
                padding: 0 !important;
            }

            @media (max-width: ${NARROW_MAX_WIDTH}px) {
                #arc_toolbar_report {
                    display: grid !important;
                    grid-template-columns: minmax(0, 1fr) !important;
                    grid-template-rows: auto auto !important;
                    row-gap: 4px !important;
                    align-items: center !important;
                    height: auto !important;
                    min-height: 0 !important;
                    padding-top: 6px !important;
                    padding-bottom: 8px !important;
                    box-sizing: border-box !important;
                }

                #arc_toolbar_report > .video-toolbar-left {
                    grid-column: 1 !important;
                    grid-row: 1 !important;
                    display: block !important;
                    width: 100% !important;
                    min-width: 0 !important;
                    max-width: 100% !important;
                    margin: 0 !important;
                }

                #arc_toolbar_report .video-toolbar-left-main {
                    display: grid !important;
                    grid-template-columns: repeat(4, minmax(0, 1fr)) !important;
                    width: 100% !important;
                    min-width: 0 !important;
                    max-width: 100% !important;
                    margin: 0 !important;
                    padding: 0 !important;
                }

                #arc_toolbar_report .video-toolbar-left-main > .toolbar-left-item-wrap {
                    display: flex !important;
                    align-items: center !important;
                    justify-content: center !important;
                    width: auto !important;
                    min-width: 0 !important;
                    margin: 0 !important;
                    padding: 0 !important;
                }

                #arc_toolbar_report .video-toolbar-left-main > .toolbar-left-item-wrap > .video-toolbar-left-item {
                    min-width: 0 !important;
                    margin: 0 !important;
                    white-space: nowrap !important;
                }

                #arc_toolbar_report > .video-toolbar-right {
                    grid-column: 1 !important;
                    grid-row: 2 !important;
                    display: flex !important;
                    align-items: center !important;
                    justify-content: flex-end !important;
                    flex-wrap: nowrap !important;
                    width: 100% !important;
                    min-width: 0 !important;
                    max-width: 100% !important;
                    height: auto !important;
                    margin: 0 !important;
                    padding: 0 !important;
                    gap: 12px !important;
                    box-sizing: border-box !important;
                }

                #arc_toolbar_report > .video-toolbar-right > * {
                    flex: 0 0 auto !important;
                    min-width: 0 !important;
                    margin-top: 0 !important;
                    margin-bottom: 0 !important;
                    white-space: nowrap !important;
                }

                #arc_toolbar_report .video-toolbar-item-text {
                    white-space: nowrap !important;
                }
            }
            `
        );
    }

    /*
     * ============================================================
     * 评论区 Shadow DOM
     * ============================================================
     */

    function getCommentShadowStyle(host) {
        const tag = host?.localName;
        if (!tag) return null;

        if (tag === 'bili-comment-renderer') {
            return `
                @media (max-width: ${NARROW_MAX_WIDTH}px) {
                    #body,
                    #main {
                        min-width: 0 !important;
                        max-width: 100% !important;
                    }

                    #header {
                        display: flex !important;
                        flex-direction: column !important;
                        align-items: flex-start !important;
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        height: auto !important;
                    }

                    #header > bili-comment-user-info {
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                    }

                    #ornament {
                        display: block !important;
                        flex: none !important;
                        width: 288px !important;
                        max-width: 100% !important;
                        height: 48px !important;
                        margin-top: 2px !important;
                    }

                    #content {
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        overflow-wrap: anywhere !important;
                        word-break: break-word !important;
                    }

                    #footer {
                        display: block !important;
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        height: auto !important;
                        margin-top: 4px !important;
                    }
                }
            `;
        }

        if (tag === 'bili-comment-reply-renderer') {
            return `
                @media (max-width: ${NARROW_MAX_WIDTH}px) {
                    #body,
                    #main,
                    #content,
                    #footer {
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        box-sizing: border-box !important;
                    }

                    #content {
                        overflow-wrap: anywhere !important;
                        word-break: break-word !important;
                    }

                    #footer {
                        display: block !important;
                        height: auto !important;
                    }
                }
            `;
        }

        if (tag === 'bili-comment-action-buttons-renderer') {
            return `
                @media (max-width: ${NARROW_MAX_WIDTH}px) {
                    :host {
                        display: flex !important;
                        flex-wrap: wrap !important;
                        align-items: center !important;
                        align-content: flex-start !important;
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        height: auto !important;
                        min-height: 0 !important;
                        column-gap: 12px !important;
                        row-gap: 4px !important;
                        box-sizing: border-box !important;
                    }

                    #pubdate,
                    #like,
                    #dislike,
                    #reply,
                    #more {
                        display: inline-flex !important;
                        align-items: center !important;
                        flex: 0 0 auto !important;
                        width: auto !important;
                        min-width: max-content !important;
                        max-width: none !important;
                        margin: 0 !important;
                        padding: 0 !important;
                        white-space: nowrap !important;
                        word-break: keep-all !important;
                        overflow-wrap: normal !important;
                    }

                    #pubdate .ip-location {
                        display: inline-block !important;
                        flex: 0 0 auto !important;
                        width: auto !important;
                        min-width: max-content !important;
                        margin-left: 15px !important;
                        white-space: nowrap !important;
                        word-break: keep-all !important;
                        overflow-wrap: normal !important;
                    }

                    #like button,
                    #dislike button,
                    #reply button,
                    #more button {
                        display: inline-flex !important;
                        align-items: center !important;
                        flex: 0 0 auto !important;
                        width: auto !important;
                        min-width: max-content !important;
                        white-space: nowrap !important;
                        word-break: keep-all !important;
                    }
                }
            `;
        }

        if (tag === 'bili-comment-box') {
            return `
                @media (max-width: ${NARROW_MAX_WIDTH}px) {
                    :host {
                        display: grid !important;
                        grid-template-columns: 48px minmax(0, 1fr) !important;
                        column-gap: 12px !important;
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        padding: 12px 0 10px !important;
                        box-sizing: border-box !important;
                    }

                    #user-avatar {
                        grid-column: 1 !important;
                        width: 48px !important;
                        min-width: 48px !important;
                        max-width: 48px !important;
                    }

                    #comment-area {
                        grid-column: 2 !important;
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        margin: 0 !important;
                        box-sizing: border-box !important;
                    }

                    #body,
                    #editor {
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        box-sizing: border-box !important;
                    }

                    #pub {
                        flex: 0 0 auto !important;
                        white-space: nowrap !important;
                    }
                }
            `;
        }

        if (tag === 'bili-comment-rich-textarea') {
            return `
                @media (max-width: ${NARROW_MAX_WIDTH}px) {
                    :host,
                    #input,
                    .brt-root,
                    .brt-editor {
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        box-sizing: border-box !important;
                    }

                    :host {
                        display: block !important;
                    }

                    .brt-placeholder {
                        max-width: 100% !important;
                        white-space: normal !important;
                        overflow-wrap: break-word !important;
                    }
                }
            `;
        }

        if (tag === 'bili-comment-thread-renderer') {
            return `
                @media (max-width: ${NARROW_MAX_WIDTH}px) {
                    :host,
                    #replies,
                    #reply-container,
                    #div {
                        width: 100% !important;
                        min-width: 0 !important;
                        max-width: 100% !important;
                        box-sizing: border-box !important;
                    }

                    :host {
                        display: block !important;
                    }
                }
            `;
        }

        return null;
    }

    function applyCommentShadowLayout(comment) {
        if (!comment) return;

        const observedRoots = new WeakSet();

        const observer = new MutationObserver(mutations => {
            for (const mutation of mutations) {
                for (const node of mutation.addedNodes) {
                    if (!(node instanceof Element)) continue;

                    scanElement(node);
                    queueMicrotask(() => scanElement(node));
                }
            }
        });

        function injectShadowStyle(root) {
            const css = getCommentShadowStyle(root.host);
            if (!css) return;

            const styleId = `potplayer-comment-narrow-${root.host.localName}`;

            if (root.querySelector(`style[data-potplayer-style="${styleId}"]`)) return;

            const style = document.createElement('style');
            style.dataset.potplayerStyle = styleId;
            style.textContent = css;
            root.prepend(style);
        }

        function scanShadowRoot(root) {
            if (!root) return;

            injectShadowStyle(root);

            if (!observedRoots.has(root)) {
                observer.observe(root, { childList: true, subtree: true });
                observedRoots.add(root);
            }

            for (const element of root.querySelectorAll('*')) {
                if (element.shadowRoot) scanShadowRoot(element.shadowRoot);
            }
        }

        function scanElement(element) {
            if (!element) return;

            if (element.shadowRoot) scanShadowRoot(element.shadowRoot);

            for (const child of element.querySelectorAll('*')) {
                if (child.shadowRoot) scanShadowRoot(child.shadowRoot);
            }
        }

        scanElement(comment);
        observer.observe(comment, { childList: true, subtree: true });
    }

    /*
     * ============================================================
     * 页面裁剪
     * ============================================================
     */

    function keepPath(keep, element) {
        let node = element;

        while (node) {
            keep.add(node);
            node = node.parentElement;
        }
    }

    function hideOtherBranches(parent, keep, visibleElements) {
        for (const child of parent.children) {
            if (visibleElements.has(child)) continue;

            if (keep.has(child)) {
                hideOtherBranches(child, keep, visibleElements);
            } else {
                child.style.setProperty('display', 'none', 'important');
            }
        }
    }

    function resetDocumentLayout() {
        const styles = {
            margin: '0',
            padding: '0',
            width: '100%',
            'min-width': '0',
            'max-width': 'none',
            height: 'auto',
            'min-height': '0',
            'overflow-x': 'hidden',
            'overflow-y': 'auto',
            'box-sizing': 'border-box'
        };

        setImportantStyles(document.documentElement, styles);
        setImportantStyles(document.body, styles);
    }

    function resetCommentAncestorLayout(comment) {
        let parent = comment.parentElement;

        while (
            parent &&
            parent !== document.body &&
            parent !== document.documentElement
        ) {
            setImportantStyles(parent, {
                position: 'static',
                display: 'block',
                float: 'none',
                width: '100%',
                'min-width': '0',
                'max-width': 'none',
                height: 'auto',
                'min-height': '0',
                margin: '0',
                padding: '0',
                transform: 'none',
                overflow: 'visible',
                'box-sizing': 'border-box'
            });

            parent = parent.parentElement;
        }
    }

    function styleCommentHost(comment, pageType) {
        setImportantStyles(comment, {
            display: 'block',
            position: 'static',
            float: 'none',
            'min-width': '0',
            height: 'auto',
            'min-height': '0',
            padding: '0',
            transform: 'none',
            'box-sizing': 'border-box'
        });

        if (pageType === 'PGC') {
            setImportantStyles(comment, {
                'margin-top': '12px',
                'margin-bottom': '0'
            });
        } else {
            setImportantStyles(comment, {
                width: `calc(100% - ${SIDE_GAP * 2}px)`,
                'max-width': `calc(100% - ${SIDE_GAP * 2}px)`,
                margin: `12px ${SIDE_GAP}px 0`
            });
        }
    }

    /*
     * ============================================================
     * 页面识别
     * ============================================================
     */

    function detectPage() {
        const ugcToolbox = getUGCToolbox();

        if (ugcToolbox) {
            return {
                type: 'UGC',
                toolbox: ugcToolbox,
                comment: getUGCComment()
            };
        }

        const pgcToolbox = getPGCToolbox();

        if (pgcToolbox) {
            return {
                type: 'PGC',
                toolbox: pgcToolbox,
                comment: getPGCComment()
            };
        }

        return null;
    }

    /*
     * ============================================================
     * 主流程
     * ============================================================
     */

    function showBilibiliCommentsAndToolbox() {
        const page = detectPage();

        if (!page) {
            console.error(TAG, '无法识别 UGC / PGC 页面');
            return false;
        }

        if (!page.comment) {
            console.error(TAG, '未找到 bili-comments');
            return false;
        }

        const sendingArea = getSendingArea();
        const sendingBar = getSendingBar();

        applyCommonSendingLayout();

        if (page.type === 'PGC') {
            applyPGCFluidLayout();
        } else {
            applyUGCFluidLayout();
        }

        setupSendingArea(sendingArea, sendingBar, page.toolbox);

        page.toolbox.style.setProperty(
            'border-bottom',
            '1px solid var(--line_regular, #2f3238)',
            'important'
        );

        const keep = new Set();
        const visibleElements = new Set([page.comment, page.toolbox]);

        keepPath(keep, page.comment);
        keepPath(keep, page.toolbox);

        if (sendingArea) {
            keepPath(keep, sendingArea);
            visibleElements.add(sendingArea);
        }

        hideOtherBranches(document.documentElement, keep, visibleElements);

        resetDocumentLayout();
        resetCommentAncestorLayout(page.comment);
        styleCommentHost(page.comment, page.type);
        applyCommentShadowLayout(page.comment);

        window.scrollTo({ top: 0, left: 0, behavior: 'instant' });

        return true;
    }

    /*
     * ============================================================
     * 入口
     * ============================================================
     */

    let pageDone = false;
    let autoPlayDone = false;
    let videoDone = false;

    function processPage() {
        if (!autoPlayDone) autoPlayDone = disableBilibiliAutoPlay();
        if (!videoDone) videoDone = pauseBilibiliVideo();
        if (!pageDone) pageDone = showBilibiliCommentsAndToolbox();

        if (pageDone && autoPlayDone && videoDone) observer.disconnect();
    }

    const observer = new MutationObserver(processPage);
    observer.observe(document, { childList: true, subtree: true });
    processPage();
})();