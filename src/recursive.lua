require("lfs")

function lastPart(path)
	return string.match(path, "([^/]+/?)$")
end

function isDir(path)
	return lfs.attributes(path, "mode") == "directory"
end

function recurse(path)
	if string.sub(lastPart(path), 1, 1) == "." then return end
	
	print((isDir(path) and "D; " or "F; ") .. path)

	if isDir(path) then
		for file in lfs.dir(path) do
			recurse(path .. "/" .. file)
		end
	end
end

recurse(arg[1])
