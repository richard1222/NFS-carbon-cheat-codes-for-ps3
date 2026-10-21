![Platform](https://img.shields.io/badge/Platform-PS3-blue)
![Region](https://img.shields.io/badge/Region-USA-green)
![Title%20ID](https://img.shields.io/badge/Title%20ID-BLUS30016-orange)
![Version](https://img.shields.io/badge/Version-01.00-yellow)
![Status](https://img.shields.io/badge/Status-Active%20Research-yellow)
# Need for Speed: Carbon â€” PS3 cheats (USA, `BLUS30016`)

Runtime cheat codes for **Need for Speed: Carbon** on the **USA** PS3 disc.

**Target:** `BLUS30016`, app **`01.00`** â€” confirmed by reading `PARAM.SFO`
directly off the console, not assumed.

> **Do not use the Europe (`BLES00020`) addresses.** They are different. The
> money and nitro code addresses differ between regions, so the two sets are not
> interchangeable.

---

## Verified on hardware

A cheat counts here only once it has been applied to a **running game on a real
console** and the effect was **seen on screen**. Not "the address looks right",
not "the tool said success".

| cheat | applied on console | effect seen in game | notes |
|---|---|---|---|
| **Infinite Nitro** | **yes** | **yes** | gauge stops draining when used, in a live race |
| Infinite Bullet Time | not yet | not yet | value looks correct; untested |
| Lot + Infinite Money | yes | **no** | see the warning below â€” the upstream value is wrong |

**One cheat is verified. Two are not.**

---

## Infinite Nitro â€” the verified one

```
ASM Infinite Nitro
0 00462CC0 60000000
```

**What it does.** The game's own instruction at `00462CC0` is `D01F0120`, which
is `stfs f0, 0x120(r31)` â€” *store the drained nitro value back*. Replacing it
with `60000000` (a `nop`) removes that store.

Here is that exact spot in the game's code, read live from the console:

```
00462CB0  C01F0120   lfs   f0, 0x120(r31)    load nitro
00462CB4  7F83E378   mr    r3, r28
00462CB8  EC1E077C   fsubs f0, f0, f1       SUBTRACT (this is the drain)
00462CBC  7F24CB78   mr    r4, r25
00462CC0  D01F0120   stfs  f0, 0x120(r31)   store it back   <-- replaced with nop
00462CC4  4BFC622D   bl    ...
00462CC8  60000000   nop                    (already a nop in the original)
```

`nop`-ing the store means the subtracted value is never written, so the gauge
stops falling.

**What it does not do.** It does not refill the gauge. It stops the subtraction.
`nop` removes a write; it does not add anything.

**Reversible.** Nothing is written to the disc. Quit the game and it is stock.

---

## Infinite Bullet Time â€” not yet tested

```
ASM Infinite Bullet Time
0 005015B4 60000000
0 005015BC 60000000
0 005015C8 60000000
```

Same pattern as nitro, but the gauge is written back from **three** separate
places, so all three are `nop`-ed. Read live from the console:

```
005015B0  FF806800   fcmpo ...
005015B4  D01F0088   stfs f0, 0x88(r31)   <-- nop'd
005015B8  409D000C   bne  ...
005015BC  D01F0088   stfs f0, 0x88(r31)   <-- nop'd
...
005015C4  FC006890   frsp f0, f13
005015C8  D01F0088   stfs f0, 0x88(r31)   <-- nop'd
```

Every one of those is a `stfs` into the same offset, `0x88(r31)` â€” a repeated
store of the bullet-time gauge. The code covers all three sites, which is what
it should do.

**Why it is not marked verified:** the structure is right, but it has never been
applied. "Looks correct" is not evidence.

---

## âš  Lot + Infinite Money â€” the upstream value appears to be wrong

```
ASM Lot + Infinite Money
0 0013CDEC 91630058
```

**Do not treat this as a working cheat.** The address is correct; the *value* is
not.

The address `0013CDEC` really does sit inside the game's money routine â€” read
live from the console:

```
0013CDE0  7C002214   add   r0, r0, r4      compute new money
0013CDE4  38800002   li    r4, 2
0013CDE8  7C1E07B4   extsw r30, r0         extend to 64-bit
0013CDEC  93C30058   stw   r30, 0x58(r3)   STORE the money
0013CDF0  83E90000   lwz   r31, 0(r9)      load balance
```

But compare the code against the real instruction:

| | instruction | meaning |
|---|---|---|
| the game has | `93C30058` | `stw r30, 0x58(r3)` â€” store the computed money |
| the code writes | `91630058` | `stw r10, 0x58(r3)` â€” store some **other** register |

That is not "money stops decreasing". It is a **different instruction** that
stores whatever happens to be in `r10` into the balance field.

**What happened when it was tried:** the write was applied, nothing observable
changed in game, and the game then froze. That is consistent with the above â€”
this is the one code of the three that writes a *wrong* instruction into live
code. Nitro and bullet time both remove a store; neither does this.

Note also that the address read `93C30058` **both before and after** the write
attempt, including after a reboot â€” the change was not in effect.

**A more plausible value** would be `60000000`, matching the other two codes.
That is a **guess**, and it is **untested**. Do not record it as working.

---

## How to apply these

Runtime codes here go in over **webMAN MOD's PS3MAPI** web interface â€” a plain
HTTP memory write. No Artemis, no cheat engine, no file installed.

### With the tool

```powershell
# what is at each address right now (writes nothing)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/carbon_mem.ps1 -IP <ps3-ip> -Mode status

# show what a code would change (still writes nothing)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/carbon_mem.ps1 -IP <ps3-ip> -Mode poke -Code "ASM Infinite Nitro"

# apply it
powershell -NoProfile -ExecutionPolicy Bypass -File tools/carbon_mem.ps1 -IP <ps3-ip> -Mode poke -Code "ASM Infinite Nitro" -Force
```

The tool:

- **writes nothing** unless you pass `-Force`
- **reads before it writes**, and refuses to write to an address it could not read
- **reads back after writing**, so "success" means the memory changed
- checks the running title, and warns if it is not `BLUS30016`

### By hand

```
read  : GET http://<ps3-ip>/getmem.ps3mapi?proc=<pid>&addr=0x00462CC0&len=4
write : GET http://<ps3-ip>/setmem.ps3mapi?proc=<pid>&addr=00462CC0&oper=0&val=60000000
```

Note the asymmetry: **`getmem` needs `0x` on the address, `setmem` must not
have it.** That is not a typo.

### PS3MAPI gotchas

- `len=` per read is capped at **256 bytes**
- the server is **single-threaded** â€” parallel requests drop
- the PS3 is **big-endian**
- `pid=` changes every launch; get it from the PS3MAPI process list
- after a write, **verify by reading back** â€” a write can silently not land

---

## What "verified" means here, and history so far

The rule for this repo is strict, because the alternative is a page of confident
numbers that do not work:

| result | counts? |
|---|---|
| applied on console, effect seen in game | **yes** |
| applied on console, game froze or crashed | **yes â€” a real finding** |
| "the address looks right" | **no** |
| checked in an emulator | **no** |
| tool printed "success" | **no** |

Two findings came out of doing this honestly:

1. **Nitro works.** First verified code for this title.
2. **The money code's upstream value is wrong** â€” established by reading the
   game's actual instruction and comparing it, not by guessing.

That second one would have stayed hidden if the money code had simply been
marked "doesn't work" and moved past. The reason it is documented in detail is
that it explains a freeze that was otherwise unexplained.

---

## Where everything came from

The three codes are from **jgduff1**, via Aldo's PS3 Artemis codelist database
(mirrored in `bucanero/ArtemisPS3`, `docs/codes/`). The values are unchanged
from upstream â€” including the money value that turned out to be wrong. Nothing
is invented here.

The addresses were **checked against the live game** on a real console before
being marked verified. See `SOURCES.md`.

---


---

## Progress Chart

`
Task Progress
─────────────────────────────────────────────────────

Cheat Research         ████████████████████ 100% ✅
Infinite Nitro         ████████████████████ 100% ✅ (verified)
Infinite Bullet Time   ████████░░░░░░░░░░░░  40% 🔄 (untested)
Lot + Infinite Money   ████████░░░░░░░░░░░░  40% 🔄 (wrong value found)
Build Verification     ████████████████████ 100% ✅ (BLUS30016 01.00)
Tool Development       ████████████████████ 100% ✅ (carbon_mem.ps1)
Verification           ████████████████████ 100% ✅ (verify_mem_tool.py)

Legend: ✅ Done  🔄 In Progress  ⏳ Pending
`

## Files

| path | what it is |
|---|---|
| `tools/carbon_mem.ps1` | PS3MAPI read/write tool. Dry-run by default. |
| `tools/verify_mem_tool.py` | asserts the tool's table still matches the codelist exactly |
| `codelists/Need For Speed Carbon BLUS30016 01.00.ncl` | the codes, in Artemis format |

```
python tools/verify_mem_tool.py
```

fails if the tool and the codelist ever disagree. That check is deliberate: a
table that drifts from the codes will confidently write the wrong value, and
nothing else would catch it.

---


---

## Resources

- [ArtemisPS3 Codelist](https://github.com/bucanero/ArtemisPS3) - Source of original codes
- [PS3MAPI Documentation](https://github.com/bucanero/ps3mapi) - Memory access API
- [webMAN MOD](https://github.com/aldostools/webMAN-MOD) - Console management
- [Drakengard 3 Cheats](https://github.com/richard1222/PS3-Drakengard-3-cheats) - Similar project

## Requirements

- A PS3 running **CFW** with **webMAN MOD** (the PS3MAPI endpoints)
- The **USA** disc, serial `BLUS30016`, app `01.00`
- The game running â€” runtime codes do nothing until it is

## Licence / credit

Codes by **jgduff1**. Repackaged here with the region confirmed and the
verification status recorded. No game data is included or distributed.

