# Run Icarus Verilog simulation from the test/ directory (Windows-friendly).
# Requires: iverilog and vvp on PATH (e.g. OSS CAD Suite or a local install).
# Usage: .\run_sim.ps1           — default + stress (same as make)
#        .\run_sim.ps1 +stress  — only the args you pass to vvp
#        .\run_sim.ps1 lint     — Verilator lint (repo RTL, no TB)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$root = Split-Path $here -Parent

if ($args.Count -ge 1 -and ($args[0] -eq "lint" -or $args[0] -eq "-lint")) {
  & verilator --lint-only -Wall -top-module cxl_ucie_bridge `
    (Join-Path $root "src\sync_fifo.v") `
    (Join-Path $root "src\cxl_ucie_bridge.v")
  exit $LASTEXITCODE
}

$build = Join-Path $here "build"
New-Item -ItemType Directory -Force -Path $build | Out-Null

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
