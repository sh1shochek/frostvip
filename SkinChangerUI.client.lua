--[[
    Skin Changer UI — визуальная копия по референсу 1016x788.

    Установка:
    1) Roblox Studio -> StarterPlayer -> StarterPlayerScripts.
    2) Создайте LocalScript.
    3) Вставьте в него весь этот код.

    Скрипт создаёт страницу Add, каталог Cats/Dogs и окно настроек.
    После Confirm выбранный скин появляется новой карточкой на главной.
    Изображения задаются в таблице SKIN_IMAGES в начале файла.
    Подтверждение вызывает BindableEvent SkinSelected.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("SkinChangerGui")
if oldGui then
    oldGui:Destroy()
end

-- Координаты ниже сохранены в логической сетке 1016x788,
-- но при создании переводятся в нативный компактный размер.
-- Благодаря этому текст больше не размывается глобальным UIScale 0.44.
local REFERENCE_SIZE = Vector2.new(1016, 788)
local LAYOUT_SCALE = 0.44
local NATIVE_SIZE = Vector2.new(
    math.round(REFERENCE_SIZE.X * LAYOUT_SCALE),
    math.round(REFERENCE_SIZE.Y * LAYOUT_SCALE)
)

-- 1 = нативные примерно 447x347 px без растягивания.
local MENU_SCALE = 1

-- Roblox не загружает .ttf по GitHub-ссылке напрямую.
-- Загрузите файл ProggyCleanAtlas.png в Asset Manager и вставьте ID сюда.
-- Пока строка пустая, используется увеличенный встроенный Enum.Font.Code.
local PROGGY_ATLAS_IMAGE = ""

-- Загруженный файл является Decal, поэтому используем его thumbnail-адрес.
-- Так ImageLabel получает саму картинку, а не контейнер Decal.
local REMOVE_CROSS_IMAGE = "rbxthumb://type=Asset&id=126363283368482&w=420&h=420"

local TEXT_READABILITY_SCALE = 1.18
local PROGGY_CELL_SIZE = Vector2.new(12, 20)
local PROGGY_COLUMNS = 16

local COLORS = {
    gold = Color3.fromRGB(226, 170, 30),
    goldDark = Color3.fromRGB(111, 82, 22),
    -- Тонкая обводка, которая идёт сразу рядом с оранжевой линией.
    outerInnerLine = Color3.fromRGB(38, 37, 47),
    window = Color3.fromRGB(16, 16, 21),
    panel = Color3.fromRGB(22, 22, 29),
    panelHover = Color3.fromRGB(25, 25, 33),
    catalog = Color3.fromRGB(23, 23, 23),
    catalogCard = Color3.fromRGB(30, 30, 32),
    catalogCardHover = Color3.fromRGB(35, 35, 38),
    catalogBlue = Color3.fromRGB(43, 67, 139),
    lineDark = Color3.fromRGB(8, 8, 12),
    -- Светлая замена почти чёрной обводки большой внутренней панели.
    contentOutline = Color3.fromRGB(28, 27, 36),
    line = Color3.fromRGB(31, 30, 40),
    lineSoft = Color3.fromRGB(26, 25, 34),
    text = Color3.fromRGB(224, 224, 226),
    textSoft = Color3.fromRGB(184, 184, 187),
    white = Color3.fromRGB(239, 239, 240),
    plus = Color3.fromRGB(18, 18, 23),
}

-- Вставьте сюда ID изображений, загруженных через Roblox Asset Manager.
-- Можно указать только число, например: "1234567890".
local SKIN_IMAGES = {
    StandingCat = "",
    AngryCat = "",
    HidingCat = "",
    SmartCat = "",
    RoseDog = "",
    WhiteDog = "",
    BlackDog = "",
}

local function assetId(value)
    if value == nil or value == "" or value == "0" then
        return ""
    end

    value = tostring(value)
    if string.find(value, "rbxasset", 1, true)
        or string.find(value, "rbxthumb", 1, true) then
        return value
    end

    return "rbxassetid://" .. value
end

local function scaleLayoutUDim2(value)
    return UDim2.new(
        value.X.Scale,
        math.round(value.X.Offset * LAYOUT_SCALE),
        value.Y.Scale,
        math.round(value.Y.Offset * LAYOUT_SCALE)
    )
end

