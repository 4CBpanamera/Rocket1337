local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera


local SPEED = 175 


local NOSE_ROTATION = CFrame.Angles(math.rad(-90), 0, 0) 
local FPV_OFFSET = 0.8 -- 


local missileModel = nil
local primaryPart = nil
local fpvPart = nil
local isFlying = false
local flightStartTime = 0


local alignOrientation = nil
local linearVelocity = nil
local attachment = nil
local touchConnection = nil
local flightConnection = nil


local origCameraSubject = nil
local origMinZoom = LocalPlayer.CameraMinZoomDistance
local origMaxZoom = LocalPlayer.CameraMaxZoomDistance
local origCameraMode = LocalPlayer.CameraMode


if getgenv and getgenv().FTAP_Gui then
    pcall(function() getgenv().FTAP_Gui:Destroy() end)
end


local gui = Instance.new("ScreenGui")
gui.Name = "FTAP_Gui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

if getgenv then getgenv().FTAP_Gui = gui end


local fpHud = Instance.new("Frame")
fpHud.Name = "FPV_Overlay"
fpHud.Size = UDim2.new(1, 0, 1, 0)
fpHud.BackgroundTransparency = 1
fpHud.Visible = false
fpHud.Parent = gui


local crossCenter = Instance.new("TextLabel")
crossCenter.Size = UDim2.new(0, 80, 0, 80)
crossCenter.Position = UDim2.new(0.5, -40, 0.5, -40)
crossCenter.BackgroundTransparency = 1
crossCenter.Font = Enum.Font.Code
crossCenter.Text = "[   +   ]"
crossCenter.TextColor3 = Color3.fromRGB(80, 255, 80)
crossCenter.TextSize = 28
crossCenter.TextStrokeTransparency = 0.5
crossCenter.Parent = fpHud


local recLabel = Instance.new("TextLabel")
recLabel.Size = UDim2.new(0, 160, 0, 30)
recLabel.Position = UDim2.new(0, 25, 0, 25)
recLabel.BackgroundTransparency = 1
recLabel.Font = Enum.Font.Code
recLabel.Text = "● REC  00:00"
recLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
recLabel.TextSize = 20
recLabel.TextXAlignment = Enum.TextXAlignment.Left
recLabel.Parent = fpHud


local spdLabel = Instance.new("TextLabel")
spdLabel.Size = UDim2.new(0, 160, 0, 30)
spdLabel.Position = UDim2.new(0, 25, 0, 55)
spdLabel.BackgroundTransparency = 1
spdLabel.Font = Enum.Font.Code
spdLabel.Text = "SPD: 1337 KM/H"
spdLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
spdLabel.TextSize = 16
spdLabel.TextXAlignment = Enum.TextXAlignment.Left
spdLabel.Parent = fpHud



local function stopMissile()
    if not isFlying then return end
    isFlying = false
    fpHud.Visible = false

    if touchConnection then touchConnection:Disconnect(); touchConnection = nil end
    if flightConnection then flightConnection:Disconnect(); flightConnection = nil end

    
    if primaryPart and primaryPart:IsDescendantOf(workspace) then
        local exp = Instance.new("Explosion")
        exp.Position = primaryPart.Position
        exp.BlastRadius = 25
        exp.BlastPressure = 600000
        exp.Parent = workspace
    end

    
    if linearVelocity then linearVelocity:Destroy(); linearVelocity = nil end
    if alignOrientation then alignOrientation:Destroy(); alignOrientation = nil end
    if attachment then attachment:Destroy(); attachment = nil end
    if fpvPart then fpvPart:Destroy(); fpvPart = nil end

    primaryPart = nil
    missileModel = nil

    
    LocalPlayer.CameraMode = origCameraMode or Enum.CameraMode.Classic
    LocalPlayer.CameraMinZoomDistance = origMinZoom or 0.5
    LocalPlayer.CameraMaxZoomDistance = origMaxZoom or 128

    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        Camera.CameraSubject = char.Humanoid
    end
end


