#importonce

#import "labels.asm"

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

.macro draw_text(text, location, color, reverse) {
  ldx #0
  clc

!:
  lda text, x
  cmp #0
  beq !+
  .if (reverse) adc #127 // use "reverse" mode
  sta location, x
  lda #color
  sta location + $d400, x
  inx
  jmp !-

!:
}

.macro rand(min, max) {
  // generates a random-ish number between 0 and max, inclusive
  // semi-"optimized" for max = 24 or max = 39
  .var mask = [max < 32] ? %11111 : %111111
!:
  lda RASTER
  eor CIA1_TALO
  sbc CIA1_TAHI
  and #mask
  cmp #max + 1
  bpl !- // try again if number >= max + 1
  cmp #min
  bmi !- // try again if number < min
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
