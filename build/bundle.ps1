# [bundle.ps1]
# Automated bundler script to compile modular src/ files into a standalone AethelDex.luau

$srcDir = Join-Path $PSScriptRoot "..\src"
$outputFile = Join-Path $PSScriptRoot "..\AethelDex.luau"

Write-Host "Bundling AethelDex v1.0..." -ForegroundColor Cyan

# Order of modules for dependency-friendly bundling
$modules = @(
    @{ Name = "Signal"; Path = "Core\Signal.luau" },
    @{ Name = "Janitor"; Path = "Core\Janitor.luau" },
    @{ Name = "Config"; Path = "Core\Config.luau" },
    @{ Name = "Scheduler"; Path = "Core\Scheduler.luau" },
    @{ Name = "SafeHost"; Path = "Core\SafeHost.luau" },
    @{ Name = "TypeDefinitions"; Path = "Reflection\TypeDefinitions.luau" },
    @{ Name = "Serializers"; Path = "Reflection\Serializers.luau" },
    @{ Name = "Theme"; Path = "UI\Theme.luau" },
    @{ Name = "Icons"; Path = "UI\Icons.luau" },
    @{ Name = "TouchEngine"; Path = "UI\TouchEngine.luau" },
    @{ Name = "ReflectionEngine"; Path = "Reflection\ReflectionEngine.luau" },
    @{ Name = "TreeState"; Path = "Tree\TreeState.luau" },
    @{ Name = "SearchEngine"; Path = "Tree\SearchEngine.luau" },
    @{ Name = "VirtualList"; Path = "Tree\VirtualList.luau" },
    @{ Name = "PropertiesView"; Path = "Tools\PropertiesView.luau" },
    @{ Name = "RemoteSpy"; Path = "Tools\RemoteSpy.luau" },
    @{ Name = "ScriptViewer"; Path = "Tools\ScriptViewer.luau" },
    @{ Name = "NilScanner"; Path = "Tools\NilScanner.luau" },
    @{ Name = "CommandPalette"; Path = "UI\CommandPalette.luau" },
    @{ Name = "WindowManager"; Path = "UI\WindowManager.luau" },
    @{ Name = "Main"; Path = "Main.luau" }
)

$bundleContent = @"
--!strict
--[[
    ================================================================================
    AethelDex v1.0.0-PRO (Build 2026)
    Next-Generation In-Game DataModel Hierarchy Explorer & Debugger Suite for Roblox
    
    Loadstring Usage:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/t0mashh/AethelDex/main/AethelDex.luau"))()
    ================================================================================
--]]

local __modules = {}
local __cache = {}

local function __require(name: string): any
    if __cache[name] ~= nil then
        return __cache[name]
    end
    local loader = __modules[name]
    if not loader then
        error("[AethelDex Bundle] Module not found: " .. tostring(name))
    end
    local result = loader()
    __cache[name] = result
    return result
end

"@

foreach ($mod in $modules) {
    $fullPath = Join-Path $srcDir $mod.Path
    if (-not (Test-Path $fullPath)) {
        Write-Error "Module file not found: $fullPath"
        exit 1
    }

    $lines = Get-Content $fullPath
    $sanitized = @()
    foreach ($line in $lines) {
        if ($line.Trim().StartsWith("--!strict")) {
            continue
        }

        # Transform relative require(...) into __require("ModuleName")
        $transformed = $line -replace 'require\(script\.Parent(?:\.Parent)?\.(?:Core\.|Reflection\.|Tree\.|UI\.|Tools\.)?([a-zA-Z0-9_]+)\)', '__require("$1")'
        $sanitized += "    " + $transformed
    }

    $modBody = $sanitized -join "`n"
    $bundleContent += "`n-- Module: $($mod.Name)`n__modules[`"$($mod.Name)`"] = function()`n$modBody`nend`n"
}

# Entrypoint invocation at bottom of bundle
$bundleContent += @"

-- Bootstrap AethelDex v1.0
local Main = __require("Main")
Main.Init()
return Main
"@

Set-Content -Path $outputFile -Value $bundleContent -Encoding UTF8
Write-Host "Successfully generated standalone bundle: $outputFile" -ForegroundColor Green
$fileSize = (Get-Item $outputFile).Length
Write-Host "Bundle size: $fileSize bytes ($([math]::Round($fileSize / 1KB, 2)) KB)" -ForegroundColor Yellow
