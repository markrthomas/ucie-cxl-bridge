# Run Icarus Verilog simulation from the test/ directory (Windows-friendly).
# Requires: iverilog and vvp on PATH (e.g. OSS CAD Suite or a local install).
# Usage: .\run_sim.ps1           — default + stress (same as make)
#        .\run_sim.ps1 +stress  — include heavy stress phase

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$build = Join-Path $here "build"
New-Item -ItemType Directory -Force -Path $build | Out-Null

$root = Split-Path $here -Parent
$src = Join-Path $root "src"
$out = Join-Path $build "tb.out"
$sources = @(
  (Join-Path $src "sync_fifo.v"),
  (Join-Path $src "cxl_ucie_bridge.v"),
  (Join-Path $src "cxl_ucie_bridge_chk.v"),
  (Join-Path $src "tb_cxl_ucie_bridge.v")
)

& iverilog -g2005-sv -o $out @sources
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$vvpArgs = $args
if ($vvpArgs.Count -eq 0) {
  & vvp $out
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & vvp $out "+stress"
} else {
  & vvp $out @vvpArgs
}

exit $LASTEXITCODE
