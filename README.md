# SnogMarryAvoid

An addon for WoW Forever that remembers the players you've met. Tag each one with a face, and the addon helps you steer clear of the ones you'd rather not group with again.

| Face | Meaning |
| --- | --- |
| Green smile | Happy: you'd play with them again |
| Yellow, straight mouth | Meh |
| Red frown | Avoid |
| Orange, thinking | Under review: someone else has reported them, so proceed with care |

You can also give each player a role (tank, healer or DPS) and a private note. Your list is shared by all the characters on your account.

## Install

1. Download the latest `SnogMarryAvoid-<version>.zip` from [Releases](https://github.com/icouldonlygetthisname/SnogMarryAvoid/releases).
2. Extract it into `World of Warcraft\_forever_\Interface\AddOns\`, so that you have `AddOns\SnogMarryAvoid\SnogMarryAvoid.toc`.
3. Restart the game. `/reload` won't pick up a newly installed addon.

When a guild mate or someone in your group has a newer version, the addon tells you in chat when you log in, with a link to download it. To update, replace the folder and `/reload`.

## Tagging players

- **Right-click a player** (a chat name, party or raid frame, target, friends list or guild roster) and hover over **SnogMarryAvoid**. Pick a face to tag them in one click. Choose **Add with note and role...** to open the window with them filled in.
- **Open the window** with the minimap button, the addon compartment, or `/sma`. You can add a player by typing their name, too.
- **Edit** a player by clicking them in the list. Change the face, role or note and press **Save**.
- **Delete** players with **Delete** in the editor, or tick several and use **Delete selected**. **Delete all** clears everything.

## Avoided players

Once a player is on your avoid list:

- **Invites are blocked both ways.** You can't invite them by accident, and their group invites are declined automatically.
- **They're ignored.** Their chat and whispers are hidden, and their duel and trade requests are declined. This is separate from the game's ignore list, so there's no limit on how many players you can ignore. They aren't told. Turn it off with the **Ignore** checkbox or `/sma ignore`. Invites stay blocked either way.

**Battle.net friends are never blocked or ignored**, even if they're on your avoid list. The window warns you when that's the case.

## Olympus

Players in any guild whose name starts with **Olympus** are added to everyone's avoid list as soon as you see them in game. Your own guild mates are never added. You can add your own guild rules with `/sma avoidguild <start of guild name>`.

## Sharing lists

You can swap avoid lists with friends and guild mates who also use the addon. Sharing always needs both sides to agree.

- **With a friend:** use **Share**, **Swap lists** in their right-click menu, or `/sma share <name>`. They have to accept, and then you both swap lists.
- **With your guild:** tick **Share with guild** in the window (or `/sma guild`). Lists are only swapped with guild mates who have ticked it too. Untick it to take your list back.

Only the names and roles of your avoided players are shared. **Your notes are never shared**, and neither are your happy and meh players.

### What you receive

One person's bad experience might be a one-off, so a player someone else reports isn't blocked straight away:

- **Under review.** A reported player gets the thinking face. You're not blocked from playing with them. If they join your group, invite you (or you invite them), or whisper you, an on-screen warning says *previous poor behaviour reported, proceed with care*. That gives them the chance to show they've changed.
- **Three strikes.** If three different people report the same player, they move to your avoid list for good. Several characters belonging to one person count as a single report.
- **Olympus members** are avoided as soon as their guild is confirmed.
- **You always have the final say.** Your own face for a player overrides anything you've received. Deleting a received player hides them for good.

## Privacy and your BattleTag

To stop one person from using several characters to report the same player more than once, the addon uses your **BattleTag** in an anonymised form when you share your list:

- Your BattleTag is **never sent, saved or shown** to anyone.
- What's shared can't be turned back into your BattleTag. It can't be traced to you, and it can't be used to confirm who you are.
- It's only used when you share your list. If you never share, it's never used.

**By sharing your list, you consent to your BattleTag being used in this anonymised way.** If you don't want that, don't share. The rest of the addon works without it.

The addon shows you this the first time you share and asks you to agree. Nothing is shared until you do. Type `/sma privacy` to read it again or to withdraw your consent, which also stops guild sharing.

## Commands

| Command | What it does |
| --- | --- |
| `/sma` | Open or close the window |
| `/sma <name>` | Open a player, or add them |
| `/sma target` | Open your current target |
| `/sma share [name]` | Offer to swap lists (your target if no name) |
| `/sma guild` | Turn guild sharing on or off |
| `/sma ignore` | Turn ignoring avoided players on or off |
| `/sma avoidguild [name]` | List your guild rules, or add one |
| `/sma avoidguild remove <name>` | Remove one of your guild rules |
| `/sma privacy` | Read the privacy notice again, or withdraw consent |
| `/sma minimap` | Show or hide the minimap button |

## Licence

MIT. See [LICENSE](LICENSE).
