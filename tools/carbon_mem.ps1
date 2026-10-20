<#
================================================================================
 carbon_mem.ps1  --  Need For Speed: Carbon (BLUS30016 01.00) memory tool
================================================================================
   Reads and writes Carbon's runtime codes through webMAN MOD's PS3MAPI web
   interface. No Artemis, no cheat engine, no file installed on the console.

   * RAM ONLY   : nothing on the PS3's disk is touched. Quit = stock game.
   * DRY RUN    : writes nothing unless you pass -Force.
   * READS FIRST: refuses to write an address it could not read.

--------------------------------------------------------------------------------
WHY THIS IS A SEPARATE TOOL FROM THE YAKUZA ONE
--------------------------------------------------------------------------------
Different game, different executable, different addresses. The address tables
are NOT interchangeable and neither are the tools' tables -- each is checked
against its own codelist.

--------------------------------------------------------------------------------
WHAT THESE CODES ACTUALLY DO  (read this)
--------------------------------------------------------------------------------
These are ASM codes. They overwrite the game's own INSTRUCTIONS, not a stored
number. So:

  * "Infinite Money" does NOT set your money to a figure. It stops the game
    from deducting it. The number rises as you trade; it does not jump.
  * All three dollar values written are 60000000 or similar -- these are
    PowerPC instructions (nop / ori), not amounts.

If you were expecting a money box that reads 999,999,999, this is not that.
That is a savepatch job, not a runtime one.

--------------------------------------------------------------------------------
WHAT IS AND IS NOT HERE
--------------------------------------------------------------------------------
In this set:  Infinite Bullet Time, Infinite Money, Infinite Nitro.
NOT here:     Speedbreaker, "unlock everything". Those are not in the upstream
              set for this build. They would have to be found on the console
              (see the read-only finder, if one is provided).

--------------------------------------------------------------------------------
STATUS OF EACH CODE  (do not flatten this)
--------------------------------------------------------------------------------
VERIFIED ON HARDWARE
  Infinite Nitro -- applied to a live race, gauge stopped draining.

UNVERIFIED, and the upstream value LOOKS WRONG
  Lot + Infinite Money -- see the block below before touching this one.

NOT YET TESTED
  Infinite Bullet Time -- the value looks correct (same nop-the-store pattern
  as nitro, and it covers all three store sites), but it has not been applied.

--------------------------------------------------------------------------------
THE MONEY CODE IS PROBABLY WRONG -- read before using it
--------------------------------------------------------------------------------
Upstream says:   0 0013CDEC 91630058
The game has:                     93C30058

Those are different INSTRUCTIONS, not a different value:

    93C30058  =  stw  r30, 0x58(r3)    store the computed money
    91630058  =  stw  r10, 0x58(r3)    store some OTHER register

The address itself is right -- it sits in the real money routine:

    7C002214   add   r0, r0, r4
    38800002   li    r4, 2
    7C1E07B4   extsw r30, r0
    93C30058   stw   r30, 0x58(r3)   <- the store
    83E90000   lwz   r31, 0(r9)

but the upstream VALUE swaps the source register to r10, which holds something
unrelated. Applying it does not make money infinite; it writes junk into the
balance field.

This is the code that was applied once, did nothing, and was followed by a
freeze. That is consistent: it is the only one of the three that writes a WRONG
instruction into live code. Neither nitro nor bullet time does this.

A more plausible value would be 60000000 (nop the store), matching the other
two codes -- but that is a GUESS and has NOT been tested. Do not record it as
working if you try it.

--------------------------------------------------------------------------------
PS3MAPI GOTCHAS  (learned on this console, do not "fix" these)
--------------------------------------------------------------------------------
  1. getmem addr= NEEDS the 0x prefix.
  2. setmem addr= MUST NOT have the 0x prefix.
  3. len= per read is capped at 256 bytes.
  4. The server is single-threaded -- requests must be sequential.
  5. The PS3 is BIG-ENDIAN. A value written as hex is read back byte-ordered.
  6. pid= changes every launch. It is scraped, never hardcoded.

--------------------------------------------------------------------------------
USAGE
--------------------------------------------------------------------------------
  # what is running, and what is at each address right now (writes nothing)
  powershell -NoProfile -ExecutionPolicy Bypass -File carbon_mem.ps1 -IP <ip> -Mode status

  # show exactly what a code would change (still writes nothing)
  powershell -NoProfile -ExecutionPolicy Bypass -File carbon_mem.ps1 -IP <ip> -Mode poke -Code "ASM Lot + Infinite Money"

  # actually write it
  powershell -NoProfile -ExecutionPolicy Bypass -File carbon_mem.ps1 -IP <ip> -Mode poke -Code "ASM Lot + Infinite Money" -Force

  # read one address by hand
  powershell -NoProfile -ExecutionPolicy Bypass -File carbon_mem.ps1 -IP <ip> -Mode read -Addr 0013CDEC

  # list the codes this tool knows
  powershell -NoProfile -ExecutionPolicy Bypass -File carbon_mem.ps1 -Mode list
