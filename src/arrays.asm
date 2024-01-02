#importonce

.segment Arrays "Screen Offsets"
// this is a list of offsets for the beginning of each row in screen RAM
screen_offsets: .lohifill 25, 40 * i

.segment Arrays "Snake Segments"
// snake segments are from tail to head
snake_segments_x: .fill 256, 16 + i
snake_segments_y: .fill 256, 12

.segment Arrays "Body Segment Chars"
horizontal_body_segment_chars: .byte $43, $44, $43, $46
vertical_body_segment_chars: .byte $42, $47, $42, $48
