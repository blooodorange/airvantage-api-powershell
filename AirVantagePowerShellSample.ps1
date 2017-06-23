# AirVantagePowerShellSample.ps1
# Created by Martin Walder | martin ( at ) waldma.org
# Version 1.2
# https://doc.airvantage.net/av/howto/cloud/gettingstarted_api/
# https://doc.airvantage.net/av/reference/cloud/API/

# AirVantage credentials

$AVUsername = ""
$AVPassword = ""

# AirVantage datacenter -> https://na.airvantage.net (North America), https://eu.airvantage.net (EMEA)

$AVDatacenter = "https://na.airvantage.net"

# API client settings -> https://na.airvantage.net/develop/api/clients

$AVClientId = ""
$AVSecretKey = ""

# Prerequisites: existing report with desired DataIDs (report <-> firmware dependency!)
# Use Get-AirVantageReports to get correct DataIDs
# Get-AirVantageReports -AVDatacenter $AVDatacenter -AVAccessToken $AVAccessToken -> Configuration

$AVSystemDataID_DeviceUptime = "lwm2m.10250.0.272" # -> Revision 4.8.0.021
$AVSystemDataID_CurrentWANTimeinUse = "lwm2m.10250.0.5046" # -> Revision 4.8.0.021

# Function Connect-AirVantage - OAUTH authorization code flow

