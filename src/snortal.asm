.encoding "screencode_upper"

.segmentdef Code [start=$0840]
.segmentdef Arrays [startAfter="Code", align=$100]
.segmentdef Strings [startAfter="Arrays"]
.segmentdef Variables [startAfter="Strings", virtual]
.segmentdef Data [startAfter="Variables", align=$100]

.file [
  name="%o.prg",
  segments="Code,Arrays,Strings,Data",
  modify="BasicUpstart",
  _start=$0840
]

// .disk [filename="Snortal.d64", name="SNORTAL", id="2024!" ]
// {
//   [name="----------------", type="rel"                        ],
//   [name="SNORTAL", type="prg", segments="Code,Arrays,Strings" ],
//   [name="----------------", type="rel"                        ],
//   [name="HIGH SCORE", type="seq", segments="High_Score"       ],
//   [name="----------------", type="rel"                        ],
// }

#import "labels.asm"
#import "macros.asm"
#import "strings.asm"
#import "constants.asm"
#import "arrays.asm"
#import "variables.asm"
#import "data.asm"


.segment Code "PreInit"
pre_init:
  mov #TITLE : game_mode

load_high_score:
  // TODO: replace this with a disk load routine
  lda #0
  ldx #0
!:
  sta high_score, x
  inx
  cpx #3
  bne !-

.segment Code "Init"
init:
  mov #BLACK : BG_COLOR
  mov #DARK_GRAY : BORDER_COLOR

  cls(SCREEN_RAM, space) // clear the screen
  cls(COLOR_RAM, GREEN)

  lda game_mode
  cmp #TITLE
  bne !+

  mov #PLAY : game_mode
  jsr draw_title_screen
  jsr draw_title_banners
  jmp wait_for_fire_to_restart

!:
  jsr reset_score
  jsr reset_bonus
  jsr init_snake_segments

  mov #right : snake_direction
  mov #right : old_snake_direction
  mov #0 : snake_tail_segment_offset
  mov #0 : snake_body_segment_char_offset
  mov #5 : snake_length
  mov #0 : snake_segments_in_transit
  mov #initial_delay : delay_time

  jsr draw_initial_snake
  dec snake_tail_segment_offset // ensure snake offsets are correct for the first move
  lda snake_head_segment_offset
  jsr get_snake_segment_position
  sty snake_segment_xpos
  stx snake_segment_ypos

  jsr draw_snake_snack
  jsr draw_orange_portal
  jsr draw_blue_portal

start_game:
  jsr set_bonus
  jsr display_bonus
  jsr draw_banner
  jsr display_high_score
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

draw_title_banners:
  draw_text(welcome_to_snortal_text, 1024, GREEN, true)
  draw_text(byline_text, 1064, GREEN, true)
  draw_text(press_fire_to_begin_text, 1984, RED, true)
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

draw_title_screen:
  .for (var offset=$000; offset<=$300; offset+=$100) {
    ldx #0
  !:
    lda title_screen + offset, x
    sta SCREEN_RAM + offset, x
    lda title_color + offset, x
    sta COLOR_RAM + offset, x
    inx
    cpx #0
    bne !-
  }
  rts

.segment Code "Main"
game_loop:
  jsr read_joystick_2
  jsr delay
  jmp game_loop

reset_score:
  lda #0
  sta score
  sta score + 1
  sta score + 2
  rts

reset_bonus:
  lda #0
  sta bonus
  sta bonus + 1
  rts

draw_initial_snake:
  .for (var offset=0; offset<5; offset++) {
    lda #offset
    sta snake_head_segment_offset
    .var char = offset < 4 ? $43 : head
    mov #char : char_to_draw
    jsr draw_snake_head
  }
  rts

draw_snake_head:
  lda snake_head_segment_offset
  jsr get_snake_segment_position
  jsr draw_char
  rts

erase_snake_tail:
  lda snake_tail_segment_offset
  jsr get_snake_segment_position
  jsr erase_char
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

draw_char:
  lda screen_offsets.lo, x
  sta screen_loc_ptr
  lda screen_offsets.hi, x
  ora #$04 // add $0400 to the screen offset
  sta screen_loc_ptr + 1

  // we have to use register y to hold the x-value because STA
  // only allows y as the indirect-indexed addressing mode offset
  lda char_to_draw
  sta (screen_loc_ptr), y

  add16 screen_loc_ptr : #$d400
  lda #GREEN
  sta (screen_loc_ptr), y
  rts

erase_char:
  lda screen_offsets.lo, x
  sta screen_loc_ptr
  lda screen_offsets.hi, x
  ora #$04 // add $0400 to the screen offset
  sta screen_loc_ptr + 1
  lda #space
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
  jsr decrease_bonus
  jsr display_bonus
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
  jsr set_bonus
  jsr display_bonus
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

  mov #head : char_to_draw
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
  // mov #$42 : char_to_draw
  rts

!:
  // down again
  cmp #down
  bne !+
  jsr get_next_vertical_body_segment
  // mov #$42 : char_to_draw
  rts

!:
  // left again or right again
  jsr get_next_horizontal_body_segment
  // mov #$43 : char_to_draw
  rts

