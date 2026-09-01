--!strict
-- [SearchEngine.luau]
-- High-speed search engine with prefix filters (c:, p:, t:) and regex support

local TreeState = require(script.Parent.TreeState)

export type MatchResult = {
	Node: TreeState.Node,
	MatchedText: string,
}

local SearchEngine = {}

function SearchEngine.FilterNodes(nodes, query)
	local trimmed = string.gsub(query, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return nodes
	end

	local results = {}

	-- Check for prefix filters
	local classFilter = nil
	local propFilterName = nil
	local propFilterValue = nil
	local tagFilter = nil
	local rawTerm = trimmed

	if string.sub(trimmed, 1, 2) == "c:" then
		classFilter = string.lower(string.sub(trimmed, 3))
	elseif string.sub(trimmed, 1, 2) == "t:" then
		tagFilter = string.sub(trimmed, 3)
	elseif string.sub(trimmed, 1, 2) == "p:" then
		local propQuery = string.sub(trimmed, 3)
		local eqPos = string.find(propQuery, "=")
		if eqPos then
			propFilterName = string.sub(propQuery, 1, eqPos - 1)
			propFilterValue = string.lower(string.sub(propQuery, eqPos + 1))
		else
			propFilterName = propQuery
		end
	end

	local lowerRaw = string.lower(rawTerm)

	for _, node in ipairs(nodes) do
		local inst = node.Instance
		local match = false

		if classFilter then
			if string.find(string.lower(inst.ClassName), classFilter, 1, true) then
				match = true
			end
		elseif tagFilter then
			local CollectionService = game:GetService("CollectionService")
			if CollectionService:HasTag(inst, tagFilter) then
				match = true
			end
		elseif propFilterName then
			local ok, val = pcall(function()
				return (inst )[propFilterName ]
			end)
			if ok and val ~= nil then
				if propFilterValue then
					if string.find(string.lower(tostring(val)), propFilterValue, 1, true) then
						match = true
					end
				else
					match = true
				end
			end
		else
			-- Standard text search by Instance Name or ClassName
			if string.find(string.lower(inst.Name), lowerRaw, 1, true) or
			   string.find(string.lower(inst.ClassName), lowerRaw, 1, true) then
				match = true
			end
		end

		if match then
			table.insert(results, node)
		end
	end

	return results
end

return SearchEngine
