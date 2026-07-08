-- SPTS SUPREME v4.0
-- Focused on safer UI loading, stronger automation, and a cleaner release layout.

local function tryGetService(name)
    local ok, service = pcall(game.GetService, game, name)
    return ok and service or nil
end

local function compileSource(source, chunkName)
    if type(source) ~= "string" or source == "" then
        return nil, "source is empty"
    end

    local compiler = loadstring or load
    if type(compiler) ~= "function" then
        return nil, "loadstring is not available in this executor"
    end

    local chunk, err = compiler(source, chunkName)
    if not chunk then
        return nil, err or "unknown compile error"
    end

    return chunk
end

local function readLocalText(path)
    if type(readfile) ~= "function" then
        return nil, "readfile is not available"
    end

    if type(isfile) == "function" and not isfile(path) then
        return nil, "file not found: " .. path
    end

    local ok, content = pcall(readfile, path)
    if not ok then
        return nil, tostring(content)
    end

    if type(content) ~= "string" or content == "" then
        return nil, "file is empty: " .. path
    end

    return content
end

local function loadLocalChunk(path)
    if type(loadfile) == "function" then
        local ok, result = pcall(loadfile, path)
        if ok and type(result) == "function" then
            return result
        end
    end

    local content, readError = readLocalText(path)
    if not content then
        return nil, readError
    end

    return compileSource(content, "@" .. path)
end