local function attachProggyBitmapFont(textObject)
    local atlasImage = assetId(PROGGY_ATLAS_IMAGE)
    if atlasImage == "" then
        return
    end

    local originalTransparency = textObject.TextTransparency
    textObject.TextTransparency = 1

    local textRoot = Instance.new("Frame")
    textRoot.Name = "ProggyCleanBitmapText"
    textRoot.Position = UDim2.fromScale(0, 0)
    textRoot.Size = UDim2.fromScale(1, 1)
    textRoot.BackgroundTransparency = 1
    textRoot.BorderSizePixel = 0
    textRoot.ClipsDescendants = true
    textRoot.ZIndex = textObject.ZIndex + 1
    textRoot.Parent = textObject

    local glyphs = {}

    local function rebuild()
        for _, child in ipairs(textRoot:GetChildren()) do
            child:Destroy()
        end
        table.clear(glyphs)

        local text = textObject.Text
        if text == "" then
            return
        end

        local textSize = textObject.TextSize
        local advance = math.max(1, math.round(textSize * 0.525))
        local totalWidth = #text * advance

        local line = Instance.new("Frame")
        line.Name = "Line"
        line.Size = UDim2.fromOffset(totalWidth, textSize)
        line.BackgroundTransparency = 1
        line.BorderSizePixel = 0
        line.ZIndex = textObject.ZIndex + 1
        line.Parent = textRoot

        if textObject.TextXAlignment == Enum.TextXAlignment.Left then
            line.AnchorPoint = Vector2.new(0, line.AnchorPoint.Y)
            line.Position = UDim2.new(0, 0, line.Position.Y.Scale, line.Position.Y.Offset)
        elseif textObject.TextXAlignment == Enum.TextXAlignment.Right then
            line.AnchorPoint = Vector2.new(1, line.AnchorPoint.Y)
            line.Position = UDim2.new(1, 0, line.Position.Y.Scale, line.Position.Y.Offset)
        else
            line.AnchorPoint = Vector2.new(0.5, line.AnchorPoint.Y)
            line.Position = UDim2.new(0.5, 0, line.Position.Y.Scale, line.Position.Y.Offset)
        end

        if textObject.TextYAlignment == Enum.TextYAlignment.Top then
            line.AnchorPoint = Vector2.new(line.AnchorPoint.X, 0)
            line.Position = UDim2.new(line.Position.X.Scale, line.Position.X.Offset, 0, 0)
        elseif textObject.TextYAlignment == Enum.TextYAlignment.Bottom then
            line.AnchorPoint = Vector2.new(line.AnchorPoint.X, 1)
            line.Position = UDim2.new(line.Position.X.Scale, line.Position.X.Offset, 1, 0)
        else
            line.AnchorPoint = Vector2.new(line.AnchorPoint.X, 0.5)
            line.Position = UDim2.new(line.Position.X.Scale, line.Position.X.Offset, 0.5, 0)
        end

        for index = 1, #text do
            local byte = string.byte(text, index)
            if byte < 32 or byte > 126 then
                byte = string.byte("?")
            end

            local glyphIndex = byte - 32
            local column = glyphIndex % PROGGY_COLUMNS
            local row = math.floor(glyphIndex / PROGGY_COLUMNS)

            local glyph = Instance.new("ImageLabel")
            glyph.Name = "Glyph_" .. tostring(index)
            glyph.Position = UDim2.fromOffset((index - 1) * advance, 0)
            glyph.Size = UDim2.fromOffset(advance, textSize)
            glyph.BackgroundTransparency = 1
            glyph.BorderSizePixel = 0
            glyph.Image = atlasImage
            glyph.ImageColor3 = textObject.TextColor3
            glyph.ImageTransparency = originalTransparency
            glyph.ImageRectOffset = Vector2.new(
                column * PROGGY_CELL_SIZE.X,
                row * PROGGY_CELL_SIZE.Y
            )
            glyph.ImageRectSize = PROGGY_CELL_SIZE
            glyph.ScaleType = Enum.ScaleType.Stretch
            glyph.ResampleMode = Enum.ResamplerMode.Pixelated
            glyph.ZIndex = textObject.ZIndex + 2
            glyph.Parent = line

            table.insert(glyphs, glyph)
        end
    end

    textObject:GetPropertyChangedSignal("Text"):Connect(rebuild)
    textObject:GetPropertyChangedSignal("TextSize"):Connect(rebuild)
    textObject:GetPropertyChangedSignal("TextColor3"):Connect(function()
        for _, glyph in ipairs(glyphs) do
            glyph.ImageColor3 = textObject.TextColor3
        end
    end)

    rebuild()
end

local function create(className, properties)
    local object = Instance.new(className)
    local isTextObject = className == "TextLabel" or className == "TextButton" or className == "TextBox"

    for property, value in pairs(properties) do
        if property ~= "Parent" then
            if typeof(value) == "UDim2" then
                object[property] = scaleLayoutUDim2(value)
            elseif isTextObject and property == "TextSize" then
                object.TextSize = math.max(
                    1,
                    math.round(value * TEXT_READABILITY_SCALE * LAYOUT_SCALE)
                )
            elseif className == "UIStroke" and property == "Thickness" then
                object.Thickness = math.max(1, math.round(value * LAYOUT_SCALE))
            else
                object[property] = value
            end
        end
    end

    object.Parent = properties.Parent

    if isTextObject and object.Text ~= "" then
        attachProggyBitmapFont(object)
    end

    return object
end

local function addCorner(parent, radius)
    return create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(radius, 0),
    })
end

-- Рамка из вложенных Frame даёт более чёткий 1 px результат, чем UIStroke.
local function borderedFrame(parent, name, position, size, borderColor, fillColor, thickness, zIndex)
    local border = create("Frame", {
        Parent = parent,
        Name = name,
        Position = position,
        Size = size,
        BackgroundColor3 = borderColor,
        BorderSizePixel = 0,
        ZIndex = zIndex,
    })

    local fill = create("Frame", {
        Parent = border,
        Name = "Fill",
        Position = UDim2.fromOffset(thickness, thickness),
        Size = UDim2.new(1, -(thickness * 2), 1, -(thickness * 2)),
        BackgroundColor3 = fillColor,
        BorderSizePixel = 0,
        ZIndex = zIndex + 1,
    })

    return border, fill
end

local gui = create("ScreenGui", {
    Parent = playerGui,
    Name = "SkinChangerGui",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    AutoLocalize = false,
})

local viewport = create("Frame", {
    Parent = gui,
    Name = "Viewport",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
})

local canvas = create("Frame", {
    Parent = viewport,
    Name = "ReferenceCanvas_1016x788",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(REFERENCE_SIZE.X, REFERENCE_SIZE.Y),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
})

