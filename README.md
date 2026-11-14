# SnogMarryAvoid

A WoW Forever (Interface 16001) addon for keeping an account-wide list of players you've met. Each player gets:

- a face: green happy, yellow meh, or red avoid (written :) :| :( below)
- a role: tank, healer, DPS or none
- a note (private: notes are never shared)

## Install

1. Download `SnogMarryAvoid-<version>.zip` from [Releases](https://github.com/icouldonlygetthisname/SnogMarryAvoid/releases).
2. Extract it into `World of Warcraft\_forever_\Interface\AddOns\`, so you end up with `AddOns\SnogMarryAvoid\SnogMarryAvoid.toc`.
3. Restart the game. A new addon folder isn't picked up by `/reload`.

To share lists, both players need the addon (see [Sharing](#sharing--lists)).

## Use

- Right-click a player (unit frame, target, party/raid, chat name, friends, guild, recent allies) and hover **SnogMarryAvoid**. Pick a face to add or re-tag them in one click (an existing note and role are kept; a new party member gets the role they queued as). **Add with note and role...** opens the window with that player filled in. If they're already tagged, the menu entry shows their face.
- The minimap button (drag it around the minimap edge) and the addon compartment entry both open the window. `/sma minimap` hides or shows the button.
- `/sma` toggles the window. `/sma target` opens your target. `/sma <name>` opens or adds a player by name.
- **Edit:** click a row, or its **Edit** button, to load it into the editor at the top (the row is highlighted). Change the face, role or note and press **Save**. For a new player, **New** clears the editor and the button reads **Add**. Enter in either text box saves.
- **Delete:** **Delete** in the editor removes the entry being edited. To remove several, tick the checkboxes next to the names (the top checkbox ticks all) and press **Delete selected**. **Delete all** removes your own entries and every received list. Both ask for confirmation first.

## :( players

- **Outgoing:** `C_PartyInfo.InviteUnit` and `C_PartyInfo.ConfirmInviteUnit` are wrapped, so inviting a :( player from any menu, `/invite`, or the friends list is blocked with a chat message.
- **Incoming:** their group invites (`PARTY_INVITE_REQUEST`) are declined automatically and the invite popup is hidden. The inviter is matched by name and by GUID (the GUID is stored when you tag someone from a unit).

- **Ignore (on by default):** their chat is hidden (say, yell, emotes, whispers, channels, party, raid, instance, guild and officer chat), and their duel and trade requests are declined. This is done by the addon, not the game's ignore list, so there's no limit on how many players you can ignore. It only affects you; the other player isn't told. Turn it off with the **Ignore :(** checkbox or `/sma ignore` (invites stay blocked either way).

**Caveat: Battle.net friends can't be blocked or ignored.** If a :( player is on your Battle.net friends list, invites in both directions go through as normal, and the window shows a red warning next to the faces. A friend is recognised by GUID, or by character name while they're online. An offline Battle.net friend tagged only by name can't be matched, but they also can't invite you while offline.

## Sharing :( lists

Sharing is always mutual. Both players agree, and both send their lists. Only your own :( entries are sent, and only the name and role. **Notes are never shared**, because they're personal opinions that could come across as unfair or discriminatory to someone else. A note field sent by an older version is ignored, and notes received before this change are removed when the addon loads. Your :) and :| entries stay private, and entries you received are never passed on.

### With any player (swap)

- Offer a swap with `/sma share <name>` (or `/sma share` for your target), the **Share** button, or **Swap :( lists** in a player's right-click menu.
- They get a popup. Nothing is sent until they click Accept, and accepting sends their list back to you. Decline, Escape or a timeout cancels it. Offers expire after 2 minutes.
- A swap is one-off. To send an updated list, offer again.

### With guild mates (opt-in)

- Tick **Share with guild** in the window, or type `/sma guild`. It's off by default.
- Lists are swapped only between guild mates who have both ticked it. A guild mate who hasn't ticked it receives nothing.
- Swaps happen when you tick it, at login, and with anyone who ticks it later. Changes to your list go out to opted-in guild mates who are online, 5 seconds after your last edit.
- Unticking it withdraws your list from everyone else's addon and removes the guild lists you received.

### Received entries

- They show in the list with a grey "from <name>" (with "+N" if several people sent the same player), and they block invites like your own :( entries.
- Your own entry for that player always wins. If you've tagged someone :), a friend's :( won't block them.
- Each new list from a sender replaces their previous one, so their deletions carry over.
- Click one to view it. **Save** adopts it as your own entry. **Delete** hides it, and it stays hidden even after that sender's next sync.

### Protocol

Addon messages on prefix `SnogMarryAvoid`. Swap offers and list data are whispers. The guild channel carries only `HELLO`, `HI <name>` and `BYE`. A message on the guild channel proves the sender is in your guild, so guild list data is accepted only from opted-in guild mates seen there this session. Sends go through a throttled queue, and they may fail in combat or instances. A failed swap tells you in chat; a failed guild sync is silent and is retried at the next login. Text from other players is shown escaped.

## Names

Forever uses regional unique names ("First Surname", no realm). Blizzard sometimes passes them as "First-Surname", so both forms map to the same entry (case-insensitive). On clients without regional names, entries are keyed by `Name-Realm`.

## Data

`SnogMarryAvoidDB.players` (account-wide SavedVariables), keyed by lowercased name:
`{ name, face = 1|2|3, role = "TANK"|"HEALER"|"DAMAGER"|nil, note, guid, updated }`.

- `inbox[senderKey] = { from, via = "direct"|"guild", updated, entries = { [playerKey] = { name, role } } }`: lists received from others (no notes).
- `dismissed[playerKey] = true`: received entries you deleted.
- `guildShare`: guild opt-in. `ignore`: hide chat and decline duels/trades from :( players (default on). `minimap = { angle, hide }`.

## Face icons

`Media/happy.tga`, `meh.tga` and `avoid.tga` are 64x64 TGAs drawn by `tools/make_faces.lua`. To regenerate them, run `lua tools/make_faces.lua` from the addon folder. Pass a folder as an argument to also get BMP previews. `tools/` is left out of release zips.

## Deploy

```
robocopy E:\VScode\SnogMarryAvoid "E:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\SnogMarryAvoid" /E /XD .git
```
