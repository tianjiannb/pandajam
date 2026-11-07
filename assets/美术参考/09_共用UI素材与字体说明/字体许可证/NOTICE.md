# 字体许可与版权 NOTICE

本项目字体均采用 SIL Open Font License 1.1（OFL-1.1）。OFL 允许将字体嵌入游戏、修改、商业发行与再分发；禁止单独销售字体本身；修改版不得使用上游保留字体名（若有）。

## 1. Noto Sans SC（Regular / Bold）

- 文件：`ui_zh_regular.otf`、`ui_zh_bold.otf`
- 版权：Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'. Noto is a trademark of Google Inc.
- 来源：https://github.com/notofonts/noto-cjk （Sans/SubsetOTF/SC）
- 许可全文：`noto_sans_sc_OFL.txt`（取自 Google Fonts 的 Noto Sans SC 发行包）
- 修改：未修改，原样分发。

## 2. Ma Shan Zheng 马善政毛笔楷书

- 文件：`ui_hand_title.ttf`
- 版权：Copyright 2014 The Ma Shan Zheng Project Authors (https://github.com/googlefonts/mashanzheng)
- 来源：https://github.com/google/fonts/tree/main/ofl/mashanzheng
- 许可全文：`mashanzheng_OFL.txt`
- 修改：未修改，原样分发。

## 3. Caveat → UI Countdown Digits

- 文件：`ui_countdown_digits.ttf`（衍生字体）
- 原始版权：Copyright 2014 The Caveat Project Authors (https://github.com/googlefonts/caveat)
- 来源：https://github.com/google/fonts/tree/main/ofl/caveat
- 许可全文：`caveat_OFL.txt`
- 修改说明（依据 OFL，修改后以新名称分发）：
  1. 由变量字体实例化为 `wght=400` 静态字体；
  2. 子集化为 `0-9 : . - 空格`（36 个字形）；
  3. 重命名字族为 "UI Countdown Digits" / Regular，PostScript 名 `UICountdownDigits-Regular`；
  4. name 表写入修改说明与 OFL 链接。
- 分发要求：随游戏一同保留本 NOTICE 与 `caveat_OFL.txt`。

## 再分发检查清单

- [x] 三份 OFL 全文随包分发
- [x] 衍生字体改名，不冒用上游名称
- [x] 保留原始版权行（name ID 0 未改动）
- [x] 不单独售卖字体