local uiScale = create("UIScale", {
    Parent = canvas,
    Scale = 1,
})

-- Непрозрачная крышка плавно раскрывает интерфейс при первом запуске.
-- В отличие от CanvasGroup на всём окне, она не размывает текст.
local startupCover = create("Frame", {
    Parent = canvas,
    Name = "StartupRevealCover",
    Position = UDim2.fromOffset(10, 5),
    Size = UDim2.fromOffset(1004, 778),
    BackgroundColor3 = Color3.fromRGB(8, 8, 12),
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    ZIndex = 100,
})

local function updateScale()
    local available = viewport.AbsoluteSize
    if available.X <= 0 or available.Y <= 0 then
        return
    end

    -- Сохраняет исходные пропорции и пиксельную геометрию на любом экране.
    -- Окно больше не растягивается почти на весь экран.
    -- Оно остаётся около 440x340 px и только уменьшается,
    -- если экран физически меньше этого размера.
    uiScale.Scale = math.min(
        MENU_SCALE,
        available.X / NATIVE_SIZE.X,
        available.Y / NATIVE_SIZE.Y
    )
end

viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
task.defer(updateScale)

-- Внешняя золотая линия теперь является самой крайней обводкой:
-- перед ней нет чёрной рамки или отступа.
local goldBorder, goldInside = borderedFrame(
    canvas,
    "GoldWindowBorder",
    UDim2.fromOffset(12, 7),
    UDim2.fromOffset(1000, 774),
    COLORS.gold,
    COLORS.window,
    2,
    2
)

-- Тёмная линия начинается сразу после золотой, без коричневого зазора.
local darkBorder, window = borderedFrame(
    goldInside,
    "DarkInnerBorder",
    UDim2.fromOffset(0, 0),
    UDim2.fromScale(1, 1),
    COLORS.outerInnerLine,
    COLORS.window,
    2,
    4
)

window.ClipsDescendants = true

-- Заголовок. Enum.Font.Code — наиболее близкий встроенный шрифт Roblox
-- к ProggyClean. Для полного совпадения нужен bitmap/sprite-шрифт.
local titleShadow = create("TextLabel", {
    Parent = canvas,
    Name = "TitleShadow",
    Position = UDim2.fromOffset(28, 12),
    Size = UDim2.fromOffset(260, 30),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Skin Changer",
    TextColor3 = Color3.fromRGB(0, 0, 0),
    TextTransparency = 0.1,
    TextSize = 21,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 8,
})

local title = create("TextLabel", {
    Parent = canvas,
    Name = "Title",
    Position = UDim2.fromOffset(27, 10),
    Size = UDim2.fromOffset(260, 30),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Skin Changer",
    TextColor3 = COLORS.text,
    TextStrokeColor3 = Color3.fromRGB(3, 3, 5),
    TextStrokeTransparency = 0.25,
    TextSize = 21,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 9,
})

-- Разделитель под заголовком: тёмная линия + мягкая внутренняя линия.
create("Frame", {
    Parent = canvas,
    Name = "HeaderSeparatorDark",
    Position = UDim2.fromOffset(15, 46),
    Size = UDim2.fromOffset(994, 2),
    BackgroundColor3 = COLORS.lineDark,
    BorderSizePixel = 0,
    ZIndex = 6,
})

create("Frame", {
    Parent = canvas,
    Name = "HeaderSeparatorSoft",
    Position = UDim2.fromOffset(17, 48),
    Size = UDim2.fromOffset(990, 1),
    BackgroundColor3 = COLORS.lineSoft,
    BorderSizePixel = 0,
    ZIndex = 6,
})

-- Внешняя область контента.
local contentBorder, contentFill = borderedFrame(
    canvas,
    "ContentOuterBorder",
    UDim2.fromOffset(29, 47),
    UDim2.fromOffset(967, 717),
    COLORS.contentOutline,
    COLORS.window,
    2,
    5
)
contentFill.ClipsDescendants = true

-- Большая пустая панель/галерея.
local galleryBorder, gallery = borderedFrame(
    canvas,
    "GalleryBorder",
    UDim2.fromOffset(40, 59),
    UDim2.fromOffset(944, 694),
    COLORS.line,
    COLORS.panel,
    2,
    7
)
gallery.ClipsDescendants = true

-- Главная страница (Add и уже добавленные скины) находится в CanvasGroup,
-- чтобы вся страница могла плавно появляться и исчезать.
local addPageLayer = create("CanvasGroup", {
    Parent = canvas,
    Name = "AddPageLayer",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    GroupTransparency = 0,
    Visible = true,
    ZIndex = 9,
})

-- Карточка Add в левом верхнем углу галереи.
local cardBorder, card = borderedFrame(
    addPageLayer,
    "AddCardBorder",
    UDim2.fromOffset(49, 68),
    UDim2.fromOffset(181, 181),
    COLORS.line,
    COLORS.panel,
    2,
    10
)
card.ClipsDescendants = true

-- Тень круглой кнопки.
local circleShadow = create("Frame", {
    Parent = card,
    Name = "CircleShadow",
    Position = UDim2.fromOffset(69, 51),
    Size = UDim2.fromOffset(44, 44),
    BackgroundColor3 = Color3.fromRGB(2, 2, 4),
    BorderSizePixel = 0,
    ZIndex = 12,
})
addCorner(circleShadow, 1)

