local pathfs = require("lune_packages/pathfs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local process = require("@lune/process")

local REQUIRED_TOOLINGS = {
	"selene",
	"luau_lsp",
	"stylua",
}

local pesdePackageFolder: {
	[string]: boolean,
} = {
	roblox_packages = true,
	luau_packages = true,
	lune_packages = true,
}

local requiredPackages = {}

for i, v in REQUIRED_TOOLINGS do
	requiredPackages[i] = "pesde/" .. v
end

local pesdeManifest: {
	dev_dependencies: {
		[string]: { name: string? },
	},
} =
	serde.decode("toml", pathfs.readFile("pesde.toml"))

local missingPackages = {}

for _, package in requiredPackages do
	local found = false
	for _, dep in pesdeManifest.dev_dependencies do
		if dep.name == package then
			found = true
			break
		end
	end
	if found then
		continue
	end
	table.insert(missingPackages, package)
end

if #missingPackages > 0 then
	print("The following required development dependencies are missing:")
	for _, v in missingPackages do
		print(`\t> {v}`)
	end
	print()
	if stdio.prompt("confirm", "Would you like to install these missing packages?") then
		for _, v in missingPackages do
			process.spawn("pesde", { "add", "--dev", v, "-t", "lune" })
		end
		local result = process.spawn("pesde", { "install" })
		if not result.ok then
			error("pesde failed to install packages. Aborting")
		end
	end
end

local sources = {}

local function scan(dirPath: pathfs.AsPath)
	for _, path in pathfs.readDir(dirPath) do
		path = pathfs.getNoCurDirPathOf(pathfs.Path.from(dirPath):join(path))

		local isPesdePackageFolder = false
		for folderName in pesdePackageFolder do
			if path:equal(pathfs.Path.from(folderName)) then
				isPesdePackageFolder = true
				break
			end
		end
		if isPesdePackageFolder then
			continue
		end

		if path:equal(pathfs.Path.from("lune_packages")) then
			continue
		end
		if path:equal(pathfs.Path.from("roblox_packages")) then
			continue
		end
		if pathfs.isDir(path) then
			scan(path)
		elseif pathfs.isFile(path) then
			if path:extension() == "luau" or path:extension() == "lua" then
				table.insert(sources, path:toString())
			end
		end
	end
end

scan(".")

local sourceFiles = table.concat(sources, " ")

local spawnOptions: process.SpawnOptions = {
	cwd = process.cwd,
	env = process.env,
	stdio = "forward",
}

stdio.write(stdio.color("cyan"))
print("[selene]")
stdio.write(stdio.color("reset"))
process.spawn("selene", { sourceFiles }, spawnOptions)
print()

stdio.write(stdio.color("cyan"))
print("[luau-lsp]")
stdio.write(stdio.color("reset"))
process.spawn("luau_lsp", { "analyze", sourceFiles }, spawnOptions)
print()

stdio.write(stdio.color("cyan"))
print("[stylua]")
stdio.write(stdio.color("reset"))
process.spawn("stylua", { "--check", sourceFiles }, spawnOptions)
local result = process.spawn("stylua", { "--check", sourceFiles }, {
	cwd = process.cwd,
	env = process.env,
	stdio = "default",
})

if result.stdout == "" then
	print("clean!")
elseif stdio.prompt("confirm", "Would you like stylua to format and fix your code?") then
	process.spawn("stylua", { sourceFiles }, spawnOptions)
end
