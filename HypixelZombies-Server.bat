@echo off
setlocal EnableExtensions EnableDelayedExpansion
title HypixelZombies - lokaler Paper-Server
chcp 65001 >nul

if "%~1"=="" (
  cmd /c "%~f0" _ && exit /b
  echo.
  echo === Die .bat wurde beendet oder es gab einen Fehler ===
  pause
  exit /b
)

set "ZROOT=%~dp0"
set "ZSERVER=%ZROOT%server"
set "ZRAM=2G"
set "ZPORT=25565"
set "ZJAVA=java"
set "ZOPNAME=Phil_316"

if not exist "%ZSERVER%" mkdir "%ZSERVER%"
if not exist "%ZSERVER%\plugins" mkdir "%ZSERVER%\plugins"

echo.
echo === 1/7 Java pruefen (17 oder neuer noetig) ===
call :javaver java
if !ZJMAJ! GEQ 17 (
  echo Java !ZJMAJ! im PATH gefunden.
  goto :java_ok
)
call :findjava
if defined ZFOUND (
  set "ZJAVA=!ZFOUND!"
  echo Verwende: !ZFOUND!  ^(Java !ZJMAJ!^)
  goto :java_ok
)
if exist "%ZROOT%java\bin\java.exe" (
  call :javaver "%ZROOT%java\bin\java.exe"
  if !ZJMAJ! GEQ 17 (
    set "ZJAVA=%ZROOT%java\bin\java.exe"
    echo Lokales Java gefunden: !ZJAVA!  ^(Java !ZJMAJ!^)
    goto :java_ok
  )
)
echo Keine Java 17+ gefunden. Lade portable Java 21...
set "ZMODE=java"
call :runps
if errorlevel 1 goto :javahelp
if exist "%ZROOT%java\bin\java.exe" (
  set "ZJAVA=%ZROOT%java\bin\java.exe"
  call :javaver "!ZJAVA!"
  echo Portable Java ok: !ZJAVA!  ^(Java !ZJMAJ!^)
  goto :java_ok
)
:javahelp
echo Java-Installation fehlgeschlagen. ZIP von https://adoptium.net/ nach java\ entpacken.
pause
exit /b 1
:java_ok

echo.
echo === 2/7 Paper 1.20.4 ===
if exist "%ZSERVER%\paper.jar" (echo paper.jar da.) else (set "ZMODE=paper" & call :runps || goto :fail)

echo.
echo === 3/7 Zombies-Plugin (Deutsch / Fork) ===
if exist "%ZROOT%Zombies-Deutsch-1.0.0.jar" (
  copy /Y "%ZROOT%Zombies-Deutsch-1.0.0.jar" "%ZSERVER%\plugins\Zombies.jar" >nul
  echo Lokale deutsche JAR kopiert.
) else if exist "%ZROOT%zombies-1.0.0.jar" (
  copy /Y "%ZROOT%zombies-1.0.0.jar" "%ZSERVER%\plugins\Zombies.jar" >nul
  echo Lokale JAR kopiert.
) else (
  echo Keine lokale JAR - lade von GitHub Fork Phil316/Zombies-Plugin ...
  set "ZMODE=plugin"
  call :runps || goto :fail
)

echo.
echo === 4/7 Dead-End-Map ===
if exist "%ZSERVER%\.world_installed" (echo Map da.) else (set "ZMODE=world" & call :runps || goto :fail)

echo.
echo === 5/7 Via-Plugins ===
set "ZMODE=via"
call :runps || goto :fail

echo.
echo === 6/7 Server vorbereiten ===
if not exist "%ZSERVER%\eula.txt" (
  echo Minecraft EULA: https://aka.ms/MinecraftEULA
  choice /c JN /m "Stimmst du der Minecraft-EULA zu"
  if errorlevel 2 (echo Ohne EULA kein Start. & pause & exit /b 1)
  > "%ZSERVER%\eula.txt" echo eula=true
)
set "ZMODE=props"
call :runps || goto :fail
set "ZMODE=ops"
call :runps || goto :fail