Function Connect-AirVantage(){
    param(
        [Parameter(Mandatory=$true)]
        $AVDatacenter,
        [Parameter(Mandatory=$true)]
        $AVUsername,
        [Parameter(Mandatory=$true)]
        $AVPassword,
        [Parameter(Mandatory=$true)]
        $AVClientId,
        [Parameter(Mandatory=$true)]
        $AVSecretKey
    )
    $Parameters = @{
        grant_type = "password"
        username = $AVUsername
        password = $AVPassword
        client_id = $AVClientId
        client_secret = $AVSecretKey
    }
    $AVAccessToken = ((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/oauth/token" -Body $Parameters).Content | ConvertFrom-Json).access_token
    if ($AVAccessToken -ne $null){
        Write-Host -ForegroundColor Yellow "Login successful"
        return $AVAccessToken
    }
}

# Function Disconnect-AirVantage

Function Disconnect-AirVantage(){
    param(
        [Parameter(Mandatory=$true)]
        $AVDatacenter,
        [Parameter(Mandatory=$true)]
        $AVAccessToken
    )
    if ((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/oauth/expire?access_token=$($AVAccessToken)?access_token=$AVAccessToken").Content -eq '"logout.successful"'){
        Write-Host -ForegroundColor Yellow "Logout successful"
    }
}

# Function Get-AirVantageReports

Function Get-AirVantageReports(){
    param(
        [Parameter(Mandatory=$true)]
        $AVDatacenter,
        [Parameter(Mandatory=$true)]
        $AVAccessToken
    )
    $AVReports = ((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/v1/datasets?fields=uid,name,configuration&access_token=$AVAccessToken").Content | ConvertFrom-Json).items | Select @{Name="Name";Expression={$_.name}}, @{Name="UID";Expression={$_.uid}}, @{Name="Configuration";Expression={$_.configuration}} | fl
    Write-Host -ForegroundColor Yellow "Available reports:"
    return $AVReports
}

# Function Retrieve-AirVantageSystemData

Function Retrieve-AirVantageSystemData(){
    param(
        [Parameter(Mandatory=$true)]
        $AVDatacenter,
        [Parameter(Mandatory=$true)]
        $AVSystemUID,
        [Parameter(Mandatory=$true)]
        $AVSystemDataID,
        [Parameter(Mandatory=$true)]
        $AVAccessToken
    )
    $Parameters = [ordered]@{
        systems = @{
            uids = @(
                $AVSystemUID
            )
        }
        data = @(
            $AVSystemDataID
        )
    }
    $JSON = $Parameters | ConvertTo-Json
    $AVOperation = Invoke-WebRequest -Method Post -Uri "$AVDatacenter/api/v1/operations/systems/data/retrieve?access_token=$AVAccessToken" -ContentType "application/json" -Body $JSON | ConvertFrom-Json
    Write-Host -ForegroundColor Yellow "Retrieving data..."
    return $AVOperation
}

# Function List-AirVantageSystemData

Function List-AirVantageSystemData(){
    param(
        [Parameter(Mandatory=$true)]
        $AVDatacenter,
        [Parameter(Mandatory=$true)]
        $AVSystemUID,
        [Parameter(Mandatory=$true)]
        $AVSystemDataID,
        [Parameter(Mandatory=$true)]
        $AVAccessToken
    )
    $AVSystemData = (Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/v1/systems/$AVSystemUID/data?ids=$AVSystemDataID&access_token=$AVAccessToken").Content | ConvertFrom-Json
    return $AVSystemData.$AVSystemDataID
}

# Function Get-AirVantageOperation

Function Get-AirVantageOperation(){
    param(
        [Parameter(Mandatory=$true)]
        $AVDatacenter,
        [Parameter(Mandatory=$true)]
        $AVOperationUID,
        [Parameter(Mandatory=$true)]
        $AVAccessToken
    )
    (Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/v1/operations/$($AVOperationUID)?access_token=$AVAccessToken").Content | ConvertFrom-Json | Select @{Name="Status";Expression={$_.state}}

}

# Function ConvertFrom-UNIXTimestamp

Function ConvertFrom-UNIXTimestamp(){
    param(
        [Parameter(Mandatory=$true)]
        $Timestamp
    )
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($Timestamp /1000))
}

# Function List-AirVantageSystems

Function List-AirVantageSystems(){
    param(
        [Parameter(Mandatory=$true)]
        $AVDatacenter,
        [Parameter(Mandatory=$true)]
        $AVAccessToken
    )
    $AVSystems += (((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/v1/systems?access_token=$AVAccessToken").Content | ConvertFrom-Json).items).name
    return $AVSystems
}

# Function Get-AirVantageSystem

Function Get-AirVantageSystem(){
    param(
        [Parameter(Mandatory=$true)]
        $AVDatacenter,
        [Parameter(Mandatory=$true)]
        $AVSystemName,
        [Parameter(Mandatory=$true)]
        $AVAccessToken
    )
    ((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/v1/systems?name=$($AVSystemName)&access_token=$AVAccessToken").Content | ConvertFrom-Json).items
}

$AVAccessToken = Connect-AirVantage -AVDatacenter $AVDatacenter -AVUsername $AVUsername -AVPassword $AVPassword -AVClientId $AVClientId -AVSecretKey $AVSecretKey

Write-Host -ForegroundColor Yellow "Registered systems:"
List-AirVantageSystems -AVDatacenter $AVDatacenter -AVAccessToken $AVAccessToken

$AVSystemName = Read-Host "Enter system's name (not case sensitive)"
$PingCount = Read-Host "Enter the number of pings you want to send to the gateway"

Write-Host -ForegroundColor Yellow "Collecting device information..."
$AVOutput = Get-AirVantageSystem -AVDatacenter $AVDatacenter -AVSystemName $AVSystemName -AVAccessToken $AVAccessToken

$AVSystemUID = $AVOutput.uid

$AVOperationUID_CurrentWANTimeinUse = (Retrieve-AirVantageSystemData -AVDatacenter $AVDatacenter -AVSystemUID $AVSystemUID -AVSystemDataID $AVSystemDataID_CurrentWANTimeinUse -AVAccessToken $AVAccessToken).operation

do {
    Get-AirVantageOperation -AVDatacenter $AVDatacenter -AVOperationUID $AVOperationUID_CurrentWANTimeinUse -AVAccessToken $AVAccessToken
}
until ((Get-AirVantageOperation -AVDatacenter $AVDatacenter -AVOperationUID $AVOperationUID_CurrentWANTimeinUse -AVAccessToken $AVAccessToken).Status -eq "FINISHED")
Write-Host -ForegroundColor Yellow "Operation finished"

$AVOperationUID_DeviceUptime = (Retrieve-AirVantageSystemData -AVDatacenter $AVDatacenter -AVSystemUID $AVSystemUID -AVSystemDataID $AVSystemDataID_DeviceUptime -AVAccessToken $AVAccessToken).operation

do {
    Get-AirVantageOperation -AVDatacenter $AVDatacenter -AVOperationUID $AVOperationUID_DeviceUptime -AVAccessToken $AVAccessToken
}
until ((Get-AirVantageOperation -AVDatacenter $AVDatacenter -AVOperationUID $AVOperationUID_DeviceUptime -AVAccessToken $AVAccessToken).Status -eq "FINISHED")
Write-Host -ForegroundColor Yellow "Operation finished"

Start-Sleep -Seconds 5 # Waiting on data to be present in AirVantage

$CurrentWANTimeinUse = List-AirVantageSystemData -AVDatacenter $AVDatacenter -AVSystemUID $AVSystemUID -AVSystemDataID $AVSystemDataID_CurrentWANTimeinUse -AVAccessToken $AVAccessToken
$DeviceUptime = List-AirVantageSystemData -AVDatacenter $AVDatacenter -AVSystemUID $AVSystemUID -AVSystemDataID $AVSystemDataID_DeviceUptime -AVAccessToken $AVAccessToken

if ($AVOutput -ne $null){

    Write-Host -ForegroundColor Yellow "Pinging $($AVOutput.subscriptions.ipAddress) with 32 bytes of data..."
    $PingResult = Test-Connection $AVOutput.subscriptions.ipAddress -Count $PingCount | Where-Object {$_.StatusCode -eq "0"} | Measure-Object ResponseTime -Minimum -Maximum -Average | Select @{Name="Packets received";Expression={$_.Count}}, @{Name="Minimum (ms)";Expression={$_.Minimum}}, @{Name="Maximum (ms)";Expression={$_.Maximum}}, @{Name="Average (ms)";Expression={$_.Average}}
    $PingResult | Add-Member -NotePropertyName "Packets sent" -NotePropertyValue $PingCount

    $SystemInfo = New-Object PSCustomObject
    $SystemInfo | Add-Member -NotePropertyName "Name" -NotePropertyValue $AVOutput.name
    $SystemInfo | Add-Member -NotePropertyName "UID" -NotePropertyValue $AVOutput.uid
    $SystemInfo | Add-Member -NotePropertyName "Communication status" -NotePropertyValue $AVOutput.commStatus
    $SystemInfo | Add-Member -NotePropertyName "Last communication" -NotePropertyValue (ConvertFrom-UNIXTimestamp -Timestamp $AVOutput.lastCommDate)
    $SystemInfo | Add-Member -NotePropertyName "Type" -NotePropertyValue $AVOutput.gateway.type
    $SystemInfo | Add-Member -NotePropertyName "Serical number" -NotePropertyValue $AVOutput.gateway.serialNumber
    $SystemInfo | Add-Member -NotePropertyName "IMEI" -NotePropertyValue $AVOutput.gateway.imei
    $SystemInfo | Add-Member -NotePropertyName "MAC-Address" -NotePropertyValue $AVOutput.gateway.macAddress
    $SystemInfo | Add-Member -NotePropertyName "IP-Address" -NotePropertyValue $AVOutput.subscriptions.ipAddress
    $SystemInfo | Add-Member -NotePropertyName "APN" -NotePropertyValue $AVOutput.data.apn
    $SystemInfo | Add-Member -NotePropertyName "Network operator" -NotePropertyValue $AVOutput.data.networkOperator
    $SystemInfo | Add-Member -NotePropertyName "Network service type" -NotePropertyValue $AVOutput.data.networkServiceType
    $SystemInfo | Add-Member -NotePropertyName "Signal strength" -NotePropertyValue $AVOutput.data.signalStrength
    $SystemInfo | Add-Member -NotePropertyName "Roaming status" -NotePropertyValue $AVOutput.data.roamingStatus
    $SystemInfo | Add-Member -NotePropertyName "RSSI level" -NotePropertyValue $AVOutput.data.rssiLevel
    $SystemInfo | Add-Member -NotePropertyName "RSSI" -NotePropertyValue $AVOutput.data.rssi
    $SystemInfo | Add-Member -NotePropertyName "RSRP level" -NotePropertyValue $AVOutput.data.rsrpLevel
    $SystemInfo | Add-Member -NotePropertyName "RSRP" -NotePropertyValue $AVOutput.data.rsrp
    $SystemInfo | Add-Member -NotePropertyName "RSRQ level" -NotePropertyValue $AVOutput.data.rsrqLevel
    $SystemInfo | Add-Member -NotePropertyName "RSRQ" -NotePropertyValue $AVOutput.data.rsrq
    $SystemInfo | Add-Member -NotePropertyName "Firmware version" -NotePropertyValue $AVOutput.data.firmwareVersion
    $SystemInfo | Add-Member -NotePropertyName "Board temperature" -NotePropertyValue $AVOutput.data.boardTemp
    $SystemInfo | Add-Member -NotePropertyName "Radio module temperature" -NotePropertyValue $AVOutput.data.radioModuleTemp
    $SystemInfo | Add-Member -NotePropertyName "Number of resets" -NotePropertyValue $AVOutput.data.numberofResets
    $SystemInfo | Add-Member -NotePropertyName "Current WAN time in use (d.hh:mm:ss)" -NotePropertyValue (New-TimeSpan -Minutes ($CurrentWANTimeinUse).value)
    $SystemInfo | Add-Member -NotePropertyName "Device uptime" -NotePropertyValue ($DeviceUptime).value

    Write-Host -ForegroundColor Yellow "Device info:"
    $SystemInfo | fl
    Write-Host -ForegroundColor Yellow "Ping statistics for $($AVOutput.subscriptions.ipAddress):"
    $PingResult | fl -Property "Packets sent", "Packets received", "Minimum (ms)", "Maximum (ms)", "Average (ms)"
}
else{
    Write-Host -ForegroundColor Red "Error: System not found"
}

# Logout

Disconnect-AirVantage -AVDatacenter $AVDatacenter -AVAccessToken $AVAccessToken

# Cleanup variables

Clear-Variable -Name AV* -Force
Clear-Variable -Name Ping* -Force
