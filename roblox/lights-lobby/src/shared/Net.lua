--!strict
--[[
	Net.lua — crea (server) o attende (client) i RemoteEvent/RemoteFunction della lobby.
	Tutti stanno in ReplicatedStorage/LightsLobby/Remotes, cosi' nessuno va creato a mano in Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local root: Instance
if RunService:IsServer() then
	root = ReplicatedStorage:FindFirstChild("LightsLobby") or Instance.new("Folder")
	root.Name = "LightsLobby"
	root.Parent = ReplicatedStorage
else
	root = ReplicatedStorage:WaitForChild("LightsLobby") -- il client attende: non deve creare una copia locale
end

local folder = root:FindFirstChild("Remotes")
if not folder then
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = root
	else
		folder = root:WaitForChild("Remotes") :: Folder -- il client attende la cartella creata dal server
	end
end

-- Restituisce il remote con quel nome. Il server lo crea se manca, il client lo attende.
local function get(name: string, className: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local created = Instance.new(className)
		created.Name = name
		created.Parent = folder
		return created
	end
	return folder:WaitForChild(name)
end

-- Eventi server -> client (LightsEvent) e client -> server (Queue, SetSettings, ...).
function Net.event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return Net
