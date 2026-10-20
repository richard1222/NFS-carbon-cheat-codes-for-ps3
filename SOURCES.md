# Sources

## The codes

All three Carbon codes are by **jgduff1**. They come from Aldo's PS3 Artemis
codelist database, which is mirrored in the public repo
[`bucanero/ArtemisPS3`](https://github.com/bucanero/ArtemisPS3) under
`docs/codes/`.

The file used:

```
docs/codes/Need For Speed Carbon BLUS30016 v01.00.ncl     265 bytes
```

**The values here are unchanged from upstream**, including the money value that
turned out to be wrong. Nothing was edited to make it look better. Where the
upstream value is suspected wrong, the file says so and the tool warns — but the
byte itself is left as published.

### Why `BLUS30016` and not another file

The upstream repo has several Carbon entries:

| file | addresses |
|---|---|
| `Need For Speed Carbon BLUS30016 v01.00.ncl` | **used here** |
| `Need For Speed Carbon BLES00020 v01.00.ncl` | different |
| `Need For Speed Carbon 01.00.ncl` | identical to the BLES00020 set |
| `Need For Speed Carbono BLES00020 v01.00.ncl` | identical to the BLES00020 set |

The USA and Europe sets genuinely differ:

| code | USA (`BLUS30016`) | Europe (`BLES00020`) |
|---|---|---|
| Infinite Bullet Time | `005015B4`, `005015BC`, `005015C8` | `00504060`, `00504068`, `00504074` |
| Lot + Infinite Money | `0013CDEC` | `0013DF88` |
| Infinite Nitro | `00462CC0` | `00465208` |

So these are build-specific addresses, not relabels. Using the Europe set on a
USA disc would write into the wrong place.

The USA file was chosen because the disc was **confirmed** to be `BLUS30016`
app `01.00`.

## Confirming the disc

The serial and version were read from the game's own `PARAM.SFO`, taken from the
installed game folder on the console:

| field | value |
|---|---|
| `TITLE_ID` | `BLUS30016` |
| `TITLE` | Need for Speed: Carbon |
| `VERSION` | `01.00` |
| `CATEGORY` | `DG` |
| `PS3_SYSTEM_VER` | `01.0200` |

This is a measurement, not an assumption. The region matters because the address
sets differ.

## How the codes were checked

The addresses were read **from the running game on a real console** over
PS3MAPI, and the bytes compared against what each code claims. That is how the
money problem was found — the game's instruction at `0013CDEC` is `93C30058`,
and the code writes `91630058`.

What each check found:

| code | game's instruction at the address | verdict |
|---|---|---|
| Infinite Nitro | `D01F0120` = `stfs f0, 0x120(r31)` | code's `nop` is correct — **verified working** |
| Infinite Bullet Time | `D01F0088` ×3 = `stfs f0, 0x88(r31)` | code's `nop` is correct — **untested** |
| Lot + Infinite Money | `93C30058` = `stw r30, 0x58(r3)` | code writes `91630058`, a **different instruction** |

The surrounding instructions were read too, to confirm each address sits in the
routine it claims to — e.g. the money address is immediately preceded by an
`add` and an `extsw` that compute the new balance.

## What is *not* claimed

- The EBOOT on disc is encrypted, so the addresses could **not** be checked
  against the binary off-console. Everything above was read from live memory.
- Bullet time has not been applied. Its structure matches the verified nitro
  code, but that is an argument, not evidence.
- The suggested replacement money value (`60000000`) is a **guess** and is
  **untested**.

## No game data

No game files are included or distributed. You need your own legitimate copy of
the USA disc. Nothing here patches the disc or the save file — the codes are
runtime memory writes, and quitting the game restores stock behaviour.
