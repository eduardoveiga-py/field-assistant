<#
.SYNOPSIS
    Script de Execução Resiliente do Aplicativo Web (Windows PowerShell)
    Ministério Pessoal - Flutter Web
.DESCRIPTION
    Resolve conflitos de porta (8080), encerra instâncias órfãs do Chrome/Edge e
    processos zumbis do Flutter/Dart, limpa diretórios temporários corrompidos de
    debug em %TEMP%\flutter_tools.*, remove restrições de permissão/somente-leitura
    causadas pelo OneDrive na pasta build\, adiciona flags de isolamento e
    concessão de origens remotas (--remote-allow-origins=*) para prevenir timeouts no
    DWDS (Dart Web Debug Service), e oferece fallback transparente para o modo web-server.
.PARAMETER Mode
    Modo de execução: "chrome" (padrão com fallback), "web-server" (servidor sem DWDS), ou "edge".
.PARAMETER Port
    Porta HTTP local (padrão: 8080).
.PARAMETER Server
    Atalho para iniciar diretamente em modo web-server com abertura automática inteligente do navegador.
.PARAMETER Clean
    Executa limpeza completa de cache (flutter clean) antes de iniciar.
.EXAMPLE
    .\scripts\run_web.ps1
    Executa no Chrome com isolamento de extensões e fallback para web-server.
.EXAMPLE
    .\scripts\run_web.ps1 -Server
    Inicia instantaneamente no modo web-server e abre o navegador assim que o servidor estiver pronto.
.EXAMPLE
    .\scripts\run_web.ps1 -Port 8085 -Clean
    Limpa cache e inicia na porta 8085.
#>
[CmdletBinding()]
param(
    [Alias("m")]
    [ValidateSet("chrome", "web-server", "edge")]
    [string]$Mode = "chrome",

    [Alias("p")]
    [int]$Port = 8080,

    [Alias("s")]
    [switch]$Server,

    [Alias("c")]
    [switch]$Clean,

    [Alias("h", "?")]
    [switch]$Help
)

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    return
}

$ErrorActionPreference = "Continue"

# Garante que o diretório de execução seja a raiz do projeto Flutter
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ProjectRoot

if ($Server) {
    $Mode = "web-server"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Ministério Pessoal - Inicializador Flutter Web Resiliente " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "[DICA] Para inicialização instantânea sem DWDS, use: .\scripts\run_web.ps1 -Server" -ForegroundColor DarkCyan

# 1. Assegurar que o Flutter esteja acessível no PATH
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    $flutterCandidates = @(
        "C:\Users\vanes\flutter\bin",
        "C:\flutter\bin",
        "C:\src\flutter\bin",
        "$env:LOCALAPPDATA\flutter\bin",
        "$env:USERPROFILE\flutter\bin"
    )
    foreach ($candidate in $flutterCandidates) {
        if (Test-Path (Join-Path $candidate "flutter.bat")) {
            $env:PATH = "$candidate;$env:PATH"
            Write-Host "[INFO] Flutter adicionado ao PATH: $candidate" -ForegroundColor DarkGray
            break
        }
    }
}

# 2. Função para abrir o navegador de forma inteligente (aguarda a porta estar ativa)
function Start-BrowserWhenReady([int]$targetPort, [string]$preferredBrowser = "") {
    Start-Job -ScriptBlock {
        param($p, $pref)
        $url = "http://localhost:$p"
        # Aguarda até 90 segundos para o servidor Flutter estar ouvindo e respondendo
        for ($i = 0; $i -lt 90; $i++) {
            Start-Sleep -Milliseconds 1000
            $ready = $false
            try {
                $client = New-Object System.Net.Sockets.TcpClient
                $client.Connect("127.0.0.1", $p)
                if ($client.Connected) {
                    $ready = $true
                    $client.Close()
                }
            } catch {}

            if ($ready) {
                # Aguarda estabilização antes de abrir o browser
                Start-Sleep -Milliseconds 500
                try {
                    if ($pref -and (Get-Command $pref -ErrorAction SilentlyContinue)) {
                        Start-Process $pref $url
                    } else {
                        Start-Process $url
                    }
                } catch {
                    Start-Process $url
                }
                break
            }
        }
    } -ArgumentList $targetPort, $preferredBrowser | Out-Null
}