-- Белый круг.
local plusCircle = create("Frame", {
    Parent = card,
    Name = "PlusCircle",
    Position = UDim2.fromOffset(69, 49),
    Size = UDim2.fromOffset(44, 44),
    BackgroundColor3 = COLORS.white,
    BorderSizePixel = 0,
    ZIndex = 13,
})
addCorner(plusCircle, 1)

create("UIStroke", {
    Parent = plusCircle,
    Color = Color3.fromRGB(9, 9, 12),
    Thickness = 1.5,
    Transparency = 0,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})

-- Знак плюс собран из двух прямоугольников, поэтому не зависит от шрифта.
create("Frame", {
    Parent = plusCircle,
    Name = "PlusHorizontal",
    Position = UDim2.fromOffset(11, 19),
    Size = UDim2.fromOffset(22, 5),
    BackgroundColor3 = COLORS.plus,
    BorderSizePixel = 0,
    ZIndex = 14,
})

create("Frame", {
    Parent = plusCircle,
    Name = "PlusVertical",
    Position = UDim2.fromOffset(19, 11),
    Size = UDim2.fromOffset(5, 22),
    BackgroundColor3 = COLORS.plus,
    BorderSizePixel = 0,
    ZIndex = 14,
})

-- Подпись Add с тёмной окантовкой и небольшой тенью.
create("TextLabel", {
    Parent = card,
    Name = "AddTextShadow",
    Position = UDim2.fromOffset(1, 112),
    Size = UDim2.new(1, -2, 0, 31),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Add",
    TextColor3 = Color3.fromRGB(0, 0, 0),
    TextTransparency = 0.05,
    TextSize = 20,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 14,
})

local addText = create("TextLabel", {
    Parent = card,
    Name = "AddText",
    Position = UDim2.fromOffset(0, 110),
    Size = UDim2.new(1, 0, 0, 31),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Add",
    TextColor3 = COLORS.textSoft,
    TextStrokeColor3 = Color3.fromRGB(3, 3, 5),
    TextStrokeTransparency = 0.2,
    TextSize = 20,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 15,
})

-- Прозрачная кнопка поверх всей карточки.
local addButton = create("TextButton", {
    Parent = cardBorder,
    Name = "AddButton",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Active = true,
    Selectable = true,
    ZIndex = 20,
})

-- Вторая страница, которая открывается после нажатия Add.
local catalogLayer = create("CanvasGroup", {
    Parent = gallery,
    Name = "SkinCatalogPage",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Visible = false,
    ZIndex = 21,
})

local backButtonLayer = create("CanvasGroup", {
    Parent = canvas,
    Name = "BackButtonLayer",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Visible = false,
    ZIndex = 29,
})

local backButton = create("TextButton", {
    Parent = backButtonLayer,
    Name = "BackButton",
    Position = UDim2.fromOffset(904, 9),
    Size = UDim2.fromOffset(92, 31),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Back",
    TextColor3 = COLORS.text,
    TextStrokeColor3 = Color3.fromRGB(3, 3, 5),
    TextStrokeTransparency = 0.2,
    TextSize = 18,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Center,
    AutoButtonColor = false,
    Visible = true,
    ZIndex = 30,
})

