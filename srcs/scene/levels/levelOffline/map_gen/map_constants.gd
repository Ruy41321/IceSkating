class_name MapConstants

const DIRECTIONS = {
    RIGHT = 0, LEFT = 1, DOWN = 2, UP = 3, INITIAL = 4
}

const DIRECTION_NAMES = ["DESTRA", "SINISTRA", "GIU", "SU"]
const DIRECTION_VECTORS = [[1, 0], [-1, 0], [0, 1], [0, -1]]

const TERRAIN = {
    WALL = 'M', ICE = 'G', NORMAL = 'T', START = 'I', END = 'E',
    FRAGILE_ICE = 'D', HOLE = 'B', BROKEN_ICE = 'X',
    CONVEYOR_RIGHT = '1', CONVEYOR_LEFT = '2', CONVEYOR_DOWN = '3', CONVEYOR_UP = '4'
}

static func direction_to_string(dir: int) -> String:
    return DIRECTION_NAMES[dir] if dir >= 0 and dir < DIRECTION_NAMES.size() else "SCONOSCIUTA"