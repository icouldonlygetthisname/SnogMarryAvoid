-- SnogMarryAvoid: tag players with a face, a role and a note.
-- Players tagged :( can't be invited, and their invites are declined automatically.

local ADDON_NAME = ...

local FACES = {
	{ text = ":)", color = "ff33dd33", label = "Happy" },
	{ text = ":|", color = "ffffd100", label = "Meh" },
	{ text = ":(", color = "ffff3333", label = "Avoid" },
}
local FACE_AVOID = 3

local ROLES = {
	{ key = "TANK", label = "Tank", atlas = "roleicon-tiny-tank" },
	{ key = "HEALER", label = "Healer", atlas = "roleicon-tiny-healer" },
	{ key = "DAMAGER", label = "DPS", atlas = "roleicon-tiny-dps" },
}
local ROLE_BY_KEY = {}
for _, r in ipairs(ROLES) do ROLE_BY_KEY[r.key] = r end

-- Unit popup menus that show a player. TARGET/FOCUS also cover NPCs, which are filtered out below.
local MENU_TYPES = {
	"PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FRIEND", "ENEMY_PLAYER", "TARGET", "FOCUS",
	"CHAT_ROSTER", "GUILD", "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER",
	"RECENT_ALLY", "PVP_SCOREBOARD",
}

local PREFIX = "|cffff69b4SnogMarryAvoid|r: "

local db -- SnogMarryAvoidDB, set on ADDON_LOADED
local SMA = {}

local function Print(msg)
	print(PREFIX .. msg)
end

----------------------------------------------------------------------------------------------------
-- Names
----------------------------------------------------------------------------------------------------
-- WoW Forever uses regional unique names: a player is "First Surname" with no realm, and
-- UnitName() returns ("First Surname", "Surname"). Blizzard sometimes joins the surname with the
-- realm separator instead ("First-Surname"), so both forms are folded into one key.

local seps = Constants and Constants.CharacterNameSeparatorConsts
local SURNAME_SEP = seps and seps.CHARACTERNAME_SURNAME_SEPARATOR or " "
local REALM_SEP = seps and seps.CHARACTERNAME_REALMNAME_SEPARATOR or "-"

local function Accessible(v)
	return v ~= nil and (not canaccessvalue or canaccessvalue(v))
end

local function RegionalNames()
	return RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()
end

-- Clean up a name for display and storage.
local function DisplayName(name)
	if type(name) ~= "string" or not Accessible(name) then return nil end
	name = strtrim(name)
	if name == "" then return nil end
	if RegionalNames() and REALM_SEP ~= SURNAME_SEP then
		local i = name:find(REALM_SEP, 1, true)
		if i then
			name = name:sub(1, i - 1) .. SURNAME_SEP .. name:sub(i + #REALM_SEP)
		end
	elseif not RegionalNames() and not name:find(REALM_SEP, 1, true) then
		name = name .. REALM_SEP .. GetNormalizedRealmName()
	end
	return name
end

local function Key(name)
	local display = DisplayName(name)
	return display and strlower(display)
end

local function NameFromUnit(unit)
	if not Accessible(unit) or not UnitExists(unit) then return nil end
	local isPlayer = UnitIsPlayer(unit)
	if not Accessible(isPlayer) or not isPlayer then return nil end
	local name, second = UnitName(unit)
	if not Accessible(name) then return nil end
	if not RegionalNames() and Accessible(second) and second and second ~= "" then
		name = name .. REALM_SEP .. second
	end
	return name
end

local function IsMe(name)
	return Key(name) == Key(NameFromUnit("player"))
end

-- Returns the player's name (and GUID if known) for a unit popup menu, or nil if it isn't a player.
local function NameFromContext(contextData)
	if not contextData then return nil end
	local unit, guid = contextData.unit, nil
	local name
	if unit then
		name = NameFromUnit(unit)
		if name then
			local g = UnitGUID(unit)
			if Accessible(g) then guid = g end
		end
	elseif Accessible(contextData.name) and contextData.name then
		name = contextData.name
		local surname = contextData.surname or contextData.server
		if Accessible(surname) and surname and surname ~= "" then
			name = name .. REALM_SEP .. surname
		end
	end
	if not name or IsMe(name) then return nil end
	return name, guid
end

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

function SMA:Get(name)
	local key = Key(name)
	return key and db.players[key], key
end

function SMA:GetByGUID(guid)
	if not Accessible(guid) or not guid then return nil end
	for _, entry in pairs(db.players) do
		if entry.guid == guid then return entry end
	end
end

-- Avoid entries received from friends. Kept apart from your own and never override them.
function SMA:GetShared(name)
	local key = Key(name)
	return key and db.shared[key], key
end

-- Your own entry decides if you have one; otherwise a friend's shared :( entry counts.
function SMA:IsAvoided(name, guid)
	local entry = self:Get(name) or self:GetByGUID(guid)
	if entry then return entry.face == FACE_AVOID, entry end
	local shared = name and self:GetShared(name)
	return shared ~= nil, shared
end

-- Battle.net friends are never blocked. Matched by GUID when we have one, else by character name
-- (only online friends expose their character, so an offline friend can't be matched by name).
function SMA:IsBNetFriend(name, guid)
	if Accessible(guid) and guid and C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID then
		if C_BattleNet.GetGameAccountInfoByGUID(guid) then return true end
	end
	local key = name and Key(name)
	if not key or not BNGetNumFriends then return false end
	local numFriends = BNGetNumFriends()
	for i = 1, numFriends or 0 do
		for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
			local info = C_BattleNet.GetFriendGameAccountInfo(i, j)
			local charName = info and info.characterName
			if Accessible(charName) and charName and charName ~= "" then
				if Key(charName) == key then return true end
				local realm = info.realmName
				if Accessible(realm) and realm and realm ~= "" and Key(charName .. REALM_SEP .. realm) == key then
					return true
				end
			end
		end
	end
	return false
end

local function FaceText(face)
	local f = FACES[face]
	return f and ("|c" .. f.color .. f.text .. "|r") or ""
end

-- Text from other players is shown escaped so it can't inject links, textures or colours.
local function Escape(s)
	return (s or ""):gsub("|", "||")
end

----------------------------------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------------------------------

local frame

local function MakeLabel(parent, text, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetText(text)
	return fs
end

local function MakeButton(parent, text, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	return b
end

local function UpdateToggleButtons(buttons, selected)
	for value, b in pairs(buttons) do
		if value == selected then b:LockHighlight() else b:UnlockHighlight() end
	end
end

function SMA:UpdateBNetWarning()
	local f = frame
	local show = f.face == FACE_AVOID and self:IsBNetFriend(f.nameBox:GetText(), f.guid)
	f.bnetWarning:SetShown(show)
end

function SMA:SetFace(face)
	frame.face = face
	UpdateToggleButtons(frame.faceButtons, face)
	self:UpdateBNetWarning()
end

function SMA:SetRole(role)
	frame.role = role
	UpdateToggleButtons(frame.roleButtons, role or "NONE")
end

-- Fill the editor with a player (existing entry or a new one).
function SMA:Load(name, guid)
	local f = self:GetFrame()
	local entry, key, shared = nil, nil, nil
	if name then entry, key = self:Get(name) end
	if name and not entry then shared = self:GetShared(name) end
	f.editKey = entry and key or nil
	f.sharedKey = shared and key or nil
	f.guid = guid or (entry and entry.guid) or nil
	local source = entry or shared
	f.nameBox:SetText(source and source.name or DisplayName(name) or "")
	f.noteBox:SetText(source and source.note or "")
	self:SetFace(entry and entry.face or (shared and FACE_AVOID) or 1)
	self:SetRole(source and source.role or nil)
	f.deleteButton:SetEnabled(source ~= nil)
	if shared then
		f.sourceText:SetText("Shared by " .. Escape(shared.from) .. ". Save to make it yours.")
	else
		f.sourceText:SetText("")
	end
	f.nameBox:ClearFocus()
	f.noteBox:ClearFocus()
end

function SMA:Save()
	local f = frame
	local name = DisplayName(f.nameBox:GetText())
	if not name then
		Print("Enter a player name first.")
		return
	end
	local key = Key(name)
	local old = f.editKey and db.players[f.editKey]
	if f.editKey and f.editKey ~= key then
		db.players[f.editKey] = nil
	end
	db.shared[key] = nil -- adopted: your own entry replaces the shared one
	db.players[key] = {
		name = name,
		face = f.face or 1,
		role = f.role,
		note = strtrim(f.noteBox:GetText() or ""),
		guid = f.guid or (old and old.guid) or nil,
		updated = time(),
	}
	self:Load(name)
	self:Refresh()
end

function SMA:Delete()
	if frame.editKey then
		db.players[frame.editKey] = nil
	elseif frame.sharedKey then
		db.shared[frame.sharedKey] = nil
	end
	self:Load(nil)
	self:Refresh()
end

function SMA:Refresh()
	if not frame then return end
	local list = {}
	for _, entry in pairs(db.players) do
		list[#list + 1] = entry
	end
	for key, shared in pairs(db.shared) do
		if not db.players[key] then
			list[#list + 1] = { name = shared.name, face = FACE_AVOID, role = shared.role, note = shared.note, from = shared.from }
		end
	end
	table.sort(list, function(a, b)
		if a.face ~= b.face then return a.face < b.face end
		return strlower(a.name) < strlower(b.name)
	end)
	frame.scrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
	frame.countText:SetText(#list .. " players")
end

local function InitRow(row, entry)
	if not row.faceText then
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.faceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.faceText:SetPoint("LEFT", 4, 0)
		row.faceText:SetWidth(22)
		row.roleIcon = row:CreateTexture(nil, "OVERLAY")
		row.roleIcon:SetSize(14, 14)
		row.roleIcon:SetPoint("LEFT", 28, 0)
		row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.nameText:SetPoint("LEFT", 48, 0)
		row.nameText:SetWidth(140)
		row.nameText:SetJustifyH("LEFT")
		row.nameText:SetWordWrap(false)
		row.noteText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.noteText:SetPoint("LEFT", 194, 0)
		row.noteText:SetPoint("RIGHT", -4, 0)
		row.noteText:SetJustifyH("LEFT")
		row.noteText:SetWordWrap(false)
		row:SetScript("OnClick", function(self) SMA:Load(self.entry.name) end)
	end
	row.entry = entry
	row.faceText:SetText(FaceText(entry.face))
	local role = ROLE_BY_KEY[entry.role or ""]
	if role then
		row.roleIcon:SetAtlas(role.atlas)
		row.roleIcon:Show()
	else
		row.roleIcon:Hide()
	end
	if entry.from then
		row.nameText:SetText(Escape(entry.name))
		row.noteText:SetText("|cff888888from " .. Escape(entry.from) .. "|r  " .. Escape(entry.note))
	else
		row.nameText:SetText(entry.name)
		row.noteText:SetText(entry.note or "")
	end
end

function SMA:GetFrame()
	if frame then return frame end

	local f = CreateFrame("Frame", "SnogMarryAvoidFrame", UIParent, "BasicFrameTemplateWithInset")
	frame = f
	f:SetSize(460, 500)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, "SnogMarryAvoidFrame") -- close with Escape

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -5)
	title:SetText("SnogMarryAvoid")

	-- Name
	MakeLabel(f, "Name", -38)
	f.nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.nameBox:SetSize(240, 20)
	f.nameBox:SetPoint("TOPLEFT", 76, -34)
	f.nameBox:SetAutoFocus(false)
	f.nameBox:SetScript("OnEnterPressed", function() SMA:Save() end)
	f.nameBox:SetScript("OnTextChanged", function() SMA:UpdateBNetWarning() end)

	f.bnetWarning = f:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	f.bnetWarning:SetPoint("TOPLEFT", 228, -70)
	f.bnetWarning:SetPoint("RIGHT", -12, 0)
	f.bnetWarning:SetJustifyH("LEFT")
	f.bnetWarning:SetText("Battle.net friend: invites won't be blocked")
	f.bnetWarning:Hide()

	-- Face
	MakeLabel(f, "Face", -68)
	f.faceButtons = {}
	for i, face in ipairs(FACES) do
		local b = MakeButton(f, FaceText(i), 48)
		b:SetPoint("TOPLEFT", 70 + (i - 1) * 52, -64)
		b:SetScript("OnClick", function() SMA:SetFace(i) end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(face.label)
			if i == FACE_AVOID then
				GameTooltip:AddLine("Can't be invited; their invites are declined.", 1, 1, 1, true)
				GameTooltip:AddLine("Battle.net friends are exempt.", 1, 0.3, 0.3, true)
			end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		f.faceButtons[i] = b
	end

	-- Role
	MakeLabel(f, "Role", -98)
	f.roleButtons = {}
	local roleChoices = { { key = "NONE", label = "None" } }
	for _, r in ipairs(ROLES) do roleChoices[#roleChoices + 1] = r end
	for i, r in ipairs(roleChoices) do
		local text = r.atlas and (CreateAtlasMarkup(r.atlas, 14, 14) .. " " .. r.label) or r.label
		local b = MakeButton(f, text, 84)
		b:SetPoint("TOPLEFT", 70 + (i - 1) * 88, -94)
		b:SetScript("OnClick", function() SMA:SetRole(r.key ~= "NONE" and r.key or nil) end)
		f.roleButtons[r.key] = b
	end

	-- Note
	MakeLabel(f, "Note", -128)
	f.noteBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.noteBox:SetSize(360, 20)
	f.noteBox:SetPoint("TOPLEFT", 76, -124)
	f.noteBox:SetAutoFocus(false)
	f.noteBox:SetMaxLetters(255)
	f.noteBox:SetScript("OnEnterPressed", function() SMA:Save() end)

	-- Actions
	local save = MakeButton(f, SAVE or "Save", 80)
	save:SetPoint("TOPLEFT", 70, -156)
	save:SetScript("OnClick", function() SMA:Save() end)

	f.deleteButton = MakeButton(f, DELETE or "Delete", 80)
	f.deleteButton:SetPoint("LEFT", save, "RIGHT", 6, 0)
	f.deleteButton:SetScript("OnClick", function() SMA:Delete() end)

	local new = MakeButton(f, "New", 80)
	new:SetPoint("LEFT", f.deleteButton, "RIGHT", 6, 0)
	new:SetScript("OnClick", function() SMA:Load(nil); f.nameBox:SetFocus() end)

	local share = MakeButton(f, "Share", 80)
	share:SetPoint("LEFT", new, "RIGHT", 6, 0)
	share:SetScript("OnClick", function() StaticPopup_Show("SNOGMARRYAVOID_SHARE") end)
	share:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Share your :( list")
		GameTooltip:AddLine("Sends your own avoid entries to another player with SnogMarryAvoid. They have to accept first.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	share:SetScript("OnLeave", GameTooltip_Hide)

	-- List
	f.countText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.countText:SetPoint("TOPLEFT", 16, -192)

	f.sourceText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.sourceText:SetPoint("TOPRIGHT", -16, -192)
	f.sourceText:SetJustifyH("RIGHT")

	f.scrollBox = CreateFrame("Frame", nil, f, "WowScrollBoxList")
	f.scrollBox:SetPoint("TOPLEFT", 12, -208)
	f.scrollBox:SetPoint("BOTTOMRIGHT", -30, 12)

	local scrollBar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", f.scrollBox, "TOPRIGHT", 6, 0)
	scrollBar:SetPoint("BOTTOMLEFT", f.scrollBox, "BOTTOMRIGHT", 6, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(20)
	view:SetElementInitializer("Button", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(f.scrollBox, scrollBar, view)

	f:SetScript("OnShow", function() SMA:Refresh() end)

	SMA:Load(nil)
	return f
end

function SMA:Open(name, guid)
	local f = self:GetFrame()
	f:Show()
	self:Load(name, guid)
	self:Refresh()
end

function SMA:Toggle()
	local f = self:GetFrame()
	if f:IsShown() then f:Hide() else self:Open(nil) end
end

----------------------------------------------------------------------------------------------------
-- Right-click menus
----------------------------------------------------------------------------------------------------

local function AddMenuEntries()
	if not (Menu and Menu.ModifyMenu) then return end
	for _, which in ipairs(MENU_TYPES) do
		Menu.ModifyMenu("MENU_UNIT_" .. which, function(_, rootDescription, contextData)
			local name, guid = NameFromContext(contextData)
			if not name then return end
			local entry = SMA:Get(name)
			local face = entry and entry.face or (SMA:GetShared(name) and FACE_AVOID)
			local text = "SnogMarryAvoid"
			if face then text = FaceText(face) .. " " .. text end
			rootDescription:CreateDivider()
			rootDescription:CreateButton(text, function() SMA:Open(name, guid) end)
			rootDescription:CreateButton("Share my " .. FaceText(FACE_AVOID) .. " list", function() SMA:Share(name) end)
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Invite blocking
----------------------------------------------------------------------------------------------------

-- Wrap the outgoing invite functions so :( players are never invited (menus, /invite, friends list).
local function WrapInvite(funcName)
	local original = C_PartyInfo and C_PartyInfo[funcName]
	if not original then return end
	C_PartyInfo[funcName] = function(targetName, ...)
		if Accessible(targetName) and SMA:IsAvoided(targetName) and not SMA:IsBNetFriend(targetName) then
			Print(FaceText(FACE_AVOID) .. " " .. DisplayName(targetName) .. " is on your avoid list. Invite blocked.")
			return
		end
		return original(targetName, ...)
	end
end

local function HideInvitePopups()
	StaticPopup_Hide("PARTY_INVITE")
	if LFGInvitePopup and LFGInvitePopup:IsShown() then
		StaticPopupSpecial_Hide(LFGInvitePopup)
	end
end

local function OnPartyInviteRequest(name, ...)
	local inviterGUID = select(6, ...)
	if not Accessible(name) then name = nil end
	if not Accessible(inviterGUID) then inviterGUID = nil end

	local avoided = name and SMA:IsAvoided(name, inviterGUID)
	if not avoided and inviterGUID then
		local _, _, _, _, _, gName, gRealm = GetPlayerInfoByGUID(inviterGUID)
		if Accessible(gName) and gName then
			avoided = SMA:IsAvoided(gName)
			if not avoided and Accessible(gRealm) and gRealm and gRealm ~= "" then
				avoided = SMA:IsAvoided(gName .. REALM_SEP .. gRealm)
			end
		end
	end
	if not avoided then return end
	if SMA:IsBNetFriend(name, inviterGUID) then return end

	DeclineGroup()
	HideInvitePopups()
	C_Timer.After(0, HideInvitePopups) -- in case Blizzard's handler runs after ours
	Print(FaceText(FACE_AVOID) .. " Declined a group invite from " .. (DisplayName(name) or "an avoided player") .. ".")
end

----------------------------------------------------------------------------------------------------
-- Sharing (manual push, receiver must accept)
----------------------------------------------------------------------------------------------------
-- Protocol, all WHISPER addon messages on COMM_PREFIX, fields separated by tabs:
--   OFFER <count>                 sender -> receiver, receiver gets an accept popup
--   ACCEPT / DECLINE              receiver -> sender
--   E <name> <role> <note>        one avoid entry (sender -> receiver, only after ACCEPT)
--   END                           sender -> receiver
-- Only your own :( entries are sent; entries received from friends are never passed on.

local COMM_PREFIX = "SnogMarryAvoid"
local MAX_MSG = 255
local OFFER_TTL = 120

local outgoingOffers = {} -- [receiverKey] = expiry time
local incoming = {}       -- [senderKey] = { expires, count }
local sendQueue = {}
local sendTicker

local THROTTLED = Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.AddonMessageThrottle
local SUCCESS = Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success

-- Cut a string to maxBytes without splitting a UTF-8 character.
local function TruncateUTF8(s, maxBytes)
	if #s <= maxBytes then return s end
	s = s:sub(1, maxBytes)
	local i = #s
	while i > 0 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
	if i > 0 and s:byte(i) >= 0xC0 then
		local lead = s:byte(i)
		local len = lead >= 0xF0 and 4 or lead >= 0xE0 and 3 or 2
		if #s - i + 1 < len then s = s:sub(1, i - 1) end
	end
	return s
end

local function ProcessSendQueue()
	local item = sendQueue[1]
	if not item then
		sendTicker:Cancel()
		sendTicker = nil
		return
	end
	local result = C_ChatInfo.SendAddonMessage(COMM_PREFIX, item.msg, "WHISPER", item.target)
	if THROTTLED and result == THROTTLED then return end -- try again next tick
	table.remove(sendQueue, 1)
	if SUCCESS and result ~= SUCCESS then
		-- Drop the rest of this transfer; it can't arrive complete.
		for i = #sendQueue, 1, -1 do
			if sendQueue[i].target == item.target then table.remove(sendQueue, i) end
		end
		Print("Couldn't send to " .. item.target .. " (error " .. tostring(result) .. "). Try again out of combat/instances.")
	end
end

local function Enqueue(msg, target)
	sendQueue[#sendQueue + 1] = { msg = TruncateUTF8(msg, MAX_MSG), target = target }
	if not sendTicker then
		sendTicker = C_Timer.NewTicker(0.2, ProcessSendQueue)
	end
end

local function OwnAvoidEntries()
	local list = {}
	for _, entry in pairs(db.players) do
		if entry.face == FACE_AVOID then list[#list + 1] = entry end
	end
	return list
end

function SMA:Share(target)
	target = type(target) == "string" and strtrim(target) or ""
	if target == "" then
		StaticPopup_Show("SNOGMARRYAVOID_SHARE")
		return
	end
	if IsMe(target) then
		Print("You can't share with yourself.")
		return
	end
	local count = #OwnAvoidEntries()
	if count == 0 then
		Print("You have no " .. FaceText(FACE_AVOID) .. " entries to share.")
		return
	end
	outgoingOffers[Key(target)] = GetTime() + OFFER_TTL
	Enqueue("OFFER\t" .. count, target)
	Print("Offered " .. count .. " " .. FaceText(FACE_AVOID) .. " entries to " .. target .. ". Waiting for them to accept.")
end

local function SendEntries(target)
	local list = OwnAvoidEntries()
	for _, entry in ipairs(list) do
		local note = (entry.note or ""):gsub("[\t\n]", " ")
		Enqueue("E\t" .. entry.name .. "\t" .. (entry.role or "") .. "\t" .. note, target)
	end
	Enqueue("END", target)
	Print("Sending " .. #list .. " entries to " .. target .. ".")
end

local function OnAddonMessage(prefix, text, channel, sender)
	if prefix ~= COMM_PREFIX or channel ~= "WHISPER" then return end
	if not (Accessible(text) and Accessible(sender)) or IsMe(sender) then return end
	local senderKey = Key(sender)
	if not senderKey then return end
	local cmd, rest = strsplit("\t", text, 2)
	local now = GetTime()

	if cmd == "OFFER" then
		local count = tonumber(rest) or 0
		StaticPopup_Show("SNOGMARRYAVOID_OFFER", Escape(DisplayName(sender)), count, sender)
	elseif cmd == "ACCEPT" then
		local expires = outgoingOffers[senderKey]
		if not expires or expires < now then return end
		outgoingOffers[senderKey] = nil
		SendEntries(sender)
	elseif cmd == "DECLINE" then
		if outgoingOffers[senderKey] then
			outgoingOffers[senderKey] = nil
			Print(sender .. " declined your list.")
		end
	elseif cmd == "E" then
		local transfer = incoming[senderKey]
		if not transfer or transfer.expires < now or not rest then return end
		local name, role, note = strsplit("\t", rest, 3)
		local key = Key(name)
		if not key or IsMe(name) then return end
		db.shared[key] = {
			name = DisplayName(name),
			role = ROLE_BY_KEY[role or ""] and role or nil,
			note = note or "",
			from = DisplayName(sender),
			received = time(),
		}
		transfer.count = transfer.count + 1
		transfer.expires = now + OFFER_TTL
	elseif cmd == "END" then
		local transfer = incoming[senderKey]
		if not transfer then return end
		incoming[senderKey] = nil
		Print("Received " .. transfer.count .. " " .. FaceText(FACE_AVOID) .. " entries from " .. Escape(DisplayName(sender)) .. ".")
		SMA:Refresh()
	end
end

StaticPopupDialogs["SNOGMARRYAVOID_OFFER"] = {
	text = "SnogMarryAvoid: %s wants to share %d avoid-list entries with you.",
	button1 = ACCEPT or "Accept",
	button2 = DECLINE or "Decline",
	OnAccept = function(_, sender)
		incoming[Key(sender)] = { expires = GetTime() + OFFER_TTL, count = 0 }
		Enqueue("ACCEPT", sender)
	end,
	OnCancel = function(_, sender, reason)
		if reason == "clicked" then Enqueue("DECLINE", sender) end
	end,
	timeout = 60,
	whileDead = 1,
	hideOnEscape = 1,
}

StaticPopupDialogs["SNOGMARRYAVOID_SHARE"] = {
	text = "Share your " .. FaceText(FACE_AVOID) .. " list with which player?",
	button1 = "Share",
	button2 = CANCEL or "Cancel",
	hasEditBox = 1,
	OnAccept = function(dialog)
		SMA:Share(dialog:GetEditBox():GetText())
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		SMA:Share(dialog:GetEditBox():GetText())
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

----------------------------------------------------------------------------------------------------
-- Minimap button & addon compartment
----------------------------------------------------------------------------------------------------

local ICON = "Interface\\Icons\\INV_Misc_Note_01"
local minimapButton

local function PositionMinimapButton()
	local angle = math.rad(db.minimap.angle or 200)
	local radius = Minimap:GetWidth() / 2 + 10
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function MinimapButtonDragUpdate()
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	PositionMinimapButton()
end

local function CreateMinimapButton()
	local b = CreateFrame("Button", "SnogMarryAvoidMinimapButton", Minimap)
	minimapButton = b
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	b:SetScript("OnClick", function() SMA:Toggle() end)
	b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", MinimapButtonDragUpdate) end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("SnogMarryAvoid")
		GameTooltip:AddLine("Click to open. Drag to move.", 1, 1, 1)
		GameTooltip:AddLine("/sma minimap to hide this button.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)

	PositionMinimapButton()
	b:SetShown(not db.minimap.hide)
end

function SnogMarryAvoid_OnAddonCompartmentClick()
	SMA:Toggle()
end

----------------------------------------------------------------------------------------------------
-- Events & slash command
----------------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PARTY_INVITE_REQUEST")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= ADDON_NAME then return end
		SnogMarryAvoidDB = SnogMarryAvoidDB or {}
		db = SnogMarryAvoidDB
		db.players = db.players or {}
		db.minimap = db.minimap or {}
		db.shared = db.shared or {}
		C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
		AddMenuEntries()
		CreateMinimapButton()
		WrapInvite("InviteUnit")
		WrapInvite("ConfirmInviteUnit")
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PARTY_INVITE_REQUEST" then
		if db then OnPartyInviteRequest(...) end
	elseif event == "CHAT_MSG_ADDON" then
		if db then OnAddonMessage(...) end
	end
end)
events:RegisterEvent("CHAT_MSG_ADDON")

SLASH_SNOGMARRYAVOID1 = "/sma"
SLASH_SNOGMARRYAVOID2 = "/snogmarryavoid"
SlashCmdList.SNOGMARRYAVOID = function(msg)
	msg = strtrim(msg or "")
	if msg == "" then
		SMA:Toggle()
	elseif msg == "minimap" then
		db.minimap.hide = not db.minimap.hide
		minimapButton:SetShown(not db.minimap.hide)
		Print("Minimap button " .. (db.minimap.hide and "hidden" or "shown") .. ".")
	elseif msg == "share" or msg:find("^share ") then
		local target = strtrim(msg:sub(6))
		if target == "" then target = NameFromUnit("target") or "" end
		SMA:Share(target)
	elseif msg == "target" then
		local name = NameFromUnit("target")
		if name and not IsMe(name) then
			local guid = UnitGUID("target")
			SMA:Open(name, Accessible(guid) and guid or nil)
		else
			Print("Your target isn't another player.")
		end
	else
		SMA:Open(msg)
	end
end
