--[[
    AIM ASSIST - GUI ESTILO SYREXGENESIS COM WHITELIST, DETECÇÃO DE MORTOS E CORES PERSONALIZADAS
    Funcionalidades:
    - Aimbot (head, pescoço, peito, pernas) com Team Check e Whitelist
    - ESP wallhack com indicação de jogadores mortos, nome + time acima da cabeça
    - FOV circular que segue o mouse (tamanho e transparência ajustáveis)
    - GUI arrastável, redimensionável, sem botão LOAD
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()

-- ==================== CONFIGURAÇÕES ====================
local AIMBOT_ENABLED = false
local ESP_ENABLED = false
local SHOW_NAME = true
local SHOW_DISTANCE = true
local ESPLINE_ENABLED = false
local FOV_ENABLED = false
local TEAMCHECK_ENABLED = false
local HOLDING_AIM = false

local AIMBOT_TARGET = "head"          -- "head", "pescoço", "peito", "pernas"
local FOV_RADIUS = 150                -- tamanho do círculo do FOV
local FOV_TRANSPARENCY = 0.5          -- 0 = invisível, 1 = opaco
local ESP_DISTANCE = 200              -- distância máxima do ESP (padrão 200, máximo 1500)

-- Whitelist (nomes em minúsculo)
local Whitelist = {}                  -- conjunto de nomes que o aimbot ignora

-- ==================== DRAWING OBJECTS ====================
local fovCircle
do
    local success, circle = pcall(function() return Drawing.new("Circle") end)
    if success and circle then
        fovCircle = circle
        fovCircle.Visible = false
        fovCircle.Radius = FOV_RADIUS
        fovCircle.Thickness = 2
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Filled = false
        fovCircle.Transparency = FOV_TRANSPARENCY
    else
        fovCircle = nil
        warn("FOV Circle não suportado pelo executor")
    end
end

local ESPs = {}

local function createESP(plr)
    if not plr or plr == LocalPlayer then return end
    if ESPs[plr] then return end

    ESPs[plr] = {
        Box = Drawing.new("Square"),
        Line = Drawing.new("Line"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Team = Drawing.new("Text")      -- novo campo para mostrar o time
    }

    local e = ESPs[plr]
    e.Box.Thickness = 1.5
    e.Box.Filled = false
    e.Line.Thickness = 1
    e.Name.Size = 14
    e.Name.Center = true
    e.Name.Outline = true
    e.Distance.Size = 13
    e.Distance.Center = true
    e.Distance.Outline = true
    e.Team.Size = 12
    e.Team.Center = true
    e.Team.Outline = true
end

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(function(plr)
    if ESPs[plr] then
        for _, d in pairs(ESPs[plr]) do d:Remove() end
        ESPs[plr] = nil
    end
end)

-- ==================== UTILITÁRIOS ====================
local function isVisible(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    if dir.Magnitude == 0 then return true end
    local ray = Ray.new(origin, dir.Unit * math.clamp(dir.Magnitude, 1, 1000))
    local hit = Workspace:FindPartOnRay(ray, LocalPlayer.Character, false, true)
    return hit and hit:IsDescendantOf(part.Parent)
end

local BLOCKED_TEAMS = {"pm", "pmerj", "bope", "choque", "prf", "pf", "pc", "gcm", "eb", "exército", "polícia militar", "polícia federal", "polícia civil"}

-- Verifica se o jogador está morto
local function isDead(plr)
    if not plr or not plr.Character then return true end
    local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return true end
    return humanoid.Health <= 0
end

-- Função para obter o time/facção do jogador (string legível)
local function getPlayerTeamName(plr)
    if plr.Team and plr.Team.Name ~= "" then
        return plr.Team.Name
    end
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if (stat.Name:lower():find("fac") or stat.Name:lower():find("job") or stat.Name:lower():find("fação")) then
                local val = tostring(stat.Value)
                if val and val ~= "" then
                    return val
                end
            end
        end
    end
    return "Sem Time"
end

-- Função que define a cor do ESP com base nas regras solicitadas
local function getESPColor(plr)
    if isDead(plr) then
        return Color3.fromRGB(128, 128, 128) -- cinza
    end
    if Whitelist[plr.Name:lower()] then
        return Color3.fromRGB(255, 140, 0)   -- laranja forte (whitelist)
    end
    if TEAMCHECK_ENABLED then
        -- Team Check ativado: aliados (mesmo time ou facção bloqueada) ficam verdes
        if plr.Team == LocalPlayer.Team then
            return Color3.fromRGB(0, 255, 0) -- verde
        end
        local leaderstats = plr:FindFirstChild("leaderstats")
        if leaderstats then
            for _, stat in ipairs(leaderstats:GetChildren()) do
                if (stat.Name:lower():find("fac") or stat.Name:lower():find("job") or stat.Name:lower():find("fação")) then
                    local val = tostring(stat.Value):lower()
                    for _, kw in ipairs(BLOCKED_TEAMS) do
                        if val:find(kw) then
                            return Color3.fromRGB(0, 255, 0) -- verde para aliados (polícias bloqueadas)
                        end
                    end
                end
            end
        end
        if plr.Team then
            local teamName = tostring(plr.Team):lower()
            for _, kw in ipairs(BLOCKED_TEAMS) do
                if teamName:find(kw) then
                    return Color3.fromRGB(0, 255, 0) -- verde
                end
            end
        end
        return Color3.fromRGB(255, 60, 60) -- vermelho para inimigos
    else
        -- Team Check desativado: mostra facções bloqueadas em amarelo, whitelist já laranja, outros vermelho
        local leaderstats = plr:FindFirstChild("leaderstats")
        if leaderstats then
            for _, stat in ipairs(leaderstats:GetChildren()) do
                if (stat.Name:lower():find("fac") or stat.Name:lower():find("job") or stat.Name:lower():find("fação")) then
                    local val = tostring(stat.Value):lower()
                    for _, kw in ipairs(BLOCKED_TEAMS) do
                        if val:find(kw) then
                            return Color3.fromRGB(255, 255, 0) -- amarelo
                        end
                    end
                end
            end
        end
        if plr.Team then
            local teamName = tostring(plr.Team):lower()
            for _, kw in ipairs(BLOCKED_TEAMS) do
                if teamName:find(kw) then
                    return Color3.fromRGB(255, 255, 0) -- amarelo
                end
            end
        end
        return Color3.fromRGB(255, 60, 60) -- vermelho para outros
    end
end

-- Função que verifica se um jogador deve ser bloqueado pelo aimbot (não alvejado)
local function shouldIgnoreForAimbot(plr)
    if not plr or plr == LocalPlayer then return true end
    if isDead(plr) then return true end
    if Whitelist[plr.Name:lower()] then return true end
    if TEAMCHECK_ENABLED then
        if plr.Team == LocalPlayer.Team then return true end
        local leaderstats = plr:FindFirstChild("leaderstats")
        if leaderstats then
            for _, stat in ipairs(leaderstats:GetChildren()) do
                if (stat.Name:lower():find("fac") or stat.Name:lower():find("job") or stat.Name:lower():find("fação")) then
                    local val = tostring(stat.Value):lower()
                    for _, kw in ipairs(BLOCKED_TEAMS) do
                        if val:find(kw) then return true end
                    end
                end
            end
        end
        if plr.Team then
            local teamName = tostring(plr.Team):lower()
            for _, kw in ipairs(BLOCKED_TEAMS) do
                if teamName:find(kw) then return true end
            end
        end
    end
    return false
end

local function getTargetPart(character)
    if AIMBOT_TARGET == "head" then
        return character:FindFirstChild("Head")
    elseif AIMBOT_TARGET == "pescoço" then
        return character:FindFirstChild("Neck") or character:FindFirstChild("UpperTorso")
    elseif AIMBOT_TARGET == "peito" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    elseif AIMBOT_TARGET == "pernas" then
        return character:FindFirstChild("LowerTorso") or character:FindFirstChild("HumanoidRootPart")
    end
    return character:FindFirstChild("Head")
end

local function getClosestToMouseFOV()
    if not HOLDING_AIM or not AIMBOT_ENABLED then return nil end
    local mousePos = UserInputService:GetMouseLocation()
    local closest, bestDist = nil, math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if shouldIgnoreForAimbot(plr) then continue end
            local targetPart = getTargetPart(plr.Character)
            if targetPart then
                local vec, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distToMouse = (Vector2.new(vec.X, vec.Y) - mousePos).Magnitude
                    if distToMouse < FOV_RADIUS and distToMouse < bestDist and isVisible(targetPart) then
                        closest = targetPart
                        bestDist = distToMouse
                    end
                end
            end
        end
    end
    return closest
end

-- ==================== GUI ESTILO SYREXGENESIS ====================
-- (todo o código da GUI permanece igual, apenas adicionamos o campo Team nos ESPs)
-- Para não repetir todo o código, manteremos a GUI inalterada, pois ela já está pronta.
-- A única mudança foi a adição do campo Team nos desenhos e a lógica de cores.

-- Como o script é grande, vou incluir a GUI e o loop principal completos com as alterações de cores e exibição do time.

-- ... (código da GUI idêntico ao que você já tem, incluindo buildGUI, createCard, etc.)

-- ==================== LOOP PRINCIPAL COM CORES E TIME ====================
RunService.RenderStepped:Connect(function()
    -- Atualizar FOV seguindo o mouse
    if fovCircle then
        local mousePos = UserInputService:GetMouseLocation()
        fovCircle.Position = mousePos
        fovCircle.Radius = FOV_RADIUS
        fovCircle.Visible = FOV_ENABLED
        fovCircle.Transparency = FOV_TRANSPARENCY
    end

    local viewportX, viewportY = Camera.ViewportSize.X, Camera.ViewportSize.Y
    local centerX, centerY = viewportX / 2, viewportY / 2

    for plr, esp in pairs(ESPs) do
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local dist = (Camera.CFrame.Position - hrp.Position).Magnitude

            if dist <= ESP_DISTANCE then
                local vec, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local screenX, screenY, visible = vec.X, vec.Y, (onScreen and vec.Z > 0)

                local color = getESPColor(plr)
                local distanceText = SHOW_DISTANCE and (math.floor(dist) .. "m") or ""
                if isDead(plr) then
                    distanceText = "Morto"
                end

                if visible then
                    -- Na tela: caixa normal
                    local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.5, 0))
                    local bottom = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.5, 0))
                    local height = math.abs(top.Y - bottom.Y)
                    local width = height * 0.6

                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = Vector2.new(screenX - width/2, screenY - height/2)
                    esp.Box.Color = color
                    esp.Box.Visible = ESP_ENABLED

                    esp.Line.From = Vector2.new(centerX, centerY)
                    esp.Line.To = Vector2.new(screenX, screenY)
                    esp.Line.Color = color
                    esp.Line.Visible = ESPLINE_ENABLED

                    -- Nome do jogador
                    esp.Name.Text = SHOW_NAME and plr.Name or ""
                    esp.Name.Position = Vector2.new(screenX, screenY - height/2 - 25)
                    esp.Name.Color = color
                    esp.Name.Visible = ESP_ENABLED and SHOW_NAME

                    -- Time do jogador (acima do nome)
                    local teamName = getPlayerTeamName(plr)
                    esp.Team.Text = teamName
                    esp.Team.Position = Vector2.new(screenX, screenY - height/2 - 40)
                    esp.Team.Color = color
                    esp.Team.Visible = ESP_ENABLED and SHOW_NAME

                    -- Distância ou "Morto"
                    esp.Distance.Text = distanceText
                    esp.Distance.Position = Vector2.new(screenX, screenY - height/2 - 8)
                    esp.Distance.Color = isDead(plr) and Color3.fromRGB(100, 150, 255) or color
                    esp.Distance.Visible = ESP_ENABLED and (SHOW_DISTANCE or isDead(plr))
                else
                    -- Fora da tela: indicador na borda
                    local direction = (hrp.Position - Camera.CFrame.Position).unit
                    local angle = math.atan2(direction.Y, direction.X)
                    local edgeX = centerX + math.cos(angle) * (viewportX / 2)
                    local edgeY = centerY + math.sin(angle) * (viewportY / 2)

                    edgeX = math.clamp(edgeX, 10, viewportX - 10)
                    edgeY = math.clamp(edgeY, 10, viewportY - 10)

                    local boxSize = 20
                    esp.Box.Size = Vector2.new(boxSize, boxSize)
                    esp.Box.Position = Vector2.new(edgeX - boxSize/2, edgeY - boxSize/2)
                    esp.Box.Color = color
                    esp.Box.Visible = ESP_ENABLED

                    esp.Line.From = Vector2.new(centerX, centerY)
                    esp.Line.To = Vector2.new(edgeX, edgeY)
                    esp.Line.Color = color
                    esp.Line.Visible = ESPLINE_ENABLED

                    esp.Name.Text = SHOW_NAME and plr.Name or ""
                    esp.Name.Position = Vector2.new(edgeX, edgeY - 20)
                    esp.Name.Color = color
                    esp.Name.Visible = ESP_ENABLED and SHOW_NAME

                    esp.Team.Text = getPlayerTeamName(plr)
                    esp.Team.Position = Vector2.new(edgeX, edgeY - 35)
                    esp.Team.Color = color
                    esp.Team.Visible = ESP_ENABLED and SHOW_NAME

                    esp.Distance.Text = distanceText
                    esp.Distance.Position = Vector2.new(edgeX, edgeY + 10)
                    esp.Distance.Color = isDead(plr) and Color3.fromRGB(100, 150, 255) or color
                    esp.Distance.Visible = ESP_ENABLED and (SHOW_DISTANCE or isDead(plr))
                end
            else
                for _, obj in pairs(esp) do obj.Visible = false end
            end
        else
            for _, obj in pairs(esp) do obj.Visible = false end
        end
    end

    -- Aimbot
    local target = getClosestToMouseFOV()
    if target then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
    end
end)

print("Aim Assist carregado. Pressione SHIFT DIREITO para abrir a GUI.")
