local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local FocusManager = require("ui/widget/focusmanager")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local RenderText = require("ui/rendertext")
local RightContainer = require("ui/widget/container/rightcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local UnderlineContainer = require("ui/widget/container/underlinecontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local util = require("ffi/util")
local _ = require("gettext")
local Input = Device.input
local Screen = Device.screen
local getMenuText = require("util").getMenuText

--[[
Widget that displays a shortcut icon for menu item
--]]
local ItemShortCutIcon = WidgetContainer:new{
    dimen = Geom:new{ w = 22, h = 22 },
    key = nil,
    bordersize = 2,
    radius = 0,
    style = "square",
}

function ItemShortCutIcon:init()
    if not self.key then
        return
    end

    local radius = 0
    local background = Blitbuffer.COLOR_WHITE
    if self.style == "rounded_corner" then
        radius = math.floor(self.width/2)
    elseif self.style == "grey_square" then
        background = Blitbuffer.gray(0.2)
    end

    --@TODO calculate font size by icon size  01.05 2012 (houqp)
    local sc_face
    if self.key:len() > 1 then
        sc_face = Font:getFace("ffont", 14)
    else
        sc_face = Font:getFace("scfont", 22)
    end

    self[1] = FrameContainer:new{
        padding = 0,
        bordersize = self.bordersize,
        radius = radius,
        background = background,
        dimen = self.dimen,
        CenterContainer:new{
            dimen = self.dimen,
            TextWidget:new{
                text = self.key,
                face = sc_face,
            },
        },
    }
end

--[[
NOTICE:
@menu entry must be provided in order to close the menu
--]]
local MenuCloseButton = InputContainer:new{
    overlap_align = "right",
    menu = nil,
    dimen = Geom:new{},
}

function MenuCloseButton:init()
    self[1] = TextWidget:new{
        text = "×",
        face = Font:getFace("cfont", 32),
    }

    local text_size = self[1]:getSize()
    self.dimen = Geom:new{
        w = text_size.w*2,
        h = text_size.h*2,
    }

    self.ges_events.Close = {
        GestureRange:new{
            ges = "tap",
            range = self.dimen,
        },
        doc = "Close menu",
    }
end

function MenuCloseButton:onClose()
    self.menu:onClose()
    return true
end

--[[
Widget that displays an item for menu
--]]
local MenuItem = InputContainer:new{
    text = nil,
    show_parent = nil,
    detail = nil,
    face = Font:getFace("cfont", 30),
    info_face = Font:getFace("infont", 15),
    dimen = nil,
    shortcut = nil,
    shortcut_style = "square",
    _underline_container = nil,
}

function MenuItem:init()
    local shortcut_icon_dimen = Geom:new()
    if self.shortcut then
        shortcut_icon_dimen.w = math.floor(self.dimen.h*4/5)
        shortcut_icon_dimen.h = shortcut_icon_dimen.w
    end

    self.detail = self.text
    -- 15 for HorizontalSpan,
    self.content_width = self.dimen.w - shortcut_icon_dimen.w - 15

    -- we need this table per-instance, so we declare it here
    if Device:isTouchDevice() then
        self.ges_events = {
            TapSelect = {
                GestureRange:new{
                    ges = "tap",
                    range = self.dimen,
                },
                doc = "Select Menu Item",
            },
            HoldSelect = {
                GestureRange:new{
                    ges = "hold",
                    range = self.dimen,
                },
                doc = "Hold Menu Item",
            },
        }
    end
    if Device:hasKeys() then
        self.active_key_events = {
            Select = { {"Press"}, doc = "chose selected item" },
        }
    end

    local mandatory = self.mandatory and ""..self.mandatory.." " or ""
    local mandatory_w = RenderText:sizeUtf8Text(0, self.dimen.w, self.info_face,
                    ""..mandatory, true, self.bold).x

    local state_button_width = self.state_size.w or 0
    local my_text = self.text and ""..self.text or ""
    local w = RenderText:sizeUtf8Text(0, self.dimen.w, self.face, my_text, true, self.bold).x
    if w + mandatory_w + state_button_width >= self.content_width then
        if Device:hasKeyboard() then
            self.active_key_events.ShowItemDetail = {
                {"Right"}, doc = "show item detail"
            }
        end
        local indicator = "\226\128\166 " -- an ellipsis
        local indicator_w = RenderText:sizeUtf8Text(0, self.dimen.w, self.face,
                        indicator, true, self.bold).x
        self.text = RenderText:getSubTextByWidth(my_text, self.face,
            self.content_width - indicator_w - mandatory_w - state_button_width,
            true, self.bold) .. indicator
    end

    local state_button = self.state or HorizontalSpan:new{
        width = state_button_width,
    }
    local state_indent = self.state and self.state.indent or ""
    local state_container = LeftContainer:new{
        dimen = Geom:new{w = self.content_width/2, h = self.dimen.h},
        HorizontalGroup:new{
            HorizontalSpan:new{
                width = RenderText:sizeUtf8Text(0, self.dimen.w, self.face,
                                state_indent, true, self.bold).x,
            },
            state_button
        }
    }
    local text_container = LeftContainer:new{
        dimen = Geom:new{w = self.content_width, h = self.dimen.h},
        HorizontalGroup:new{
            HorizontalSpan:new{
                width = self.state_size.w,
            },
            TextWidget:new{
                text = self.text,
                face = self.face,
                bold = self.bold,
            }
        }
    }

    local mandatory_container = RightContainer:new{
        dimen = Geom:new{w = self.content_width, h = self.dimen.h},
        TextWidget:new{
            text = mandatory,
            face = self.info_face,
            bold = self.bold,
        }
    }

    self._underline_container = UnderlineContainer:new{
        vertical_align = "center",
        dimen = Geom:new{
            w = self.content_width,
            h = self.dimen.h
        },
        HorizontalGroup:new{
            align = "center",
            OverlapGroup:new{
                dimen = Geom:new{w = self.content_width, h = self.dimen.h},
                state_container,
                text_container,
                mandatory_container,
            },
        }
    }
    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        HorizontalGroup:new{
            align = "center",
            HorizontalSpan:new{ width = 5 },
            ItemShortCutIcon:new{
                dimen = shortcut_icon_dimen,
                key = self.shortcut,
                style = self.shortcut_style,
            },
            HorizontalSpan:new{ width = 10 },
            self._underline_container
        }
    }
