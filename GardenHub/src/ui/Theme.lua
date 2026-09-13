local Theme = {
    Background = Color3.fromRGB(8, 8, 10),
    Panel = Color3.fromRGB(18, 18, 22),
    PanelSecondary = Color3.fromRGB(34, 34, 38),
    Text = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(180, 180, 185),
    Blue = Color3.fromRGB(51, 130, 255),
    BlueHover = Color3.fromRGB(82, 156, 255),
    Border = Color3.fromRGB(50, 50, 58),
    Disabled = Color3.fromRGB(90, 90, 95),
    Accent = Color3.fromRGB(20, 120, 255),
    Success = Color3.fromRGB(79, 196, 116),
    Warning = Color3.fromRGB(248, 179, 70),
    Error = Color3.fromRGB(239, 89, 89),
    Shadow = Color3.fromRGB(0, 0, 0),
}

Theme.Button = {
    Default = Theme.Blue,
    Hover = Theme.BlueHover,
    Text = Theme.Text,
    Border = Theme.Border,
}

return Theme
