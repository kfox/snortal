.encoding "screencode_upper"
.segmentdef Code [start=$0840]
.segmentdef Arrays [startAfter="Code", align=$100]
.segmentdef Strings [startAfter="Arrays"]
.segmentdef Variables [startAfter="Strings", virtual]
.file [
  name="%o.prg",
  segments="Code,Arrays,Strings",
  modify="BasicUpstart",
  _start=$0840
]

#import "labels.asm"
#import "macros.asm"
#import "strings.asm"
#import "constants.asm"
#import "arrays.asm"
#import "variables.asm"

.segment Code "Init"
init:
  lda #BLACK
  sta BG_COLOR
  lda #DARK_GRAY
  sta BORDER_COLOR

  cls(SCREEN_RAM, space) // clear the screen
  cls(COLOR_RAM, GREEN)

  jsr init_snake_segments

  mov #right : snake_direction
  mov #right : old_snake_direction
  mov #0 : snake_tail_segment_offset
  mov #0 : snake_body_segment_char_offset
  mov #0 : snake_length
  mov #0 : snake_segments_in_transit
  mov #initial_delay : delay_time

  jsr reset_score
  jsr draw_banner

  jsr draw_initial_snake
  dec snake_tail_segment_offset // ensure snake offsets are correct for the first move
  lda snake_head_segment_offset
  jsr get_snake_segment_position
  sty snake_segment_xpos
  stx snake_segment_ypos

  jsr draw_snake_snack
  jsr draw_orange_portal
  jsr draw_blue_portal

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

draw_banner:
  ldx #0
  clc

!:
  lda banner_text, x
  adc #128 // use reverse text
  sta $0400, x
  lda #DARK_GRAY
  sta $d800, x
  inx
  cpx #40
  bne !-

  rts

.segment Code "Main"
game_loop:
  jsr read_joystick_2
  jsr delay
  jmp game_loop

reset_score:
  ldx #0
  lda #0

!:
  sta score, x
  inx
  cpx #3
  bne !-

  rts