end

function MenuItem:onFocus()
    self._underline_container.color = Blitbuffer.COLOR_BLACK
    self.key_events = self.active_key_events
    return true
end

function MenuItem:onUnfocus()
    self._underline_container.color = Blitbuffer.COLOR_WHITE
    self.key_events = {}
    return true
end

function MenuItem:onShowItemDetail()
    UIManager:show(InfoMessage:new{ text = self.detail, })
    return true
end

function MenuItem:getGesPosition(ges)
    local dimen = self[1].dimen
    return {
        x = (ges.pos.x - dimen.x)/dimen.w,
        y = (ges.pos.y - dimen.y)/dimen.h,
    }
end

function MenuItem:onTapSelect(arg, ges)
    local pos = self:getGesPosition(ges)
    self[1].invert = true
    local refreshfunc = function()
        return "ui", self[1].dimen
    end
    UIManager:setDirty(self.show_parent, refreshfunc)
    UIManager:scheduleIn(0.1, function()
        self[1].invert = false
        UIManager:setDirty(self.show_parent, refreshfunc)
        logger.dbg("creating coroutine for menu select")
        local co = coroutine.create(function()
            self.menu:onMenuSelect(self.table, pos)
        end)
        coroutine.resume(co)
    end)
    return true
end

function MenuItem:onHoldSelect(arg, ges)
    local pos = self:getGesPosition(ges)
    self[1].invert = true
    local refreshfunc = function()
        return "ui", self[1].dimen
    end
    UIManager:setDirty(self.show_parent, refreshfunc)
    UIManager:scheduleIn(0.1, function()
        self[1].invert = false
        UIManager:setDirty(self.show_parent, refreshfunc)
        self.menu:onMenuHold(self.table, pos)
    end)
    return true
