"""Original procedural sound design, no samples or voice models.

Run with Python 3.12+ and numpy. Outputs 48 kHz stereo PCM16 WAV.
The source game is never modified.
"""

import csv
import json
import math
from pathlib import Path
import wave

import numpy as np

RATE = 48000
BASE = Path(__file__).resolve().parents[1]
OUT = BASE / "07_恐怖音效"
ASSET_OUT = BASE / "01_Godot_UI预览工程" / "assets" / "audio" / "horror"
RNG = np.random.default_rng(20261107)
ROWS = []
WAVES = []


def noise(n, low=120, high=9000):
    data = RNG.normal(0, 1, n)
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    mask = (1 - np.exp(-((freqs / low) ** 4))) / np.sqrt(1 + (freqs / high) ** 8)
    result = np.fft.irfft(np.fft.rfft(data) * mask, n)
    return result / max(np.std(result), 1e-6)


def sweep(t, start, end, decay):
    freq = end + (start - end) * np.exp(-t * decay)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def reverberate(x, strength=.22):
    y = x.copy()
    for i, delay in enumerate((.023, .041, .067, .113, .181, .293, .419)):
        shift = int(delay * RATE)
        if shift < len(x):
            y[shift:] += x[:-shift] * strength * .76**i * (-1 if i % 3 == 0 else 1)
    return y


