"""Assemble labeled handoff folders, inventory, offline index, and ZIP.

Reads only the handoff snapshot and existing audio assets.
Generated caches, credentials and unrelated game scenes are never packaged.
"""

import csv
import hashlib
import html
import json
from pathlib import Path
import shutil
import wave
import zipfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parents[1]
PROJECT = BASE / "01_Godot_UI预览工程"
WORKSPACE = BASE.parents[2]
FONT = PROJECT / "assets/fonts/ui_zh_regular.otf"
MODULES = [
    ("02_开始页面", "开始页面 / 标题页", ["scenes/title_screen.tscn", "scripts/title_screen.gd"],
     ["title_bg.png", "title_logo.png", "title_veil.png", "ui_button_*.png", "ui_menu_panel.png"],
     "title.png", "scenes/title_screen.tscn",
     "开始、设置、操作说明、退出；背景、LOGO、按钮四态和标题音乐。",
     "本交付工程中“开始实验”进入 UI 预览页；接回游戏时只需修改 title_screen.gd 的 _on_start() 目标场景。原标题画面与其他按钮逻辑保留。"),
    ("03_左下角操作指引", "左下角操作指引", ["ui/scenes/ui_controls_panel.tscn", "ui/scripts/ui_controls_panel.gd"],
     ["ui_key_*.png", "ui_state_self_end.png", "ui_hud_panel.png"],
     "controls.png", "ui/scenes/ui_controls_panel.tscn",
     "WASD/方向键、空格跳跃、E交互、Q/R回环；展开与折叠两种状态。",
     "调用 set_collapsed(true/false)。F1 的按键切换由总装 ui_hud.gd 处理；独立放入游戏需把动作接上。"),
    ("04_倒计时", "倒计时 / 普通、警告、回声", ["ui/scenes/ui_countdown.tscn", "ui/scripts/ui_countdown.gd"],
     ["ui_countdown_*.png"],
     "countdown.png", "ui/scenes/ui_countdown.tscn",
     "数字图集、手绘抖动材质；普通12秒、最后3秒警告、紫色回声三种状态。",
     "set_time_left(12.0) 更新；set_style(&\"ghost\") 改为回声；auto_follow_parent_timer=true 时自动读取父节点 CountdownTimer。"),
    ("05_暂停页面", "暂停页面", ["ui/scenes/ui_pause_menu.tscn", "ui/scripts/ui_pause_menu.gd"],
     ["ui_menu_panel.png", "ui_button_*.png", "ui_icon_pause*.png"],
     "pause.png", "ui/scenes/ui_pause_menu.tscn",
     "继续、重新开始、设置、退出；支持键盘焦点和鼠标，暂停时仍能操作。",
     "open()/resume() 控制开关。监听 restart_requested/settings_requested/quit_requested。独立使用时 pause_tree=true；总装 HUD 统一管理时为 false。"),
    ("06_设置页面", "设置页面 / 游戏内和标题页", ["ui/scenes/ui_settings_menu.tscn", "ui/scripts/ui_settings_menu.gd",
     "scripts/game_config.gd"],
     ["ui_menu_panel.png", "ui_button_*.png", "ui_icon_volume*.png", "ui_icon_back*.png", "ui_icon_check*.png"],
     "settings.png", "ui/scenes/ui_settings_menu.tscn",
     "游戏内：音效、音乐、视野开关、恢复默认；标题页另含主音量和全屏设置。",
     "open()/close()；settings_changed(sfx,music,vision) 写入 GameConfig。视野选项必须连接有 enabled 属性的实际视野节点；交付预览只演示开关，不含游戏地图。"),
]


def copy(source, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest)


