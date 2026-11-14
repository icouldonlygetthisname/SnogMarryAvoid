# SnogMarryAvoid

A WoW Forever (Interface 16001) addon for keeping an account-wide list of players you've met. Each player gets:

- a face: :) happy, :| meh, :( avoid
- a role: tank, healer, DPS or none
- a note

## Use

- Right-click a player (unit frame, target, party/raid, chat name, friends, guild, recent allies) and choose **SnogMarryAvoid**. The window opens with that player filled in. If they're already tagged, the menu entry shows their face.
- `/sma` toggles the window. `/sma target` opens your target. `/sma <name>` opens or adds a player by name.
- Click a row in the list to edit it. Save, Delete, or New to start a blank entry. Enter in either text box saves.

## :( players

- **Outgoing:** `C_PartyInfo.InviteUnit` and `C_PartyInfo.ConfirmInviteUnit` are wrapped, so inviting a :( player from any menu, `/invite`, or the friends list is blocked with a chat message.
- **Incoming:** their group invites (`PARTY_INVITE_REQUEST`) are declined automatically and the invite popup is hidden. The inviter is matched by name and by GUID (the GUID is stored when you tag someone from a unit).

**Caveat: Battle.net friends can't be blocked.** If a :( player is on your Battle.net friends list, invites in both directions go through as normal, and the window shows a red warning next to the faces. A friend is recognised by GUID, or by character name while they're online. An offline Battle.net friend tagged only by name can't be matched, but they also can't invite you while offline.

## Names

Forever uses regional unique names ("First Surname", no realm). Blizzard sometimes passes them as "First-Surname", so both forms map to the same entry (case-insensitive). On clients without regional names, entries are keyed by `Name-Realm`.

## Data

`SnogMarryAvoidDB.players` (account-wide SavedVariables), keyed by lowercased name:
`{ name, face = 1|2|3, role = "TANK"|"HEALER"|"DAMAGER"|nil, note, guid, updated }`.

## Deploy

```
robocopy E:\VScode\SnogMarryAvoid "E:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\SnogMarryAvoid" /E /XD .git
```
