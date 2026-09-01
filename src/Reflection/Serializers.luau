--!strict
-- [Serializers.luau]
-- Bidirectional string <-> Luau Type serializer and formatters

local Serializers = {}

function Serializers.FormatValue(val, valType)
	local t = valType or typeof(val)

	if val == nil then
		return "nil"
	elseif t == "string" then
		return tostring(val)
	elseif t == "number" then
		return string.format("%.4f", val):gsub("%.?0+$", "")
	elseif t == "boolean" then
		return val and "true" or "false"
	elseif t == "Vector2" then
		return string.format("%.2f, %.2f", val.X, val.Y)
	elseif t == "Vector3" then
		return string.format("%.2f, %.2f, %.2f", val.X, val.Y, val.Z)
	elseif t == "CFrame" then
		local x, y, z = val.X, val.Y, val.Z
		local rx, ry, rz = val:ToEulerAnglesXYZ()
		return string.format(
			"Pos(%.1f, %.1f, %.1f) Rot(%.1f, %.1f, %.1f)",
			x, y, z,
			math.deg(rx), math.deg(ry), math.deg(rz)
		)
	elseif t == "Color3" then
		return string.format("%d, %d, %d", math.round(val.R * 255), math.round(val.G * 255), math.round(val.B * 255))
	elseif t == "BrickColor" then
		return val.Name
	elseif t == "UDim" then
		return string.format("%.2f, %d", val.Scale, val.Offset)
	elseif t == "UDim2" then
		return string.format("{%.2f, %d}, {%.2f, %d}", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
	elseif t == "EnumItem" then
		return val.Name
	elseif t == "Instance" then
		return val.Name .. " [" .. val.ClassName .. "]"
	elseif t == "Font" then
		return val.Family .. " (" .. tostring(val.Weight.Name) .. ")"
	elseif t == "buffer" then
		return "[buffer: " .. tostring(buffer.len(val)) .. " bytes]"
	else
		return tostring(val)
	end
end

function Serializers.ParseValue(inputStr, targetType)
	if targetType == "string" then
		return true, inputStr
	elseif targetType == "number" then
		local num = tonumber(inputStr)
		if num ~= nil then
			return true, num
		end
		return false, "Invalid number"
	elseif targetType == "boolean" then
		local lower = string.lower(inputStr)
		if lower == "true" or lower == "1" then
			return true, true
		elseif lower == "false" or lower == "0" then
			return true, false
		end
		return false, "Invalid boolean"
	elseif targetType == "Vector3" then
		local parts = string.split(inputStr, ",")
		if #parts == 3 then
			local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
			if x and y and z then
				return true, Vector3.new(x, y, z)
			end
		end
		return false, "Expected 'x, y, z'"
	elseif targetType == "Vector2" then
		local parts = string.split(inputStr, ",")
		if #parts == 2 then
			local x, y = tonumber(parts[1]), tonumber(parts[2])
			if x and y then
				return true, Vector2.new(x, y)
			end
		end
		return false, "Expected 'x, y'"
	elseif targetType == "Color3" then
		local parts = string.split(inputStr, ",")
		if #parts == 3 then
			local r, g, b = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
			if r and g and b then
				return true, Color3.fromRGB(r, g, b)
			end
		end
		return false, "Expected 'r, g, b' (0-255)"
	elseif targetType == "UDim2" then
		local numbers = {}
		for num in string.gmatch(inputStr, "[-+]?%d*%.?%d+") do
			table.insert(numbers, tonumber(num))
		end
		if #numbers == 4 then
			return true, UDim2.new(numbers[1], numbers[2], numbers[3], numbers[4])
		end
		return false, "Expected '{xs, xo}, {ys, yo}'"
	end

	return false, "Unsupported direct parse type: " .. targetType
end

return Serializers
