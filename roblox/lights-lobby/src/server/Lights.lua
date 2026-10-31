--!strict
--[[
	Lights.lua — sistema delle luci (solo server; lo stato delle Part e delle PointLight si replica da solo).
	- Ogni lampada lampeggia in modo irregolare; alcune sono "malate" e lampeggiano di piu'.
	- Ogni tanto la corrente salta: breve interruzione o blackout generale (raro).
	- Al ritorno le lampade si riaccendono con ritardo casuale; a volte una ripete il lampeggio.
	- Passarci sotto spegne per un attimo la lampada.
	Gli eventi importanti vengono inviati ai client (LightsEvent) per sincronizzare logo e monitor.
]]

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LightsLobby")
local Config = require(shared:WaitForChild("Config"))
local Rules = require(shared:WaitForChild("Rules"))
local Net = require(shared:WaitForChild("Net"))

local Lights = {}

export type Lamp = { housing: Part, light: PointLight, trigger: Part? }
export type Fixture = {
	housing: Part,
	light: PointLight,
	trigger: Part?,
	buzz: Sound?,
	powered: boolean, -- la corrente arriva a questa lampada
	lit: boolean, -- stato del lampeggio
	forced: number, -- quante cause la tengono spenta (es. un giocatore ci passa sotto)
	unstable: boolean, -- lampada "malata"
	lastTrigger: number?,
}

local LIT_COLOR = Color3.fromRGB(226, 244, 236)
local OFF_COLOR = Color3.fromRGB(52, 54, 56)
local DARK_AMBIENT = Color3.fromRGB(3, 3, 4)

local fixtures: { Fixture } = {}
local rng: Random
local event: RemoteEvent
local baseAmbient: Color3

-- Gruppi audio controllabili dalle impostazioni del client (volume musica / effetti).
Lights.groups = {}

-- Crea un Sound solo se l'ID e' configurato: senza ID il suono viene saltato, nessun errore.
local function makeSound(parent: Instance, id: string, volume: number, group: SoundGroup?, looped: boolean): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.RollOffMaxDistance = 40
	if group then
		sound.SoundGroup = group
	end
	sound.Parent = parent
	return sound
end

-- Suono una tantum posizionato nello spazio 3D vicino a una lampada.
local function playAt(part: BasePart, id: string, volume: number)
	local sound = makeSound(part, id, volume, Lights.groups.Effects, false)
	if sound then
		sound:Play()
		Debris:AddItem(sound, 12)
	end
end

-- Applica lo stato reale a una lampada: accesa solo se riceve corrente, e' nel suo lampeggio attivo e non e' forzata spenta.
local function apply(f: Fixture)
	local on = f.powered and f.lit and f.forced == 0
	f.light.Enabled = on
	f.housing.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	f.housing.Color = if on then LIT_COLOR else OFF_COLOR
	if f.buzz then
		if on and not f.buzz.IsPlaying then
			f.buzz:Play()
		elseif not on and f.buzz.IsPlaying then
			f.buzz:Stop()
		end
	end
end

local function setPowered(f: Fixture, value: boolean)
	f.powered = value
	apply(f)
end

-- Lampeggio irregolare: qualche on/off rapido, poi torna stabile.
local function flicker(f: Fixture)
	if not f.powered then
		return
	end
	local steps = if f.unstable then rng:NextInteger(3, 8) else rng:NextInteger(1, 3)
	for _ = 1, steps do
		f.lit = not f.lit
		apply(f)
		task.wait(Rules.randomBetween(rng, 0.03, 0.16))
	end
	f.lit = true
	apply(f)
end

