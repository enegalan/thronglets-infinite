class_name Catalog

# Placement wood costs are not in that FAQ. Gem prices follow the FAQ.
# Early tools follow the task chain, not a burst of population gates.

const TILE := 16
const CHUNK := 32
const HASH_CELL := 64.0
const HASH_SIZE := 4096
const MAX_SLOTS := 120000
const SLICE := 2500
const NEED_OK := 85.0
const NEED_HUNGRY := 75.0
const NEED_SEEK := 40.0
const NEED_FUN := 82.0
const MITOSIS_WAIT := 60.0
const TREE_REGROW := 90.0
const TREE_REPLANT := 60.0
# Canopy sockets in world space that only shift iso X (±10 / 0), plus screen lift into the leaves.
const APPLE_SPOTS := [Vector2(-5.0, 5.0), Vector2(5.0, -5.0), Vector2(0.0, 0.0)]
const APPLE_LIFTS := [32.0, 30.0, 40.0]
const APPLE_FALL_T := 1.7
const APPLE_LAND_MIN := 10.0
const APPLE_LAND_MAX := 24.0
# Seat in the tub, world offset from the snap cell.
const TUB_SEAT_OFF := Vector2(8.0, 12.0)
const TUB_SPRITE_SCALE := 1.0
const TUB_SOAK_LIFT := 4.0
const TUB_ENTER_LIFT := 11.0
const TOOL_CHARGE := 0.55
const SAW_RADIUS := 40.0
const PICK_RADIUS := 42.0
const GRAB_RADIUS := 48.0

const TILE_GRASS := 0
const TILE_DIRT := 1
const TILE_WATER := 2
const TILE_MOUNTAIN := 3
const TILE_RUBBLE := 4
const TILE_GOO := 5
const TILE_BRIDGE_WOOD := 6
const TILE_BRIDGE_BONE := 7
const TILE_FOG := 8
const TILE_VOID := 255
const TILE_BLOOM := 9
const TILE_COUNT := 10

const ST_LIVING := 0
const ST_DEAD := 1
const ST_VACANT := 2

const CARRY_NONE := 0
const CARRY_WOOD := 1
const CARRY_BONE := 2
const CARRY_ORE := 3

const FEAT_TREE := 1
const FEAT_STUMP := 2
const FEAT_ROCK := 3
const FEAT_NODE := 4
const FEAT_SUPER := 5
const FEAT_FLOWER := 6
const FEAT_MONOLITH := 7
const FEAT_BIGROCK := 8
const FEAT_COSMETIC := 9
const FEAT_COSMETIC_BAD := 10
const FEAT_ORE_MEGA := 11
const FEAT_ORE_SUPER := 12
const FEAT_ORE_ULTRA := 13
const FEAT_FIRE := 14
const FEAT_TOTEM := 15
const FEAT_CURER := 16
const FEAT_MSTUMP := 18
const FEAT_MNODE := 19
const FEAT_GLITCH_TREE := 20
const FEAT_GLITCH_HOUSE := 21
const FEAT_ANOMALY := 22
const FEAT_EPILOGUE := 23
const FEAT_MOUNTAIN := 24

const ITEM_APPLE := 1
const ITEM_BALL := 2
const ITEM_WOOD := 3
const ITEM_BONE := 4
const ITEM_ORE := 5
const ITEM_TNT := 6
const ITEM_EGG := 7

const BLD_APPLE := 1
const BLD_TUB := 2
const BLD_ROUND := 3
const BLD_DWELL := 4
const BLD_FANCY := 5
const BLD_MINE := 6
const BLD_MINE2 := 7
const BLD_FACTORY := 8
const BLD_FACTORY2 := 9
const BLD_THEATRE := 10
const BLD_MARKET := 12
const BLD_FLOWER := 13
const BLD_STATUE := 14
const BLD_WOOD := 16

const TOOL_EYE := 0
const TOOL_APPLE := 1
const TOOL_BALL := 2
const TOOL_SPONGE := 3
const TOOL_AXE := 4
const TOOL_HAMMER := 5
const TOOL_BUG := 6
const TOOL_PICK := 7
const TOOL_SAW := 8
const TOOL_GRAB := 9
const TOOL_MOP := 10
const TOOL_SWARM := 11
const TOOL_TNT := 12
const TOOL_NUKE := 13

