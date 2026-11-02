--!strict
--[[
	LobbyBuilder.lua — costruisce a runtime la lobby di LIGHTS: un hangar di ricerca/contenimento dismesso.
	Coordinate (y = 0 pavimento):
	- Hangar: X[-60,60] Z[-45,45], soffitto y=34. Spawn a sud (Z=32), guarda verso l'insegna al centro.
	- Centro: basamento con grata e insegna LIGHTS sospesa alle capriate (y=17), leggibile da entrambi i lati.
	- Nord: ballatoio a y=12 con scala (lato ovest) e sala controllo vetrata (sagoma dietro il vetro).
	- Est: baia di partenza, 4 porte blindate con barra rossa e monitor della coda.
	- Ovest: area informazioni (bacheca, rapporto) e porta di servizio verso uno stanzino buio.
	build() crea la lobby (in Studio con bake(), o a runtime se manca); collect() la rilegge da tag e marcatori.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("LIGHTS"):WaitForChild("Config"))
local Geometry = require(script.Parent.Geometry)

local LobbyBuilder = {}

local CONCRETE = Color3.fromRGB(88, 90, 92)
local CONCRETE_DARK = Color3.fromRGB(58, 60, 62)
local STEEL = Color3.fromRGB(46, 48, 52)
local RUST = Color3.fromRGB(74, 52, 40)
local ACCENT_RED = Color3.fromRGB(92, 18, 20)
local WOOD = Color3.fromRGB(92, 66, 44)
local BLACK = Color3.fromRGB(10, 10, 12)
local GLASS = Color3.fromRGB(150, 165, 175)
local WINDOW = Color3.fromRGB(205, 214, 218)
local RED_LIGHT = Color3.fromRGB(255, 40, 40)

export type Lamp = { housing: Part, light: PointLight, trigger: Part? }
export type Spot = { name: string, position: Vector3, minDistance: number }
export type Layout = {
	folder: Folder,
	lamps: { Lamp },
	monitors: { Part },
	deployScreens: { TextLabel },
	door: { part: Part, hinge: CFrame }?,
	shadowPaths: { { from: Vector3, to: Vector3 } },
	spots: { Spot },
}

-- Seed fisso: la lobby e' sempre uguale, sia costruita in Studio sia a runtime.
LobbyBuilder.SEED = 20261102

-- Crea un valore figlio (riferimenti che i tag da soli non possono esprimere).
local function valueChild(className: string, name: string, value: any, parent: Instance)
	local v = Instance.new(className) :: any
	v.Name = name
	v.Value = value
	v.Parent = parent
end

function LobbyBuilder.build(rng: Random): Folder
	local folder = Instance.new("Folder")
	folder.Name = "LIGHTS_Lobby"
	folder.Parent = workspace

	local function block(a: Vector3, b: Vector3, color: Color3?, material: Enum.Material?): Part
		return Geometry.block(folder, a, b, material or Enum.Material.Concrete, Geometry.jitter(color or CONCRETE, rng))
	end
	-- Parte decorativa: niente collisioni ne' query, per non disturbare movimento e raycast.
	local function prop(a: Vector3, b: Vector3, color: Color3, material: Enum.Material): Part
		local p = block(a, b, color, material)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		return p
	end

	local function addLamp(housing: Part, light: PointLight, trigger: Part?)
		CollectionService:AddTag(housing, "LightsLamp")
		if trigger then
			valueChild("ObjectValue", "Trigger", trigger, housing)
		end
	end
	-- Lampada a campana appesa a un cavo (come nei riferimenti). Il bulbo e' la parte che si accende.
	local function pendant(x: number, z: number, y: number, trigger: boolean)
		prop(Vector3.new(x - 0.06, y + 1.2, z - 0.06), Vector3.new(x + 0.06, 34, z + 0.06), BLACK, Enum.Material.SmoothPlastic)
		local shade = Instance.new("Part")
		shade.Anchored = true
		shade.CanCollide = false
		shade.CanQuery = false
		shade.Shape = Enum.PartType.Cylinder
		shade.Size = Vector3.new(0.9, 2.6, 2.6)
		shade.CFrame = CFrame.new(x, y + 0.7, z) * CFrame.Angles(0, 0, math.pi / 2)
		shade.Material = Enum.Material.Metal
		shade.Color = STEEL
		shade.Parent = folder
		local bulb, light = Geometry.fixture(folder, Vector3.new(x, y, z), rng, 34)
		bulb.Shape = Enum.PartType.Ball
		bulb.Size = Vector3.new(0.9, 0.9, 0.9)
		local column: Part? = nil
		if trigger then
			local t = Instance.new("Part")
			t.Anchored = true
			t.CanCollide = false
			t.CanQuery = false
			t.Transparency = 1
			t.Size = Vector3.new(6, 10, 6)
			t.CFrame = CFrame.new(x, 5, z)
			t.Parent = folder
			column = t
		end
		addLamp(bulb, light, column)
	end
	-- Plafoniera a tubo (sotto il ballatoio, stanze di servizio).
	local function tube(pos: Vector3, range: number)
		local housing, light = Geometry.fixture(folder, pos, rng, range)
		addLamp(housing, light, nil)
	end

	-- ================= Involucro =================
	block(Vector3.new(-62, -2, -47), Vector3.new(62, 0, 47)) -- pavimento
	block(Vector3.new(-62, 34, -47), Vector3.new(62, 36, 47), CONCRETE_DARK) -- soffitto
	block(Vector3.new(-62, 0, -47), Vector3.new(62, 34, -45)) -- muro nord
	block(Vector3.new(-62, 0, 45), Vector3.new(62, 34, 47)) -- muro sud
	block(Vector3.new(60, 0, -45), Vector3.new(62, 34, 45)) -- muro est (baia di partenza)
	-- Muro ovest con l'apertura della porta di servizio (Z[14,20], alta 7)
	block(Vector3.new(-62, 0, -45), Vector3.new(-60, 34, 14))
	block(Vector3.new(-62, 0, 20), Vector3.new(-60, 34, 45))
	block(Vector3.new(-62, 7, 14), Vector3.new(-60, 34, 20))
	-- Zoccolo scuro sporco lungo i muri: sporcizia e umidita' alla base
	for _, wall in {
		{ Vector3.new(-60, 0, -45), Vector3.new(60, 2.5, -44.8) },
		{ Vector3.new(-60, 0, 44.8), Vector3.new(60, 2.5, 45) },
		{ Vector3.new(59.8, 0, -45), Vector3.new(60, 2.5, 45) },
	} do
		prop(wall[1], wall[2], CONCRETE_DARK, Enum.Material.Concrete)
	end

	-- Finestre a nastro alte (est e ovest): luce fredda e lattiginosa, telaio scuro
	for _, side in { -1, 1 } do
		local x = side * 59.9
		for z = -40, 32, 12 do
			local pane = prop(Vector3.new(x - 0.1, 24, z), Vector3.new(x + 0.1, 30, z + 9), WINDOW, Enum.Material.Neon)
			pane.Transparency = 0.15
			local surface = Instance.new("SurfaceLight")
			surface.Face = if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left
			surface.Brightness = 0.6
			surface.Range = 40
			surface.Angle = 70
			surface.Color = Color3.fromRGB(200, 214, 225)
			surface.Shadows = true
			surface.Parent = pane
			for mz = z, z + 9, 1.5 do
				prop(Vector3.new(x - 0.25, 24, mz - 0.08), Vector3.new(x + 0.25, 30, mz + 0.08), BLACK, Enum.Material.Metal)
			end
			prop(Vector3.new(x - 0.25, 26.9, z), Vector3.new(x + 0.25, 27.1, z + 9), BLACK, Enum.Material.Metal)
		end
	end

	-- Capriate del tetto
	for _, z in { -30, -10, 10, 30 } do
		prop(Vector3.new(-60, 30.6, z - 0.4), Vector3.new(60, 31.4, z + 0.4), STEEL, Enum.Material.Metal)
		prop(Vector3.new(-60, 33.2, z - 0.3), Vector3.new(60, 33.8, z + 0.3), STEEL, Enum.Material.Metal)
		for x = -55, 55, 10 do
			prop(Vector3.new(x - 0.2, 31.4, z - 0.2), Vector3.new(x + 0.2, 33.2, z + 0.2), STEEL, Enum.Material.Metal)
		end
	end

	-- Pilastri con fascia rossa (accento dei riferimenti)
	for _, x in { -30, 30 } do
		for _, z in { -30, -10, 10, 30 } do
			block(Vector3.new(x - 2, 0, z - 2), Vector3.new(x + 2, 34, z + 2))
			prop(Vector3.new(x - 2.05, 0, z + 0.6), Vector3.new(x + 2.05, 9, z + 1.4), ACCENT_RED, Enum.Material.Concrete)
		end
	end

	-- Tubature lungo i muri e una calata verticale
	Geometry.pipeZ(folder, Vector3.new(-58.8, 21, 0), 90, 0.7, RUST)
	Geometry.pipeZ(folder, Vector3.new(-58.8, 19.4, 0), 90, 0.35, STEEL)
	Geometry.pipeZ(folder, Vector3.new(58.8, 21, 0), 90, 0.7, RUST)
	Geometry.pipeX(folder, Vector3.new(0, 22, 44), 120, 0.5, STEEL)
	local drop = Geometry.pipeX(folder, Vector3.new(-58.8, 10.5, -20), 21, 0.35, STEEL)
	drop.CFrame = CFrame.new(-58.8, 10.5, -20) * CFrame.Angles(0, 0, math.pi / 2)

	-- Macchie e pozzanghere sul pavimento (riflessi)
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-55, 55), rng:NextNumber(-40, 40)
		local w, d = rng:NextNumber(3, 9), rng:NextNumber(3, 8)
		local stain = prop(Vector3.new(x, 0, z), Vector3.new(x + w, 0.03, z + d), Color3.fromRGB(30, 31, 30), Enum.Material.Concrete)
		stain.Transparency = 0.55
	end
	for _, spec in { { -18, 6, 7, 4 }, { 14, -14, 5, 3 }, { 38, 22, 4, 6 } } do
		local puddle = prop(Vector3.new(spec[1], 0, spec[2]), Vector3.new(spec[1] + spec[3], 0.04, spec[2] + spec[4]), Color3.fromRGB(26, 30, 34), Enum.Material.Glass)
		puddle.Transparency = 0.45
		puddle.Reflectance = 0.35
	end

	-- ================= Centro: basamento e insegna LIGHTS =================
	local plinth = Instance.new("Part")
	plinth.Anchored = true
	plinth.Shape = Enum.PartType.Cylinder
	plinth.Size = Vector3.new(0.6, 18, 18)
	plinth.CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	plinth.Material = Enum.Material.Concrete
	plinth.Color = CONCRETE_DARK
	plinth.Parent = folder
	local grate = plinth:Clone()
	grate.Size = Vector3.new(0.62, 10, 10)
	grate.Material = Enum.Material.DiamondPlate
	grate.Color = STEEL
	grate.Parent = folder

	local sign = Instance.new("Part")
	sign.Name = "LogoPanel"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Size = Vector3.new(30, 7, 0.6)
	sign.CFrame = Geometry.facing(Vector3.new(0, 17, 0), Vector3.new(0, 0, 1))
	sign.Material = Enum.Material.Metal
	sign.Color = BLACK
	sign.Parent = folder
	CollectionService:AddTag(sign, "LightsLogo")
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui.Parent = sign
		for index, letter in { "L", "I", "G", "H", "T", "S" } do
			local label = Instance.new("TextLabel")
			label.Name = "LogoLetter" .. index
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(0.13, 0.62)
			label.Position = UDim2.fromScale(0.0225 + (index - 1) * 0.165, 0.19)
			label.Text = letter
			label.Font = Enum.Font.Michroma
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(240, 246, 252)
			label.TextStrokeColor3 = Color3.fromRGB(230, 240, 255)
			label.TextStrokeTransparency = 0.55
			label.Parent = gui
		end
	end
	for _, x in { -13, 13 } do -- cavi di sospensione
		prop(Vector3.new(x - 0.05, 20.5, -0.05), Vector3.new(x + 0.05, 30.6, 0.05), BLACK, Enum.Material.SmoothPlastic)
	end
	local signTube, signLight = Geometry.fixture(folder, Vector3.new(0, 13.2, 0), rng, 20)
	signTube.Size = Vector3.new(26, 0.3, 0.3)
	addLamp(signTube, signLight, nil)

	-- Lampade a campana sulla sala (la fila centrale ha il trigger "spegni passando sotto")
	for _, x in { -45, -15, 15, 45 } do
		for _, z in { -22, 2, 26 } do
			pendant(x, z, 22, z == 2 and (x == -15 or x == 15))
		end
	end

	-- ================= Spawn e panche =================
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 32)
	spawn.Parent = folder
	local function bench(x: number, z: number)
		block(Vector3.new(x - 4, 1.6, z - 0.9), Vector3.new(x + 4, 1.9, z + 0.9), WOOD, Enum.Material.WoodPlanks)
		for _, lx in { x - 3.6, x + 3.6 } do
			block(Vector3.new(lx - 0.15, 0, z - 0.8), Vector3.new(lx + 0.15, 1.6, z + 0.8), STEEL, Enum.Material.Metal)
		end
	end
	bench(-16, 22)
	bench(16, 22)
	bench(-44, 12)
	bench(44, -2)

	-- ================= Nord: ballatoio, scala, sala controllo =================
	block(Vector3.new(-60, 11, -45), Vector3.new(60, 12, -33), STEEL, Enum.Material.DiamondPlate)
	for x = -58, 58, 12 do -- travi di sostegno
		block(Vector3.new(x - 0.5, 0, -33.6), Vector3.new(x + 0.5, 11, -32.6), STEEL, Enum.Material.Metal)
	end
	for x = -60, 60, 4 do -- ringhiera, con il varco dell'arrivo della scala (X[-54,-48])
		if x < -54 or x > -48 then
			prop(Vector3.new(x - 0.08, 12, -33.1), Vector3.new(x + 0.08, 15.4, -32.9), BLACK, Enum.Material.Metal)
		end
	end
	block(Vector3.new(-60, 15.2, -33.15), Vector3.new(-54, 15.5, -32.85), BLACK, Enum.Material.Metal)
	block(Vector3.new(-48, 15.2, -33.15), Vector3.new(60, 15.5, -32.85), BLACK, Enum.Material.Metal)
	for step = 1, 12 do -- scala dal pavimento al ballatoio (lato ovest)
		block(Vector3.new(-54, 0, -21 - step), Vector3.new(-48, step, -20 - step), STEEL, Enum.Material.DiamondPlate)
	end
	for x = -40, 40, 16 do
		tube(Vector3.new(x, 10.4, -39), 18) -- plafoniere sotto il ballatoio
	end

	-- Sala controllo vetrata sul ballatoio: X[10,30], Z[-45,-36], y 12..20
	block(Vector3.new(9, 12, -45), Vector3.new(10, 21, -36))
	block(Vector3.new(30, 12, -45), Vector3.new(31, 21, -36))
	block(Vector3.new(9, 20, -45), Vector3.new(31, 21, -36), CONCRETE_DARK)
	block(Vector3.new(10, 12, -36.5), Vector3.new(30, 14.5, -36))
	block(Vector3.new(10, 18.5, -36.5), Vector3.new(30, 20, -36))
	block(Vector3.new(10, 12, -36.5), Vector3.new(13, 20, -36)) -- montante ovest: la sala e' chiusa, si vede solo attraverso il vetro
	local glass = Geometry.block(folder, Vector3.new(13, 14.5, -36.4), Vector3.new(30, 18.5, -36.1), Enum.Material.Glass, GLASS)
	glass.Transparency = 0.5
	glass.Reflectance = 0.12
	block(Vector3.new(15, 12, -44), Vector3.new(27, 14.6, -42), STEEL, Enum.Material.Metal) -- console
	tube(Vector3.new(20, 19.4, -41), 12)

	-- Scaffalature e casse sotto il ballatoio
	for x = -36, 36, 12 do
		for shelf = 0, 3 do
			prop(Vector3.new(x - 4, 0.2 + shelf * 2.6, -44.6), Vector3.new(x + 4, 0.4 + shelf * 2.6, -42), STEEL, Enum.Material.Metal)
		end
		for _, px in { x - 4, x + 4 } do
			block(Vector3.new(px - 0.15, 0, -44.6), Vector3.new(px + 0.15, 8.2, -42), STEEL, Enum.Material.Metal)
		end
		if rng:NextNumber() < 0.7 then
			block(Vector3.new(x - 3, 0.4, -44.3), Vector3.new(x - 0.5, 2.6, -42.3), WOOD, Enum.Material.WoodPlanks)
		end
	end

	-- ================= Est: baia di partenza =================
	for index, z in { -24, -8, 8, 24 } do
		block(Vector3.new(57, 0, z - 5), Vector3.new(60, 11, z - 4)) -- spallette
		block(Vector3.new(57, 0, z + 4), Vector3.new(60, 11, z + 5))
		block(Vector3.new(57, 10, z - 4), Vector3.new(60, 11, z + 4))
		block(Vector3.new(59.4, 0, z - 4), Vector3.new(59.8, 10, z + 4), STEEL, Enum.Material.Metal) -- porta blindata
		for y = 1.5, 9, 2.5 do
			prop(Vector3.new(59.2, y, z - 3.6), Vector3.new(59.4, y + 0.2, z + 3.6), BLACK, Enum.Material.Metal)
		end
		-- Barra rossa sopra la porta: e' una lampada (si spegne con i blackout)
		local bar, barLight = Geometry.fixture(folder, Vector3.new(56.8, 11.6, z), rng, 14)
		bar.Size = Vector3.new(0.4, 0.5, 6)
		bar.Color = RED_LIGHT
		barLight.Color = RED_LIGHT
		addLamp(bar, barLight, nil)
		-- Monitor della coda
		local monitor = Instance.new("Part")
		monitor.Name = "LightsMonitor"
		monitor.Anchored = true
		monitor.Size = Vector3.new(4.6, 2.8, 0.8)
		monitor.CFrame = Geometry.facing(Vector3.new(59.5, 13.8, z), Vector3.new(-1, 0, 0)) -- appoggiato al muro
		monitor.Material = Enum.Material.Metal
		monitor.Color = BLACK
		monitor.Parent = folder
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Parent = monitor
		local screen = Instance.new("Frame")
		screen.Name = "Screen"
		screen.Size = UDim2.fromScale(1, 1)
		screen.BackgroundColor3 = Color3.fromRGB(10, 12, 12)
		screen.BorderSizePixel = 0
		screen.Parent = gui
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(0.9, 0.86)
		text.Position = UDim2.fromScale(0.05, 0.07)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.RobotoMono
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(205, 220, 210)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = "BAIA " .. index
		text.Parent = screen
		CollectionService:AddTag(monitor, "LightsMonitor")
		CollectionService:AddTag(text, "LightsDeployScreen")
		text:SetAttribute("Bay", index)
	end
	Geometry.sign(folder, Vector3.new(59.6, 18, 0), Vector3.new(-1, 0, 0), Vector2.new(14, 2.4), "BAIA DI PARTENZA", {
		background = BLACK,
		foreground = Color3.fromRGB(220, 224, 228),
		font = Enum.Font.RobotoMono,
		textSize = 40,
	})

	-- ================= Ovest: area informazioni e porta di servizio =================
	local news = Config.News[1]
	Geometry.sign(folder, Vector3.new(-59.7, 7, -6), Vector3.new(1, 0, 0), Vector2.new(12, 6),
		"AGGIORNAMENTI\n" .. news.Title .. "\n" .. news.Body, {
			background = Color3.fromRGB(16, 17, 19),
			foreground = Color3.fromRGB(232, 236, 240),
			font = Enum.Font.RobotoMono,
			textSize = 26,
		})
	Geometry.sign(folder, Vector3.new(-59.7, 6, 4), Vector3.new(1, 0, 0), Vector2.new(4, 5.2),
		"RAPPORTO 07-C\n\nIl soggetto non tollera la luce.\nAbbiamo spento il settore C per contenerlo.\n\nNessuno ha riacceso il settore C.", {
			background = Color3.fromRGB(214, 208, 192),
			foreground = Color3.fromRGB(30, 28, 26),
			font = Enum.Font.SpecialElite,
			textSize = 18,
		})
	block(Vector3.new(-58, 0, -14), Vector3.new(-52, 3, -11), STEEL, Enum.Material.Metal) -- scrivania
	Geometry.sign(folder, Vector3.new(-59.7, 9.5, 17), Vector3.new(1, 0, 0), Vector2.new(5, 1.3), "SERVIZIO", {
		background = Color3.fromRGB(205, 200, 190),
		foreground = BLACK,
		font = Enum.Font.RobotoMono,
		textSize = 30,
	})

	-- Porta di servizio: cerniera a Z=20, si apre verso la sala. Ruotata di 90° per stare nel muro ovest.
	local hinge = CFrame.new(-61, 0, 20) * CFrame.Angles(0, math.pi / 2, 0)
	local doorPanel = Instance.new("Part")
	doorPanel.Name = "LightsDoor"
	doorPanel.Anchored = true
	doorPanel.Size = Vector3.new(6, 7, 0.4)
	doorPanel.Material = Enum.Material.Metal
	doorPanel.Color = Geometry.jitter(STEEL, rng)
	doorPanel.CFrame = hinge * CFrame.Angles(0, -1.2, 0) * CFrame.new(3, 3.5, 0)
	doorPanel.Parent = folder
	CollectionService:AddTag(doorPanel, "LightsDoor")
	valueChild("CFrameValue", "Hinge", hinge, doorPanel)

	-- Stanzino buio dietro la porta: X[-72,-62] Z[10,24]
	block(Vector3.new(-73, -2, 9), Vector3.new(-62, 0, 25))
	block(Vector3.new(-73, 9, 9), Vector3.new(-62, 10, 25), CONCRETE_DARK)
	block(Vector3.new(-73, 0, 9), Vector3.new(-72, 9, 25))
	block(Vector3.new(-72, 0, 9), Vector3.new(-62, 9, 10))
	block(Vector3.new(-72, 0, 24), Vector3.new(-62, 9, 25))
	tube(Vector3.new(-67, 8.4, 17), 10)

	-- ================= Marcatori (invisibili, spostabili in Studio) =================
	-- Percorsi delle ombre e postazioni delle sagome sono Part invisibili: si possono spostare a mano.
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = folder
	local function marker(name: string, position: Vector3, size: Vector3): Part
		local m = Instance.new("Part")
		m.Name = name
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.CanTouch = false
		m.Transparency = 1
		m.Size = size
		m.CFrame = CFrame.new(position)
		m.Parent = markers
		return m
	end
	for _, path in {
		{ Vector3.new(-56, 3.2, -38), Vector3.new(56, 3.2, -38) }, -- sotto il ballatoio
		{ Vector3.new(54, 3.2, -30), Vector3.new(54, 3.2, 30) }, -- davanti alle porte della baia
	} do
		local m = marker("ShadowPath", (path[1] + path[2]) / 2, Vector3.new(1, 1, 1))
		m:SetAttribute("From", path[1])
		m:SetAttribute("To", path[2])
	end
	for _, spot in {
		{ "underMezzanine", Vector3.new(-56, 0, -42), Config.Apparition.MinPlayerDistance },
		{ "serviceRoom", Vector3.new(-69, 0, 13), 30 },
		{ "glass", Vector3.new(22, 12, -40), 16 }, -- dietro il vetro della sala controllo
	} do
		-- Il marcatore e' grande quanto la sagoma: la sua base e' il punto dove compare.
		local m = marker("ApparitionSpot", spot[2] + Vector3.new(0, 4, 0), Vector3.new(2, 8, 1))
		m:SetAttribute("SpotName", spot[1])
		m:SetAttribute("MinDistance", spot[3])
	end

	return folder
