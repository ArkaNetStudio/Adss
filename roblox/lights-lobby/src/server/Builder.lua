--!strict
--[[
	Builder.lua — costruisce a runtime la struttura abbandonata della lobby LIGHTS.
	Layout (y = 0 e' il pavimento):
	- Sala centrale: X[-42,42] Z[-32,32], soffitto y=22. Logo sul muro nord (Z=-30), spawn a sud.
	- Corridoio ovest: X[-100,-42], Z[-6,6], soffitto y=10. Ha una finestra di vetro su un'alcova (sagoma),
	  una stanza di servizio con porta metallica a sud e un monitor sul muro nord.
	- Corridoio est: X[42,100], Z[-6,6], stesso soffitto.
	Restituisce un riepilogo (lampade, monitor, porta, postazioni delle sagome) usato dagli altri moduli.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LightsLobby"):WaitForChild("Config"))
local Geometry = require(script.Parent.Geometry)

local Builder = {}

-- Palette fredda e sporca, nessun colore acceso.
local CONCRETE = Color3.fromRGB(92, 94, 96)
local CONCRETE_DARK = Color3.fromRGB(62, 64, 66)
local METAL_DARK = Color3.fromRGB(40, 42, 46)
local RUST = Color3.fromRGB(76, 52, 40)
local WOOD = Color3.fromRGB(86, 64, 44)
local CABLE = Color3.fromRGB(16, 16, 18)
local YELLOW = Color3.fromRGB(214, 170, 32)
local BLACK = Color3.fromRGB(10, 10, 12)
local GLASS = Color3.fromRGB(120, 140, 150)

export type Lamp = { housing: Part, light: PointLight, trigger: Part? }
export type Spot = { name: string, position: Vector3, minDistance: number }
export type Layout = {
	folder: Folder,
	lamps: { Lamp },
	monitors: { Part },
	door: { part: Part, hinge: Vector3 },
	spots: { Spot },
	spawn: Vector3,
}

function Builder.build(rng: Random): Layout
	local folder = Instance.new("Folder")
	folder.Name = "LightsLobby_Map"
	folder.Parent = workspace

	-- Piccoli helper locali: ogni muro/pavimento passa da qui con una variazione di colore.
	local function block(a: Vector3, b: Vector3, color: Color3?, material: Enum.Material?): Part
		return Geometry.block(folder, a, b, material or Enum.Material.Concrete, Geometry.jitter(color or CONCRETE, rng))
	end

	local lamps: { Lamp } = {}
	local function lamp(pos: Vector3, range: number, trigger: boolean): Lamp
		local housing, light = Geometry.fixture(folder, pos, rng, range)
		local entry: Lamp = { housing = housing, light = light, trigger = nil }
		if trigger then
			-- Colonna invisibile sotto la lampada: quando un giocatore la attraversa, la lampada si spegne.
			local t = Instance.new("Part")
			t.Anchored = true
			t.CanCollide = false
			t.CanQuery = false
			t.Transparency = 1
			t.Size = Vector3.new(5, 10, 5)
			t.CFrame = CFrame.new(pos.X, 5, pos.Z)
			t.Parent = folder
			entry.trigger = t
		end
		table.insert(lamps, entry)
		return entry
	end

	-- ---------- Sala centrale ----------
	block(Vector3.new(-42, -2, -32), Vector3.new(42, 0, 32)) -- pavimento
	block(Vector3.new(-42, 22, -32), Vector3.new(42, 24, 32)) -- soffitto
	block(Vector3.new(-40, 0, -32), Vector3.new(40, 22, -30)) -- muro nord (logo)
	block(Vector3.new(-40, 0, 30), Vector3.new(40, 22, 32)) -- muro sud
	-- Muri est/ovest con apertura verso i corridoi (Z[-6,6], fino a y=10)
	block(Vector3.new(-42, 0, -30), Vector3.new(-40, 22, -6))
	block(Vector3.new(-42, 0, 6), Vector3.new(-40, 22, 30))
	block(Vector3.new(-42, 10, -6), Vector3.new(-40, 22, 6))
	block(Vector3.new(40, 0, -30), Vector3.new(42, 22, -6))
	block(Vector3.new(40, 0, 6), Vector3.new(42, 22, 30))
	block(Vector3.new(40, 10, -6), Vector3.new(42, 22, 6))
	-- Porta d'ingresso sud, solo decorativa (non si apre)
	block(Vector3.new(-3, 0, 29.4), Vector3.new(3, 9, 29.9), METAL_DARK, Enum.Material.Metal)

	-- Tubature e cavi sul soffitto della sala
	Geometry.pipeX(folder, Vector3.new(0, 20.5, -27.5), 80, 0.6, RUST)
	Geometry.pipeX(folder, Vector3.new(0, 20.5, 27.5), 80, 0.6, RUST)

	-- Lampade a soffitto della sala (la prima riga resta piu' buia di proposito)
	for _, x in { -24, 0, 24 } do
		for _, z in { -14, 14 } do
			lamp(Vector3.new(x, 21.5, z), 30, false)
		end
	end

	-- Ingombri: casse e fusti negli angoli
	block(Vector3.new(-36, 0, -26), Vector3.new(-31, 4, -21), WOOD, Enum.Material.WoodPlanks)
	block(Vector3.new(-30, 0, -26), Vector3.new(-27, 3, -23), WOOD, Enum.Material.WoodPlanks)
	for _, pos in { Vector3.new(33.5, 2, -24), Vector3.new(36, 2, -20) } do
		local barrel = Instance.new("Part")
		barrel.Anchored = true
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Size = Vector3.new(4, 3.2, 3.2)
		barrel.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
		barrel.Material = Enum.Material.CorrodedMetal
		barrel.Color = Geometry.jitter(RUST, rng)
		barrel.Parent = folder
	end

	-- Cartello delle notizie (tabellone nel mondo, legge Config.News)
	local news = Config.News[1]
	Geometry.sign(folder, Vector3.new(-39.7, 12, 18), Vector3.new(1, 0, 0), Vector2.new(12, 7),
		"AGGIORNAMENTI\n" .. news.Title .. "\n" .. news.Body, {
			background = Color3.fromRGB(14, 15, 17),
			foreground = Color3.fromRGB(236, 240, 244),
			font = Enum.Font.RobotoMono,
			textSize = 26,
		})

	-- Logo LIGHTS: pannello scuro sul muro nord, lettere bianche spaziate, con un alone.
	local panel = Geometry.block(folder, Vector3.new(-20, 7, -30), Vector3.new(20, 19, -29.2), Enum.Material.Metal, BLACK)
	panel.Name = "LogoPanel"
	panel.CFrame = Geometry.facing(Vector3.new(0, 13, -29.6), Vector3.new(0, 0, 1))
	panel.Size = Vector3.new(40, 12, 0.8)
	CollectionService:AddTag(panel, "LightsLogo")
	local logoGui = Instance.new("SurfaceGui")
	logoGui.Face = Enum.NormalId.Front
	logoGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	logoGui.PixelsPerStud = 50
	logoGui.LightInfluence = 0
	logoGui.Parent = panel
	local letters = { "L", "I", "G", "H", "T", "S" }
	for index, letter in letters do
		local label = Instance.new("TextLabel")
		label.Name = "LogoLetter" .. index
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.13, 0.42)
		label.Position = UDim2.fromScale(0.0225 + (index - 1) * 0.165, 0.29)
		label.Text = letter
		label.Font = Enum.Font.Michroma
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(240, 246, 252)
		label.TextStrokeColor3 = Color3.fromRGB(230, 240, 255) -- alone freddo
		label.TextStrokeTransparency = 0.55
		label.Parent = logoGui
	end
	-- Tubo al neon sotto il logo: e' una lampada come le altre (si spegne con le luci)
	local logoHousing, logoLight = Geometry.fixture(folder, Vector3.new(0, 6.6, -28.9), rng, 16)
	logoHousing.Size = Vector3.new(28, 0.4, 0.5)
	table.insert(lamps, { housing = logoHousing, light = logoLight, trigger = nil })

	-- Spawn dei giocatori, a sud, rivolti verso il logo
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, 18)
	spawn.Parent = folder

	-- ---------- Corridoio ovest ----------
	block(Vector3.new(-101, -2, -6), Vector3.new(-42, 0, 6)) -- pavimento
	block(Vector3.new(-100, 10, -6), Vector3.new(-42, 12, 6)) -- soffitto
	block(Vector3.new(-101, 0, -7), Vector3.new(-100, 10, 7)) -- fondo
	block(Vector3.new(-100, 0, -7), Vector3.new(-70, 10, -6)) -- muro nord (prima della finestra)
	block(Vector3.new(-62, 0, -7), Vector3.new(-42, 10, -6)) -- muro nord (dopo la finestra)
	block(Vector3.new(-70, 0, -7), Vector3.new(-62, 3, -6)) -- sotto la finestra
	block(Vector3.new(-70, 8, -7), Vector3.new(-62, 10, -6)) -- sopra la finestra
	block(Vector3.new(-100, 0, 6), Vector3.new(-80, 10, 7)) -- muro sud, parte ovest
	block(Vector3.new(-74, 0, 6), Vector3.new(-42, 10, 7)) -- muro sud, parte est
	block(Vector3.new(-80, 7, 6), Vector3.new(-74, 10, 7)) -- architrave della porta

	-- Finestra su un'alcova buia: qui compare la sagoma dietro il vetro
	local glass = Geometry.block(folder, Vector3.new(-70, 3, -6.6), Vector3.new(-62, 8, -6.4), Enum.Material.Glass, GLASS)
	glass.Transparency = 0.55
	glass.Reflectance = 0.1
	block(Vector3.new(-71, -2, -17), Vector3.new(-61, 0, -7)) -- pavimento alcova
	block(Vector3.new(-71, 10, -17), Vector3.new(-61, 11, -7)) -- soffitto alcova
	block(Vector3.new(-71, 0, -17), Vector3.new(-61, 10, -16)) -- fondo alcova
	block(Vector3.new(-71, 0, -16), Vector3.new(-70, 10, -7)) -- parete alcova ovest
	block(Vector3.new(-62, 0, -16), Vector3.new(-61, 10, -7)) -- parete alcova est

	-- Porta metallica della stanza di servizio (sud), con cerniera sul bordo ovest
	local hinge = Vector3.new(-80, 0, 6.5)
	local doorPanel = Instance.new("Part")
	doorPanel.Anchored = true
	doorPanel.Size = Vector3.new(6, 7, 0.4)
	doorPanel.Material = Enum.Material.Metal
	doorPanel.Color = Geometry.jitter(METAL_DARK, rng)
	doorPanel.CFrame = CFrame.new(hinge) * CFrame.Angles(0, -1.2, 0) * CFrame.new(3, 3.5, 0)
	doorPanel.Name = "LightsDoor"
	doorPanel.Parent = folder

	-- Stanza di servizio dietro la porta
	block(Vector3.new(-81, -2, 7), Vector3.new(-73, 0, 17)) -- pavimento
	block(Vector3.new(-81, 10, 7), Vector3.new(-73, 12, 17)) -- soffitto
	block(Vector3.new(-81, 0, 16), Vector3.new(-73, 10, 17)) -- fondo
	block(Vector3.new(-81, 0, 7), Vector3.new(-80, 10, 16)) -- parete ovest
	block(Vector3.new(-74, 0, 7), Vector3.new(-73, 10, 16)) -- parete est
	lamp(Vector3.new(-77, 9.4, 11.5), 12, false)

	-- Quadro elettrico con cartello di pericolo
	block(Vector3.new(-58, 0, 4.8), Vector3.new(-54, 5, 6), METAL_DARK, Enum.Material.Metal)
	Geometry.sign(folder, Vector3.new(-56, 3.5, 4.6), Vector3.new(0, 0, -1), Vector2.new(3.2, 1.8),
		"ALTA TENSIONE\nNON TOCCARE", {
			background = YELLOW,
			foreground = BLACK,
			font = Enum.Font.RobotoMono,
			textSize = 20,
		})

	-- Monitor sul muro nord: il suo schermo viene disturbato dal client
	local monitor = Geometry.block(folder, Vector3.new(-90.2, 3.3, -6.2), Vector3.new(-85.8, 6.7, -5), METAL_DARK)
	monitor.Name = "LightsMonitor"
	monitor.CFrame = Geometry.facing(Vector3.new(-88, 5, -5.6), Vector3.new(0, 0, 1))
	monitor.Size = Vector3.new(4.4, 3.4, 1.2)
	local screen = Instance.new("SurfaceGui")
	screen.Face = Enum.NormalId.Front
	screen.LightInfluence = 0
	screen.Parent = monitor
	local screenFrame = Instance.new("Frame")
	screenFrame.Name = "Screen"
	screenFrame.Size = UDim2.fromScale(1, 1)
	screenFrame.BackgroundColor3 = Color3.fromRGB(8, 9, 10)
	screenFrame.BorderSizePixel = 0
	screenFrame.Parent = screen
	CollectionService:AddTag(monitor, "LightsMonitor")

	-- Tubature e cavi della corridoio ovest
	Geometry.pipeX(folder, Vector3.new(-71, 8.6, -4.5), 58, 0.35, RUST)
	Geometry.pipeX(folder, Vector3.new(-71, 9.8, 2.5), 58, 0.12, CABLE)

	-- Pozza d'acqua sul pavimento (riflette la poca luce)
	local puddle = Geometry.block(folder, Vector3.new(-79, -0.05, -3), Vector3.new(-72, 0.02, 0), Enum.Material.Glass, Color3.fromRGB(28, 32, 36))
	puddle.Reflectance = 0.35
	puddle.Transparency = 0.5

	for _, x in { -50, -64, -78, -92 } do
		lamp(Vector3.new(x, 9.4, 0), 18, x == -50)
	end

	-- ---------- Corridoio est ----------
	block(Vector3.new(42, -2, -6), Vector3.new(101, 0, 6)) -- pavimento
	block(Vector3.new(42, 10, -6), Vector3.new(100, 12, 6)) -- soffitto
	block(Vector3.new(99, 0, -7), Vector3.new(100, 10, 7)) -- fondo
	block(Vector3.new(42, 0, -7), Vector3.new(100, 10, -6)) -- muro nord
	block(Vector3.new(42, 0, 6), Vector3.new(100, 10, 7)) -- muro sud

	Geometry.pipeX(folder, Vector3.new(71, 8.6, -4.5), 58, 0.35, RUST)
	Geometry.pipeX(folder, Vector3.new(71, 9.8, 2.5), 58, 0.12, CABLE)
	block(Vector3.new(64, 0, -6), Vector3.new(68, 5, -4.8), METAL_DARK, Enum.Material.Metal)
	Geometry.sign(folder, Vector3.new(66, 3.5, -4.6), Vector3.new(0, 0, 1), Vector2.new(3.2, 1.8),
		"ZONA CHIUSA\nPERSONALE AUTORIZZATO", {
			background = Color3.fromRGB(226, 224, 216),
			foreground = BLACK,
			font = Enum.Font.RobotoMono,
			textSize = 20,
		})

	for _, x in { 50, 64, 78, 92 } do
		lamp(Vector3.new(x, 9.4, 0), 18, x == 50)
	end

	-- ---------- Postazioni della sagoma e riepilogo ----------
	local spots: { Spot } = {
		{ name = "westEnd", position = Vector3.new(-94, 0, 0), minDistance = Config.Apparition.MinPlayerDistance },
		{ name = "eastEnd", position = Vector3.new(94, 0, 0), minDistance = Config.Apparition.MinPlayerDistance },
		{ name = "glass", position = Vector3.new(-66, 0, -12), minDistance = 14 }, -- dietro il vetro
	}

	local monitors: { Part } = {}
	for _, tagged in CollectionService:GetTagged("LightsMonitor") do
		if tagged:IsDescendantOf(folder) then
			table.insert(monitors, tagged :: Part)
		end
	end

	return {
		folder = folder,
		lamps = lamps,
		monitors = monitors,
		door = { part = doorPanel, hinge = hinge },
		spots = spots,
		spawn = spawn.Position,
	}
end

return Builder
