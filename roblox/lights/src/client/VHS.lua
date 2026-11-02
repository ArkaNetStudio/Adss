--!strict
--[[
	VHS.lua — filtro videocamera VHS del client.
	- Scanline, vignettatura, banda di tracking, strappi orizzontali, colore spento e lieve sfocatura.
	- Overlay da videocamera: "REC" con pallino rosso lampeggiante, angoli del mirino, timecode e data.
	- Grana: solo se Config.VHS.NoiseImage contiene un ID immagine (Roblox non genera rumore da codice).
	Intensita' 0..1: base bassa (leggibilita'), sale con gli eventi (blackout, disturbi) e in futuro con la sanity.
	Sta sotto le interfacce (DisplayOrder basso): menu e testi restano sempre leggibili.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("LIGHTS")
local Config = require(shared:WaitForChild("Config"))
local Net = require(shared:WaitForChild("Net"))
local Settings = require(script.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local VHS = {}

local SCANLINES = 160
local gui: ScreenGui
local scanlines: { Frame } = {}
local band: Frame
local tear: Frame
local grain: ImageLabel?
local recDot: Frame
local timecode: TextLabel
local color: ColorCorrectionEffect
local blur: BlurEffect
local base = Config.VHS.BaseIntensity
local boost = 0 -- picco temporaneo che decade
local external = 0 -- contributo esterno (es. sanity)
local startedAt = os.clock()

local function intensity(): number
	return math.clamp(base + boost + external, 0, 1)
end

local function enabled(): boolean
	return Settings.values.VHS ~= false
end

local function reduced(): boolean
	return Settings.values.ReduceFlicker == true
end

-- Angolo del mirino a forma di L.
local function bracket(anchor: Vector2, position: UDim2)
	local holder = UIKit.create("Frame", {
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
	}, gui)
	local horizontal = UIKit.create("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.fromScale(0, anchor.Y),
		AnchorPoint = Vector2.new(0, anchor.Y),
		BackgroundColor3 = UIKit.Colors.Text,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, holder)
	local vertical = horizontal:Clone()
	vertical.Size = UDim2.new(0, 3, 1, 0)
	vertical.Position = UDim2.fromScale(anchor.X, 0)
	vertical.AnchorPoint = Vector2.new(anchor.X, 0)
	vertical.Parent = holder
end

local function build()
	gui = UIKit.create("ScreenGui", {
		Name = "LightsVHS",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 1,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))

	-- Scanline: linee orizzontali sottili, create una volta sola.
	for i = 0, SCANLINES - 1 do
		table.insert(scanlines, UIKit.create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, i / SCANLINES),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
		}, gui))
	end

	-- Vignettatura: quattro bordi sfumati verso il centro.
	for _, side in {
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
		{ UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.18, 1), UDim2.fromScale(0.82, 0), 180 },
	} do
		local edge = UIKit.create("Frame", {
			Size = side[1],
			Position = side[2],
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
		}, gui)
		UIKit.create("UIGradient", {
			Rotation = side[3],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, edge)
	end

	-- Banda di tracking: fascia chiara e sfocata che scorre verso il basso.
	band = UIKit.create("Frame", {
		Size = UDim2.fromScale(1, 0.07),
		Position = UDim2.fromScale(0, -0.1),
		BackgroundColor3 = Color3.fromRGB(220, 225, 230),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, gui)
	UIKit.create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, band)

	-- Strappo orizzontale: striscia scura spostata di lato per un attimo.
	tear = UIKit.create("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(30, 30, 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, gui)

	if Config.VHS.NoiseImage ~= "" then
		grain = UIKit.create("ImageLabel", {
			Image = Config.VHS.NoiseImage,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(256, 256),
			Size = UDim2.new(1, 256, 1, 256),
			BackgroundTransparency = 1,
			ImageTransparency = 0.9,
		}, gui)
	end

	-- Overlay videocamera
	bracket(Vector2.new(0, 0), UDim2.new(0, 28, 0, 28))
	bracket(Vector2.new(1, 0), UDim2.new(1, -28, 0, 28))
	bracket(Vector2.new(0, 1), UDim2.new(0, 28, 1, -28))
	bracket(Vector2.new(1, 1), UDim2.new(1, -28, 1, -28))

	recDot = UIKit.create("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(0, 92, 0, 50),
		BackgroundColor3 = Color3.fromRGB(225, 30, 30),
		BorderSizePixel = 0,
	}, gui)
	UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }, recDot)
	UIKit.text(gui, { Text = "REC", Position = UDim2.new(0, 116, 0, 44), Size = UDim2.fromOffset(70, 28) }, 26)
	timecode = UIKit.text(gui, {
		Text = "",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 92, 1, -44),
		Size = UDim2.fromOffset(260, 26),
	}, 22)
	UIKit.text(gui, {
		Text = string.upper(DateTime.now():FormatLocalTime("MMM. DD YYYY", "en-us")),
		AnchorPoint = Vector2.new(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -92, 1, -44),
		Size = UDim2.fromOffset(220, 26),
	}, 22)

	-- Colore e sfocatura locali (non toccano gli altri giocatori).
	color = UIKit.create("ColorCorrectionEffect", { Name = "VHSColor" }, Lighting)
	blur = UIKit.create("BlurEffect", { Name = "VHSBlur", Size = 0 }, Lighting)
