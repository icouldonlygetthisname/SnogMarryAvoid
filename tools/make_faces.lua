-- Generates the smiley face textures in Media/ as 64x64 32-bit TGA (WoW-readable).
-- Usage (from the addon folder): lua tools/make_faces.lua [previewDir]
-- With previewDir, also writes BMP copies there for viewing outside the game.

local SIZE = 64
local SS = 4 -- supersampling per axis

local FACES = {
	happy = { fill = { 0.30, 0.85, 0.25 }, mouth = "smile" },
	meh   = { fill = { 1.00, 0.80, 0.10 }, mouth = "flat" },
	avoid = { fill = { 0.92, 0.22, 0.20 }, mouth = "frown" },
}

local DARK = { 0.12, 0.08, 0.05 }

local function dist(x1, y1, x2, y2)
	local dx, dy = x1 - x2, y1 - y2
	return math.sqrt(dx * dx + dy * dy)
end

-- Distance from point to an arc (part of circle centre cx,cy radius r between angles a1..a2, radians,
-- y axis pointing down).
local function distArc(x, y, cx, cy, r, a1, a2)
	local a = math.atan2(y - cy, x - cx)
	if a >= a1 and a <= a2 then
		return math.abs(dist(x, y, cx, cy) - r)
	end
	local e1 = dist(x, y, cx + r * math.cos(a1), cy + r * math.sin(a1))
	local e2 = dist(x, y, cx + r * math.cos(a2), cy + r * math.sin(a2))
	return math.min(e1, e2)
end

local function distSegment(x, y, x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)
	t = math.max(0, math.min(1, t))
	return dist(x, y, x1 + t * dx, y1 + t * dy)
end

-- Returns r, g, b, a (0..1) for one sample point.
local function sample(face, x, y)
	local c = SIZE / 2
	local R = 29
	local d = dist(x, y, c, c)
	if d > R then return 0, 0, 0, 0 end

	-- outline
	if d > R - 2.5 then return DARK[1], DARK[2], DARK[3], 1 end

	-- features
	local eyeY, eyeDX = c - 6, 9
	if ((x - (c - eyeDX)) / 3.2) ^ 2 + ((y - eyeY) / 5) ^ 2 <= 1 then return DARK[1], DARK[2], DARK[3], 1 end
	if ((x - (c + eyeDX)) / 3.2) ^ 2 + ((y - eyeY) / 5) ^ 2 <= 1 then return DARK[1], DARK[2], DARK[3], 1 end

	local mouthD
	if face.mouth == "smile" then
		mouthD = distArc(x, y, c, c + 1, 15, math.rad(25), math.rad(155))
	elseif face.mouth == "frown" then
		mouthD = distArc(x, y, c, c + 24, 13, math.rad(-150), math.rad(-30))
	else
		mouthD = distSegment(x, y, c - 11, c + 13, c + 11, c + 13)
	end
	if mouthD <= 2.2 then return DARK[1], DARK[2], DARK[3], 1 end

	-- fill with a soft highlight towards the top-left
	local f = face.fill
	local shade = 1 + 0.35 * math.max(0, 1 - dist(x, y, c - 9, c - 11) / 26) - 0.18 * (y - c) / R
	return math.min(1, f[1] * shade), math.min(1, f[2] * shade), math.min(1, f[3] * shade), 1
end

local function render(face)
	local px = {}
	for py = 0, SIZE - 1 do
		for pxi = 0, SIZE - 1 do
			local r, g, b, a = 0, 0, 0, 0
			for sy = 0, SS - 1 do
				for sx = 0, SS - 1 do
					local sr, sg, sb, sa = sample(face, pxi + (sx + 0.5) / SS, py + (sy + 0.5) / SS)
					r, g, b, a = r + sr * sa, g + sg * sa, b + sb * sa, a + sa
				end
			end
			local n = SS * SS
			if a > 0 then r, g, b = r / a, g / a, b / a end -- un-premultiply
			px[#px + 1] = { r, g, b, a / n }
		end
	end
	return px
end

local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
local function le16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
local function le32(n) return le16(n % 65536) .. le16(math.floor(n / 65536)) end

local function writeTGA(path, px)
	local out = { string.char(0, 0, 2, 0, 0, 0, 0, 0), le16(0), le16(0), le16(SIZE), le16(SIZE), string.char(32, 0x28) }
	for _, p in ipairs(px) do
		out[#out + 1] = string.char(byte(p[3]), byte(p[2]), byte(p[1]), byte(p[4]))
	end
	local f = assert(io.open(path, "wb"))
	f:write(table.concat(out))
	f:close()
end

-- BMP preview, composited on a mid-grey background (bottom-up rows).
local function writeBMP(path, px)
	local rows = {}
	for y = SIZE - 1, 0, -1 do
		for x = 0, SIZE - 1 do
			local p = px[y * SIZE + x + 1]
			local bg = 0.35
			local function mix(v) return byte(v * p[4] + bg * (1 - p[4])) end
			rows[#rows + 1] = string.char(mix(p[3]), mix(p[2]), mix(p[1]))
		end
	end
	local data = table.concat(rows)
	local header = "BM" .. le32(54 + #data) .. le32(0) .. le32(54)
		.. le32(40) .. le32(SIZE) .. le32(SIZE) .. le16(1) .. le16(24) .. le32(0) .. le32(#data)
		.. le32(2835) .. le32(2835) .. le32(0) .. le32(0)
	local f = assert(io.open(path, "wb"))
	f:write(header .. data)
	f:close()
end

local previewDir = arg[1]
for name, face in pairs(FACES) do
	local px = render(face)
	writeTGA("Media/" .. name .. ".tga", px)
	if previewDir then writeBMP(previewDir .. "/" .. name .. ".bmp", px) end
	print("wrote Media/" .. name .. ".tga")
end
