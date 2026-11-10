extends Node
# Звук і музика. Жодних зовнішніх файлів: усе синтезується кодом під час запуску
# (у фоновому потоці, тож меню не підвисає). Клавіша M вмикає/вимикає музику.
# Використання з будь-якого скрипта: Sfx.play("hit"), Sfx.play_at("groan1", позиція), Sfx.music("battle").

const RATE := 22050
const MRATE := 16000
const MUSIC_DB := -9.0
const IMPACT_DB := -17.0   # поправка для звуків ударів (мінус = тихіше); змініть, якщо треба тихіше чи гучніше
const SHOT_DB := -6.0     # поправка для звуків пострілів, метання та магії
const BATTLE_DB := -2.0   # гучність основи бойової музики (барабани, баси, пад)
const VIOLIN_DB := -6.0   # гучність скрипки поверх бойової музики (мінус = тихіше)
const BASS_DB := -2.5     # гучність бас-гітари (грає від першого спаду до кінця, у т.ч. разом з барабанами)
const AMB_DB := -16.0     # гучність фонового шуму базару на екрані броні (мінус = тихіше)

const W_SIN := 0
const W_SAW := 1
const W_SQR := 2
const W_TRI := 3
const W_NOI := 4

var ready_ok := false       # звуки й музика меню готові
var battle_ready := false   # довга бойова музика (синтезується пізніше, окремим кроком) готова
var music_on := true
var _abort := false
var _bank := {}

var _sounds := {}
var _gain := {}
var _tracks := {}
var _pool: Array = []
var _pool_i := 0
var _players := {}
var _tweens := {}
var _cur := ""
var _amb_cur := ""
var _amb := {}
var _battle_layers := {}
var _battle_intensity := 0.0
var _battle_target := 0.0
var _last := {}
var _thread: Thread
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # Обмежувач на головній шині: музика гучна, тож піки не мають хрипіти.
    var lim := AudioEffectLimiter.new()
    lim.ceiling_db = -1.0
    lim.threshold_db = -4.0
    AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), lim)
    for i in range(14):
        var p := AudioStreamPlayer.new()
        add_child(p)
        _pool.append(p)
    for k in ["menu", "battle"]:
        var mp := AudioStreamPlayer.new()
        mp.volume_db = -60.0
        add_child(mp)
        _players[k] = mp
    # Шари бою не є фоновою музикою меню: вони запускаються лише в level.gd.
    for k in ["tension", "drive", "horde", "violin", "bass"]:
        var bp := AudioStreamPlayer.new()
        bp.volume_db = -60.0
        add_child(bp)
        _battle_layers[k] = bp
    for k in ["market"]:
        var ap := AudioStreamPlayer.new()
        ap.volume_db = -60.0
        add_child(ap)
        _amb[k] = ap
    _thread = Thread.new()
    _thread.start(_build_all)

func _exit_tree() -> void:
    _abort = true
    if _thread != null and _thread.is_started():
        _thread.wait_to_finish()

# Два етапи: спершу звуки, музика меню й шум базару (швидко, щоб меню не мовчало), а потім —
# довга бойова музика (272 с із скрипкою й бас-гітарою), яка синтезується довше. Якщо бій
# почнеться раніше, музика просто вмикається, щойно буде готова.
func _build_all() -> void:
    _rng.seed = 20260
    _build_sfx()
    _tracks["menu"] = _make_menu_music()
    _tracks["market"] = _make_market_ambience()
    _built.call_deferred()
    if _abort:
        return
    var bt := _build_battle_tracks()
    if _abort:
        return
    _battle_built.call_deferred(bt)

func _built() -> void:
    ready_ok = true
    _apply_music()

func _battle_built(bt: Dictionary) -> void:
    if _thread.is_started():
        _thread.wait_to_finish()
    for k in bt:
        _tracks[k] = bt[k]
    battle_ready = true
    _apply_music()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if int(event.physical_keycode) == int(KEY_M):
            toggle_music()

func toggle_music() -> void:
    music_on = not music_on
    _apply_music()

func _process(delta: float) -> void:
    # Не змінюємо меню або його атмосферу. Цей мікс живе тільки під час бою.
    _battle_intensity = move_toward(_battle_intensity, _battle_target, delta * 0.32)
    _update_battle_layers(delta)