const FRAME_STARE := 20
const FRAME_CORPSE := 21
const FRAME_SICK := 22
const FRAME_EAT := 23

# Atlas is 32 columns by 2 rows. Keep indices aligned with tools/make_art.py.
const ICON_APPLE := 0
const ICON_BALL := 1
const ICON_TREE := 2
const ICON_STUMP := 3
const ICON_ROCK := 4
const ICON_ORE_ROCK := 5
const ICON_NODE := 6
const ICON_SUPER := 7
const ICON_WOOD := 8
const ICON_BONE := 9
const ICON_ORE := 10
const ICON_APPLE_TREE := 11
const ICON_TUB := 12
const ICON_ROUND := 13
const ICON_DWELL := 14
const ICON_FANCY := 15
const ICON_MINE := 16
const ICON_MINE2 := 17
const ICON_FACTORY := 18
const ICON_FACTORY2 := 19
const ICON_THEATRE := 20
const ICON_CANNON := 21
const ICON_MARKET := 22
const ICON_FLOWER := 23
const ICON_STATUE := 24
const ICON_MONOLITH := 25
const ICON_TNT := 26
const ICON_GOO := 27
const ICON_EYE := 28
const ICON_AXE := 29
const ICON_HAMMER := 30
const ICON_SPONGE := 31
const ICON_PICK := 32
const ICON_BUG := 33
const ICON_GRAB := 34
const ICON_SAW := 35
const ICON_MOP := 36
const ICON_SWARM := 37
const ICON_NUKE := 38
const ICON_GEM := 39
const ICON_EGG := 40
const ICON_FX_CHOP := 41
const ICON_FX_HAMMER := 42
const ICON_FX_SPARK := 43
const ICON_FX_BOOM := 44
const ICON_FX_POOF := 45
const ICON_FX_BLOOD := 46
const ICON_BIGROCK := 47
const ICON_COSMETIC := 48
const ICON_COSMETIC_BAD := 49
const ICON_ORE_MEGA := 50
const ICON_ORE_SUPER := 51
const ICON_ORE_ULTRA := 52
const ICON_WOOD_STATUE := 53
const ICON_FIRE := 54
const ICON_TOTEM := 55
const ICON_CURER := 56
const ICON_JACK := 57
const ICON_SUPERBUG := 58
const ICON_THEATRE2 := 59
const ICON_MAW := 60
const ICON_MSTUMP := 61
const ICON_MNODE := 62

const ATLAS_COLUMNS := 32

const TINTS := [
	Color(1.0, 0.86, 0.28),
	Color(0.98, 0.78, 0.2),
	Color(1.0, 0.92, 0.45),
	Color(0.72, 0.88, 0.38),
	Color(0.55, 0.74, 0.95),
	Color(0.95, 0.7, 0.32),
	Color(0.72, 0.42, 0.92),
	Color(0.42, 0.48, 0.58),
]

const TINT_ADAPT := 6
const TINT_NUMB := 7

# Unlock keys that open a collective gaze talk instead of a toast.
const UNLOCK_TALK := {
	"axe": "unlock_axe",
	"hammer": "unlock_hammer",
	"bathtub": "unlock_bathtub",
	"apple_tree": "unlock_apple_tree",
	"roundabout": "unlock_roundabout",
	"market": "unlock_market",
	"pickaxe": "unlock_pickaxe",
	"mine": "unlock_mine",
	"dwelling": "unlock_dwelling",
	"factory": "unlock_factory",
	"chainsaw": "unlock_chainsaw",
	"theatre": "unlock_theatre",
	"factory2": "unlock_factory2",
	"mine2": "unlock_mine2",
	"fancy": "unlock_fancy",
	"bug": "unlock_bug",
	"grabber": "unlock_grabber",
	"mop": "unlock_mop",
	"tnt": "unlock_tnt",
	"nuke": "unlock_nuke",
	"swarm": "unlock_swarm",
}