# 3. Função para liberar porta e processos órfãos
function Clear-PortAndOrphans([int]$targetPort) {
    Write-Host "[1/4] Verificando integridade da porta $targetPort e limpando processos órfãos..." -ForegroundColor Yellow
    
    # 3.1 Identificar e encerrar processos que estejam ouvindo na porta
    $targetPids = @()
    try {
        $connections = Get-NetTCPConnection -LocalPort $targetPort -ErrorAction SilentlyContinue
        if ($connections) {
            $targetPids += ($connections | Select-Object -ExpandProperty OwningProcess -Unique)
        }
    } catch {}

    # Fallback via netstat caso Get-NetTCPConnection falhe ou retorne vazio
    if ($targetPids.Count -eq 0) {
        try {
            $netstatMatches = netstat -ano | Select-String ":$targetPort\s+.*LISTENING\s+(\d+)"
            foreach ($match in $netstatMatches) {
                $firstMatch = $match.Matches | Select-Object -First 1
                if ($firstMatch -and $firstMatch.Groups.Count -gt 1) {
                    $targetPids += [int]$firstMatch.Groups[1].Value
                }
            }
        } catch {}
    }

    $targetPids = $targetPids | Select-Object -Unique | Where-Object { $_ -gt 0 -and $_ -ne $PID }
    foreach ($p in $targetPids) {
        $proc = Get-Process -Id $p -ErrorAction SilentlyContinue
        $procName = if ($proc) { $proc.ProcessName } else { "PID $p" }
        Write-Host "  -> Encerrando processo na porta ${targetPort}: $procName (PID $p)..." -ForegroundColor Yellow
        Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
    }

    # 3.2 Encerrar instâncias órfãs do Chrome/Edge de sessões de depuração do Flutter
    # Não afeta instâncias de navegação pessoal normais do usuário
    try {
        $browserProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            ($_.Name -in @("chrome.exe", "msedge.exe")) -and
            ($_.CommandLine -like "*flutter_tools*" -or $_.CommandLine -like "*remote-debugging-port*") -and
            $_.ProcessId -ne $PID
        }
        foreach ($bp in $browserProcs) {
            Write-Host "  -> Encerrando instância órfã de depuração $($bp.Name) (PID $($bp.ProcessId))..." -ForegroundColor Yellow
            Stop-Process -Id $bp.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    # 3.3 Encerrar processos zumbis do compilador frontend_server ou flutter_tools
    try {
        $zombies = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            ($_.Name -match "^dart.*\.exe$") -and
            ($_.CommandLine -like "*flutter_tools*" -or $_.CommandLine -like "*frontend_server*") -and
            $_.ProcessId -ne $PID
        }
        foreach ($z in $zombies) {
            Write-Host "  -> Encerrando processo zumbi do compilador Dart/Flutter (PID $($z.ProcessId))..." -ForegroundColor Yellow
            Stop-Process -Id $z.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    # 3.4 Limpar diretórios temporários corrompidos de sessões anteriores em %TEMP%\flutter_tools.*
    try {
        Get-ChildItem -Path $env:TEMP -Filter "flutter_tools*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                attrib -r -s "$($_.FullName)" /d 2>$null
                attrib -r -s "$($_.FullName)\*" /s /d 2>$null
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    } catch {}
}

# 4. Função para corrigir permissões e travas do OneDrive em build/
function Fix-BuildDirectoryPermissions {
    Write-Host "[2/4] Verificando e corrigindo permissões do diretório de build..." -ForegroundColor Yellow
    $buildDir = Join-Path $ProjectRoot "build"
    if (Test-Path $buildDir) {
        try {
            $assetsDir = Join-Path $buildDir "flutter_assets"
            if (Test-Path $assetsDir) {
                attrib -r -s "$assetsDir" /d 2>$null
                attrib -r -s "$assetsDir\*" /s /d 2>$null
                Remove-Item -Path $assetsDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            attrib -r -s "$buildDir" /d 2>$null
            attrib -r -s "$buildDir\*" /s /d 2>$null
        } catch {
            Write-Host "  -> [Nota] Não foi possível limpar build/flutter_assets: $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }
}

# Executa as limpezas preliminares
Clear-PortAndOrphans -targetPort $Port
Fix-BuildDirectoryPermissions

if ($Clean) {
    Write-Host "`n[LIMPEZA] Executando flutter clean..." -ForegroundColor Cyan
    flutter clean
}

# 5. Iniciar aplicação
$browserFlags = @(
    "--remote-allow-origins=*",
    "--disable-extensions",
    "--disable-background-timer-throttling",
    "--disable-renderer-backgrounding",
    "--disable-backgrounding-occluded-windows",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-default-apps",
    "--disable-translate",
    "--disable-popup-blocking"
)

if ($Mode -eq "web-server") {
    Write-Host "`n[3/4] Modo Web-Server Selecionado (Resiliente, sem dependência de DWDS)" -ForegroundColor Green
    Write-Host "  -> URL: http://localhost:$Port" -ForegroundColor Cyan
    Write-Host "  -> O navegador abrirá automaticamente assim que o servidor estiver pronto..." -ForegroundColor Cyan
    
    # Inicia abertura inteligente do navegador
    Start-BrowserWhenReady -targetPort $Port
    
    Write-Host "`n[4/4] Executando 'flutter run -d web-server --web-port $Port'..." -ForegroundColor Green
    & flutter run -d web-server --web-port $Port
} else {
    Write-Host "`n[3/4] Iniciando no $Mode com flags de isolamento e permissão de origens..." -ForegroundColor Cyan
    Write-Host "  -> Porta: $Port" -ForegroundColor Cyan
    Write-Host "  -> Flags de depuração limpa ativas." -ForegroundColor Cyan
    
    $extraArgs = @("--web-port", "$Port")
    foreach ($flag in $browserFlags) {
        $extraArgs += @("--web-browser-flag", $flag)
    }

    Write-Host "[4/4] Executando flutter run -d $Mode..." -ForegroundColor Green
    & flutter run -d $Mode @extraArgs

    # 6. Tratamento de fallback caso flutter run termine com erro (ex: DWDS timeout)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n==========================================================" -ForegroundColor Red
        Write-Host " [AVISO] Falha ou encerramento inesperado no ${Mode}/DWDS." -ForegroundColor Red
        Write-Host " Ativando FALLBACK transparente para o modo Web-Server..." -ForegroundColor Yellow
        Write-Host "==========================================================" -ForegroundColor Yellow
        
        # Limpa processos órfãos e portas resultantes da falha
        Clear-PortAndOrphans -targetPort $Port
        Fix-BuildDirectoryPermissions
        
        Write-Host "`nIniciando servidor local resiliente em http://localhost:$Port..." -ForegroundColor Green
        Start-BrowserWhenReady -targetPort $Port -preferredBrowser $Mode
        
        & flutter run -d web-server --web-port $Port
    }
}