local function httpGetText(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        return nil, tostring(result)
    end

    if type(result) ~= "string" or result == "" then
        return nil, "empty response from " .. url
    end

    return result
end

local function loadRemoteChunk(url)
    local content, requestError = httpGetText(url)
    if not content then
        return nil, requestError
    end

    return compileSource(content, "@" .. url)
end

local function loadRayfield()
    local loaders = {
        {
            label = "local StarRayfield",
            load = function()
                local candidates = {
                    "api/connection/StarRayfield.lua",
                    "./api/connection/StarRayfield.lua",
                    "Scipts/api/connection/StarRayfield.lua",
                    "api/connection/UI.lua",
                    "./api/connection/UI.lua",
                    "Scipts/api/connection/UI.lua",
                }

                local lastError = "local UI file was not available"
                for _, path in ipairs(candidates) do
                    local chunk, err = loadLocalChunk(path)
                    if chunk then
                        return chunk()
                    end

                    if err then
                        lastError = tostring(err)
                    end
                end

                error(lastError)
            end,
        },
        {
            label = "official loader",
            load = function()
                local chunk, err = loadRemoteChunk("https://sirius.menu/rayfield")
                if not chunk then
                    error(err)
                end
                return chunk()
            end,
        },
        {
            label = "single-file fallback",
            load = function()
                local chunk, err = loadRemoteChunk("https://raw.githubusercontent.com/mohamadusmanov216-spec/StarScript/main/api/connection/StarRayfield.lua")
                if not chunk then
                    chunk, err = loadRemoteChunk("https://raw.githubusercontent.com/mohamadusmanov216-spec/StarScript/main/api/connection/UI.lua")
                end
                if not chunk then
                    error(err)
                end
                return chunk()
            end,
        },
    }

    local errors = {}

    for _, loader in ipairs(loaders) do
        local ok, result = pcall(loader.load)
        if ok and result then
            return result
        end

        errors[#errors + 1] = loader.label .. ": " .. tostring(result)
    end

    error("Failed to load StarRayfield in single-file mode.\n" .. table.concat(errors, "\n"))
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local VirtualInputManager = tryGetService("VirtualInputManager")
local Rayfield = loadRayfield()

local scriptRunning = true
local shuttingDown = false
local activeConnections = {}
local deathConnection = nil
local sharedRemoteEvent = nil

local autoPool = false
local autoStrength = false
local autoPsychic = false
local infiniteJump = false
local antiAfk = false
local autoRespawn = false
local pendingRespawn = false
local godMode = false
local antiVoid = true
local antiKnockback = false
local walkSpeedEnabled = false
local mouseAssist = true

local selectedPool = "1. 100"
local selectedStrength = "Normal Rock"
local selectedPsychic = "1M"
local respawnDelay = 2
local walkSpeedValue = 35
local farmLoopDelay = 0.08
local strengthBurst = 6
local psychicBurst = 10
local clickBurst = 3
local positionLockRadius = 6
local clickPosition = Vector2.new(401, 270)
local defaultWalkSpeed = 16
local lastSafePosition = Vector3.new(0, 250, 0)

local strengthOptions = {"Normal Rock", "Blue Crystal", "Blue Star 1B", "Green Star 100B", "Sun 10T"}
local poolOptions = {"1. 100", "2. 10k", "3. 100k", "4. 1m", "5. 10m", "6. 1B", "7. 1T"}
local psychicOptions = {"1M", "1B", "1T", "1Qa"}
local themeOptions = {"AmberGlow", "Ocean", "Default", "Green", "Light", "Amethyst"}

local pools = {
    ["1. 100"] = Vector3.new(366, 250, -446),
    ["2. 10k"] = Vector3.new(348, 264, -499),
    ["3. 100k"] = Vector3.new(1639, 260, 2250),
    ["4. 1m"] = Vector3.new(-2303, 977, 1072),
    ["5. 10m"] = Vector3.new(-2051, 714, -1893),
    ["6. 1B"] = Vector3.new(-246.4, 286.8, 983.9),
    ["7. 1T"] = Vector3.new(-275.4, 279.9, 998.0),
}

local strengthLocations = {
    ["Normal Rock"] = Vector3.new(403, 249, 988),
    ["Blue Crystal"] = Vector3.new(-2275, 1943, 1051),
    ["Blue Star 1B"] = Vector3.new(1175.0, 4787.7, -2294.9),
    ["Green Star 100B"] = Vector3.new(1380.7, 9273.0, 1646.3),
    ["Sun 10T"] = Vector3.new(-366.5, 15733.0, 1.2),
}

local psychicLocations = {
    ["1M"] = Vector3.new(-2531, 5486, -533),
    ["1B"] = Vector3.new(-2562, 5501, -435),
    ["1T"] = Vector3.new(-2582, 5516, -503),
    ["1Qa"] = Vector3.new(-2544, 5412, -494),
}

local teleportLocations = {
    ["Quest"] = Vector3.new(489, 249, 895),
    ["Leaderboard"] = Vector3.new(-750, 249, 747),
    ["Spawn"] = Vector3.new(0, 250, 0),
    ["Pool 1B"] = Vector3.new(-246.4, 286.8, 983.9),
    ["Pool 1T"] = Vector3.new(-275.4, 279.9, 998.0),
    ["Strength 1B"] = Vector3.new(1175.0, 4787.7, -2294.9),
    ["Strength 100B"] = Vector3.new(1380.7, 9273.0, 1646.3),
    ["Strength 10T"] = Vector3.new(-366.5, 15733.0, 1.2),
}

local psychicTools = {
    ["1M"] = "M1",
    ["1B"] = "M1B",
    ["1T"] = "M1T",
    ["1Qa"] = "M1Q",
}

local poolToggleRef
local strengthToggleRef
local psychicToggleRef
local walkSpeedSliderRef
local respawnDelaySliderRef
local farmDelaySliderRef
local strengthBurstSliderRef
local psychicBurstSliderRef
local clickBurstSliderRef
local positionLockSliderRef

local function safeNotify(options)
    if not Rayfield or type(Rayfield.Notify) ~= "function" then
        if type(options) == "table" then
            print(string.format("[SPTS] %s: %s", tostring(options.Title or "Notice"), tostring(options.Content or "")))
        end
        return
    end

    pcall(function()
        Rayfield:Notify(options)
    end)
end

local function trackConnection(connection)
    if connection then
        activeConnections[#activeConnections + 1] = connection
    end
    return connection
end

local function disconnectAllConnections()
    if deathConnection then
        pcall(function()
            deathConnection:Disconnect()
        end)
        deathConnection = nil
    end

    for _, connection in ipairs(activeConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(activeConnections)
end

local function setUiElementValue(element, value)
    if not element or type(element.Set) ~= "function" then
        return false
    end

    return pcall(function()
        element:Set(value)
    end)
end

local function resolveSingleOption(option, fallback)
    if type(option) == "table" then
        return option[1] or fallback
    end

    if type(option) == "string" and option ~= "" then
        return option
    end

    return fallback
end

local function shutdownScript(destroyUi)
    if shuttingDown then
        return
    end

    shuttingDown = true
    scriptRunning = false
    disconnectAllConnections()

    if destroyUi and Rayfield and type(Rayfield.Destroy) == "function" then
        pcall(function()
            Rayfield:Destroy()
        end)
    end
end

local function getCharacterParts()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, rootPart
end

local function isAlive()
    local _, humanoid, rootPart = getCharacterParts()
    return humanoid ~= nil and rootPart ~= nil and humanoid.Health > 0
end

local function safeTeleport(position)
    if not position then
        return false
    end

    local _, humanoid, rootPart = getCharacterParts()
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return false
    end

    local ok = pcall(function()
        rootPart.CFrame = CFrame.new(position)
    end)

    if ok then
        lastSafePosition = position
    end

    return ok
end

local function showCurrentCoordinates()
    local _, _, rootPart = getCharacterParts()
    if not rootPart then
        safeNotify({
            Title = "Coordinates",
            Content = "Character position is not available right now.",
            Duration = 3,
        })
        return
    end

    local position = rootPart.Position
    local vectorText = string.format("Vector3.new(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
    local notifyText = string.format("X %.1f | Y %.1f | Z %.1f", position.X, position.Y, position.Z)

    print("[SPTS] Current coordinates: " .. vectorText)

    if setclipboard then
        pcall(function()
            setclipboard(vectorText)
        end)
        notifyText = notifyText .. " | Copied"
    end

    safeNotify({
        Title = "Coordinates",
        Content = notifyText,
        Duration = 5,
    })
end

local function findToolByName(toolName)
    if not toolName then
        return nil
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == toolName then
                return tool
            end
        end
    end

    local character = LocalPlayer.Character
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == toolName then
                return tool
            end
        end
    end

    return nil
end

local function canUseMouseAssist()
    if not mouseAssist then
        return false
    end

    if Rayfield and type(Rayfield.IsVisible) == "function" then
        local ok, visible = pcall(function()
            return Rayfield:IsVisible()
        end)

        if ok and visible then
            return false
        end
    end

    return true
end

local function sendMouseClick()
    if not canUseMouseAssist() then
        return false
    end

    if VirtualInputManager then
        local ok = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(clickPosition.X, clickPosition.Y, 0, true, game, 1)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(clickPosition.X, clickPosition.Y, 0, false, game, 1)
        end)

        if ok then
            return true
        end
    end

    if mouse1click then
        local ok = pcall(mouse1click)
        if ok then
            return true
        end
    end

    if mouse1press and mouse1release then
        local ok = pcall(function()
            mouse1press()
            task.wait(0.01)
            mouse1release()
        end)

        if ok then
            return true
        end
    end

    return false
end

local function pulseMovement()
    local _, _, rootPart = getCharacterParts()
    if not rootPart then
        return
    end

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
            task.wait(0.1)
        end)
    end

    pcall(function()
        rootPart.CFrame = rootPart.CFrame + (rootPart.CFrame.LookVector * 0.5)
    end)
end

local function getMainRemoteEvent()
    if sharedRemoteEvent and sharedRemoteEvent.Parent then
        return sharedRemoteEvent
    end

    local preferredNames = {
        "RemoteEvent",
        "remoteevent",
        "Event",
        "event",
    }

    for _, name in ipairs(preferredNames) do
        local exactRemote = ReplicatedStorage:FindFirstChild(name, true)
        if exactRemote and exactRemote:IsA("RemoteEvent") then
            sharedRemoteEvent = exactRemote
            return sharedRemoteEvent
        end
    end

    for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
        if object:IsA("RemoteEvent") then
            local upperName = string.upper(object.Name)
            if string.find(upperName, "STRENGTH", 1, true)
                or string.find(upperName, "TRAIN", 1, true)
                or string.find(upperName, "PSYCHIC", 1, true)
                or string.find(upperName, "REMOTE", 1, true) then
                sharedRemoteEvent = object
                return sharedRemoteEvent
            end
        end
    end

    for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
        if object:IsA("RemoteEvent") then
            sharedRemoteEvent = object
            return sharedRemoteEvent
        end
    end

    return nil
end

local function fireStrengthRequest()
    local remoteEvent = getMainRemoteEvent()
    if not remoteEvent then
        return false
    end

    local payloads = {
        {"Add_FS_Request"},
        "Add_FS_Request",
        {"Add_FS_Request", true},
    }

    for _, payload in ipairs(payloads) do
        local ok = pcall(function()
            remoteEvent:FireServer(payload)
        end)

        if ok then
            return true
        end
    end

    return false
end

local function equipPsychicTool()
    local toolName = psychicTools[selectedPsychic]
    local tool = findToolByName(toolName)
    if not tool then
        return nil
    end

    pcall(function()
        tool.Parent = LocalPlayer.Character
    end)

    return tool
end

local function findSpawnButton()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return false
    end

    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local parts = {gui.Name}

            if gui:IsA("TextButton") then
                parts[#parts + 1] = gui.Text
            end

            for _, descendant in ipairs(gui:GetDescendants()) do
                if descendant:IsA("TextLabel") or descendant:IsA("TextBox") then
                    parts[#parts + 1] = descendant.Text
                end
            end

            local combinedText = string.upper(table.concat(parts, " "))
            if string.find(combinedText, "SPAWN", 1, true)
                or string.find(combinedText, "RESPAWN", 1, true)
                or string.find(combinedText, "REVIVE", 1, true) then
                local ok = pcall(function()
                    gui:Activate()
                end)

                if ok then
                    return true
                end
            end
        end
    end

    return false
end

local function findRespawnRemote()
    local remote = getMainRemoteEvent()
    if remote then
        return remote
    end

    for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
        if object:IsA("RemoteEvent") then
            local upperName = string.upper(object.Name)
            if string.find(upperName, "RESPAWN", 1, true) or string.find(upperName, "SPAWN", 1, true) then
                return object
            end
        end
    end

    return nil
end

local function respawnPlayer()
    if pendingRespawn or shuttingDown then
        return false
    end

    pendingRespawn = true
    local success = false

    if findSpawnButton() then
        success = true
    else
        local remoteEvent = findRespawnRemote()
        if remoteEvent then
            success = pcall(function()
                remoteEvent:FireServer({"Respawn"})
            end)

            if not success then
                success = pcall(function()
                    remoteEvent:FireServer("Respawn")
                end)
            end
        end
    end

    if not success then
        local character = LocalPlayer.Character
        if character then
            pcall(function()
                character:BreakJoints()
            end)
        end
    end

    pendingRespawn = false

    safeNotify({
        Title = success and "Respawn" or "Respawn Attempt",
        Content = success and "Respawn request sent." or "Fallback respawn triggered.",
        Duration = 2,
    })

    return success
end

local function restoreAutomationPosition()
    if autoPsychic and psychicLocations[selectedPsychic] then
        safeTeleport(psychicLocations[selectedPsychic])
        return
    end

    if autoStrength and strengthLocations[selectedStrength] then
        safeTeleport(strengthLocations[selectedStrength])
        return
    end

    if autoPool and pools[selectedPool] then
        safeTeleport(pools[selectedPool])
    end
end

local function disableOtherFarmModes(activeMode)
    if activeMode ~= "pool" and poolToggleRef and autoPool then
        setUiElementValue(poolToggleRef, false)
    end

    if activeMode ~= "strength" and strengthToggleRef and autoStrength then
        setUiElementValue(strengthToggleRef, false)
    end

    if activeMode ~= "psychic" and psychicToggleRef and autoPsychic then
        setUiElementValue(psychicToggleRef, false)
    end
end

local function applyUltraPreset()
    if farmDelaySliderRef then
        setUiElementValue(farmDelaySliderRef, 0.04)
    end

    if strengthBurstSliderRef then
        setUiElementValue(strengthBurstSliderRef, 10)
    end

    if psychicBurstSliderRef then
        setUiElementValue(psychicBurstSliderRef, 16)
    end

    if clickBurstSliderRef then
        setUiElementValue(clickBurstSliderRef, 5)
    end

    if positionLockSliderRef then
        setUiElementValue(positionLockSliderRef, 3)
    end

    if walkSpeedSliderRef then
        setUiElementValue(walkSpeedSliderRef, 42)
    end

    mouseAssist = true
    antiVoid = true

    safeNotify({
        Title = "Ultra Preset",
        Content = "Aggressive farm settings applied.",
        Duration = 3,
    })
end

local function restartScript()
    safeNotify({
        Title = "Reload",
        Content = "Attempting a safe reload in 2 seconds.",
        Duration = 2,
    })

    task.wait(2)

    local sourceCandidates = {
        "SPTS.lua",
        "./SPTS.lua",
    }
    local remoteCandidates = {
        "https://raw.githubusercontent.com/mohamadusmanov216-spec/StarScript/main/SPTS.lua",
    }

    local source = nil
    for _, path in ipairs(sourceCandidates) do
        local content = readLocalText(path)
        if content then
            source = content
            break
        end
    end

    if not source then
        for _, url in ipairs(remoteCandidates) do
            local content = httpGetText(url)
            if content then
                source = content
                break
            end
        end
    end

    if not source then
        safeNotify({
            Title = "Reload Failed",
            Content = "Could not find the current script source.",
            Duration = 4,
        })
        return
    end

    local chunk, compileError = compileSource(source, "@SPTS-reload")
    if not chunk then
        safeNotify({
            Title = "Reload Failed",
            Content = "The script source could not be compiled: " .. tostring(compileError),
            Duration = 4,
        })
        return
    end

    shutdownScript(true)
    task.wait(0.2)
    chunk()
end

local function applyFpsBoost(enabled)
    if enabled then
        pcall(function()
            settings().Rendering.QualityLevel = Enum.SavedQualitySetting.QualityLevel1
        end)
        pcall(function()
            Lighting.GlobalShadows = false
        end)
        safeNotify({
            Title = "FPS Boost",
            Content = "Low-quality rendering enabled.",
            Duration = 2,
        })
    else
        pcall(function()
            settings().Rendering.QualityLevel = Enum.SavedQualitySetting.Automatic
        end)
        pcall(function()
            Lighting.GlobalShadows = true
        end)
        safeNotify({
            Title = "FPS Boost",
            Content = "Rendering restored to automatic.",
            Duration = 2,
        })
    end
end

local function maintainCharacterState()
    local _, humanoid, rootPart = getCharacterParts()
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return
    end

    if rootPart.Position.Y > -25 then
        lastSafePosition = rootPart.Position
    end

    if antiVoid and rootPart.Position.Y < -50 then
        safeTeleport(lastSafePosition or teleportLocations["Spawn"])
    end

    if walkSpeedEnabled then
        pcall(function()
            if humanoid.WalkSpeed ~= walkSpeedValue then
                humanoid.WalkSpeed = walkSpeedValue
            end
        end)
    elseif defaultWalkSpeed and humanoid.WalkSpeed ~= defaultWalkSpeed then
        pcall(function()
            humanoid.WalkSpeed = defaultWalkSpeed
        end)
    end

    if godMode then
        pcall(function()
            humanoid.Health = humanoid.MaxHealth
        end)
        pcall(function()
            humanoid.PlatformStand = false
        end)
        pcall(function()
            humanoid.Sit = false
        end)
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end)
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end

    if antiKnockback then
        pcall(function()
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

if type(Rayfield) ~= "table" or type(Rayfield.CreateWindow) ~= "function" then
    error("StarRayfield did not load a valid library object.")
end

local windowOk, Window = pcall(function()
    return Rayfield:CreateWindow({
        Name = "SPTS SUPREME v4.0",
        LoadingTitle = "SPTS SUPREME",
        LoadingSubtitle = "Aggressive farm build",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "SPTSAuto",
            FileName = "Config",
        },
        Discord = {
            Enabled = false,
            Invite = "xwUDTAKFK5",
            RememberJoins = true,
        },
        KeySystem = false,
    })
end)

if not windowOk or not Window then
    error("StarRayfield window could not be created: " .. tostring(Window))
end

pcall(function()
    Window.ModifyTheme("AmberGlow")
end)

local DashboardTab = Window:CreateTab("Dashboard", 4483362458)
DashboardTab:CreateParagraph({
    Title = "Release Build",
    Content = "Stable UI loader, safer restarts, stronger farm bursts, and exclusive mode switching to avoid self-conflicting teleports.",
})

DashboardTab:CreateSection("Quick Actions")

DashboardTab:CreateButton({
    Name = "Apply Ultra Farm Preset",
    Callback = function()
        applyUltraPreset()
    end,
})

DashboardTab:CreateButton({
    Name = "Respawn Now",
    Callback = function()
        respawnPlayer()
    end,
})

DashboardTab:CreateButton({
    Name = "Status Snapshot",
    Callback = function()
        local _, humanoid, rootPart = getCharacterParts()
        local health = humanoid and math.floor(humanoid.Health) or 0
        local position = rootPart and rootPart.Position or Vector3.zero

        safeNotify({
            Title = "Status",
            Content = string.format(
                "HP %d | WS %d | Delay %.2f | Sx%d | Px%d",
                health,
                walkSpeedValue,
                farmLoopDelay,
                strengthBurst,
                psychicBurst
            ),
            Duration = 4,
        })

        print(string.format(
            "[SPTS] Pos: %.1f %.1f %.1f | Pool=%s | Strength=%s | Psychic=%s",
            position.X,
            position.Y,
            position.Z,
            tostring(autoPool),
            tostring(autoStrength),
            tostring(autoPsychic)
        ))
    end,
})

DashboardTab:CreateSection("General")

DashboardTab:CreateToggle({
    Name = "Auto Respawn",
    CurrentValue = false,
    Flag = "auto_respawn",
    Callback = function(value)
        autoRespawn = value
        if value then
            safeNotify({
                Title = "Auto Respawn",
                Content = "Enabled.",
                Duration = 2,
            })
        end
    end,
})

respawnDelaySliderRef = DashboardTab:CreateSlider({
    Name = "Respawn Delay",
    Range = {1, 10},
    Increment = 0.5,
    CurrentValue = 2,
    Suffix = "sec",
    Flag = "respawn_delay",
    Callback = function(value)
        respawnDelay = value
    end,
})

local FarmTab = Window:CreateTab("Farm", 3570695123)
FarmTab:CreateParagraph({
    Title = "Mode Logic",
    Content = "Training modes are exclusive. Enabling a new one disables the others so the character does not bounce between farm locations.",
})

FarmTab:CreateSection("Pool")
poolToggleRef = FarmTab:CreateToggle({
    Name = "Auto Pool",
    CurrentValue = false,
    Flag = "auto_pool",
    Callback = function(value)
        autoPool = value
        if value then
            disableOtherFarmModes("pool")
            safeNotify({
                Title = "Auto Pool",
                Content = "Target: " .. selectedPool,
                Duration = 2,
            })
        end
    end,
})

FarmTab:CreateDropdown({
    Name = "Pool Target",
    Options = poolOptions,
    CurrentOption = {selectedPool},
    Flag = "pool_target",
    Callback = function(option)
        selectedPool = resolveSingleOption(option, selectedPool)
    end,
})

FarmTab:CreateSection("Strength")
strengthToggleRef = FarmTab:CreateToggle({
    Name = "Auto Strength",
    CurrentValue = false,
    Flag = "auto_strength",
    Callback = function(value)
        autoStrength = value
        if value then
            disableOtherFarmModes("strength")
            safeNotify({
                Title = "Auto Strength",
                Content = "Target: " .. selectedStrength,
                Duration = 2,
            })
        end
    end,
})

FarmTab:CreateDropdown({
    Name = "Strength Target",
    Options = strengthOptions,
    CurrentOption = {selectedStrength},
    Flag = "strength_target",
    Callback = function(option)
        selectedStrength = resolveSingleOption(option, selectedStrength)
    end,
})

FarmTab:CreateSection("Psychic")
psychicToggleRef = FarmTab:CreateToggle({
    Name = "Auto Psychic",
    CurrentValue = false,
    Flag = "auto_psychic",
    Callback = function(value)
        autoPsychic = value
        if value then
            disableOtherFarmModes("psychic")
            safeNotify({
                Title = "Auto Psychic",
                Content = "Target: " .. selectedPsychic,
                Duration = 2,
            })
        end
    end,
})

FarmTab:CreateDropdown({
    Name = "Psychic Target",
    Options = psychicOptions,
    CurrentOption = {selectedPsychic},
    Flag = "psychic_target",
    Callback = function(option)
        selectedPsychic = resolveSingleOption(option, selectedPsychic)
    end,
})

FarmTab:CreateSection("Speed Farm")

farmDelaySliderRef = FarmTab:CreateSlider({
    Name = "Farm Loop Delay",
    Range = {0.03, 0.25},
    Increment = 0.01,
    CurrentValue = 0.08,
    Suffix = "sec",
    Flag = "farm_delay",
    Callback = function(value)
        farmLoopDelay = value
    end,
})

strengthBurstSliderRef = FarmTab:CreateSlider({
    Name = "Strength Burst",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = 6,
    Suffix = "calls",
    Flag = "strength_burst",
    Callback = function(value)
        strengthBurst = value
    end,
})

psychicBurstSliderRef = FarmTab:CreateSlider({
    Name = "Psychic Burst",
    Range = {1, 25},
    Increment = 1,
    CurrentValue = 10,
    Suffix = "casts",
    Flag = "psychic_burst",
    Callback = function(value)
        psychicBurst = value
    end,
})

clickBurstSliderRef = FarmTab:CreateSlider({
    Name = "Mouse Assist Burst",
    Range = {0, 8},
    Increment = 1,
    CurrentValue = 3,
    Suffix = "clicks",
    Flag = "click_burst",
    Callback = function(value)
        clickBurst = value
    end,
})

positionLockSliderRef = FarmTab:CreateSlider({
    Name = "Position Lock Radius",
    Range = {2, 12},
    Increment = 1,
    CurrentValue = 6,
    Suffix = "studs",
    Flag = "position_lock_radius",
    Callback = function(value)
        positionLockRadius = value
    end,
})

FarmTab:CreateToggle({
    Name = "Mouse Assist",
    CurrentValue = true,
    Flag = "mouse_assist",
    Callback = function(value)
        mouseAssist = value
    end,
})

local ProtectionTab = Window:CreateTab("Protection", 3943728921)
ProtectionTab:CreateParagraph({
    Title = "Best Effort God Mode",
    Content = "This tries to keep health full, cancel ragdoll-like states, recover from void falls, and optionally remove knockback. Full server-side immunity still depends on the game.",
})

ProtectionTab:CreateSection("Defense")

ProtectionTab:CreateToggle({
    Name = "God Mode",
    CurrentValue = false,
    Flag = "god_mode",
    Callback = function(value)
        godMode = value
        if value then
            safeNotify({
                Title = "God Mode",
                Content = "Best-effort protection enabled.",
                Duration = 2,
            })
        end
    end,
})

ProtectionTab:CreateToggle({
    Name = "Anti Void",
    CurrentValue = true,
    Flag = "anti_void",
    Callback = function(value)
        antiVoid = value
    end,
})

ProtectionTab:CreateToggle({
    Name = "Anti Knockback",
    CurrentValue = false,
    Flag = "anti_knockback",
    Callback = function(value)
        antiKnockback = value
    end,
})

local MovementTab = Window:CreateTab("Movement", 6022668967)
MovementTab:CreateSection("Mobility")

MovementTab:CreateToggle({
    Name = "WalkSpeed Override",
    CurrentValue = false,
    Flag = "walkspeed_enabled",
    Callback = function(value)
        walkSpeedEnabled = value
    end,
})

walkSpeedSliderRef = MovementTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 80},
    Increment = 1,
    CurrentValue = 35,
    Suffix = "ws",
    Flag = "walkspeed_value",
    Callback = function(value)
        walkSpeedValue = value
    end,
})

MovementTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "infinite_jump",
    Callback = function(value)
        infiniteJump = value
    end,
})

