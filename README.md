# 🍌 BananaBank

**Guild bank for Vanilla WoW 1.12 (OctoWoW): share your stock, request items, track donations.**

![Version](https://img.shields.io/badge/version-1.7.0-ffd100) ![Client](https://img.shields.io/badge/client-1.12.1-blue) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

Vanilla WoW has no guild bank, so nobody knows what the bank character holds or who donated what. BananaBank fixes that: the bank character shares its stock over the guild channel, members request items with a code, the bank mails them out, and every donation and withdrawal lands in a ledger. Built for the guild **Banana Republic**. Lua 5.0, no libraries.

## Requirement: the guild rank `Gildenbank`

BananaBank only works in a guild that has a guild rank called **`Gildenbank`** (`guildbank` works as well, case does not matter). Only characters holding that rank count as a verified bank.

- The rank names are fixed in the addon. There is no setting for another rank.
- Without a character holding the rank, the addon is locked and the window only shows a notice.
- Every member checks the rank in their own guild roster, so editing files does not get around it.

## Features

- **Stock for everyone:** the bank character records bags and bank on every bank visit. Grid with quality borders, search and filters. Soulbound items are hidden.
- **Requests by code:** fill the cart, create a code, post it on Discord. The code reserves the items right away. Status: `Open → Confirmed → Sent`. Open requests expire after 7 days.
- **Mail and trade:** *Fetch items* prepares exact stacks, the send helper mails them (several attachments if the client allows). A trade with a requester counts towards their confirmed request.
- **Prices and COD:** targeted auction house scan for BOE items (average of the cheapest 30 %, divided by 2). Prices can be set by hand. Mail goes out cash on delivery if you want.
- **Ledger:** donations by mail and trade, withdrawals, COD sales and returned mail are booked automatically. Click a member in *Top donors* or *Withdrawals per member* to open a window with every stack (item, amount, date, source) in a scrollable list, switchable to totals per item. The **Totals** window shows how much of each material the whole guild donated or took, with search and top donors per material. Transfers between bank characters are not donations.
- **Bank directory (visible on bank characters only):** every bank character sets its own role (short role, description, categories such as cloth, leather, herbs, ore, potions, bags, recipes, BoE gear). The **Banks** tab lists all active banks with contents, gold, last scan and online state. The stock can be shown for all banks together or for a single bank (button next to *only available*). Item tooltips say which bank an item belongs to and when it lies on the wrong one. The Bank tab shows where the rest of a request is stored.
- **Guild quests:** officers post farm quests ("60 Runecloth for bags", several items per quest, optional deadline). Progress is counted from the ledger whenever the bank character accepts a delivery by mail or trade. Top helpers per quest, a permanent points ranking, a tracker window and a toast when a quest is complete. Delivered items can be locked for requests.
- German and English, minimap button, `/bb status` diagnostics.

## Screenshots

| Stock | Request code | Ledger | Prices |
|---|---|---|---|
| ![Stock](screenshots/01-stock-browse.png) | ![Code](screenshots/03-request-created.png) | ![Ledger](screenshots/10-ledger.png) | ![Prices](screenshots/11-prices.png) |

## Installation

1. Download the [latest release](https://github.com/BananaForge/BananaBank/releases) and put the `BananaBank` folder into `Interface/AddOns/`.
2. Enable it on the character screen and open the window with `/bb`.

When updating, delete the old folder first, otherwise an old `BananaBank.toc` can stop the new files from loading. **Every member needs the addon.**

## Usage

**Setup (once):** the guild master creates the rank `Gildenbank` and gives it to the bank character. On that character run `/bb setbank`, then open the bank.

**Members:** open `/bb`, click items on the **Stock** tab (click `+1`, Shift+click all, right-click `-1`), hit **Create code**, copy the message to Discord, follow the status on **Requests**.

**Bank character:** on the **Bank** tab paste the code, **Check**, then **Confirm** or **Reject**. At the bank hit **Fetch items**, at the mailbox **Send mail**.

| Command | Effect |
|---|---|
| `/bb` | Open or close the window |
| `/bb status` | Diagnostics: why is nothing shown? |
| `/bb setbank` / `removebank` | Set or remove the bank role for this character |
| `/bb scan` / `sync` | Record and send stock / sync with the guild |
| `/bb prices` / `ahscan` | Prices tab / fetch prices at the auction house |
| `/bb ledger [n\|text\|today]` | Print the latest ledger entries in chat (to check what was booked) |
| `/bb credit` | (bank character) credit donations that were booked without a quest to the open quests |
| `/bb book <player> <count> <item>` | (bank character) book a donation by hand |
| `/bb stock <text>` | (any character) show which stored bank stocks contain an item, with age and sender |
| `/bb find <text>` | (bank character) show where matching items are, and which bags are in use |
| `/bb banks` | Open the Banks tab |
| `/bb totals` | Open the donation totals window |
| `/bb quests` / `tracker` | Open the Guild quests tab / show or hide the quest tracker |
| `/bb unhide` | Show hidden items again (Alt+click hides an item) |
| `/bb lang de\|en\|auto` | Language |
| `/bb minimap` / `support` / `debug` | Minimap button / donation window / debug output |

A second bank character works the same way: any character with the rank can run `/bb setbank`. Stocks are added up, and a request can be filled from both.

## Guild quests

- **Who may create and manage quests:** guild master (rank 1), the `Gildenbank` rank and the officers (ranks 2 and 3). Everybody else sees quests and progress.
- **Creating:** *Guild quests* tab, **+ New quest**. Add items with Shift-click on an item in your bags (or Ctrl-click in the stock), set amounts, optional deadline in days, and whether delivered items are locked for requests.
- **Delivering:** by mail or trade to a bank character. A delivery counts when the bank accepts it. Overflow beyond the need is booked as a normal donation, older quests are filled first.
- **Points:** your share of each quest, added up (a whole quest alone = 10 points). Ranking is permanent, with a monthly view.
- **Tracker:** *Track* on a quest puts it into a small movable window. `/bb tracker` hides or shows it.
- Only deliveries booked by a verified bank character count, other clients discard anything else.
- Quest managers' activity is kept in a hidden local log for officers.

## Technical notes

- Client 1.12.1 (Interface 11200), saved variables `BananaBankDB`, addon prefix `BBNK` on the guild channel.
- Analytics: once per login, and when the guild dashboard BananaGuild asks for it, the addon reports its name and version invisibly to the guild (guild addon channel, prefix `BGLD`, via `BananaPresence.lua`). Nothing is shown in chat.
- Throttled send queue (0.3 s), messages under 250 bytes. Synchronised: stock, ledger, requests, prices, guild quests.
- Code format: `BB1-<ID>-<Player>-<ItemID>x<Amount>.<...>-<Checksum>` (Base36, DJB2 checksum).
- Limits: stock can only be read while the bank is open (the last scan is used in between). Other mail addons such as TurtleMail can interfere with attachments. Someone editing their own files can only fool themselves: other clients discard the data, and mail only goes to the name in the code.

## Contributing

Pull requests welcome, tested in-game on a 1.12 client. Lua 5.0 rules: no `#`, `%`, `string.match`, `select` or `...`; script handlers read `this`, `event` and `arg1..9` as globals; no `SetSize` or `SetColorTexture`; German texts in `Locale.lua` use umlauts and `ss` instead of `ß`.

## Changelog

- **1.7.0:** every BOE item and every recipe/formula counts as sellable (prices tab lists them all, bind column shows "Recipe"). New type filter in the stock tab for everyone: all recipes or one profession (e.g. Alchemy), BOE by slot, "Sellable", materials. A completed quest has a new **Pay out** button: it sets the delivered amounts aside as a confirmed request for a recipient (e.g. your tailor) and closes the quest, so the quest reservation ends and nothing stays reserved twice; mail it from the Bank tab. Banks must scan once so older snapshots get types.
- **1.6.6:** mail that stacks onto a partial stack is booked also when the bags are full (before, it was missed). New `/bb ledger`, `/bb credit` (credit unassigned donations to open quests, as separate "Quest credit" entries) and `/bb book` (book a donation by hand).
- **1.6.5:** a character holding the Gildenbank rank without bank mode gets a hint at login (its stock would otherwise go stale unnoticed); `/bb setbank` scans and sends the stock right away.
- **1.6.4:** new `/bb stock <text>` diagnostic for any character: which stored bank stocks contain an item, when they were stored and who sent them.
- **1.6.3:** equipping or swapping bags (bag slots and bank bag slots) refreshes the bank stock, so bags in use no longer count as available. New `/bb find <text>` shows where a bank character holds an item.
- **1.6.2:** the bank stock updates on every change of the bags, also with the bank closed (mailing, trading, opening the bags), but is only sent when the content changed. Fixes items showing up twice after being mailed from one bank to another.
- **1.6.1:** the bank directory (Banks tab, bank selector, belongs-to hints) is only shown on characters in bank mode.
- **1.6.0:** bank directory with roles and categories, banks tab, stock per bank, "belongs to" hints in tooltips, remaining items of a request shown with the bank that holds them. Stock snapshots carry the item category (set by the bank character).
- **1.5.0:** clickable ledger members (stack-by-stack window with item tooltips, scrollable, totals per item) and a guild-wide totals window per material. Split deliveries are shown as one stack again.
- **1.4.0:** guild quests (several items, optional deadline, top helpers, points ranking, tracker, toast, item reservation, hidden manager log). Ledger entries that advance a quest are only accepted from verified bank characters.
- **1.3.0:** fixed bank rank `Gildenbank` / `guildbank` as a hard requirement (lock screen, no rank setting), trades count towards confirmed requests, COD price frozen per stack, returned mail reduces withdrawals, bank-to-bank transfers are no longer donations.
- **1.2.x:** AH scan per item, price dialog, COD, rank sync (removed in 1.3.0).
- **1.0.0:** first release.

## Credits and license

Part of **BananaForge** (with [BananaRepublicProfs](https://github.com/BananaForge/BananaRepublicProfs) and [BananaLootline](https://github.com/BananaForge/BananaLootline)). Development: **Lumihunt**, guild Banana Republic. Free forever; if you want to support it, send in-game mail to Lumihunt. MIT, see [LICENSE](LICENSE).