end

-- Banda di tracking che attraversa lo schermo.
local function trackingSweep()
	band.Position = UDim2.fromScale(0, -0.1)
	band.BackgroundTransparency = 0.82 - intensity() * 0.25
	UIKit.tween(band, 0.9 + (1 - intensity()), { Position = UDim2.fromScale(0, 1.05) })
end

-- Strappo: per pochi fotogrammi una striscia si sposta lateralmente.
local function tearGlitch()
	tear.Position = UDim2.new(math.random() * 0.06 - 0.03, 0, math.random(), 0)
	tear.BackgroundTransparency = 0.4
	task.wait(0.06)
	tear.BackgroundTransparency = 1
end

local lastLevel = -1
local lastOn: boolean? = nil
local function apply()
	local on = enabled()
	local level = if on then intensity() else 0
	if on == lastOn and math.abs(level - lastLevel) < 0.01 then
		return -- niente da aggiornare: evita 160 scritture per fotogramma
	end
	lastOn, lastLevel = on, level
	gui.Enabled = on
	for _, line in scanlines do
		line.BackgroundTransparency = 0.93 - level * 0.12
	end
	color.Enabled = on
	color.Saturation = -0.12 - level * 0.35
	color.Contrast = 0.04 + level * 0.1
	color.TintColor = Color3.fromRGB(255, 248, 236)
	blur.Enabled = on
	blur.Size = level * 3 -- massimo 3: l'immagine resta leggibile
end

-- Contributo esterno all'intensita' (0..1), per la sanity delle prossime milestone.
function VHS.setExternal(value: number)
	external = math.clamp(value, 0, 0.6)
end

-- Picco temporaneo: sale subito e torna alla base in qualche secondo.
function VHS.pulse(amount: number)
	boost = math.max(boost, amount)
end

function VHS.start()
	build()
	Settings.onChanged(apply)
	apply()

	Net.event("LightsEvent").OnClientEvent:Connect(function(kind: string)
		if kind == "blackout" then
			VHS.pulse(0.6)
		elseif kind == "cut" or kind == "static" then
			VHS.pulse(0.35)
		elseif kind == "restore" then
			VHS.pulse(0.25)
		end
	end)

	-- Eventi VHS sporadici: piu' frequenti con intensita' alta. Disattivati con "Riduci lampeggi".
	task.spawn(function()
		while true do
			task.wait(4 + (1 - intensity()) * 10 * math.random())
			if enabled() and not reduced() then
				if math.random() < 0.6 then
					trackingSweep()
				else
					tearGlitch()
				end
			end
		end
	end)

	local lastBlink = 0
	RunService.RenderStepped:Connect(function(dt: number)
		boost = math.max(0, boost - dt * 0.25)
		if not enabled() then
			return
		end
		apply()
		local t = os.clock()
		if t - lastBlink >= 0.5 then -- pallino REC: 1 secondo acceso/spento
			lastBlink = t
			recDot.Visible = not recDot.Visible
		end
		local elapsed = math.floor(t - startedAt)
		timecode.Text = string.format("SP  %02d:%02d:%02d", elapsed // 3600, (elapsed // 60) % 60, elapsed % 60)
		if grain then
			grain.Position = UDim2.fromOffset(-math.random(0, 255), -math.random(0, 255))
			grain.ImageTransparency = 0.92 - intensity() * 0.1
		end
	end)
end

return VHS
