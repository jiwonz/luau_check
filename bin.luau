local pathfs = require("./lune_packages/pathfs")
local fs = pathfs.fs
local stdio = require("@lune/stdio")
local process = require("@lune/process")
local dirs = require("./lune_packages/dirs")
local net = require("@lune/net")
local pesdeExec = require("./lune_packages/pesde_exec")

local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`

local sources = table.clone(process.args)
if #sources < 1 then
	stdio.ewrite(`{ERROR_PREFIX} No input source was given.\n`)
	return process.exit(1)
end

local spawnOptions: process.SpawnOptions = {
	cwd = process.cwd,
	env = process.env,
	stdio = "forward",
}

stdio.write(stdio.color("cyan"))
print("[selene]")
stdio.write(stdio.color("reset"))
pesdeExec("selene", { unpack(sources) }, spawnOptions)
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
local globalTypesFilePath = tempDir.path:join("globalTypes.d.luau")
fs.writeFile(globalTypesFilePath, globalTypes.body)

table.insert(luauLspParams, "--defs")
table.insert(luauLspParams, globalTypesFilePath:toString())

if fs.isFile("sourcemap.json") then
	table.insert(luauLspParams, "--sourcemap")
	table.insert(luauLspParams, "sourcemap.json")
end

for _, sourceFile in sources do
	table.insert(luauLspParams, sourceFile)
end

pesdeExec("luau_lsp", luauLspParams, spawnOptions)
print()
tempDir:removeDir()

stdio.write(stdio.color("cyan"))
print("[stylua]")
stdio.write(stdio.color("reset"))
pesdeExec("stylua", { "--syntax", "Luau", "--check", unpack(sources) }, spawnOptions)
local result = pesdeExec("stylua", { "--syntax", "Luau", "--check", unpack(sources) }, {
	cwd = process.cwd,
	env = process.env,
	stdio = "default",
})

if result.ok then
	if result.stdout ~= "" and stdio.prompt("confirm", "Would you like stylua to format and fix your code?") then
		pesdeExec("stylua", { "--syntax", "Luau", unpack(sources) }, spawnOptions)
	end
end