-- Ciclo di vita di una lampada: lampeggia a intervalli casuali (piu' spesso se malata).
local function runFixture(f: Fixture)
	while true do
		local interval = Rules.randomBetween(rng, Config.Lights.FlickerIntervalMin, Config.Lights.FlickerIntervalMax)
		task.wait(if f.unstable then interval * 0.5 else interval)
		flicker(f)
	end
end

-- Una lampada che riceve un giocatore sotto la colonna trigger si spegne per un attimo.
local function connectTrigger(f: Fixture)
	if not f.trigger then
		return
	end
	f.trigger.Touched:Connect(function(hit: BasePart)
		local model = hit.Parent
		if not model or not model:FindFirstChildOfClass("Humanoid") then
			return
		end
		local now = os.clock()
		if f.forced > 0 or not Rules.cooldownReady(f.lastTrigger, now, 25) then
			return
		end
		f.lastTrigger = now
		f.forced += 1
		apply(f)
		task.delay(Config.Lights.TriggerLampOffTime, function()
			f.forced -= 1
			apply(f)
		end)
	end)
end

local function tweenAmbient(color: Color3, time: number)
	TweenService:Create(Lighting, TweenInfo.new(time, Enum.EasingStyle.Quad), { Ambient = color }):Play()
end

-- Un'interruzione di corrente ("cut" breve o "blackout" generale).
-- onStart/onEnd permettono ad Apparition di agganciarsi al buio senza conoscere le luci.
local function dark(kind: string, duration: number, onStart: (string, number) -> (), onEnd: () -> ())
	event:FireAllClients(kind, duration)
	local sample = fixtures[rng:NextInteger(1, #fixtures)]
	playAt(sample.housing, Config.Sounds.PowerDown, 0.8)
	if kind == "blackout" then
		tweenAmbient(DARK_AMBIENT, 0.4)
		playAt(sample.housing, Config.Sounds.Crackle, 0.6)
	end

	-- Lo spegnimento non e' istantaneo: ogni lampada si spegne con un piccolo sfasamento.
	for _, f in fixtures do
		task.delay(Rules.randomBetween(rng, 0, 0.12), setPowered, f, false)
	end

	onStart(kind, duration)
	task.wait(duration)
	onEnd()

	-- Riaccensione scaglionata; alcune lampade ripetono il lampeggio.
	for _, f in fixtures do
		task.delay(Rules.restoreDelay(rng, Config.Lights.RestoreSpread), function()
			setPowered(f, true)
			if rng:NextNumber() < 0.3 then
				task.spawn(flicker, f)
			end
		end)
	end
	if kind == "blackout" then
		tweenAmbient(baseAmbient, 0.8)
	end
	event:FireAllClients("restore")
	playAt(sample.housing, Config.Sounds.PowerUp, 0.7)
end

-- Crea lo stato delle lampade, i gruppi audio e avvia i cicli di lampeggio.
function Lights.init(lamps: { Lamp }, random: Random)
	rng = random
	event = Net.event("LightsEvent")
	baseAmbient = Lighting.Ambient

	for _, name in { "Ambient", "Effects" } do
		local group = Instance.new("SoundGroup")
		group.Name = "Lights" .. name
		group.Parent = SoundService
		Lights.groups[name] = group
	end

	for _, lamp in lamps do
		local f: Fixture = {
			housing = lamp.housing,
			light = lamp.light,
			trigger = lamp.trigger,
			buzz = makeSound(lamp.housing, Config.Sounds.Buzz, 0.25, Lights.groups.Ambient, true),
			powered = true,
			lit = true,
			forced = 0,
			unstable = rng:NextNumber() < Config.Lights.UnstableChance,
			lastTrigger = nil,
		}
		table.insert(fixtures, f)
		apply(f)
		connectTrigger(f)
		task.spawn(runFixture, f)
	end
end

-- Ciclo principale degli eventi di luce. Chiama onStart/onEnd attorno ai blackout.
function Lights.run(onStart: (string, number) -> (), onEnd: () -> ())
	local nextBlackoutAt = os.clock()
		+ Rules.randomBetween(rng, Config.Lights.BlackoutMinGap, Config.Lights.BlackoutMaxGap)
	while true do
		task.wait(Rules.randomBetween(rng, Config.Lights.CutIntervalMin, Config.Lights.CutIntervalMax))
		if os.clock() >= nextBlackoutAt then
			nextBlackoutAt = os.clock()
				+ Rules.randomBetween(rng, Config.Lights.BlackoutMinGap, Config.Lights.BlackoutMaxGap)
			dark("blackout", Rules.randomBetween(rng, Config.Lights.BlackoutDurationMin, Config.Lights.BlackoutDurationMax), onStart, onEnd)
		elseif rng:NextNumber() < Config.Lights.BriefCutChance then
			dark("cut", Rules.randomBetween(rng, 0.4, 1.2), onStart, onEnd)
		else
			-- Piccolo sfarfallio su tre lampade a caso
			for _ = 1, 3 do
				task.spawn(flicker, fixtures[rng:NextInteger(1, #fixtures)])
			end
		end
	end
end

-- Esposto per Events (porta, monitor): stesso helper audio, stesso gruppo "Effects".
Lights.playAt = playAt

return Lights
