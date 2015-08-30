-- Lander
-- (c) 2015 Koen Bolhuis

require("lfs")

local action = arg[1]
local arguments = {}

for i = 2, #arg do
	table.insert(arguments, arg[i])
end

---- Constants ----
local POSTS_DIR = "_posts"
local PAGES_DIR = "_pages"
local OUTPUT_DIR = "_output"

local INDEX_FILE = "_pages/index.html"
local INDEX_DEFAULT_CONTENT = [[<!DOCTYPE html>
<html>
<head>
	<title><% echo( config.site.name ) %></title>
</head>
<body>
	<h1>Hello world!</h1>
</body>
</html>]]

local POST_FILE = "_pages/post.html"
local POST_DEFAULT_CONTENT = [[<!DOCTYPE html>
<html>
<head>
	<title><% echo( post.title ) %></title>
</head>
<body>
	<h1><% echo( post.title ) %></h1>
	<p>Posted on <% echo( post.date ) %> by <% echo( post.author ) %></p>
	<p><% echo( post.content ) %></p>
</body>
</html>]]

local CONFIG_FILE = "_config.lua"
local CONFIG_DEFAULT_CONTENT = [[return {
	site = {
		name = "A website",
	},
	pagesAsDirectories = false,
}]]

---- Required files and directories ----
local DIRECTORIES = {POSTS_DIR, PAGES_DIR, OUTPUT_DIR}

local FILES = {
	[INDEX_FILE] = INDEX_DEFAULT_CONTENT,
	[POST_FILE] = POST_DEFAULT_CONTENT,
	[CONFIG_FILE] = CONFIG_DEFAULT_CONTENT,
}

---- Actions ----
if action == "setup" then

	local output = ""
	if arguments[1] then
		output = arguments[1] .. "/"
	end

	print("Setting up site")

	print("* Making directories")
	for _, dir in ipairs(DIRECTORIES) do
		print(" * " .. output .. dir)
		lfs.makedir(output .. dir)
	end

	print("* Making files")
	for file, content in pairs(FILES) do
		print(" * " .. output .. file)

		local handle = io.open(output .. file, "w")

		if not handle then
			print("Error: cannot create '" .. output .. file .. "'")
			os.exit(1)
		end

		if content and content ~= "" then
			handle:write(content)
		end

		handle:close()
	end

	print("Done")

elseif action == "make" then

	local target = ""
	if arguments[1] then
		target = arguments[1] .. "/"
	end

	print("Generating site")

	local result, siteConfigFunc = pcall(loadfile, target .. CONFIG_FILE)

	if not result then
		print("Error: cannot open the site config file (" .. target .. CONFIG_FILE .. ")")
		os.exit(1)
	end

	local result, siteConfig = pcall(siteConfigFunc)

	if not result then
		print("Error: something went wrong while loading the site config file")
		os.exit(1)
	end

	print("* Loaded site config")

	local markdown = require("markdown")

	if not markdown then
		print("Error: something went wrong while loading the Markdown renderer")
		os.exit(1)
	end

	print("* Loaded Markdown renderer")

	

end
