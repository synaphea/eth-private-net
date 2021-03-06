Param(
  [string] $CMD,
  [string] $IDENTITY1,
  [string] $IDENTITY2
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

$IDENTITIES = @("alice", "bob", "lily")
$FLAGS = "--networkid=8888 --preload=identities.js"
$DEV_FLAGS = "--nodiscover  --verbosity=4"

$version = "1.7.1-05101641"

$BASE_PORT = 40300
$BASE_RPC_PORT = 8100

$SCRIPT = $MyInvocation.MyCommand.Name

$USAGE = "Name:
    $SCRIPT - Command line utility for creating and running a three node Ethereum private net

    Network comes with three identities at the following addresses:

        alice: 0xdda6ef2ff259928c561b2d30f0cad2c2736ce8b6 (initialized with 1 Ether)
        bob:   0x8691bf25ce4a56b15c1f99c944dc948269031801 (initialized with 1 Ether)
        lily:  0xb1b6a66a410edc72473d92decb3772bad863e243

Usage:
    $SCRIPT command [command options]

Commands:
    setup      Download geth client
    init       Initialize private network from genesis block in genesis.json
    clean      Destroy all blockchain history, resetting to pristine state
    start      Start a running ethereum node on the network (example: 'start alice')
    connect    Connect two running nodes as peers (example: 'connect alice bob')
    help       Print this help message

Author:
    George Theofilis (@theofilis), Synaphea
    https://github.com/vincentchu/eth-private-net
"

function GetArch {
  switch ($ENV:PROCESSOR_ARCHITECTURE) {
    "AMD64" {"amd64"}
    "IA64" {"amd64"}
    "x86" {"386"}
  }
}

function DownloadFile {
  param($Url, $Output)

  $start_time = Get-Date
  Write-Output "Start downloading from $Url"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $wc = New-Object System.Net.WebClient
  $wc.DownloadFile($url, $output)
  Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

function Unzip {
  param([string]$zipfile, [string]$outpath)
  Write-Output "Unzip geth tools"
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function Setup {
  $arch = GetArch
  $filename = "geth-alltools-windows-$arch-$version"
  $url = "https://gethstore.blob.core.windows.net/builds/$filename.zip"

  if (Test-Path "$PSScriptRoot\bin" ) {
    Remove-Item -Force -Confirm:$false -Recurse "bin" | Out-Null
  }

  New-Item -path . -name "bin" -itemtype directory | Out-Null
  $output = "$PSScriptRoot\bin\geth.zip"
  DownloadFile $url $output

  Unzip $output "$PSScriptRoot\bin"
  Remove-Item -Force -Confirm:$false $output | Out-Null
  Move-Item -Path "$PSScriptRoot\bin\$filename\*" .\bin | Out-Null
  Remove-Item -Force -Confirm:$false "$PSScriptRoot\bin\$filename" | Out-Null
}

function Init {
  Foreach ($IDENTITY in $IDENTITIES) {
    Write-Output  "Initializing genesis block for $IDENTITY"
    $args = "$FLAGS --datadir=.\$IDENTITY"
    Invoke-Expression ".\bin\geth.exe $args init genesis.json"
  }
}

function Clean {
  Foreach ($IDENTITY in $IDENTITIES) {
    Write-Output  "Cleaning geth/ directory from $IDENTITY"
    Remove-Item -Force -Confirm:$false -Recurse "$PSScriptRoot\$IDENTITY\geth" | Out-Null
  }
}

function GetOffset {
  param([string] $IDENTITY)

  switch ($IDENTITY) {
      "alice" {
        $OFFSET=1
       }
      "bob" {
        $OFFSET=2
       }
      "lily" {
        $OFFSET=3
       }
  }

  return $OFFSET
}

function Start-Node {
  param([string] $IDENTITY)

  if (!$IDENTITY) {
    Write-Host "No identity specified. Identity must be one of: ($IDENTITIES)"
    exit -1
  }

  $OFFSET = GetOffset $IDENTITY

  $PORT=$BASE_PORT + $OFFSET
  $RPC_PORT=$BASE_RPC_PORT + $OFFSET

  Write-Output "Starting node for $IDENTITY on port: $PORT, RPC port: $RPC_PORT. Console logs sent to ./$IDENTITY/console.log"
  $args = "--port $PORT --rpc --rpcapi admin,eth,web3 --rpcport $RPC_PORT --ipcpath ./$IDENTITY/geth.ipc --datadir ./$IDENTITY/ $FLAGS $DEV_FLAGS"
  Invoke-Expression "./bin/geth.exe $args console 2>> ./$IDENTITY/console.log"
}

function Connect-Node {
  param([string] $IDENTITY1, [string] $IDENTITY2)
  Write-Output "Connect geth from $IDENTITY1 to $IDENTITY2"
  $ENODE=ExecOnNode 'admin.nodeInfo.enode' $IDENTITY1
  $CONNECT_JS="admin.addPeer($ENODE)"
  Write-Output  "$CONNECT_JS"
  $CONNECT_JS = 'admin.addPeer("enode://9045fb138d3de7f1314229096a4d208a7827d18f5b7df55a18015e7c7a3be9d1e8de120d2ac58b03965ef6a2196597cd8ee697da551fd413a40cba4b8454815f@[::]:40303?discport=0")'
  ExecOnNode $CONNECT_JS $IDENTITY2
}

function ExecOnNode {
  param($Exec, $Identity)

  $OFFSET = GetOffset $IDENTITY
  $RPC_PORT=$BASE_RPC_PORT + $OFFSET
  Invoke-Expression "./bin/geth --exec='$Exec' attach http://localhost:$RPC_PORT"
}

switch ($CMD) {
  "setup" {
    Setup
  }
  "init" {
    Init
  }
  "clean" {
    Clean
  }
  "start" {
    Start-Node $IDENTITY1
  }
  "connect" {
    Connect-Node $IDENTITY1 $IDENTITY2
  }
  "help" {
    Write-Output $USAGE
  }
}