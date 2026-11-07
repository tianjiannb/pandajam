# lab_32px — 生化实验室 32×32 俯视像素瓦片模块（v2）

## 规格
- 32×32 像素、sRGB、PNG-32（带 alpha）、无预乘、像素对齐
- 用途：2D 俯视角（正交）实验室地图，Godot 4.7 直接导入
- 统一色板：墙 `#D8E2EA`（高光 `#F7FBFD` / 投影 `#A6B8C6`）、地面 `#93A7BA`、描边 `#1E252E`

## 目录
```
lab_32px/
├─ floors/     地板（plain / grid / hazard + floor_set_3.png 横排图集 + AI 版）
├─ walls/      墙（wall_autotile_16.png 4×4 自动拼边 + wall_00..15 单块 + AI 白墙/玻璃）
├─ doors/      门（关 / 开）
├─ props/      道具（补给箱 / 控制台）
├─ godot_dropin/   ← 直接复制进 Godot 工程就能用（tiles/ + scenes/ + README）
├─ preview.png     12×8 示例房间（3× 放大）
├─ sheet.png       全部瓦片检查表（6× 放大 + 透明棋盘格）
└─ ingame_proof.png  Godot 4.7 实机截图（队长 main.tscn 玩法 + 本模块地图）
```

## 关键约定
- **墙 16 格自动拼边**：索引 = 上 1、右 2、下 4、左 8（该位为 1 表示「这一侧也是墙」），
  `wall_autotile_16.png` 按 4 列 × 4 行排列，第 n 格 = `wall_nn.png`
- **地板无缝**：`floor_plain` 的拼接缝在 x=0 / y=0 边界上，任意铺不会出现断线
- **警示带**：`floor_hazard` 用 `(x+y) % 16` 生成 45°，四方向都无缝
- **碰撞**：墙整格 32×32；门关挡路、门开不挡；道具 32×32

## 已经验过的（本机实测）
1. `godot --headless --path <proj> --import`：45 个资源导入无报错
2. `tiles/lab_tileset.tres` 生成成功（`err=0`）：两个地形集 + 墙块碰撞多边形都在
3. `scenes/lab_map.tscn` 生成成功（7.6KB，两层已刷好）
4. 实机跑起来：地图/道具/门全部正确渲染（见 `ingame_proof.png`）
5. 碰撞验证：把玩家按住向左走，停在 `x=-278`（墙面 -288 + 身位 10），没有穿墙

## 怎么放进游戏
见 `godot_dropin/README.md`。一句话：把 `godot_dropin/tiles` 和 `godot_dropin/scenes`
复制到工程根目录，纹理过滤设 Nearest，打开 `scenes/lab_map.tscn` 继续刷即可。

## 备注
- 这套只含「地图瓦片 + 可直接用的 TileSet/示例地图」，不含玩家角色和玩法脚本
- 还没做的：炮塔瓦片、管道/培养舱等装饰、监控摄像头、更多墙变体（门框/转角装饰）
