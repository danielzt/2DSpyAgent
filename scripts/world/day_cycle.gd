extends RefCounted
## Ciclo de dia e noite (lógica pura): hora do mundo, fases do dia, cor ambiente e
## horários das luzes. O autoload WorldClock só acumula o tempo; tudo o que depende da
## hora é calculado aqui. Ver docs/redesign-visual.md, seção 8.

## Um dia de jogo em segundos reais (12 min: 1 hora de jogo = 30 s).
const DAY_SECONDS := 720.0
const START_HOUR := 8.0

const PHASES := ["madrugada", "amanhecer", "dia", "entardecer", "noite"]
## Início de cada fase, em horas.
const DAWN := 5.0
const DAY := 8.0
const DUSK := 17.0
const NIGHT := 19.5

## Chaves da cor ambiente: [hora, cor]. Entre duas chaves a cor é interpolada.
const AMBIENT_KEYS := [
	[0.0, "7078d0"], [5.0, "7078d0"], [6.25, "f2b3c7"], [8.0, "ffffff"],
	[17.0, "ffffff"], [18.5, "ffc49a"], [19.5, "9e73cc"], [21.0, "7078d0"], [24.0, "7078d0"],
]
## Piso de luminosidade: a noite nunca fica mais escura que isto.
const MIN_LUMINANCE := 0.45
const MIN_CHANNEL := 0.40

## Luzes: [acende, apaga] em horas (podem virar a meia-noite).
const LIGHTS := {
	"lamp": [18.0, 6.5],
	"window": [18.0, 6.0],
	"sign": [18.0, 6.0],
	"headlight": [18.0, 6.5],
	"player": [19.5, 6.0],
}
## Moradias apagam as janelas neste intervalo; escritórios apagam às 20:00.
const HOME_LIGHTS_OFF := [23.0, 6.0]
const OFFICE_LIGHTS_OFF := 20.0

## População e trânsito conforme a hora.
const CITY_PEDESTRIANS_DAY := 110
const CITY_PEDESTRIANS_NIGHT := 60
const CITY_PEDESTRIANS_LATE := 25
const LATE_HOUR := 23.0
const TRAFFIC_DAY := 10
const TRAFFIC_NIGHT := 6
## Intervalo entre crimes na cidade à noite (de dia vale o do perfil).
const NIGHT_CRIME_INTERVAL_FACTOR := 0.64


## Hora (0 a 24) a partir dos segundos acumulados desde 00:00 do primeiro dia.
static func hour_of(seconds: float) -> float:
	return fposmod(seconds, DAY_SECONDS) / DAY_SECONDS * 24.0


## Dia do mundo (0 = primeiro).
static func day_of(seconds: float) -> int:
	return int(floor(seconds / DAY_SECONDS))


static func seconds_per_hour() -> float:
	return DAY_SECONDS / 24.0


static func phase_of(hour: float) -> String:
	hour = fposmod(hour, 24.0)
	if hour < DAWN:
		return "madrugada"
	if hour < DAY:
		return "amanhecer"
	if hour < DUSK:
		return "dia"
	if hour < NIGHT:
		return "entardecer"
	return "noite"


## Noite para o jogo (crimes, pedestres, prédios): das 19:30 às 05:00.
static func is_night(hour: float) -> bool:
	var phase := phase_of(hour)
	return phase == "noite" or phase == "madrugada"


## True se `hour` está no intervalo [from, to), que pode virar a meia-noite.
static func in_range(hour: float, from: float, to: float) -> bool:
	hour = fposmod(hour, 24.0)
	if from <= to:
		return hour >= from and hour < to
	return hour >= from or hour < to


## Horas que faltam de `hour` até `target` (sempre para a frente, de 0 a 24).
static func hours_until(hour: float, target: float) -> float:
	return fposmod(target - hour, 24.0)


## "08:05".
static func clock_text(hour: float) -> String:
	hour = fposmod(hour, 24.0)
	var total_minutes := int(floor(hour * 60.0 + 0.0001))
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]


## Cor ambiente do mundo externo (multiplica tudo). Nunca abaixo do piso de luminosidade.
static func ambient_color(hour: float) -> Color:
	hour = fposmod(hour, 24.0)
	var color := Color.WHITE
	for i in range(AMBIENT_KEYS.size() - 1):
		var a: Array = AMBIENT_KEYS[i]
		var b: Array = AMBIENT_KEYS[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t: float = 0.0 if b[0] == a[0] else (hour - a[0]) / (b[0] - a[0])
			color = Color(a[1]).lerp(Color(b[1]), t)
			break
	return Color(maxf(color.r, MIN_CHANNEL), maxf(color.g, MIN_CHANNEL), maxf(color.b, MIN_CHANNEL))


static func luminance(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


## Quanto do escuro da noite está valendo (0 de dia, 1 no auge da noite). Serve para a
## intensidade das luzes.
static func darkness(hour: float) -> float:
	var lum := luminance(ambient_color(hour))
	var night_lum := luminance(Color(AMBIENT_KEYS[0][1]))
	return clampf((1.0 - lum) / (1.0 - night_lum), 0.0, 1.0)


## True se a luz do tipo dado está acesa.
static func light_on(kind: String, hour: float) -> bool:
	if not LIGHTS.has(kind):
		return false
	var span: Array = LIGHTS[kind]
	return in_range(hour, span[0], span[1])


## Janelas: acesas de noite conforme o uso do prédio ("home", "office" ou "" para o resto).
static func windows_on(use: String, hour: float) -> bool:
	if not light_on("window", hour):
		return false
	match use:
		"home":
			return not in_range(hour, HOME_LIGHTS_OFF[0], HOME_LIGHTS_OFF[1])
		"office":
			return in_range(hour, LIGHTS["window"][0], OFFICE_LIGHTS_OFF)
	return true


## Pedestres da cidade na hora dada.
static func city_pedestrians(hour: float) -> int:
	if not is_night(hour):
		return CITY_PEDESTRIANS_DAY
	if in_range(hour, NIGHT, LATE_HOUR):
		return CITY_PEDESTRIANS_NIGHT
	return CITY_PEDESTRIANS_LATE


static func traffic_cars(hour: float) -> int:
	return TRAFFIC_NIGHT if is_night(hour) else TRAFFIC_DAY


## Multiplicador do intervalo entre crimes (só a cidade fica mais agitada à noite).
static func crime_interval_factor(hour: float, region: String) -> float:
	return NIGHT_CRIME_INTERVAL_FACTOR if region == "Cidade" and is_night(hour) else 1.0
