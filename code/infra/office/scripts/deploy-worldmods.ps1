param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [Parameter(Mandatory = $true)]
    [string]$Zone,

    [Parameter(Mandatory = $true)]
    [string]$InstanceName,

    [Parameter(Mandatory = $true)]
    [string]$SshUser,

    [Parameter(Mandatory = $true)]
    [string]$WorldDiskDevice,

    [Parameter(Mandatory = $true)]
    [string]$AccessModPath,

    [Parameter(Mandatory = $true)]
    [string]$TriviumModPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$remote = "$SshUser@$InstanceName"
$instanceIp = (& gcloud compute instances describe $InstanceName "--project=$ProjectId" "--zone=$Zone" "--format=get(networkInterfaces[0].accessConfigs[0].natIP)").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($instanceIp)) {
    throw "Failed to resolve the current public IP for the office VM."
}

$puttyHostKeysPath = 'HKCU:\Software\SimonTatham\PuTTY\SshHostKeys'
if (Test-Path $puttyHostKeysPath) {
    $hostKeyProperties = (Get-Item $puttyHostKeysPath).Property | Where-Object { $_ -like "*:$instanceIp" }
    foreach ($propertyName in $hostKeyProperties) {
        Remove-ItemProperty -Path $puttyHostKeysPath -Name $propertyName -ErrorAction SilentlyContinue
    }
}

function Wait-ForSshAccess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IpAddress,

        [int]$TimeoutSeconds = 600
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $client = [System.Net.Sockets.TcpClient]::new()
        try {
            $asyncResult = $client.BeginConnect($IpAddress, 22, $null, $null)
            if ($asyncResult.AsyncWaitHandle.WaitOne(5000) -and $client.Connected) {
                $client.EndConnect($asyncResult)
                return
            }
        }
        catch {
        }
        finally {
            $client.Dispose()
        }

        Start-Sleep -Seconds 5
    }

    throw "The office VM did not become reachable over SSH within $TimeoutSeconds seconds."
}

$remoteScriptPath = Join-Path ([System.IO.Path]::GetTempPath()) 'trivium-deploy-worldmods.sh'
$worldDataRoot = '/srv/trivium-office-data'
$worldDir = "$worldDataRoot/world"
$worldmodsDir = "$worldDir/worldmods"
$legacyWorldDir = '/opt/luanti/worlds/office'
$remoteScriptContent = @(
    '#!/bin/bash'
    'set -euo pipefail'
    "WORLD_DISK_DEVICE='$WorldDiskDevice'"
    "WORLD_DATA_ROOT='$worldDataRoot'"
    "WORLD_DIR='$worldDir'"
    "WORLDMODS_DIR='$worldmodsDir'"
    "LEGACY_WORLD_DIR='$legacyWorldDir'"
    "SERVICE_FILE='/etc/systemd/system/trivium-office.service'"
    'while true; do startup_state="$(systemctl is-active google-startup-scripts.service || true)"; if [ "$startup_state" != "active" ] && [ "$startup_state" != "activating" ] && [ "$startup_state" != "reloading" ]; then break; fi; sleep 5; done'
    'if ! systemctl cat trivium-office.service >/dev/null 2>&1; then echo "trivium-office.service was not created by startup bootstrap" >&2; exit 1; fi'
    'if [ ! -b "$WORLD_DISK_DEVICE" ]; then echo "Expected world disk device $WORLD_DISK_DEVICE was not found" >&2; exit 1; fi'
    'if ! blkid "$WORLD_DISK_DEVICE" >/dev/null 2>&1; then mkfs.ext4 -F "$WORLD_DISK_DEVICE"; fi'
    'install -d -m 0755 "$WORLD_DATA_ROOT"'
    'world_disk_uuid="$(blkid -s UUID -o value "$WORLD_DISK_DEVICE")"'
    'if ! grep -q "$world_disk_uuid" /etc/fstab; then echo "UUID=$world_disk_uuid $WORLD_DATA_ROOT ext4 defaults,nofail,discard 0 2" >> /etc/fstab; fi'
    'if systemctl is-active --quiet trivium-office; then systemctl stop trivium-office; fi'
    'if ! mountpoint -q "$WORLD_DATA_ROOT"; then mount "$WORLD_DATA_ROOT"; fi'
    'install -d -o luanti -g luanti "$WORLD_DATA_ROOT" "$WORLD_DATA_ROOT/worlds"'
    'if [ -d "$LEGACY_WORLD_DIR" ] && [ ! -e "$WORLD_DIR/world.mt" ]; then cp -a "$LEGACY_WORLD_DIR" "$WORLD_DIR"; fi'
    'install -d -o luanti -g luanti "$WORLDMODS_DIR"'
    'sed -i "s#--world /opt/luanti/worlds/office#--world $WORLD_DIR#g" "$SERVICE_FILE"'
    'rm -rf "$WORLDMODS_DIR/trivium_access"'
    'rm -rf "$WORLDMODS_DIR/trivium"'
    'cp -R /tmp/trivium_access "$WORLDMODS_DIR/"'
    'cp -R /tmp/trivium "$WORLDMODS_DIR/"'
    'chown -R luanti:luanti "$WORLD_DATA_ROOT"'
    'systemctl daemon-reload'
    'systemctl restart trivium-office'
    'systemctl is-active trivium-office'
) -join "`n"

[System.IO.File]::WriteAllText(
    $remoteScriptPath,
    $remoteScriptContent,
    [System.Text.UTF8Encoding]::new($false)
)

try {
    Wait-ForSshAccess -IpAddress $instanceIp

    'y' | & gcloud compute scp --quiet --recurse $AccessModPath "${remote}:/tmp/" "--project=$ProjectId" "--zone=$Zone" '--strict-host-key-checking=no'
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to copy trivium_access to the office VM."
    }

    'y' | & gcloud compute scp --quiet --recurse $TriviumModPath "${remote}:/tmp/" "--project=$ProjectId" "--zone=$Zone" '--strict-host-key-checking=no'
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to copy trivium to the office VM."
    }

    'y' | & gcloud compute scp --quiet $remoteScriptPath "${remote}:/tmp/trivium-deploy-worldmods.sh" "--project=$ProjectId" "--zone=$Zone" '--strict-host-key-checking=no'
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to copy deploy script to the office VM."
    }

    'y' | & gcloud compute ssh $remote "--project=$ProjectId" "--zone=$Zone" '--strict-host-key-checking=no' "--command=sudo bash /tmp/trivium-deploy-worldmods.sh"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to deploy worldmods on the office VM."
    }
}
finally {
    Remove-Item $remoteScriptPath -ErrorAction SilentlyContinue
}