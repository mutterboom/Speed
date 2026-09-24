-- By boom | วิ่งไว + บินได้ + มองทะลุ + เห็นชื่อ
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local speedOn, flyOn, espOn, nameOn = false, false, false, false
local runSpeed, flySpeed = 50, 50
local bodyVel, bodyGyro
local alive = true
local dirs = {F=false, B=false, L=false, R=false, U=false, D=false}
local espList, nameList = {}, {}

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "BoomUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 240, 0, 370)
main.Position = UDim2.new(0, 20, 0, 100)
main.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 20)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
title.Text = "Tricky | By boom"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 20)

local function mkBtn(text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.55, 0, 0, 34)
    b.Position = UDim2.new(0.05, 0, y, 0)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.SourceSans
    b.TextSize = 14
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 17)
    return b
end

local function mkBox(y, default)
    local b = Instance.new("TextBox")
    b.Size = UDim2.new(0.3, 0, 0, 34)
    b.Position = UDim2.new(0.65, 0, y, 0)
    b.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    b.Text = default
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.SourceSans
    b.TextSize = 14
    b.Parent = main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 17)
    return b
end

local spdBtn = mkBtn("วิ่งไว: ปิด", 0.14)
local spdBox = mkBox(0.14, "50")
local flyBtn = mkBtn("บินได้: ปิด", 0.28)
local flyBox = mkBox(0.28, "50")
local espBtn = mkBtn("มองทะลุ: ปิด", 0.42)
local nameBtn = mkBtn("เห็นชื่อ: ปิด", 0.56)
local killBtn = mkBtn("ปิดสคริปต์", 0.72)

killBtn.Size = UDim2.new(0.9, 0, 0, 34)
killBtn.Position = UDim2.new(0.05, 0, 0.72, 0)
killBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
killBtn.Font = Enum.Font.SourceSansBold

local closeBtn = mkBtn("ซ่อนเมนู", 0.87)
closeBtn.Size = UDim2.new(0.9, 0, 0, 34)
closeBtn.Position = UDim2.new(0.05, 0, 0.87, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Font = Enum.Font.SourceSansBold

-- D-Pad
local pad = Instance.new("Frame")
pad.Size = UDim2.new(0, 170, 0, 170)
pad.Position = UDim2.new(1, -190, 0.5, -85)
pad.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
pad.BackgroundTransparency = 0.3
pad.Visible = false
pad.Parent = gui
Instance.new("UICorner", pad).CornerRadius = UDim.new(1, 0)

local function mkP(t, p)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 48, 0, 48)
    b.Position = p
    b.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    b.Text = t
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 18
    b.Parent = pad
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    return b
end

local pU = mkP("⬆", UDim2.new(0.5, -24, 0, 4))
local pD = mkP("⬇", UDim2.new(0.5, -24, 1, -52))
local pL = mkP("⬅", UDim2.new(0, 4, 0.5, -24))
local pR = mkP("➡", UDim2.new(1, -52, 0.5, -24))
local pF = mkP("W", UDim2.new(0.5, -24, 0.5, -24))

local function bindP(b, k)
    b.MouseButton1Down:Connect(function() dirs[k]=true; b.BackgroundColor3=Color3.fromRGB(0,200,100) end)
    b.MouseButton1Up:Connect(function() dirs[k]=false; b.BackgroundColor3=Color3.fromRGB(0,120,200) end)
    b.MouseLeave:Connect(function() dirs[k]=false; b.BackgroundColor3=Color3.fromRGB(0,120,200) end)
end
bindP(pU,"U") bindP(pD,"D") bindP(pL,"L") bindP(pR,"R") bindP(pF,"F")

-- วิ่งไว
spdBtn.MouseButton1Click:Connect(function()
    speedOn = not speedOn
    spdBtn.Text = speedOn and "วิ่งไว: เปิด" or "วิ่งไว: ปิด"
    spdBtn.BackgroundColor3 = speedOn and Color3.fromRGB(0,170,0) or Color3.fromRGB(50,50,70)
    if not speedOn then humanoid.WalkSpeed = 16 end
end)

spdBox.FocusLost:Connect(function()
    local v = tonumber(spdBox.Text)
    if v and v > 0 then runSpeed = math.min(v, 200) else spdBox.Text="50"; runSpeed=50 end
end)

RunService.Heartbeat:Connect(function()
    if not alive then return end
    if speedOn and humanoid.Parent == character then
        humanoid.WalkSpeed = runSpeed
    end
end)

-- บิน
flyBtn.MouseButton1Click:Connect(function()
    flyOn = not flyOn
    flyBtn.Text = flyOn and "บินได้: เปิด" or "บินได้: ปิด"
    flyBtn.BackgroundColor3 = flyOn and Color3.fromRGB(0,170,0) or Color3.fromRGB(50,50,70)
    if flyOn then
        if bodyVel then bodyVel:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 3, 0)
        bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVel.Velocity = Vector3.new(0, 0, 0)
        bodyVel.P = 1250
        bodyVel.Parent = rootPart
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bodyGyro.P = 3000
        bodyGyro.D = 50
        bodyGyro.CFrame = workspace.CurrentCamera.CFrame
        bodyGyro.Parent = rootPart
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        pad.Visible = true
    else
        if bodyVel then bodyVel:Destroy(); bodyVel=nil end
        if bodyGyro then bodyGyro:Destroy(); bodyGyro=nil end
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        humanoid.WalkSpeed = speedOn and runSpeed or 16
        pad.Visible = false
        for k in pairs(dirs) do dirs[k]=false end
    end
