--!strict
--[[
	Events.lua — eventi casuali di contorno: porta che si chiude da sola, ombra che attraversa un corridoio,
	monitor che si disturba per un istante, sagoma dietro il vetro (la piu' rara).
	Ogni evento ha il suo cooldown; un evento non parte se un giocatore e' troppo vicino.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Config = require(shared:WaitForChild("Config"))
local Rules = require(shared:WaitForChild("Rules"))
local Net = require(shared:WaitForChild("Net"))
local Lights = require(script.Parent.Lights)
local Apparition = require(script.Parent.Apparition)

local Events = {}

local OPEN_ANGLE = -1.2 -- stessa apertura iniziale della porta nel Builder
local rng: Random
local folder: Instance
local visuals: RemoteEvent
local doorRef: { part: Part, hinge: Vector3 }? = nil
local monitorList: { Part } = {}
local lastAt: { [string]: number } = {}
local lastAny: number? = nil

-- Vero se un giocatore e' entro "radius" studs dal punto.
local function playerNear(position: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude < radius then
			return true
		end
	end
	return false
end

-- Porta ruotata sulla cerniera: si chiude piano; se un giocatore si avvicina torna indietro.
local function swingDoor(door: Part, hinge: Vector3)
	local angle = Instance.new("NumberValue")
	angle.Value = OPEN_ANGLE
	angle.Parent = folder
	local connection = angle.Changed:Connect(function()
		door.CFrame = CFrame.new(hinge) * CFrame.Angles(0, angle.Value, 0) * CFrame.new(3, 3.5, 0)
	end)

	local function reopen()
		local tween = TweenService:Create(angle, TweenInfo.new(6, Enum.EasingStyle.Sine), { Value = OPEN_ANGLE })
		tween.Completed:Connect(function()
			connection:Disconnect()
			angle:Destroy()
		end)
		tween:Play()
	end

	local closing = TweenService:Create(angle, TweenInfo.new(9, Enum.EasingStyle.Sine), { Value = 0 })
	local guard: RBXScriptConnection? = nil
	guard = RunService.Heartbeat:Connect(function()
		if closing.PlaybackState == Enum.PlaybackState.Playing and playerNear(door.Position, 8) then
			closing:Cancel()
			if guard then
				guard:Disconnect()
			end
		end
	end)
	closing.Completed:Connect(function(state: Enum.PlaybackState)
		if guard then
			guard:Disconnect()
		end
		if state == Enum.PlaybackState.Completed then
			task.delay(4, reopen)
		else
			reopen()
		end
	end)
	Lights.playAt(door, Config.Sounds.Door, 0.6)
	closing:Play()
end

-- Ombra scura e semitrasparente che attraversa il corridoio in pochi secondi.
local function crossShadow()
	local fromWest = rng:NextNumber() < 0.5
	local z = Rules.randomBetween(rng, -2, 2)
	local startX = if fromWest then -95 else 95
	local endX = -startX

	local shadow = Instance.new("Part")
	shadow.Name = "Shadow"
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanQuery = false
	shadow.CanTouch = false
	shadow.CastShadow = false
	shadow.Material = Enum.Material.SmoothPlastic
	shadow.Color = Color3.fromRGB(4, 4, 5)
	shadow.Transparency = 1
	shadow.Size = Vector3.new(2.2, 6.5, 0.3)
	shadow.CFrame = CFrame.new(startX, 3.2, z)
	shadow.Parent = folder

	local info = TweenInfo.new(1.6, Enum.EasingStyle.Linear)
	TweenService:Create(shadow, TweenInfo.new(0.25), { Transparency = 0.7 }):Play()
	TweenService:Create(shadow, info, { CFrame = CFrame.new(endX, 3.2, z) }):Play()
	task.delay(1.3, function()
		TweenService:Create(shadow, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	task.delay(2, function()
		shadow:Destroy()
	end)
end

-- Il monitor si disturba per un istante: il client disegna la statica, qui si manda solo il segnale.
local function monitorStatic()
	local monitors = monitorList
	if #monitors == 0 then
		return
	end
	local monitor = monitors[rng:NextInteger(1, #monitors)]
	visuals:FireAllClients("static", monitor)
	Lights.playAt(monitor, Config.Sounds.Static, 0.35)
end

-- Sceglie e avvia un evento, rispettando cooldown e distanza dai giocatori. Restituisce il nome se e' partito.
local function tryEvent(name: string): string?
	local now = os.clock()
	if name == "door" then
		local door = doorRef
		if not door or playerNear(door.part.Position, 14) then
			return nil
		end
		swingDoor(door.part, door.hinge)
	elseif name == "shadow" then
		crossShadow()
	elseif name == "monitor" then
		monitorStatic()
	end
	lastAt[name] = now
	lastAny = now
	return name
end

-- Programma gli eventi a intervalli casuali. Ogni tick sceglie al massimo un evento.
function Events.run()
	while true do
		task.wait(Rules.randomBetween(rng, Config.Events.TickMin, Config.Events.TickMax))
		local now = os.clock()
		if not Rules.cooldownReady(lastAny, now, Config.Events.GlobalCooldown) then
			continue
		end

		if rng:NextNumber() < Config.Events.GlimpseChance and Rules.cooldownReady(lastAt.glimpse, now, Config.Events.GlimpseCooldown) then
			Apparition.glimpse()
			lastAt.glimpse = now
			lastAny = now
			continue
		end

		local entries = {
			{ name = "door", weight = if Rules.cooldownReady(lastAt.door, now, Config.Events.DoorCooldown) then 3 else 0 },
			{ name = "shadow", weight = if Rules.cooldownReady(lastAt.shadow, now, Config.Events.ShadowCooldown) then 3 else 0 },
			{ name = "monitor", weight = if Rules.cooldownReady(lastAt.monitor, now, Config.Events.MonitorCooldown) then 2 else 0 },
			{ name = "none", weight = 3 },
		}
		local picked = Rules.pickWeighted(rng, entries)
		if picked and picked ~= "none" then
			tryEvent(picked)
		end
	end
end

-- Prepara gli eventi con la porta e i monitor del layout.
function Events.init(door: { part: Part, hinge: Vector3 }, monitors: { Part }, parent: Instance, random: Random)
	doorRef = door
	monitorList = monitors
	folder = parent
	rng = random
	visuals = Net.event("LightsEvent")
end

return Events