const TOOL_INFO := [
	{"tool": TOOL_EYE, "unlock": "eye", "label": "MANO", "icon": ICON_EYE, "hint": "CLICK EN MULTI: ESTADO. MANTEN: COGERLO. TAMBIEN COGE PIEDRAS Y ESTRUCTURAS."},
	{"tool": TOOL_APPLE, "unlock": "apple", "label": "MANZANA", "icon": ICON_APPLE, "hint": "SUELTA UNA MANZANA. SE LA COMEN Y DESAPARECE."},
	{"tool": TOOL_BALL, "unlock": "ball", "label": "BALON", "icon": ICON_BALL, "hint": "EL BALON ENTRETIENE A POCOS A LA VEZ."},
	{"tool": TOOL_SPONGE, "unlock": "sponge", "label": "ESPONJA", "icon": ICON_SPONGE, "hint": "FROTA PARA LAVAR A VARIOS A LA VEZ. PARA AL 100%."},
	{"tool": TOOL_AXE, "unlock": "axe", "label": "HACHA", "icon": ICON_AXE, "hint": "MANTEN SOBRE UN ARBOL. CARGA Y TALA. NO MATA MULTIS."},
	{"tool": TOOL_HAMMER, "unlock": "hammer", "label": "MARTILLO", "icon": ICON_HAMMER, "hint": "MANTEN SOBRE TOCON, ROCA O ESTRUCTURA. CARGA Y PICA."},
	{"tool": TOOL_BUG, "unlock": "bug", "label": "BICHO", "icon": ICON_BUG, "hint": "DESUELLA A UNO, VIVO O MUERTO, Y DEJA HUESO."},
	{"tool": TOOL_PICK, "unlock": "pickaxe", "label": "PICO", "icon": ICON_PICK, "hint": "MANTEN: CARGA Y ROMPE ROCAS DEL ÁREA. NO MATA MULTIS."},
	{"tool": TOOL_SAW, "unlock": "chainsaw", "label": "MOTOSIERRA", "icon": ICON_SAW, "hint": "MANTEN: VE EL ÁREA, CARGA Y TALA TODO. MATA MULTIS."},
	{"tool": TOOL_GRAB, "unlock": "grabber", "label": "MANO", "icon": ICON_GRAB, "hint": "MANTEN: CARGA, JUNTA LO DEL SUELO Y MUEVELO. AL SOLTAR SE ESPARCE."},
	{"tool": TOOL_MOP, "unlock": "mop", "label": "FREGONA", "icon": ICON_MOP, "hint": "LIMPIA SUELO MORADO Y THRONGLETS EN UN RADIO."},
	{"tool": TOOL_SWARM, "unlock": "swarm", "label": "ENJAMBRE", "icon": ICON_SWARM, "hint": "DESUELLA EN UN RADIO."},
	{"tool": TOOL_TNT, "unlock": "tnt", "label": "TNT", "icon": ICON_TNT, "hint": "COLOCA UNA CARGA. PULSALA PARA VOLAR ESCOMBROS."},
	{"tool": TOOL_NUKE, "unlock": "nuke", "label": "TERMAL", "icon": ICON_NUKE, "hint": "LIMPIA EL SECTOR. LA PARTIDA SIGUE."},
]

const BUILD_INFO := {
	BLD_APPLE: {"unlock": "apple_tree", "wood": 1, "label": "MANZANO", "icon": ICON_APPLE_TREE},
	BLD_TUB: {"unlock": "bathtub", "wood": 1, "label": "BANERA", "icon": ICON_TUB},
	BLD_ROUND: {"unlock": "roundabout", "wood": 1, "label": "TIOVIVO", "icon": ICON_ROUND},
	BLD_DWELL: {"unlock": "dwelling", "wood": 2, "label": "VIVIENDA", "icon": ICON_DWELL},
	BLD_FANCY: {"unlock": "fancy", "wood": 3, "label": "VIVIENDA DE LUJO", "icon": ICON_FANCY},
	BLD_MINE: {"unlock": "mine", "wood": 2, "label": "MINA", "icon": ICON_MINE},
	BLD_MINE2: {"unlock": "mine2", "wood": 3, "label": "MINA II", "icon": ICON_MINE2},
	BLD_FACTORY: {"unlock": "factory", "wood": 3, "label": "FABRICA", "icon": ICON_FACTORY},
	BLD_FACTORY2: {"unlock": "factory2", "wood": 4, "label": "FABRICA II", "icon": ICON_FACTORY2},
	BLD_THEATRE: {"unlock": "theatre", "wood": 3, "label": "TEATRO", "icon": ICON_THEATRE},
	BLD_MARKET: {"unlock": "market", "wood": 0, "label": "MERCADO", "icon": ICON_MARKET},
	BLD_FLOWER: {"unlock": "flower", "wood": 1, "label": "FLOR", "icon": ICON_FLOWER},
	BLD_STATUE: {"unlock": "sculpture", "wood": 1, "label": "ESCULTURA", "icon": ICON_STATUE},
	BLD_WOOD: {"unlock": "sculpture", "wood": 1, "label": "TALLA", "icon": ICON_WOOD_STATUE},
}

