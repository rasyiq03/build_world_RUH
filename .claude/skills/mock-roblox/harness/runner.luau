--!nocheck
-- runner.luau — HARNESS "Mock Roblox" untuk RUH (jalan di Lune, headless).
-- Meniru cukup banyak API Roblox agar ModuleScript di roblox/shared/ bisa dimuat &
-- dijalankan TANPA Studio: game:GetService, Instance.new, RBXScriptSignal (:Connect/:Fire),
-- pohon Instance untuk `script.Parent`/`require(<ModuleScript>)`, RunService.Heartbeat
-- bergerak via JAM VIRTUAL yang dikendalikan skenario.
--
-- Pakai:  lune run .claude/skills/mock-roblox/harness/runner.luau -- <scenario.luau>
-- Output: .claude/skills/mock-roblox/web/data.js  (window.RUN_DATA = {...}) untuk visualizer.
--
-- Mekanisme TIDAK boleh tahu soal harness ini (di Roblox asli ia nil). Visualisasi diturunkan
-- dari log print/Notify + event yang dikeluarkan skenario.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SKILL_DIR = ".claude/skills/mock-roblox"
local SHARED_DIR = "roblox/shared"

local realPrint = print

--==========================================================================
-- 0. Perekam event + jam virtual
--==========================================================================
local clock = 0.0
local events = {}
local meta = { mechanism = "?", scenario = "?", startedAt = os.time() }