local function startMissile(part, model)
    if not part or not part:IsDescendantOf(workspace) then return end
    primaryPart = part
    missileModel = model

    pcall(function()
        primaryPart:SetNetworkOwner(LocalPlayer)
    end)

    
    local halfLength = primaryPart.Size.Y / 2
    if missileModel then
        local _, modelSize = missileModel:GetBoundingBox()
        halfLength = math.max(modelSize.Y, modelSize.Z) / 2
    end

    
    fpvPart = Instance.new("Part")
    fpvPart.Name = "FPV_NosePoint"
    fpvPart.Size = Vector3.new(0.2, 0.2, 0.2)
    fpvPart.Transparency = 1
    fpvPart.CanCollide = false
    fpvPart.CanTouch = false
    fpvPart.CanQuery = false
    fpvPart.Massless = true
    fpvPart.CFrame = primaryPart.CFrame * CFrame.new(0, halfLength + FPV_OFFSET, 0)
    fpvPart.Parent = primaryPart

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = primaryPart
    weld.Part1 = fpvPart
    weld.Parent = fpvPart

    
    attachment = Instance.new("Attachment")
    attachment.Parent = primaryPart

    alignOrientation = Instance.new("AlignOrientation")
    alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOrientation.Attachment0 = attachment
    alignOrientation.MaxTorque = math.huge
    alignOrientation.Responsiveness = 200
    alignOrientation.CFrame = Camera.CFrame * NOSE_ROTATION
    alignOrientation.Parent = primaryPart

    linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.MaxForce = math.huge
    linearVelocity.Attachment0 = attachment
    linearVelocity.VectorVelocity = Camera.CFrame.LookVector * SPEED
    linearVelocity.Parent = primaryPart

    
    origMinZoom = LocalPlayer.CameraMinZoomDistance
    origMaxZoom = LocalPlayer.CameraMaxZoomDistance
    origCameraMode = LocalPlayer.CameraMode

    LocalPlayer.CameraMinZoomDistance = 0.5
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    Camera.CameraSubject = fpvPart

    isFlying = true
    flightStartTime = os.clock()
    fpHud.Visible = true

    
    local armTime = os.clock() + 0.2
    touchConnection = primaryPart.Touched:Connect(function(hitPart)
        if not isFlying or not hitPart or os.clock() < armTime then return end

        local char = LocalPlayer.Character
        if char and hitPart:IsDescendantOf(char) then return end
        if missileModel and hitPart:IsDescendantOf(missileModel) then return end
        if hitPart == primaryPart or hitPart == fpvPart then return end
        if not hitPart.CanCollide and hitPart.Transparency >= 1 then return end

        stopMissile()
    end)

    
    flightConnection = RunService.RenderStepped:Connect(function()
        if not isFlying or not primaryPart or not primaryPart:IsDescendantOf(workspace) then
            stopMissile()
            return
        end

        local camCF = Camera.CFrame
        if alignOrientation and linearVelocity then
            
            alignOrientation.CFrame = camCF * NOSE_ROTATION
            linearVelocity.VectorVelocity = camCF.LookVector * SPEED
        end

        
        local elapsed = os.clock() - flightStartTime
        local mins = math.floor(elapsed / 60)
        local secs = math.floor(elapsed % 60)
        recLabel.Text = string.format("● REC  %02d:%02d", mins, secs)
    end)
end


local function isUnanchored(part, model)
    if part.Anchored then return false end
    if model and #model:GetChildren() < 30 then
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Anchored then
                return false
            end
        end
    end
    return true
end


local function toggleMissile()
    if isFlying then
        stopMissile()
    else
        local centerRay = Camera:ViewportPointToRay(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude

        local ignoreList = {}
        if LocalPlayer.Character then table.insert(ignoreList, LocalPlayer.Character) end
        params.FilterDescendantsInstances = ignoreList

        local hit = workspace:Raycast(centerRay.Origin, centerRay.Direction * 600, params)
        if hit and hit.Instance then
            local obj = hit.Instance
            local model = obj:FindFirstAncestorOfClass("Model")

            if model and model:FindFirstChildOfClass("Humanoid") and model ~= LocalPlayer.Character then
                model = nil
            end

            local targetPart = (model and model.PrimaryPart) or obj

            if isUnanchored(targetPart, model) then
                startMissile(targetPart, model)
            else
                StarterGui:SetCore("SendNotification", {
                    Title = "Missile",
                    Text = "OBJECT ANCHORED!",
                    Duration = 1.2,
                })
            end
        else
            StarterGui:SetCore("SendNotification", {
                Title = "Missile",
                Text = "CMOTPU HA RAKETY",
                Duration = 1.2,
            })
        end
    end
end


UserInput.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Y then
        toggleMissile()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if isFlying then stopMissile() end
end)

print ("rocketa1337 loaded bro xD")