# ================= Публічний інтерфейс =================
func play(snd: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
    snd = _combat_variant(snd)
    if not ready_ok or not _sounds.has(snd):
        return
    var now := Time.get_ticks_msec()
    var last: int = int(_last.get(snd, -1000))
    if now - last < 35:
        return
    _last[snd] = now
    var p: AudioStreamPlayer = null
    for c in _pool:
        if not c.playing:
            p = c
            break
    if p == null:
        p = _pool[_pool_i]
        _pool_i = (_pool_i + 1) % _pool.size()
    p.stream = _sounds[snd]
    p.volume_db = vol_db + float(_gain.get(snd, 0.0))
    p.pitch_scale = pitch * randf_range(0.95, 1.05)
    p.play()

# Звук у світі: що далі від гравця, то тихіше.
func play_at(snd: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
    var db := vol_db
    var listener: Node3D = get_tree().get_first_node_in_group("player") as Node3D
    if listener != null:
        var d := Vector2(pos.x - listener.global_position.x, pos.z - listener.global_position.z).length()
        if d > 40.0:
            return
        db -= minf(d * 0.8, 30.0)
    play(snd, db, pitch)

func groan_at(pos: Vector3) -> void:
    play_at("groan%d" % (1 + randi() % 3), pos)

func music(track: String) -> void:
    _cur = track
    if track != "battle":
        _battle_target = 0.0
    _apply_music()

# Дані надходять лише зі сцени бою. Тривога залежить від натовпу, близькості,
# хвилі, здоров'я героя та присутності боса, а не від меню чи екранів крамниць.
func set_battle_state(zombies: int, waiting_to_spawn: int, health_ratio: float, nearest_ratio: float, boss_present: bool) -> void:
    var crowd := clampf(float(zombies) / 22.0, 0.0, 1.0)
    var incoming := clampf(float(waiting_to_spawn) / 45.0, 0.0, 1.0)
    var wounded := clampf((0.55 - health_ratio) / 0.55, 0.0, 1.0)
    var close := clampf(nearest_ratio, 0.0, 1.0)
    var target := crowd * 0.58 + incoming * 0.16 + close * 0.18 + wounded * 0.16
    if boss_present:
        target += 0.38
    _battle_target = clampf(target, 0.0, 1.0)

func _combat_variant(id: String) -> String:
    if _cur != "battle":
        return id
    var suffix := ""
    if _battle_intensity >= 0.70:
        suffix = "_horde"
    elif _battle_intensity >= 0.34:
        suffix = "_tense"
    if suffix != "" and _sounds.has(id + suffix):
        return id + suffix
    return id

# Фоновий шум місця (наприклад, базару на екрані броні): Sfx.ambience("market"), вимкнути — Sfx.ambience("").
# Вимикається разом із музикою (клавіша M).
func ambience(track: String) -> void:
    _amb_cur = track
    _apply_music()

func _apply_ambience() -> void:
    for k in _amb:
        var p: AudioStreamPlayer = _amb[k]
        var key := "amb_" + String(k)
        var want: bool = (String(k) == _amb_cur) and music_on
        if _tweens.has(key):
            var old: Tween = _tweens[key]
            if old != null and old.is_valid():
                old.kill()
        if want:
            if not p.playing:
                p.stream = _tracks[k]
                p.volume_db = -60.0
                p.play()
            var tw := create_tween()
            _tweens[key] = tw
            tw.tween_property(p, "volume_db", AMB_DB, 1.5)
        elif p.playing:
            var tw2 := create_tween()
            _tweens[key] = tw2
            tw2.tween_property(p, "volume_db", -60.0, 0.8)
            tw2.tween_callback(p.stop)

func _apply_music() -> void:
    if not ready_ok:
        return
    _apply_ambience()
    for k in _players:
        var p: AudioStreamPlayer = _players[k]
        var want: bool = (String(k) == _cur) and music_on
        if _tweens.has(k):
            var old: Tween = _tweens[k]
            if old != null and old.is_valid():
                old.kill()
        if want and not _tracks.has(k):
            continue   # бойова музика ще синтезується: увімкнеться, щойно буде готова
        if want:
            if not p.playing:
                p.stream = _tracks[k]
                p.volume_db = -60.0
                p.play()
            var tw := create_tween()
            _tweens[k] = tw
            var target := MUSIC_DB
            var fade_in := 1.5
            if String(k) == "battle":
                target = BATTLE_DB
                fade_in = 0.35
            if _amb_cur != "":
                target -= 6.0
            tw.tween_property(p, "volume_db", target, fade_in)
        elif p.playing:
            var tw2 := create_tween()
            _tweens[k] = tw2
            tw2.tween_property(p, "volume_db", -60.0, 1.2)
            tw2.tween_callback(p.stop)

# Шари бою додаються поступово: мало зомбі — лише основа, більше — хвилюючий бас і хети, ще більше —
# рубаний ритм, найбільше — повний натовп. Скрипка й бас-гітара звучать завжди (поріг -1 = одразу на
# повну гучність): це частини самої композиції, їх розташування в часі зашите в доріжки. Усі шари
# мають однакову довжину (272 с) і один темп, тож завжди звучать синхронно.
const LAYER_RULES := {
    "tension": [0.05, -8.0],
    "drive": [0.32, -7.0],
    "horde": [0.58, -6.0],
    "violin": [-1.0, VIOLIN_DB],
    "bass": [-1.0, BASS_DB],
}

func _update_battle_layers(delta: float) -> void:
    if not ready_ok or not battle_ready:
        return
    var active := music_on and _cur == "battle"
    var base: AudioStreamPlayer = _players["battle"]
    if active and base.playing:
        var speed := 0.92 + _battle_intensity * 0.24
        base.pitch_scale = lerpf(base.pitch_scale, speed, minf(1.0, delta * 2.0))
    elif not base.playing:
        base.pitch_scale = 0.92
    for k in _battle_layers:
        var p: AudioStreamPlayer = _battle_layers[k]
        if not active:
            if p.playing:
                p.volume_db = move_toward(p.volume_db, -60.0, delta * 40.0)
                if p.volume_db <= -59.0 or not base.playing:
                    p.stop()
            continue
        if not p.playing:
            p.stream = _tracks["battle_" + String(k)]
            p.volume_db = -60.0
            p.pitch_scale = base.pitch_scale
            p.play(base.get_playback_position() if base.playing else 0.0)
        p.pitch_scale = base.pitch_scale
        var rule: Array = LAYER_RULES[String(k)]
        var layer := clampf((_battle_intensity - float(rule[0])) / 0.25, 0.0, 1.0)
        layer = pow(layer, 0.6)
        var target_db := lerpf(-60.0, float(rule[1]), layer)
        p.volume_db = move_toward(p.volume_db, target_db, delta * 14.0)

# ================= Синтез =================
func _new(sec: float, rate: int = RATE) -> PackedFloat32Array:
    var b := PackedFloat32Array()
    b.resize(int(sec * float(rate)))
    return b

# Один "голос": хвиля зі зміною висоти від f0 до f1, затуханням, атакою, фільтром і вібрато.
func _tone(b: PackedFloat32Array, rate: int, t0: float, dur: float, f0: float, f1: float, wave: int, amp: float, decay: float = 4.0, attack: float = 0.004, lp: float = 1.0, vib_hz: float = 0.0, vib: float = 0.0) -> void:
    var n0 := int(t0 * float(rate))
    var n := int(dur * float(rate))
    if n <= 0:
        return
    var att := maxf(1.0, attack * float(rate))
    var ph := 0.0
    var y := 0.0
    var ratio := f1 / f0
    for i in range(n):
        var idx := n0 + i
        if idx >= b.size():
            break
        var t := float(i) / float(n)
        var f := f0 * pow(ratio, t)
        if vib > 0.0:
            f *= 1.0 + vib * sin(TAU * vib_hz * float(i) / float(rate))
        ph += f / float(rate)
        var fr := ph - floorf(ph)
        var s := 0.0
        match wave:
            0:
                s = sin(TAU * ph)
            1:
                s = 2.0 * fr - 1.0
            2:
                s = 1.0 if fr < 0.5 else -1.0
            3:
                s = 4.0 * absf(fr - 0.5) - 1.0
            _:
                s = _rng.randf() * 2.0 - 1.0
        y += (s - y) * lp
        b[idx] += y * amp * minf(1.0, float(i) / att) * exp(-decay * t)

# М'який смуговий шум: замість "піксельного" білого шуму дає повітря, пил,
# тканину й вологу фактуру. Використовуємо лише для бойових ефектів.
func _air_noise(b: PackedFloat32Array, rate: int, t0: float, dur: float, amp: float, decay: float, low: float = 0.035, high: float = 0.32) -> void:
    var n0 := int(t0 * float(rate))
    var n := int(dur * float(rate))
    var slow := 0.0
    var fast := 0.0
    for i in range(n):
        var idx := n0 + i
        if idx >= b.size():
            break
        var white := _rng.randf_range(-1.0, 1.0)
        slow += (white - slow) * low
        fast += (white - fast) * high
        var t := float(i) / float(maxi(n, 1))
        var env := minf(1.0, float(i) / maxf(1.0, float(rate) * 0.008)) * exp(-decay * t)
        b[idx] += (fast - slow * 0.82) * amp * env

# Нерівний низький голос із диханням і формантами — більш тілесний за просту пилку.
func _voice(b: PackedFloat32Array, rate: int, t0: float, dur: float, f0: float, f1: float, amp: float, rasp: float = 0.22) -> void:
    var n0 := int(t0 * float(rate))
    var n := int(dur * float(rate))
    var ph := 0.0
    var breath := 0.0
    for i in range(n):
        var idx := n0 + i
        if idx >= b.size():
            break
        var t := float(i) / float(maxi(n, 1))
        var glide := f0 * pow(f1 / f0, t)
        var wobble := 1.0 + 0.024 * sin(TAU * (3.1 + 0.7 * sin(TAU * 0.9 * t)) * float(i) / float(rate))
        ph += glide * wobble / float(rate)
        breath += (_rng.randf_range(-1.0, 1.0) - breath) * 0.18
        var voiced := sin(TAU * ph) + 0.42 * sin(TAU * ph * 2.03 + 0.4) + 0.16 * sin(TAU * ph * 3.87 + 1.2)
        var throat := 0.75 + 0.25 * sin(TAU * 2.2 * t + 0.8)
        var env := minf(1.0, float(i) / maxf(1.0, float(rate) * 0.025)) * exp(-1.35 * t)
        b[idx] += (voiced * throat + breath * rasp) * amp * env

func _whoosh(b: PackedFloat32Array, rate: int, t0: float, dur: float, amp: float, heavy: bool = false) -> void:
    _air_noise(b, rate, t0, dur, amp * (0.75 if heavy else 0.55), 3.5, 0.018, 0.44)
    _tone(b, rate, t0 + dur * 0.18, dur * 0.68, 180.0 if heavy else 300.0, 68.0 if heavy else 150.0, W_SIN, amp * 0.28, 4.0, 0.006, 0.22)
    _tone(b, rate, t0 + dur * 0.05, dur * 0.75, 820.0, 310.0, W_SIN, amp * 0.10, 4.0, 0.003, 0.28, 5.5, 0.015)

func _flesh_impact(b: PackedFloat32Array, rate: int, t0: float, amp: float, large: bool = false) -> void:
    var tail := 0.46 if large else 0.27
    _tone(b, rate, t0, tail, 118.0 if large else 168.0, 34.0 if large else 56.0, W_SIN, amp * 0.82, 5.5, 0.002)
    _air_noise(b, rate, t0, tail, amp * 0.72, 7.5, 0.05, 0.58)
    _air_noise(b, rate, t0 + 0.018, tail * 0.72, amp * 0.42, 5.0, 0.012, 0.18)
    _tone(b, rate, t0 + 0.01, tail * 0.58, 310.0, 96.0, W_SIN, amp * 0.16, 5.0, 0.004, 0.16)

func _wav(b: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
    var n := b.size()
    var peak := 0.0001
    for i in range(n):
        peak = maxf(peak, absf(b[i]))
    var k := 0.9 / peak
    var bytes := PackedByteArray()
    bytes.resize(n * 2)
    var fade := 0
    if not loop:
        fade = mini(200, n)
    for i in range(n):
        var v := b[i] * k
        if fade > 0 and i >= n - fade:
            v *= float(n - i) / float(fade)
        bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = rate
    s.stereo = false
    s.data = bytes
    if loop:
        s.loop_mode = AudioStreamWAV.LOOP_FORWARD
        s.loop_begin = 0
        s.loop_end = n
    return s

func _is_impact(id: String) -> bool:
    return id.begins_with("swing") or id.begins_with("hit") or id.begins_with("zhit") or id == "crit" or id == "slam" or id == "explosion" or id == "player_hurt"

func _reg(id: String, b: PackedFloat32Array, gain_db: float = 0.0) -> void:
    _sounds[id] = _wav(b, RATE, false)
    var g := gain_db
    if _is_impact(id):
        g += IMPACT_DB
    elif id == "bow" or id == "xbow" or id == "gun" or id == "throw" or id == "fire" or id == "zap" or id == "water" or id == "ice":
        g += SHOT_DB
    _gain[id] = g

# ================= Звукові ефекти =================
func _build_sfx() -> void:
    var b: PackedFloat32Array
    var R := RATE

    # --- бойова зброя: тілесні матеріали, повітря та резонанс замість 8-bit тембрів ---
    b = _new(0.48)
    _whoosh(b, R, 0.0, 0.42, 0.85)
    _reg("swing", b, -8.0)
    b = _new(0.54)
    _whoosh(b, R, 0.0, 0.47, 1.0)
    _air_noise(b, R, 0.12, 0.32, 0.18, 3.0, 0.02, 0.22)
    _reg("swing_tense", b, -7.0)
    b = _new(0.60)
    _whoosh(b, R, 0.0, 0.54, 1.15)
    _tone(b, R, 0.22, 0.30, 82.0, 46.0, W_SIN, 0.18, 4.0, 0.004)
    _reg("swing_horde", b, -6.0)
    b = _new(0.64)
    _whoosh(b, R, 0.0, 0.56, 1.0, true)
    _flesh_impact(b, R, 0.37, 0.32, true)
    _reg("swing_heavy", b, -5.0)
    b = _new(0.72)
    _whoosh(b, R, 0.0, 0.64, 1.18, true)
    _flesh_impact(b, R, 0.38, 0.48, true)
    _reg("swing_heavy_tense", b, -4.0)
    b = _new(0.82)
    _whoosh(b, R, 0.0, 0.70, 1.34, true)
    _flesh_impact(b, R, 0.34, 0.70, true)
    _air_noise(b, R, 0.38, 0.36, 0.28, 3.2, 0.02, 0.20)
    _reg("swing_heavy_horde", b, -3.0)
    b = _new(0.70)
    _flesh_impact(b, R, 0.0, 1.0)
    _air_noise(b, R, 0.09, 0.34, 0.22, 4.0, 0.018, 0.20)
    _reg("hit", b, -3.0)
    b = _new(0.76)
    _flesh_impact(b, R, 0.0, 1.18)
    _voice(b, R, 0.02, 0.40, 118.0, 66.0, 0.24, 0.40)
    _reg("hit_tense", b, -2.0)
    b = _new(0.88)
    _flesh_impact(b, R, 0.0, 1.36, true)
    _voice(b, R, 0.02, 0.52, 105.0, 44.0, 0.36, 0.52)
    _reg("hit_horde", b, -1.0)
    b = _new(0.86)
    _flesh_impact(b, R, 0.0, 1.1, true)
    _tone(b, R, 0.015, 0.52, 920.0, 410.0, W_SIN, 0.18, 3.6, 0.002, 0.16, 5.2, 0.022)
    _reg("crit", b, -2.0)
    b = _new(0.9)
    _flesh_impact(b, R, 0.0, 1.2, true)
    _air_noise(b, R, 0.03, 0.72, 0.56, 2.4, 0.010, 0.20)
    _reg("slam", b, -2.0)
    b = _new(1.45)
    _tone(b, R, 0.0, 1.28, 76.0, 24.0, W_SIN, 1.0, 2.6, 0.002)
    _air_noise(b, R, 0.0, 1.15, 1.0, 2.4, 0.012, 0.24)
    _air_noise(b, R, 0.02, 0.72, 0.50, 4.0, 0.06, 0.64)
    _reg("explosion", b, -1.0)

    # --- постріли: натяг, механіка та ударне повітря ---
    b = _new(0.42)
    _tone(b, R, 0.0, 0.18, 510.0, 112.0, W_SIN, 0.45, 7.0, 0.001, 0.19)
    _whoosh(b, R, 0.015, 0.32, 0.45)
    _reg("bow", b, -5.0)
    b = _new(0.48)
    _tone(b, R, 0.0, 0.09, 185.0, 68.0, W_SIN, 0.65, 8.0, 0.001)
    _air_noise(b, R, 0.0, 0.26, 0.58, 6.5, 0.10, 0.62)
    _whoosh(b, R, 0.04, 0.32, 0.34)
    _reg("xbow", b, -4.0)
    b = _new(0.9)
    _tone(b, R, 0.0, 0.62, 104.0, 30.0, W_SIN, 0.9, 3.7, 0.001)
    _air_noise(b, R, 0.0, 0.68, 1.0, 5.0, 0.06, 0.76)
    _air_noise(b, R, 0.07, 0.56, 0.42, 2.2, 0.01, 0.14)
    _reg("gun", b, -2.0)
    b = _new(0.30)
    _whoosh(b, R, 0.0, 0.26, 0.52)
    _reg("throw", b, -9.0)
    b = _new(0.95)
    _air_noise(b, R, 0.0, 0.86, 0.8, 2.0, 0.02, 0.34)
    _tone(b, R, 0.02, 0.65, 144.0, 52.0, W_SIN, 0.35, 3.0, 0.008, 0.18)
    _reg("fire", b, -5.0)
    b = _new(0.52)
    _air_noise(b, R, 0.0, 0.45, 0.7, 4.0, 0.025, 0.64)
    _tone(b, R, 0.0, 0.34, 1480.0, 96.0, W_SIN, 0.22, 4.8, 0.001, 0.42, 17.0, 0.04)
    _reg("zap", b, -5.0)
    # водяний сплеск: шурхіт води + булькаючі «краплі», що злітають угору
    b = _new(0.34)
    _air_noise(b, R, 0.0, 0.3, 0.45, 5.0, 0.05, 0.5)
    _whoosh(b, R, 0.02, 0.26, 0.3)
    _tone(b, R, 0.0, 0.16, 420.0, 1250.0, W_SIN, 0.26, 7.0, 0.002)
    _tone(b, R, 0.06, 0.18, 640.0, 1700.0, W_SIN, 0.2, 8.0, 0.002)
    _tone(b, R, 0.11, 0.14, 900.0, 2100.0, W_SIN, 0.14, 9.0, 0.002)
    _reg("water", b, -7.0)
    # лід: холодний свист і дзвінкі кристалічні ноти
    b = _new(0.5)
    _air_noise(b, R, 0.0, 0.4, 0.3, 4.0, 0.08, 0.6)
    _tone(b, R, 0.0, 0.36, 1760.0, 2600.0, W_SIN, 0.16, 5.0, 0.002)
    _tone(b, R, 0.05, 0.34, 2350.0, 3100.0, W_SIN, 0.12, 6.0, 0.002)
    _tone(b, R, 0.12, 0.3, 2960.0, 3900.0, W_SIN, 0.09, 7.0, 0.002)
    _reg("ice", b, -8.0)
    # заморозка / розбиття льоду: тріск і дзенькіт
    b = _new(0.42)
    _air_noise(b, R, 0.0, 0.08, 0.9, 30.0, 0.2, 0.9)
    _tone(b, R, 0.0, 0.3, 3300.0, 1900.0, W_SIN, 0.2, 8.0, 0.001)
    _tone(b, R, 0.02, 0.26, 2500.0, 1500.0, W_SIN, 0.16, 9.0, 0.001)
    _air_noise(b, R, 0.03, 0.3, 0.25, 7.0, 0.15, 0.7)
    _reg("freeze", b, -5.0)

    # --- зомбі: хрипке дихання, голос і мокра плоть ---
    b = _new(0.38)
    _voice(b, R, 0.0, 0.30, 142.0, 82.0, 0.56, 0.35)
    _air_noise(b, R, 0.0, 0.25, 0.28, 6.0, 0.05, 0.42)
    _reg("zhit", b, -10.0)
    b = _new(0.46)
    _voice(b, R, 0.0, 0.36, 128.0, 62.0, 0.72, 0.48)
    _flesh_impact(b, R, 0.0, 0.34)
    _reg("zhit_tense", b, -9.0)
    b = _new(0.58)
    _voice(b, R, 0.0, 0.48, 114.0, 48.0, 0.92, 0.58)
    _flesh_impact(b, R, 0.02, 0.50, true)
    _reg("zhit_horde", b, -8.0)

    b = _new(1.12)
    _voice(b, R, 0.0, 0.82, 128.0, 36.0, 0.70, 0.42)
    _air_noise(b, R, 0.08, 0.72, 0.40, 2.6, 0.02, 0.32)
    _flesh_impact(b, R, 0.08, 0.30)
    _reg("zdie", b, -4.0)
    b = _new(1.18)
    _voice(b, R, 0.0, 0.95, 154.0, 29.0, 0.90, 0.58)
    _flesh_impact(b, R, 0.10, 0.66, true)
    _reg("zdie_horde", b, -3.0)
    b = _new(1.65)
    _voice(b, R, 0.0, 1.32, 78.0, 22.0, 1.0, 0.54)
    _tone(b, R, 0.02, 1.34, 54.0, 25.0, W_SIN, 0.62, 2.4, 0.008)
    _air_noise(b, R, 0.05, 1.18, 0.68, 2.4, 0.02, 0.28)
    _reg("zdie_big", b, -2.0)

    b = _new(1.55)
    _voice(b, R, 0.0, 1.42, 91.0, 64.0, 0.52, 0.35)
    _air_noise(b, R, 0.12, 1.18, 0.16, 1.5, 0.03, 0.24)
    _reg("groan1", b, -8.0)
    b = _new(1.36)
    _voice(b, R, 0.0, 1.24, 122.0, 84.0, 0.50, 0.30)
    _air_noise(b, R, 0.1, 0.82, 0.15, 1.8, 0.03, 0.24)
    _reg("groan2", b, -8.0)
    b = _new(1.75)
    _voice(b, R, 0.0, 1.62, 76.0, 54.0, 0.60, 0.40)
    _air_noise(b, R, 0.22, 1.25, 0.18, 1.4, 0.03, 0.26)
    _reg("groan3", b, -7.0)
    b = _new(1.22)
    _voice(b, R, 0.0, 1.12, 88.0, 44.0, 0.76, 0.56)
    _air_noise(b, R, 0.02, 1.1, 0.33, 1.7, 0.025, 0.38)
    _reg("groan1_horde", b, -6.0)
    b = _new(1.15)
    _voice(b, R, 0.0, 1.05, 112.0, 60.0, 0.74, 0.54)
    _air_noise(b, R, 0.0, 1.0, 0.30, 1.8, 0.025, 0.38)
    _reg("groan2_horde", b, -6.0)
    b = _new(1.35)
    _voice(b, R, 0.0, 1.25, 68.0, 38.0, 0.86, 0.62)
    _air_noise(b, R, 0.05, 1.15, 0.34, 1.6, 0.025, 0.40)
    _reg("groan3_horde", b, -5.0)

    b = _new(2.45)
    _voice(b, R, 0.0, 2.20, 66.0, 31.0, 1.0, 0.52)
    _voice(b, R, 0.06, 1.86, 104.0, 58.0, 0.46, 0.42)
    _tone(b, R, 0.0, 2.25, 42.0, 28.0, W_SIN, 0.66, 1.4, 0.02)
    _air_noise(b, R, 0.04, 2.10, 0.70, 1.3, 0.015, 0.20)
    _reg("boss_roar", b, 0.0)
    b = _new(0.46)
    _air_noise(b, R, 0.0, 0.38, 0.70, 3.0, 0.04, 0.30)
    _tone(b, R, 0.03, 0.30, 180.0, 620.0, W_SIN, 0.24, 4.0, 0.006, 0.20)
    _reg("spit", b, -8.0)

    # --- гравець ---
    b = _new(0.56)
    _voice(b, R, 0.0, 0.42, 196.0, 105.0, 0.48, 0.18)
    _flesh_impact(b, R, 0.0, 0.48)
    _reg("player_hurt", b, -2.0)

    b = _new(1.75)
    _voice(b, R, 0.0, 1.24, 188.0, 46.0, 0.58, 0.28)
    _tone(b, R, 0.48, 0.98, 74.0, 28.0, W_SIN, 0.72, 3.5, 0.005)
    _air_noise(b, R, 0.24, 1.22, 0.38, 2.6, 0.02, 0.26)
    _reg("player_die", b, 0.0)

    b = _new(0.18)
    _tone(b, R, 0.0, 0.13, 92.0, 48.0, W_SIN, 0.55, 7.0, 0.001)
    _air_noise(b, R, 0.0, 0.12, 0.38, 8.0, 0.08, 0.46)
    _reg("step", b, -16.0)

    b = _new(0.14)
    _tone(b, R, 0.0, 0.04, 200.0, 200.0, W_NOI, 0.6, 8.0, 0.001, 0.6)
    _tone(b, R, 0.0, 0.07, 900.0, 700.0, W_SIN, 0.25, 7.0, 0.001)
    _tone(b, R, 0.0, 0.05, 200.0, 180.0, W_SQR, 0.15, 6.0, 0.001, 0.4)
    _reg("equip", b, -8.0)

    b = _new(0.7)
    var heal_notes := [440.0, 554.4, 659.3, 880.0]
    for i in range(heal_notes.size()):
        var hf: float = heal_notes[i]
        _tone(b, R, float(i) * 0.08, 0.35, hf, hf, W_SIN, 0.4, 5.0, 0.005)
    _reg("heal", b, -4.0)

    b = _new(0.4)
    _tone(b, R, 0.0, 0.06, 1318.0, 1318.0, W_TRI, 0.5, 2.0, 0.001)
    _tone(b, R, 0.06, 0.28, 1760.0, 1760.0, W_TRI, 0.5, 7.0, 0.001)
    _reg("coin", b, -8.0)

    b = _new(0.6)
    _tone(b, R, 0.0, 0.25, 1046.5, 1046.5, W_TRI, 0.45, 5.0, 0.002)
    _tone(b, R, 0.07, 0.25, 1318.5, 1318.5, W_TRI, 0.45, 5.0, 0.002)
    _tone(b, R, 0.14, 0.35, 1568.0, 1568.0, W_TRI, 0.45, 5.0, 0.002)
    _tone(b, R, 0.0, 0.03, 200.0, 200.0, W_NOI, 0.2, 8.0, 0.001, 0.8)
    _reg("buy", b, -5.0)

    # --- хвилі та фінали ---
    b = _new(2.3)
    _tone(b, R, 0.0, 2.1, 110.0, 110.0, W_SAW, 0.5, 1.2, 0.18, 0.08, 5.0, 0.01)
    _tone(b, R, 0.0, 2.1, 164.8, 164.8, W_SAW, 0.35, 1.2, 0.2, 0.08, 5.0, 0.01)
    _tone(b, R, 0.0, 2.1, 55.0, 55.0, W_SAW, 0.4, 1.2, 0.18, 0.08)
    _reg("wave", b, -3.0)

    b = _new(1.5)
    var clear_notes := [392.0, 494.0, 587.0]
    for i in range(clear_notes.size()):
        var cf: float = clear_notes[i]
        _tone(b, R, float(i) * 0.12, 1.2, cf, cf, W_SIN, 0.35, 3.0, 0.02)
    _reg("clear", b, -6.0)

    b = _new(2.6)
    var vic_notes := [293.7, 370.0, 440.0, 587.3]
    for i in range(vic_notes.size()):
        var vf: float = vic_notes[i]
        _tone(b, R, float(i) * 0.22, 1.4, vf, vf, W_TRI, 0.4, 3.0, 0.01)
        _tone(b, R, float(i) * 0.22, 1.4, vf * 2.0, vf * 2.0, W_SIN, 0.12, 3.5, 0.01)
    _tone(b, R, 0.88, 1.6, 740.0, 740.0, W_TRI, 0.3, 2.5, 0.02)
    _tone(b, R, 0.88, 1.6, 880.0, 880.0, W_SIN, 0.2, 2.5, 0.02)
    _reg("victory", b, -2.0)

    b = _new(2.6)
    _tone(b, R, 0.0, 2.2, 196.0, 98.0, W_SAW, 0.45, 1.6, 0.05, 0.1)
    _tone(b, R, 0.0, 2.2, 55.0, 40.0, W_SIN, 0.6, 1.5, 0.01)
    _tone(b, R, 0.0, 2.2, 185.0, 92.0, W_SAW, 0.25, 1.6, 0.05, 0.1)
    _reg("defeat", b, -2.0)

    b = _new(1.7)
    _tone(b, R, 0.0, 1.5, 70.0, 35.0, W_SIN, 0.9, 2.0, 0.01)
    _tone(b, R, 0.0, 1.5, 200.0, 200.0, W_NOI, 0.5, 2.0, 0.8, 0.05)
    _tone(b, R, 0.0, 1.4, 55.0, 110.0, W_SAW, 0.25, 2.0, 0.6, 0.08)
    _reg("start", b, -2.0)

    b = _new(0.55)
    _tone(b, R, 0.0, 0.16, 62.0, 45.0, W_SIN, 1.0, 7.0, 0.005)
    _tone(b, R, 0.21, 0.2, 55.0, 40.0, W_SIN, 0.8, 7.0, 0.005)
    _reg("heartbeat", b, -4.0)

    b = _new(3.6)
    _tone(b, R, 0.0, 3.2, 200.0, 200.0, W_NOI, 1.0, 1.6, 0.35, 0.025)
    _tone(b, R, 0.0, 3.0, 45.0, 28.0, W_SIN, 0.6, 1.4, 0.3)
    _tone(b, R, 0.9, 2.5, 200.0, 200.0, W_NOI, 0.6, 1.8, 0.3, 0.03)
    _reg("thunder", b, -4.0)

    # --- інтерфейс ---
    b = _new(0.09)
    _tone(b, R, 0.0, 0.05, 720.0, 480.0, W_SIN, 0.5, 8.0, 0.001)
    _tone(b, R, 0.0, 0.02, 200.0, 200.0, W_NOI, 0.3, 8.0, 0.001, 0.5)
    _reg("click", b, -8.0)

    b = _new(0.05)
    _tone(b, R, 0.0, 0.03, 1300.0, 1300.0, W_SIN, 0.5, 6.0, 0.001)
    _reg("hover", b, -16.0)

    # удар молота по ковадлу (фон екрана зброї)
    b = _new(0.9)
    _tone(b, R, 0.0, 0.03, 300.0, 300.0, W_NOI, 0.9, 10.0, 0.001, 0.9)
    _tone(b, R, 0.0, 0.8, 1180.0, 1180.0, W_SIN, 0.45, 5.0, 0.001)
    _tone(b, R, 0.0, 0.6, 1870.0, 1870.0, W_SIN, 0.35, 7.0, 0.001)
    _tone(b, R, 0.0, 0.5, 2950.0, 2950.0, W_SIN, 0.20, 9.0, 0.001)
    _tone(b, R, 0.0, 0.25, 140.0, 80.0, W_SIN, 0.60, 12.0, 0.001)
    _reg("anvil", b, -10.0)

    b = _new(0.3)
    _tone(b, R, 0.0, 0.25, 120.0, 90.0, W_SQR, 0.4, 3.0, 0.002, 0.25)
    _tone(b, R, 0.0, 0.25, 127.0, 96.0, W_SQR, 0.3, 3.0, 0.002, 0.25)
    _reg("deny", b, -8.0)

    # --- екран броні: брязкіт кілець, сміх крамаря, ворон ---
    b = _new(0.55)
    for k in range(9):
        var ct := 0.0 + float(k) * 0.045 + _rng.randf() * 0.02
        _tone(b, R, ct, 0.02, 3000.0, 3000.0, W_NOI, 0.35, 8.0, 0.0005, 0.9)
        var cf := _rng.randf_range(2200.0, 4600.0)
        _tone(b, R, ct, 0.22, cf, cf * 0.98, W_SIN, 0.20, 9.0, 0.0005)
        _tone(b, R, ct, 0.12, cf * 1.51, cf * 1.51, W_SIN, 0.10, 12.0, 0.0005)
    _tone(b, R, 0.0, 0.25, 120.0, 90.0, W_NOI, 0.10, 6.0, 0.002, 0.2)
    _reg("armor_clink", b, -4.0)

    b = _new(1.5)
    for k in range(5):
        var lt := 0.05 + float(k) * 0.24
        var f0 := 150.0 - float(k) * 8.0
        _tone(b, R, lt, 0.17, f0 * 1.15, f0 * 0.8, W_SAW, 0.55, 3.5, 0.01, 0.10, 31.0, 0.03)
        _tone(b, R, lt, 0.17, f0 * 2.3, f0 * 1.6, W_SAW, 0.20, 3.5, 0.01, 0.07)
        _tone(b, R, lt, 0.15, 200.0, 200.0, W_NOI, 0.10, 5.0, 0.01, 0.3)
    _tone(b, R, 1.15, 0.30, 140.0, 70.0, W_SAW, 0.40, 3.0, 0.02, 0.08, 22.0, 0.06)
    _reg("merchant_laugh", b, -2.0)

    b = _new(1.1)
    for k in range(3):
        var rt := float(k) * 0.34
        _tone(b, R, rt, 0.24, 780.0, 420.0, W_SAW, 0.45, 3.0, 0.01, 0.30, 55.0, 0.04)
        _tone(b, R, rt, 0.20, 1560.0, 840.0, W_SAW, 0.12, 4.0, 0.01, 0.20)
    _reg("raven", b, -6.0)

# ================= Музика =================
# Периодична складова: частоти підганяються під ціле число періодів, тому петля без швів.
func _periodic(b: PackedFloat32Array, rate: int, secs: float, freq: float, amp: float, lfo_k: int, lfo_phase: float, harm: float = 0.4) -> void:
    var f := roundf(freq * secs) / secs
    var n := b.size()
    for i in range(n):
        var t := float(i) / float(rate)
        var lfo := 0.65 + 0.35 * sin(TAU * float(lfo_k) * t / secs + lfo_phase)
        var s := sin(TAU * f * t) + harm * sin(TAU * 2.0 * f * t + 0.7) + harm * 0.5 * sin(TAU * 3.0 * f * t + 1.9)
        b[i] += s * amp * lfo

func _bell(ev: PackedFloat32Array, rate: int, t0: float, f: float, amp: float, dur: float = 3.0) -> void:
    var n0 := int(t0 * float(rate))
    var n := int(dur * float(rate))
    for i in range(n):
        var idx := n0 + i
        if idx >= ev.size():
            break
        var t := float(i) / float(rate)
        var env := exp(-1.3 * t) * minf(1.0, t / 0.004)
        var md := sin(TAU * f * 3.5 * t) * 2.2 * exp(-3.0 * t)
        ev[idx] += sin(TAU * f * t + md) * env * amp

# Склеює петлю: "хвіст" подій, що вийшов за кінець, накладається на початок.
func _finish_loop(per: PackedFloat32Array, ev: PackedFloat32Array) -> PackedFloat32Array:
    var n := per.size()
    var out := PackedFloat32Array()
    out.resize(n)
    for i in range(n):
        var v := per[i] + ev[i]
        if n + i < ev.size():
            v += ev[n + i]
        out[i] = v
    return out

func _kick(ev: PackedFloat32Array, t0: float, amp: float = 0.9) -> void:
    _tone(ev, MRATE, t0, 0.3, 120.0, 42.0, W_SIN, amp, 5.0, 0.002)

func _snare(ev: PackedFloat32Array, t0: float, amp: float = 0.5) -> void:
    _tone(ev, MRATE, t0, 0.22, 200.0, 200.0, W_NOI, amp, 8.0, 0.001, 0.5)
    _tone(ev, MRATE, t0, 0.12, 200.0, 150.0, W_SIN, amp * 0.5, 9.0, 0.001)

# Бойова музика: основа й п'ять шарів, усі по 272 с. Між кроками перевіряємо _abort, щоб вихід
# з гри не чекав кінця синтезу.
func _build_battle_tracks() -> Dictionary:
    var bt := {}
    _build_stems()
    _build_banks()
    bt["battle"] = _make_battle_music()
    if _abort:
        return bt
    bt["battle_tension"] = _make_battle_tension()
    bt["battle_drive"] = _make_battle_drive()
    bt["battle_horde"] = _make_battle_horde()
    if _abort:
        return bt
    bt["battle_violin"] = _make_battle_violin()
    if _abort:
        return bt
    bt["battle_bass"] = _make_battle_bass()
    return bt

# Шум нічного базару: гул натовпу, приглушені голоси, брязкіт броні, скрип вивіски, виття вітру,
# низький тривожний дрон, далекий дзвін, шепіт і крик ворона. Петля 20 секунд без швів.
func _make_market_ambience() -> AudioStreamWAV:
    var secs := 20.0
    var n := int(secs * float(MRATE))
    var per := _new(secs, MRATE)
    # --- гул натовпу: смуговий шум, що «дихає» складами ---
    var cf := int(0.4 * float(MRATE))
    var raw := PackedFloat32Array()
    raw.resize(n + cf)
    var y1 := 0.0
    var y2 := 0.0
    for i in range(n + cf):
        var s := _rng.randf() * 2.0 - 1.0
        y1 += (s - y1) * 0.30
        y2 += (s - y2) * 0.06
        raw[i] = y1 - y2
    for i in range(n):
        var v := raw[i]
        if i < cf:
            var k := float(i) / float(cf)
            v = raw[i] * k + raw[n + i] * (1.0 - k)
        var tt := float(i) / float(MRATE)
        var swell := 0.60 + 0.25 * sin(TAU * 3.0 * tt / secs + 0.5) + 0.15 * sin(TAU * 7.0 * tt / secs + 2.0)
        var syl := 0.70 + 0.30 * sin(TAU * 70.0 * tt / secs) * (0.6 + 0.4 * sin(TAU * 110.0 * tt / secs + 1.0))
        per[i] += v * swell * syl * 2.2
    # --- низький тривожний дрон (дві ноти, що биються) і подих вітру ---
    _periodic(per, MRATE, secs, 55.0, 0.10, 1, 0.0, 0.3)
    _periodic(per, MRATE, secs, 58.27, 0.07, 2, 1.3, 0.3)
    _periodic(per, MRATE, secs, 311.13, 0.012, 3, 0.4, 0.2)
    var ev := _new(secs + 3.0, MRATE)
    # --- приглушені голоси: склади різної висоти ---
    var phrases := [
        [1.0, 112.0, 4], [3.2, 205.0, 3], [5.1, 98.0, 5], [7.6, 190.0, 4], [9.4, 120.0, 3],
        [11.8, 88.0, 5], [13.9, 215.0, 3], [15.5, 105.0, 4], [17.6, 180.0, 4],
    ]
    for ph in phrases:
        var pt: float = ph[0]
        var pf: float = ph[1]
        for k in range(int(ph[2])):
            var st := pt + float(k) * _rng.randf_range(0.16, 0.26)
            var f0 := pf * _rng.randf_range(0.85, 1.25)
            _tone(ev, MRATE, st, 0.14, f0, f0 * _rng.randf_range(0.75, 1.2), W_SAW, 0.30, 4.0, 0.02, 0.07, 6.0, 0.02)
            _tone(ev, MRATE, st, 0.12, f0 * 2.4, f0 * 2.0, W_SAW, 0.10, 4.0, 0.02, 0.05)
    # --- крики торговців ---
    _tone(ev, MRATE, 4.0, 0.7, 150.0, 210.0, W_SAW, 0.45, 2.4, 0.06, 0.09, 5.0, 0.03)
    _tone(ev, MRATE, 4.0, 0.6, 330.0, 440.0, W_SAW, 0.16, 2.4, 0.06, 0.06)
    _tone(ev, MRATE, 12.4, 0.9, 135.0, 90.0, W_SAW, 0.50, 2.0, 0.08, 0.08, 4.0, 0.03)
    # --- брязкіт броні та ланцюгів ---
    for ct in [2.3, 2.38, 6.8, 6.86, 6.95, 10.2, 14.7, 14.76, 18.9]:
        var cft := _rng.randf_range(2000.0, 4200.0)
        _tone(ev, MRATE, float(ct), 0.02, 3000.0, 3000.0, W_NOI, 0.22, 8.0, 0.0005, 0.9)
        _tone(ev, MRATE, float(ct), 0.25, cft, cft * 0.98, W_SIN, 0.12, 8.0, 0.0005)
        _tone(ev, MRATE, float(ct), 0.12, cft * 1.51, cft * 1.51, W_SIN, 0.06, 12.0, 0.0005)
    # --- скрип дерев'яної вивіски ---
    _tone(ev, MRATE, 8.2, 0.9, 190.0, 140.0, W_SAW, 0.14, 1.6, 0.08, 0.05, 9.0, 0.05)
    _tone(ev, MRATE, 16.3, 0.7, 150.0, 210.0, W_SAW, 0.12, 1.6, 0.08, 0.05, 11.0, 0.05)
    # --- далекий дзвін, шепіт, ворон ---
    _bell(ev, MRATE, 3.0, 196.0, 0.20, 4.0)
    _bell(ev, MRATE, 12.0, 185.0, 0.16, 4.0)
    _tone(ev, MRATE, 7.0, 3.0, 200.0, 200.0, W_NOI, 0.05, 2.0, 1.0, 0.55)
    _tone(ev, MRATE, 14.3, 2.6, 200.0, 200.0, W_NOI, 0.045, 2.0, 0.8, 0.5)
    _tone(ev, MRATE, 18.2, 0.28, 700.0, 420.0, W_SAW, 0.09, 3.0, 0.01, 0.28, 50.0, 0.04)
    _tone(ev, MRATE, 18.55, 0.26, 680.0, 400.0, W_SAW, 0.08, 3.0, 0.01, 0.28, 50.0, 0.04)
    var mixed := _finish_loop(per, ev)
    for i in range(mixed.size()):
        mixed[i] = tanh(mixed[i] * 1.1)
    return _wav(mixed, MRATE, true)

# Меню: низький тривожний дрон, дисонансні ноти й повільні дзвони.
func _make_menu_music() -> AudioStreamWAV:
    var secs := 16.0
    var per := _new(secs, MRATE)
    _periodic(per, MRATE, secs, 73.42, 0.30, 1, 0.0)
    _periodic(per, MRATE, secs, 110.0, 0.18, 2, 1.0)
    _periodic(per, MRATE, secs, 147.0, 0.12, 1, 2.0)
    _periodic(per, MRATE, secs, 174.61, 0.08, 3, 0.5)
    _periodic(per, MRATE, secs, 311.13, 0.05, 1, 1.57, 0.2)
    var ev := _new(secs + 3.0, MRATE)
    var bells := [[0.0, 587.33, 0.16], [3.0, 698.46, 0.12], [5.5, 659.25, 0.13], [8.0, 440.0, 0.14], [10.5, 622.25, 0.10], [12.0, 523.25, 0.12], [14.0, 587.33, 0.10]]
    for bl in bells:
        _bell(ev, MRATE, float(bl[0]), float(bl[1]), float(bl[2]))
    _tone(ev, MRATE, 0.0, 3.0, 62.0, 38.0, W_SIN, 0.55, 2.0, 0.01)
    _tone(ev, MRATE, 8.0, 3.0, 62.0, 38.0, W_SIN, 0.4, 2.0, 0.01)
    _tone(ev, MRATE, 5.0, 6.0, 200.0, 200.0, W_NOI, 0.12, 2.5, 2.5, 0.03)
    return _wav(_finish_loop(per, ev), MRATE, true)

# ===== Бойова музика: страшний фонк (horror phonk) =====
# Сітка: удар = 0.5 с, такт = 2 с, фраза = 2 такти = 4 с, петля = 16 с. Тональність F/Es/As
# (півтон, тритон) — моторошно й грубо. Основа вже має повний біт — перевантажені 808 і кік,
# важкий снейр, клепи, товстий низький «рис» (reese), ковбел, дзвони й голос, тож грає гучно
# з першої секунди. Динаміка: шари (tension → drive → horde) додають хети, баси, мелодію,
# том-томи, крики й мідь, і весь мікс прискорюється разом із кількістю зомбі.

# 808: синусоїда з коротким «падінням» висоти, сповзанням f → f2 та сильним перевантаженням (drive).
func _808(ev: PackedFloat32Array, t0: float, dur: float, f: float, f2: float, amp: float, drive: float = 4.0) -> void:
    var n0 := int(t0 * float(MRATE))
    var n := int(dur * float(MRATE))
    var ph := 0.0
    for i in range(n):
        var idx := n0 + i
        if idx >= ev.size():
            break
        var t := float(i) / float(MRATE)
        var u := float(i) / float(maxi(n, 1))
        var fr := (f + (f2 - f) * u) * (1.0 + 1.1 * exp(-t * 30.0))
        ph += fr / float(MRATE)
        var env := minf(1.0, float(i) / (float(MRATE) * 0.003)) * exp(-3.0 * u)
        ev[idx] += tanh(sin(TAU * ph) * drive) * amp * env

# Товстий бас («рис»): дві розстроєні пилки + синус октавою нижче, фільтр (можна хвилювати lfo_hz) і дисторсія.
func _reese(ev: PackedFloat32Array, t0: float, dur: float, f: float, amp: float, lfo_hz: float = 0.0, drive: float = 3.0) -> void:
    var n0 := int(t0 * float(MRATE))
    var n := int(dur * float(MRATE))
    var p1 := 0.0
    var p2 := 0.0
    var p3 := 0.0
    var y := 0.0
    for i in range(n):
        var idx := n0 + i
        if idx >= ev.size():
            break
        var t := float(i) / float(MRATE)
        var u := float(i) / float(maxi(n, 1))
        p1 += f * 0.994 / float(MRATE)
        p2 += f * 1.006 / float(MRATE)
        p3 += f * 0.5 / float(MRATE)
        var sw := (2.0 * (p1 - floorf(p1)) - 1.0) + (2.0 * (p2 - floorf(p2)) - 1.0)
        var k := 0.14
        if lfo_hz > 0.0:
            k = 0.05 + 0.12 * (0.5 + 0.5 * sin(TAU * lfo_hz * t))
        y += (sw * 0.5 - y) * k
        var v := tanh((y + sin(TAU * p3) * 0.8) * drive)
        var env := minf(1.0, float(i) / (float(MRATE) * 0.006)) * exp(-1.1 * u) * minf(1.0, float(n - i) / (float(MRATE) * 0.02))
        ev[idx] += v * amp * env

# Важкий кік: короткий перевантажений 808 плюс глухий «удар в груди».
func _kick_heavy(ev: PackedFloat32Array, t0: float, amp: float) -> void:
    _808(ev, t0, 0.30, 52.0, 38.0, amp, 3.5)
    _air_noise(ev, MRATE, t0, 0.025, amp * 0.35, 10.0, 0.04, 0.18)

# Важкий снейр: низьке тіло + середній шум (без «писку»).
func _snare_heavy(ev: PackedFloat32Array, t0: float, amp: float) -> void:
    _tone(ev, MRATE, t0, 0.20, 210.0, 120.0, W_SIN, amp * 0.7, 7.0, 0.001)
    _air_noise(ev, MRATE, t0, 0.22, amp * 0.9, 6.0, 0.06, 0.40)

func _tom(ev: PackedFloat32Array, t0: float, f: float, amp: float) -> void:
    _808(ev, t0, 0.32, f, f * 0.6, amp, 2.0)

# Клеп: низька смуга шуму, без високих частот.
func _clap(ev: PackedFloat32Array, t0: float, amp: float) -> void:
    for o in [0.0, 0.011, 0.022]:
        _air_noise(ev, MRATE, t0 + float(o), 0.05, amp, 10.0, 0.06, 0.35)
    _air_noise(ev, MRATE, t0 + 0.03, 0.24, amp * 0.7, 6.0, 0.05, 0.30)

# Хет: приглушений, у середніх частотах.
func _hat(ev: PackedFloat32Array, t0: float, amp: float, open: bool = false) -> void:
    if open:
        _air_noise(ev, MRATE, t0, 0.22, amp, 5.0, 0.12, 0.42)
    else:
        _air_noise(ev, MRATE, t0, 0.055, amp, 10.0, 0.12, 0.42)

# Ковбел: нижчий і темніший, дві прямокутні хвилі у співвідношенні 1 : 1.48.
func _cowbell(ev: PackedFloat32Array, t0: float, f: float, amp: float) -> void:
    _tone(ev, MRATE, t0, 0.24, f, f, W_SQR, amp, 7.0, 0.001, 0.20)
    _tone(ev, MRATE, t0, 0.24, f * 1.4815, f * 1.4815, W_SQR, amp * 0.8, 7.0, 0.001, 0.20)

# Грубий щипок: розстроєні пилки в низькій октаві й синус ще нижче.
func _pluck(ev: PackedFloat32Array, t0: float, f: float, amp: float) -> void:
    _tone(ev, MRATE, t0, 0.34, f, f, W_SAW, amp, 6.0, 0.002, 0.12)
    _tone(ev, MRATE, t0, 0.34, f * 1.007, f * 1.007, W_SAW, amp * 0.7, 6.0, 0.002, 0.12)
    _tone(ev, MRATE, t0, 0.34, f * 0.5, f * 0.5, W_SIN, amp * 1.1, 5.0, 0.002)

# ===== Структура композиції (272 с = 68 фраз по 4 с = 136 тактів, 120 уд/хв) =====
#  фрази  0–11  ВСТУП (48 с): довге наростання. Пад і серцебиття, потім хети, кік, 808, клепи, том-томи,
#               райзер і «ту-ту-ту». Скрипка з тихих довгих нот переходить у тремоло й швидкі пасажі.
#  фрази 12–26  БІТИ 1 (60 с): повний біт, БУХ на початку, піки й короткі передихи. Скрипка «скажена».
#  фрази 27–36  СПАД 1 (40 с): біти провалюються, далі лише жорстка музика БЕЗ бітів: бас-гітара,
#               скрипка, пад, дзвони.
#  фрази 37–44  НАРОСТАННЯ 2 (32 с): бас-гітара ще грає, потім вона замовкає й біти повертаються.
#  фрази 45–59  БІТИ 2 (60 с): найщільніший біт, мідь, крики. Скрипка ще скаженіша.
#  фрази 60–67  СПАД 2 (32 с): знову жорстка музика з бас-гітарою, затихає й петля на новий ВСТУП.
# Темп змінюється разом із кількістю зомбі (×0.92 ... ×1.16), тож «60 с» — плюс-мінус.
const PHRASE_SECS := 4.0
const P_INTRO := 0
const P_BEATS1 := 12
const P_DECL1 := 27
const P_BUILD2 := 37
const P_BEATS2 := 45
const P_DECL2 := 60
const P_TOTAL := 68
const SONG_SECS := 272.0
# Щільність бітів по фразах: 1 — легкий біт, 2 — повний, 3 — найщільніший (мідь, додаткові 808).
const BEATS1_LV := [3, 3, 2, 3, 1, 2, 3, 3, 3, 2, 3, 3, 2, 1, 1]
const BEATS2_LV := [3, 3, 3, 2, 3, 3, 1, 3, 3, 3, 2, 3, 3, 2, 1]
const GAP1 := 47.5     # «пф»: тиша 0.5 с перед першим БУХом
const GAP2 := 179.5    # «пф» перед другим БУХом
var _st := {}
# Ноти (MIDI) акордового пада у фоні спадів; назви збігаються з CH_ROOT.
const CH_VOICE := {"Fm": [53, 56, 60], "Db": [49, 53, 56], "Eb": [51, 58, 65], "Bb": [46, 53, 61], "C": [48, 55, 58]}

func _stem(sec: float = 5.0) -> PackedFloat32Array:
    return _new(sec, MRATE)

func _place(dst: PackedFloat32Array, src: PackedFloat32Array, t0: float, gain: float = 1.0) -> void:
    var n0 := int(t0 * float(MRATE))
    var lim := mini(src.size(), dst.size() - n0)
    for i in range(lim):
        dst[n0 + i] += src[i] * gain

func _put(dst: PackedFloat32Array, nm: String, t0: float, gain: float = 1.0) -> void:
    _place(dst, _st[nm], t0, gain)

# Тиша «пф» перед кожним БУХом: зрізає все в [t0, t1) (із коротким згасанням).
func _cut(dst: PackedFloat32Array, t0: float, t1: float) -> void:
    var n0 := int(t0 * float(MRATE))
    var n1 := mini(int(t1 * float(MRATE)), dst.size())
    var fade := int(0.005 * float(MRATE))
    for i in range(maxi(0, n0 - fade), mini(n0, dst.size())):
        dst[i] *= float(n0 - i) / float(fade)
    for i in range(n0, n1):
        dst[i] = 0.0

func _pt(p: int) -> float:
    return float(p) * PHRASE_SECS

# Щільність бітів у фразі p: 0 — тут немає бітів (вступ, спади, наростання).
func _beat_level(p: int) -> int:
    if p >= P_BEATS1 and p < P_BEATS1 + BEATS1_LV.size():
        return int(BEATS1_LV[p - P_BEATS1])
    if p >= P_BEATS2 and p < P_BEATS2 + BEATS2_LV.size():
        return int(BEATS2_LV[p - P_BEATS2])
    return 0

# Варіант a/b фрази з бітами (так само, як в основі: рахунок від початку своєї частини), щоб шари
# грали той самий бас, що й основа.
func _beat_var(p: int) -> int:
    if p < P_DECL1:
        return (p - P_BEATS1) % 2
    return (p - P_BEATS2) % 2

func _apply_gaps(ev: PackedFloat32Array) -> void:
    _cut(ev, GAP1, GAP1 + 0.5)
    _cut(ev, GAP2, GAP2 + 0.5)

# Збирає доріжку в петлю: «хвіст» за межею накладається на початок, додається тихий дрон per8
# (якщо він є), мікс м'яко стискається (tanh) і кодується в зациклений звук.
func _finish_track(per8: PackedFloat32Array, ev: PackedFloat32Array, drive: float = 1.4) -> AudioStreamWAV:
    _apply_gaps(ev)
    var n := int(SONG_SECS * float(MRATE))
    var tail := ev.size() - n
    for i in range(tail):
        ev[i] += ev[n + i]
    var out := PackedFloat32Array()
    out.resize(n)
    var m := per8.size()
    if m > 0:
        var j := 0
        for i2 in range(n):
            out[i2] = tanh((ev[i2] + per8[j]) * drive)
            j += 1
            if j >= m:
                j = 0
    else:
        for i3 in range(n):
            out[i3] = tanh(ev[i3] * drive)
    return _wav(out, MRATE, true)

func _noise_swell(ev: PackedFloat32Array, t0: float, dur: float, amp: float) -> void:
    var n0 := int(t0 * float(MRATE))
    var n := int(dur * float(MRATE))
    var lp := 0.0
    for i in range(n):
        var idx := n0 + i
        if idx >= ev.size():
            break
        var u := float(i) / float(maxi(n, 1))
        lp += (_rng.randf_range(-1.0, 1.0) - lp) * (0.08 + 0.45 * u)
        ev[idx] += lp * amp * u * u

func _riser(ev: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, amp: float) -> void:
    _tone(ev, MRATE, t0, dur, f0, f1, W_SAW, amp, 0.0, dur, 0.08, 6.0, 0.010)

# «Ту-ту-ту-ту»: дрібний барабанний перебір, що поступово пришвидшується й гучнішає.
func _roll(ev: PackedFloat32Array, t0: float, dur: float, amp: float) -> void:
    var t := 0.0
    while t < dur:
        var u := t / dur
        var a := amp * (0.35 + 0.65 * u)
        _air_noise(ev, MRATE, t0 + t, 0.07, a, 9.0, 0.06, 0.40)
        _tone(ev, MRATE, t0 + t, 0.08, 220.0, 150.0, W_SIN, a * 0.5, 8.0, 0.001)
        t += lerpf(0.25, 0.0625, u)

func _build_stems() -> void:
    var s: PackedFloat32Array
    for v in ["a", "b"]:
        s = _stem()
        _808(s, 0.0, 1.0, 43.65, 43.65, 0.95)
        _808(s, 1.25, 0.4, 43.65, 43.65, 0.75)
        _808(s, 2.0, 0.9, 49.0, 43.65, 0.90)
        _808(s, 3.0, 0.3, 43.65, 43.65, 0.70)
        if v == "b":
            _808(s, 3.5, 0.5, 38.89, 36.71, 0.95)
        else:
            _808(s, 3.5, 0.45, 51.91, 43.65, 0.80)
        _st["808" + v] = s
        s = _stem()
        _reese(s, 0.0, 1.0, 87.31, 0.30)
        _reese(s, 1.25, 0.4, 87.31, 0.26)
        _reese(s, 2.0, 0.9, 98.0, 0.30)
        _reese(s, 3.0, 0.4, 87.31, 0.26)
        if v == "b":
            _reese(s, 3.5, 0.5, 77.78, 0.28)
        else:
            _reese(s, 3.5, 0.45, 103.83, 0.26)
        _st["reese" + v] = s
    s = _stem()
    _808(s, 0.0, 1.4, 43.65, 43.65, 0.95)
    _808(s, 2.0, 1.2, 49.0, 41.0, 0.90)
    _st["sparse808"] = s
    s = _stem()
    _reese(s, 0.0, 1.4, 87.31, 0.28)
    _reese(s, 2.0, 1.2, 98.0, 0.28)
    _st["sparse_reese"] = s
    s = _stem()
    for kt in [0.0, 1.25, 2.0, 3.0]:
        _kick_heavy(s, float(kt), 0.80)
    _st["kicks"] = s
    s = _stem()
    for kt in [1.75, 3.25]:
        _kick_heavy(s, float(kt), 0.70)
    _st["kick_extra"] = s
    s = _stem()
    for i in range(8):
        _kick_heavy(s, float(i) * 0.5, 0.65)
    _st["kick4"] = s
    s = _stem()
    for c in [0.5, 1.5, 2.5, 3.5]:
        _clap(s, float(c), 0.34)
    _snare_heavy(s, 1.5, 0.70)
    _snare_heavy(s, 3.5, 0.70)
    _st["claps"] = s
    s = _stem()
    _clap(s, 2.0, 0.40)
    _snare_heavy(s, 2.0, 0.75)
    _st["clap_half"] = s
    s = _stem()
    for k in range(16):
        var ha := 0.05
        if k % 2 == 1:
            ha = 0.07
        _hat(s, float(k) * 0.25, ha)
    _st["hats8"] = s
    s = _stem()
    for k in range(32):
        var hb := 0.045
        if k % 4 == 0:
            hb = 0.075
        _hat(s, float(k) * 0.125, hb)
    _hat(s, 1.75, 0.08, true)
    _hat(s, 3.75, 0.08, true)
    _st["hats16"] = s
    s = _stem()
    for bar in range(2):
        var tb := float(bar) * 2.0
        _cowbell(s, tb, 380.0, 0.16)
        _cowbell(s, tb + 0.75, 380.0, 0.16)
        _cowbell(s, tb + 1.5, 450.0, 0.16)
    _st["cow"] = s
    s = _stem()
    for bar in range(2):
        var tc := float(bar) * 2.0
        _cowbell(s, tc + 0.25, 420.0, 0.12)
        _cowbell(s, tc + 1.0, 420.0, 0.12)
        _cowbell(s, tc + 1.25, 500.0, 0.10)
    _st["cow2"] = s
    s = _stem()
    var melody := [146.83, 0.0, 174.61, 0.0, 220.0, 207.65, 174.61, 0.0, 146.83, 0.0, 155.56, 0.0, 174.61, 146.83, 138.59, 0.0]
    for k in range(16):
        var mf: float = melody[k]
        if mf > 0.0:
            _pluck(s, float(k) * 0.25, mf, 0.12)
    _st["pluck"] = s
    s = _stem()
    var stab := [87.31, 0.0, 87.31, 98.0, 87.31, 0.0, 103.83, 98.0]
    for bar in range(2):
        for k in range(8):
            var sf: float = stab[k]
            if sf > 0.0:
                _reese(s, float(bar) * 2.0 + float(k) * 0.25, 0.22, sf, 0.30, 0.0, 4.0)
    _st["stab"] = s
    for v in [0, 1]:
        s = _stem()
        var fs: Array = [[87.31, 87.31], [103.83, 98.0]][v]
        _reese(s, 0.0, 1.9, float(fs[0]), 0.34, 2.0, 3.5)
        _reese(s, 2.0, 1.9, float(fs[1]), 0.34, 2.0, 3.5)
        _st["wub%d" % v] = s
    s = _stem()
    for tt in [0.0, 0.75, 1.25, 1.75, 2.0, 2.75, 3.25, 3.75]:
        _tom(s, float(tt), 100.0, 0.50)
    _st["toms"] = s
    s = _stem()
    _tom(s, 3.0, 110.0, 0.60)
    _tom(s, 3.5, 90.0, 0.65)
    _tom(s, 3.75, 70.0, 0.70)
    _st["tom_fill"] = s
    s = _stem()
    for kb in [0.5, 1.0, 1.5, 2.5, 3.0, 3.5]:
        _808(s, float(kb), 0.25, 43.65, 43.65, 0.65)
        _kick_heavy(s, float(kb), 0.55)
    _st["dbl808"] = s
    s = _stem()
    for tb2 in [1.0, 3.0]:
        for f in [87.31, 103.83, 155.56]:
            _tone(s, MRATE, float(tb2), 0.45, float(f), float(f), W_SAW, 0.12, 3.0, 0.02, 0.12)
    _st["brass"] = s
    s = _stem()
    _voice(s, MRATE, 0.3, 1.2, 300.0, 170.0, 0.22, 0.60)
    _voice(s, MRATE, 2.3, 1.2, 300.0, 170.0, 0.22, 0.60)
    _st["scream"] = s
    s = _stem()
    _voice(s, MRATE, 1.0, 0.30, 200.0, 140.0, 0.18, 0.50)
    _st["chop"] = s
    s = _stem()
    _kick_heavy(s, 0.0, 0.40)
    _kick_heavy(s, 0.30, 0.28)
    _kick_heavy(s, 2.0, 0.40)
    _kick_heavy(s, 2.30, 0.28)
    _st["heart"] = s
    s = _stem(8.5)
    for f in [87.31, 103.83, 155.56, 207.65]:
        _tone(s, MRATE, 0.0, 7.8, float(f), float(f) * 0.992, W_SAW, 0.05, 1.2, 3.0, 0.08, 5.5, 0.006)
    _st["pad"] = s
    s = _stem(2.4)
    _808(s, 0.0, 1.8, 60.0, 30.0, 1.0, 3.0)
    _kick_heavy(s, 0.0, 1.0)
    _air_noise(s, MRATE, 0.0, 1.6, 0.9, 2.8, 0.03, 0.50)
    _clap(s, 0.0, 0.6)
    _st["boom"] = s
    s = _stem(2.0)
    _808(s, 0.0, 1.6, 87.31, 36.71, 0.95, 3.0)
    _air_noise(s, MRATE, 0.0, 0.6, 0.35, 4.0, 0.03, 0.30)
    _st["fall"] = s
    # Акорди спадів і наростання 2 (по такту, 2 с): м'який пад, що рухається разом з басом і скрипкою.
    for nm in CH_VOICE:
        s = _stem(2.4)
        for m in CH_VOICE[nm]:
            var cf := _vm(float(m))
            _tone(s, MRATE, 0.0, 2.3, cf, cf * 0.996, W_SAW, 0.045, 1.4, 0.35, 0.10, 5.5, 0.005)
        _st["ch_" + String(nm)] = s

# ================= Бойова музика: заготовки, план вступу й наростання =================
# Заготовки «фраз» із готовим мікшем кількох стемів: так пісня на 272 с збирається за лічені проходи.
func _build_banks() -> void:
    for v in ["a", "b"]:
        var vs: String = v
        for lv in [1, 2, 3]:
            var lvl: int = lv
            var s := _stem()
            if lvl == 1:
                _put(s, "808" + vs, 0.0)
                _put(s, "reese" + vs, 0.0)
                _put(s, "kicks", 0.0)
                _put(s, "claps", 0.0)
                _put(s, "hats8", 0.0)
                _put(s, "cow", 0.0)
            elif lvl == 2:
                _put(s, "808" + vs, 0.0, 0.9)
                _put(s, "reese" + vs, 0.0, 0.9)
                _put(s, "kick4", 0.0, 0.8)
                _put(s, "claps", 0.0, 0.9)
                _put(s, "hats16", 0.0)
                _put(s, "cow", 0.0, 0.6)
            else:
                _put(s, "808" + vs, 0.0)
                _put(s, "dbl808", 0.0)
                _put(s, "reese" + vs, 0.0)
                _put(s, "kicks", 0.0)
                _put(s, "claps", 0.0)
                _put(s, "hats16", 0.0)
                _put(s, "cow", 0.0)
                _put(s, "toms", 0.0, 0.8)
                _put(s, "brass", 0.0, 0.9)
            _bank["%s%d" % [vs, lvl]] = s
    # шари: tension (хети + wub + ковбел), drive (рубаний бас, щипок, кіки, нарізки), horde (808, томи, мідь, крики)
    for w in [0, 1]:
        var st := _stem()
        _put(st, "hats16", 0.0, 0.9)
        _put(st, "wub%d" % w, 0.0)
        _put(st, "cow2", 0.0)
        _bank["tens%d" % w] = st
        var sd := _stem()
        _put(sd, "stab", 0.0)
        _put(sd, "pluck", 0.0)
        _put(sd, "kick_extra", 0.0)
        _put(sd, "chop", 0.0)
        if w == 1:
            _put(sd, "tom_fill", 0.0)
        _bank["drive%d" % w] = sd
        var sh := _stem()
        _put(sh, "dbl808", 0.0)
        _put(sh, "toms", 0.0)
        _put(sh, "brass", 0.0)
        if w == 1:
            _put(sh, "scream", 0.0)
        _bank["horde%d" % w] = sh

# План вступу: гучність кожного стема в кожній з 12 фраз. Біти набираються повільно: серцебиття й пад,
# потім хети, рідкий 808, кік, клепи, повний ритм, том-томи. «808*» і «reese*» — варіант a/b за парністю фрази.
const INTRO_PLAN := {
    "pad":          [0.8, 0.0, 0.8, 0.0, 0.8, 0.0, 0.8, 0.0, 0.6, 0.0, 0.6, 0.0],
    "heart":        [0.55, 0.6, 0.65, 0.7, 0.7, 0.7, 0.7, 0.7, 0.0, 0.0, 0.0, 0.0],
    "hats8":        [0.0, 0.0, 0.18, 0.25, 0.32, 0.4, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0],
    "sparse808":    [0.0, 0.0, 0.0, 0.3, 0.4, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "sparse_reese": [0.0, 0.0, 0.0, 0.0, 0.3, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "clap_half":    [0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "kicks":        [0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.5, 0.65, 0.0, 0.0, 0.0, 0.0],
    "kick4":        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.7, 0.85, 0.9],
    "claps":        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.55, 0.65, 0.75, 0.9, 0.9],
    "cow":          [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.5, 0.55, 0.6, 0.7, 0.7],
    "808*":         [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.45, 0.6, 0.7, 0.8, 0.9, 1.0],
    "reese*":       [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.5, 0.6, 0.7, 0.85, 0.95],
    "hats16":       [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.45, 0.6, 0.75, 0.9, 1.0],
    "toms":         [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.7, 0.9],
    "tom_fill":     [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.8],
    "dbl808":       [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5],
}

# План другого наростання (8 фраз): перші дві — лише пад (бас-гітара ще грає, барабанів немає),
# далі біти повертаються швидше, ніж у вступі.
const BUILD2_PLAN := {
    "pad":          [0.7, 0.0, 0.6, 0.0, 0.5, 0.0, 0.5, 0.0],
    "kicks":        [0.0, 0.0, 0.45, 0.6, 0.0, 0.0, 0.0, 0.0],
    "kick4":        [0.0, 0.0, 0.0, 0.0, 0.6, 0.75, 0.9, 0.95],
    "hats8":        [0.0, 0.0, 0.35, 0.5, 0.0, 0.0, 0.0, 0.0],
    "hats16":       [0.0, 0.0, 0.0, 0.0, 0.6, 0.8, 0.9, 1.0],
    "sparse808":    [0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0],
    "sparse_reese": [0.0, 0.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0],
    "claps":        [0.0, 0.0, 0.0, 0.5, 0.65, 0.8, 0.9, 0.9],
    "cow":          [0.0, 0.0, 0.0, 0.4, 0.5, 0.6, 0.7, 0.7],
    "808*":         [0.0, 0.0, 0.0, 0.6, 0.7, 0.8, 0.9, 1.0],
    "reese*":       [0.0, 0.0, 0.0, 0.5, 0.65, 0.75, 0.85, 0.95],
    "toms":         [0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.8, 0.9],
    "tom_fill":     [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 0.9],
    "dbl808":       [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5],
}

func _apply_plan(ev: PackedFloat32Array, plan: Dictionary, p0: int, count: int) -> void:
    for k in range(count):
        var t := _pt(p0 + k)
        var v := "a"
        if k % 2 == 1:
            v = "b"
        for key in plan:
            var gl: Array = plan[key]
            var g: float = gl[k]
            if g <= 0.0:
                continue
            var nm := String(key)
            if nm.ends_with("*"):
                nm = nm.trim_suffix("*") + v
            _put(ev, nm, t, g)

# ВСТУП: довге наростання. Серцебиття й пад → хети → рідкий 808 → кік → клепи → повний ритм → том-томи,
# під усім повільний райзер, у кінці «ту-ту-ту», шум і тиша «пф» перед першим БУХом.
func _song_intro(ev: PackedFloat32Array) -> void:
    _apply_plan(ev, INTRO_PLAN, P_INTRO, 12)
    _riser(ev, 20.0, 27.5, 120.0, 800.0, 0.08)
    _roll(ev, 36.0, 11.5, 0.5)
    _noise_swell(ev, 38.0, 9.5, 0.40)
    _bell(ev, MRATE, 8.0, 155.56, 0.06, 3.0)
    _bell(ev, MRATE, 20.0, 207.65, 0.06, 3.0)
    _bell(ev, MRATE, 30.0, 155.56, 0.07, 3.0)
    _voice(ev, MRATE, 26.0, 0.45, 200.0, 140.0, 0.16, 0.5)
    _voice(ev, MRATE, 34.0, 0.45, 200.0, 140.0, 0.18, 0.5)

# Частина з бітами (60 с): кожна фраза — готовий мікс потрібної щільності, на піках БУХ і крики.
func _song_beats(ev: PackedFloat32Array, p0: int, lv: Array, second: bool) -> void:
    for k in range(lv.size()):
        var t := _pt(p0 + k)
        var v := "a"
        if k % 2 == 1:
            v = "b"
        var level: int = lv[k]
        _place(ev, _bank["%s%d" % [v, level]], t)
        var big := false
        var shout := false
        if second:
            big = k == 0 or k == 4 or k == 7 or k == 10 or k == 12
            shout = k == 0 or k == 7 or k == 12
        else:
            big = k == 0 or k == 6 or k == 8
            shout = k == 0 or k == 8
        if big:
            _put(ev, "boom", t)
            _bell(ev, MRATE, t, 155.56, 0.08, 3.0)
        if shout:
            _put(ev, "scream", t)
        if k == lv.size() - 2:
            _put(ev, "tom_fill", t)

# СПАД: біти провалюються (фаза 0), майже тиша (фаза 1), далі «жорстка музика» без бітів: тут грає
# бас-гітара й скрипка (вони в окремих доріжках), а основа лишає лише пад, дзвони й шепіт.
func _song_decline(ev: PackedFloat32Array, p0: int, n: int) -> void:
    var t0 := _pt(p0)
    _put(ev, "fall", t0)
    _put(ev, "clap_half", t0, 0.8)
    _put(ev, "sparse808", t0, 0.7)
    _put(ev, "hats8", t0, 0.3)
    _put(ev, "pad", t0, 0.8)
    _put(ev, "heart", t0 + 4.0, 0.8)
    _put(ev, "sparse808", t0 + 4.0, 0.35)
    for k in range(2, n):
        if k % 2 == 0:
            _put(ev, "pad", t0 + float(k) * 4.0, 0.9)
    _bell(ev, MRATE, t0 + 14.0, 155.56, 0.07, 3.0)
    _bell(ev, MRATE, t0 + 22.0, 207.65, 0.07, 3.0)
    _voice(ev, MRATE, t0 + 18.0, 0.45, 200.0, 140.0, 0.16, 0.5)
    if n > 8:
        _bell(ev, MRATE, t0 + 30.0, 155.56, 0.07, 3.0)
        _voice(ev, MRATE, t0 + 26.0, 0.45, 200.0, 140.0, 0.18, 0.5)

# НАРОСТАННЯ 2: біти повертаються швидше, ніж у вступі; у кінці райзер, «ту-ту-ту» і «пф».
# Акордовий пад під прогресію (по такту на акорд): основа підтримує те, що грають бас і скрипка.
func _decl_chords(ev: PackedFloat32Array, t0: float, prog: Array, count: int, gain: float) -> void:
    for i in range(mini(count, prog.size())):
        _put(ev, "ch_" + String(prog[i]), t0 + float(i) * 2.0, gain)

func _song_build2(ev: PackedFloat32Array) -> void:
    _apply_plan(ev, BUILD2_PLAN, P_BUILD2, 8)
    var t0 := _pt(P_BUILD2)
    _riser(ev, t0 + 8.0, 23.5, 150.0, 900.0, 0.08)
    _roll(ev, t0 + 20.0, 11.5, 0.5)
    _noise_swell(ev, t0 + 22.0, 9.5, 0.40)

# Основа: уся композиція (барабани, баси, пад, дзвони). Скрипка й бас-гітара — окремі доріжки-шари.
func _make_battle_music() -> AudioStreamWAV:
    var per8 := _new(8.0, MRATE)
    _periodic(per8, MRATE, 8.0, 43.65, 0.12, 1, 0.0, 0.50)
    _periodic(per8, MRATE, 8.0, 87.31, 0.05, 2, 1.0, 0.40)
    _periodic(per8, MRATE, 8.0, 155.56, 0.02, 3, 1.0, 0.25)
    var ev := _new(SONG_SECS + 5.0, MRATE)
    _song_intro(ev)
    _song_beats(ev, P_BEATS1, BEATS1_LV, false)
    _song_decline(ev, P_DECL1, 10)
    _decl_chords(ev, _pt(P_DECL1 + 2), PROG_D1, 16, 0.9)
    _song_build2(ev)
    _decl_chords(ev, _pt(P_BUILD2), PROG_B2, 4, 1.0)
    _song_beats(ev, P_BEATS2, BEATS2_LV, true)
    _song_decline(ev, P_DECL2, 8)
    _decl_chords(ev, _pt(P_DECL2 + 2), PROG_D2, 10, 0.8)
    return _finish_track(per8, ev)

# Шар 1 «tension»: хвилюючий бас, приглушені хети, нижній ковбел — у частинах з бітами.
func _make_battle_tension() -> AudioStreamWAV:
    var per8 := _new(8.0, MRATE)
    _periodic(per8, MRATE, 8.0, 65.41, 0.05, 4, 0.0, 0.30)
    var ev := _new(SONG_SECS + 5.0, MRATE)
    for p in range(P_TOTAL):
        var lv := _beat_level(p)
        if lv > 0:
            var g := 1.0
            if lv == 1:
                g = 0.7
            _place(ev, _bank["tens%d" % _beat_var(p)], _pt(p), g)
    return _finish_track(per8, ev)

# Шар 2 «drive»: рубаний бас, грубий щипок-мелодія, додаткові кіки, том-філи — у щільних фразах.
func _make_battle_drive() -> AudioStreamWAV:
    var per8 := _new(8.0, MRATE)
    _periodic(per8, MRATE, 8.0, 87.31, 0.04, 8, 0.0, 0.40)
    var ev := _new(SONG_SECS + 5.0, MRATE)
    for p in range(P_TOTAL):
        if _beat_level(p) >= 2:
            _place(ev, _bank["drive%d" % _beat_var(p)], _pt(p))
    return _finish_track(per8, ev)

# Шар 3 «horde»: 808 на кожну долю, том-томи, мідь, крики, гуркіт — у найщільніших фразах.
func _make_battle_horde() -> AudioStreamWAV:
    var per8 := _new(8.0, MRATE)
    _periodic(per8, MRATE, 8.0, 77.78, 0.06, 9, 0.0, 0.40)
    _periodic(per8, MRATE, 8.0, 116.54, 0.03, 7, 1.7, 0.30)
    var ev := _new(SONG_SECS + 5.0, MRATE)
    for p in range(P_TOTAL):
        if _beat_level(p) == 3:
            _place(ev, _bank["horde%d" % (1 if p % 3 == 0 else 0)], _pt(p))
    _air_noise(ev, MRATE, _pt(P_BEATS1), 6.0, 0.10, 0.8, 0.02, 0.10)
    _air_noise(ev, MRATE, _pt(P_BEATS2), 6.0, 0.10, 0.8, 0.02, 0.10)
    return _finish_track(per8, ev)

# ================= Скрипка =================
# Скрипка — окремий шар (доріжка battle_violin), що доповнює музику, а не замінює її:
#  вступ — самотні ноти, що набирають силу, тремоло й швидкі арпеджіо, крик перед першим БУХом;
#  біти — «скажені» пасажі 32-ми, різкі мотиви, подвійні ноти, крики й тремоло;
#  спади — сумна лінія у діалозі з бас-гітарою, наростання знову до скаженої гри.
const SCALE := [0, 2, 3, 5, 7, 8, 10]   # F-мінор від тоніки; ступінь 0 = F4 (MIDI 65)
const RUN_ARP := [0, 2, 4, 7, 4, 2]
const RUN_SCL := [0, 1, 2, 3, 4, 5, 6, 7]
const MOTIF_A := [7, 7, 9, 7, 11, 9, 7, 5, 7, 7, 9, 7, 12, 11, 9, 8]
const MOTIF_B := [9, 9, 11, 9, 12, 11, 9, 7, 13, 12, 11, 9, 8, 9, 7, 5]
const DBL_A := [9, 8, 7, 6, 7, 8, 9, 7]
const DBL_B := [6, 5, 4, 6, 7, 5, 4, 2]
# Мелодії скрипки в частинах з бас-гітарою. Нота: [такт, початок у вісімках (0..7), довжина у вісімках, MIDI, гучність].
# Такт = 2 с = 8 вісімок по 0.25 с, тож кожна нота починається рівно на долю, а довжини кратні вісімці.
# Акорди тактів збігаються з басом і падом (PROG_D1 / PROG_D2), ноти — тони відповідного акорду.
# Спад 1, такти 0–7: Fm Fm Db Eb Fm Bb Db C (співуча лінія; бас: тік-так рифів і ходи)
const VMEL_D1A := [
    [0, 0, 6, 72, 0.9], [0, 6, 2, 70, 0.8],
    [1, 0, 4, 68, 0.9], [1, 4, 4, 65, 0.8],
    [2, 0, 2, 68, 0.8], [2, 2, 2, 73, 0.9], [2, 4, 4, 77, 1.0],
    [3, 0, 4, 79, 0.95], [3, 4, 4, 75, 0.9],
    [4, 0, 3, 80, 1.0], [4, 3, 1, 79, 0.85], [4, 4, 4, 77, 0.95],
    [5, 0, 4, 73, 0.9], [5, 4, 4, 77, 0.95],
    [6, 0, 2, 80, 0.95], [6, 2, 2, 77, 0.9], [6, 4, 4, 73, 0.9],
    [7, 0, 4, 72, 0.9], [7, 4, 1, 73, 0.8], [7, 5, 1, 72, 0.8], [7, 6, 2, 67, 0.85],
]
# Спад 1, такти 8–11: Fm Db Bb C (вище й гучніше, підводить до арпеджіо)
const VMEL_D1B := [
    [0, 0, 2, 77, 0.9], [0, 2, 2, 80, 0.95], [0, 4, 4, 84, 1.0],
    [1, 0, 4, 77, 0.9], [1, 4, 4, 80, 0.95],
    [2, 0, 4, 82, 0.95], [2, 4, 4, 77, 0.9],
    [3, 0, 4, 84, 1.0], [3, 4, 2, 82, 0.9], [3, 6, 2, 80, 0.9],
]
# Спад 2, такти 0–7: Fm Fm Db Eb Bb C Fm Fm (тихіша, довші ноти, затихає)
const VMEL_D2 := [
    [0, 0, 8, 72, 0.9],
    [1, 0, 4, 68, 0.9], [1, 4, 4, 65, 0.85],
    [2, 0, 4, 73, 0.9], [2, 4, 4, 68, 0.85],
    [3, 0, 6, 75, 0.9], [3, 6, 2, 73, 0.8],
    [4, 0, 8, 77, 0.9],
    [5, 0, 4, 72, 0.9], [5, 4, 4, 70, 0.85],
    [6, 0, 6, 68, 0.85], [6, 6, 2, 67, 0.8],
    [7, 0, 8, 72, 0.8],
]
# Які «скажені» фрази грає скрипка в частинах з бітами: 0 крик+пасаж, 1 пасажі, 2 мотив, 3 тремоло+крик, 4 подвійні ноти.
const VBEATS1 := [0, 1, 2, 1, 3, 2, 4, 1, 0, 2, 1, 4, 2, 3, 1]
const VBEATS2 := [0, 1, 4, 1, 2, 1, 3, 0, 1, 4, 2, 1, 0, 4, 3]

# MIDI-нота (можна дробову) → частота, Гц.
func _vm(m: float) -> float:
    return 440.0 * pow(2.0, (m - 69.0) / 12.0)

# Ступінь F-мінору → MIDI-нота (0 = F4).
func _sd(d: int) -> int:
    var oc := floori(float(d) / 7.0)
    return 65 + oc * 12 + int(SCALE[d - oc * 7])

# Голос скрипки: пилка (PolyBLEP) → двополюсний фільтр, що розкривається разом зі смичком → два резонанси
# корпусу (≈1.05 і ≈2.9 кГц) → перевантаження. Є вібрато із затримкою, «заїзд» знизу (scoop), тремоло смичка
# (trem_hz, td), шум смичка, плавний перехід висоти f → f_end і наростання/спад гучності (swell).
func _violin(ev: PackedFloat32Array, t0: float, dur: float, f: float, f_end: float, amp: float, bright: float, att: float, rel: float, vib_hz: float, vd: float, noise: float, trem_hz: float, td: float, drive: float, swell: float, scoop: float) -> void:
    var R := float(MRATE)
    var n0 := int(t0 * R)
    var n := int(dur * R)
    if n < 8:
        return
    var att_n := maxf(1.0, att * R)
    var rel_n := maxf(1.0, rel * R)
    var lp_lo := 1.0 - exp(-TAU * (500.0 + 1500.0 * bright) / R)
    var lp_hi := 1.0 - exp(-TAU * (900.0 + 5200.0 * bright) / R)
    var rr := 0.93
    var c1 := 2.0 * rr * cos(TAU * 1050.0 / R)
    var c2 := 2.0 * rr * cos(TAU * 2900.0 / R)
    var r2 := rr * rr
    var rg := (1.0 - rr) * 1.2
    var nrm := 1.0
    if drive > 1.0:
        nrm = 1.0 / tanh(drive * 0.7)
    var ph := 0.0
    var y1 := 0.0
    var y2 := 0.0
    var a1 := 0.0
    var a2 := 0.0
    var b1 := 0.0
    var b2 := 0.0
    var nzp := 0.0
    var df := f_end - f
    for i in range(n):
        var idx := n0 + i
        if idx >= ev.size():
            break
        var t := float(i) / R
        var u := float(i) / float(n)
        var fi := f + df * (u * u * (3.0 - 2.0 * u))
        if scoop > 0.0:
            fi *= 1.0 - scoop * exp(-t * 18.0)
        if vd > 0.0 and t > 0.12:
            fi *= 1.0 + vd * minf(1.0, (t - 0.12) * 4.0) * sin(TAU * vib_hz * t)
        var dt := fi / R
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
        var s := 2.0 * ph - 1.0
        if ph < dt:
            var x1 := ph / dt
            s -= x1 + x1 - x1 * x1 - 1.0
        elif ph > 1.0 - dt:
            var x2 := (ph - 1.0) / dt
            s -= x2 * x2 + x2 + x2 + 1.0
        var e := minf(1.0, float(i) / att_n) * minf(1.0, float(n - i) / rel_n)
        var a := amp * e * (1.0 + (swell - 1.0) * u)
        if td > 0.0:
            a *= (1.0 - td) + td * absf(sin(PI * trem_hz * t))
        var lp := lp_lo + (lp_hi - lp_lo) * e
        y1 += (s - y1) * lp
        y2 += (y1 - y2) * lp
        var q1 := c1 * a1 - r2 * a2 + y2 * rg
        a2 = a1
        a1 = q1
        var q2 := c2 * b1 - r2 * b2 + y2 * rg
        b2 = b1
        b1 = q2
        var v := y2 * 0.8 + q1 * 0.9 + q2 * 0.5
        if noise > 0.0:
            var nz := _rng.randf_range(-1.0, 1.0)
            v += (nz - nzp) * noise * 0.5
            nzp = nz
        if drive > 1.0:
            v = tanh(v * drive) * nrm
        ev[idx] += v * a

# Співоча нота: повільний смичок, вібрато, наростання гучності (swell > 1) або спад (< 1).
func _v_sing(ev: PackedFloat32Array, t0: float, dur: float, m: float, amp: float, bright: float, swell: float, att: float) -> void:
    var f := _vm(m)
    _violin(ev, t0, dur, f, f, amp, bright, att, 0.3, 5.8, 0.009, 0.03, 0.0, 0.0, 1.0, swell, 0.03)

# Швидка нота (спікато / пасаж): короткий смичок, без вібрато, із шумом смичка й перевантаженням.
func _v_fast(ev: PackedFloat32Array, t0: float, dur: float, m: float, amp: float, bright: float, drive: float) -> void:
    var f := _vm(m)
    _violin(ev, t0, dur, f, f, amp, bright, 0.006, 0.012, 0.0, 0.0, 0.07, 0.0, 0.0, drive, 1.0, 0.0)

# Те саме, але нота задається ступенем F-мінору.
func _v_deg(ev: PackedFloat32Array, t0: float, dur: float, d: int, amp: float, bright: float, drive: float) -> void:
    _v_fast(ev, t0, dur, float(_sd(clampi(d, -6, 14))), amp, bright, drive)

# Тремоло смичка: нота тремтить (rate штрихів за секунду) і поступово голоснішає.
func _v_trem(ev: PackedFloat32Array, t0: float, dur: float, m: float, amp: float, bright: float, swell: float, rate: float) -> void:
    var f := _vm(m)
    _violin(ev, t0, dur, f, f, amp, bright, 0.08, 0.2, 6.5, 0.006, 0.05, rate, 0.75, 1.6, swell, 0.0)

# Крик: висока нота, що злітає знизу (glide — у півтонах), із широким швидким вібрато й дисторсією.
func _v_shriek(ev: PackedFloat32Array, t0: float, dur: float, m: float, amp: float, glide: float) -> void:
    _violin(ev, t0, dur, _vm(m - glide), _vm(m), amp, 1.0, 0.03, 0.08, 7.6, 0.016, 0.1, 0.0, 0.0, 2.8, 1.15, 0.0)

# Падіння: довга нота повзе вниз і згасає.
func _v_fall(ev: PackedFloat32Array, t0: float, dur: float, m0: float, m1: float, amp: float) -> void:
    _violin(ev, t0, dur, _vm(m0), _vm(m1), amp, 0.5, 0.05, 0.6, 5.5, 0.012, 0.06, 0.0, 0.0, 1.8, 0.5, 0.0)

# Арпеджіо/пасаж по ступенях: pattern — зсуви ступенів у циклі, base росте на rise за кожен цикл.
func _v_arp(ev: PackedFloat32Array, t0: float, step: float, count: int, base: int, pattern: Array, rise: int, amp0: float, amp1: float, bright: float, drive: float) -> void:
    var psz := pattern.size()
    for k in range(count):
        var cyc := floori(float(k) / float(psz))
        var d: int = base + int(pattern[k % psz]) + rise * cyc
        var u := float(k) / float(maxi(1, count - 1))
        var a := lerpf(amp0, amp1, u)
        if k % psz == 0:
            a *= 1.12
        _v_deg(ev, t0 + float(k) * step, step * 1.12, d, a, bright, drive)

# --- «скажені» фрази для частин з бітами (кожна — 4 с = 2 такти) ---
func _vp_run(ev: PackedFloat32Array, t: float, k: int, pw: float) -> void:
    var bases := [2, 5, 3, 7, 2, 6]
    for h in range(4):
        var b: int = int(bases[(k + h) % 6])
        var pat: Array = RUN_ARP
        if h % 2 == 1:
            pat = RUN_SCL
        _v_arp(ev, t + float(h), 0.0625, 16, b, pat, 0, 0.8 * pw, 0.95 * pw, 0.9, 2.2)

func _vp_stac(ev: PackedFloat32Array, t: float, k: int, pw: float) -> void:
    var shifts := [0, -2, 2]
    var shift: int = shifts[k % 3]
    for bar in range(2):
        var mt: Array = MOTIF_A
        if bar == 1:
            mt = MOTIF_B
        for i in range(16):
            var a := 0.78 * pw
            if i % 4 == 0:
                a = 0.95 * pw
            _v_deg(ev, t + float(bar) * 2.0 + float(i) * 0.125, 0.14, int(mt[i]) + shift, a, 0.95, 2.4)

func _vp_trem(ev: PackedFloat32Array, t: float, pw: float) -> void:
    _v_trem(ev, t, 2.0, float(_sd(11)), 0.75 * pw, 0.9, 1.5, 14.0)
    _v_shriek(ev, t + 2.0, 1.95, float(_sd(13)), 0.9 * pw, 5.0)

func _vp_double(ev: PackedFloat32Array, t: float, pw: float) -> void:
    for bar in range(2):
        var dd: Array = DBL_A
        if bar == 1:
            dd = DBL_B
        for i in range(8):
            var d: int = int(dd[i])
            var a := 0.62 * pw
            if i == 0:
                a = 0.78 * pw
            var tt := t + float(bar) * 2.0 + float(i) * 0.25
            _v_deg(ev, tt, 0.26, d, a, 0.85, 2.0)
            _v_deg(ev, tt, 0.26, d + 4, a * 0.85, 0.85, 2.0)

func _vp_shriek(ev: PackedFloat32Array, t: float, k: int, pw: float) -> void:
    _v_shriek(ev, t, 1.95, float(_sd(14)), 0.95 * pw, 3.0)
    var bases := [3, 6, 2, 5]
    for h in range(2):
        var b: int = int(bases[(k + h) % 4])
        _v_arp(ev, t + 2.0 + float(h), 0.0625, 16, b, RUN_ARP, 0, 0.85 * pw, 0.98 * pw, 0.9, 2.3)

func _vio_beats(ev: PackedFloat32Array, p0: int, seq: Array, pw: float) -> void:
    for k in range(seq.size()):
        var t := _pt(p0 + k)
        var w := pw
        if k == seq.size() - 1:
            w = pw * 0.8
        match int(seq[k]):
            0:
                _vp_shriek(ev, t, k, w)
            1:
                _vp_run(ev, t, k, w)
            2:
                _vp_stac(ev, t, k, w)
            3:
                _vp_trem(ev, t, w)
            _:
                _vp_double(ev, t, w)

# ВСТУП: самотні довгі ноти → ноти по 2 с → тремоло → арпеджіо 8-ми → 16-ті → 32-ті → крик перед «пф».
func _vio_intro(ev: PackedFloat32Array) -> void:
    var lament := [4, 5, 4, 2]
    for k in range(4):
        var u := float(k) / 3.0
        _v_sing(ev, 1.0 + float(k) * 4.0, 4.8, float(_sd(int(lament[k]))), lerpf(0.16, 0.26, u), lerpf(0.15, 0.3, u), 1.3, 0.9)
    var mid := [5, 7, 8, 7, 9, 8]
    for k2 in range(6):
        var u2 := float(k2) / 5.0
        _v_sing(ev, 16.0 + float(k2) * 2.0, 2.3, float(_sd(int(mid[k2]))), lerpf(0.3, 0.5, u2), lerpf(0.35, 0.55, u2), 1.25, 0.2)
    _v_trem(ev, 28.0, 2.2, float(_sd(9)), 0.52, 0.6, 1.3, 13.0)
    _v_trem(ev, 30.0, 2.2, float(_sd(10)), 0.6, 0.65, 1.3, 14.0)
    _v_arp(ev, 32.0, 0.25, 16, 4, [0, 2, 4, 2], 1, 0.5, 0.62, 0.6, 1.5)
    _v_arp(ev, 36.0, 0.25, 16, 6, [0, 2, 4, 2], 1, 0.64, 0.75, 0.65, 1.6)
    _v_arp(ev, 40.0, 0.125, 32, 2, RUN_ARP, 1, 0.7, 0.8, 0.8, 1.8)
    _v_arp(ev, 44.0, 0.0625, 32, 0, [0, 2, 4, 7], 1, 0.8, 0.9, 0.9, 2.2)
    _v_shriek(ev, 46.0, 1.55, float(_sd(14)), 0.95, 7.0)

# Грає мелодію з таблиці (див. VMEL_*): кожна нота починається рівно на вісімці свого такту.
func _vio_mel(ev: PackedFloat32Array, t0: float, mel: Array, amp: float, bright: float) -> void:
    for nt in mel:
        var n: Array = nt
        var ts := t0 + float(n[0]) * 2.0 + float(n[1]) * 0.25
        var dur := float(n[2]) * 0.25
        var att := minf(0.14, dur * 0.35)
        _v_sing(ev, ts, dur + 0.1, float(n[3]), amp * float(n[4]), bright, 1.25, att)

# Арпеджіо з тонів акорда (MIDI), що йде рівно по сітці: count нот із кроком step, гучність amp0 → amp1.
func _v_chord_arp(ev: PackedFloat32Array, t0: float, step: float, count: int, tones: Array, amp0: float, amp1: float, bright: float, drive: float) -> void:
    var sz := tones.size()
    for k in range(count):
        var u := float(k) / float(maxi(1, count - 1))
        var a := lerpf(amp0, amp1, u)
        if k % sz == 0:
            a *= 1.12
        _v_fast(ev, t0 + float(k) * step, step * 1.12, float(tones[k % sz]), a, bright, drive)

# СПАД: скрипка падає вниз, ледь чутний флажолет перед входом бас-гітари, далі мелодія за акордами баса.
# У першому спаді в кінці знову наростає (арпеджіо Fm по тактах), у другому — згасає перед новим вступом.
func _vio_decline(ev: PackedFloat32Array, p0: int, n: int) -> void:
    var t0 := _pt(p0)
    _v_fall(ev, t0, 3.6, float(_sd(9)), float(_sd(0)), 0.6)
    _v_sing(ev, t0 + 5.0, 3.2, float(_sd(11)), 0.16, 0.1, 0.7, 0.9)
    if n > 8:
        _vio_mel(ev, t0 + 8.0, VMEL_D1A, 0.42, 0.35)
        _vio_mel(ev, t0 + 24.0, VMEL_D1B, 0.52, 0.5)
        _v_chord_arp(ev, t0 + 32.0, 0.25, 8, [65, 68, 72, 68], 0.40, 0.45, 0.55, 1.4)
        _v_chord_arp(ev, t0 + 34.0, 0.25, 8, [68, 72, 77, 72], 0.45, 0.50, 0.58, 1.4)
        _v_chord_arp(ev, t0 + 36.0, 0.125, 16, [72, 77, 80, 77], 0.50, 0.56, 0.62, 1.5)
        _v_chord_arp(ev, t0 + 38.0, 0.125, 16, [77, 80, 84, 80], 0.58, 0.66, 0.68, 1.6)
    else:
        _vio_mel(ev, t0 + 8.0, VMEL_D2, 0.38, 0.3)
        _v_sing(ev, t0 + 24.0, 5.5, float(_sd(0)), 0.22, 0.2, 0.25, 0.6)

# НАРОСТАННЯ 2: такти 0–3 (Db Eb C C) — тремоло по тонах акордів, що лізе вгору; далі над басом F
# арпеджіо Fm по тактах: 8-ті → 16-ті → 32-ті, у кінці тремоло й крик до «пф».
func _vio_build2(ev: PackedFloat32Array) -> void:
    var t0 := _pt(P_BUILD2)
    var trem := [77, 79, 82, 84]
    for k in range(4):
        _v_trem(ev, t0 + float(k) * 2.0, 2.2, float(trem[k]), 0.45 + 0.05 * float(k), 0.55, 1.5, 13.0)
    _v_chord_arp(ev, t0 + 8.0, 0.25, 8, [65, 68, 72, 68], 0.60, 0.66, 0.7, 1.6)
    _v_chord_arp(ev, t0 + 10.0, 0.25, 8, [68, 72, 75, 72], 0.66, 0.72, 0.7, 1.6)
    _v_chord_arp(ev, t0 + 12.0, 0.25, 8, [72, 77, 80, 77], 0.72, 0.76, 0.72, 1.6)
    _v_chord_arp(ev, t0 + 14.0, 0.25, 8, [75, 80, 84, 80], 0.76, 0.80, 0.74, 1.7)
    _v_chord_arp(ev, t0 + 16.0, 0.125, 16, [65, 68, 72, 75, 77, 75, 72, 68], 0.78, 0.80, 0.85, 2.0)
    _v_chord_arp(ev, t0 + 18.0, 0.125, 16, [65, 68, 72, 75, 77, 75, 72, 68], 0.80, 0.82, 0.85, 2.0)
    _v_chord_arp(ev, t0 + 20.0, 0.125, 16, [68, 72, 75, 77, 80, 77, 75, 72], 0.82, 0.86, 0.85, 2.0)
    _v_chord_arp(ev, t0 + 22.0, 0.125, 16, [68, 72, 75, 77, 80, 77, 75, 72], 0.86, 0.90, 0.85, 2.0)
    _v_chord_arp(ev, t0 + 24.0, 0.0625, 24, [72, 75, 77, 80, 84, 80, 77, 75], 0.90, 0.95, 0.9, 2.3)
    _v_chord_arp(ev, t0 + 25.5, 0.0625, 24, [75, 77, 80, 84, 87, 84, 80, 77], 0.92, 0.97, 0.9, 2.3)
    _v_chord_arp(ev, t0 + 27.0, 0.0625, 24, [77, 80, 84, 87, 89, 87, 84, 80], 0.94, 1.0, 0.95, 2.4)
    _v_trem(ev, t0 + 28.5, 2.5, float(_sd(12)), 0.95, 1.0, 1.3, 16.0)
    _v_shriek(ev, t0 + 29.5, 2.0, float(_sd(14)), 0.95, 8.0)

func _make_battle_violin() -> AudioStreamWAV:
    var ev := _new(SONG_SECS + 5.0, MRATE)
    _vio_intro(ev)
    _vio_beats(ev, P_BEATS1, VBEATS1, 0.85)
    _vio_decline(ev, P_DECL1, 10)
    _vio_build2(ev)
    _vio_beats(ev, P_BEATS2, VBEATS2, 1.0)
    _vio_decline(ev, P_DECL2, 8)
    return _finish_track(PackedFloat32Array(), ev, 1.3)

# ================= Бас-гітара =================
# Бас-гітара — окрема доріжка (battle_bass). Вступ і перша частина з бітами (0–116 с) — без неї.
# Вона входить після першого затишшя (спад 1) і далі не замовкає: спад 1, наростання 2 (рубані
# шістнадцяті перед БУХом), уся друга частина з бітами — разом з барабанами, і спад 2.

# Струна Карплуса-Стронга (щипок медіатором): шматок згладженого шуму в лінії затримки, що поступово
# гасне. mute (0..1) — глушіння долонею (коротка «рубана» нота), drive — перевантаження (жорсткий тембр).
func _bass(ev: PackedFloat32Array, t0: float, dur: float, f: float, amp: float, mute: float, drive: float = 2.2, lp: float = 0.55) -> void:
    var R := float(MRATE)
    var n0 := int(t0 * R)
    var n := int(dur * R)
    if n < 8:
        return
    var L := maxi(8, int(roundf(R / f - 0.5)))
    var buf := PackedFloat32Array()
    buf.resize(L)
    var lpx := 0.0
    var acc := 0.0
    for i in range(L):
        lpx += (_rng.randf_range(-1.0, 1.0) - lpx) * 0.30
        buf[i] = lpx
        acc += lpx
    var mean := acc / float(L)
    var pk := 0.0001
    for i2 in range(L):
        buf[i2] -= mean
        pk = maxf(pk, absf(buf[i2]))
    for i3 in range(L):
        buf[i3] /= pk
    var g := 0.9985 - 0.03 * mute
    var tone := 0.0
    var j := 0
    var att_n := maxf(1.0, 0.002 * R)
    var rel_n := maxf(1.0, 0.03 * R)
    for i4 in range(n):
        var idx := n0 + i4
        if idx >= ev.size():
            break
        var nx := j + 1
        if nx >= L:
            nx = 0
        var s := buf[j]
        buf[j] = (s + buf[nx]) * 0.5 * g
        j = nx
        tone += (s - tone) * lp
        var e := minf(1.0, float(i4) / att_n) * minf(1.0, float(n - i4) / rel_n)
        var v := tanh(tone * drive * 2.2) * amp * e
        if i4 < 48:
            v += _rng.randf_range(-1.0, 1.0) * amp * 0.25 * (1.0 - float(i4) / 48.0)
        ev[idx] += v

# ===== Гармонія половини з бас-гітарою (спад 1, наростання 2, біти 2, спад 2) =====
# Такт = 2 с (4 долі по 0.5 с, 8 вісімок), фраза = 2 такти. Бас, скрипка й акордовий пад у фоні грають за
# ОДНІЄЮ послідовністю акордів F-мінору й міняють акорд точно на початку такту, тож усе збігається.
# Корінь баса — півтони від F1 (MIDI 29); «колір» — інтервал від кореня (3-тя, 2-га чи 7-ма), що не б'ється з падом.
const BASE_MIDI := 29
const CH_ROOT := {"Fm": 0, "Db": 8, "Eb": 10, "Bb": 5, "C": 7}
const CH_COL := {"Fm": 3, "Db": 4, "Eb": 2, "Bb": 3, "C": 10}
# Спад 1 (фрази 29–36, 16 тактів): два кола прогресії, далі 4 такти F під арпеджіо скрипки.
const PROG_D1 := ["Fm", "Fm", "Db", "Eb", "Fm", "Bb", "Db", "C", "Fm", "Db", "Bb", "C", "Fm", "Fm", "Fm", "Fm"]
const STY_D1 := [1, 3, 5, 2, 4, 3, 1, 0, 1, 4, 2, 3, 2, 1, 6, 6]
# Наростання 2 (фрази 37–44): 4 такти «пада» (Db Eb C C), далі басовий педаль F під барабани.
const PROG_B2 := ["Db", "Eb", "C", "C", "Fm", "Fm", "Fm", "Fm", "Fm", "Fm", "Fm", "Fm", "Fm", "Fm", "Fm", "Fm"]
const STY_B2 := [0, 5, 6, 6, 1, 4, 2, 1, 6, 2, 6, 4, 6, 6, 6, 6]
# Спад 2 (фрази 62–66, 10 тактів): повільніше, тихіше, в кінці — дрон F.
const PROG_D2 := ["Fm", "Fm", "Db", "Eb", "Bb", "C", "Fm", "Fm", "Fm", "Fm"]
const STY_D2 := [5, 3, 0, 5, 3, 0, 3, 0, 0, 0]
# Стилі такту: 0 довга нота, 1 пульс вісімками з октавою, 2 галоп, 3 хід чвертями, 4 синкопа, 5 арпеджіо, 6 рубані 16-ті.
# Біти 2 (15 фраз): стилі першого й другого такту кожної фрази; корінь F — під 808.
const BASS_BEATS2 := [[1, 1], [2, 4], [1, 2], [4, 3], [1, 6], [2, 1], [5, 3], [1, 4], [4, 6], [1, 5], [2, 3], [6, 1], [1, 6], [4, 2], [3, 0]]

func _bn(root: int, iv: int) -> float:
    return _vm(float(BASE_MIDI + root + iv))

# Нота-підхід до наступного кореня (на пів тону зверху чи знизу); 99 — підхід не потрібен.
func _appr(root: int, nxt: int) -> int:
    if nxt == root:
        return 99
    if nxt < root:
        return nxt + 1
    return nxt - 1

# Один такт (2 с). hard — жорсткий тембр з перевантаженням (для рифів), інакше — тепліший (для довгих нот і ходів).
# appr — нота-підхід в останній вісімці такту (півтони від F1) або 99.
func _bass_bar(ev: PackedFloat32Array, t: float, style: int, root: int, col: int, amp: float, hard: bool, appr: int) -> void:
    var drive := 1.5
    var lp := 0.34
    var mu := 0.35
    if hard:
        drive = 2.4
        lp = 0.55
        mu = 0.8
    var has_app := appr != 99
    var fa := 0.0
    if has_app:
        fa = _bn(0, appr)
    match style:
        0:
            _bass(ev, t, 1.5, _bn(root, 0), amp, 0.0, drive, lp)
            if has_app:
                _bass(ev, t + 1.5, 0.45, fa, amp * 0.85, 0.3, drive, lp)
            else:
                _bass(ev, t + 1.5, 0.45, _bn(root, 7), amp * 0.5, 0.3, drive, lp)
        1:
            var pat := [0, 0, 12, 0, 0, 0, 7, 0]
            for k in range(8):
                var tk := t + float(k) * 0.25
                var ak := amp * 0.85
                if k % 4 == 0:
                    ak = amp
                if k == 7 and has_app:
                    _bass(ev, tk, 0.24, fa, amp * 0.9, mu, drive, lp)
                else:
                    var ivk := int(pat[k])
                    var mk := mu
                    if ivk == 12:
                        mk = 0.3
                    _bass(ev, tk, 0.24, _bn(root, ivk), ak, mk, drive, lp)
        2:
            for g in range(4):
                var tg := t + float(g) * 0.5
                _bass(ev, tg, 0.23, _bn(root, 0), amp, mu, drive, lp)
                if g == 3 and has_app:
                    _bass(ev, tg + 0.25, 0.24, fa, amp * 0.9, mu, drive, lp)
                else:
                    _bass(ev, tg + 0.25, 0.11, _bn(root, 0), amp * 0.8, minf(1.0, mu + 0.1), drive, lp)
                    _bass(ev, tg + 0.375, 0.11, _bn(root, 0), amp * 0.8, minf(1.0, mu + 0.1), drive, lp)
        3:
            var wk := [0, 0, col, 7]
            for w in range(4):
                var aw := amp * 0.9
                if w == 0:
                    aw = amp
                if w == 3 and has_app:
                    _bass(ev, t + 1.5, 0.5, fa, amp * 0.9, mu * 0.4, drive, lp)
                else:
                    _bass(ev, t + float(w) * 0.5, 0.5, _bn(root, int(wk[w])), aw, mu * 0.4, drive, lp)
        4:
            var sy_t := [0.0, 0.75, 1.0, 1.5, 1.75]
            var sy_i := [0, 0, 12, 0, col]
            var sy_d := [0.7, 0.2, 0.2, 0.2, 0.2]
            for y in range(5):
                var ay := amp * 0.82
                if y == 0:
                    ay = amp
                var fy := _bn(root, int(sy_i[y]))
                if y == 4 and has_app:
                    fy = fa
                var my := mu
                if y == 0:
                    my = mu * 0.4
                _bass(ev, t + float(sy_t[y]), float(sy_d[y]), fy, ay, my, drive, lp)
        5:
            var ar := [0, 7, 12, 7, 0, 7, 12, col]
            for q in range(8):
                var aq := amp * 0.85
                if q % 4 == 0:
                    aq = amp
                var fq := _bn(root, int(ar[q]))
                if q == 7 and has_app:
                    fq = fa
                _bass(ev, t + float(q) * 0.25, 0.24, fq, aq, mu * 0.6, drive, lp)
        _:
            for c in range(16):
                var ivc := 0
                if c % 8 == 7:
                    ivc = 12
                var fc := _bn(root, ivc)
                if c == 15 and has_app:
                    fc = fa
                var ac := amp * 0.78
                if c % 4 == 0:
                    ac = amp
                _bass(ev, t + float(c) * 0.125, 0.12, fc, ac, 0.9, drive, lp)

# Ряд тактів за прогресією prog і стилями styles; nxt — акорд, що йде після останнього такту (для ноти-підходу).
func _bass_run(ev: PackedFloat32Array, t0: float, prog: Array, styles: Array, amp0: float, amp1: float, nxt: String) -> void:
    var n := prog.size()
    for i in range(n):
        var nm := String(prog[i])
        var nn := nxt
        if i + 1 < n:
            nn = String(prog[i + 1])
        var st := int(styles[i])
        var hard := st == 1 or st == 2 or st == 4 or st == 6
        var a := lerpf(amp0, amp1, float(i) / float(maxi(1, n - 1)))
        _bass_bar(ev, t0 + float(i) * 2.0, st, int(CH_ROOT[nm]), int(CH_COL[nm]), a, hard, _appr(int(CH_ROOT[nm]), int(CH_ROOT[nn])))

# Біти 2: бас-гітара грає разом з барабанами, корінь F (як 808). У кожній фразі свої два стилі,
# в останній вісімці другого такту — підхід (Ab під 808 «a», Eb під 808 «b»), що веде до наступного F.
func _bass_beats2(ev: PackedFloat32Array) -> void:
    var total := BEATS2_LV.size()
    for k in range(total):
        var t := _pt(P_BEATS2 + k)
        var pr: Array = BASS_BEATS2[k]
        var ap := 3
        if k % 2 == 1:
            ap = -2
        if k == total - 1:
            ap = 99
        var a := 1.0
        if int(BEATS2_LV[k]) == 1:
            a = 0.9
        _bass_bar(ev, t, int(pr[0]), 0, 3, a, true, 99)
        _bass_bar(ev, t + 2.0, int(pr[1]), 0, 3, a * 0.95, true, ap)

func _make_battle_bass() -> AudioStreamWAV:
    var ev := _new(SONG_SECS + 5.0, MRATE)
    # Спад 1: вхід після падіння бітів (3-тя фраза спаду, 116 с), 16 тактів за прогресією.
    _bass_run(ev, _pt(P_DECL1 + 2), PROG_D1, STY_D1, 0.9, 1.0, "Db")
    # Наростання 2: 4 такти під пад, далі педаль F і рубані шістнадцяті аж до БУХу.
    _bass_run(ev, _pt(P_BUILD2), PROG_B2, STY_B2, 0.9, 1.0, "Fm")
    # Біти 2 (180–240 с): разом з барабанами.
    _bass_beats2(ev)
    # Спад 2: 10 тактів (фрази 62–66), поступово тихіше, в кінці дрон F.
    _bass_run(ev, _pt(P_DECL2 + 2), PROG_D2, STY_D2, 0.95, 0.5, "Fm")
    return _finish_track(PackedFloat32Array(), ev, 1.2)