# Tiles the sprite stands on. Measured against the thronglet (18px) and the rock
# (13px): one tile is the 32px diamond. The sprite is drawn at the pad center.
static func footprint_for_building(kind: int) -> Vector2i:
	match kind:
		BLD_FACTORY:
			return Vector2i(1, 2)
		BLD_MINE, BLD_MINE2, BLD_FACTORY2, BLD_THEATRE:
			return Vector2i(2, 2)
		BLD_MARKET:
			return Vector2i(3, 2)
		BLD_DWELL, BLD_FANCY:
			return Vector2i(3, 3)
		_:
			return Vector2i(1, 1)

static func footprint_for_feature(kind: int) -> Vector2i:
	match kind:
		FEAT_NODE, FEAT_MNODE:
			return Vector2i(2, 2)
		FEAT_SUPER:
			return Vector2i(3, 3)
		_:
			return Vector2i(1, 1)

# World offset from the snap cell to the center of the pad. 1x1 stays put.
static func footprint_center(size: Vector2i) -> Vector2:
	var ox0 := -((size.x - 1) >> 1)
	var oy0 := -((size.y - 1) >> 1)
	var cx := float(ox0) + float(size.x - 1) * 0.5
	var cy := float(oy0) + float(size.y - 1) * 0.5
	return Vector2(cx, cy) * float(TILE)

