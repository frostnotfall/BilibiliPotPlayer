# PotPlayer 1.7.23156 接入说明

## 安装与版本

当前源码最低支持 **64 位 PotPlayer 1.7.23156**。请一起更新 `Extension/Media/PlayParse`、`Extension/Playback/Statistics` 和 `Extension/Lib` 中的项目文件，保留个人配置时合并新的配置注释。修改配置后重新加载扩展或重启播放器。

PlaybackStatistics 直接调用此版本注册的 `string HostGetCookie()`；旧版若缺少该函数，会在 AngelScript 编译时失败，运行时版本判断不能解决此问题。本次不提供旧版兼容分支。

## 登录与 Cookie

MediaPlayParse 和 PlaybackStatistics 分别声明相同的站点：

| 声明 | 值 |
| --- | --- |
| `GetWebAccountUrl()` | `https://passport.bilibili.com/login` |
| `GetWebAccountDomain()` | `www.bilibili.com;bilibili.com` |

两份声明独立初始化，并通过回归检查防止配置不一致。第一个域名 `www.bilibili.com` 是 `HostGetCookie()` 的查询站点，可获取构造直播请求参数所需的非 HttpOnly `bili_jct`；父域覆盖登录、直播、动态、空间等 Bilibili 子站。CDN 域名继续用于 HTTP User-Agent/Referer 设置，不作为登录 Cookie 的同步域。

在播放器的网页登录窗口登录即可。两类脚本由 PotPlayer 按站点复用登录状态，不传递、缓存或手工覆盖完整 Cookie。常规请求保留默认 `NoCookie=false`，由播放器发送适用的 Cookie，包括 HttpOnly 字段。getter 不返回 HttpOnly 字段，缺少这些字段不能判断为未登录。

直播心跳在实际后台请求开始时读取一次 Cookie，优先提取其中的 `bili_jct` 并 URL 编码，用于 CSRF 参数。如果原生 Cookie 没有此字段或字段为空，则沿用旧方式：MediaPlayParse 读取配置文件根级的 `bili_jct`，通过 `BilibiliPotPlayer.BiliJct()` 临时存储交给 PlaybackStatistics 作为后备。该配置默认空；配置缺失或清空时也会清除临时存储中的旧值。两种来源均为空时跳过这次操作；服务器返回失败时沿用错误提示，不新增重试。后备只提供 CSRF 参数，不替代原生登录 Cookie。不会在 `OnInitialize()` 中读取或永久缓存 Cookie，也不会打印带 CSRF 的请求 URL。点播和直播心跳均遵守 `heartBeat` 开关，原有后台线程方式及弹幕姬连接/断开回调保留。

`直播/VOD` 默认浏览 `www.bilibili.com`、`t.bilibili.com`，与上述站点声明一致。浏览后的同步、每 60 秒同步，以及关闭/切换时保存均由 PotPlayer 原生完成。项目没有另加 Cookie 定时保存、续期或浏览器服务；登录失效时可在网页登录窗口刷新登录状态，网站是否续期仍取决于网站。

## 历史标识与起播

普通视频使用解析后分段的 `cid` 字符串，番剧使用解析后真实分集的 `epid` 字符串。BV/av 入口规范为 BV 视频网页，保留实际分段 `p`；ss/md 入口规范为真实 ep 网页。视频跳转至番剧时也采用真实 ep。画质、编码、临时 CDN 地址不参与历史键，直播保留原有标识和行为。

PotPlayer 以 `webUrl` 的域名与 `vid` 组合记忆位置及音轨/字幕轨道。项目不新增播放进度数据库。普通视频原来的 `cid` 格式保留；番剧从旧的 `bvid` 改为 `epid` 后，旧键下的历史不会自动迁移，首次需重新积累记录。

点播起播按两种情况处理：存在 `t` 时，将其数值秒数转为整数，例如 `t=90.9` 截为 90 秒；不存在 `t` 时，通过 Bilibili 网页端最新进度接口查询，匹配当前 `cid` 后将毫秒除以 1000，再转为整数秒。`t` 即使为空或无效也不会改用网页历史。小于一秒、零、负数、溢出或非法值不设置 `seek`。URL 的 `t` 单位是秒，不能把 `t=90000` 当作 90 秒；这里不额外扩展时分秒字符串格式。

配置项 `vod.queryPlayPosition` 控制无 `t` 时是否查询 `/x/player/wbi/v2`，默认 `false`，旧配置未填写时也默认关闭。设为 `true` 后，普通视频与番剧会查询网页进度；关闭时无 `t` 不设置 `seek`，由 PotPlayer 恢复自身历史。显式 `t` 不受此开关影响。修改配置后重新加载扩展或重启播放器。

优先级由播放器执行：**命令行、播放列表位置等显式位置 > `MetaData["seek"]` > 播放器历史**。有 `t` 时它优先于网页历史；没有 `t` 时使用网页进度；网页进度请求失败、登录失效、没有记录或不属于当前分段时省略 `seek`，由播放器恢复自身历史，不弹窗阻断播放。质量列表只包含播放流 URL，不携带首次起播的 `t`，切换画质由播放器保持当前位置。BV/av 重定向至番剧、生成当前分集链接时，拼接原链接的查询参数，再由原有 `makeWebUrl()` 保留 `t`、`p`；多 P 列表的当前条目直接复用原链接。其他条目不继承这些参数。时间在播放解析阶段转换为有效整数秒，章节与列表时长原有毫秒单位保持不变。

