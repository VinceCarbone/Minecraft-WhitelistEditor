param (    
    [Parameter(Mandatory=$true)][string[]]$UserNames,
    [Parameter(mandatory=$true)][string]$FilePath
)

# Variables
$ExistingUsers = @()
$UsersToAdd = @()
$NewUserInfo = @()

# Checks to see if floodgate is installed (for Bedrock players) and reads the prefix character, otherwise it defaults to "."
If(Test-Path -Path "$FilePath\plugins\floodgate\config.yml"){
    $floodgate = Get-Content "$FilePath\plugins\floodgate\config.yml"
    $prefix = (($floodgate -like "username-prefix*") -replace 'username-prefix: ') -replace '"'
}
else {
    $prefix = "."
}

# Checks to see if there's already a whitelist file
$FilePath = $FilePath -replace "\whitelist.json"
if (Test-Path $FilePath){
    if (Get-ChildItem -Path $FilePath -Filter "whitelist.json"){
        $confirm = Read-Host "Do you want to append the existing whitelist.json file? [Y/N]"
        If($confirm -like "n*"){exit}
        $ExistingUsers = @(Get-Content -Path "$FilePath\whitelist.json" | ConvertFrom-Json)
    }
}

# If there's a whitelist, checks to see if the people you're trying to add are already present
if ($ExistingUsers) {
    ForEach($UserName in $UserNames){
        if ($ExistingUsers.name -notcontains $UserName){
            if ($ExistingUsers.name -notcontains "$($prefix+$UserName)"){
                $UsersToAdd += $UserName
            }
            else {Write-Host "$($prefix+$UserName) - Bedrock Minecraft user already in whitelist" -ForegroundColor Yellow}
        }
        else {Write-Host "$UserName - Minecraft user already in whitelist" -ForegroundColor Yellow}
    }
}
else {
    $UsersToAdd = $UserNames
}

# UUID lookup
ForEach($UserToAdd in $UsersToAdd){
    $UUID = $null
    Try{
        # Java players
        $response = Invoke-WebRequest -Uri "https://playerdb.co/api/player/minecraft/$UserToAdd" -UseBasicParsing -ErrorAction Stop
        $UUID = ($response.content | ConvertFrom-Json).data.Player.id
        $name = ($response.content | ConvertFrom-Json).data.Player.username
        Write-Host "$name - Minecraft user found" -ForegroundColor Green
    }
    Catch{
        Try{
            # Bedrock players
            $response = Invoke-WebRequest -Uri "https://mcprofile.io/api/v1/bedrock/gamertag/$UserToAdd" -UseBasicParsing -ErrorAction Stop
            $UUID = ($response.content | ConvertFrom-Json).floodgateuid
            $name = "$prefix" + "$(($response.content | ConvertFrom-Json).gamertag)"
            Write-Host "$name - Bedrock Minecraft user found" -ForegroundColor Green     
        }
        Catch{            
            Write-Host "$UserToAdd - Unable to find Minecraft user" -ForegroundColor Red
        }
    }
    If($UUID){
        $NewUserInfo += [PSCustomObject]@{
            uuid = $UUID
            name = $name               
        }
    }
}

# Build the new whitelist.json file
if ($NewUserInfo){
    if ($ExistingUsers){
        $AllUsers = $ExistingUsers + $NewUserInfo
    }
    else {
        $AllUsers = $NewUserInfo
    }
    Try{
        $AllUsers | Sort-Object name | ConvertTo-Json | Out-File -FilePath "$FilePath\whitelist.json" -Force -ErrorAction Stop
        Write-Host "New whitelist.json file was successfully written to $filepath"
    }
    Catch{
        Write-Host "Failed to write whitelist.json to $filepath" -ForegroundColor Red
    }
}