#>

param(
    [string] $IP = "PS3_IP_HERE",

    [ValidateSet("status","poke","read","list")] [string] $Mode = "status",

    # which code to apply (must match a name in the table below)
    [string] $Code = "",

    # only for -Mode read
    [string] $Addr = "",

    # without this, nothing is ever written
    [switch] $Force
)

$ErrorActionPreference = "Stop"

$TITLE_ID   = "BLUS30016"
$READ_CAP   = 256

# ---------------------------------------------------------------------------
# THE CODE TABLE
# Mirrors codelists\Need For Speed Carbon BLUS30016 01.00.ncl exactly.
# tools\verify_mem_tool.py asserts these two agree. If you edit one, the check
# fails until you edit the other -- that is the point.
# ---------------------------------------------------------------------------
$CODES = @(
    @{
        Name  = "ASM Infinite Bullet Time"
        Type  = "ASM"
        Note  = "stops the bullet-time gauge draining (nops 3 store sites)"
        Writes = @(
            @{ Addr = "005015B4"; Value = "60000000" },
            @{ Addr = "005015BC"; Value = "60000000" },
            @{ Addr = "005015C8"; Value = "60000000" }
        )
    },
    @{
        Name  = "ASM Lot + Infinite Money"
        Type  = "ASM"
        Note  = "UNVERIFIED -- see the warning in carbon_mem.ps1. Upstream value looks wrong."
        Writes = @(
            @{ Addr = "0013CDEC"; Value = "91630058" }
        )
    },
    @{
        Name  = "ASM Infinite Nitro"
        Type  = "ASM"
        Note  = "VERIFIED on hardware -- stops the nitro gauge draining"
        Writes = @(
            @{ Addr = "00462CC0"; Value = "60000000" }
        )
    }
)

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
function Show([string]$m, [string]$c = "Gray") { Write-Host $m -ForegroundColor $c }

function Invoke-Ps3([string]$path) {
    return ((curl.exe -s --max-time 20 "http://$IP/$path") -join "")
}

function Get-Pid {
    if ($IP -eq "PS3_IP_HERE" -or -not $IP) {
        Show "  No -IP given. Pass the PS3's address, e.g. -IP <your-ps3-ip>" Red
        exit 1
    }
    $cpursx = Invoke-Ps3 "cpursx.ps3?/sman.ps3"
    if (-not $cpursx -or $cpursx -notmatch "wMAN|webMAN") {
        Show "  No webMAN MOD at $IP -- is the PS3 on and on the network?" Red
        exit 1
    }
    # the running title's pid appears as pid=xxxxxxxx
    if ($cpursx -match "pid=([0-9A-Fa-f]{8})") {
        $p = "0x" + $matches[1]
        if ($p -eq "0x00000000") {
            Show "  No game running (webMAN is up, but nothing is loaded)." Red
            Show "  Launch Need For Speed: Carbon first." Yellow
            exit 1
        }
        if ($cpursx -notmatch $TITLE_ID) {
            Show "  WARNING: the running title does not look like $TITLE_ID." Yellow
            Show "  These addresses are for $TITLE_ID only. Continuing could" Yellow
            Show "  write into the wrong game's memory." Yellow
            if (-not $Force) {
                Show "  Refusing to continue without -Force." Red
                exit 1
            }
        }
        return $p
    }
    Show "  Could not find a game pid on the page. Is a game running?" Red
    exit 1
}

# Read bytes; returns byte[] or $null. NOTE getmem needs 0x on the address.
function Get-Bytes([string]$hexAddr, [int]$len, [string]$proc) {
    $r = Invoke-Ps3 "getmem.ps3mapi?proc=$proc&addr=0x$hexAddr&len=$len"
    $m = [regex]::Match($r, [regex]::Escape($hexAddr) + "\s+((?:[0-9A-Fa-f]{2}\s+){1,})")
    if (-not $m.Success) { return $null }
    $hex = ($m.Groups[1].Value.Trim() -replace '\s+', '')
    if ($hex.Length -lt 2) { return $null }
    $n = [int]($hex.Length / 2)
    $out = New-Object byte[] $n
    for ($i = 0; $i -lt $n; $i++) { $out[$i] = [Convert]::ToByte($hex.Substring($i*2, 2), 16) }
    return $out
}

# Write ONE 32-bit word. NOTE setmem must NOT have 0x on the address.
function Set-Word([string]$hexAddr, [string]$value, [string]$proc) {
    $r = Invoke-Ps3 "setmem.ps3mapi?proc=$proc&addr=$hexAddr&oper=0&val=$value"
    return $r
}

