# Tab drawing for tab_bar_style custom.
#
# Each tab is a padding cell, the title, and an edge cell. The edge cell draws
# U+258C LEFT HALF BLOCK in the tab color on the tab bar background. The right
# half of the edge cell is the gap to the next tab, so the gap is half a cell.
#
# kitty documents this interface by example only: see the draw_tab_with_*
# functions in kitty/tab_bar.py. When draw_tab raises an exception, kitty logs
# the error and draws the tab with the fade style.

from kitty.fast_data_types import Screen
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_title
from kitty.utils import color_as_int


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    tab_bg = screen.cursor.bg
    screen.draw(" ")
    draw_title(draw_data, screen, tab, index, max_tab_length)
    # The edge cell is the last cell of the tab, so the title ends one cell
    # before max_tab_length.
    extra = screen.cursor.x + 1 - before - max_tab_length
    if extra > 0:
        screen.cursor.x -= extra + 1
        screen.draw("…")
    end = screen.cursor.x
    screen.cursor.fg = tab_bg
    screen.cursor.bg = as_rgb(color_as_int(draw_data.default_bg))
    screen.draw("▌")
    return end