local TeleportTab = Window:CreateTab("Teleports", 4483362458)
TeleportTab:CreateSection("Locations")

for name, position in pairs(teleportLocations) do
    TeleportTab:CreateButton({
        Name = name,
        Callback = function()
            local ok = safeTeleport(position)
            safeNotify({
                Title = ok and "Teleport" or "Teleport Failed",
                Content = ok and ("Moved to " .. name .. ".") or ("Could not move to " .. name .. "."),
                Duration = 2,
            })
        end,
    })
end

TeleportTab:CreateSection("Coordinates")

TeleportTab:CreateButton({
    Name = "Show My Coordinates",
    Callback = function()
        showCurrentCoordinates()
    end,
})

local UtilityTab = Window:CreateTab("Utility", 3943728921)
UtilityTab:CreateSection("Quality")

UtilityTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Flag = "anti_afk",
    Callback = function(value)
        antiAfk = value
    end,
})

UtilityTab:CreateToggle({
    Name = "FPS Boost",
    CurrentValue = false,
    Flag = "fps_boost",
    Callback = function(value)
        applyFpsBoost(value)
    end,
})

UtilityTab:CreateDropdown({
    Name = "Theme",
    Options = themeOptions,
    CurrentOption = {"AmberGlow"},
    Flag = "ui_theme",
    Callback = function(option)
        local themeName = resolveSingleOption(option, "AmberGlow")
        if themeName then
            pcall(function()
                Window.ModifyTheme(themeName)
            end)
        end
    end,
})