def write(name, x, purpose, desc, gain):
    OUT.mkdir(parents=True, exist_ok=True)
    ASSET_OUT.mkdir(parents=True, exist_ok=True)
    left = reverberate(x, .24)
    right = reverberate(x, .29)
    shift = int(.007 * RATE)
    right[shift:] = right[shift:] * .87 + left[:-shift] * .13
    data = np.column_stack((left, right))
    fade = min(int(.009 * RATE), len(x) // 4)
    data[:fade] *= np.linspace(0, 1, fade)[:, None]
    tail = min(int(.12 * RATE), len(x) // 3)
    data[-tail:] *= np.linspace(1, 0, tail)[:, None] ** 2
    data -= data.mean(axis=0)
    data[:fade] *= np.linspace(0, 1, fade)[:, None]
    data[-fade:] *= np.linspace(1, 0, fade)[:, None]
    data *= gain / max(np.max(np.abs(data)), 1e-9)
    pcm = np.round(data * 32767).astype("<i2")
    for folder in (OUT, ASSET_OUT):
        with wave.open(str(folder / name), "wb") as handle:
            handle.setnchannels(2)
            handle.setsampwidth(2)
            handle.setframerate(RATE)
            handle.writeframes(pcm.tobytes())
    row = {
        "文件": name, "用途": purpose, "听感": desc,
        "时长秒": round(len(x) / RATE, 3), "采样率": RATE, "声道": 2, "位深": 16,
        "峰值dBFS": round(20 * math.log10(float(np.max(np.abs(data)))), 2),
        "RMS_dBFS": round(20 * math.log10(float(np.sqrt(np.mean(data**2)))), 2),
        "来源": "Codex原创程序合成，无采样、无人声、非模型音效",
    }
    ROWS.append(row)
    WAVES.append(data)
    print(name, row["时长秒"], "s", row["峰值dBFS"], "dBFS")


def main():
    for variant, seconds in enumerate((.48, .62, .78)):
        t = np.arange(round(seconds * RATE)) / RATE
        crack = noise(len(t), 900, 11000) * np.exp(-t * (85 - variant * 10))
        body = sweep(t, 210 - variant * 20, 47, 38) * np.exp(-t * 16)
        ring = np.zeros(len(t))
        for k, freq in enumerate((743, 1229, 2087, 3011)):
            ring += .09 * np.sin(2 * np.pi * freq * (1 + variant * .13) * t) * np.exp(-t * (11 + k * 4))
        if variant == 1:
            ring += .16 * sweep(t, 2800, 300, 18) * np.exp(-t * 13)
        elif variant == 2:
            ring += .22 * sweep(t, 130, 39, 8) * np.exp(-t * 9)
        x = .4 * crack + .7 * body + ring
        name, desc = [
            ("安保气动枪", "短促气压爆裂、冷金属尾音，适合炮塔连续射击"),
            ("电弧穿刺", "电击尖啸与下坠低频，适合能量弹发射"),
            ("生化脉冲", "湿润脉冲与不稳定共振，适合生化武器"),
        ][variant]
        write(f"01_射击_0{variant+1}_{name}.wav", x, "射击/发射", desc, .63)

    for variant, seconds in enumerate((1.35, 1.15, 2.0)):
        t = np.arange(round(seconds * RATE)) / RATE
        thud = .65 * sweep(t, 150, 32, 20) * np.exp(-t * (7 if variant == 2 else 13))
        grit = .18 * noise(len(t), 200, 7500) * np.exp(-t * (11 if variant == 1 else 19))
        metal = sum(.1 / (k + 1) * np.sin(2 * np.pi * freq * t) * np.exp(-t * (2.8 + k))
                    for k, freq in enumerate((233, 397, 661, 1009, 1583)))
        if variant == 1:
            metal = .12 * noise(len(t), 1500, 12000) * np.exp(-t * 7)
            for delay in (.12, .19, .29, .37):
                start = int(delay * RATE)
                metal[start:] += .06 * noise(len(t) - start, 2000, 11000) * np.exp(-np.arange(len(t) - start) / RATE * 28)
        if variant == 2:
            metal *= .3
            thud += .25 * np.sin(2 * np.pi * 37 * t) * np.exp(-t * 2.8)
        name, desc = [
            ("金属重击", "低频闷砸、非谐金属长鸣，适合击中门或护甲"),
            ("玻璃与肉质", "碎裂、湿润撞击与散落颗粒，适合命中实验体或玻璃"),
            ("低频爆震", "下沉震波、管道回响，适合重击和场景震动"),
        ][variant]
        write(f"02_冲击_0{variant+1}_{name}.wav", thud + grit + metal, "命中/冲击", desc, .67)

    for variant, seconds in enumerate((2.6, 3.2, 3.8)):
        t = np.arange(round(seconds * RATE)) / RATE
        fall = sweep(t, 155 + variant * 35, 24 + variant * 3, 2.4)
        beating = .5 + .5 * np.sin(2 * np.pi * (7.3 + variant) * t)
        body = .42 * fall * np.exp(-t * 1.9) * (.6 + .4 * beating)
        texture = noise(len(t), 160, 2600)
        breath = texture * (.4 + .6 * np.sin(np.pi * np.minimum(t / seconds, 1))) * np.exp(-t * 1.2) * .13
        dissonance = sum(.055 * np.sin(2 * np.pi * f * t + np.sin(t * 4.1)) for f in (81, 86.3, 121.7))
        dissonance *= np.exp(-t * 1.3)
        x = body + breath + dissonance
        if variant == 0:
            for delay in (.08, .21, .34):
                start = round(delay * RATE)
                x[start:] += .13 * noise(len(t) - start, 1000, 9000) * np.exp(-np.arange(len(t) - start) / RATE * 19)
        elif variant == 1:
            x += .12 * texture * np.exp(-((t - .6) / .32) ** 2)
        else:
            rise = np.exp(-((t - .7) / .55) ** 2)
            x += .17 * sweep(t, 90, 510, 2.0) * rise
            x += .12 * sweep(t, 420, 33, 1.7) * np.exp(-np.maximum(t - .8, 0) * 1.2)
        name, desc = [
            ("实验体崩解", "组织碎裂、低频失速与冷空气尾响"),
            ("窒息回声", "合成气息、心跳失稳与空房间残响，无真人录音"),
            ("循环吞噬", "反向吸入、失谐下坠和漫长尾音，适合死亡转场"),
        ][variant]
        write(f"03_死亡_0{variant+1}_{name}.wav", x, "角色死亡/失败转场", desc, .65)

    gap = np.zeros((int(RATE * .65), 2))
    montage = np.concatenate([piece for data in WAVES for piece in (data * .8, gap)])
    with wave.open(str(OUT / "00_九条音效连续试听_顺序见清单.wav"), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(np.round(montage * 32767).astype("<i2").tobytes())
    (OUT / "音效清单.json").write_text(json.dumps(ROWS, ensure_ascii=False, indent=2), encoding="utf-8")
    with (OUT / "音效清单.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(ROWS[0]))
        writer.writeheader()
        writer.writerows(ROWS)
    lines = ["# 恐怖音效：逐条说明", "", "原创程序合成；48 kHz、双声道、16-bit PCM WAV；无真人采样。", "",
             "| 文件 | 时长 | 用途与听感 |", "|---|---:|---|"]
    for row in ROWS:
        lines.append(f"| {row['文件']} | {row['时长秒']}秒 | {row['听感']} |")
    lines += ["", "射击尽量用短变体；死亡音效允许尾音自然结束。Godot 建议放 SFX 总线，默认播放器为 -8 dB，可按游戏混音调整。",
              "", "Godot 播放器：`scripts/horror_sound_bank.gd`，fire()/impact()/death() 随机选变体且避免连续重复。",
              "", "本目录的连续试听按表格从上到下播放，每条之间留 0.65 秒静音。"]
    (OUT / "每一条是什么.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
