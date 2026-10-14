# Polarix Tow Job

<table>
  <tr>
    <td><img src="https://i.imgur.com/rmcChrR.png" alt="Screenshot 1" width="100%"/></td>
    <td><img src="https://i.imgur.com/7hM8LxP.png" alt="Screenshot 2" width="100%"/></td>
  </tr>
  <tr>
    <td><img src="https://i.imgur.com/LQTgX83.png" alt="Screenshot 3" width="100%"/></td>
    <td><img src="https://i.imgur.com/N4VF3f9.png" alt="Screenshot 4" width="100%"/></td>
  </tr>
</table>

A tow job for FiveM. Get paged for a stalled or wrecked car, search for it, rig it with the native tow arm and deliver it to the drop-off. It comes with a skill tree, unlockable map areas, police-marked tow requests and a Vue-based dashboard.

Works with **qbox**, **qb-core**, and **ESX** out of the box.

## Features

- **On-call pager** — go on call and get paged with a random job. Each page shows its payout range. Declining repeatedly makes the next page take longer.
- **Real tow gameplay** — find the vehicle inside a search circle, tow it with GTA's native tow rig and place it in the drop-off outline. Crashes during the tow cut into your payout.
- **Distance-based payout** — each mission pays a flat base plus an optional per-km bonus from the spawn point to the drop-off.
- **Police tow requests** — officers mark a player's vehicle for towing and it becomes a priority job for on-call operators, with an optional impound hook (`polarix_towjob:vehicleImpounded` event, or write straight to your framework's vehicle table). Officers mark via target option, or `/towrequest` without a target system. A vehicle that was just towed can't be marked again for an hour.
- **Skill tree** — three branches (Precision, Economy, Access) with perks that reduce damage penalties, boost payouts, discount truck purchases, repairs and area unlocks, and open up jobs earlier.
- **Map areas** — unlock regions of the map with money and level. Each area has its own reward and XP multiplier.
- **Vehicles** — buy tow trucks with their own damage resistance, or rent one on the spot (the first payment is taken when the rental starts). Optional livery, extras, colours and mods per truck.
- **Admin editor** — create and edit missions and areas in-game, test a mission without it being paid or recorded, and tune the economy at runtime. No restart needed.
- **Multi-language** — dashboard and notifications ship in de, en, es, fr, it, nl, pl, pt-br and tr.
- **Multiple target systems** — ox_target, qb-target, sleepless_interact, or none (markers and text prompts).
- **Polished dashboard** — overview, areas, skills, vehicles, history and leaderboard.

## Requirements

- [`ox_lib`](https://github.com/overextended/ox_lib)
- [`oxmysql`](https://github.com/overextended/oxmysql), with a **MariaDB** database
- One of: `qbx_core` (qbox), `qb-core`, or `es_extended` (ESX)

## Installation

1. IMPORTANT: Download the current version called `polarix_towjob_vX.X.X.zip` via the [release section](https://github.com/derPolarix/polarix_towjob/releases).
2. Drop the resource into your server's `resources/` folder as `polarix_towjob`.
3. Add to your `server.cfg`:
   ```
   ensure ox_lib
   ensure oxmysql
   ensure polarix_towjob
   ```
4. Take a look at the `config/` files and adjust your framework and target settings.
5. Start your server. Database tables are created and updated automatically on every start, no manual SQL import needed. The first admin to open the editor can import the example missions and areas with one click.

## Configuration

| File | What you can change |
|---|---|
| [config/shared.lua](config/shared.lua) | Framework, target system, language, currency, update check, XP curve, skill tree |
| [config/server.lua](config/server.lua) | Admin access, tow truck shop and rental (incl. livery, extras, colours, mods), pager timing, police requests and impound mode, damage penalty and payout tuning |
| [config/client.lua](config/client.lua) | Depot NPC and blip, spawn and parking locations, default keybinds (dashboard, store truck, confirm delivery, pager accept/decline) |

Missions, areas and most economy values are edited in-game, not in these files.

## Admin editor

Admins open the in-game editor with `/towjobadmin` to create, edit or disable missions and areas and to change runtime settings. Missions use hand-placed spawn points with a ghost-vehicle preview, and a test run is never paid or recorded. Admin access follows your framework's permission group, with an ACE fallback (`command.towjob_admin`).

## Support

Report bugs or request features via Tickets on [my Discord](https://discord.gg/EfzCFzqTRR) or via [GitHub Issues](https://github.com/derPolarix/polarix_towjob/issues).
