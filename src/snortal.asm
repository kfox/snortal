.encoding "screencode_upper"
.segmentdef Code [start=$0840]
.segmentdef Data [startAfter="Code", align=$100]
.segmentdef Variables [startAfter="Data", align=$100, virtual]
.file [
  name="%o.prg",
  segments="Code,Data",
  modify="BasicUpstart",
  _start=$0840
]

// KERNAL memory locations
.label SCREEN_RAM = $0400
.label RASTER = $d012
.label BORDER_COLOR = $d020
.label BG_COLOR = $d021
.label COLOR_RAM = $d800
.label JOY2   = $dc00
.label CIA1_TALO = $dc04
.label CIA1_TAHI = $dc05

// joystick 2 values
.var joy2_fire = $6f
.var joy2_left = $7b
.var joy2_right = $77
.var joy2_up = $7e
.var joy2_down = $7d

// directions
.var up    = %00001
.var down  = %00010
.var left  = %00100
.var right = %01000

// min/max x/y offsets
.var min_x = 0
.var max_x = 39
.var min_y = 0
.var max_y = 24

// snake characters
.var space = $20
.var body  = $51
.var apple = $53
.var head  = $57

// game-specific memory locations
.label snake_segment_char = $02 // character to draw
.label snake_segment_xpos = $fb // min_x - max_x
.label snake_segment_ypos = $fc // min_y - max_y
.label screen_loc_ptr  = $fd    // low byte of word ($fd-$fe)

.segment Code "Init"
init:
  lda #BLACK
  sta BG_COLOR
  lda #DARK_GRAY
  sta BORDER_COLOR

  cls(SCREEN_RAM, space) // clear the screen
  cls(COLOR_RAM, GREEN)  // fill color RAM with green

  jsr init_snake_segments

  mov #right : snake_direction
  mov #right : old_snake_direction
  mov #0 : snake_tail_segment_offset
  mov #0 : snake_length
  mov #127 : last_joystick_value

  jsr draw_initial_snake
  dec snake_tail_segment_offset // ensure snake offsets are correct for the first move
  lda snake_head_segment_offset
  jsr get_snake_segment_position
  sty snake_segment_xpos
  stx snake_segment_ypos

  jsr place_apple

  jmp game_loop

init_snake_segments:
  ldx #0
  clc

!:
  txa
  adc #16
  sta snake_segments_x, x
  lda #12
  sta snake_segments_y, x
  inx
  bne !-

  rts

.segment Code "Main"
game_loop:
  jsr read_joystick_2
  jmp game_loop

draw_initial_snake:
  .for (var offset=0; offset<5; offset++) {
    lda #offset
    sta snake_head_segment_offset
    .var char = offset < 4 ? body : head
    mov #char : snake_segment_char
    jsr draw_snake_head
    inc snake_length
  }
  rts

draw_snake_head:
  lda snake_head_segment_offset
  jsr get_snake_segment_position
  jsr draw_snake_segment
  rts

erase_snake_tail:
  lda snake_tail_segment_offset
  jsr get_snake_segment_position
  mov #space : snake_segment_char
  jsr draw_snake_segment
  rts

get_snake_segment_position:
  // before this:
  // the snake segment offset must be in a
  // after this:
  // the row offset will be in x
  // the column offset will be in y
  tax
  tay
  lda snake_segments_y, y // row
  ldy snake_segments_x, x // column
  tax
  rts

draw_snake_segment:
  lda screen_offsets.lo, x
  sta screen_loc_ptr
  lda screen_offsets.hi, x
  ora #$04 // add $0400 to the screen offset
  sta screen_loc_ptr + 1

  // we have to use register y to hold the x-value because STA
  // only allows y as the indirect-indexed addressing mode offset
  lda snake_segment_char
  sta (screen_loc_ptr), y

  add16 screen_loc_ptr : #$d400
  lda #GREEN
  sta (screen_loc_ptr), y
  rts

read_joystick_2:
  lda JOY2
  cmp last_joystick_value
  bne !+
  rts
!:
  sta last_joystick_value

  cmp #joy2_up
  bne !+
  jmp check_up
!:
  cmp #joy2_down
  bne !+
  jmp check_down
!:
  cmp #joy2_left
  bne !+
  jmp check_left
!:
  cmp #joy2_right
  bne !+
  jmp check_right
!:
  rts

move_snake:
  ldx snake_segment_ypos
  ldy snake_segment_xpos
  jsr get_screen_loc_contents

  // did the snake try to eat itself? bad idea.
  cmp #body
  bne !+
  jmp game_over

!:
  // did the snake eat something yummy, or not?
  cmp #apple
  bne erase_tail // no, move along
  inc snake_length
  lda snake_length
  sta $0427
  jsr place_apple // yes, grow and place a new snake snack
  jmp !+

erase_tail:
  inc snake_tail_segment_offset
  jsr erase_snake_tail

!:
  mov #body : snake_segment_char
  jsr draw_snake_head

  inc snake_head_segment_offset
  ldx snake_head_segment_offset
  lda snake_segment_xpos
  sta snake_segments_x, x
  lda snake_segment_ypos
  sta snake_segments_y, x

  mov #head : snake_segment_char
  jsr draw_snake_head
  rts

