# BilibiliPotPlayer

适用于 PotPlayer 的 Bilibili 播放插件。配合 [油猴脚本](https://greasyfork.org/zh-CN/scripts/461800-bilibilipotplayer)，
可以直接从 Bilibili 网页调用 PotPlayer 进行播放。

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

### 📺 直播

- 支持 AVC、HEVC、AV1
- 默认使用低延迟的 HLS/fMP4 流，无法提供时回退至 HLS/TS
- 支持直播备用地址
- 动态生成直播画质选项

### ▶️ 点播

- 支持屏蔽 P2PCDN，可通过配置文件调整，默认屏蔽
- 修复部分 Host 为 `upos` 的点播 URL 播放失败的问题
- Bilibili 点播更换新接口，尽量使用wbi签名认证防止接口失效
- 重新支持用户合集视频，potplayer播放列表( 快捷键 <kbd>F6</kbd> )正确显示合集视频
- 播放番剧，电视剧等其它PGC合集或用户合集时，正确定位当前视频，不会出现从第一集开始播放的问题
- 支持AV播放地址
- 优化 Bilibili 音频画质选项显示：
  - `EC-3` → **杜比全景声 EC-3**
  - `FLAC` → **Hi-Res 无损 FLAC**
- 当同时存在杜比全景声与Hi-Res无损时，默认使用Hi-Res无损。
- 请求本地缓存，尽量减少请求次数
- 移除或注释无用旧代码，比较激进。


## TODO

* 支持精准空降（视 PotPlayer 是否提供相关支持）。
* 直播播放目前存在 `exception` 异常，但暂未发现其对实际播放造成影响；当前播放及画质选项均正常。

# 一些可能的问题及解决办法

#### 播放视频时一直转圈，右下角画质选项不断跳动

这通常是由于 PotPlayer 中保存了旧的 `Cookie`、`Header` 或 `Referer` 信息导致的。可以尝试清理相关配置后重新播放。

**如果未勾选「保存设置到 INI 文件」：(按 F5 打开选项"设置 - 基本" 页面下 )**

1. 打开注册表编辑器（`regedit`）。

2. 定位到：

   `计算机\HKEY_CURRENT_USER\Software\DAUM\`

3. 根据你平时使用的 PotPlayer 程序，进入对应的注册表项：

   * `PotPlayer64`
   * `PotPlayerMini64`

   一般情况下使用的是 `PotPlayerMini64`。

4. 删除其中的以下键值（如果存在）：

   * `_UrlCookie`
   * `_UrlHeader`
   * `_UrlReferer`

**如果已勾选「保存设置到 INI 文件」：**

1. 打开 PotPlayer 安装目录。

2. 根据你平时使用的程序，打开对应的配置文件：

   * `PotPlayerMini64.ini`
   * `PotPlayer64.ini`

   一般情况下使用的是 `PotPlayerMini64.ini`。

3. 在文件中删除以下配置节（如果存在）：

   ```ini
   [_UrlCookie]

   [_UrlHeader]

   [_UrlReferer]
   ```

完成后重新启动 PotPlayer，再尝试播放。


## 安装插件

[下载项目](https://github.com/frostnotfall/BilibiliPotPlayer/archive/refs/heads/master.zip)

将项目 `Media/PlayParse` 路径下的 `MediaPlayParse - Bilibili.as`、`MediaPlayParse - Bilibili.ico` 和 `Bilibili_Config.json` 三个文件复制到 `{PotPlayer 安装路径}\Extension\Media\PlayParse` 文件夹下。

`MediaPlayParse - Bilibili.as` 提供了解析 `Bilibili` 链接的功能。

将项目 `Media/UrlList` 路径下的 `MediaUrlList - Bilibili.as` 和 `MediaUrlList - Bilibili.ico` 两个文件复制到 `{PotPlayer 安装路径}\Extension\Media\UrlList` 文件夹下。

`MediaUrlList - Bilibili.as` 提供了列出 `Bilibili` 常用链接的功能，使用方式为按下 <kbd>ctrl</kbd> + <kbd>U</kbd> 并选择要播放的项目，如下图所示

![UrlList](https://cdn.jsdelivr.net/gh/chen310/BilibiliPotPlayer/public/urllist.png)

## 新登录方式（旧cookie方式已弃用）

打开 PotPlayer，按 <kbd>F5</kbd> 打开选项，点击`扩展功能`，此时有两种登录方式，任选其一即可：

* 第一种，点击`媒体播放列表/项目`，再点击 `Bilibili`，然后点击`设置`，此时弹出一个网页进程，按照正常网页端登录即可。

![login_1](public/login_1.png)

* 第二种，点击右方向右箭头，找到`网络账户`并点击，然后点击`Bilibili`，最后点击`管理账户`，同样会弹出一个网页进程，按照正常网页端登录即可。

![login_2](/public/login_2.png)

### 网页登陆界面
注：窗口大小可手动调整
![login_web](/public/login_web.png)

## 使用方法

### 播放视频/直播

将 Bilibili 链接拖到 PotPlayer，或者按 <kbd>ctrl</kbd> + <kbd>U</kbd> 粘贴 Bilibili 链接即可播放。可参考[视频](https://www.bilibili.com/video/BV1mM41177kT)

### 搜索

按 <kbd>ctrl</kbd> + <kbd>U</kbd>，在文件地址列表中选择`搜索`，然后到上面的输入框中替换关键词，最后回车即可

![Search](https://cdn.jsdelivr.net/gh/chen310/BilibiliPotPlayer/public/search.png)

### 跳过片头片尾

对于一些电视剧、番剧，能够跳过片头和片尾。具体设置为：在 PotPlayer 上点击鼠标右键，选择`播放`-`跳略播放`-`跳略播放设置`

![Skip_Settings](https://cdn.jsdelivr.net/gh/chen310/BilibiliPotPlayer/public/skip_1.png)

勾选`跳略播放`和`章节名称`，并在名称列表中追加`哔哩哔哩-片头`和`哔哩哔哩-片尾`两项，每一项之间用英文分号`;`隔开。

![Skip_Settings](https://cdn.jsdelivr.net/gh/chen310/BilibiliPotPlayer/public/skip_2.png)

### 在列表中显示缩略图

按 <kbd>F6</kbd> 打开播放列表，点击鼠标右键，点击`样式`，选择`显示缩略图`，即可显示视频的缩略图。

![Thumbnail](https://cdn.jsdelivr.net/gh/chen310/BilibiliPotPlayer/public/thumbnail.png)

### 创建自动更新的播放列表

按 <kbd>F6</kbd> 打开播放列表，点击新建专辑，起一个合适的专辑名称，选择外部播放列表，并填写相应的链接，再点击确定即可。这样就得到一个可以自动更新的列表。

![Create_Playlist](https://cdn.jsdelivr.net/gh/chen310/BilibiliPotPlayer/public/create_playlist_1.png)

![Create_Playlist](https://cdn.jsdelivr.net/gh/chen310/BilibiliPotPlayer/public/create_playlist_2.png)

本项目源自 [chen310/BilibiliPotPlayer](https://github.com/chen310/BilibiliPotPlayer)，
并基于 [juening2000/BilibiliPotPlayer](https://github.com/juening2000/BilibiliPotPlayer)
继续进行修改和维护。

# 声明
- 致敬原作者：[chen310/BilibiliPotPlayer](https://github.com/chen310/BilibiliPotPlayer) 
- 致敬上游作者：[juening2000/BilibiliPotPlayer](https://github.com/juening2000/BilibiliPotPlayer)
- 在上游项目的基础上，本项目根据个人使用需求进行了进一步的功能调整与兼容性修复，主要用于搭配 [vs-mlrt](https://github.com/AmusementClub/vs-mlrt) 的学习与测试。

## THANKS
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [Make-Bilibili-Great-Than-Ever-Before](https://github.com/SukkaW/Make-Bilibili-Great-Than-Ever-Before)
- [hgcat-360/PotPlayer-Extension_yt-dlp](https://github.com/hgcat-360/PotPlayer-Extension_yt-dlp)
