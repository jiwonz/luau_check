local pathfs = require("./lune_packages/pathfs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local process = require("@lune/process")
local dirs = require("./lune_packages/dirs")
local net = require("@lune/net")

local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`

local sources = table.clone(process.args)
if #sources < 1 and pathfs.isFile("pesde.toml") then
	local pesdeManifest: {
		target: {
			environment: "roblox" | "luau" | "lune",
			lib: string?,
			bin: string?,
			build_files: { string }?,
		},
	} =
		serde.decode("toml", pathfs.readFile("pesde.toml"))

	local target = pesdeManifest.target
	if target.bin then
		table.insert(sources, target.bin)
	end
	if target.lib then
		table.insert(sources, target.lib)
	end
	if target.build_files then
		for _, v in target.build_files do
			table.insert(sources, v)
		end
	end
end

if #sources < 1 then
	stdio.ewrite(`{ERROR_PREFIX} No input source was given.\n`)
	process.exit(1)
	error("unreachable")
end

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

local luauLspParams = {
	"analyze",
}
local tempDir = dirs.createTempDir()

local globalTypes =
	net.request("https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/master/scripts/globalTypes.d.luau")
if not globalTypes.ok then
	stdio.ewrite(globalTypes.body)
	return process.exit(1)
end
local globalTypesFilePath = tempDir:join("globalTypes.d.luau")
pathfs.writeFile(globalTypesFilePath, globalTypes.body)

table.insert(luauLspParams, "--defs")
table.insert(luauLspParams, globalTypesFilePath:toString())

if pathfs.isFile("sourcemap.json") then
	table.insert(luauLspParams, "--sourcemap")
	table.insert(luauLspParams, "sourcemap.json")
end

table.insert(luauLspParams, sourceFiles)

process.spawn("luau_lsp", luauLspParams, spawnOptions)
print()
pathfs.removeDir(tempDir)

stdio.write(stdio.color("cyan"))
print("[stylua]")
stdio.write(stdio.color("reset"))
process.spawn("stylua", { "--check", sourceFiles }, spawnOptions)
local result = process.spawn("stylua", { "--check", sourceFiles }, {
	cwd = process.cwd,
	env = process.env,
	stdio = "default",
})

if result.ok then
	if result.stdout ~= "" and stdio.prompt("confirm", "Would you like stylua to format and fix your code?") then
		process.spawn("stylua", { sourceFiles }, spawnOptions)
	end
end
