"""synth 来源的风格模板：节奏、调式、速度范围、配器（GM 程序号，MuseScore_General）。

鼓谱字符：X 重音 / x 普通 / o 轻 / g 幽灵音 / . 休止；每条 16 个字符 = 一小节 16 分音符。
贝斯谱：r 根音 / 3 / 5 / 7 / o 高八度根音 / - 延音 / . 休止。和弦谱：x 整个和弦 / a b c d 单个和弦音 / - 延音 / . 休止。
"""

from .compose import Part, Style

D = Part  # 缩写

STYLES: dict[str, Style] = {}


def add(st: Style) -> None:
    STYLES[st.id] = st


add(Style(
    id="house", genre="house", bpm=(120, 128), modes=["minor", "dorian"], kit=24, keys=[0, 2, 5, 7, 9, 10],
    drums={"kick": ["X...X...X...X..."], "clap": ["....X.......X..."], "chat": ["x.x.x.x.x.x.x.x."], "ohat": ["..x...x...x...x."]},
    bass=["..r...r...r...r.", "..r..or...r..5r.", ".r-.r-.r-.r-.o-."],
    chords=["..x...x...x...x.", "x--.x--.x---x---", ".x..x..x..x..x.."], lead_density=0.45, seventh=True,
    parts=[D("Drums", "drums", "drums", 24), D("Bass", "bass", "bass", 38, -1), D("Chords", "chords", "chords", 4, -5),
           D("Lead", "lead", "lead", 81, -6), D("Pad", "pad", "pad", 89, -9), D("Arp", "arp", "arp", 46, -9)],
    tags=["dance", "four-on-the-floor"],
))
add(Style(
    id="hiphop", genre="hip-hop", bpm=(82, 96), modes=["minor", "dorian"], kit=8, swing=0.18, keys=[0, 2, 3, 5, 7, 9, 10],
    drums={"kick": ["X.....x...X..x..", "X..x..x...X....."], "snare": ["....X.......X...", "....X.......X..o"], "chat": ["x.x.x.x.x.x.x.x.", "x.xxx.x.x.x.xxx."]},
    bass=["r.....r...r..5..", "r--.....r-.5-..."], chords=["x-----.....x....", "x-..x-..x-..x-.."], lead_density=0.35, seventh=True,
    parts=[D("Drums", "drums", "drums", 8), D("Bass", "bass", "bass", 39, -1), D("Keys", "keys", "chords", 4, -5),
           D("Lead", "lead", "lead", 11, -6), D("Strings", "strings", "pad", 49, -9), D("Perc", "perc", "perc", 0, -9)],
    tags=["boom-bap", "groove"],
))
add(Style(
    id="lofi", genre="lo-fi", bpm=(70, 84), modes=["dorian", "major", "minor"], kit=8, swing=0.22, keys=[0, 2, 3, 5, 7, 8, 10],
    drums={"kick": ["X.....o..x......", "X......o.x.....o"], "snare": ["....x.......x..o", "....x..g....x..."], "chat": ["o.o.o.o.o.o.o.o.", "o.o.o.oo.o.o.o.o"]},
    bass=["r-----..r---5-..", "r-.....r..o-5..."], chords=["x-------x-------", "x-----..x--.x..."], lead_density=0.3, seventh=True,
    parts=[D("Drums", "drums", "drums", 8), D("Bass", "bass", "bass", 33), D("Rhodes", "keys", "chords", 4, -4),
           D("Guitar", "guitar", "lead", 24, -6), D("Pad", "pad", "pad", 89, -10), D("Vibes", "arp", "arp", 11, -10)],
    tags=["chill", "study"],
))
add(Style(
    id="trap", genre="trap", bpm=(136, 150), modes=["minor", "phrygian"], kit=25, keys=[0, 1, 3, 5, 6, 8, 10],
    drums={"kick": ["X.......X.x....."], "snare": ["........X......."], "clap": ["........x......."],
           "chat": ["x.x.x.x.x.x.x.xx", "xxxx.x.xxxxx..xx"], "ohat": ["...............x"]},
    bass=["r-------r-5-----", "r-----r-r---5-r-"], chords=["x---------------", "x-----x-x-------"], lead_density=0.3,
    parts=[D("Drums", "drums", "drums", 25), D("808", "bass", "bass", 39, -1, 0), D("Keys", "keys", "chords", 98, -7),
           D("Bell", "lead", "lead", 10, -7, 1), D("Choir", "pad", "pad", 52, -9), D("Celesta", "arp", "arp", 8, -10)],
    tags=["808", "half-time"],
))
add(Style(
    id="dnb", genre="drum-and-bass", bpm=(168, 176), modes=["minor", "phrygian"], kit=16, keys=[0, 2, 5, 7, 9, 10],
    drums={"kick": ["X.........x....."], "snare": ["....X.......X..."], "chat": ["x.x.x.x.x.x.x.x."], "ohat": ["......x.......x."]},
    bass=["r-------r-----5-", "r-------r---o---"], chords=["x---------------", "x-------x-------"], lead_density=0.4,
    parts=[D("Drums", "drums", "drums", 16), D("Sub", "bass", "bass", 38, -1), D("Stabs", "chords", "chords", 90, -7),
           D("Lead", "lead", "lead", 80, -8), D("Pad", "pad", "pad", 89, -9), D("Arp", "arp", "arp", 98, -11)],
    tags=["breakbeat", "energetic"],
))
add(Style(
    id="funk", genre="funk", bpm=(98, 112), modes=["dorian", "mixolydian"], kit=0, swing=0.1, keys=[0, 2, 5, 7, 9, 10],
    drums={"kick": ["X..x..x...X..x.."], "snare": ["....X..o.o..X..o"], "chat": ["xoxoxoxoxoxoxoxo"], "ohat": ["......X........."]},
    bass=["r..r.or..r..5.r.", "r.or..r.r..o5.r."], chords=["x..x..x.x..x..x.", "..x.x..x..x.x..x"], lead_density=0.5, seventh=True,
    parts=[D("Drums", "drums", "drums", 0), D("Bass", "bass", "bass", 36, -1), D("Clav", "keys", "chords", 7, -5),
           D("Brass", "lead", "lead", 61, -6), D("Organ", "pad", "pad", 16, -10), D("Perc", "perc", "perc", 0, -9)],
    tags=["groove", "slap"],
))
add(Style(
    id="ambient", genre="ambient", bpm=(62, 78), modes=["major", "minor", "dorian"], kit=0, keys=[0, 2, 3, 5, 7, 9, 10],
    drums={}, bass=["r---------------"], chords=["x---------------"], lead_density=0.12, seventh=True,
    parts=[D("Warm Pad", "pad", "pad", 89, -2), D("Strings", "strings", "pad", 48, -4, 1), D("Drone", "bass", "bass", 38, -2),
           D("Bells", "lead", "lead", 98, -8, 1), D("Choir", "fx", "pad", 52, -8), D("Kalimba", "arp", "arp", 108, -8)],
    tags=["calm", "atmospheric"],
))
add(Style(
    id="chiptune", genre="chiptune", bpm=(128, 150), modes=["minor", "major"], kit=24, keys=[0, 2, 4, 5, 7, 9],
    drums={"kick": ["X...x...X...x..."], "snare": ["....X.......X..."], "chat": ["x.xxx.xxx.xxx.xx"]},
    bass=["r.r.o.r.r.r.o.r.", "r.rr.r.or.rr.r.o"], chords=["x.x.x.x.x.x.x.x."], lead_density=0.6,
    parts=[D("Drums", "drums", "drums", 24, -1), D("Bass", "bass", "bass", 80, -4, 1), D("Pulse", "keys", "arp", 80, -9),
           D("Lead", "lead", "lead", 80, -7), D("Saw", "pad", "pad", 81, -12), D("Arp", "arp", "arp", 81, -11, 1)],
    tags=["8-bit", "retro-game"],
))
add(Style(
    id="synthwave", genre="synthwave", bpm=(98, 116), modes=["minor", "dorian"], kit=16, keys=[0, 2, 3, 5, 7, 9, 10],
    drums={"kick": ["X.......X.......", "X.....x.X......."], "snare": ["....X.......X..."], "chat": ["x.x.x.x.x.x.x.x."]},
    bass=["r.r.r.r.r.r.r.r.", "r.rr.r.or.rr.r.o"], chords=["x---------------", "x-----x-x-------"], lead_density=0.4, seventh=True,
    parts=[D("Drums", "drums", "drums", 16), D("Bass", "bass", "bass", 38, -2), D("Poly", "keys", "chords", 90, -7),
           D("Lead", "lead", "lead", 81, -6), D("Strings", "strings", "pad", 50, -9), D("Arp", "arp", "arp", 5, -10)],
    tags=["retro", "neon"],
))
add(Style(
    id="disco", genre="disco", bpm=(114, 122), modes=["major", "dorian"], kit=0, keys=[0, 2, 5, 7, 9],
    drums={"kick": ["X...X...X...X..."], "snare": ["....X.......X..."], "chat": ["x.x.x.x.x.x.x.x."], "ohat": ["..X...X...X...X."]},
    bass=["r.or.r.or.r.or.r.", "r.o.r.o.r.o.r.o."], chords=["x.xx.x.xx.xx.x.x", "x..x.x..x..x.x.."], lead_density=0.5, seventh=True,
    parts=[D("Drums", "drums", "drums", 0), D("Bass", "bass", "bass", 33), D("Guitar", "guitar", "chords", 28, -5),
           D("Brass", "lead", "lead", 61, -6), D("Strings", "strings", "pad", 48, -9), D("Perc", "perc", "perc", 0, -9)],
    tags=["party", "four-on-the-floor"],
))
