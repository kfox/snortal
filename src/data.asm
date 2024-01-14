#importonce

.segment Data "Title Screen"
.var title_screen_data = LoadBinary("../data/title_screen.seq")
title_screen: .fill title_screen_data.getSize(), title_screen_data.uget(i)

.segment Data "Title Color"
.var title_color_data = LoadBinary("../data/title_color.seq")
title_color: .fill title_color_data.getSize(), title_color_data.uget(i)