local function categoryLabel(text, y)
    return create("TextLabel", {
        Parent = catalogLayer,
        Name = text .. "Category",
        Position = UDim2.fromOffset(10, y),
        Size = UDim2.fromOffset(250, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = COLORS.text,
        TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
        TextStrokeTransparency = 0.4,
        TextSize = 18,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 23,
    })
end

categoryLabel("Cats", 0)
categoryLabel("Dogs", 216)

local skinSelected = create("BindableEvent", {
    Parent = gui,
    Name = "SkinSelected",
})

local catalogTween = TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local openSettings
local showAddPage
local showCatalogPage

local function makeCatalogCard(data, column, rowY)
    local x = 10 + ((column - 1) * 187)

    local border, fill = borderedFrame(
        catalogLayer,
        data.Key .. "Card",
        UDim2.fromOffset(x, rowY),
        UDim2.fromOffset(181, 181),
        COLORS.line,
        COLORS.catalogCard,
        2,
        23
    )
    fill.ClipsDescendants = true

    local imageValue = assetId(data.Image)

    local image = create("ImageLabel", {
        Parent = fill,
        Name = "Preview",
        Position = UDim2.fromOffset(31, 12),
        Size = UDim2.fromOffset(116, 116),
        BackgroundColor3 = Color3.fromRGB(72, 72, 76),
        BorderSizePixel = 0,
        Image = imageValue,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 25,
    })

    create("UIStroke", {
        Parent = image,
        Color = Color3.fromRGB(20, 20, 22),
        Thickness = 1,
        Transparency = 0.15,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    create("TextLabel", {
        Parent = image,
        Name = "MissingImagePlaceholder",
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "?",
        TextColor3 = Color3.fromRGB(160, 160, 164),
        TextSize = 44,
        Font = Enum.Font.Code,
        Visible = imageValue == "",
        ZIndex = 26,
    })

    create("TextLabel", {
        Parent = fill,
        Name = "SkinName",
        Position = UDim2.fromOffset(3, 133),
        Size = UDim2.new(1, -6, 0, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = data.Name,
        TextColor3 = COLORS.text,
        TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
        TextStrokeTransparency = 0.45,
        TextSize = 17,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 25,
    })

    local hitbox = create("TextButton", {
        Parent = border,
        Name = "SelectButton",
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 28,
    })

    hitbox.MouseEnter:Connect(function()
        TweenService:Create(fill, catalogTween, {
            BackgroundColor3 = COLORS.catalogCardHover,
        }):Play()
    end)

    hitbox.MouseLeave:Connect(function()
        TweenService:Create(fill, catalogTween, {
            BackgroundColor3 = COLORS.catalogCard,
        }):Play()
    end)

    hitbox.Activated:Connect(function()
        if openSettings then
            openSettings(data)
        end
    end)
end

local cats = {
    {Key = "StandingCat", Name = "Standing Cat", Image = SKIN_IMAGES.StandingCat},
    {Key = "AngryCat", Name = "Angry Cat", Image = SKIN_IMAGES.AngryCat},
    {Key = "HidingCat", Name = "Hiding Cat", Image = SKIN_IMAGES.HidingCat},
    {Key = "SmartCat", Name = "Smart Cat", Image = SKIN_IMAGES.SmartCat},
}

local dogs = {
    {Key = "RoseDog", Name = "Rose Dog", Image = SKIN_IMAGES.RoseDog},
    {Key = "WhiteDog", Name = "White Dog", Image = SKIN_IMAGES.WhiteDog},
    {Key = "BlackDog", Name = "Black Dog", Image = SKIN_IMAGES.BlackDog},
}

for index, data in ipairs(cats) do
    makeCatalogCard(data, index, 30)
end

for index, data in ipairs(dogs) do
    makeCatalogCard(data, index, 246)
end

-- Затемнение здесь прозрачное: оно только блокирует карточки под окном настроек.
local modalBlocker = create("TextButton", {
    Parent = canvas,
    Name = "SettingsModalBlocker",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Active = true,
    Selectable = false,
    Visible = false,
    ZIndex = 40,
})

local modalVisual = create("CanvasGroup", {
    Parent = modalBlocker,
    Name = "SettingsModalVisual",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    ZIndex = 41,
})

local modalBorder, modalFill = borderedFrame(
    modalVisual,
    "SettingsWindow",
    UDim2.fromOffset(170, 260),
    UDim2.fromOffset(680, 278),
    COLORS.catalogBlue,
    COLORS.outerInnerLine,
    3,
    41
)
modalBorder.AnchorPoint = Vector2.new(0.5, 0.5)
modalBorder.Position = scaleLayoutUDim2(UDim2.fromOffset(510, 399))

local modalScale = create("UIScale", {
    Parent = modalBorder,
    Scale = 0.96,
})

local modalInnerBorder, modalWindow = borderedFrame(
    modalFill,
    "SettingsWindowInnerBorder",
    UDim2.fromOffset(3, 3),
    UDim2.new(1, -6, 1, -6),
    COLORS.lineDark,
    COLORS.window,
    2,
    43
)
modalWindow.ClipsDescendants = true

local modalTitle = create("TextLabel", {
    Parent = modalWindow,
    Name = "SelectedSkinTitle",
    Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -24, 0, 36),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Standing Cat",
    TextColor3 = COLORS.text,
    TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
    TextStrokeTransparency = 0.35,
    TextSize = 18,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 46,
})

create("Frame", {
    Parent = modalWindow,
    Name = "TitleSeparator",
    Position = UDim2.fromOffset(9, 36),
    Size = UDim2.new(1, -18, 0, 2),
    BackgroundColor3 = COLORS.line,
    BorderSizePixel = 0,
    ZIndex = 46,
})

local settingsBorder, settingsPanel = borderedFrame(
    modalWindow,
    "SettingsGroupBorder",
    UDim2.fromOffset(17, 43),
    UDim2.new(1, -34, 1, -54),
    COLORS.line,
    Color3.fromRGB(20, 20, 23),
    2,
    45
)
settingsPanel.ClipsDescendants = true

create("TextLabel", {
    Parent = settingsPanel,
    Name = "SettingsCaption",
    Position = UDim2.fromOffset(15, 2),
    Size = UDim2.fromOffset(115, 27),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "- Settings",
    TextColor3 = COLORS.text,
    TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
    TextStrokeTransparency = 0.4,
    TextSize = 17,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 48,
})

create("Frame", {
    Parent = settingsPanel,
    Name = "SettingsBlueLine",
    Position = UDim2.fromOffset(126, 15),
    Size = UDim2.new(1, -142, 0, 3),
    BackgroundColor3 = COLORS.catalogBlue,
    BorderSizePixel = 0,
    ZIndex = 48,
})

local checkBorder, checkFill = borderedFrame(
    settingsPanel,
    "StatTrakCheckbox",
    UDim2.fromOffset(22, 35),
    UDim2.fromOffset(24, 24),
    COLORS.line,
    Color3.fromRGB(27, 27, 30),
    2,
    48
)

local checkMark = create("Frame", {
    Parent = checkFill,
    Name = "CheckMark",
    Position = UDim2.fromOffset(4, 4),
    Size = UDim2.new(1, -8, 1, -8),
    BackgroundColor3 = COLORS.catalogBlue,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 51,
})

local statTrakButton = create("TextButton", {
    Parent = settingsPanel,
    Name = "StatTrakButton",
    Position = UDim2.fromOffset(20, 32),
    Size = UDim2.fromOffset(190, 31),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "    StatTrak",
    TextColor3 = COLORS.textSoft,
    TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
    TextStrokeTransparency = 0.45,
    TextSize = 17,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    AutoButtonColor = false,
    ZIndex = 52,
})

create("TextLabel", {
    Parent = settingsPanel,
    Name = "WearCaption",
    Position = UDim2.fromOffset(20, 66),
    Size = UDim2.fromOffset(90, 26),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Wear",
    TextColor3 = COLORS.text,
    TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
    TextStrokeTransparency = 0.4,
    TextSize = 17,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 48,
})

local minusButton = create("TextButton", {
    Parent = settingsPanel,
    Name = "WearMinus",
    Position = UDim2.fromOffset(18, 91),
    Size = UDim2.fromOffset(24, 22),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "-",
    TextColor3 = COLORS.textSoft,
    TextSize = 17,
    Font = Enum.Font.Code,
    AutoButtonColor = false,
    ZIndex = 52,
})

local sliderBorder, sliderTrack = borderedFrame(
    settingsPanel,
    "WearSlider",
    UDim2.fromOffset(43, 92),
    UDim2.new(1, -86, 0, 20),
    COLORS.line,
    Color3.fromRGB(14, 14, 17),
    2,
    48
)

local sliderFill = create("Frame", {
    Parent = sliderTrack,
    Name = "BlueFill",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.new(0.15, 0, 1, 0),
    BackgroundColor3 = COLORS.catalogBlue,
    BorderSizePixel = 0,
    ZIndex = 50,
})

local sliderHandle = create("Frame", {
    Parent = sliderTrack,
    Name = "Handle",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.15, 0, 0, 0),
    Size = UDim2.fromOffset(4, 16),
    BackgroundColor3 = Color3.fromRGB(111, 129, 190),
    BorderSizePixel = 0,
    ZIndex = 51,
})

local wearValueLabel = create("TextLabel", {
    Parent = sliderTrack,
    Name = "WearValue",
    Position = UDim2.fromOffset(0, -2),
    Size = UDim2.fromOffset(160, 18),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "0.15",
    TextColor3 = Color3.fromRGB(245, 245, 246),
    TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
    TextStrokeTransparency = 0.3,
    TextSize = 17,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 53,
})

local sliderHitbox = create("TextButton", {
    Parent = sliderBorder,
    Name = "SliderHitbox",
    Position = UDim2.fromScale(0, 0),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 54,
})

local plusWearButton = create("TextButton", {
    Parent = settingsPanel,
    Name = "WearPlus",
    Position = UDim2.new(1, -42, 0, 91),
    Size = UDim2.fromOffset(24, 22),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "+",
    TextColor3 = COLORS.textSoft,
    TextSize = 17,
    Font = Enum.Font.Code,
    AutoButtonColor = false,
    ZIndex = 52,
})

local function settingsButton(name, text, xScale, xOffset)
    local button = create("TextButton", {
        Parent = settingsPanel,
        Name = name,
        Position = UDim2.new(xScale, xOffset, 0, 128),
        Size = UDim2.new(0.5, -28, 0, 36),
        BackgroundColor3 = Color3.fromRGB(30, 30, 33),
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = COLORS.text,
        TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
        TextStrokeTransparency = 0.4,
        TextSize = 17,
        Font = Enum.Font.Code,
        AutoButtonColor = false,
        ZIndex = 50,
    })

    create("UIStroke", {
        Parent = button,
        Color = COLORS.line,
        Thickness = 1,
        Transparency = 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(37, 37, 40)
    end)

    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(30, 30, 33)
    end)

    return button
end

local confirmButton = settingsButton("ConfirmButton", "Confirm", 0, 20)
local cancelButton = settingsButton("CancelButton", "Cancel", 0.5, 8)

local selectedSkin = nil
local statTrakEnabled = false
local wearValue = 0.15
local draggingSlider = false
local savedCards = {}

local function savedCardPosition(index)
    -- index 1 идёт сразу после карточки Add, которая занимает slot 0.
    local column = index % 5
    local row = math.floor(index / 5)
    return UDim2.fromOffset(
        49 + (column * 187),
        68 + (row * 187)
    )
end

local function relayoutSavedCards()
    for index, saved in ipairs(savedCards) do
        saved.Root.Position = scaleLayoutUDim2(savedCardPosition(index))
    end
end

local function updateWearVisual()
    wearValue = math.clamp(math.round(wearValue * 100) / 100, 0, 1)
    sliderFill.Size = UDim2.new(wearValue, 0, 1, 0)
    sliderHandle.Position = UDim2.new(wearValue, 0, 0, 0)
    wearValueLabel.Text = string.format("%.2f", wearValue)
end

local function setWearFromScreenX(screenX)
    local width = sliderTrack.AbsoluteSize.X
    if width <= 0 then
        return
    end

    wearValue = math.clamp((screenX - sliderTrack.AbsolutePosition.X) / width, 0, 1)
    updateWearVisual()
end

local settingsTweenInfo = TweenInfo.new(
    0.22,
    Enum.EasingStyle.Sine,
    Enum.EasingDirection.InOut
)
local settingsTransitionId = 0

local function closeSettings()
    draggingSlider = false
    settingsTransitionId += 1
    local transitionId = settingsTransitionId

    TweenService:Create(modalVisual, settingsTweenInfo, {
        GroupTransparency = 1,
    }):Play()
    TweenService:Create(modalScale, settingsTweenInfo, {
        Scale = 0.96,
    }):Play()

    task.delay(0.22, function()
        if settingsTransitionId == transitionId then
            modalBlocker.Visible = false
        end
    end)
end

local function makeSavedCard(data, statTrak, wear)
    local slot = #savedCards + 1 -- slot 0 уже занимает Add.

    local border, fill = borderedFrame(
        addPageLayer,
        "Saved_" .. data.Key .. "_" .. tostring(slot),
        savedCardPosition(slot),
        UDim2.fromOffset(181, 181),
        COLORS.line,
        COLORS.panel,
        2,
        10
    )

    border:SetAttribute("SkinKey", data.Key)
    border:SetAttribute("StatTrak", statTrak)
    border:SetAttribute("Wear", wear)

    local imageValue = assetId(data.Image)
    local image = create("ImageLabel", {
        Parent = fill,
        Name = "Preview",
        Position = UDim2.fromOffset(31, 12),
        Size = UDim2.fromOffset(116, 116),
        BackgroundColor3 = Color3.fromRGB(72, 72, 76),
        BorderSizePixel = 0,
        Image = imageValue,
        ScaleType = Enum.ScaleType.Crop,
        Active = true,
        ZIndex = 13,
    })

    create("TextLabel", {
        Parent = image,
        Name = "MissingImagePlaceholder",
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "?",
        TextColor3 = Color3.fromRGB(160, 160, 164),
        TextSize = 44,
        Font = Enum.Font.Code,
        Visible = imageValue == "",
        ZIndex = 14,
    })

    create("TextLabel", {
        Parent = fill,
        Name = "SkinName",
        Position = UDim2.fromOffset(3, 133),
        Size = UDim2.new(1, -6, 0, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = data.Name,
        TextColor3 = COLORS.text,
        TextStrokeColor3 = Color3.fromRGB(3, 3, 4),
        TextStrokeTransparency = 0.4,
        TextSize = 17,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })

    if statTrak then
        create("TextLabel", {
            Parent = image,
            Name = "StatTrakBadge",
            Position = UDim2.fromOffset(4, 4),
            Size = UDim2.fromOffset(35, 22),
            BackgroundColor3 = Color3.fromRGB(12, 12, 15),
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Text = "ST",
            TextColor3 = Color3.fromRGB(225, 146, 43),
            TextSize = 14,
            Font = Enum.Font.Code,
            ZIndex = 15,
        })
    end

    -- При наведении на сохранённую карточку поверх всей картинки
    -- появляется большой крест. Нажатие удаляет карточку.
    local removeOverlay = create("TextButton", {
        Parent = image,
        Name = "RemoveOverlay",
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(5, 5, 7),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Active = true,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 30,
    })

    -- Используется готовая PNG-иконка вместо пересекающихся Frame.
    -- В RemoveCrossGlow.png уже находятся округление, подсветка и мягкие края.
    local customCrossImage = assetId(REMOVE_CROSS_IMAGE)
    local hasCustomCross = customCrossImage ~= ""
    local crossImage = hasCustomCross
        and customCrossImage
        or "rbxasset://textures/ui/closeButton.png"

    local crossIcon = create("ImageLabel", {
        Parent = removeOverlay,
        Name = "RemoveCrossIcon",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.34, 1.34),
        Rotation = 0,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = crossImage,
        -- Приглушаем яркость уже запечённого в PNG свечения.
        ImageColor3 = hasCustomCross
            and Color3.fromRGB(185, 185, 185)
            or Color3.fromRGB(196, 119, 123),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        ResampleMode = Enum.ResamplerMode.Default,
        Active = false,
        ZIndex = 32,
    })

    local entry = {
        Root = border,
        Data = data,
        StatTrak = statTrak,
        Wear = wear,
    }
    table.insert(savedCards, entry)

    border.Active = true

    -- Только прозрачность: без увеличения, вращения и изменения формы.
    local overlayTweenInfo = TweenInfo.new(
        0.30,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut
    )
    local overlayTweens = {}
    local hoverGeneration = 0
    local hovering = false

    local function cancelOverlayTweens()
        for _, tween in ipairs(overlayTweens) do
            tween:Cancel()
        end
        table.clear(overlayTweens)
    end

    local function playOverlayTween(object, properties)
        local tween = TweenService:Create(object, overlayTweenInfo, properties)
        table.insert(overlayTweens, tween)
        tween:Play()
    end

    local function setRemoveOverlayVisible(visible)
        hoverGeneration += 1
        local currentGeneration = hoverGeneration
        hovering = visible
        cancelOverlayTweens()

        if visible then
            removeOverlay.Visible = true
            playOverlayTween(removeOverlay, {BackgroundTransparency = 0.62})
            playOverlayTween(crossIcon, {ImageTransparency = 0.23})
        else
            playOverlayTween(removeOverlay, {BackgroundTransparency = 1})
            playOverlayTween(crossIcon, {ImageTransparency = 1})

            task.delay(0.30, function()
                if hoverGeneration == currentGeneration and not hovering then
                    removeOverlay.Visible = false
                end
            end)
        end
    end

    border.MouseEnter:Connect(function()
        setRemoveOverlayVisible(true)
    end)

    border.MouseLeave:Connect(function()
        setRemoveOverlayVisible(false)
    end)

    removeOverlay.Activated:Connect(function()
        for index, saved in ipairs(savedCards) do
            if saved == entry then
                table.remove(savedCards, index)
                break
            end
        end

        border:Destroy()
        relayoutSavedCards()
    end)
end

openSettings = function(data)
    selectedSkin = data
    statTrakEnabled = false
    wearValue = 0.15
    checkMark.Visible = false
    statTrakButton.TextColor3 = COLORS.textSoft
    modalTitle.Text = data.Name
    updateWearVisual()

    settingsTransitionId += 1
    modalVisual.GroupTransparency = 1
    modalScale.Scale = 0.96
    modalBlocker.Visible = true

    TweenService:Create(modalVisual, settingsTweenInfo, {
        GroupTransparency = 0,
    }):Play()
    TweenService:Create(modalScale, settingsTweenInfo, {
        Scale = 1,
    }):Play()
end

statTrakButton.Activated:Connect(function()
    statTrakEnabled = not statTrakEnabled
    checkMark.Visible = statTrakEnabled
    statTrakButton.TextColor3 = statTrakEnabled and COLORS.text or COLORS.textSoft
end)

minusButton.Activated:Connect(function()
    wearValue -= 0.01
    updateWearVisual()
end)

plusWearButton.Activated:Connect(function()
    wearValue += 0.01
    updateWearVisual()
end)

sliderHitbox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        setWearFromScreenX(input.Position.X)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        setWearFromScreenX(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end)

cancelButton.Activated:Connect(closeSettings)

confirmButton.Activated:Connect(function()
    if not selectedSkin then
        return
    end

    makeSavedCard(selectedSkin, statTrakEnabled, wearValue)

    -- Событие содержит все выбранные настройки.
    skinSelected:Fire(
        selectedSkin.Key,
        selectedSkin.Name,
        assetId(selectedSkin.Image),
        statTrakEnabled,
        wearValue
    )

    print(
        "Skin Changer confirmed:",
        selectedSkin.Name,
        "StatTrak:",
        statTrakEnabled,
        "Wear:",
        wearValue
    )

    closeSettings()
    showAddPage()
end)

local normalTween = TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

addButton.MouseEnter:Connect(function()
    TweenService:Create(card, normalTween, {BackgroundColor3 = COLORS.panelHover}):Play()
    TweenService:Create(plusCircle, normalTween, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    TweenService:Create(addText, normalTween, {TextColor3 = COLORS.text}):Play()
end)

addButton.MouseLeave:Connect(function()
    TweenService:Create(card, normalTween, {BackgroundColor3 = COLORS.panel}):Play()
    TweenService:Create(plusCircle, normalTween, {BackgroundColor3 = COLORS.white}):Play()
    TweenService:Create(addText, normalTween, {TextColor3 = COLORS.textSoft}):Play()
end)

addButton.MouseButton1Down:Connect(function()
    plusCircle.Position = scaleLayoutUDim2(UDim2.fromOffset(69, 50))
end)

addButton.MouseButton1Up:Connect(function()
    plusCircle.Position = scaleLayoutUDim2(UDim2.fromOffset(69, 49))
end)

local pageTweenInfo = TweenInfo.new(
    0.22,
    Enum.EasingStyle.Sine,
    Enum.EasingDirection.InOut
)
local pageTransitionId = 0

showCatalogPage = function()
    pageTransitionId += 1
    local transitionId = pageTransitionId

    addButton.Active = false
    backButton.Active = false
    addPageLayer.Visible = true
    catalogLayer.Visible = true
    backButtonLayer.Visible = true
    catalogLayer.GroupTransparency = 1
    backButtonLayer.GroupTransparency = 1

    TweenService:Create(addPageLayer, pageTweenInfo, {
        GroupTransparency = 1,
    }):Play()
    TweenService:Create(catalogLayer, pageTweenInfo, {
        GroupTransparency = 0,
    }):Play()
    TweenService:Create(backButtonLayer, pageTweenInfo, {
        GroupTransparency = 0,
    }):Play()
    TweenService:Create(goldBorder, pageTweenInfo, {
        BackgroundColor3 = COLORS.catalogBlue,
    }):Play()
    TweenService:Create(gallery, pageTweenInfo, {
        BackgroundColor3 = COLORS.catalog,
    }):Play()

    task.delay(0.22, function()
        if pageTransitionId == transitionId then
            addPageLayer.Visible = false
            backButton.Active = true
        end
    end)
end

showAddPage = function()
    pageTransitionId += 1
    local transitionId = pageTransitionId

    backButton.Active = false
    addPageLayer.Visible = true
    catalogLayer.Visible = true
    backButtonLayer.Visible = true
    addPageLayer.GroupTransparency = 1

    TweenService:Create(addPageLayer, pageTweenInfo, {
        GroupTransparency = 0,
    }):Play()
    TweenService:Create(catalogLayer, pageTweenInfo, {
        GroupTransparency = 1,
    }):Play()
    TweenService:Create(backButtonLayer, pageTweenInfo, {
        GroupTransparency = 1,
    }):Play()
    TweenService:Create(goldBorder, pageTweenInfo, {
        BackgroundColor3 = COLORS.gold,
    }):Play()
    TweenService:Create(gallery, pageTweenInfo, {
        BackgroundColor3 = COLORS.panel,
    }):Play()

    task.delay(0.22, function()
        if pageTransitionId == transitionId then
            catalogLayer.Visible = false
            backButtonLayer.Visible = false
            addButton.Active = true
        end
    end)
end

local function onAddClicked()
    showCatalogPage()
end

addButton.Activated:Connect(onAddClicked)
backButton.Activated:Connect(showAddPage)

backButton.MouseEnter:Connect(function()
    backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
end)

backButton.MouseLeave:Connect(function()
    backButton.TextColor3 = COLORS.text
end)

-- Плавное первое появление всего интерфейса без размытия текста.
task.defer(function()
    local revealTween = TweenService:Create(
        startupCover,
        TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    )
    revealTween:Play()
    revealTween.Completed:Connect(function()
        startupCover:Destroy()
    end)
end)
