#importonce

// these are all virtual because they're reset for every game

.segment Variables "Direction"
snake_direction: .byte 0
old_snake_direction: .byte 0

.segment Variables "Offsets"
snake_head_segment_offset: .byte 0
snake_body_segment_char_offset: .byte 0
snake_tail_segment_offset: .byte 0

.segment Variables "Stats"
snake_length: .byte 0
score: .byte 0, 0, 0
high_score: .byte 0, 0, 0
bonus: .byte 0, 0
delay_time: .byte 0
game_mode: .enum {WAIT_FOR_FIRE, PLAY}

.segment Variables "Portals"
blue_portal_x: .byte 0
blue_portal_y: .byte 0
orange_portal_x: .byte 0
orange_portal_y: .byte 0
snake_segments_in_transit: .byte 0
