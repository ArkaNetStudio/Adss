--!strict
--[[
	Geometry.lua — mattoni per costruire la lobby: blocchi, tubi, cartelli, apparecchi luce.
	Tutto e' Part reali con Material e Color (nessun asset esterno necessario).
]]

local Lighting = game:GetService("Lighting")

local Geometry = {}

-- Piccola variazione di tono, cosi' le superfici non sembrano tutte uguali.
function Geometry.jitter(color: Color3, rng: Random): Color3
	local k = 0.92 + rng:NextNumber() * 0.12
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

-- Blocco ancorato tra due angoli a e b (coordinate di mondo).
function Geometry.block(parent: Instance, a: Vector3, b: Vector3, material: Enum.Material, color: Color3): Part
	local lo = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = hi - lo
	p.CFrame = CFrame.new((lo + hi) / 2)
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Tubo orizzontale lungo X (asse del cilindro) centrato in center.
function Geometry.pipeX(parent: Instance, center: Vector3, length: number, radius: number, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, radius * 2, radius * 2)
	p.CFrame = CFrame.new(center)
	p.Material = Enum.Material.Metal
	p.Color = color
	p.Parent = parent
	return p
end

-- Tubo orizzontale lungo Z.
function Geometry.pipeZ(parent: Instance, center: Vector3, length: number, radius: number, color: Color3): Part
	local p = Geometry.pipeX(parent, center, length, radius, color)
	p.CFrame = CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0)
	return p
end

-- Orientamento di una faccia: la faccia "Front" del Part guarda verso normal.
function Geometry.facing(pos: Vector3, normal: Vector3): CFrame
	return CFrame.lookAt(pos, pos + normal)
end

-- Cartello con testo su una faccia. Il Part e' sottile e ancorato alla parete.
function Geometry.sign(parent: Instance, pos: Vector3, normal: Vector3, size: Vector2, text: string,
	style: { background: Color3, foreground: Color3, font: Enum.Font, textSize: number })
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = Vector3.new(size.X, size.Y, 0.3)
	part.CFrame = Geometry.facing(pos, normal)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = style.background
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = style.foreground
	label.Font = style.font
	label.TextScaled = true
	label.Parent = gui

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = style.textSize
	constraint.Parent = label

	return part
end

-- Apparecchio luce a soffitto: un tubo "housing" (che si accende e spegne) + una PointLight.
-- Lights.lua decide quando accendere/spegnere; qui si crea solo la geometria.
function Geometry.fixture(parent: Instance, pos: Vector3, rng: Random, range: number): (Part, PointLight)
	local housing = Instance.new("Part")
	housing.Anchored = true
	housing.CanCollide = false
	housing.CanTouch = false
	housing.CanQuery = false
	housing.CastShadow = false
	housing.Size = Vector3.new(5, 0.4, 1.1)
	housing.CFrame = CFrame.new(pos)
	housing.Material = Enum.Material.Neon
	housing.Color = Color3.fromRGB(220, 240, 232)
	housing.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(214, 238, 228)
	light.Range = range
	light.Brightness = 1.1
	light.Shadows = false
	light.Parent = housing

	return housing, light
end

-- Chiude l'illuminazione per tutta la lobby: buio di base, nebbia leggera, bagliore e cromatura fredda.
function Geometry.setupLighting()
	-- Nota: Lighting.Technology non si cambia da script; impostalo in Studio (consigliato ShadowMap per mobile/console).
	Lighting.Ambient = Color3.fromRGB(12, 13, 16)
	Lighting.OutdoorAmbient = Color3.fromRGB(8, 9, 11)
	Lighting.Brightness = 0.4
	Lighting.FogColor = Color3.fromRGB(6, 7, 9)
	Lighting.FogStart = 60
	Lighting.FogEnd = 240

	local function ensure(className: string): Instance
		local existing = Lighting:FindFirstChildOfClass(className :: any)
		if existing then
			return existing
		end
		local created = Instance.new(className :: any)
		created.Parent = Lighting
		return created
	end

	local atmosphere = ensure("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(70, 78, 86)
	atmosphere.Haze = 1.6

	local bloom = ensure("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 18
	bloom.Threshold = 0.95

	local color = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Brightness = -0.04
	color.Contrast = 0.2
	color.Saturation = -0.85
	color.TintColor = Color3.fromRGB(205, 222, 240)
end

return Geometry