UtilityTab:CreateSection("Actions")

UtilityTab:CreateButton({
    Name = "Restore Farm Position",
    Callback = function()
        restoreAutomationPosition()
    end,
})

UtilityTab:CreateButton({
    Name = "Copy Discord",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/xwUDTAKFK5")
            safeNotify({
                Title = "Discord",
                Content = "Invite copied to clipboard.",
                Duration = 3,
            })
        else
            safeNotify({
                Title = "Discord",
                Content = "Clipboard access is not available in this executor.",
                Duration = 3,
            })
        end
    end,
})

UtilityTab:CreateButton({
    Name = "Reload Script",
    Callback = function()
        restartScript()
    end,
})

local function setupDeathHandler(character)
    if deathConnection then
        pcall(function()
            deathConnection:Disconnect()
        end)
        deathConnection = nil
    end

    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    defaultWalkSpeed = humanoid.WalkSpeed

    deathConnection = humanoid.Died:Connect(function()
        if shuttingDown then
            return
        end

        safeNotify({
            Title = "Character Died",
            Content = autoRespawn and "Waiting to respawn." or "Auto respawn is disabled.",
            Duration = 2,
        })

        if autoRespawn then
            task.delay(respawnDelay, function()
                if scriptRunning and not shuttingDown then
                    respawnPlayer()
                end
            end)
        end
    end)
