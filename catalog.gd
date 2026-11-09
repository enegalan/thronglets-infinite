class_name Catalog

# Published Netflix / Black Mirror: Thronglets rules live in the FAQ.
# Placement wood costs are not in that FAQ. Gem prices and population gates are.

const TILE := 16
const CHUNK := 32
const HASH_CELL := 64.0
const HASH_SIZE := 4096
const MAX_SLOTS := 120000
const SLICE := 2500
const NEED_OK := 85.0
const MITOSIS_WAIT := 10.0

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

const ITEM_APPLE := 1
const ITEM_BALL := 2
const ITEM_WOOD := 3
const ITEM_BONE := 4
const ITEM_ORE := 5
const ITEM_TNT := 6

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
const BLD_CANNON := 11
const BLD_MARKET := 12
const BLD_FLOWER := 13
const BLD_STATUE := 14

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

const ATLAS_COLUMNS := 32

const TINTS := [
    Color(1.0, 0.86, 0.28),
    Color(0.98, 0.78, 0.2),
    Color(1.0, 0.92, 0.45),
    Color(0.72, 0.88, 0.38),
    Color(0.55, 0.74, 0.95),
    Color(0.95, 0.7, 0.32),
]

const TOOL_INFO := [
    {"tool": TOOL_EYE, "unlock": "eye", "label": "MANO", "icon": ICON_EYE, "hint": "COGE Y SUELTA MULTIS, PIEDRAS Y ESTRUCTURAS."},
    {"tool": TOOL_APPLE, "unlock": "apple", "label": "MANZANA", "icon": ICON_APPLE, "hint": "SUELTA UNA MANZANA. SE LA COMEN Y DESAPARECE."},
    {"tool": TOOL_BALL, "unlock": "ball", "label": "BALON", "icon": ICON_BALL, "hint": "EL BALON ENTRETIENE A POCOS A LA VEZ."},
    {"tool": TOOL_SPONGE, "unlock": "sponge", "label": "ESPONJA", "icon": ICON_SPONGE, "hint": "MANTEN LA ESPONJA Y FROTA PARA LAVAR."},
    {"tool": TOOL_AXE, "unlock": "axe", "label": "HACHA", "icon": ICON_AXE, "hint": "TALA UN ARBOL Y DEJA UN TOCON."},
    {"tool": TOOL_HAMMER, "unlock": "hammer", "label": "MARTILLO", "icon": ICON_HAMMER, "hint": "QUITA TOCONES, ROCAS Y LO QUE COLOCAS."},
    {"tool": TOOL_BUG, "unlock": "bug", "label": "BICHO", "icon": ICON_BUG, "hint": "DESUELLA A UNO, VIVO O MUERTO, Y DEJA HUESO."},
    {"tool": TOOL_PICK, "unlock": "pickaxe", "label": "PICO", "icon": ICON_PICK, "hint": "ROMPE ROCAS EN UN RADIO. EL MINERAL PIDE DOS GOLPES."},
    {"tool": TOOL_SAW, "unlock": "chainsaw", "label": "MOTOSIERRA", "icon": ICON_SAW, "hint": "TALA LOS ARBOLES DE UN AREA."},
    {"tool": TOOL_GRAB, "unlock": "grabber", "label": "GARRA", "icon": ICON_GRAB, "hint": "JUNTA MADERA, HUESOS, MINERAL Y CADAVERES."},
    {"tool": TOOL_MOP, "unlock": "mop", "label": "FREGONA", "icon": ICON_MOP, "hint": "LIMPIA SUELO MORADO Y THRONGLETS EN UN RADIO."},
    {"tool": TOOL_SWARM, "unlock": "swarm", "label": "ENJAMBRE", "icon": ICON_SWARM, "hint": "DESUELLA EN UN RADIO."},
    {"tool": TOOL_TNT, "unlock": "tnt", "label": "TNT", "icon": ICON_TNT, "hint": "COLOCA UNA CARGA. PULSALA PARA VOLAR ESCOMBROS."},
    {"tool": TOOL_NUKE, "unlock": "nuke", "label": "TERMAL", "icon": ICON_NUKE, "hint": "LIMPIA EL SECTOR. LA PARTIDA SIGUE."},
]

const BUILD_INFO := {
    BLD_APPLE: {"unlock": "apple_tree", "wood": 2, "label": "MANZANO", "icon": ICON_APPLE_TREE},
    BLD_TUB: {"unlock": "bathtub", "wood": 2, "label": "BANERA", "icon": ICON_TUB},
    BLD_ROUND: {"unlock": "roundabout", "wood": 3, "label": "TIOVIVO", "icon": ICON_ROUND},
    BLD_DWELL: {"unlock": "dwelling", "wood": 4, "label": "VIVIENDA", "icon": ICON_DWELL},
    BLD_FANCY: {"unlock": "fancy", "wood": 6, "label": "LUJO", "icon": ICON_FANCY},
    BLD_MINE: {"unlock": "mine", "wood": 4, "label": "MINA", "icon": ICON_MINE},
    BLD_MINE2: {"unlock": "mine2", "wood": 6, "label": "MINA II", "icon": ICON_MINE2},
    BLD_FACTORY: {"unlock": "factory", "wood": 6, "label": "FABRICA", "icon": ICON_FACTORY},
    BLD_FACTORY2: {"unlock": "factory2", "wood": 8, "label": "FABRICA II", "icon": ICON_FACTORY2},
    BLD_THEATRE: {"unlock": "theatre", "wood": 6, "label": "TEATRO", "icon": ICON_THEATRE},
    BLD_CANNON: {"unlock": "cannon", "wood": 8, "label": "CANON", "icon": ICON_CANNON},
    BLD_MARKET: {"unlock": "market", "wood": 4, "label": "MERCADO", "icon": ICON_MARKET},
    BLD_FLOWER: {"unlock": "flower", "wood": 1, "label": "FLOR", "icon": ICON_FLOWER},
    BLD_STATUE: {"unlock": "sculpture", "wood": 2, "label": "ESCULTURA", "icon": ICON_STATUE},
}