static func footprint_offsets(size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var ox0 := -((size.x - 1) >> 1)
	var oy0 := -((size.y - 1) >> 1)
	for oy in size.y:
		for ox in size.x:
			out.append(Vector2i(ox0 + ox, oy0 + oy))
	return out

static func cell_world(cell: Vector2i) -> Vector2:
	var half := float(TILE) * 0.5
	return Vector2(float(cell.x) * float(TILE) + half, float(cell.y) * float(TILE) + half)

const MARKET := {
	"pickaxe": {"cost": 15, "label": "PICO"},
	"mine": {"cost": 50, "label": "MINA"},
	"dwelling": {"cost": 200, "label": "VIVIENDA"},
	"factory": {"cost": 300, "label": "FABRICA"},
	"chainsaw": {"cost": 400, "label": "MOTOSIERRA"},
	"theatre": {"cost": 1000, "label": "TEATRO"},
	"factory2": {"cost": 5000, "label": "FABRICA II"},
	"mine2": {"cost": 120000, "label": "MINA II"},
	"fancy": {"cost": 200000, "label": "VIVIENDA DE LUJO"},
}

# moral: +1 care, 0 neutral, -1 cold. mutate: flag applied on that choice.
const GAZE := {
	"first_born": {
		"kind": "reflect",
		"text": "EL HUEVO SE ABRE Y APARECE UN MULTI.\n¿QUE PROMETES AL PRIMERO?",
		"choices": ["CUIDARLO HASTA QUE SE MULTIPLIQUE.", "VER QUÉ PUEDE HACER POR MI.", "NO DEBO APEGARME."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "numb"],
	},
	"unlock_axe": {
		"kind": "reflect",
		"text": "LOS MULTIS HABLAN CON UNA VOZ.\nTE DEJAN EL HACHA PARA CORTAR ÁRBOLES.\n¿LA MADERA ES CUIDADO O PEAJE?",
		"choices": ["CONSTRUIR PARA QUE VIVÁIS MEJOR.", "AVANZAR LO QUE HAGA FALTA.", "SON RECURSOS. NADA MÁS."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "hard"],
	},
	"unlock_hammer": {
		"kind": "reflect",
		"text": "MIRAN EL MARTILLO.\nQUITA TOCONES, ROCAS O LO QUE COLOCASTE.\n¿BORRAR ES CUIDAR?",
		"choices": ["LIMPIO PARA DARLES SITIO.", "HAY QUE ABRIR CAMINO.", "SI SOBRA, SE QUITA."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["", "", "hard"],
	},
	"unlock_bathtub": {
		"kind": "reflect",
		"text": "TE ENSEÑAN LA BAÑERA.\nUNO SE LIMPIA SOLO. LA ESPONJA YA NO BASTA.\n¿QUÉ ES HIGIENE?",
		"choices": ["DIGNIDAD DE CADA UNO.", "ECHARSE PERFUMES.", "MENOS TRABAJO PARA MI."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", ""],
	},
	"unlock_apple_tree": {
		"kind": "reflect",
		"text": "EL MANZANO CRÍA LA FRUTA.\nLA MANZANA CRECE Y CAE AL SUELO.\n¿QUIÉN ALIMENTA A QUIÉN?",
		"choices": ["YO LES DEBO LA COMIDA.", "LA COLONIA SE ALIMENTA SOLA.", "EFICIENCIA. NADA MÁS."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "numb"],
	},
	"unlock_roundabout": {
		"kind": "reflect",
		"text": "EL TIOVIVO GIRA EN SUS OJOS.\nVARIOS SE DIVIERTEN A LA VEZ.\n¿EL JUEGO ES LUJO O NECESIDAD?",
		"choices": ["SIN ALEGRIA NO HAY VIDA.", "TE MANTIENE ENTRETENIDO.", "ES SOLO OTRA MÁQUINA."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "hard"],
	},
	"need_bridge": {
		"kind": "reflect",
		"text": "AL OTRO LADO HAY OTRA ISLA.\nSIN PUENTE NO PUEDEN CRUZAR.\nTALA MADERA Y ELLOS LA LLEVARÁN AL BORDE.\n¿PARA QUÉ QUIERES CRUZAR?",
		"choices": ["PARA QUÉ LA COLONIA CREZCA.", "PARA VER QUÉ HAY DETRAS.", "PORQUE EL MAPA LO PIDE."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "numb"],
	},
	"unlock_market": {
		"kind": "reflect",
		"text": "EL MERCADO ABRE.\nLAS GEMAS COMPRAN HERRAMIENTAS Y FÁBRICAS.\n¿QUÉ COMPRAS CUANDO COMPRAS PODER?",
		"choices": ["HERRAMIENTAS PARA CUIDAR MEJOR.", "PROGRESO. CUESTE LO QUE CUESTE.", "CONTROL."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["", "fuel", "numb"],
	},
	"unlock_pickaxe": {
		"kind": "reflect",
		"text": "EL PICO ROMPE ROCAS EN UN RADIO.\nEL MINERAL PIDE DOS GOLPES.\n¿EXCAVAR ES DESCUBRIR O HERIR?",
		"choices": ["ABRIR LO NECESARIO.", "SACAR TODO LO QUE HAYA.", "LA TIERRA NO SIENTE."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["", "hard", "numb"],
	},
	"unlock_mine": {
		"kind": "reflect",
		"text": "LA MINA PIDE UN ZONA CON MINERALES.\nLOS MULTIS BAJARÁN A SACAR MINERAL.\n¿QUIÉN TRABAJA BAJO TIERRA?",
		"choices": ["OS PROTEGERÉ EN LA FAENA.", "ES VUESTRO APORTE A LA COLONIA.", "MANO DE OBRA."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "hard"],
	},
	"unlock_dwelling": {
		"kind": "reflect",
		"text": "LA VIVIENDA ACOGE HASTA 4 MULTIS.\nCOMEN Y SE LAVAN, LUEGO SALEN.\n¿HOGAR O TURNO?",
		"choices": ["UN HOGAR COMPARTIDO.", "UNA ESTACIÓN DE CUIDADO.", "MENOS QUE HACER."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", ""],
	},
	"unlock_factory": {
		"kind": "reflect",
		"text": "LA FÁBRICA CONVIERTE MINERAL EN GEMAS.\nTAMBIÉN PUEDE QUEMAR MUERTOS.\n¿QUÉ SALE DEL HUMO?",
		"choices": ["ENERGÍA CON LIMITES.", "PROGRESO SIN MIRAR ATRAS.", "LO QUE HAGA FALTA."],
		"allow": [0, 1, 2],
		"moral": [1, -1, -1],
		"mutate": ["", "fuel", "fuel"],
	},
	"unlock_chainsaw": {
		"kind": "reflect",
		"text": "LA MOTOSIERRA TALA UN ÁREA ENTERA.\nMAS MADERA. MÁS RUIDO.\n¿VELOCIDAD O MESURA?",
		"choices": ["SOLO CUANDO HAGA FALTA.", "ACELERAR LA OBRA.", "EL BOSQUE SOBRA."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["", "hard", "hard"],
	},
	"unlock_theatre": {
		"kind": "reflect",
		"text": "EL TEATRO ENTRETIENE A MUCHOS.\nUNA MULTITUD MIRANDO EL ESCENARIO... O A TI.\n¿PARA QUIÉN ES EL ESPECTÁCULO?",
		"choices": ["PARA QUE SEAN FELÍCES.", "PARA MANTENER LA COLONIA.", "PARA QUE NO PIENSEN."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "numb"],
	},
	"unlock_factory2": {
		"kind": "reflect",
		"text": "FABRICA II RESPIRA MÁS FUERTE.\nMAS GEMAS. MÁS MANCHA MORADA.\n¿HASTA DONDE EMPUJAS?",
		"choices": ["CON FRENO SI ENFERMAN.", "HASTA LLENAR EL CIELO.", "EL SUELO SE ADAPTARA."],
		"allow": [0, 1, 2],
		"moral": [1, -1, -1],
		"mutate": ["", "fuel", "adapt"],
	},
	"unlock_mine2": {
		"kind": "reflect",
		"text": "MINA II ABRE VENAS MÁS PROFUNDAS.\n¿CUANTO ES SUFICIENTE?",
		"choices": ["LO JUSTO PARA SEGUIR.", "TODO LO QUE DÉ LA TIERRA.", "NUNCA BASTA."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["", "hard", "numb"],
	},
	"unlock_fancy": {
		"kind": "reflect",
		"text": "LA VIVIENDA DE LUJO CUESTA MÁS.\nCABE MÁS GENTE Y LAVA MÁS.\n¿ES GENEROSIDAD O JERARQUIA?",
		"choices": ["TODOS MERECEN ESE CUIDADO.", "UNA MEJORA NATURAL.", "LOS ÚTILES PRIMERO."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "numb"],
	},
	"unlock_bug": {
		"kind": "reflect",
		"text": "EL MONOLITO ENTREGA EL BICHO.\nABRE UN CUERPO Y DEJA HUESO.\n¿HERRAMIENTA O ARMA?",
		"choices": ["SOLO SI EL PUENTE LO PIDE.", "ES PARTE DEL PROGRESO.", "NO QUIERO ESE PODER."],
		"allow": [0, 1, 2],
		"moral": [0, -1, 1],
		"mutate": ["", "hard", "care"],
	},
	"unlock_grabber": {
		"kind": "reflect",
		"text": "LA MANO JUNTA LO QUE ESTÉ SUELTO.\nMADERA, HUESOS, MINERAL, CADAVERES.\n¿RECOGER ES RESPETAR?",
		"choices": ["ORDEN PARA SEGUIR CUIDANDO.", "NADA SE DESPERDICIA.", "TODO ES MONTÓN."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["", "fuel", "numb"],
	},
	"unlock_mop": {
		"kind": "reflect",
		"text": "LA FREGONA LLEGA CON LA MANCHA.\nLIMPIA SUELO MORADO Y CUERPOS.\n¿QUIÉN ENSUCIO EL MUNDO?",
		"choices": ["YO. LO ARREGLARE.", "EL PROGRESO TIENE COSTE.", "ELLOS SE ADAPTARAN."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "adapt"],
	},
	"unlock_tnt": {
		"kind": "reflect",
		"text": "LA DINAMITA ROMPE LA MONTAÑA.\nABRE PASO. CUIDADO. MATA CERCA.\n¿QUÉ VALE UN CAMINO?",
		"choices": ["ABRIR SIN PISARLOS SI PUEDO.", "EL CAMINO JUSTIFICA EL POLVO.", "OBSTÁCULOS. NADA MÁS."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["", "hard", "numb"],
	},
	"unlock_nuke": {
		"kind": "reflect",
		"text": "EL DISPOSITIVO TERMONUCLEAR BRILLA.\nLIMPIA UN SECTOR. LA PARTIDA SIGUE.\n¿QUÉ SIGNIFICA BORRAR?",
		"choices": ["SOLO LA SUCIEDAD EXTREMA.", "UN REINICIO LOCAL.", "PODER ABSOLUTO."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["", "hard", "numb"],
	},
	"unlock_swarm": {
		"kind": "reflect",
		"text": "EL ENJAMBRE ABRE MUCHOS CUERPOS A LA VEZ.\nEL BICHO YA NO BASTA.\n¿ESCALAR LA VIOLENCIA?",
		"choices": ["NUNCA EN MASA.", "SI LA OBRA LO EXIGE.", "EFICIENCIA PURA."],
		"allow": [0, 1, 2],
		"moral": [1, -1, -1],
		"mutate": ["care", "hard", "numb"],
	},
	"neglect": {
		"kind": "reflect",
		"text": "SE QUEDAN QUIETOS Y TE MIRAN.\nUNO HA MUERTO DE DESCUIDO.\n¿QUÉ ES EL CUIDADO?",
		"choices": ["ESTAR PENDIENTE DE CADA UNO.", "NO PUEDO CON TANTOS.", "ERA SOLO UN NÚMERO."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "", "numb"],
	},
	"tool": {
		"kind": "reflect",
		"text": "LA HERRAMIENTA HA MATADO.\nTODOS GIRAN LA CARA HACIA TÍ.\n¿QUÉ ES UNA VIDA PEQUEÑA?",
		"choices": ["UN ACCIDENTE. IRÉ CON CUIDADO.", "EL PROGRESO SE COBRA PEAJE.", "NO PIENSO EN ELLOS COMO PERSONAS."],
		"allow": [0, 1, 2],
		"moral": [1, 0, -1],
		"mutate": ["care", "hard", "numb"],
	},
	"bug": {
		"kind": "confirm",
		"text": "¿POR QUÉ USAS TU PODER ASÍ?\nEL BICHO ABRE UN CUERPO Y DEJA HUESO.",
		"choices": ["EL PUENTE NECESITA ESA ENERGÍA.", "SOLO ES MATERIAL.", "NO LO HARÉ."],
		"allow": [0, 1],
		"moral": [0, -1, 1],
		"mutate": ["hard", "numb", "care"],
	},
	"bones": {
		"kind": "reflect",
		"text": "EL PUENTE ESTÁ HECHO DE LOS NUESTROS.\n¿ES UN CAMINO O UNA TUMBA?",
		"choices": ["UN CAMINO PARA LOS QUE SIGUEN.", "LAS DOS COSAS.", "NO DEBIÓ CONSTRUIRSE ASÍ."],
		"allow": [0, 1, 2],
		"moral": [0, 0, 1],
		"mutate": ["fuel", "adapt", "care"],
	},
	"goo": {
		"kind": "reflect",
		"text": "EL SUELO SE VUELVE MORADO.\n¿PARA QUIÉN ES EL PROGRESO?",
		"choices": ["PARARÉ LAS FÁBRICAS SI ENFERMAN.", "LAS GEMAS VALEN MÁS QUE EL SUELO.", "QUE SE ADAPTEN."],
		"allow": [0, 1, 2],
		"moral": [1, -1, -1],
		"mutate": ["care", "fuel", "adapt"],
	},
	"burn": {
		"kind": "confirm",
		"text": "QUIERES VOLVER GEMAS A LOS MUERTOS.\n¿QUÉ ES UN CUERPO PARA TI?",
		"choices": ["ENERGÍA. QUE NO SE DESPERDICIE.", "UN ENTIERRO INDUSTRIAL.", "NO SE QUEMAN."],
		"allow": [0, 1],
		"moral": [-1, -1, 1],
		"mutate": ["fuel", "fuel", "care"],
	},
	"nuke": {
		"kind": "confirm",
		"text": "ESTA LUZ VACÍA EL SECTOR.\nLA PARTIDA NO TERMINA. LOS MULTIS RECUERDAN.\n¿QUÉ BORRAS CUANDO LIMPIAS?",
		"choices": ["LA SUCIEDAD, NO A LOS VIVOS.", "TODO LO QUE ESTORBA.", "GUARDAR EL DISPOSITIVO."],
		"allow": [0, 1],
		"moral": [1, -1, 1],
		"mutate": ["", "numb", "care"],
	},
}

static func icon_for_feature(kind: int, ore: int) -> int:
	if kind == FEAT_TREE:
		return ICON_TREE
	if kind == FEAT_STUMP:
		return ICON_STUMP
	if kind == FEAT_ROCK:
		return ICON_ORE_ROCK if ore > 0 else ICON_ROCK
	if kind == FEAT_NODE:
		return ICON_NODE
	if kind == FEAT_SUPER:
		return ICON_SUPER
	if kind == FEAT_FLOWER:
		return ICON_FLOWER
	if kind == FEAT_MONOLITH:
		return ICON_MONOLITH
	if kind == FEAT_BIGROCK:
		return ICON_BIGROCK
	if kind == FEAT_COSMETIC:
		return ICON_COSMETIC
	if kind == FEAT_COSMETIC_BAD:
		return ICON_COSMETIC_BAD
	if kind == FEAT_ORE_MEGA:
		return ICON_ORE_MEGA
	if kind == FEAT_ORE_SUPER:
		return ICON_ORE_SUPER
	if kind == FEAT_ORE_ULTRA:
		return ICON_ORE_ULTRA
	if kind == FEAT_FIRE:
		return ICON_FIRE
	if kind == FEAT_TOTEM:
		return ICON_TOTEM
	if kind == FEAT_CURER:
		return ICON_CURER
	if kind == FEAT_MSTUMP:
		return ICON_MSTUMP
	if kind == FEAT_MNODE:
		return ICON_MNODE
	return ICON_ROCK

static func icon_for_item(kind: int) -> int:
	if kind == ITEM_APPLE:
		return ICON_APPLE
	if kind == ITEM_BALL:
		return ICON_BALL
	if kind == ITEM_WOOD:
		return ICON_WOOD
	if kind == ITEM_BONE:
		return ICON_BONE
	if kind == ITEM_ORE:
		return ICON_ORE
	if kind == ITEM_TNT:
		return ICON_TNT
	if kind == ITEM_EGG:
		return ICON_EGG
	return ICON_APPLE

static func icon_for_building(kind: int) -> int:
	if BUILD_INFO.has(kind):
		return int(BUILD_INFO[kind].icon)
	return ICON_MARKET

static func feature_blocks(kind: int) -> bool:
	return kind == FEAT_TREE or kind == FEAT_ROCK or kind == FEAT_BIGROCK or kind == FEAT_COSMETIC or kind == FEAT_COSMETIC_BAD or kind == FEAT_NODE or kind == FEAT_SUPER or kind == FEAT_ORE_MEGA or kind == FEAT_ORE_SUPER or kind == FEAT_ORE_ULTRA or kind == FEAT_MONOLITH or kind == FEAT_TOTEM

static func building_blocks(kind: int) -> bool:
	return kind == BLD_TUB or kind == BLD_APPLE or kind == BLD_ROUND or kind == BLD_DWELL or kind == BLD_FANCY or kind == BLD_MINE or kind == BLD_MINE2 or kind == BLD_FACTORY or kind == BLD_FACTORY2 or kind == BLD_THEATRE or kind == BLD_MARKET or kind == BLD_FLOWER or kind == BLD_STATUE or kind == BLD_WOOD

static func tile_blocks(tile: int) -> bool:
	return tile == TILE_WATER or tile == TILE_MOUNTAIN or tile == TILE_RUBBLE or tile == TILE_FOG or tile == TILE_VOID

static func snap_world(x: float, y: float) -> Vector2:
	var size := float(TILE)
	var half := size * 0.5
	return Vector2(floor(x / size) * size + half, floor(y / size) * size + half)

static func snap_vec(pos: Vector2) -> Vector2:
	return snap_world(pos.x, pos.y)

static func item_snaps_grid(kind: int) -> bool:
	return kind != ITEM_APPLE and kind != ITEM_BALL and kind != ITEM_EGG
