# MenuLyrics

A lightweight native macOS menu bar app for Apple Music lyrics. 支持中文和 English。

![App icon](Assets/AppIcon.png)

## 下载与使用

[下载 MenuLyrics.zip](MenuLyrics.zip?raw=true)，解压并打开 `MenuLyrics.app`。更新时请先退出旧版。

1. 在 Apple Music 播放歌曲，并允许 MenuLyrics 控制 Music，以读取歌曲和播放进度。
2. 在菜单开启 LRCLIB 自动查找，或为当前歌曲导入 UTF-8 LRC 文件。
3. 在「歌词显示方式」选择连续滚动或逐句跳转，立即生效并自动保存。
4. 在「歌词来源与使用说明」上方的「语言 / Language」切换中英文，退出并重新打开后生效。

支持歌词提前/延后微调。跳转模式的长句末尾会省略。请在菜单栏留出约 300 点宽度。

## Download and use

[Download MenuLyrics.zip](MenuLyrics.zip?raw=true), unzip it, and open `MenuLyrics.app`. Quit the old version before replacing it.

Play a song in Apple Music and allow access to Music. Enable LRCLIB lookup or import a UTF-8 LRC file. Choose **Scroll** or **Jump** under **Lyrics display mode**. The choice applies immediately and is saved. Change **Language / 语言** above **Lyrics source and help**, then quit and reopen to apply it.

## Build

Requires macOS and Xcode command line tools. No third-party build dependencies.

```sh
./build.sh
```

The script builds for the current Mac's architecture, creates the app icon, applies an ad hoc signature, and produces `MenuLyrics.zip`. The included binary is built for Apple Silicon. The app is not notarized by Apple.

## Lyrics and privacy / 歌词与隐私

Automatic lookup is off by default. If enabled, the song title, artist and duration are sent to [LRCLIB](https://lrclib.net) to retrieve synced lyrics. No Apple account information is sent. Lyrics may be missing or differ from the recording. This app does not include song lyrics or redistribute a lyrics database. Imported lyrics remain in memory until the app quits.

自动查找默认关闭。开启后会向 LRCLIB 发送歌名、歌手和时长。歌词来自第三方，并非 Apple 官方歌词，可能缺失或与当前版本不同。导入的歌词仅保留至退出应用。

More details: [使用说明](使用说明.md).
