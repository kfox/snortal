#importonce

// joystick 2 values
.const fire  = $6f
.const left  = $7b
.const right = $77
.const up    = $7e
.const down  = $7d
.const idle  = $7f

// EOR'ed directional combos
.const up_left    = $05
.const down_left  = $06
.const up_right   = $09
.const down_right = $0a

// min/max x/y offsets
.const min_x = 0
.const max_x = 39
.const min_y = 1  // reserve the first screen row for game info
.const max_y = 24

// characters
.const space         = $20
.const snack         = $53
.const head          = $57
.const orange_portal = $66
.const blue_portal   = $e6
.const body_vert1    = $47
.const body_vert2    = $42
.const body_vert3    = $48
.const body_horiz1   = $44
.const body_horiz2   = $43
.const body_horiz3   = $46

// other variables
.const initial_delay = 27