draw_initial_snake:
  .for (var offset=0; offset<5; offset++) {
    lda #offset
    sta snake_head_segment_offset
    .var char = offset < 4 ? $43 : head
    mov #char : snake_segment_char
    jsr draw_snake_head
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
  cmp #idle
  bne check_snake_direction

move_along:
  lda snake_direction

check_snake_direction:
  cmp #up
  bne !+
  jmp check_up
!:
  cmp #down
  bne !+
  jmp check_down
!:
  cmp #left
  bne !+
  jmp check_left
!:
  cmp #right
  bne !+
  jmp check_right
!:
  jmp move_along
  rts

move_snake:
  ldx snake_segment_ypos
  ldy snake_segment_xpos
  jsr get_screen_loc_contents

check_move_space:
  cmp #space
  bne check_move_orange_portal
  jsr erase_snake_tail
  inc snake_tail_segment_offset
  jmp check_portal_transit

check_move_orange_portal:
  cmp #orange_portal
  bne check_move_blue_portal
  jsr handle_orange_portal_transit
  jmp check_portal_transit

check_move_blue_portal:
  cmp #blue_portal
  bne check_move_snack
  jsr handle_blue_portal_transit
  jmp check_portal_transit

check_move_snack:
  cmp #snack
  bne !+
  jsr increase_score
  inc snake_length
  jsr draw_snake_snack
  jmp check_portal_transit

!:
  // snake tried to eat itself
  jmp game_over

check_portal_transit:
  lda snake_segments_in_transit
  cmp #0
  beq check_portal_redraw
  dec snake_segments_in_transit
  jmp move_head

check_portal_redraw:
  rand(1, 36)
  cmp #1
  bne move_head
  jsr redraw_portals
  jmp move_head

move_head:
  jsr set_new_snake_segment
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

set_new_snake_segment:
  lda old_snake_direction
  eor snake_direction
  bne reset_body_segment_char_offset

  // up again
  lda old_snake_direction
  cmp #up
  bne !+
  jsr get_next_vertical_body_segment
  // mov #$42 : snake_segment_char
  rts

!:
  // down again
  cmp #down
  bne !+
  jsr get_next_vertical_body_segment
  // mov #$42 : snake_segment_char
  rts

!:
  // left again or right again
  jsr get_next_horizontal_body_segment
  // mov #$43 : snake_segment_char
  rts

get_next_vertical_body_segment:
  ldx snake_body_segment_char_offset
  lda vertical_body_segment_chars, x
  sta snake_segment_char
  jsr inc_body_segment_offset
  rts

get_next_horizontal_body_segment:
  ldx snake_body_segment_char_offset
  lda horizontal_body_segment_chars, x
  sta snake_segment_char
  jsr inc_body_segment_offset
  rts

inc_body_segment_offset:
  inc snake_body_segment_char_offset
  lda snake_body_segment_char_offset
  cmp #4
  bne !+
  lda #0
  sta snake_body_segment_char_offset

!:
  rts

reset_body_segment_char_offset:
  ldx #0
  stx snake_body_segment_char_offset

check_up_left:
  cmp #up_left
  bne check_up_right
  lda old_snake_direction
  cmp #up
  bne !+
  mov #$49 : snake_segment_char
  rts

!:
  mov #$4a : snake_segment_char
  rts

check_up_right:
  cmp #up_right
  bne check_down_left
  lda old_snake_direction
  cmp #up
  bne !+
  mov #$55 : snake_segment_char
  rts

!:
  mov #$4b : snake_segment_char
  rts

check_down_left:
  cmp #down_left
  bne check_down_right
  lda old_snake_direction
  cmp #down
  bne !+
  mov #$4b : snake_segment_char
  rts

!:
  mov #$55 : snake_segment_char
  rts

check_down_right:
  cmp #down_right
  bne unknown_snake_direction
  lda old_snake_direction
  cmp #down
  bne !+
  mov #$4a : snake_segment_char
  rts

!:
  mov #$49 : snake_segment_char
  rts

unknown_snake_direction:
  mov #$3f : snake_segment_char
  rts

redraw_portals:
  jsr erase_portals
  jsr draw_orange_portal
  jsr draw_blue_portal
  rts

handle_blue_portal_transit:
  ldy orange_portal_x
  ldx orange_portal_y
  jmp handle_portal_transit

handle_orange_portal_transit:
  ldy blue_portal_x
  ldx blue_portal_y
  jmp handle_portal_transit

handle_portal_transit:
  sty snake_segment_xpos
  stx snake_segment_ypos

  lda snake_direction
  cmp #right
  bne !+
  jsr portal_transit_initiated
  jmp check_right

!:
  lda snake_direction
  cmp #left
  bne !+
  jsr portal_transit_initiated
  jmp check_left

!:
  lda snake_direction
  cmp #up
  bne !+
  jsr portal_transit_initiated
  jmp check_up

!:
  lda snake_direction
  jsr portal_transit_initiated
  jmp check_down

portal_transit_initiated:
  mov snake_length : snake_segments_in_transit
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
  jmp move_snake

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
  jmp move_snake

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
  jmp move_snake

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
  jmp move_snake

delay:
  ldy delay_time
!:
  ldx RASTER
  cpx #$ff
  bne !-
  dey
  bne !-
  rts

get_screen_loc_contents:
  // expects:
  // the row in the x register
  // the column in the y register
  // returns:
  // contents of that screen ram location in accumulator
  lda screen_offsets.lo, x
  sta screen_loc_ptr
  lda screen_offsets.hi, x
  ora #$04 // add $0400 to the screen offset
  sta screen_loc_ptr + 1
  lda (screen_loc_ptr), y
  rts

find_empty_screen_location:
  rand(min_x, max_x) // pick a column
  tay                // store column in y register
  rand(min_y, max_y) // pick a row
  tax                // store row in x register

  jsr get_screen_loc_contents    // what's at that location?
  cmp #space                     // is it an empty space?
  bne find_empty_screen_location // if not, try again

  rts

draw_snake_snack:
  jsr find_empty_screen_location

  // draw the snack
  lda #snack
  sta (screen_loc_ptr), y
  add16 screen_loc_ptr : #$d400
  lda #RED
  sta (screen_loc_ptr), y
  rts

draw_orange_portal:
  jsr find_empty_screen_location
  stx orange_portal_y
  sty orange_portal_x

  lda #orange_portal
  sta (screen_loc_ptr), y
  add16 screen_loc_ptr : #$d400
  lda #ORANGE
  sta (screen_loc_ptr), y
  rts

draw_blue_portal:
  jsr find_empty_screen_location
  stx blue_portal_y
  sty blue_portal_x

  lda #blue_portal
  sta (screen_loc_ptr), y
  add16 screen_loc_ptr : #$d400
  lda #LIGHT_BLUE
  sta (screen_loc_ptr), y
  rts

erase_portals:
  ldx blue_portal_y
  ldy blue_portal_x
  lda screen_offsets.lo, x
  sta screen_loc_ptr
  lda screen_offsets.hi, x
  ora #$04
  sta screen_loc_ptr + 1
  lda #space
  sta (screen_loc_ptr), y

  ldx orange_portal_y
  ldy orange_portal_x
  lda screen_offsets.lo, x
  sta screen_loc_ptr
  lda screen_offsets.hi, x
  ora #$04
  sta screen_loc_ptr + 1
  lda #space
  sta (screen_loc_ptr), y

  rts

increase_score:
  sed // we're using BCD for scoring
  clc

  lda score
  adc #$10 // add 10 to the current score
  sta score
  bcc !+

  dec delay_time
  lda score + 1
  adc #$00
  sta score + 1
  bcc !+

  lda score + 2
  adc #$00
  sta score + 2

!:
  cld

  jsr display_score

  rts

display_score:
  ldy #5 // screen offset, starting with the least-significant digit
  ldx #0 // score byte index (0-2)

score_loop:
  // get the lowest 4 bits of the current score byte and draw it
  lda score, x
  and #$0f
  jsr draw_digit

  // now do the same thing with the upper 4 bits of the byte
  lda score, x
  lsr
  lsr
  lsr
  lsr
  jsr draw_digit

  inx
  cpx #3
  bne score_loop

  rts

draw_digit:
  clc
  adc #48 + 128 // "0" - "9", reverse mode
  sta $0422, y  // screen location for score display
  dey
  rts

game_over:
  cls(COLOR_RAM, DARK_GRAY)
  ldx #$0

!:
  lda game_over_text, x
  beq wait_for_fire_button
  sta $05ee, x
  lda press_fire_text, x
  sta $063e, x
  lda #RED
  sta $d9ee, x
  sta $da3e, x
  inx
  jmp !-

wait_for_fire_button:
  jsr delay
!:
  lda JOY2
  cmp #fire
  bne !-
  jmp init

exit:
