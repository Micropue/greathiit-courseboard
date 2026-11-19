# 哈信息课程表

[![Build and Release](https://github.com/Micropue/greathiit-courseboard/actions/workflows/release.yml/badge.svg)](https://github.com/Micropue/greathiit-courseboard/actions/workflows/release.yml)
[![Latest Release](https://img.shields.io/github/v/release/Micropue/greathiit-courseboard?include_prereleases&style=flat-square)](https://github.com/Micropue/greathiit-courseboard/releases)
![macOS 27+](https://img.shields.io/badge/macOS-27%2B-black?style=flat-square)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Liquid%20Glass-blue?style=flat-square)

根据“获取课程表”快捷指令制作的 macOS 原生课程表查看器。应用常驻菜单栏，
通过全局快捷键在屏幕左侧呼出，并以适合课表阅读的 9:16 长条窗口展示整周课程。

<p align="center">
  <img src="docs/screenshots/main.png" width="390" alt="哈信息课程表主界面">
</p>

## 功能

- 原生 SwiftUI 界面，使用 macOS 27 Liquid Glass 与系统材质，不使用渐变配色。
- 常驻菜单栏，不占用 Dock；再次按下全局快捷键即可收起。
- 默认使用 `⌥Space`，可在设置中录制并持久化新的全局快捷键。
- 以 9:16 长条窗口显示周一至周日的完整课表，并展示节次、起止时间、地点和教师。
- 点击课程可查看教学周、节次、时间、地点和教师等完整信息。
- 支持 20 个教学周切换；星期导航和教学周切换保持统一尺寸。
- 支持系统、蓝、紫、粉、红、橙、黄、绿、青和石墨共 10 种主题色。
- 支持将 20 个教学周导出为 `.ics` 日历文件。
- 支持将 20 个教学周去重后导出为结构化的 `.json` 课程数据。
- 导出前可设置第 1 周周一日期；修改任意一周后，该周及后续教学周会自动顺延。
- 支持通过 macOS 登录项实现开机自启；登录时静默驻留菜单栏，不主动弹出窗口。
- JWT 仅保存在 macOS 钥匙串，不写入源码、日志或课程缓存。
- 最近一次成功结果缓存到 Application Support，网络异常时仍可查看。
- 切换到其他应用时窗口保持显示，不会因失焦自动消失。

## 安装

从 [Releases](https://github.com/Micropue/greathiit-courseboard/releases)
下载最新的 `greathiit-courseboard-*.zip`，解压后将“哈信息课程表.app”
拖入“应用程序”目录。

当前发布包使用本地临时签名，未经过 Apple 公证。首次打开时如果被 Gatekeeper
拦截，请在 Finder 中右键应用并选择“打开”。也可以在终端执行：

```sh
xattr -dr com.apple.quarantine "/Applications/哈信息课程表.app"
```

自动构建发布为预发布版本，稳定版本请选择 `v*` 标签对应的 Release。

## 首次使用

首次打开后输入原“获取课程表”快捷指令所使用的 JWT。应用会把令牌写入
macOS 钥匙串；之后使用全局快捷键呼出即可刷新当前教学周的课程。

如果 `⌥Space` 已被其他应用占用，应用会自动尝试 `⌃⌥C`。也可以在
“设置 → 全局快捷键”中录制新的组合键。

“设置 → 开机自启”使用 `SMAppService` 注册系统登录项。如果系统要求确认，
请在“系统设置 → 通用 → 登录项”中允许哈信息课程表。建议先将应用移动到
“应用程序”目录再开启此功能。

## 从源码构建

需要 macOS 27 或更高版本，以及支持 macOS 27 SDK 的 Xcode 工具链。

```sh
swift test
./scripts/build-app.sh
```

构建产物位于：

```text
dist/哈信息课程表.app
```

可选地指定发布版本号：

```sh
APP_VERSION=1.1.0 APP_BUILD=3 ./scripts/build-app.sh
```

## 快捷指令逻辑

原快捷指令的关键步骤已还原到应用：

1. 输入教学周。
2. 请求 `https://api.greathiit.com/api/timetable/getDataWeek?week=<周次>`。
3. 使用快捷指令中保存的 JWT 作为 `Authorization` 请求头。
4. 读取响应中的 `data` 数组。
5. 解析每条课程的 `timeAdd`：
   - 取最后一个 `-` 后的片段；
   - 第 4 位为教学楼编码，`1` 映射为 A，`2` 映射为 B；
   - 第 5–7 位为教室；
   - 第 10 位为节次；
   - 第 11 位为星期。
6. 取出 `courseName`、`teacherName`，按星期和节次展示。

解析器也兼容响应中直接提供的 `weekday`、`period`、`buildingName`、
`classroomName` 等字段。

## 导出到日历

课程接口只返回教学周和课程节次，不返回具体年月日，因此导出前需要确认
“第 1 周周一日期”。应用会按选定的日期，将 20 周内实际返回的课程逐条生成
日历事件；不会凭猜测硬编码学期开始日期。

如果遇到国庆、校历调整等情况，可以在“导出到日历”窗口中修改任意教学周的
周一日期。该周及之后的所有教学周会按相同天数自动顺延，之后再次导出即可。
你还可以设置第一节课的开始时间；应用会沿用学校原有的课间间隔，自动计算
其余课节的起止时间，并在导出前显示时间预览。
可以在“提前提醒”中选择不提醒、日程发生时、5–30 分钟前、1–2 小时前或
1–2 天前提醒；选择“自定义…”后还可以输入任意分钟、小时或天数。提醒会作为
标准 `VALARM` 写入每个课程事件，默认不添加提醒。
生成的 `.ics` 文件保存后可直接双击导入 macOS“日历”，不会自动上传到服务器。

应用没有采用日历订阅链接：订阅需要稳定、公开可访问的 ICS 地址，而本应用
只在本地持有 JWT 和课程数据。使用文件导出可以避免把访问令牌或课程表暴露给
第三方托管服务。

## 导出 JSON

点击主界面顶部的 `{}` 按钮即可导出 JSON。应用会读取 20 个教学周，按课程、
教师、教室、星期、教学周和节次去重，再按星期与节次排序。输出为 UTF-8
编码的格式化 JSON，字段结构与下面示例一致：

```json
[
  {
    "name": "通信工程专业导论",
    "teacher": "赵月",
    "classRoom": "综合楼313",
    "weekday": "星期一",
    "fixWeeks": "6-7周",
    "courseNumbers": "1-2节"
  }
]
```

`classRoom` 优先使用接口提供的地点；没有单独地点时会使用教学楼与教室拼接。
`courseNumbers` 在单节课程时输出类似 `3节`，连续两节时输出 `3-4节`。
导出过程中可再次点击顶部按钮取消。

## 自动构建与发布

工作流位于 `.github/workflows/release.yml`。任意 push 都会触发以下流程：

1. 在 Xcode 27 runner 上运行 `swift test`。
2. 构建 `.app`，生成 ZIP 和 SHA-256 校验文件。
3. 发布到 GitHub Releases。

推送 `v*` 标签会发布正式版本；普通分支 push 会生成带独立构建编号的预发布版本。

## 隐私说明

- 本应用是非官方客户端，与哈尔滨信息工程学院没有隶属关系。
- JWT 只保存在本机钥匙串中。
- 课程数据仅从学校接口获取，并缓存在本机 Application Support 目录。
- 应用不包含统计、遥测或第三方上传逻辑。

## 许可证

本项目使用 [MIT License](LICENSE)。