def text(path, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")


def image_description(name):
    fixed = {
        "title_bg.png": "开始页面完整实验室背景",
        "title_logo.png": "DL-Circle标题LOGO透明图，运行时同款文字由Label绘制",
        "title_veil.png": "标题页暗色遮罩",
        "ui_hud_panel.png": "操作指引与HUD的九宫格底板",
        "ui_menu_panel.png": "暂停、设置菜单的九宫格底板",
        "ui_countdown_digits.png": "倒计时数字图集，0-9及符号",
        "ui_countdown_panel.png": "普通倒计时底板",
        "ui_countdown_panel_warning.png": "最后三秒警告倒计时底板",
        "ui_countdown_panel_ghost.png": "回声倒计时底板",
        "ui_state_self_end.png": "主动结束本轮/回环图标",
    }
    if name in fixed:
        return fixed[name]
    for fragment, purpose in [("normal", "常态"), ("hover", "鼠标悬停"), ("pressed", "按下"), ("disabled", "禁用")]:
        if name.startswith("ui_button_") and fragment in name:
            return "按钮九宫格：" + purpose
    if name.startswith("ui_key_"):
        return "操作按键键帽：" + name.removeprefix("ui_key_").split(".")[0]
    if name.startswith("ui_icon_"):
        return "通用图标：" + name.removeprefix("ui_icon_").split(".")[0]
    return "共用UI素材：" + name


def module_folders():
    for dirname, title, programs, patterns, screenshot, scene, purpose, note in MODULES:
        folder = BASE / dirname
        for program in programs:
            copy(PROJECT / program, folder / "程序与场景" / program)
        if dirname == "04_倒计时":
            for directory in ("ui/materials", "ui/shaders"):
                for source in (PROJECT / directory).rglob("*"):
                    if source.is_file() and source.suffix != ".uid":
                        copy(source, folder / "程序与场景" / source.relative_to(PROJECT))
        image_rows = []
        selected = set()
        for pattern in patterns:
            selected.update((PROJECT / "assets/ui").glob(pattern))
        for source in sorted(selected):
            if source.suffix != ".png":
                continue
            copy(source, folder / "UI图片" / source.name)
            with Image.open(source) as img:
                image_rows.append((source.name, f"{img.width}×{img.height}", image_description(source.name)))
        md = [f"# {title}", "", purpose, "", f"- 可运行页面：`01_Godot_UI预览工程/{scene}`",
              "- `程序与场景`：该模块源码的查阅副本，文件夹结构与工程相同。",
              "- `UI图片`：原始透明图片，可交给美术或程序。",
              "- `预览`：实际Godot渲染；透明PNG是整体效果图，动态效果仍需运行程序。",
              "- 场景中的 `res://` 路径从 Godot 工程根目录解析。接入时以 `01_Godot_UI预览工程` 为准，不要只复制单个 tscn。",
              "", "## 接入", "", note, "",
              "共用主题 `ui/theme/ui_theme.tres`、字体 `assets/fonts` 和素材 `assets/ui` 均已包含在预览工程。",
              "", "## 每张图是什么", "", "| 文件 | 尺寸 | 用途 |", "|---|---|---|"]
        md.extend(f"| {name} | {size} | {desc} |" for name, size, desc in image_rows)
        text(folder / "这个文件夹是什么.md", "\n".join(md))
        with (folder / "图片对照表.csv").open("w", encoding="utf-8-sig", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["文件名", "像素尺寸", "用途"])
            writer.writerows(image_rows)
        preview_folder = folder / "预览"
        preview_folder.mkdir(exist_ok=True)
        if (PROJECT / "captures" / screenshot).exists():
            copy(PROJECT / "captures" / screenshot, preview_folder / screenshot)
    mapping = {
        "logo_alpha.png": "02_开始页面/预览/DL-Circle_LOGO_透明.png",
        "title_settings.png": "02_开始页面/预览/标题页_设置.png",
        "title_help.png": "02_开始页面/预览/标题页_操作说明.png",
        "controls_alpha.png": "03_左下角操作指引/预览/操作指引_展开_透明.png",
        "compact_alpha.png": "03_左下角操作指引/预览/操作指引_折叠_透明.png",
        "clock_normal.png": "04_倒计时/预览/倒计时_普通_透明.png",
        "clock_warning.png": "04_倒计时/预览/倒计时_最后三秒_透明.png",
        "clock_ghost.png": "04_倒计时/预览/倒计时_回声_透明.png",
        "pause_alpha.png": "05_暂停页面/预览/暂停菜单_透明.png",
        "settings_alpha.png": "06_设置页面/预览/设置菜单_透明.png",
    }
    for source, dest in mapping.items():
        path = PROJECT / "captures" / source
        if path.exists():
            copy(path, BASE / dest)
    for source in (PROJECT / "captures").glob("*_960x540.png"):
        for dirname, _, _, _, screen, *_ in MODULES:
            if source.name.startswith(Path(screen).stem + "_"):
                copy(source, BASE / dirname / "预览" / source.name)


def original_audio():
    folder = BASE / "08_原版音效与背景音乐"
    descriptions = {
        "cycle_ambient": "原版探索环境背景音乐，60秒",
        "pressure_pulse": "安保压力叠加脉冲",
        "checkpoint": "过区/检查点确认",
        "death": "原版死亡音效；恐怖增强版另见07",
        "denied": "交互无效或拒绝",
        "door": "机械门开闭",
        "pickup": "道具拾取",
        "reveal": "结局揭示冲击",
        "rewind": "回环/重置",
        "switch": "机关切换/接通",
        "tick": "倒计时末尾提示",
        "tool": "扳手使用/工具冲击",
        "bgm_explore": "DSH探索BGM",
        "bgm_tension": "DSH紧张BGM",
        "bgm_ending": "DSH结局BGM",
        "sfx_echo": "DSH副本生成音效",
        "sfx_ending": "DSH结局冲击音效",
        "sfx_insert": "DSH插入供能芯音效",
    }
    for source in (PROJECT / "assets/audio").glob("*.wav"):
        copy(source, folder / source.name)
    source_dsh = WORKSPACE / "dsh/输出/音频"
    for name in ("bgm_explore", "bgm_tension", "bgm_ending", "sfx_echo", "sfx_ending", "sfx_insert"):
        source = source_dsh / (name + ".wav")
        if source.exists():
            copy(source, folder / source.name)
    rows = []
    for path in sorted(folder.glob("*.wav")):
        with wave.open(str(path), "rb") as handle:
            rows.append([path.name, descriptions.get(path.stem, "原工程音效"),
                         round(handle.getnframes() / handle.getframerate(), 3),
                         handle.getframerate(), handle.getnchannels(), handle.getsampwidth() * 8])
    with (folder / "每条音频是什么.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["文件", "用途", "时长秒", "采样率", "声道", "位深"])
        writer.writerows(rows)
    text(folder / "这个文件夹是什么.md", "# 原版音效与背景音乐\n\n来自现有整合工程与DSH音频目录，保留原始文件。\n已有制作记录标注为本地程序合成，未标成模型作曲。\n\n" +
         "\n".join(f"- `{row[0]}`：{row[1]}，{row[2]}秒。" for row in rows))


def audio_validation():
    rows = []
    problems = []
    for path in sorted((BASE / "07_恐怖音效").glob("0[123]_*.wav")):
        with wave.open(str(path), "rb") as f:
            channels, rate, width, length = f.getnchannels(), f.getframerate(), f.getsampwidth(), f.getnframes()
            values = np.frombuffer(f.readframes(length), dtype="<i2").reshape(-1, channels) / 32768
        peak = float(np.abs(values).max())
        head_tail = float(max(np.abs(values[0]).max(), np.abs(values[-1]).max()))
        rms = float(np.sqrt(np.mean(values ** 2)))
        ok = channels == 2 and rate == 48000 and width == 2 and .04 < peak < .9 and rms > .002 and head_tail < .001
        if not ok:
            problems.append(path.name)
        rows.append({"file": path.name, "seconds": length / rate, "peak": peak, "RMS": rms,
                     "endpoint_peak": head_tail, "pass": ok})
    text(BASE / "10_生成程序与验收/audio_validation.json", json.dumps(rows, ensure_ascii=False, indent=2))
    if problems or len(rows) != 9:
        raise RuntimeError(f"Audio QA failed: {problems}; count={len(rows)}")
    return rows


def contact_sheet():
    width = 1500
    canvas = Image.new("RGB", (width, 1360), "#172328")
    draw = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(str(FONT), 32)
    font = ImageFont.truetype(str(FONT), 21)
    draw.text((32, 20), "DL-Circle · UI与程序交付索引", font=title, fill="#d9efdf")
    for i, (dirname, label, _, _, screenshot, *_) in enumerate(MODULES):
        source = BASE / dirname / "预览" / screenshot
        x, y = 30 + (i % 2) * 740, 88 + (i // 2) * 410
        draw.text((x, y), f"{i+1:02d}  {label}", font=font, fill="#7ee0bf")
        if source.exists():
            image = Image.open(source).convert("RGB")
            image.thumbnail((705, 350))
            canvas.paste(image, (x, y + 40))
    draw.text((770, 950), "06  恐怖音效", font=font, fill="#7ee0bf")
    for i, line in enumerate(["射击 3 条", "冲击 3 条", "死亡 3 条", "带Godot随机变体播放器", "逐条用途、时长、来源说明"]):
        draw.text((790, 1000 + i * 40), line, font=font, fill="#e6e4d8")
    canvas.save(BASE / "00_全部内容预览.jpg", quality=92)


def offline_index():
    sections = []
    for dirname, title, programs, _, screenshot, _, purpose, _ in MODULES:
        url = f"{dirname}/预览/{screenshot}"
        sections.append(f'<section><h2>{html.escape(title)}</h2><a href="{html.escape(url)}"><img src="{html.escape(url)}"></a>'
                        f'<p>{html.escape(purpose)}</p><a href="{dirname}/这个文件夹是什么.md">说明与文件对照</a><ul>' +
                        "".join(f'<li><a href="{dirname}/程序与场景/{program}">{html.escape(program)}</a></li>' for program in programs) +
                        "</ul></section>")
    audio_rows = json.loads((BASE / "07_恐怖音效/音效清单.json").read_text(encoding="utf-8"))
    audio_html = "".join(f'<div class="sound"><b>{html.escape(row["文件"])}</b><p>{html.escape(row["听感"])} · {row["时长秒"]}秒</p>'
                         f'<audio controls preload="none" src="07_恐怖音效/{html.escape(row["文件"])}"></audio></div>'
                         for row in audio_rows)
    page = f"""<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>DL-Circle UI、程序与恐怖音效</title>
<style>body{{margin:0;background:#172328;color:#e0e8df;font:16px/1.6 "Microsoft YaHei",sans-serif}}
main{{max-width:1180px;margin:auto;padding:32px}}h1{{font-size:30px}}h2{{font-size:22px;color:#81ddba}}
a{{color:#9adbd5}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:32px}}
section{{border-top:1px solid #52636a;padding:16px 0}}img{{width:100%;height:auto}}audio{{width:100%;max-width:500px}}
.sound{{padding:16px 0;border-bottom:1px solid #52636a}}p{{color:#baccc7}}li{{word-break:break-all}}</style>
<main><h1>DL-Circle · UI、页面程序与恐怖音效</h1>
<p>打开 <b>01_Godot_UI预览工程/project.godot</b> 可运行标题页、指引、倒计时、暂停、设置和音效试听。
本页面是离线文件索引，可直接看图、听音效。</p>
<p><a href="00_总说明_每一项是什么.md">总说明与接入方法</a> · <a href="00_全部文件清单.csv">逐文件用途表</a></p>
<div class="grid">{"".join(sections)}</div>
<section><h2>射击、冲击、死亡 · 恐怖风格</h2><p>原创程序合成，无真人录音。48kHz立体声WAV，每类三种变体。</p>{audio_html}</section></main></html>"""
    text(BASE / "00_点我看图和听音效.html", page)


def file_inventory():
    rows = []
    skip = {".godot", "__pycache__"}
    for path in sorted(BASE.rglob("*")):
        if not path.is_file() or skip.intersection(path.relative_to(BASE).parts) or path.suffix in {".import", ".uid", ".log", ".pyc"}:
            continue
        rel = path.relative_to(BASE).as_posix()
        if path.name in {"00_全部文件清单.csv", "SHA256SUMS.txt"}:
            continue
        suffix = path.suffix.lower()
        kind = {".gd": "Godot程序", ".tscn": "Godot页面/场景", ".tres": "Godot主题/材质",
                ".gdshader": "Godot着色器", ".png": "UI图片/预览", ".jpg": "预览总图",
                ".wav": "音频", ".otf": "字体", ".ttf": "字体", ".md": "说明文档",
                ".py": "构建/合成程序", ".html": "离线看图听音效", ".csv": "对照表",
                ".json": "结构化清单", ".cmd": "Windows启动入口", ".ps1": "Windows启动脚本"}.get(suffix, "资源/配置")
        usage = image_description(path.name) if suffix == ".png" else kind + "：" + path.stem
        if path.name.startswith("01_射击"):
            usage = "恐怖射击音效"
        elif path.name.startswith("02_冲击"):
            usage = "恐怖冲击/命中音效"
        elif path.name.startswith("03_死亡"):
            usage = "恐怖死亡/失败音效"
        if path.name == "title_screen.gd":
            usage = "开始页程序：背景、按钮、设置、操作说明、音乐"
        if path.name == "game_config.gd":
            usage = "音量/全屏/视野设置存取与音频总线"
        if path.name == "screen_fade.gd":
            usage = "页面淡入淡出转场"
        if path.name == "horror_sound_bank.gd":
            usage = "恐怖音效播放器：随机变体与射速限制"
        if path.name == "delivery_preview.gd":
            usage = "交付预览界面，接游戏时可删除"
        if path.name == "test2_entry.tscn":
            usage = "交付预览入口，不包含游戏关卡"
        if path.name == "cycle_hud.gd":
            usage = "整合版HUD接入参考，需要游戏提供角色/回声数据"
        rows.append([rel, kind, usage, path.stat().st_size, hashlib.sha256(path.read_bytes()).hexdigest()])
    with (BASE / "00_全部文件清单.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["相对路径", "类型", "用途说明", "字节数", "SHA256"])
        writer.writerows(rows)
    text(BASE / "SHA256SUMS.txt", "\n".join(f"{row[4]}  {row[0]}" for row in rows))
    return rows


def validate_references():
    import re
    missing = []
    count = 0
    for path in PROJECT.rglob("*"):
        if not path.is_file() or ".godot" in path.parts or path.suffix not in {".gd", ".tscn", ".tres", ".gdshader"}:
            continue
        for ref in re.findall(r'res://[^"\'\s\)\],]+?\.(?:gdshader|png|svg|gd|tscn|tres|ttf|otf|wav)(?![A-Za-z0-9_])', path.read_text(encoding="utf-8-sig")):
            count += 1
            if not (PROJECT / ref.removeprefix("res://")).is_file():
                missing.append((path.relative_to(PROJECT).as_posix(), ref))
    text(BASE / "10_生成程序与验收/资源引用检查.json", json.dumps({"references": count, "missing": missing}, ensure_ascii=False, indent=2))
    if missing:
        raise RuntimeError(f"Missing resource references: {missing[:8]}")
    return count


def archive():
    target = BASE.parent / (BASE.name + ".zip")
    count = 0
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as handle:
        for path in sorted(BASE.rglob("*")):
            rel = path.relative_to(BASE)
            if not path.is_file() or {".godot", "__pycache__"}.intersection(rel.parts) or path.suffix in {".import", ".uid", ".pyc", ".log"}:
                continue
            if path.name.lower() in {"key.txt", ".env", "config.json"}:
                raise RuntimeError(f"Unexpected sensitive filename: {rel}")
            handle.write(path, arcname=(Path(BASE.name) / rel).as_posix())
            count += 1
    with zipfile.ZipFile(target) as handle:
        if handle.testzip() is not None:
            raise RuntimeError("ZIP CRC validation failed")
    print(json.dumps({"zip": str(target), "files": count, "MB": round(target.stat().st_size / 1048576, 2),
                      "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}, ensure_ascii=False, indent=2))


def image_validation():
    required = ["title", "title_settings", "title_help", "controls", "countdown", "pause", "settings", "audio",
                "controls_alpha", "compact_alpha", "clock_normal", "clock_warning", "clock_ghost",
                "pause_alpha", "settings_alpha", "logo_alpha",
                "title_960x540", "controls_960x540", "countdown_960x540", "pause_960x540", "settings_960x540"]
    rows = []
    for name in required:
        path = PROJECT / "captures" / (name + ".png")
        if not path.exists():
            raise RuntimeError("Missing capture: " + name)
        with Image.open(path).convert("RGBA") as image:
            lo, hi = image.getchannel("A").getextrema()
            rgb = np.asarray(image)[:, :, :3]
            if float(rgb.std()) < 2:
                raise RuntimeError("Blank capture: " + name)
            if ("alpha" in name or name.startswith("clock_")) and (lo > 5 or hi == 0):
                raise RuntimeError("Transparency missing: " + name)
            rows.append({"file": name, "width": image.width, "height": image.height,
                         "alpha_min": lo, "alpha_max": hi, "RGB_std": round(float(rgb.std()), 2)})
    for name, folder in [("pause_alpha", "05_暂停页面"), ("settings_alpha", "06_设置页面")]:
        with Image.open(PROJECT / "captures" / (name + ".png")).convert("RGBA") as image:
            bounds = image.getchannel("A").getbbox()
            image.crop(bounds).save(BASE / folder / "预览" / "菜单面板_透明裁切.png")
    text(BASE / "10_生成程序与验收/图片验收.json", json.dumps(rows, ensure_ascii=False, indent=2))
    return len(rows)


def main():
    module_folders()
    original_audio()
    copy(PROJECT / "scripts/horror_sound_bank.gd", BASE / "07_恐怖音效/horror_sound_bank.gd")
    copy(PROJECT / "assets/fonts/README.md", BASE / "09_共用UI素材与字体说明/字体与授权说明.md")
    for path in (PROJECT / "assets/fonts/licenses").glob("*"):
        if path.is_file():
            copy(path, BASE / "09_共用UI素材与字体说明/字体许可证" / path.name)
    copy(PROJECT / "ui/README.md", BASE / "09_共用UI素材与字体说明/原组件API说明.md")
    audio_rows = audio_validation()
    references = validate_references()
    pictures = image_validation()
    validation_log = (PROJECT / "ui_validation.log").read_text(encoding="utf-8-sig")
    import re
    result = re.search(r"DELIVERY_UI_RESULT: (\d+) checks, 0 failures", validation_log)
    if not result or "SCRIPT ERROR" in validation_log:
        raise RuntimeError("UI functional validation has not passed")
    text(BASE / "10_生成程序与验收/验收结果.md",
         f"# 交付验收结果\n\n- Godot UI功能检查：{result.group(1)}项通过，0失败。\n"
         f"- 静态资源引用检查：{references}处引用，缺失0。\n"
         f"- 图片检查：{pictures}张实际渲染，含1280×720和960×540；透明图确认存在Alpha通道。\n"
         "- 新音频：9条全部通过48kHz/双声道/16-bit/非静音/无削波/首尾淡化检查。\n"
         "- 压缩包排除Godot缓存、API密钥和日志；打包后检查ZIP CRC。\n"
         "- 程序检查不等同于音乐听感评审，音效可通过离线HTML或Godot试听页直接试听。\n\n"
         "## 功能检查原始结果\n\n```text\n" + validation_log + "\n```\n")
    contact_sheet()
    offline_index()
    rows = file_inventory()
    print("references=", references, "audio_pass=", len(audio_rows), "inventory=", len(rows))
    archive()


if __name__ == "__main__":
    main()
