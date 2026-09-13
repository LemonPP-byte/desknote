# 桌签 DeskNote

安静待在桌面上的极简信息分流小工具。macOS 原生（SwiftUI / AppKit），单文件，《我的世界》草地风。

## 它解决什么

信息太多、渠道太杂时，真正的问题不是量，而是几种**保质期完全不同**的信息挤在同一个待办里，导致最易流失、也最值钱的那类（趁热要问人 / 趁热要做的动作）在手上烂掉。

DeskNote 只做一件事：给这类信息一个零摩擦出口，让它安静待在桌面上，随手记、做完点掉。

## 三类（靠颜色和位置区分，界面不显示标题）

- **趁热**（最上，红石红色带，黑字）—— 行动窗口型：趁热问人 / 趁热做动作，保质期以小时计
- **待办**（中间，草绿色带，灰字）—— 紧急 + 重要不紧急，该做就做
- **想学**（底部，木箱棕色带，灰字）—— 知识囤积，没压力，有空再翻

每一类合并成一个方块面板，左侧一条粗色带标类别。底部一条像素地面带，小精灵（苦力怕 / 爱心 / 草方块）站在草线上。

## 用法

- 输入框敲字，回车（或点 `＋`）= 扔进「待办」
- 每条右边按钮：`↑` 升一档 / `↓` 降一档 / `✓` 做完点掉
- 窗口像苹果便签，安静待在桌面某处，位置和大小自动记住
- 数据存在本地 `~/.desknote/notes.json`（不进仓库）

## 安装字体（可选，但强烈建议）

MC 味道来自像素字体。用开源的 [Fusion Pixel 字体](https://github.com/TakWolf/fusion-pixel-font)（SIL 开源协议）：

```sh
# 下载 12px 简中比例版并安装到用户字体目录
gh release download --repo TakWolf/fusion-pixel-font \
  --pattern 'fusion-pixel-font-12px-proportional-ttf-v*.zip' --dir /tmp/fpf
cd /tmp/fpf && unzip -o *.zip
cp fusion-pixel-12px-proportional-zh_hans.ttf ~/Library/Fonts/
```

没装字体也能跑，会自动回退到系统等宽字体（只是少了像素感）。

## 编译与运行

```sh
swiftc -O DeskNote.swift -o desknote
./desknote
```

需要 macOS + Xcode Command Line Tools（自带 `swiftc`）。