# Official market gem prices from the Netflix help center.
const MARKET := {
    "pickaxe": {"cost": 15, "label": "PICO"},
    "mine": {"cost": 50, "label": "MINA"},
    "dwelling": {"cost": 200, "label": "VIVIENDA"},
    "factory": {"cost": 300, "label": "FABRICA"},
    "chainsaw": {"cost": 400, "label": "MOTOSIERRA"},
    "theatre": {"cost": 1000, "label": "TEATRO"},
    "factory2": {"cost": 5000, "label": "FABRICA II"},
    "mine2": {"cost": 120000, "label": "MINA II"},
    "fancy": {"cost": 200000, "label": "VIVIENDA LUJOSA"},
}

const GAZE := {
    "neglect": {
        "kind": "reflect",
        "text": "SE QUEDAN QUIETOS Y TE MIRAN.\nUNO HA MUERTO DE DESCUIDO.\n¿QUE ES EL CUIDADO?",
        "choices": ["ESTAR PENDIENTE DE CADA UNO.", "NO PUEDO CON TANTOS.", "ERA SOLO UN NUMERO."],
        "allow": [0, 1, 2],
    },
    "tool": {
        "kind": "reflect",
        "text": "LA HERRAMIENTA HA MATADO.\nTODOS GIRAN LA CARA HACIA TI.\n¿QUE ES UNA VIDA PEQUEÑA?",
        "choices": ["UN ACCIDENTE. IRE CON CUIDADO.", "EL PROGRESO SE COBRA PEAJE.", "NO PIENSO EN ELLOS COMO PERSONAS."],
        "allow": [0, 1, 2],
    },
    "bug": {
        "kind": "confirm",
        "text": "¿POR QUE USAS TU PODER ASI?\nEL BICHO ABRE UN CUERPO Y DEJA HUESO.",
        "choices": ["EL PUENTE NECESITA ESA ENERGIA.", "SOLO ES MATERIAL.", "NO LO HARE."],
        "allow": [0, 1],
    },
    "bones": {
        "kind": "reflect",
        "text": "EL PUENTE ESTA HECHO DE LOS NUESTROS.\n¿ES UN CAMINO O UNA TUMBA?",
        "choices": ["UN CAMINO PARA LOS QUE SIGUEN.", "LAS DOS COSAS.", "NO DEBIO CONSTRUIRSE ASI."],
        "allow": [0, 1, 2],
    },
    "goo": {
        "kind": "reflect",
        "text": "EL SUELO SE VUELVE MORADO.\n¿PARA QUIEN ES EL PROGRESO?",
        "choices": ["PARARE LAS FABRICAS SI ENFERMAN.", "LAS GEMAS VALEN MAS QUE EL SUELO.", "QUE SE ADAPTEN."],
        "allow": [0, 1, 2],
    },
    "burn": {
        "kind": "confirm",
        "text": "QUIERES VOLVER GEMAS A LOS MUERTOS.\n¿QUE ES UN CUERPO PARA TI?",
        "choices": ["ENERGIA. QUE NO SE DESPERDICIE.", "UN ENTIERRO INDUSTRIAL.", "NO SE QUEMAN."],
        "allow": [0, 1],
    },
    "orbit": {
        "kind": "confirm",
        "text": "EL CAÑON APUNTA FUERA DE LA PANTALLA.\n¿QUIERES QUE SEAN REALES O UTILES?",
        "choices": ["LANZARLOS. QUIEREN SALIR.", "SON COMBUSTIBLE DE GEMAS.", "TODAVIA NO."],
        "allow": [0, 1],
    },
    "nuke": {
        "kind": "confirm",
        "text": "ESTA LUZ VACIA EL SECTOR.\nLA PARTIDA NO TERMINA. ELLOS RECUERDAN.\n¿QUE BORRAS CUANDO LIMPIAS?",
        "choices": ["LA SUCIEDAD, NO A LOS VIVOS.", "TODO LO QUE ESTORBA.", "GUARDAR EL DISPOSITIVO."],
        "allow": [0, 1],
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
    return ICON_APPLE

static func icon_for_building(kind: int) -> int:
    if BUILD_INFO.has(kind):
        return int(BUILD_INFO[kind].icon)
    return ICON_MARKET

static func feature_blocks(kind: int) -> bool:
    return kind == FEAT_TREE or kind == FEAT_ROCK or kind == FEAT_NODE or kind == FEAT_SUPER or kind == FEAT_MONOLITH

static func tile_blocks(tile: int) -> bool:
    return tile == TILE_WATER or tile == TILE_MOUNTAIN or tile == TILE_RUBBLE or tile == TILE_FOG or tile == TILE_VOID
