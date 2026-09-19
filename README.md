# BilibiliPotPlayer

适用于 PotPlayer 的 Bilibili 插件，可直接解析并播放 Bilibili 视频、番剧、影视、直播等内容。

配合 [BilibiliPotPlayer-改](https://greasyfork.org/zh-CN/scripts/593353-bilibilipotplayer-%E6%94%B9) 油猴脚本，可直接从 Bilibili 网页调用 PotPlayer 播放，并支持精准空降等功能。

> 本项目基于 [chen310/BilibiliPotPlayer](https://github.com/chen310/BilibiliPotPlayer) 及其上游版本 [juening2000/BilibiliPotPlayer](https://github.com/juening2000/BilibiliPotPlayer) 进行维护，并针对个人使用需求持续进行功能改进、Bug 修复和测试。
>
> 如果上游项目恢复持续更新，本项目将优先向上游提交相关改进，并根据上游项目的维护情况决定是否继续维护本项目。
>
> 本项目是个人用于搭配 [vs-mlrt](https://github.com/AmusementClub/vs-mlrt) 的学习与测试维护的项目，但与 [vs-mlrt](https://github.com/AmusementClub/vs-mlrt) 无关。


## ✨ 主要改进

### 🔐 直接网页登录，免手动配置 Cookie

相较于原版本[chen310/BilibiliPotPlayer](https://github.com/chen310/BilibiliPotPlayer) 和上游版本[juening2000/BilibiliPotPlayer](https://github.com/juening2000/BilibiliPotPlayer)，本项目对 Bilibili 登录方式进行了较大的改进：

- **无需手动获取、复制和配置 Cookie**
- 通过**网页登录**完成账号认证
- 登录流程更加直观，降低使用门槛
- 登录状态由程序自动处理
- 对普通用户更加友好

> 如果你不希望手动获取 Cookie，这是本项目与上游版本最明显的区别。

**_注意：由于登录机制的改变，从上游项目迁移过来的同学， 旧的 Cookie、Header、Referer 一定要删除。参考 [wiki](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/常见问题与故障排查#播放视频时一直转圈右下角画质选项不断跳动)。_**

## 其它改进

### 🔧 整体优化

- 正确选择默认播放画质，支持设定编码格式优先级。
- 本地缓存响应数据，降低 API 请求次数。可在配置文件中设置，默认300s。
- 清理无用代码，较为激进，有问题请提 issue。
- 支持屏蔽 P2PCDN。
- 优化风控策略。
- 动态生成画质选项，与官方保持一致。
- 增加心跳上报功能，用于历史记录同步。

### 📺 直播

- 默认使用低延迟的 HLS/fMP4 流，无法提供时回退至 HLS/TS。
- 支持直播备用地址。
- 增加 解析真实 M3U8 开关。规避画质选项 potplayer 自动覆盖成 HLS 的问题。详见配置项注释。
- 支持收发弹幕（依赖自建 [Bilibili_Danmuji](https://github.com/BanqiJane/Bilibili_Danmuji) 服务, [Bilibili_Danmuji接入教程](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/%E8%BF%9B%E9%98%B6%E6%95%99%E7%A8%8B#%E6%8E%A5%E5%85%A5-bilibili_danmuji-%E6%9C%8D%E5%8A%A1)）。
- 遇到未开播的情况，弹出对话框提醒。
- 从单个直播间打开时，播放列表增加推荐的直播间。

### ▶️ 点播

- 支持设置 HDR/杜比视界 优先。
- 重新支持用户合集视频，并支持多合集，potplayer 播放列表( 快捷键 <kbd>F6</kbd> ) 正确显示合集视频。
  - 当存在用户视频合集时，播放列表里只展示合集视频。
  - 当只存在单个视频时，播放列表里包含当前视频与推荐视频（是否包含推荐视频取决于配置文件`showRecommendedVideos`开关）
- 播放番剧，电视剧等其它PGC合集或用户合集时，正确定位当前视频，不会出现从第一集开始播放的问题。
- 支持AV播放地址。
- 当同时存在 杜比全景声 与 Hi-Res无损 时，默认使用 Hi-Res无损。
- 增加 [空降助手](https://github.com/hanydd/BilibiliSponsorBlock) 支持。通过配置文件设置，默认禁用。
   另外支持指定镜像站点，以解决主站访问不稳定的问题。（由于目前主站访问不稳定，镜像站是临时的，所以默认禁用。注：**连接失败直接会造成播放失败**。）  
- 增加番剧官方开场动画与片尾支持，并与空降助手合并。
- 当播放付费内容时，弹出对话框提醒。
- 增加番剧预告开关。
- 播放列表支持时间显示。

### 播放列表
- “我的动态”、"首页推荐"、"历史记录"、“综合热门”、个人“空间动态”，支持设定视频数量。
- 各类生成的播放列表，日期基本上已全部显示。
- "我关注的直播间"当无人开播时，弹出对话框提醒。
- 直接从直播分区页面打开时：
  - 打开支持关键帧截图。
  - 增加分区信息。
  - 支持荣誉称号显示。
- "稍后再看" 无内容时，弹出对话框提醒。
- 直播缩略图支持使用关键帧截图。
- 增加 `直播首页推荐` 支持。

## 打开链接
- "Potplayer - 打开链接"，类别重新整理命名。
  - 增加 PGC 内容类别。
- 直接打开各类
  - 页面支持"综合热门"页面。
  - 增加"热门-排行榜-PGC"页面支持。
  - 增加UP主个人空间动态页面支持。
  - 排行榜适配B站新分区。


## 📚 文档

第一次使用建议按以下顺序阅读：

1. [安装与快速开始](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/%E5%AE%89%E8%A3%85%E4%B8%8E%E5%BF%AB%E9%80%9F%E5%BC%80%E5%A7%8B)
2. [使用指南](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/%E4%BD%BF%E7%94%A8%E6%8C%87%E5%8D%97)

其他文档：

- [Bilibili_Danmuji 弹幕接入](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/Bilibili_Danmuji-%E5%BC%B9%E5%B9%95%E6%8E%A5%E5%85%A5)
- [常见问题与故障排查](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98%E4%B8%8E%E6%95%85%E9%9A%9C%E6%8E%92%E6%9F%A5)
- [PotPlayer AngelScript 开发参考](https://github.com/frostnotfall/BilibiliPotPlayer/wiki/PotPlayer-AngelScript-%E5%BC%80%E5%8F%91%E5%8F%82%E8%80%83)

## 🐒 油猴脚本

由于从 PotPlayer 内部实现精准空降存在一定限制，目前通过外部油猴脚本补充网页侧功能。

修改版脚本 [BilibiliPotPlayer-改](https://greasyfork.org/zh-CN/scripts/593353-bilibilipotplayer-%E6%94%B9) 支持：

- **精准空降**：将网页端当前播放时间传递给 PotPlayer。
- **打开 PotPlayer 后自动暂停网页视频**：避免网页与 PotPlayer 同时播放。

该脚本基于原版 BilibiliPotPlayer 油猴脚本修改，并保留原作者及原项目相关信息。

## 致谢

- [chen310/BilibiliPotPlayer](https://github.com/chen310/BilibiliPotPlayer)
- [juening2000/BilibiliPotPlayer](https://github.com/juening2000/BilibiliPotPlayer)
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [Make-Bilibili-Great-Than-Ever-Before](https://github.com/SukkaW/Make-Bilibili-Great-Than-Ever-Before)
- [hgcat-360/PotPlayer-Extension_yt-dlp](https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp)