end

--[[
Widget that displays menu
--]]
local Menu = FocusManager:new{
    show_parent = nil,
    -- face for displaying item contents
    cface = Font:getFace("cfont"),
    -- face for menu title
    tface = Font:getFace("tfont"),
    -- face for paging info display
    fface = Font:getFace("ffont"),
    -- font for item shortcut
    sface = Font:getFace("scfont"),

    title = "No Title",
    -- default width and height
    width = 500,
    -- height will be calculated according to item number if not given
    height = nil,
    header_padding = Screen:scaleBySize(10),
    dimen = Geom:new{},
    item_table = {},
    item_shortcuts = {
        "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
        "A", "S", "D", "F", "G", "H", "J", "K", "L", "Del",
        "Z", "X", "C", "V", "B", "N", "M", ".", "Sym", "Enter",
    },
    item_table_stack = nil,
    is_enable_shortcut = true,

    item_dimen = nil,
    page = 1,

    item_group = nil,
    page_info = nil,
    page_return = nil,

    paths = {},  -- table to trace navigation path

    -- set this to true to not paint as popup menu
    is_borderless = false,
    -- if you want to embed the menu widget into another widget, set
    -- this to false
    is_popout = true,
    -- set this to true to add close button
    has_close_button = true,
    -- close_callback is a function, which is executed when menu is closed
    -- it is usually set by the widget which creates the menu
    close_callback = nil
}