get_next_vertical_body_segment:
  ldx snake_body_segment_char_offset
  lda vertical_body_segment_chars, x
  sta char_to_draw
  jsr inc_body_segment_offset
  rts

get_next_horizontal_body_segment:
  ldx snake_body_segment_char_offset
  lda horizontal_body_segment_chars, x
  sta char_to_draw
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
  mov #$49 : char_to_draw
  rts

!:
  mov #$4a : char_to_draw
  rts

check_up_right:
  cmp #up_right
  bne check_down_left
  lda old_snake_direction
  cmp #up
  bne !+
  mov #$55 : char_to_draw
  rts

!:
  mov #$4b : char_to_draw
  rts

check_down_left:
  cmp #down_left
  bne check_down_right
  lda old_snake_direction
  cmp #down
  bne !+
  mov #$4b : char_to_draw
  rts

!:
  mov #$55 : char_to_draw
  rts

check_down_right:
  cmp #down_right
  bne unknown_snake_direction
  lda old_snake_direction
  cmp #down
  bne !+
  mov #$4a : char_to_draw
  rts

!:
  mov #$49 : char_to_draw
  rts

unknown_snake_direction:
  mov #$3f : char_to_draw
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
  jsr erase_char

  ldx orange_portal_y
  ldy orange_portal_x
  jsr erase_char

  rts

set_bonus:
  sed // use BCD
  clc

  lda #50
  sta bonus
  lda bonus
  adc snake_length
  sta bonus
  bcc !+

  lda bonus + 1
  adc #$00
  sta bonus + 1

  rts

decrease_bonus:
  // check if the bonus is already 1... if so, don't decrease it again
  lda bonus
  eor bonus + 1
  cmp #$01
  beq !+

  // bonus > 1, decrease it by 1
  sed // use BCD
  sec

  lda bonus
  sbc #$01
  sta bonus
  bcc !+

  lda bonus + 1
  sbc #$00
  sta bonus + 1

!:
  cld
  rts

display_bonus:
  ldy #2 // screen offset, starting with the least-significant digit
  ldx #0 // bonus byte index (0-1)

bonus_loop:
  // get the lowest 4 bits of the current bonus byte and draw it
  lda bonus, x
  and #$0f
  jsr draw_bonus_digit
  cpx #1 // we only want the first 3 nybbles; skip the upper 4 bits of the 2nd byte
  beq !+

  // now do the same thing with the upper 4 bits of the byte
  lda bonus, x
  lsr
  lsr
  lsr
  lsr
  jsr draw_bonus_digit

  inx
  jmp bonus_loop

!:
  rts

draw_bonus_digit:
  clc
  adc #48 + 128 // "0" through "9", reverse mode
  sta $0406, y  // screen location for bonus display
  dey
  rts

increase_score:
  sed // use BCD
  clc

  lda score
  adc bonus
  sta score
  bcc !+

  dec delay_time
  lda score + 1
  adc bonus + 1
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
  jsr draw_score_digit

  // now do the same thing with the upper 4 bits of the byte
  lda score, x
  lsr
  lsr
  lsr
  lsr
  jsr draw_score_digit

  inx
  cpx #3
  bne score_loop

  rts

draw_score_digit:
  clc
  adc #48 + 128 // "0" through "9", reverse mode
  sta $0422, y  // screen location for score display
  dey
  rts

game_over:
  jsr check_high_score
  cls(COLOR_RAM, DARK_GRAY)
  ldx #$0

!:
  lda game_over_text, x
  beq wait_for_fire_to_restart
  sta $05ee, x
  lda press_fire_text, x
  sta $063e, x
  lda #RED
  sta $d9ee, x
  sta $da3e, x
  inx
  jmp !-

check_high_score:
  lda score + 2          // compare high bytes
  cmp high_score + 2
  bcc no_new_high_score
  bne set_new_high_score
  lda score + 1          // compare middle bytes
  cmp high_score + 1
  bcc no_new_high_score
  bne set_new_high_score
  lda score              // compare low bytes
  cmp high_score
  bcc no_new_high_score

set_new_high_score:
  ldx #0

!:
  lda score, x
  sta high_score, x
  inx
  cpx #3
  bne !-

  jsr display_high_score

no_new_high_score:
  rts

display_high_score:
  ldy #5 // screen offset, starting with the least-significant digit
  ldx #0 // high score byte index (0-2)

high_score_loop:
  // get the lowest 4 bits of the current high score byte and draw it
  lda high_score, x
  and #$0f
  jsr draw_high_score_digit

  // now do the same thing with the upper 4 bits of the byte
  lda high_score, x
  lsr
  lsr
  lsr
  lsr
  jsr draw_high_score_digit

  inx
  cpx #3
  bne high_score_loop

  rts

draw_high_score_digit:
  clc
  adc #48 + 128 // "0" through "9", reverse mode
  sta $0412, y  // screen location for score display
  dey
  rts

wait_for_fire_to_restart:
  jsr delay
!:
  lda JOY2
  cmp #fire
  bne !-
  jmp init

exit:
