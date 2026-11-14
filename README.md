# SnogMarryAvoid

A WoW Forever (Interface 16001) addon for keeping an account-wide list of players you've met. Each player gets:

- a face: :) happy, :| meh, :( avoid
- a role: tank, healer, DPS or none
- a note

## Install

1. Download `SnogMarryAvoid-<version>.zip` from [Releases](https://github.com/icouldonlygetthisname/SnogMarryAvoid/releases).
2. Extract it into `World of Warcraft\_forever_\Interface\AddOns\`, so you end up with `AddOns\SnogMarryAvoid\SnogMarryAvoid.toc`.
3. Restart the game. A new addon folder isn't picked up by `/reload`.

To share lists, both players need the addon (see [Sharing](#sharing--lists)).

## Use

- Right-click a player (unit frame, target, party/raid, chat name, friends, guild, recent allies) and choose **SnogMarryAvoid**. The window opens with that player filled in. If they're already tagged, the menu entry shows their face.
- The minimap button (drag it around the minimap edge) and the addon compartment entry both open the window. `/sma minimap` hides or shows the button.
- `/sma` toggles the window. `/sma target` opens your target. `/sma <name>` opens or adds a player by name.
- Click a row in the list to edit it. Save, Delete, or New to start a blank entry. Enter in either text box saves.

## :( players

- **Outgoing:** `C_PartyInfo.InviteUnit` and `C_PartyInfo.ConfirmInviteUnit` are wrapped, so inviting a :( player from any menu, `/invite`, or the friends list is blocked with a chat message.
- **Incoming:** their group invites (`PARTY_INVITE_REQUEST`) are declined automatically and the invite popup is hidden. The inviter is matched by name and by GUID (the GUID is stored when you tag someone from a unit).

**Caveat: Battle.net friends can't be blocked.** If a :( player is on your Battle.net friends list, invites in both directions go through as normal, and the window shows a red warning next to the faces. A friend is recognised by GUID, or by character name while they're online. An offline Battle.net friend tagged only by name can't be matched, but they also can't invite you while offline.

## Sharing :( lists

Sharing is always mutual. Both players agree, and both send their lists. Only your own :( entries are sent (name, role, note). Your :) and :| entries stay private, and entries you received are never passed on.

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

- `inbox[senderKey] = { from, via = "direct"|"guild", updated, entries = { [playerKey] = { name, role, note } } }`: lists received from others.
- `dismissed[playerKey] = true`: received entries you deleted.
- `guildShare`: guild opt-in. `minimap = { angle, hide }`.

## Deploy

```
robocopy E:\VScode\SnogMarryAvoid "E:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\SnogMarryAvoid" /E /XD .git
```