end

-- Rilegge il layout da una lobby esistente (costruita ora o salvata nel place e magari modificata a mano).
-- Tutto passa da tag e marcatori: spostare o duplicare lampade e marcatori in Studio funziona senza toccare il codice.
function LobbyBuilder.collect(folder: Instance): Layout
	local lamps: { Lamp } = {}
	local monitors: { Part } = {}
	local screens: { TextLabel } = {}
	local door: { part: Part, hinge: CFrame }? = nil
	local shadowPaths = {}
	local spots: { Spot } = {}
	for _, item in folder:GetDescendants() do
		if item:IsA("Part") and CollectionService:HasTag(item, "LightsLamp") then
			local light = item:FindFirstChildOfClass("PointLight")
			local trigger = item:FindFirstChild("Trigger")
			if light then
				table.insert(lamps, {
					housing = item,
					light = light,
					trigger = if trigger and trigger:IsA("ObjectValue") and trigger.Value and trigger.Value:IsA("Part")
						then trigger.Value
						else nil,
				})
			end
		elseif item:IsA("Part") and CollectionService:HasTag(item, "LightsMonitor") then
			table.insert(monitors, item)
		elseif item:IsA("TextLabel") and CollectionService:HasTag(item, "LightsDeployScreen") then
			table.insert(screens, item)
		elseif item:IsA("Part") and CollectionService:HasTag(item, "LightsDoor") then
			local hinge = item:FindFirstChild("Hinge")
			if hinge and hinge:IsA("CFrameValue") then
				door = { part = item, hinge = hinge.Value }
			end
		elseif item:IsA("BasePart") and item.Name == "ShadowPath" then
			local from, to = item:GetAttribute("From"), item:GetAttribute("To")
			if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
				table.insert(shadowPaths, { from = from, to = to })
			end
		elseif item:IsA("BasePart") and item.Name == "ApparitionSpot" then
			table.insert(spots, {
				name = tostring(item:GetAttribute("SpotName") or "spot"),
				position = item.Position - Vector3.new(0, item.Size.Y / 2, 0),
				minDistance = tonumber(item:GetAttribute("MinDistance")) or Config.Apparition.MinPlayerDistance,
			})
		end
	end
	table.sort(screens, function(a, b)
		return (a:GetAttribute("Bay") or 0) < (b:GetAttribute("Bay") or 0)
	end)
	if #lamps == 0 then
		warn("[LIGHTS] Nessuna lampada con tag LightsLamp in " .. folder:GetFullName() .. ": luci ed eventi disattivati")
	end
	return {
		folder = folder :: Folder,
		lamps = lamps,
		monitors = monitors,
		deployScreens = screens,
		door = door,
		shadowPaths = shadowPaths,
		spots = spots,
	}
end

-- Da eseguire UNA volta dalla Command Bar di Studio, in modalita' Edit:
--   require(game.ServerScriptService.LIGHTS.LobbyBuilder).bake()
-- Costruisce la lobby nel Workspace e imposta l'illuminazione; poi si salva il place (Ctrl+S).
-- Non sovrascrive mai una lobby esistente, per non cancellare modifiche fatte a mano.
function LobbyBuilder.bake(): Folder
	if workspace:FindFirstChild("LIGHTS_Lobby") then
		error("[LIGHTS] Workspace.LIGHTS_Lobby esiste gia'. Eliminalo a mano se vuoi ricostruirlo (perderai le modifiche fatte su di esso).")
	end
	Geometry.setupLighting()
	local folder = LobbyBuilder.build(Random.new(LobbyBuilder.SEED))
	print("[LIGHTS] Lobby costruita in Workspace.LIGHTS_Lobby. Salva il place.")
	return folder
end

return LobbyBuilder
