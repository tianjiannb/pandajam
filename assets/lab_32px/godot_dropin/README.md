# godot_dropin — 直接放进 Godot 工程就能用

## 用法（30 秒）
1. 把本目录下的 `tiles/` 和 `scenes/` 两个文件夹整体复制到你的 Godot 4.7 工程根目录（和 `project.godot` 同级）。
2. 工程设置 → 渲染 → 纹理 → 默认纹理过滤 = `Nearest`（像素风必须，否则会糊）。
3. 双击 `scenes/lab_map.tscn` 就能看到已经铺好的 20×14 实验室（Floor / Walls 两层）。
4. 选中 `Walls` 图层 → 顶部切到「地形」页签 → 选 `lab_wall` 地形，用笔刷继续刷墙；
   `Floor` 图层同理选 `lab_floor`。四边会自动接边，转角/门洞都自动处理。

## 里面是什么
- `tiles/lab_tileset.tres`：TileSet 资源
  - 地形集 0 `lab_wall`：16 格自动拼边（掩码 = 上1 右2 下4 左8），每格带 32×32 整格碰撞
  - 地形集 1 `lab_floor`：主地面（可无缝铺）
  - 图集 0 = `walls/wall_autotile_16.png`（4×4）；图集 1 = `floors/floor_set_3.png`（plain / grid / hazard 横排 3 格）
- `scenes/lab_map.tscn`：20×14 示例地图，含
  - Floor 层：整片地面 + 一块格栅（grid）+ 一块警示带（hazard）
  - Walls 层：外圈墙，右侧 r=6 留门洞
  - 门（关/开）、控制台、补给箱 ×2、玻璃隔断：Sprite2D + StaticBody2D（32×32 碰撞；开门不挡路）

## 已经验过的
- Godot 4.7 headless + 窗口模式都能正常加载，无脚本报错
- 玩家（队长 main.tscn 里的 CharacterBody2D）向左走会停在 `x = -278`（墙面 -288 + 身位），
  即整格碰撞生效、不会穿墙
- 地形笔刷（`set_cells_terrain_connect`）运行时铺出来的墙四边自动接边，与编辑器笔刷同一套规则

## 注意
- 图块尺寸 32×32；如果工程是别的尺寸，需要重新导出瓦片
- 玩家/机关/玩法脚本不在本目录（用队长的）
- 想把门做成「压力板开门」：把 `door_closed` 的 Sprite 换成动态节点或用 AtlasTexture 切图，碰撞体删掉/启用即可