# Render bytes as the big-endian word the PS3 would see.
function To-BeWord([byte[]]$b) {
    if ($null -eq $b -or $b.Length -lt 4) { return $null }
    return (($b[0].ToString("X2")) + $b[1].ToString("X2") + $b[2].ToString("X2") + $b[3].ToString("X2"))
}

# ---------------------------------------------------------------------------
Show ""
Show "==============================================================================" Cyan
Show "  Need For Speed: Carbon  $TITLE_ID 01.00   --  memory tool   PS3MAPI"          Cyan
Show "==============================================================================" Cyan
Show ""

if ($Mode -eq "list") {
    Show "  Codes this tool knows:" Cyan
    Show ""
    foreach ($c in $CODES) {
        $n = $c.Writes.Count
        Show ("    {0}" -f $c.Name) Green
        Show ("        {0}  --  {1} write(s)" -f $c.Type, $n) DarkGray
        Show ("        {0}" -f $c.Note) DarkGray
        foreach ($w in $c.Writes) { Show ("          {0} <- {1}" -f $w.Addr, $w.Value) DarkGray }
        Show ""
    }
    exit 0
}

# ---- console required from here -------------------------------------------
$proc = Get-Pid
Show ("  webMAN MOD at {0}" -f $IP) Green
Show ("  game pid   : {0}" -f $proc) Green
Show ""

if ($Mode -eq "read") {
    if (-not $Addr) { Show "  -Mode read needs -Addr <hex>, e.g. -Addr 0013CDEC" Red; exit 1 }
    $a = ($Addr -replace '^0x','').ToUpper()
    if ($a -notmatch '^[0-9A-F]{1,8}$') { Show "  -Addr must be hex, no 0x needed" Red; exit 1 }
    $a = $a.PadLeft(8, '0')
    $b = Get-Bytes $a 16 $proc
    if ($null -eq $b) { Show ("  could not read 0x{0}" -f $a) Red; exit 1 }
    $bytes = ($b | ForEach-Object { $_.ToString("X2") }) -join " "
    Show ("  0x{0} : {1}" -f $a, $bytes) Gray
    Show ("  word 0 : {0}   (big-endian)" -f (To-BeWord $b)) Green
    Show ""
    exit 0
}

if ($Mode -eq "status" -or $Mode -eq "poke") {
    # decide which codes to look at
    $targets = @()
    if ($Mode -eq "poke") {
        if (-not $Code) { Show "  -Mode poke needs -Code `"<name>`"" Red; Show "  Run -Mode list to see the names." Yellow; exit 1 }
        $targets = $CODES | Where-Object { $_.Name -eq $Code }
        if (-not $targets) {
            Show ("  No code named `"{0}`" in the table." -f $Code) Red
            Show "  Run -Mode list to see the names." Yellow
            exit 1
        }
    } else {
        $targets = $CODES
    }

    foreach ($c in $targets) {
        Show ("  [{0}]" -f $c.Name) Cyan
        Show ("      {0}  --  {1}" -f $c.Type, $c.Note) DarkGray
        Show ""

        $allReadable = $true
        foreach ($w in $c.Writes) {
            $b = Get-Bytes $w.Addr 4 $proc
            $cur = To-BeWord $b
            if ($null -eq $cur) {
                Show ("      0x{0}  : (could not read)" -f $w.Addr) Red
                $allReadable = $false
            } else {
                $same = ($cur -eq $w.Value)
                $mark = if ($same) { "already applied" } else { "would change" }
                $col  = if ($same) { "DarkGray" } else { "Yellow" }
                Show ("      0x{0}  : now {1}   want {2}   ({3})" -f $w.Addr, $cur, $w.Value, $mark) $col
            }
        }
        Show ""

        if ($Mode -eq "poke") {
            if (-not $allReadable) {
                Show "      REFUSING to write: an address could not be read first." Red
                Show "      Writing blind to a hung game is how you lose a save." DarkGray
                Show ""
                continue
            }
            if (-not $Force) {
                Show "      DRY RUN -- nothing written. Add -Force to apply." Yellow
                Show ""
                continue
            }
            $ok = 0
            foreach ($w in $c.Writes) {
                $res = Set-Word $w.Addr $w.Value $proc
                $after = To-BeWord (Get-Bytes $w.Addr 4 $proc)
                if ($after -eq $w.Value) {
                    Show ("      wrote 0x{0} = {1}   verified by read-back" -f $w.Addr, $w.Value) Green
                    $ok++
                } else {
                    Show ("      wrote 0x{0} = {1}   READ-BACK SAYS {2}" -f $w.Addr, $w.Value, $after) Red
                }
            }
            Show ""
            Show ("      {0}/{1} address(es) confirmed written." -f $ok, $c.Writes.Count) $(if ($ok -eq $c.Writes.Count) { "Green" } else { "Yellow" })
            Show "      Now LOOK AT THE SCREEN -- a confirmed write is not a confirmed cheat." DarkGray
            Show ""
        }
    }
    exit 0
}