end

local function onCharacterAdded(character)
    if shuttingDown then
        return
    end

    task.wait(0.75)
    setupDeathHandler(character)

    if autoPool or autoStrength or autoPsychic then
        task.wait(1)
        restoreAutomationPosition()
    end
end

trackConnection(LocalPlayer.CharacterAdded:Connect(onCharacterAdded))

if LocalPlayer.Character then
    setupDeathHandler(LocalPlayer.Character)
end

trackConnection(UserInputService.JumpRequest:Connect(function()
    if not infiniteJump then
        return
    end

    local _, humanoid = getCharacterParts()
    if humanoid and humanoid.Health > 0 then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end))

task.spawn(function()
    while scriptRunning do
        if antiAfk and isAlive() then
            pcall(pulseMovement)
        end

        task.wait(25)
    end
end)

task.spawn(function()
    while scriptRunning do
        if isAlive() then
            pcall(maintainCharacterState)
        end

        task.wait(0.08)
    end
end)

task.spawn(function()
    while scriptRunning do
        if autoPool and isAlive() and pools[selectedPool] then
            local _, _, rootPart = getCharacterParts()
            local target = pools[selectedPool]

            if rootPart and (rootPart.Position - target).Magnitude > positionLockRadius then
                safeTeleport(target)
            end
        end

        task.wait(0.2)
    end
end)