local function record(kind, data)
	events[#events + 1] = { t = clock, kind = kind, data = data or {} }
end

local function logLine(prefix, msg)
	realPrint(("[t=%6.1f] %s%s"):format(clock, prefix, msg))
end

--==========================================================================
-- 1. RBXScriptSignal tiruan
--==========================================================================
local function newSignal(name)
	local handlers = {}
	local sig = { __isSignal = true, __name = name }
	function sig:Connect(fn)
		handlers[fn] = true
		return {
			Connected = true,
			Disconnect = function(self)
				handlers[fn] = nil
				self.Connected = false
			end,
		}
	end
	sig.connect = sig.Connect
	function sig:Once(fn)
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end
	function sig:Fire(...)
		for fn in pairs(handlers) do
			fn(...)
		end
	end
	function sig:Wait()
		-- headless: tak ada yield nyata; kembalikan langsung.
		return
	end
	return sig
end

--==========================================================================
-- 2. Instance runtime tiruan (Instance.new) — Part/Folder/Model/dll
--==========================================================================
local AUTO_SIGNALS = {
	Touched = true,
	TouchEnded = true,
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	AncestryChanged = true,
}

local RuntimeMethods = {}
local RuntimeMeta = {}

local function newInstance(className)
	local inst = {
		__isInstance = true,
		__isRuntime = true,
		ClassName = className,
		Name = className,
		__sigs = {},
		__children = {},
		__props = {},
	}
	return setmetatable(inst, RuntimeMeta)
end

function RuntimeMethods.Destroy(self)
	if self.Parent then
		local sib = self.Parent.__children
		for i, c in ipairs(sib) do
			if c == self then
				table.remove(sib, i)
				break
			end
		end
	end
	self.__destroyed = true
end
function RuntimeMethods.FindFirstChild(self, name)
	for _, c in ipairs(self.__children) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
RuntimeMethods.WaitForChild = function(self, name)
	return RuntimeMethods.FindFirstChild(self, name)
end
function RuntimeMethods.GetChildren(self)
	local t = {}
	for i, c in ipairs(self.__children) do
		t[i] = c
	end
	return t
end
function RuntimeMethods.FindFirstChildOfClass(self, class)
	for _, c in ipairs(self.__children) do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end
function RuntimeMethods.IsA(self, class)
	return self.ClassName == class or class == "Instance" or class == "BasePart" and (self.ClassName == "Part")
end
function RuntimeMethods.Clone(self)
	local c = newInstance(self.ClassName)
	for k, v in pairs(self.__props) do
		c.__props[k] = v
	end
	c.Name = self.Name
	return c
end

RuntimeMeta.__index = function(self, key)
	local m = RuntimeMethods[key]
	if m then
		return m
	end
	if AUTO_SIGNALS[key] then
		local s = rawget(self, "__sigs")[key]
		if not s then
			s = newSignal(key)
			rawget(self, "__sigs")[key] = s
		end
		return s
	end
	local props = rawget(self, "__props")
	if props[key] ~= nil then
		return props[key]
	end
	-- anak berdasarkan nama (gaya Roblox: workspace.SomeChild)
	for _, c in ipairs(rawget(self, "__children")) do
		if c.Name == key then
			return c
		end
	end
	return nil
end

RuntimeMeta.__newindex = function(self, key, val)
	if key == "Parent" then
		local old = rawget(self, "Parent")
		if old then
			for i, c in ipairs(old.__children) do
				if c == self then
					table.remove(old.__children, i)
					break
				end
			end
		end
		rawset(self, "Parent", val)
		if val and val.__children then
			table.insert(val.__children, self)
		end
		return
	end
	-- properti reguler (Name/ClassName tersimpan langsung; lainnya ke __props)
	if key == "Name" or key == "ClassName" or key:sub(1, 2) == "__" then
		rawset(self, key, val)
	else
		rawget(self, "__props")[key] = val
	end
end

--==========================================================================
-- 3. Services & global Roblox
--==========================================================================
local Players = {
	__isInstance = true,
	ClassName = "Players",
	Name = "Players",
	_players = {},
	PlayerAdded = newSignal("PlayerAdded"),
	PlayerRemoving = newSignal("PlayerRemoving"),
}
function Players:GetPlayers()
	local t = {}
	for p in pairs(self._players) do
		t[#t + 1] = p
	end
	return t
end
function Players:GetPlayerFromCharacter(char)
	if not char then
		return nil
	end
	for p in pairs(self._players) do
		if p.Character == char then
			return p
		end
	end
	return nil
end

local RunService = {
	__isInstance = true,
	ClassName = "RunService",
	Name = "RunService",
	Heartbeat = newSignal("Heartbeat"),
	Stepped = newSignal("Stepped"),
	RenderStepped = newSignal("RenderStepped"),
}
function RunService:IsClient()
	return false
end
function RunService:IsServer()
	return true
end
function RunService:IsStudio()
	return false
end

local HttpService = {
	__isInstance = true,
	ClassName = "HttpService",
	Name = "HttpService",
}
function HttpService:JSONDecode(s)
	return serde.decode("json", s)
end
function HttpService:JSONEncode(v)
	return serde.encode("json", v)
end
function HttpService:GenerateGUID()
	return "00000000-0000-0000-0000-000000000000"
end

local ReplicatedStorage = newInstance("ReplicatedStorage")
ReplicatedStorage.Name = "ReplicatedStorage"
local Workspace = newInstance("Workspace")
Workspace.Name = "Workspace"
function Workspace.Raycast()
	return nil
end
Workspace.Terrain = newInstance("Terrain")

local services = {
	Players = Players,
	RunService = RunService,
	HttpService = HttpService,
	ReplicatedStorage = ReplicatedStorage,
	Workspace = Workspace,
	Lighting = newInstance("Lighting"),
	TweenService = setmetatable({ ClassName = "TweenService" }, {
		__index = function()
			return function() end
		end,
	}),
}

local game = {
	__isInstance = true,
	ClassName = "DataModel",
	Name = "game",
	Workspace = Workspace,
}
function game:GetService(name)
	local s = services[name]
	if not s then
		s = newInstance(name)
		services[name] = s
	end
	return s
end
game.service = game.GetService

-- Enum permisif: Enum.Material.Concrete dst → token unik tak ber-efek.
local function permissiveProxy()
	return setmetatable({}, {
		__index = function(t, k)
			local child = setmetatable({ __enum = k }, {
				__index = function(_, kk)
					return { __enumItem = kk, Value = 0, Name = kk }
				end,
			})
			rawset(t, k, child)
			return child
		end,
	})
end
local Enum = permissiveProxy()

-- Vector3 / CFrame / Color3 / dll — cukup untuk skenario & build-script ringan.
local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
function Vector3.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function Vector3.__mul(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	elseif type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function Vector3.__div(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
function Vector3:__index2() end
Vector3.Magnitude = nil
setmetatable(Vector3, {
	__index = function(_, k)
		if k == "new" then
			return rawget(Vector3, "new")
		end
		return nil
	end,
})
-- magnitude sebagai properti
local Vector3mt = getmetatable(Vector3.new(0, 0, 0))
Vector3mt.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	end
	return rawget(Vector3, k)
end

local Vector2 = {
	new = function(x, y)
		return { X = x or 0, Y = y or 0 }
	end,
}
local Color3 = {
	new = function(r, g, b)
		return { R = r or 0, G = g or 0, B = b or 0 }
	end,
	fromRGB = function(r, g, b)
		return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }
	end,
}
local CFrame = {}
CFrame.new = function(x, y, z)
	return { X = x or 0, Y = y or 0, Z = z or 0, __cframe = true }
end
CFrame.Angles = function()
	return { __cframe = true, __angles = true }
end
setmetatable(CFrame, {
	__index = function()
		return function()
			return CFrame.new(0, 0, 0)
		end
	end,
})
local NumberRange = {
	new = function(a, b)
		return { Min = a, Max = b or a }
	end,
}
local NumberSequence = {
	new = function(a)
		return { value = a }
	end,
}

-- task: tanpa yield nyata (mekanisme kita pakai Heartbeat, bukan task.wait).
local task = {
	wait = function(t)
		return t or 0
	end,
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		coroutine.resume(co, ...)
		return co
	end,
	defer = function(fn, ...)
		local co = coroutine.create(fn)
		coroutine.resume(co, ...)
		return co
	end,
	delay = function(_, fn, ...)
		local co = coroutine.create(fn)
		coroutine.resume(co, ...)
		return co
	end,
	cancel = function() end,
}

local function mockPrint(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	local msg = table.concat(parts, " ")
	record("print", { text = msg })
	logLine("", msg)
end
local function mockWarn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	local msg = table.concat(parts, " ")
	record("warn", { text = msg })
	logLine("WARN: ", msg)
end

--==========================================================================
-- 4. Pohon ModuleScript dari filesystem + require berbasis Instance
--==========================================================================
local ModuleMethods = {}
local ModuleMeta = {}

local function newNode(className, name, parent, path)
	local n = {
		__isInstance = true,
		__isModuleNode = true,
		ClassName = className,
		Name = name,
		Parent = parent,
		__children = {},
		__path = path,
	}
	return setmetatable(n, ModuleMeta)
end

function ModuleMethods.FindFirstChild(self, name)
	for _, c in ipairs(self.__children) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function ModuleMethods.WaitForChild(self, name)
	local c = ModuleMethods.FindFirstChild(self, name)
	if not c then
		error(("[mock] WaitForChild gagal (tak ada): %s di %s"):format(name, self.Name), 2)
	end
	return c
end
function ModuleMethods.GetChildren(self)
	local t = {}
	for i, c in ipairs(self.__children) do
		t[i] = c
	end
	return t
end
function ModuleMethods.IsA(self, class)
	return self.ClassName == class
		or class == "Instance"
		or (self.ClassName == "ModuleScript" and class == "LuaSourceContainer")
end

ModuleMeta.__index = function(self, key)
	local m = ModuleMethods[key]
	if m then
		return m
	end
	for _, c in ipairs(rawget(self, "__children")) do
		if c.Name == key then
			return c
		end
	end
	return nil
end

local function buildTree(dirPath, name, parent)
	local folder = newNode("Folder", name, parent, dirPath)
	local entries = fs.readDir(dirPath)
	table.sort(entries)
	for _, entry in ipairs(entries) do
		local full = dirPath .. "/" .. entry
		if fs.isDir(full) then
			table.insert(folder.__children, buildTree(full, entry, folder))
		elseif fs.isFile(full) and (entry:match("%.lua$") or entry:match("%.luau$")) then
			local modName = entry:gsub("%.luau?$", "")
			table.insert(folder.__children, newNode("ModuleScript", modName, folder, full))
		end
	end
	return folder
end

local moduleCache = {}
local customRequire -- forward

local function baseGlobals(scriptNode)
	return {
		script = scriptNode,
		require = customRequire,
		game = game,
		workspace = Workspace,
		Instance = { new = newInstance },
		Enum = Enum,
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		NumberRange = NumberRange,
		NumberSequence = NumberSequence,
		task = task,
		tick = function()
			return clock
		end,
		time = function()
			return clock
		end,
		print = mockPrint,
		warn = mockWarn,
	}
end

local function makeEnv(scriptNode)
	local env = baseGlobals(scriptNode)
	return setmetatable(env, { __index = _G })
end

local function loadModule(node)
	if node.ClassName ~= "ModuleScript" then
		error("[mock] require bukan ModuleScript: " .. tostring(node.Name), 2)
	end
	if moduleCache[node] then
		return moduleCache[node]
	end
	local src = fs.readFile(node.__path)
	local chunk = luau.load(src, { environment = makeEnv(node), debugName = node.Name })
	local result = chunk()
	moduleCache[node] = result
	return result
end

customRequire = function(target)
	if type(target) == "table" and target.__isModuleNode then
		return loadModule(target)
	end
	error("[mock] require hanya mendukung ModuleScript instance, dapat: " .. tostring(target), 2)
end

--==========================================================================
-- 5. API harness untuk skenario (objek `h`)
--==========================================================================
local sharedTree = buildTree(SHARED_DIR, "shared", ReplicatedStorage)
-- shared & mechanisms juga ditaruh di ReplicatedStorage agar pola Roblox konsisten.
table.insert(ReplicatedStorage.__children, sharedTree)

-- npc/ (ReplicatedStorage.Npc di Rojo) di-mount juga agar behavior NPC bisa di-uji headless.
local NPC_DIR = "roblox/npc"
local npcTree = nil
if fs.isDir(NPC_DIR) then
	npcTree = buildTree(NPC_DIR, "Npc", ReplicatedStorage)
	table.insert(ReplicatedStorage.__children, npcTree)
end

-- Resolve node "MechanismRegistry"/"mechanisms/Wukuf" dari sebuah pohon (nil bila tak ada).
local function resolveNode(tree, dotted)
	local node = tree
	for part in dotted:gmatch("[^/]+") do
		node = node and ModuleMethods.FindFirstChild(node, part)
		if not node then
			return nil
		end
	end
	return node
end

local function requireFromShared(dotted)
	local node = resolveNode(sharedTree, dotted)
	if not node then
		error("[mock] modul shared tak ditemukan: " .. dotted, 2)
	end
	return loadModule(node)
end

local Registry = requireFromShared("MechanismRegistry")

local h = {}
function h.now()
	return clock
end
function h.event(kind, data)
	record(kind, data)
end
function h.spawnPlayer(name)
	local char = newInstance("Model")
	char.Name = name
	local hrp = newInstance("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Parent = char
	local player = {
		__isInstance = true,
		__isPlayer = true,
		ClassName = "Player",
		Name = name,
		Character = char,
		__hrp = hrp,
		__attrs = {},
	}
	function player:SetAttribute(k, v)
		self.__attrs[k] = v
	end
	function player:GetAttribute(k)
		return self.__attrs[k]
	end
	Players._players[player] = true
	Players.PlayerAdded:Fire(player)
	record("player_join", { player = name })
	return player
end
function h.newZone(opts)
	opts = opts or {}
	local p = newInstance("Part")
	p.Name = opts.name or "Zone"
	p.Anchored = true
	p.CanCollide = false
	if opts.size then
		p.Size = opts.size
	end
	if opts.center then
		p.Position = opts.center
	end
	p.Parent = Workspace
	return p
end
function h.enter(part, player)
	record("enter", { player = player.Name, zone = part.Name })
	part.Touched:Fire(player.__hrp)
end
function h.leave(part, player)
	record("leave", { player = player.Name, zone = part.Name })
	part.TouchEnded:Fire(player.__hrp)
end
function h.heartbeat(dt)
	clock += dt
	RunService.Heartbeat:Fire(dt)
end
function h.advance(seconds, step)
	step = step or 1
	local remaining = seconds
	while remaining > 1e-6 do
		local dt = math.min(step, remaining)
		h.heartbeat(dt)
		remaining -= dt
	end
end
h.registry = Registry
function h.activate(id, ctx)
	record("activate", { id = id })
	Registry.activate(id, ctx)
end
function h.deactivate()
	record("deactivate", {})
	Registry.deactivateCurrent()
end
function h.isDone()
	local d = Registry.isActiveDone()
	record("isDone", { value = d })
	return d
end
function h.mech(id)
	return Registry._mods[id]
end
-- Ambil modul shared/npc berdasarkan path bertitik-miring (mis. "ManasikRunner",
-- "mechanisms/Wukuf", "JamaahTawaf") untuk skenario tingkat-spine / NPC.
function h.require(dotted)
	local node = resolveNode(sharedTree, dotted) or (npcTree and resolveNode(npcTree, dotted))
	if not node then
		error("[mock] modul tak ditemukan di shared/npc: " .. dotted, 2)
	end
	return loadModule(node)
end

--==========================================================================
-- 6. Muat semua mekanisme + jalankan skenario
--==========================================================================
local scenarioPath = process.args[1] or (SKILL_DIR .. "/scenarios/wukuf.luau")
meta.scenario = scenarioPath

realPrint("== mock-roblox harness ==")
realPrint("shared : " .. SHARED_DIR)
realPrint("scenario: " .. scenarioPath)
realPrint("--------------------------------")

Registry.load() -- memuat & init semua mekanisme (validasi kontrak)

-- Lingkungan skenario: global Roblox + h.
local scenarioEnv = baseGlobals(nil)
scenarioEnv.h = h
scenarioEnv.meta = function(k, v)
	meta[k] = v
end
setmetatable(scenarioEnv, { __index = _G })

local scenarioSrc = fs.readFile(scenarioPath)
local scenarioChunk = luau.load(scenarioSrc, { environment = scenarioEnv, debugName = "scenario" })
scenarioChunk()

--==========================================================================
-- 7. Tulis output untuk visualizer web
--==========================================================================
meta.duration = clock
meta.eventCount = #events
local payload = serde.encode("json", { meta = meta, events = events }, true)
local webDir = SKILL_DIR .. "/web"
if not fs.isDir(webDir) then
	fs.writeDir(webDir)
end
local outPath = webDir .. "/data.js"
fs.writeFile(outPath, "window.RUN_DATA = " .. payload .. ";\n")

realPrint("--------------------------------")
realPrint(("selesai: %d event, durasi virtual %.1fs"):format(#events, clock))
realPrint("data -> " .. outPath)
realPrint("buka  -> " .. SKILL_DIR .. "/web/index.html")
