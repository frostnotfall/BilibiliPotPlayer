# BilibiliPotPlayer

适用于 PotPlayer 的 Bilibili 插件。如果配合[油猴脚本](#油猴脚本)，可以直接在网页打开 PotPlayer 进行播放

本项目基于 [chen310/BilibiliPotPlayer](https://github.com/chen310/BilibiliPotPlayer) 及其上游版本 [juening2000/BilibiliPotPlayer](https://github.com/juening2000/BilibiliPotPlayer) 进行维护，并针对个人使用需求持续进行功能改进、Bug 修复和测试。

如果上游项目恢复持续更新，本项目将优先向上游提交相关改进，并根据上游项目的维护情况决定是否继续维护本项目。


## ✨ 主要改进

### 🔐 直接网页登录，免手动配置 Cookie

相较于原版本[chen310/BilibiliPotPlayer](https://github.com/chen310/BilibiliPotPlayer) 和上游版本[juening2000/BilibiliPotPlayer](https://github.com/juening2000/BilibiliPotPlayer)，本项目对 Bilibili 登录方式进行了较大的改进：

- **无需手动获取、复制和配置 Cookie**
- 通过**网页登录**完成账号认证
- 登录流程更加直观，降低使用门槛
- 登录状态由程序自动处理
- 对普通用户更加友好

> 如果你不希望手动获取 Cookie，这是本项目与上游版本最明显的区别。

## 其它改进

### 🔧 整体优化
- 本地缓存响应数据，降低 API 请求次数。可在配置文件中设置，默认300s。
- 清理无用代码，较为激进，有问题请提issue。
- 换用新的 itag 选择机制。

### 📺 直播

- 支持 AVC、HEVC、AV1
- 默认使用低延迟的 HLS/fMP4 流，无法提供时回退至 HLS/TS。
- 支持直播备用地址。
- 动态生成直播画质选项。
- 增加 解析真实 M3U8 开关。规避画质选项 potplayer 自动覆盖成 HLS 的问题。详见配置项注释。
- 支持 [Bilibili_Danmuji](https://github.com/BanqiJane/Bilibili_Danmuji)，增加 potplayer 收发弹幕功能。需自建 Bilibili_Danmuji 服务，详见配置项注释。

### ▶️ 点播

- 支持屏蔽 P2PCDN，可通过配置文件调整，默认屏蔽
- 修复部分 Host 为 `upos` 的点播 URL 播放失败的问题
- Bilibili 点播更换新接口，尽量使用wbi签名认证防止接口失效
- 重新支持用户合集视频，并支持多合集，potplayer 播放列表( 快捷键 <kbd>F6</kbd> ) 正确显示合集视频。
  - 当存在用户视频合集时，播放列表里只展示合集视频。
  - 当只存在单个视频时，播放列表里包含当前视频与推荐视频（是否包含推荐视频取决于配置文件`showRecommendedVideos`开关）
- 播放番剧，电视剧等其它PGC合集或用户合集时，正确定位当前视频，不会出现从第一集开始播放的问题
- 支持AV播放地址
- 优化 Bilibili 音频画质选项显示：
  - `EC-3` → **杜比全景声**
  - `FLAC` → **Hi-Res 无损**
- 当同时存在杜比全景声与Hi-Res无损时，默认使用Hi-Res无损。
- 视频与播放列表增加多项属性，如果你足够细心的话，就可以发现。
- 增加 [空降助手](https://github.com/hanydd/BilibiliSponsorBlock) 支持。通过配置文件设置，默认禁用。

   另外支持指定镜像站点，以解决主站访问不稳定的问题。（由于目前主站访问不稳定，镜像站是临时的，所以默认禁用。）  

- 换用新的画质选项名称生成逻辑，现在动态获取，与官方名称一致。
- 画质选项增加更多属性。
- 增加 disableAVC 和 preferHDR 设置。
- 音频 itag 生成不再使用预定义。
- 支持历史播放记录。(使用场景：potplayer 重新启动后直接播放或从播放列表中播放)。
- 增加番剧官方开场动画与片尾，可与空降助手合并。

## TODO

* ~~支持精准空降（视 PotPlayer 是否提供相关支持）~~，目前搭配[油猴脚本](#油猴脚本)实现。
* ~~支持空降助手~~。

## wiki

一些问题的解决办法，[wiki](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/%E4%B8%80%E4%BA%9B%E5%8F%AF%E8%83%BD%E7%9A%84%E9%97%AE%E9%A2%98%E5%8F%8A%E9%83%A8%E5%88%86%E8%A7%A3%E5%86%B3%E5%8A%9E%E6%B3%95)

## 安装插件

参考 [安装及基本使用教程](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/%E5%AE%89%E8%A3%85%E5%8F%8A%E5%9F%BA%E6%9C%AC%E4%BD%BF%E7%94%A8%E6%95%99%E7%A8%8B)，[进阶教程](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/%E8%BF%9B%E9%98%B6%E6%95%99%E7%A8%8B)。

## 油猴脚本

由于从 PotPlayer 内部实现精准空降存在一定难度<sup>[1](#关于精准空降)</sup>，因此目前采用外部油猴脚本的方式实现其功能。

目前修改版脚本 [BilibiliPotPlayer-改](https://greasyfork.org/zh-CN/scripts/593353-bilibilipotplayer-改) 支持：

* **精准空降**：将网页端指定的播放时间传递给 PotPlayer，实现精准跳转。

* **打开 PotPlayer 时自动暂停网页端视频**：启动 PotPlayer 播放后，自动暂停 Bilibili 网页端正在播放的视频，避免音视频重复播放。

### 油猴脚本声明

修改版脚本 `BilibiliPotPlayer-改` [https://greasyfork.org/zh-CN/scripts/593353-bilibilipotplayer-改](https://greasyfork.org/zh-CN/scripts/593353-bilibilipotplayer-%E6%94%B9)) 基于`原版油猴脚本` [油猴脚本https://greasyfork.org/zh-CN/scripts/461800-bilibilipotplayer](https://greasyfork.org/zh-CN/scripts/461800-bilibilipotplayer)，并保留原作者及原项目相关信息。如原作者对本脚本的发布或再分发存在异议，并要求停止发布，本人将配合下架本脚本。

# 声明
- 致敬原作者：[chen310/BilibiliPotPlayer](https://github.com/chen310/BilibiliPotPlayer) 
- 致敬上游作者：[juening2000/BilibiliPotPlayer](https://github.com/juening2000/BilibiliPotPlayer)
- 在上游项目的基础上，本项目根据个人使用需求进行了进一步的功能调整与兼容性修复，主要用于搭配 [vs-mlrt](https://github.com/AmusementClub/vs-mlrt) 的学习与测试。

# THANKS
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [Make-Bilibili-Great-Than-Ever-Before](https://github.com/SukkaW/Make-Bilibili-Great-Than-Ever-Before)
- [hgcat-360/PotPlayer-Extension_yt-dlp](https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp)