task.spawn(function()
    while scriptRunning do
        if autoStrength and isAlive() and strengthLocations[selectedStrength] then
            local _, _, rootPart = getCharacterParts()
            local target = strengthLocations[selectedStrength]

            if rootPart and (rootPart.Position - target).Magnitude > positionLockRadius then
                safeTeleport(target)
            end

            for index = 1, strengthBurst do
                fireStrengthRequest()

                if index % 4 == 0 then
                    task.wait(0.01)
                end
            end

            for index = 1, clickBurst do
                sendMouseClick()

                if index % 2 == 0 then
                    task.wait(0.01)
                end
            end
        end

        task.wait(farmLoopDelay)
    end
end)

task.spawn(function()
    while scriptRunning do
        if autoPsychic and isAlive() and psychicLocations[selectedPsychic] then
            local _, _, rootPart = getCharacterParts()
            local target = psychicLocations[selectedPsychic]

            if rootPart and (rootPart.Position - target).Magnitude > positionLockRadius then
                safeTeleport(target)
            end

            local tool = equipPsychicTool()
            if tool then
                for index = 1, psychicBurst do
                    pcall(function()
                        tool:Activate()
                    end)

                    if clickBurst > 0 and index <= clickBurst then
                        sendMouseClick()
                    end

                    if index % 4 == 0 then
                        task.wait(0.01)
                    end
                end
            end
        end

        task.wait(farmLoopDelay)
    end
end)

task.delay(0.5, function()
    local _, humanoid = getCharacterParts()
    if humanoid and humanoid.Health <= 0 and autoRespawn then
        task.wait(respawnDelay)
        if scriptRunning then
            respawnPlayer()
        end
    end
end)

safeNotify({
    Title = "SPTS SUPREME v4.0",
    Content = "Loaded successfully. Start with Ultra Farm Preset, then tune bursts if the server begins to throttle.",
    Duration = 6,
})

pcall(function()
    game:BindToClose(function()
        shutdownScript(true)
    end)
end)
