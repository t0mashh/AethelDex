--!strict
-- [SafeHost.luau]
-- Environment detection, stealth mounting, and GUI host manager for AethelDex

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

export type SafeHost = {
	RootGui: ScreenGui,
	Container: Instance,
	IsStealth: boolean,
	Destroy: (self: SafeHost) -> (),
}

local SafeHost = {}
SafeHost.__index = SafeHost

local function getSafeRef(inst)
	local cloneref = (rawget(getfenv(), "cloneref") )
	if typeof(cloneref) == "function" then
		local success, result = pcall(cloneref, inst)
		if success and typeof(result) == "Instance" then
			return result
		end
	end
	return inst
end

function SafeHost.new(customName)
	local name = customName or ("AethelDex_" .. string.sub(HttpService:GenerateGUID(false), 1, 8))
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 999999
	screenGui.IgnoreGuiInset = true

	local hostContainer = CoreGui
	local isStealth = false

	local gethui = (rawget(getfenv(), "gethui") )
	local syn = (rawget(getfenv(), "syn") )

	if typeof(gethui) == "function" then
		local success, hui = pcall(gethui)
		if success and typeof(hui) == "Instance" then
			hostContainer = getSafeRef(hui)
			screenGui.Parent = hostContainer
			isStealth = true
		end
	end

	if not isStealth and syn and typeof(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, screenGui)
		screenGui.Parent = getSafeRef(CoreGui)
		isStealth = true
	end

	if screenGui.Parent == nil then
		-- Fallback to CoreGui or PlayerGui
		local parented = pcall(function()
			screenGui.Parent = getSafeRef(CoreGui)
		end)

		if not parented or screenGui.Parent == nil then
			local localPlayer = Players.LocalPlayer
			if localPlayer then
				local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
				if playerGui then
					screenGui.Parent = getSafeRef(playerGui)
				end
			end
		end
	end

	local self = setmetatable({
		RootGui = screenGui,
		Container = hostContainer,
		IsStealth = isStealth,
	}, SafeHost)

	return self
end

function SafeHost:Destroy()
	if self.RootGui then
		self.RootGui:Destroy()
	end
end

return SafeHost
