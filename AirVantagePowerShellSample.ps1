# AirVantagePowerShellSample.ps1
# Created by Martin Walder
# Version 1.0
# https://doc.airvantage.net/av/howto/cloud/gettingstarted_api/

# AirVantage credentials

$Username = "user@domain.com"
$Password = "password"

# AirVantage datacenter -> https://na.airvantage.net (North America), https://eu.airvantage.net (EMEA)

$AVDatacenter = "https://na.airvantage.net"

# API client settings -> https://na.airvantage.net/develop/api/clients

$ClientId = ""
$SecretKey = ""

# Function Connect-AirVantage - OAUTH authorization code flow
# https://doc.airvantage.net/av/reference/cloud/API/

Function Connect-AirVantage(){
    param(
        [Parameter(Mandatory=$true)]
        $Username,
        [Parameter(Mandatory=$true)]
        $Password,
        [Parameter(Mandatory=$true)]
        $ClientId,
        [Parameter(Mandatory=$true)]
        $SecretKey
    )
    $Parameters = @{
        grant_type = "password"
        username = $Username
        password = $Password
        client_id = $ClientId
        client_secret = $SecretKey
    }
    ((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/oauth/token" -Body $Parameters).Content | ConvertFrom-Json).access_token
}

# Function Get-AirVantageSystem
# https://doc.airvantage.net/av/reference/cloud/API/API-System-v1/

Function Get-AirVantageSystem(){
    param(
        [Parameter(Mandatory=$true)]
        $Name
    )
    ((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/v1/systems?name=$($Name)&access_token=$AccessToken").Content | ConvertFrom-Json).items
}

# Function ConvertFrom-UNIXTimestamp

Function ConvertFrom-UNIXTimestamp(){
    param(
        [Parameter(Mandatory=$true)]
        $Timestamp
    )
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($Timestamp /1000))
}

$AccessToken = Connect-AirVantage -Username $Username -Password $Password -ClientId $ClientId -SecretKey $SecretKey
if ($AccessToken -ne $null){
    Write-Host -ForegroundColor Yellow "Login successful"
}

Write-Host -ForegroundColor Yellow "Registered systems:"
(((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/v1/systems?access_token=$AccessToken").Content | ConvertFrom-Json).items).name

$AVSystemName = Read-Host "`nEnter system's name (not case sensitive)"
$PingCount = Read-Host "Enter the number of pings you want to send to the gateway"

Write-Host -ForegroundColor Yellow "Collecting device information..."
$AVOutput = Get-AirVantageSystem -Name $AVSystemName

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

    Write-Host -ForegroundColor Yellow "Device info:"
    $SystemInfo | fl
    Write-Host -ForegroundColor Yellow "Ping statistics for $($AVOutput.subscriptions.ipAddress):"
    $PingResult | fl -Property "Packets sent", "Packets received", "Minimum (ms)", "Maximum (ms)", "Average (ms)"
}
else{
    Write-Host -ForegroundColor Red "Error: System not found"
}

if ((Invoke-WebRequest -Method Get -Uri "$AVDatacenter/api/oauth/expire?access_token=$($AccessToken)?access_token=$AccessToken").Content -eq '"logout.successful"'){
    Write-Host -ForegroundColor Yellow "Logout successful"
}

# Cleanup variables
Clear-Variable -Name AirVantage* -Force
Clear-Variable -Name Ping* -Force