2026-10-19 已再次通过内置浏览器捕获普通视频与番剧网页播放器请求：`GET https://api.bilibili.com/x/player/wbi/v2`，包含 `aid`、`cid` 及 WBI 等参数，番剧网页还附带 `ep_id`、`season_id`。响应包含 `last_play_time`、`last_play_cid`；当日页面加载的官方 `core.147ce847.js`、`core.ba67b466.js` 将历史时间除以 1000 转为秒，并匹配分段。实现复用现有 WBI 签名及原生 Cookie HTTP 请求，番剧附带 `ep_id`，进度请求不经过扩展响应缓存。这是当日网页实测接口，不取自旧网络文档。

## 聊天窗口与辅助工具

已有的点播/番剧及官方直播聊天页面通过有效 `chatUrl` 配合 `chatScript` 加载。AngelScript 只读取 JS 文件、去除 UTF-8 BOM 并传递内容，处理缺失/打不开的文件；`GetBroadcastListScript()` 同样直接返回对应 JS 内容。文档创建时机、DOM 就绪、重复注入、动态 DOM、样式、点击和快捷键均由各自 JS 负责，AngelScript 不再额外包装或增加事件监听。

仓库中的 `injector.py` 只服务于聊天 JS 的外部 CDP 注入，现已删除；聊天不再需要该进程或 websocket-client。用户系统级 WebView2 调试环境设置保持不变，仓库之外的工具和进程未修改。

以下组件仍有实际用途，因此保留：

- `Bilibili - BroadcastListScript.js`：直播/VOD 浏览、布局与视频点击。
- `Bilibili - ChatScriptVod.js`、`Bilibili - ChatScriptLive.js`：聊天页面样式、交互和动态 DOM 处理，由原生接口注入。
- `BilibiliRegex.dll` 与 Native 构建/测试工具：内置弹幕的正则过滤。
- 可选 Bilibili_Danmuji 服务及统计脚本连接回调：第三方直播弹幕窗口；该页面沿用服务自己的实现，不注入官方直播页面脚本。
- 可选字幕/弹幕服务、空降助手及画质/音频解析代码：功能用途不变。

## 自动检查与人工验收

仓库现有检查命令：

```powershell
python Native/BilibiliRegex/tests/verify.py
python Native/BilibiliRegex/tests/verify_integration.py --sdk D:/src/angelscript
git diff --check
```

集成检查需要官方 AngelScript SDK、Visual Studio C++ 工具链、Python 和 Node。测试从生产脚本提取实际的起播/Cookie/JS 文件读取函数及直播心跳控制流程，在官方 AngelScript 运行时执行；Cookie、JSON、HTTP 和播放回调使用测试替身，不访问用户 Cookie 或实际发送心跳。覆盖有 `t` 时不查询进度、数值秒转换、无 `t` 时请求网页进度、毫秒转换、分段匹配、登录失效/空响应/非法 JSON/缺失数据、非法及溢出时间、Cookie 精确字段提取、心跳开关和 JS 内容直接读取；同时核对元数据赋值及 URL 参数嫁接。Node 另检查原聊天 JS 的语法。原有真实 x64 DLL、过滤、字幕 ASS、排序、分段收集和日志回归继续执行。

这些检查没有编译完整 PotPlayer 宿主脚本或完成真实播放验收。最小人工验收如下：

1. 更新文件并重启 PotPlayer 1.7.23156 或更新的 64 位版本，启用“记忆播放位置”等相关选项；在网页登录窗口登录。打开直播/VOD 浏览动态或空间页面，关闭后重开/重启，确认登录仍可用。
2. 选一个多 P 视频，在 P1 播放至中途，选择音轨/字幕后关闭；分别用 BV、av 入口重开同一 P，确认恢复。P2 应有独立记录。分别用 ss、ep 入口重开同一番剧分集，确认记录一致，另一集独立。
3. 对已有记录的视频打开 `?t=90.9`（有分 P 时用 `&t=90.9`），确认约 90 秒起播；播放前进后切换画质/编码，确认保持当前位置。先在网页端留下当前分段的进度，再用无 `t` 的普通链接打开，确认应用网页进度；没有可用网页进度时确认仍可播放并使用播放器自身历史。用命令行/播放列表另指定位置，确认其优先。直播不套用点播起播参数。
4. 启用点播聊天及官方直播聊天开关，打开/刷新/切换聊天页面，确认评论、布局、时间点击及快捷键正常；无需启动旧 injector。需要时另测弹幕姬模式。
5. 开启 `heartBeat`，播放普通视频及直播，确认站点历史/心跳没有认证错误；更新登录后重试，关闭播放器确认退出正常。关闭开关后确认不再发起心跳。抽查原画质/音频选择、内置字幕、弹幕与章节，确认继续正常工作。
