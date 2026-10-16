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
- **Guild quests:** officers post farm quests ("60 Runecloth for bags", several items per quest, optional deadline). Progress is counted from the ledger whenever the bank character accepts a delivery by mail or trade. Top helpers per quest, a permanent points ranking, a tracker window and a toast when a quest is complete. Delivered items can be locked for requests. Each quest has its own **icon** (picked from the game's macro icon list, default = icon of the first item) and an own **tooltip text**; quest items show the normal item tooltip, **Shift-click** puts an item link (or the quest title) into the chat or the open quest editor, **Ctrl-click** takes an item over into a new quest. Completing a quest offers **post again with a new name** (#2, #3 ...), closed quests have a **Repeat** button, and officers can **post a quest to guild chat** (title plus real item links).
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
| `/bb maillog [N]` | (bank character) the last mail takes and why something was not booked |
| `/bb abgleich [rezepte]` / `abgleich buchen <Spieler> <Nr>` | (bank character) items in stock without a ledger entry, and book them afterwards |
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

- **3.0.5:** settings: an open selection menu (rank, depot type/char, keyword profession) is now closed when switching tabs or closing the window and covers the whole screen while open, so it can no longer carry over into other tabs. Without a selection the previous value stays unchanged.
- **3.0.4:** guild crafter flow as agreed: only recipes the **player's own client claimed** (G button in the basket) can be accepted by the bank; the automatic "possible" marking by keyword is gone. The bank tab shows the claim directly under the item rows with the cash on delivery **now and after accepting** (e.g. 4 recipes at 50 silver: 2g now, 1g 50s after accepting one), the claimed recipe is tagged [G], accepted ones [frei]. The overlapping layout is fixed.
- **3.0.3:** the bank also offers *Accept as guild crafter* when the player sent no claim (older client): recipes that fit keyword, profession and the ledger are marked `[guild crafter possible]`. New diagnostics: `/bb rights [name]` (keyword table, officer note keywords, rights list, effective keywords of a player) and `/bb craft [text]` (why a recipe can or cannot be requested for free on this character).
- **3.0.2:** the missing-file message now also says that /reload does not re-read BananaBank.toc: after an update with new files, quit WoW completely and start it again.
- **3.0.1:** if `Rules.lua` or `Craft.lua` are missing (incomplete update), the addon no longer throws errors; the file check names the missing file.
- **3.0.0:** **guild crafters and keywords** (step 4). New *Keywords* tab in the settings (Gildenbank rank): keyword and profession (or bags) pairs for the officer note, e.g. `[B, GSN, GE]`. Bank characters with the officer-note permission read the keywords and send a keyword list to the guild so every client knows its own rights. **Bags** can only be requested with the bags keyword. **Guild crafter:** a recipe whose profession fits one of your keywords gets a **G** button in the basket (only when your own client confirms: profession window scanned once, recipe not learned yet, skill high enough). The request is marked *guild crafter*; the bank sees *Accept as guild crafter* (checks rank, quality, keyword, profession of the recipe, and that the player has not received the recipe before according to the ledger; then the price of that recipe is 0, the rest stays normal), *Confirm normally* or *Reject*. Items from depot characters can no longer be requested (checked by the bank as well). A second short hello message (`X~`) now carries the rule / main bank / keyword list stamps.
- **2.9.1:** fix: depot type names typed in the settings were lost (the edit field changed the wrong row because of a Lua 5.0 loop variable), the same for removing rows and the type / character menus of the depot rows.
- **2.9.0:** depot types are editable. New **Depots** tab in the settings: up to 6 freely named types (default: Welcome packages, Raid stuff; rename, add with + Type, delete with x), every type shows up in the stock tree under "View only". Below, up to 4 depot characters: the type on the left, the character on the right (menus). The types are part of the synced rule set.
- **2.8.1:** depot characters are chosen from a menu of the known bank characters instead of typed in; each row has a character menu, a kind menu (welcome packages / raid stuff) and an x; **+ Depot** adds a row (up to 4, several characters per kind are merged).
- **2.8.0:** **depot characters** (step 3). In the Rules tab a Gildenbank character names one character for *Welcome packages* and one for *Raid stuff*. Their stock is left out of "Entire bank" and shown only in two new entries under "View only" in the category tree; items there cannot be requested (also not when such a character is picked in the bank selector). The depot names are part of the synced rule set.
- **2.7.2:** items that had no price at the last scan (not found at the AH) are always scanned again, regardless of the age setting.
- **2.7.1:** faster AH scan: items without any price scan come first, then the oldest scans; only prices older than N days are fetched again (setting for bank characters, default 10, 0 = scan everything). Hand-set prices are never fetched.
- **2.7.0:** guild prices: the calculated guild price (half of the cheapest 30 percent at the AH) is at least **50 silver**; older AH-based prices are raised to 50 silver as well, hand-set prices are left alone. **Bags** are now priced by the AH scan like BOE items and recipes (bind column shows "Bag", the price shows in the tooltip and goes into the cash on delivery).
- **2.6.0:** **request rules** (step 1 of the officer meeting list). New *Rules* tab in the settings: a character with the Gildenbank rank sets from which rank requests are allowed at all, and from which rank green, blue and epic items may be requested. Saved rules are synced to the guild (only accepted from a verified bank character; the newer set wins). **Until rules are saved, all requests are locked.** Members below the rank see the stock but cannot fill the basket or create a code; items above their quality are dimmed with a tooltip hint. The bank checks rank and quality again when it confirms a request (old or modified clients cannot bypass it), an unknown rank (not in the guild roster yet) counts as locked. Ranks are stored by name and position, a renamed rank is shown in the rules tab. Bank characters are exempt.
- **2.5.0:** **TurtleMail support**: with TurtleMail installed the attachments live in its own list (invisible to `GetSendMailItem`) and its Send button sends them. The addon now checks attachments with `TurtleMail.sendmail_attached` and sends through `TurtleMail.send_mail_button_onclick` (recipient set past its `SetText` override), instead of the standard send function, which sent letters without attachment and was rejected by the server for small characters.
- **2.4.5:** mail sending: when the mail window takes the item from the cursor but does not answer `GetSendMailItem`, an empty cursor after the click now counts as attached (the letter is sent). The failure message also prints the raw answers of `GetSendMailItem`. If the server still rejects the letter nothing is lost.
- **2.4.4:** mail sending: one single click per attachment (the second click attached items twice in the multi-attachment mail window), the result is checked after half a second, then the right-click way is tried once. A letter is never sent without a confirmed attachment.
- **2.4.3:** mail sending now goes through the mail window's own Send function like a manual send (cash on delivery in the amount field, COD mode selected), so a replacement mail window / mail addon handles it. The direct `SendMail` call remains as fallback.
- **2.4.2:** mail sending: when the client reports the attachment a moment late (multi-attachment mail window), the addon waits half a second and checks again instead of aborting with "The client did not take the attachment".
- **2.4.1:** mail sending: if the client does not take an attachment by the cursor, a second way (right-click attach, only while the Send tab is open) is tried and checked with `GetSendMailItem`. On failure the window state is printed, also `/bb maildebug`. The attachment slot count is no longer cached before the mail window exists.
- **2.4.0:** **bank mode is automatic** for every character with the Gildenbank rank (set at login; switch in the settings; whoever ran `/bb removebank` stays off). New **stock / ledger check**: `/bb abgleich [rezepte]` lists items that are in the bank without the ledger knowing them as received, `/bb abgleich buchen <player> <1,3,5-9|alle>` books them afterwards as a donation of that player (quests are credited as usual).
- **2.3.2:** opening the mailbox on a bank character refreshes the guild roster first, so new members are known. Mail from senders who are not in the guild roster is still booked, but marked: "(not in guild)" in the ledger and a note in the mail log.
- **2.3.1:** **mail log** for bank characters (`/bb maillog [N]` or Settings > Mail log): every mail take is logged with the reason when it was not booked (cash on delivery, sender is a bank, no room in the bags, no attachment, duplicate call). Duplicate detection is now based on the mailbox update event instead of a timer, so a pile of identical mails taken quickly is booked completely.
- **2.3.0:** category tree by profession: Entire bank, **Professions** (every profession selectable: alchemy, blacksmithing, enchanting, engineering, leatherworking, tailoring, jewelcrafting, cooking, first aid, other), each with its trade materials and its recipes (herbs under alchemy, ore under blacksmithing, leather under leatherworking, cloth under tailoring), then BOE (by slot), Potions, Bags, Other. Results are grouped the same way, e.g. "Alchemy - Recipes". Jewelcrafting recipes are recognised.
- **2.2.2:** category tree reordered: Entire bank, Trade materials, BOE, Recipes, Potions, Bags, Other (the results follow the same order). "Sellable" removed from the filter.
- **2.2.1:** cloth, leather and ore are recognised by the item name ending even when the server reports the same sub type for all trade goods (they were listed under trade goods / other). Category renamed to **Trade goods** (German: Handwerkswaren).
- **2.2.0:** the category tree gets a **All materials** group with sub-categories: cloth, leather, herbs, ore, and trade materials by profession (alchemy, enchanting, engineering, blacksmithing, jewelcrafting, tailoring, cooking, other). Results are grouped the same way, e.g. "Trade materials - Jewelcrafting". Banks scan the profession once more; until then it is derived from the item info or the name.
- **2.1.1:** sorting fix: items from old snapshots without a category are now sorted by their real type on every client (cloth, leather, ore, potions by item info or name), new category **Trade materials** for gems, thread, essences and similar, so "Other" only holds what really does not fit. The type name "Sellable" is shorter.
- **2.1.0:** stock tab in auction-house style: category tree on the left (recipes by profession, BOE by slot, cloth, leather, herbs, ore, potions, bags, other), results grouped under category headings (empty search = whole bank, sorted by category, then quality and name), icons at 24 px, scrolling instead of pages, switchable **list view** with names, counts and guild price. The type drop-down is replaced by the tree. Items from old snapshots without a category are listed under "Other" until the bank scans again.
- **2.0.0:** **settings window** (gear button, top right) replaces most slash commands: language, minimap button, quest tracker, debug, unhide items, status; for quest managers the quest log and quest credit; for bank characters bank mode, cash on delivery, whisper, scan, sync, AH scan and booking by hand. Sections that do not apply to the character are hidden. New **main bank**: the name members should send donations and mail to is shown at the top right ("Donate to: Bananenbank", click puts it into chat) and used in the guide and the quest hint. Guild master, Gildenbank rank and officers set it in the settings, the guild syncs it (only from managers). The guide no longer opens by itself. Slash commands keep working.
- **1.9.0:** built-in guide as a slideshow: the new **?** button (top right) or `/bb guide` opens 7 steps for members (stock, requests, pick-up, donating, guild quests, prices) and 5 steps for bank and officers (bank mode, handling requests, booking donations, creating quests, paying out). Screenshots can be added per slide later.
- **1.8.0:** guild quests get an **icon** (macro icon picker, default = first item) and a custom **tooltip text** (shown on the icon in the list, the detail view and the tracker, followed by need and progress). **Complete and post again:** closing a quest opens a dialog (only complete, or complete and post again with a new name, duration and reservation); closed and cancelled quests have a **Repeat** button. **Post to guild chat** sends the quest as text with real item links (officers only). Quest items now show the normal item tooltip everywhere; **Shift-click** an item (or the quest title) to put it into the chat, or into the open quest editor; **Ctrl-click** an item to take it over into a new quest; **Shift-click an item link in the chat** adds it to the open editor. Icon and tooltip are synced with the guild; older versions ignore the new fields.
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
