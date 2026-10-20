# Need For Speed: Carbon -- USA (BLUS30016) app 01.00
#
# Runtime codelist. Source: bucanero/ArtemisPS3, docs/codes/
#   "Need For Speed Carbon BLUS30016 v01.00.ncl"  (265 bytes)
#   author: jgduff1
#
# USA only. The Europe file (BLES00020) has DIFFERENT addresses:
#   money  EU 0013DF88   vs   US 0013CDEC
#   nitro  EU 00465208   vs   US 00462CC0
# Do not mix them.
#
# Confirmed from this console's own PARAM.SFO:
#   TITLE_ID = BLUS30016   VERSION = 01.00
#
# NOTE ON CODE TYPE
# These are ASM codes -- they overwrite the game's own INSTRUCTIONS, not a
# stored number. "Infinite Money" does not set the money figure; it stops the
# game from deducting it. Expect the number to climb as you trade, not to jump
# to a fixed value.
#
# STATUS (do not flatten this)
#   Infinite Nitro      -- VERIFIED on hardware (applied to a live race,
#                          gauge stopped draining)
#   Infinite Bullet Time-- not yet tested; value looks correct
#   Lot + Infinite Money-- NOT trusted. The upstream value is a different
#                          INSTRUCTION from what the game has (91630058 vs
#                          93C30058) and swaps the source register. See the
#                          comment inside the block below.

Alternative Names
0
PARAM.SFO
/*
Need For Speed Carbon
*/
#
ASM Infinite Bullet Time
0
jgduff1
0 005015B4 60000000
0 005015BC 60000000
0 005015C8 60000000
#
ASM Lot + Infinite Money
0
jgduff1
# Upstream says 91630058. The game actually has 93C30058 at this address.
#   game : 93C30058 = stw r30, 0x58(r3)   store the computed money
#   code : 91630058 = stw r10, 0x58(r3)   store an unrelated register
# The address is right (it is the real money routine) but the value writes a
# WRONG instruction. Left as upstream so this file stays a faithful copy;
# the tool warns about it separately.
0 0013CDEC 91630058
#
ASM Infinite Nitro
0
jgduff1
0 00462CC0 60000000
#
