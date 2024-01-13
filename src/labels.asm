#importonce

// KERNAL memory locations
.label SCREEN_RAM   = $0400
.label RASTER       = $d012
.label BORDER_COLOR = $d020
.label BG_COLOR     = $d021
.label COLOR_RAM    = $d800
.label JOY2         = $dc00
.label CIA1_TALO    = $dc04
.label CIA1_TAHI    = $dc05

// game-specific memory locations
.label char_to_draw       = $02 // character to draw
.label snake_segment_xpos = $fb // min_x to max_x
.label snake_segment_ypos = $fc // min_y to max_y
.label screen_loc_ptr     = $fd // low byte of word ($fd-$fe)
