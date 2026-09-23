# Economy audit

The Shards economy currently awards 25 for a Solo escape, 35 for a clean Solo escape, 40 for a Group escape, and 50 for a clean Group escape. The Daily Reactor awards 50 per UTC day. A new published-game profile starts with 150 Shards. Studio profiles start with 2,000 to make cosmetic QA fast; they do not represent live progression.

The expanded catalog has 12 items purchased with Shards across Drone, Trail, Vision, and Title slots. The first goal costs 200, so one daily claim or two ordinary Solo wins can unlock it. The highest goal costs 1,250, equal to 44 ordinary Solo wins, 28 ordinary Group wins, or 22 clean Group wins from the starting balance. These counts assume the player saves every Shard; buying earlier cosmetics extends the path.

Run `pwsh -File scripts/economy_audit.ps1` to recalculate the full price ladder directly from `Config.luau`. The script reports wins needed from a fresh profile for ordinary Solo, clean Solo, ordinary Group, clean Group, and clean Solo with one daily claim.

## Balance decisions

- Keep escape rewards unchanged until actual completion rates and round times are measured. Raising rewards blindly would shorten every existing cosmetic goal.
- Add a 200 Shard first goal and higher priced goals at 950 and 1,250 Shards. They provide early feedback and a longer term target without adding power advantages.
- Use the existing daily reward as a modest accelerator. Claiming it once is enough for the first cosmetic, while the highest goal still requires repeated play.
- Keep paid Shard packs optional. All Shards cosmetics are earnable through play, and the two pass cosmetics remain cosmetic only.

## Playtest data needed before the final balance pass

Record completed expeditions per player, Solo/Group win rates, median round duration, daily claim frequency, Shards earned and spent, first purchase time, and purchases by SKU over at least a week. Review new players separately from returning players. The existing player stats and economy telemetry already capture most of these signals; the Creator Dashboard is needed for live aggregate analysis. Adjust prices or rewards only after comparing these observations with the intended first purchase and long term goal times.