netsh advfirewall firewall show rule name="Minecraft Server %ZPORT%" >nul 2>&1
if errorlevel 1 netsh advfirewall firewall add rule name="Minecraft Server %ZPORT%" dir=in action=allow protocol=TCP localport=%ZPORT% >nul 2>&1

echo.
echo ============================================================
echo  Server startet.  localhost  /  LAN:
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do echo     %%a:%ZPORT%
echo  Auto-OP: %ZOPNAME%   online-mode=false
echo  Resource-Pack: OPTIONAL (MC fragt beim Join Ja/Nein)
echo  Auto-Start: Spiel startet ca. 8s nach Join
echo ============================================================
echo.
cd /d "%ZSERVER%"
"%ZJAVA%" -Xms1G -Xmx%ZRAM% -jar paper.jar nogui
echo Server beendet.
pause
exit /b 0

:fail
echo FEHLER beim Installieren.
pause
exit /b 1

:javaver
set "ZJMAJ=0"
set "ZJV="
"%~1" -version > "%TEMP%\zjv.txt" 2>&1
if errorlevel 1 exit /b 0
for /f "tokens=3" %%v in ('findstr /i version "%TEMP%\zjv.txt"') do if not defined ZJV set "ZJV=%%~v"
if not defined ZJV exit /b 0
for /f "tokens=1,2 delims=.-_+" %%a in ("%ZJV%") do (set "ZJ1=%%a" & set "ZJ2=%%b")
set "ZJMAJ=!ZJ1!"
if "!ZJ1!"=="1" set "ZJMAJ=!ZJ2!"
exit /b 0

:findjava
set "ZFOUND="
for /d %%d in ("%ProgramFiles%\Eclipse Adoptium\*" "%ProgramFiles%\Java\*" "%ProgramFiles%\Microsoft\jdk*" "%ProgramFiles%\Zulu\*" "%ProgramFiles%\Amazon Corretto\*" "%LocalAppData%\Programs\Eclipse Adoptium\*") do (
  if not defined ZFOUND if exist "%%~d\bin\java.exe" (
    call :javaver "%%~d\bin\java.exe"
    if !ZJMAJ! GEQ 17 set "ZFOUND=%%~d\bin\java.exe"
  )
)
exit /b 0

:runps
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0'); $i=$s.IndexOf('#PS'+'START'); Invoke-Expression $s.Substring($i)"
exit /b %errorlevel%

#PSSTART
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ 'User-Agent' = 'HypixelZombies-Installer/2.1' }
$dir  = $env:ZSERVER
$mode = $env:ZMODE
$root = $env:ZROOT
$opName = if ($env:ZOPNAME) { $env:ZOPNAME } else { 'Phil_316' }

function Get-ViaPlugin($modrinthSlug, $hangarName, $target) {
    if (Test-Path $target) { Write-Host "$modrinthSlug schon da."; return }
    $ok = $false
    try {
        $loaders = [uri]::EscapeDataString('["paper","spigot","bukkit"]')
        $vers = Invoke-RestMethod -Headers $headers -Uri "https://api.modrinth.com/v2/project/$modrinthSlug/version?loaders=$loaders"
        $rel = $vers | Where-Object { $_.version_type -eq 'release' } | Select-Object -First 1
        if (-not $rel) { $rel = $vers | Select-Object -First 1 }
        $f = $rel.files | Where-Object { $_.primary } | Select-Object -First 1
        if (-not $f) { $f = $rel.files | Select-Object -First 1 }
        Write-Host "Lade $modrinthSlug $($rel.version_number)"
        Invoke-WebRequest -Headers $headers -Uri $f.url -OutFile $target
        $ok = $true
    } catch { }
    if (-not $ok) {
        $v = (Invoke-RestMethod -Headers $headers -Uri "https://hangar.papermc.io/api/v1/projects/$hangarName/latestrelease").ToString().Trim()
        Invoke-WebRequest -Headers $headers -Uri "https://hangar.papermc.io/api/v1/projects/$hangarName/versions/$v/PAPER/download" -OutFile $target
    }
}