check_left:
  lda snake_direction
  cmp #right
  bne !+
  rts

!:
  lda snake_segment_xpos
  cmp #min_x
  bne !+
  jmp game_over

!:
  dec snake_segment_xpos
  mov snake_direction : old_snake_direction
  mov #left : snake_direction
  jsr move_snake
  rts

check_right:
  lda snake_direction
  cmp #left
  bne !+
  rts

!:
  lda snake_segment_xpos
  cmp #max_x
  bne !+
  jmp game_over

!:
  inc snake_segment_xpos
  mov snake_direction : old_snake_direction
  mov #right : snake_direction
  jsr move_snake
  rts

check_up:
  lda snake_direction
  cmp #down
  bne !+
  rts

!:
  lda snake_segment_ypos
  cmp #min_y
  bne !+
  jmp game_over

!:
  dec snake_segment_ypos
  mov snake_direction : old_snake_direction
  mov #up : snake_direction
  jsr move_snake
  rts

check_down:
  lda snake_direction
  cmp #up
  bne !+
  rts

!:
  lda snake_segment_ypos
  cmp #max_y
  bne !+
  jmp game_over

!:
  inc snake_segment_ypos
  mov snake_direction : old_snake_direction
  mov #down : snake_direction
  jsr move_snake
  rts

alternate_delay:
  lda RASTER
  cmp #$ff
  bne alternate_delay
  dey
  bne alternate_delay
  rts

delay:
  lda snake_length
  adc snake_length
!:
  nop
  nop
  adc #1
  bne !-
  jmp game_loop

get_screen_loc_contents:
  lda screen_offsets.lo, x
  sta screen_loc_ptr
  lda screen_offsets.hi, x
  ora #$04 // add $0400 to the screen offset
  sta screen_loc_ptr + 1
  lda (screen_loc_ptr), y
  rts

place_apple:
  // pick a column
  rand(39)
  tay

  // pick a row
  rand(24)
  tax

  // check if the screen location is occupied
  jsr get_screen_loc_contents
  cmp #space
  bne place_apple

  // draw the apple
  lda #apple
  sta (screen_loc_ptr), y
  add16 screen_loc_ptr : #$d400
  lda #RED
  sta (screen_loc_ptr), y
  rts

game_over:
  cls(SCREEN_RAM, space)
  ldx #$0

!:
  lda game_over_text, x
  cmp #$ff
  beq wait_for_fire_button
  sta $05ee, x
  lda press_fire_text, x
  sta $063e, x
  lda #WHITE
  sta $d9ee, x
  sta $da3e, x
  inx
  jmp !-

wait_for_fire_button:
  jsr alternate_delay
!:
  lda JOY2
  cmp #joy2_fire
  bne !-
  jmp init

exit:

//
// data
//

.segment Data "Screen Offsets"
// screen_offsets is a list of addresses for the first location of every row
screen_offsets: .lohifill 25, 40 * i

.segment Data "Text Strings"
welcome_text:
  .text "WELCOME TO SNORTAL"
  .byte $ff
press_fire_text:
  .text "PRESS FIRE"
  .byte $ff
game_over_text:
  .text "GAME OVER!"
  .byte $ff

.segment Variables
// snake segments are from tail to head
snake_segments_x: .fill 256, 16 + i
snake_segments_y: .fill 256, 12
snake_direction: .byte right
old_snake_direction: .byte right
snake_head_segment_offset: .byte 4
snake_tail_segment_offset: .byte 0
snake_length: .byte 5
last_joystick_value: .byte 127

//
// functions, macros, pseudocommands
//

.macro cls(screen, fillchar) {
  lda #fillchar
  ldx #0
!:
  sta screen, x
  sta screen + $100, x
  sta screen + $200, x
  sta screen + $300, x
  inx
  bne !-
}

.macro rand(max) {
  // generates a random-ish number between 0 and max, inclusive
  // semi-"optimized" for max = 24 or max = 39
  .var mask = [max < 32] ? %11111 : %111111
!:
  lda RASTER
  eor CIA1_TALO
  sbc CIA1_TAHI
  and #mask
  cmp #max + 1
  bpl !- // regenerate a random number if number >= max + 1
}

.pseudocommand mov source : dest {
  lda source
  sta dest
}

.function _16bit_nextArgument(arg) {
  .if (arg.getType()==AT_IMMEDIATE)
    .return CmdArgument(arg.getType(),>arg.getValue())
  .return CmdArgument(arg.getType(),arg.getValue()+1)
}

.pseudocommand mov16 source : dest {
  lda source
  sta dest
  lda _16bit_nextArgument(source)
  sta _16bit_nextArgument(dest)
}

.pseudocommand add16 arg1 : arg2 : target {
  .if (target.getType()==AT_NONE) .eval target=arg1
  clc
  lda arg1
  adc arg2
  sta target
  lda _16bit_nextArgument(arg1)
  adc _16bit_nextArgument(arg2)
  sta _16bit_nextArgument(target)
}

.pseudocommand dec16 arg {
  lda arg
  bne !+
  dec _16bit_nextArgument(arg)
!:
  dec arg
}