end)

flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v and v > 0 then flySpeed = math.min(v, 300) else flyBox.Text="50"; flySpeed=50 end
end)

RunService.RenderStepped:Connect(function()
    if not alive then return end
    if flyOn and bodyVel and rootPart.Parent == character then
        if humanoid:GetState() ~= Enum.HumanoidStateType.Running then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
        humanoid.PlatformStand = false
        if bodyGyro then bodyGyro.CFrame = workspace.CurrentCamera.CFrame end
        local cam = workspace.CurrentCamera
        local mv = Vector3.new(0, 0, 0)
        if dirs.F then mv = mv + cam.CFrame.LookVector end
        if dirs.B then mv = mv - cam.CFrame.LookVector end
        if dirs.L then mv = mv - cam.CFrame.RightVector end
        if dirs.R then mv = mv + cam.CFrame.RightVector end
        if dirs.U then mv = mv + Vector3.new(0,1,0) end
        if dirs.D then mv = mv - Vector3.new(0,1,0) end
        bodyVel.Velocity = mv.Magnitude > 0 and (mv.Unit * flySpeed) or Vector3.new(0,0,0)
    end
end)

-- มองทะลุ
espBtn.MouseButton1Click:Connect(function()
    espOn = not espOn
    espBtn.Text = espOn and "มองทะลุ: เปิด" or "มองทะลุ: ปิด"
    espBtn.BackgroundColor3 = espOn and Color3.fromRGB(0,170,0) or Color3.fromRGB(50,50,70)
    for _, obj in pairs(espList) do if obj then obj:Destroy() end end
    espList = {}
    if espOn then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local hl = Instance.new("Highlight")
                hl.Adornee = p.Character
                hl.FillColor = Color3.fromRGB(255, 0, 0)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.5
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = p.Character
                table.insert(espList, hl)
            end
        end
    end
end)

-- เห็นชื่อ
local nameData = {}
nameBtn.MouseButton1Click:Connect(function()
    nameOn = not nameOn
    nameBtn.Text = nameOn and "เห็นชื่อ: เปิด" or "เห็นชื่อ: ปิด"
    nameBtn.BackgroundColor3 = nameOn and Color3.fromRGB(0,170,0) or Color3.fromRGB(50,50,70)
    for _, obj in pairs(nameList) do if obj then obj:Destroy() end end
    nameList = {}
    nameData = {}
    if nameOn then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    local bg = Instance.new("BillboardGui")
                    bg.Size = UDim2.new(0, 110, 0, 24)
                    bg.StudsOffset = Vector3.new(0, 2.8, 0)
                    bg.AlwaysOnTop = true
                    bg.LightInfluence = 0
                    bg.Adornee = head
                    bg.Parent = head
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = p.Name
                    lbl.TextColor3 = Color3.fromRGB(255, 255, 0)
                    lbl.TextStrokeTransparency = 0
                    lbl.Font = Enum.Font.SourceSansBold
                    lbl.TextSize = 14
                    lbl.Parent = bg
                    table.insert(nameList, bg)
                    table.insert(nameData, {gui=bg, head=head})
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not alive or not nameOn then return end
    local cam = workspace.CurrentCamera
    local camPos = cam.CFrame.Position
    local look = cam.CFrame.LookVector
    local vp = cam.ViewportSize
    for i = #nameData, 1, -1 do
        local d = nameData[i]
        if not d.head or not d.head.Parent then
            if d.gui then d.gui:Destroy() end
            table.remove(nameData, i)
        else
            local hp = d.head.Position
            local delta = hp - camPos
            local dist = delta.Magnitude
            if dist > 800 then
                d.gui.Enabled = false
            else
                local dot = look:Dot(delta.Unit)
                if dot < 0.15 then
                    d.gui.Enabled = false
                else
                    local sp, onScreen = cam:WorldToViewportPoint(hp)
                    d.gui.Enabled = onScreen and sp.Z > 0
                        and sp.X > -50 and sp.X < vp.X + 50
                        and sp.Y > -50 and sp.Y < vp.Y + 50
                end
            end
        end
    end
end)

-- ปุ่มปิด
local function killAll()
    alive = false
    speedOn, flyOn, espOn, nameOn = false, false, false, false
    if bodyVel then bodyVel:Destroy(); bodyVel=nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro=nil end
    for _, obj in pairs(espList) do if obj then obj:Destroy() end end
    for _, obj in pairs(nameList) do if obj then obj:Destroy() end end
    espList, nameList, nameData = {}, {}, {}
    if humanoid and humanoid.Parent == character then
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    gui:Destroy()
end

killBtn.MouseButton1Click:Connect(killAll)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
end)

-- เกิดใหม่
player.CharacterAdded:Connect(function(nc)
    character = nc
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    speedOn, flyOn = false, false
    if bodyVel then bodyVel:Destroy(); bodyVel=nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro=nil end
    pad.Visible = false
end)

print("Boom script loaded OK")