function Set-Prop($path, $key, $value) {
    $lines = @()
    if (Test-Path $path) { $lines = Get-Content $path }
    $found = $false
    $out = foreach ($line in $lines) {
        if ($line -match ("^\s*" + [regex]::Escape($key) + "\s*=")) { $found = $true; "$key=$value" } else { $line }
    }
    if (-not $found) { $out = @($out) + "$key=$value" }
    Set-Content -Path $path -Value $out -Encoding UTF8
}

try {
    if ($mode -eq 'java') {
        $javaDir = Join-Path $root 'java'
        $zipPath = Join-Path $env:TEMP 'temurin21.zip'
        Write-Host 'Lade Temurin 21...'
        Invoke-WebRequest -Headers $headers -Uri 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk' -OutFile $zipPath
        if (Test-Path $javaDir) { Remove-Item $javaDir -Recurse -Force }
        New-Item -ItemType Directory -Path $javaDir | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $javaDir -Force
        Remove-Item $zipPath -Force
        $jdkFolder = Get-ChildItem -Path $javaDir -Directory | Select-Object -First 1
        if ($jdkFolder -and (Test-Path (Join-Path $jdkFolder.FullName 'bin\java.exe'))) {
            Get-ChildItem -Path $jdkFolder.FullName | Move-Item -Destination $javaDir -Force
            Remove-Item $jdkFolder.FullName -Recurse -Force
        }
        if (-not (Test-Path (Join-Path $javaDir 'bin\java.exe'))) { throw 'java.exe fehlt' }
        Write-Host 'Java 21 ok.'
    }
    elseif ($mode -eq 'paper') {
        $url = $null
        try {
            $r = Invoke-RestMethod -Headers $headers -Uri 'https://fill.papermc.io/v3/projects/paper/versions/1.20.4/builds/latest'
            $url = $r.downloads.'server:default'.url
        } catch { }
        if (-not $url) {
            $r = Invoke-RestMethod -Headers $headers -Uri 'https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds'
            $b = ($r.builds | Select-Object -Last 1)
            $url = "https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/$($b.build)/downloads/$($b.downloads.application.name)"
        }
        Write-Host "Lade Paper..."
        Invoke-WebRequest -Headers $headers -Uri $url -OutFile "$dir\paper.jar"
        Write-Host 'Paper ok.'
    }
    elseif ($mode -eq 'plugin') {
        $target = "$dir\plugins\Zombies.jar"
        $ok = $false
        $urls = @(
            'https://github.com/Phil316/Zombies-Plugin/releases/latest/download/Zombies-Deutsch-1.0.0.jar',
            'https://github.com/Phil316/Zombies-Plugin/releases/latest/download/zombies-1.0.0.jar',
            'https://github.com/Phil316/Zombies-Plugin/releases/download/v1.0.0-deutsch/Zombies-Deutsch-1.0.0.jar'
        )
        foreach ($url in $urls) {
            try {
                Write-Host "Versuche $url"
                Invoke-WebRequest -Headers $headers -Uri $url -OutFile $target
                if ((Get-Item $target).Length -gt 10000) { $ok = $true; Write-Host 'Fork-JAR geladen.'; break }
            } catch { Write-Host '  nicht verfuegbar.' }
        }
        if (-not $ok) {
            Write-Host 'Fallback: Original Hangar...'
            Invoke-WebRequest -Headers $headers -Uri 'https://hangarcdn.papermc.io/plugins/Lama06/HypixelZombies/versions/1.0.0/PAPER/Zombies.jar' -OutFile $target
            Write-Host 'Original geladen. GitHub Actions Release fehlt noch - nach Build erscheint Deutsch-JAR.'
        }
    }
    elseif ($mode -eq 'via') {
        Get-ViaPlugin 'viaversion' 'ViaVersion' "$dir\plugins\ViaVersion.jar"
        Get-ViaPlugin 'viabackwards' 'ViaBackwards' "$dir\plugins\ViaBackwards.jar"
        Get-ViaPlugin 'viarewind' 'ViaRewind' "$dir\plugins\ViaRewind.jar"
        Write-Host 'Via ok.'
    }
    elseif ($mode -eq 'world') {
        $rel = Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/Lama06/Zombies-Plugin/releases/tags/world'
        $asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
        if (-not $asset) { $asset = $rel.assets | Select-Object -First 1 }
        if (-not $asset) { throw 'Keine World-Datei' }
        $tmp = Join-Path $env:TEMP 'zombies_world'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $file = Join-Path $tmp $asset.name
        Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $file
        $ex = Join-Path $tmp 'x'
        Expand-Archive -Path $file -DestinationPath $ex -Force
        $lvl = Get-ChildItem -Path $ex -Recurse -Filter level.dat | Select-Object -First 1
        if (-not $lvl) { throw 'level.dat fehlt' }
        foreach ($w in 'world','world_nether','world_the_end') { if (Test-Path "$dir\$w") { Remove-Item "$dir\$w" -Recurse -Force } }
        Copy-Item -Path $lvl.Directory.FullName -Destination "$dir\world" -Recurse
        Set-Content -Path "$dir\.world_installed" -Value 'ok'
        Remove-Item $tmp -Recurse -Force
        Write-Host 'Map ok.'
    }
    elseif ($mode -eq 'props') {
        $props = Join-Path $dir 'server.properties'
        if (-not (Test-Path $props)) {
            @('level-name=world','server-port=25565','max-players=10','motd=HypixelZombies LAN (Deutsch)','difficulty=normal','spawn-protection=0','online-mode=false','gamemode=adventure','force-gamemode=true','pvp=false','allow-nether=false','enable-command-block=true','resource-pack=','require-resource-pack=false') | Set-Content -Path $props -Encoding UTF8
        } else {
            Set-Prop $props 'online-mode' 'false'
            Set-Prop $props 'require-resource-pack' 'false'
            Set-Prop $props 'spawn-protection' '0'
            Set-Prop $props 'gamemode' 'adventure'
            Set-Prop $props 'force-gamemode' 'true'
            Set-Prop $props 'pvp' 'false'
            Set-Prop $props 'allow-nether' 'false'
        }
        try {
            $vers = Invoke-RestMethod -Headers $headers -Uri 'https://api.modrinth.com/v2/project/hypixel-zombies-2d/version'
            $rel = $vers | Select-Object -First 1
            $f = $rel.files | Where-Object { $_.primary } | Select-Object -First 1
            if (-not $f) { $f = $rel.files | Select-Object -First 1 }
            if ($f -and $f.url) {
                Set-Prop $props 'resource-pack' $f.url
                Set-Prop $props 'require-resource-pack' 'false'
                if ($f.hashes -and $f.hashes.sha1) { Set-Prop $props 'resource-pack-sha1' $f.hashes.sha1 }
                Set-Prop $props 'resource-pack-prompt' '{"text":"Hypixel-Zombies-Pack (optional)?","color":"gold"}'
                Write-Host "Resource-Pack optional: $($f.url)"
                Write-Host '  Beim Join fragt Minecraft (Ja/Nein) - Ablehnen ok.'
            }
        } catch {
            Set-Prop $props 'require-resource-pack' 'false'
            Write-Host 'Resource-Pack optional nicht gesetzt (kein Fehler).'
        }
    }
    elseif ($mode -eq 'ops') {
        $opsPath = Join-Path $dir 'ops.json'
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $bytes = [Text.Encoding]::UTF8.GetBytes('OfflinePlayer:' + $opName)
        $hash = $md5.ComputeHash($bytes)
        $hash[6] = ($hash[6] -band 0x0F) -bor 0x30
        $hash[8] = ($hash[8] -band 0x3F) -bor 0x80
        $uuid = [guid]::new($hash).ToString()
        $json = @"
[
  {
    "uuid": "$uuid",
    "name": "$opName",
    "level": 4,
    "bypassesPlayerLimit": true
  }
]
"@
        Set-Content -Path $opsPath -Value $json -Encoding UTF8
        Write-Host "Auto-OP: $opName"
    }
    exit 0
}
catch {
    Write-Host "Fehler: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