function Menu:_recalculateDimen()
    self.dimen.w = self.width
    self.item_dimen = Geom:new{
        w = self.dimen.w,
        h = Screen:scaleBySize(46), -- hardcoded for now
    }
    -- if height not given, dynamically calculate it
    self.dimen.h = self.height or (#self.item_table + 2) * self.item_dimen.h
    if self.dimen.h > Screen:getHeight() then
        self.dimen.h = Screen:getHeight()
    end
    -- header and footer should approximately take up space of 2 items
    self.perpage = math.floor(self.dimen.h / self.item_dimen.h) - (self.no_title and 1 or 2)
    self.page_num = math.ceil(#self.item_table / self.perpage)
end

function Menu:init()
    self.show_parent = self.show_parent or self
    self.item_table_stack = {}
    self:_recalculateDimen()
    self.page = 1

    -----------------------------------
    -- start to set up widget layout --
    -----------------------------------
    self.menu_title = TextWidget:new{
        overlap_align = "center",
        text = self.title,
        face = self.tface,
    }
    -- group for title bar
    self.title_bar = OverlapGroup:new{
        dimen = {w = self.dimen.w, h = self.menu_title:getSize().h},
        self.menu_title,
    }
    -- group for items
    self.item_group = VerticalGroup:new{}
    -- group for page info
    self.page_info_left_chev = Button:new{
        icon = "resources/icons/appbar.chevron.left.png",
        callback = function() self:onPrevPage() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_right_chev = Button:new{
        icon = "resources/icons/appbar.chevron.right.png",
        callback = function() self:onNextPage() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_first_chev = Button:new{
        icon = "resources/icons/appbar.chevron.first.png",
        callback = function() self:onFirstPage() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_last_chev = Button:new{
        icon = "resources/icons/appbar.chevron.last.png",
        callback = function() self:onLastPage() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_info_spacer = HorizontalSpan:new{
        width = Screen:scaleBySize(32),
    }
    self.page_info_left_chev:hide()
    self.page_info_right_chev:hide()
    self.page_info_first_chev:hide()
    self.page_info_last_chev:hide()

    self.page_info_text = Button:new{
        text = "",
        hold_input = {
            title = _("Input page number"),
            type = "number",
            hint_func = function()
                return "(" .. "1 - " .. self.page_num .. ")"
            end,
            callback = function(input)
                local page = tonumber(input)
                if page and page >= 1 and page <= self.page_num then
                    self:onGotoPage(page)
                end
            end,
        },
        bordersize = 0,
        text_font_face = "cfont",
        text_font_size = 20,
        text_font_bold = false,
    }
    self.page_info = HorizontalGroup:new{
        self.page_info_first_chev,
        self.page_info_spacer,
        self.page_info_left_chev,
        self.page_info_text,
        self.page_info_right_chev,
        self.page_info_spacer,
        self.page_info_last_chev,
    }

    -- return button
    self.page_return_arrow = Button:new{
        icon = "resources/icons/appbar.arrow.left.up.png",
        callback = function() self:onReturn() end,
        bordersize = 0,
        show_parent = self,
    }
    self.page_return_arrow:hide()
    self.return_button = HorizontalGroup:new{
        HorizontalSpan:new{
            width = Screen:scaleBySize(5),
        },
        self.page_return_arrow,
    }

    local header = VerticalGroup:new{
        VerticalSpan:new{width = self.header_padding},
        self.title_bar,
    }
    local body = self.item_group
    local footer = BottomContainer:new{
        dimen = self.dimen:copy(),
        self.page_info,
    }
    local page_return = BottomContainer:new{
        dimen = self.dimen:copy(),
        WidgetContainer:new{
            dimen = Geom:new{
                w = Screen:getWidth(),
                h = self.page_return_arrow:getSize().h,
            },
            self.return_button,
        }
    }

    local content
    if self.no_title then
        content = OverlapGroup:new{
            dimen = self.dimen:copy(),
            VerticalGroup:new{
                align = "left",
                body,
            },
            page_return,
            footer,
        }
    else
        content = OverlapGroup:new{
            dimen = self.dimen:copy(),
            VerticalGroup:new{
                align = "left",
                header,
                body,
            },
            page_return,
            footer,
        }
    end

    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = self.is_borderless and 0 or 2,
        padding = 0,
        margin = 0,
        radius = self.is_popout and math.floor(self.dimen.w/20) or 0,
        content
    }

    ------------------------------------------
    -- start to set up input event callback --
    ------------------------------------------
    if Device:isTouchDevice() then
        if self.has_close_button then
            table.insert(self.title_bar,
                         MenuCloseButton:new{ menu = self })
        end
        -- watch for outer region if it's a self contained widget
        if self.is_popout then
            self.ges_events.TapCloseAllMenus = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{
                        x = 0, y = 0,
                        w = Screen:getWidth(),
                        h = Screen:getHeight(),
                    }
                }
            }
        end
        self.ges_events.Swipe = {
            GestureRange:new{
                ges = "swipe",
                range = self.dimen,
            }
        }
        self.ges_events.Close = self.on_close_ges
    end

    if not Device:hasKeyboard() then
        -- remove menu item shortcut for K4
        self.is_enable_shortcut = false
    end

    if Device:hasKeys() then
        -- set up keyboard events
        self.key_events.Close = { {"Back"}, doc = "close menu" }
        self.key_events.NextPage = {
            {Input.group.PgFwd}, doc = "goto next page of the menu"
        }
        self.key_events.PrevPage = {
            {Input.group.PgBack}, doc = "goto previous page of the menu"
        }
        -- we won't catch presses to "Right", leave that to MenuItem.
        self.key_events.FocusRight = nil
        -- shortcut icon is not needed for touch device
        if self.is_enable_shortcut then
            self.key_events.SelectByShortCut = { {self.item_shortcuts} }
        end
        self.key_events.Select = {
            {"Press"}, doc = "select current menu item"
        }
    end


    if #self.item_table > 0 then
        -- if the table is not yet initialized, this call
        -- must be done manually:
        self.page = math.ceil((self.item_table.current or 1) / self.perpage)
    end
    if self.path_items then
        self:refreshPath()
    else
        self:updateItems()
    end
end

function Menu:onCloseWidget()
    -- FIXME:
    -- we cannot refresh regionally using the dimen field
    -- because some menus without menu title use VerticalGroup to include
    -- a text widget which is not calculated into the dimen.
    -- For example, it's a dirty hack to use two menus(one this menu and one
    -- touch menu) in the filemanager in order to capture tap gesture to popup
    -- the filemanager menu.
    UIManager:setDirty(nil, "partial")
end

function Menu:updateItems(select_number)
    local old_dimen = self.dimen and self.dimen:copy()
    -- self.layout must be updated for focusmanager
    self.layout = {}
    self.item_group:clear()
    self.page_info:resetLayout()
    self.return_button:resetLayout()
    self:_recalculateDimen()

    -- default to select the first item
    if not select_number then
        select_number = 1
    end

    for c = 1, math.min(self.perpage, #self.item_table) do
        -- calculate index in item_table
        local i = (self.page - 1) * self.perpage + c
        if i <= #self.item_table then
            local item_shortcut = nil
            local shortcut_style = "square"
            if self.is_enable_shortcut then
                -- give different shortcut_style to keys in different
                -- lines of keyboard
                if c >= 11 and c <= 20 then
                    --shortcut_style = "rounded_corner"
                    shortcut_style = "grey_square"
                end
                item_shortcut = self.item_shortcuts[c]
                if item_shortcut == "Enter" then
                    item_shortcut = "Ent"
                end
            end
            local item_tmp = MenuItem:new{
                show_parent = self.show_parent,
                state = self.item_table[i].state,
                state_size = self.state_size or {},
                text = getMenuText(self.item_table[i]),
                mandatory = self.item_table[i].mandatory,
                bold = self.item_table.current == i or self.item_table[i].bold == true,
                face = self.cface,
                dimen = self.item_dimen:new(),
                shortcut = item_shortcut,
                shortcut_style = shortcut_style,
                table = self.item_table[i],
                menu = self,
            }
            table.insert(self.item_group, item_tmp)
            -- this is for focus manager
            table.insert(self.layout, {item_tmp})
        end -- if i <= self.items
    end -- for c=1, self.perpage
    if self.item_group[1] then
        if not Device:isTouchDevice() then
            -- only draw underline for nontouch device
            -- reset focus manager accordingly
            self.selected = { x = 1, y = select_number }
            -- set focus to requested menu item
            self.item_group[select_number]:onFocus()
        end
        -- update page information
        self.page_info_text:setText(util.template(_("page %1 of %2"), self.page, self.page_num))
        self.page_info_left_chev:showHide(self.page_num > 1)
        self.page_info_right_chev:showHide(self.page_num > 1)
        self.page_info_first_chev:showHide(self.page_num > 2)
        self.page_info_last_chev:showHide(self.page_num > 2)
        self.page_return_arrow:showHide(self.onReturn ~= nil)

        self.page_info_left_chev:enableDisable(self.page > 1)
        self.page_info_right_chev:enableDisable(self.page < self.page_num)
        self.page_info_first_chev:enableDisable(self.page > 1)
        self.page_info_last_chev:enableDisable(self.page < self.page_num)
        self.page_return_arrow:enableDisable(#self.paths > 0)
    else
        self.page_info_text:setText(_("No choices available"))
    end

    UIManager:setDirty("all", function()
        local refresh_dimen =
            old_dimen and old_dimen:combine(self.dimen)
            or self.dimen
        return "ui", refresh_dimen
    end)
end

--[[
    the itemnumber paramter determines menu page number after switching item table
    1. itemnumber >= 0
        the page number is calculated with items per page
    2. itemnumber == nil
        the page number is 1
    3. itemnumber is negative number
        the page number is not changed, used when item_table is appended with
        new entries
--]]
function Menu:switchItemTable(new_title, new_item_table, itemnumber)
    if self.menu_title and new_title then
        self.menu_title.text = new_title
    end

    if itemnumber == nil then
        self.page = 1
    elseif itemnumber >= 0 then
        self.page = math.ceil(itemnumber / self.perpage)
    end

    -- make sure current page is in right page range
    local max_pages = math.ceil(#new_item_table / self.perpage)
    if self.page > max_pages then
        self.page = max_pages
    end

    self.item_table = new_item_table
    self:updateItems()
end

function Menu:onSelectByShortCut(_, keyevent)
    for k,v in ipairs(self.item_shortcuts) do
        if k > self.perpage then
            break
        elseif v == keyevent.key then
            if self.item_table[(self.page-1)*self.perpage + k] then
                self:onMenuSelect(self.item_table[(self.page-1)*self.perpage + k])
            end
            break
        end
    end
    return true
end

function Menu:onWrapFirst()
    if self.page > 1 then
        self.page = self.page - 1
        local end_position = self.perpage
        if self.page == self.page_num then
            end_position = #self.item_table % self.perpage
        end
        self:updateItems(end_position)
    end
    return false
end

function Menu:onWrapLast()
    if self.page < self.page_num then
        self:onNextPage()
    end
    return false
end

--[[
override this function to process the item selected in a different manner
]]--
function Menu:onMenuSelect(item)
    if item.sub_item_table == nil then
        if self.close_callback then
            self.close_callback()
        end
        self:onMenuChoice(item)
    else
        -- save menu title for later resume
        self.item_table.title = self.title
        table.insert(self.item_table_stack, self.item_table)
        self:switchItemTable(item.text, item.sub_item_table)
    end
    return true
end

--[[
    default to call item callback
    override this function to handle the choice
--]]
function Menu:onMenuChoice(item)
    if item.callback then
        item.callback()
    end
    return true
end

--[[
override this function to process the item hold in a different manner
]]--
function Menu:onMenuHold(item)
    return true
end

function Menu:onNextPage()
    if self.onNext and self.page == self.page_num - 1 then
        self:onNext()
    end
    if self.page < self.page_num then
        self.page = self.page + 1
        self:updateItems()
    elseif self.page == self.page_num then
        -- on the last page, we check if we're on the last item
        local end_position = #self.item_table % self.perpage
        if end_position == 0 then
            end_position = self.perpage
        end
        if end_position ~= self.selected.y then
            self:updateItems(end_position)
        end
        self.page = 1
        self:updateItems()
    end
    return true
end

function Menu:onPrevPage()
    if self.page > 1 then
        self.page = self.page - 1
    elseif self.page == 1 then
        self.page = self.page_num
    end
    self:updateItems()
    return true
end

function Menu:onFirstPage()
    self.page = 1
    self:updateItems()
    return true
end

function Menu:onLastPage()
    self.page = self.page_num
    self:updateItems()
    return true
end

function Menu:onGotoPage(page)
    self.page = page
    self:updateItems()
    return true
end

function Menu:onSelect()
    local item = self.item_table[(self.page-1)*self.perpage+self.selected.y]
    if item then
        self:onMenuSelect(item)
    end
    return true
end

function Menu:onClose()
    local table_length = #self.item_table_stack
    if table_length == 0 then
        self:onCloseAllMenus()
    else
        -- back to parent menu
        local parent_item_table = table.remove(self.item_table_stack, table_length)
        self:switchItemTable(parent_item_table.title, parent_item_table)
    end
    return true
end

function Menu:onCloseAllMenus()
    UIManager:close(self)
    if self.close_callback then
        self.close_callback()
    end
    return true
end

function Menu:onTapCloseAllMenus(arg, ges_ev)
    if ges_ev.pos:notIntersectWith(self.dimen) then
        self:onCloseAllMenus()
        return true
    end
end

function Menu:onSwipe(arg, ges_ev)
    if ges_ev.direction == "west" then
        self:onNextPage()
    elseif ges_ev.direction == "east" then
        self:onPrevPage()
    end
end

function Menu.itemTableFromTouchMenu(t)
    local item_t = {}
    for k,v in pairs(t) do
        local item = { text = k }
        if v.callback then
            item.callback = v.callback
        else
            item.sub_item_table = v
        end
        table.insert(item_t, item)
    end
    return item_t
end

return Menu
