<#
.SYNOPSIS
Cubotimize - Backup de Aplicações Qlik Cloud

.DESCRIPTION
Script para controle de backups do Qlik Cloud (SaaS).
Suporta dump de Apps (.qvf) de todos os tipos de Space:
Managed, Shared, Personal e Data Space.

Funcionalidades:
  - Autenticação via API Key (Bearer Token)
  - Paginação automática da API
  - Relatório executivo em HTML via e-mail com seção por tipo de Space
  - Gestão de retenção por número de dias
  - BYPASS DE REDE CORPORATIVA: Utiliza curl.exe nativo para contornar SSL Inspection.
  - Mapeamento dinâmico de IDs de usuário para Nomes no Personal Space.
  - Filtros avançados por Nome e Tipo de Space.
  - Exclusões avançadas por Nome e Tipo.
  - Ignora de forma elegante a restrição de privacidade de Personal Spaces de terceiros.

.NOTES
Versão: 3.9.0
Licença: MIT License
Créditos: Mario Sergio Soares
Bio Page: https://cubo.plus/mariosergioti
Direitos Reservados: https://cubotimize.com
#>

# =================================================================
# ⚙️ 1. CONFIGURAÇÕES DO AMBIENTE QLIK CLOUD (AUTENTICAÇÃO)
# =================================================================
# URL do seu ambiente Qlik Cloud. 
# IMPORTANTE: Não coloque barra (/) no final. Ex: "https://empresa.us.qlikcloud.com"
$vTenantUrl         = "https://trocar.us.qlikcloud.com"

# Sua Chave de API (Bearer Token) gerada no painel do Qlik Cloud.
$vApiKey            = "SUA_APIKEY_TROCAR"

# =================================================================
# ⚙️ 2. O QUE FAZER NO DUMP (COMPORTAMENTO)
# =================================================================
# $true para baixar os painéis (.qvf), $false para ignorar.
$vDumpApps        = $true

# Configuração de Peso dos Apps:
# $true  -> Baixa apenas o layout/script do App (Arquivo leve e rápido).
# $false -> Baixa o App completo, incluindo todos os dados carregados nele (Arquivo pesado).
$vDumpAppsSemDados = $true

# =================================================================
# ⚙️ 3. FILTROS OPCIONAIS (REGRAS DE INCLUSÃO)
# =================================================================
# Baixa APENAS os Apps com essa palavra no nome. Deixe "" para baixar tudo. Ex: "Producao"
$vFiltroNome        = ""

# Baixa APENAS este TIPO de Space ("managed", "shared", "personal"). Deixe "" para todos.
$vFiltroTipoEspaco  = ""

# Baixa APENAS os Spaces que contenham esta palavra no nome. Deixe "" para todos. Ex: "Vendas"
$vFiltroNomeEspaco  = ""

# =================================================================
# ⚙️ 4. EXCLUSÕES OPCIONAIS (REGRAS DE EXCLUSÃO)
# =================================================================
# IGNORA os Apps que contenham esta palavra no nome. Deixe "" para não excluir nada. Ex: "Teste"
$vExcluirNome       = ""

# IGNORA este TIPO de Space ("managed", "shared", "personal"). Deixe "" para não excluir nada.
$vExcluirTipoEspaco = ""

# IGNORA os Spaces que contenham esta palavra no nome. Deixe "" para não excluir nada. Ex: "Homologacao"
$vExcluirNomeEspaco = ""

# =================================================================
# ⚙️ 5. CONFIGURAÇÕES DE DESTINO E RETENÇÃO DE ARQUIVOS
# =================================================================
# Nome do servidor atual (usado para identificar nos logs/emails)
$vServidorNome      = $(hostname).ToUpper()

# Caminho exato onde a pasta diária de backup será criada.
# IMPORTANTE: O caminho deve terminar sempre com uma barra (\).
$vPastaBackup       = "\\TROCAR\BACKUP\QLIK\QLIK_CLOUD\$vServidorNome\Dumps\"

# Tempo de vida do backup em dias. Pastas mais antigas que isso serão apagadas automaticamente.
$vDiasBackup        = 30

# =================================================================
# ⚙️ 6. CONFIGURAÇÕES DE E-MAIL (NOTIFICAÇÕES)
# =================================================================
# $true para enviar o relatório HTML por e-mail, $false para rodar silenciosamente.
$vEnviarEmail       = $true 

$vSmtpServer        = "smtp.gmail.com"
$vSmtpPort          = 587

# E-mail robô que fará o disparo (remetente)
$vEmailRemetente    = "TROCAR@gmail.com"

# Senha de Aplicativo (App Password) de 16 dígitos gerada nas configurações de segurança do provedor.
$vSenhaAppGmail     = "xxxx xxxx xxxx xxxx"

# E-mail da equipe/pessoa que vai receber o relatório final.
$vEmailDestino      = "TROCAR", "TROCAR"


# -----------------------------------------------------------------
# 🛑 FIM DAS CONFIGURAÇÕES DO USUÁRIO. NÃO ALTERAR ABAIXO DESTA LINHA.
# -----------------------------------------------------------------


# =================================================================
# PREPARAÇÃO DE SISTEMA E REDE
# =================================================================
# Correção de Acentuação e Caracteres Especiais (UTF-8)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Mantido para o disparo de e-mails (não afeta o cURL)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Remove espaços vazios acidentais da chave
$vApiKeyLimpa = $vApiKey -replace "\s", ""

# Array de argumentos padrão que serão injetados nas chamadas curl
$vCurlHeaders = @(
    "-H", "Authorization: Bearer $vApiKeyLimpa",
    "-H", "Content-Type: application/json",
    "-H", "Accept: application/json"
)

# =================================================================
# FUNÇÃO AUXILIAR: Chamar API Qlik Cloud GET com paginação automática (VIA cURL)
# =================================================================
Function Invoke-QlikCloudGet {
    param(
        [string]$Endpoint,
        [int]$Limit = 100
    )
    $allItems = @()
    $url = "$vTenantUrl$Endpoint"
    if ($url -notmatch "[?&]limit=") {
        $url += if ($url -match "\?") { "&limit=$Limit" } else { "?limit=$Limit" }
    }
    do {
        try {
            $vArgsGet = @("-s", "-L", "--ssl-no-revoke") + $vCurlHeaders + @($url)
            $vResponseStr = & curl.exe $vArgsGet
            $response = $vResponseStr | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Warning "Erro na chamada GET $url : $($_.Exception.Message)"
            break
        }
        
        if ($response.data)                    { $allItems += $response.data }
        elseif ($response -is [System.Array])  { $allItems += $response }
        else                                   { $allItems += $response }
        
        $nextUrl = $null
        if ($response.links -and $response.links.next -and $response.links.next.href) {
            $nextUrl = $response.links.next.href
            $url     = $nextUrl
        }
    } while ($nextUrl)
    return $allItems
}

# =================================================================
# FUNÇÃO: ENVIO DE E-MAIL HTML (TEMPLATE CUBOTIMIZE)
# =================================================================
Function Send-CubotimizeEmail {
    param (
        [string]$Status,
        [string]$Mensagem,
        [string]$Anexo    = "",
        [string]$CorBadge = "#4A5568"
    )

    $vServicoNome = "Dump de Apps Qlik Cloud - $vServidorNome"

    $vHtmlBody = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 0; background-color: #f0f2f5; }
    .container { max-width: 650px; margin: 20px auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 8px 20px rgba(0,0,0,0.1); border: 1px solid #e1e4e8; }
    .cube-strip { height: 6px; width: 100%; display: flex; }
    .strip-blue { background-color: #2E63E6; width: 33.3%; }
    .strip-green { background-color: #3BE854; width: 33.3%; }
    .strip-red { background-color: #E83B3B; width: 33.3%; }
    .header { padding: 30px 20px; text-align: center; background-image: linear-gradient(135deg, #3BE854 0%, #2E63E6 100%); }
    .header h1 { color: #ffffff; margin: 0; font-size: 26px; font-weight: 800; letter-spacing: 3px; text-transform: uppercase; text-shadow: 0 2px 4px rgba(0,0,0,0.2); }
    .content { padding: 40px 30px; color: #333333; text-align: center; }
    .status-badge { display: inline-block; padding: 12px 28px; border-radius: 50px; font-weight: 900; font-size: 20px; color: #ffffff; background-color: $CorBadge; margin-bottom: 25px; min-width: 140px; text-transform: uppercase; letter-spacing: 1px; }
    .info-card { background-color: #f8f9fa; border-radius: 8px; padding: 25px; margin-top: 20px; text-align: left; border: 1px solid #eaeaea; }
    .label { font-size: 11px; color: #888; text-transform: uppercase; font-weight: 700; letter-spacing: 0.5px; margin-bottom: 4px; display: block; }
    .value { font-size: 15px; color: #222; font-weight: 500; margin-bottom: 15px; word-break: break-all; }
    .value-link { color: #2E63E6; text-decoration: none; font-weight: bold; }
    .footer { background-color: #f8f9fa; padding: 25px; text-align: center; font-size: 12px; color: #999; border-top: 1px solid #eaeaea; }
    .slogan { color: #2E63E6; font-weight: 700; font-size: 13px; margin-bottom: 8px; display: block; }
  </style>
</head>
<body>
  <div class="container">
    <div class="cube-strip"><div class="strip-blue"></div><div class="strip-green"></div><div class="strip-red"></div></div>
    <div class="header"><h1>STATUS DO PROCESSO</h1></div>
    <div class="content">
        <div class="status-badge">$Status</div>
        <div style="font-size: 16px; color: #555; margin-bottom: 20px;">Notificação de alteração de estado.</div>
        <div class="info-card">
            <span class="label">SERVIÇO</span>
            <div class="value">$vServicoNome</div>
            <span class="label">TENANT QLIK CLOUD</span>
            <div class="value"><a href="$vTenantUrl" class="value-link">$vTenantUrl</a></div>
            <span class="label">PASTA DE DESTINO</span>
            <div class="value">$vPastaDestino</div>
            <div style="margin-top: 25px; font-size: 14px; color: #333; border-top: 1px solid #ddd; padding-top: 20px;">
                $Mensagem
            </div>
        </div>
    </div>
    <div class="footer"><span class="slogan">Soluções em Inteligência Tecnológica</span>&copy; Cubotimize - Monitoramento</div>
  </div>
</body>
</html>
"@

    $vAssunto = "[Cubotimize] $Status - Dump Apps Qlik Cloud ($vServidorNome)"

    try {
        $vSecurePassword = ConvertTo-SecureString $vSenhaAppGmail -AsPlainText -Force
        $vCredenciais    = New-Object System.Management.Automation.PSCredential ($vEmailRemetente, $vSecurePassword)
        $mailParams = @{
            From       = $vEmailRemetente
            To         = $vEmailDestino
            Subject    = $vAssunto
            Body       = $vHtmlBody
            BodyAsHtml = $true
            SmtpServer = $vSmtpServer
            Port       = $vSmtpPort
            UseSsl     = $true
            Credential = $vCredenciais
            Encoding   = [System.Text.Encoding]::UTF8
        }
        if ($Anexo -ne "" -and (Test-Path $Anexo)) { $mailParams.Add("Attachments", $Anexo) }
        Send-MailMessage @mailParams
        Write-Host "Notificação '$Status' enviada com sucesso!" -ForegroundColor Green
    } catch {
        Write-Host "Falha ao enviar e-mail: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# =================================================================
# SETUP DE DIRETÓRIOS E LOGS
# =================================================================
$vTempoInicioScript = Get-Date
$vDataAgora    = Get-Date -Format "yyyy-MM-dd"
$vPastaDestino = "$($vPastaBackup)$($vDataAgora)\"

If (!(Test-Path $vPastaDestino)) {
    New-Item -ItemType Directory -Force -Path $vPastaDestino | Out-Null
}

# =================================================================
# DISPARO 1: E-MAIL DE INÍCIO
# =================================================================
if ($vEnviarEmail) {
    $vModoAppsTexto = if ($vDumpAppsSemDados) { "Apps SEM dados de carga (NoData)" } else { "Apps COM dados de carga" }

    $vFiltroTexto    = if ($vFiltroNome -ne "") { "Filtro Nome App: <b>'$vFiltroNome'</b><br>" } else { "" }
    $vFiltroTexto   += if ($vFiltroTipoEspaco -ne "") { "Filtro Tipo Space: <b>'$vFiltroTipoEspaco'</b><br>" } else { "" }
    $vFiltroTexto   += if ($vFiltroNomeEspaco -ne "") { "Filtro Nome Space: <b>'$vFiltroNomeEspaco'</b><br>" } else { "" }
    if ($vFiltroTexto -eq "") { $vFiltroTexto = "Sem filtros inclusivos ativos.<br>" }

    $vExclusaoTexto  = if ($vExcluirNome -ne "") { "Excluir Nome App: <b>'$vExcluirNome'</b><br>" } else { "" }
    $vExclusaoTexto += if ($vExcluirTipoEspaco -ne "") { "Excluir Tipo Space: <b>'$vExcluirTipoEspaco'</b><br>" } else { "" }
    $vExclusaoTexto += if ($vExcluirNomeEspaco -ne "") { "Excluir Nome Space: <b>'$vExcluirNomeEspaco'</b><br>" } else { "" }
    if ($vExclusaoTexto -eq "") { $vExclusaoTexto = "Sem exclusões ativas.<br>" }

    Send-CubotimizeEmail -Status "▶️ INICIADO" -Mensagem @"
<div style='background-color:#fff3cd; color:#856404; padding:15px; border-radius:6px; font-family:Consolas,monospace; font-size:13px; line-height:1.8;'>
O processo de dump do Qlik Cloud começou.<br>
<b>$vModoAppsTexto</b><br>
<hr style="border: 0; border-top: 1px solid #ffe8a1; margin: 10px 0;">
<b>Filtros (Inclusão):</b><br>
$vFiltroTexto
<hr style="border: 0; border-top: 1px solid #ffe8a1; margin: 10px 0;">
<b>Exclusões:</b><br>
$vExclusaoTexto
Aguarde o relatório de conclusão.
</div>
"@ -CorBadge "#2E63E6"
}

$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | Out-Null
$ErrorActionPreference = "Continue"
Start-Transcript -path "$($vPastaDestino)backup.log" -append

Echo "================================================================="
Echo " Cubotimize - Backup de Aplicações Qlik Cloud"
Echo " Versão: 3.9.0"
Echo "================================================================="
Echo ""
Echo " Dump de Apps  : $(if ($vDumpAppsSemDados) { 'SIM (sem dados de carga)' } else { 'SIM (com dados de carga)' })"
Echo ""
Echo " --- FILTROS ---"
Echo " Filtro Nome App  : $(if ($vFiltroNome -ne '') { $vFiltroNome } else { '(nenhum)' })"
Echo " Filtro Tipo Space: $(if ($vFiltroTipoEspaco -ne '') { $vFiltroTipoEspaco } else { '(nenhum)' })"
Echo " Filtro Nome Space: $(if ($vFiltroNomeEspaco -ne '') { $vFiltroNomeEspaco } else { '(nenhum)' })"
Echo ""
Echo " --- EXCLUSÕES ---"
Echo " Excluir Nome App  : $(if ($vExcluirNome -ne '') { $vExcluirNome } else { '(nenhum)' })"
Echo " Excluir Tipo Space: $(if ($vExcluirTipoEspaco -ne '') { $vExcluirTipoEspaco } else { '(nenhum)' })"
Echo " Excluir Nome Space: $(if ($vExcluirNomeEspaco -ne '') { $vExcluirNomeEspaco } else { '(nenhum)' })"
Echo "================================================================="
Echo ""

# =================================================================
# VALIDAÇÃO DA CONEXÃO COM O TENANT (VIA cURL)
# =================================================================
Echo "Validando conexão com o Qlik Cloud ($vTenantUrl)..."
try {
    $vArgsTest = @("-s", "-L", "--ssl-no-revoke") + $vCurlHeaders + @("$vTenantUrl/api/v1/users/me")
    $vResponseStr = & curl.exe $vArgsTest
    $vUserInfo = $vResponseStr | ConvertFrom-Json -ErrorAction Stop
    Echo "Conectado! Usuário: $($vUserInfo.name) ($($vUserInfo.email))"
} catch {
    Write-Error "FALHA CRÍTICA: Não foi possível conectar ao Qlik Cloud."
    Write-Error "Detalhe: $($_.Exception.Message)"
    Stop-Transcript
    if ($vEnviarEmail) {
        Send-CubotimizeEmail -Status "❌ FALHA CRÍTICA" -Mensagem "<div style='background-color:#fce8e6; color:#d93025; padding:15px; border-radius:6px;'>Falha na autenticação com o Qlik Cloud.<br>Verifique a URL do tenant e a API Key.<br>Detalhe: $($_.Exception.Message)</div>" -CorBadge "#E83B3B"
    }
    exit 1
}

# =================================================================
# CONTADORES GERAIS E REGEX
# =================================================================
$vCaracteresInvalidos = '[\\/:*?"<>|\[\]]'

$vQtdTotalDeApps     = 0
$vCountManaged       = 0
$vCountShared        = 0
$vCountPersonal      = 0
$vCountAppsIgnorados = 0
$vContagemManaged    = @{}
$vContagemShared     = @{}
$vContagemPessoa     = @{}

$vCountErros = 0
$vListaErros = @()

# =================================================================
# BUSCA DOS SPACES E USUÁRIOS
# =================================================================
Echo "Buscando Spaces do tenant..."
$vTodosOsSpaces = Invoke-QlikCloudGet -Endpoint "/api/v1/spaces"
$vMapaSpaces    = @{}
foreach ($space in $vTodosOsSpaces) { $vMapaSpaces[$space.id] = $space }
Echo "Total de Spaces encontrados: $($vTodosOsSpaces.Count)"

Echo "Buscando Usuários do tenant..."
$vTodosOsUsuarios = Invoke-QlikCloudGet -Endpoint "/api/v1/users"
$vMapaUsuarios    = @{}
foreach ($user in $vTodosOsUsuarios) { $vMapaUsuarios[$user.id] = $user.name }
Echo "Total de Usuários encontrados: $($vTodosOsUsuarios.Count)"

# =================================================================
# BLOCO 1: DUMP DE APPS
# =================================================================
Echo ""
Echo "------[ DUMP DE APPS ]----------------------------------------------"

$vEndpointApps = "/api/v1/items?resourceType=app"
if ($vFiltroNome -ne "") { $vEndpointApps += "&name=$([Uri]::EscapeDataString($vFiltroNome))" }

$vTodosOsApps    = Invoke-QlikCloudGet -Endpoint $vEndpointApps
$vQtdTotalDeApps = $vTodosOsApps.Count
Echo "Apps encontrados na API: $vQtdTotalDeApps"

foreach ($vItem in $vTodosOsApps) {

    $vAppId   = $vItem.resourceId
    $vAppName = $vItem.name
    $vSpaceId = $vItem.spaceId
    $vOwnerId = $vItem.ownerId

    $vEspaco     = if ($vSpaceId -and $vMapaSpaces.ContainsKey($vSpaceId)) { $vMapaSpaces[$vSpaceId] } else { $null }
    $vTipoEspaco = if ($vEspaco) { $vEspaco.type } else { "personal" }
    $vSpaceNome  = if ($vEspaco) { $vEspaco.name } else { "Personal" }

    # --- FILTROS DE INCLUSÃO ---
    if ($vFiltroTipoEspaco -ne "" -and $vTipoEspaco -ne $vFiltroTipoEspaco.ToLower()) { $vCountAppsIgnorados++; continue }
    if ($vFiltroNomeEspaco -ne "" -and $vSpaceNome -notmatch [regex]::Escape($vFiltroNomeEspaco)) { $vCountAppsIgnorados++; continue }

    # --- FILTROS DE EXCLUSÃO ---
    if ($vExcluirNome -ne "" -and $vAppName -match [regex]::Escape($vExcluirNome)) { $vCountAppsIgnorados++; continue }
    if ($vExcluirTipoEspaco -ne "" -and $vTipoEspaco -eq $vExcluirTipoEspaco.ToLower()) { $vCountAppsIgnorados++; continue }
    if ($vExcluirNomeEspaco -ne "" -and $vSpaceNome -match [regex]::Escape($vExcluirNomeEspaco)) { $vCountAppsIgnorados++; continue }

    if ($vTipoEspaco -eq "managed") {
        $vCountManaged++
        $vNomeLimpo        = ($vSpaceNome -replace $vCaracteresInvalidos, "").Trim()
        $vNomePastaDestino = "__Managed\$vNomeLimpo"
        $vContagemManaged[$vNomeLimpo] = [int]$vContagemManaged[$vNomeLimpo] + 1

    } elseif ($vTipoEspaco -eq "shared") {
        $vCountShared++
        $vNomeLimpo        = ($vSpaceNome -replace $vCaracteresInvalidos, "").Trim()
        $vNomePastaDestino = "__Shared\$vNomeLimpo"
        $vContagemShared[$vNomeLimpo] = [int]$vContagemShared[$vNomeLimpo] + 1

    } else {
        $vCountPersonal++
        $vNomeDono = if ($vOwnerId -and $vMapaUsuarios.ContainsKey($vOwnerId)) { $vMapaUsuarios[$vOwnerId] } else { $vOwnerId }
        $vNomeLimpo        = if (![string]::IsNullOrWhiteSpace($vNomeDono)) { ($vNomeDono -replace $vCaracteresInvalidos, "").Trim() } else { "SemDono" }
        $vNomePastaDestino = "__Personal\$vNomeLimpo"
        $vContagemPessoa[$vNomeLimpo] = [int]$vContagemPessoa[$vNomeLimpo] + 1
    }

    Echo "Exportando App: $vAppName | Space/User: $vNomeLimpo ($vTipoEspaco)"

    $vCaminhoCompletoPasta = "$vPastaDestino$vNomePastaDestino"
    If (!(Test-Path $vCaminhoCompletoPasta)) { New-Item -ItemType Directory -Force -Path $vCaminhoCompletoPasta | Out-Null }

    $vArquivoLimpo   = ($vAppName -replace $vCaracteresInvalidos, "").Trim()
    $vCaminhoArquivo = "$vCaminhoCompletoPasta\$vArquivoLimpo.qvf"

    try {
        $vExportUrl = "$vTenantUrl/api/v1/apps/$vAppId/export"
        if ($vDumpAppsSemDados) { $vExportUrl += "?NoData=true" }

        $vTempHeaderFile = "$vPastaDestino\temp_headers_$vAppId.txt"
        $vArgsExport = @("-s", "--ssl-no-revoke", "-X", "POST", "-D", $vTempHeaderFile) + $vCurlHeaders + @($vExportUrl)
        & curl.exe $vArgsExport | Out-Null

        $vDownloadUrl = $null
        if (Test-Path $vTempHeaderFile) {
            $vHeadersLidos = Get-Content $vTempHeaderFile -Encoding UTF8
            foreach ($line in $vHeadersLidos) {
                if ($line -match "^Location:\s*(.+)$") {
                    $vDownloadUrl = $matches[1].Trim()
                    break
                }
            }
            Remove-Item -Path $vTempHeaderFile -ErrorAction SilentlyContinue
        }

        # VERIFICAÇÃO INTELIGENTE DE PRIVACIDADE DO PERSONAL SPACE
        if ([string]::IsNullOrWhiteSpace($vDownloadUrl)) { 
            if ($vTipoEspaco -eq "personal") {
                Echo "  -> ⚠️ IGNORADO: Sem permissão para exportar App do Personal Space de terceiros."
                $vCountAppsIgnorados++
                $vCountPersonal--
                continue 
            } else {
                throw "Link de download ausente na resposta da API." 
            }
        }
        
        if ($vDownloadUrl -notmatch "^https?://") { $vDownloadUrl = "$vTenantUrl$vDownloadUrl" }

        $vArgsDownload = @("-s", "-L", "--ssl-no-revoke", "-H", "Authorization: Bearer $vApiKeyLimpa", "-o", $vCaminhoArquivo, $vDownloadUrl)
        & curl.exe $vArgsDownload

        Echo "  -> OK: $vCaminhoArquivo"

    } catch {
        $vCountErros++
        $vListaErros += "<b>App:</b> $vAppName <br><b>ID:</b> $vAppId <br><b>Falha:</b> $($_.Exception.Message)"
        Write-Warning "FALHA ao exportar '$vAppName' (ID: $vAppId): $($_.Exception.Message)"
    }
}
Echo "------[ FIM DUMP DE APPS ]------------------------------------------"

# =================================================================
# LIMPEZA DE RETENÇÃO
# =================================================================
Echo ""
Echo "------Iniciando exclusão Backup antigo D-$($vDiasBackup)-------"

$vDataCorte      = (Get-Date).AddDays(-$vDiasBackup)
$vPastas_Deletar = Get-ChildItem -Path $vPastaBackup -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match "^\d{4}-\d{2}-\d{2}$" -and $_.CreationTime -lt $vDataCorte
}

if ($vPastas_Deletar) {
    foreach ($vPasta in $vPastas_Deletar) {
        Echo "Excluindo backup antigo: $($vPasta.FullName)"
        Get-ChildItem -Path $vPasta.FullName -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { if ($_.Attributes -match "ReadOnly") { $_.Attributes = "Normal" } }
        Remove-Item -Path $vPasta.FullName -Force -Recurse -ErrorAction Continue
    }
} else {
    Echo "Nenhum backup com mais de $vDiasBackup dias encontrado para exclusão."
}

Echo "------Finalizado-------"

$vTempoFimScript = Get-Date
$vDuracaoScript  = $vTempoFimScript - $vTempoInicioScript

Echo ""
Echo ">>>>>>>>>>> Tempo de execução: $([math]::Round($vDuracaoScript.TotalMinutes, 2)) minutos"
Echo ""

Stop-Transcript

# =================================================================
# DISPARO 2: E-MAIL DE CONCLUSÃO (DINÂMICO)
# =================================================================
if ($vEnviarEmail) {
    $vDuracaoArredondada = [math]::Round($vDuracaoScript.TotalMinutes, 2)
    $vCorErro        = if ($vCountErros -gt 0) { "#E83B3B" } else { "#3BE854" }
    $vStatusFinal    = if ($vCountErros -gt 0) { "⚠️ CONCLUÍDO COM FALHAS" } else { "✅ CONCLUÍDO COM SUCESSO" }
    $vCorBadgeFinal  = if ($vCountErros -gt 0) { "#E83B3B" } else { "#3BE854" }

    $vModoAppsRelat    = if ($vDumpAppsSemDados) { "SEM dados de carga (NoData)" } else { "COM dados de carga" }
    $vFiltroNomeRelat  = if ($vFiltroNome -ne "") { $vFiltroNome } else { "(nenhum)" }
    $vFiltroTipoRelat  = if ($vFiltroTipoEspaco -ne "") { $vFiltroTipoEspaco } else { "(nenhum)" }
    $vFiltroSpaceRelat = if ($vFiltroNomeEspaco -ne "") { $vFiltroNomeEspaco } else { "(nenhum)" }
    $vExcluirNomeRelat  = if ($vExcluirNome -ne "") { $vExcluirNome } else { "(nenhuma)" }
    $vExcluirTipoRelat  = if ($vExcluirTipoEspaco -ne "") { $vExcluirTipoEspaco } else { "(nenhuma)" }
    $vExcluirSpaceRelat = if ($vExcluirNomeEspaco -ne "") { $vExcluirNomeEspaco } else { "(nenhuma)" }

    $vHtmlRelatorio = @"
    <h3 style='color: #2E63E6; margin-bottom: 10px; font-size: 17px;'>📊 Resumo da Execução</h3>
    <table style='width: 100%; border-collapse: collapse; text-align: left; background-color: #fff; border: 1px solid #eee; font-size: 13px;'>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Tenant</td><td style='padding: 7px 8px; font-weight: bold; color: #2E63E6; border-bottom: 1px solid #eee;'>$vTenantUrl</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Modo de Dump</td><td style='padding: 7px 8px; font-weight: bold; color: #4A5567; border-bottom: 1px solid #eee;'>$vModoAppsRelat</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Filtro Nome App</td><td style='padding: 7px 8px; font-weight: bold; color: #4A5567; border-bottom: 1px solid #eee;'>$vFiltroNomeRelat</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Filtro Tipo Space</td><td style='padding: 7px 8px; font-weight: bold; color: #4A5567; border-bottom: 1px solid #eee;'>$vFiltroTipoRelat</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Filtro Nome Space</td><td style='padding: 7px 8px; font-weight: bold; color: #4A5567; border-bottom: 1px solid #eee;'>$vFiltroSpaceRelat</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Excluir Nome App</td><td style='padding: 7px 8px; font-weight: bold; color: #4A5567; border-bottom: 1px solid #eee;'>$vExcluirNomeRelat</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Excluir Tipo Space</td><td style='padding: 7px 8px; font-weight: bold; color: #4A5567; border-bottom: 1px solid #eee;'>$vExcluirTipoRelat</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Excluir Nome Space</td><td style='padding: 7px 8px; font-weight: bold; color: #4A5567; border-bottom: 1px solid #eee;'>$vExcluirSpaceRelat</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Retenção</td><td style='padding: 7px 8px; font-weight: bold; border-bottom: 1px solid #eee;'>$vDiasBackup dias</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Apps Managed 🔴</td><td style='padding: 7px 8px; font-weight: bold; color: #E83B3B; border-bottom: 1px solid #eee;'>$vCountManaged</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Apps Shared 🔵</td><td style='padding: 7px 8px; font-weight: bold; color: #2E63E6; border-bottom: 1px solid #eee;'>$vCountShared</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Apps Personal 👤</td><td style='padding: 7px 8px; font-weight: bold; border-bottom: 1px solid #eee;'>$vCountPersonal</td></tr>
        <tr><td style='padding: 7px 8px; border-bottom: 1px solid #eee; color: #555;'>Apps Ignorados ⚠️</td><td style='padding: 7px 8px; font-weight: bold; color: #f39c12; border-bottom: 1px solid #eee;'>$vCountAppsIgnorados (Filtros + Privacidade)</td></tr>
        <tr><td style='padding: 7px 8px; color: #555;'>Falhas de Exportação</td><td style='padding: 7px 8px; font-weight: bold; color: $vCorErro;'>$vCountErros</td></tr>
    </table><br>
"@

    if ($vCountErros -gt 0) {
        $vHtmlRelatorio += @"
        <h3 style='color: #E83B3B; margin-bottom: 10px; font-size: 15px;'>⚠️ Alertas e Falhas</h3>
        <div style='background-color: #fce8e6; padding: 15px; border-radius: 6px; border-left: 4px solid #E83B3B; margin-bottom: 20px;'>
            <ul style='color: #d93025; margin: 0; padding-left: 20px; font-size: 13px; line-height: 1.6;'>
"@
        foreach ($erro in $vListaErros) { $vHtmlRelatorio += "<li style='margin-bottom: 8px;'>$erro</li>" }
        $vHtmlRelatorio += "</ul></div>"
    }

    if ($vContagemManaged.Count -gt 0) {
        $vHtmlRelatorio += "<h3 style='color:#E83B3B;margin-top:15px;margin-bottom:10px;font-size:15px;'>🔴 Apps por Managed Space</h3>"
        $vHtmlRelatorio += "<table style='width:100%;border-collapse:collapse;font-size:13px;border:1px solid #ddd;'><tr style='background:#f1f3f4;'><th style='padding:7px 8px;border:1px solid #ddd;text-align:left;'>Space</th><th style='padding:7px 8px;border:1px solid #ddd;width:80px;text-align:center;'>Apps</th></tr>"
        foreach ($key in ($vContagemManaged.Keys | Sort-Object)) {
            $vHtmlRelatorio += "<tr><td style='padding:6px 8px;border:1px solid #ddd;'>$key</td><td style='padding:6px 8px;border:1px solid #ddd;text-align:center;font-weight:bold;'>$($vContagemManaged[$key])</td></tr>"
        }
        $vHtmlRelatorio += "</table><br>"
    }

    if ($vContagemShared.Count -gt 0) {
        $vHtmlRelatorio += "<h3 style='color:#2E63E6;margin-top:15px;margin-bottom:10px;font-size:15px;'>🔵 Apps por Shared Space</h3>"
        $vHtmlRelatorio += "<table style='width:100%;border-collapse:collapse;font-size:13px;border:1px solid #ddd;'><tr style='background:#f1f3f4;'><th style='padding:7px 8px;border:1px solid #ddd;text-align:left;'>Space</th><th style='padding:7px 8px;border:1px solid #ddd;width:80px;text-align:center;'>Apps</th></tr>"
        foreach ($key in ($vContagemShared.Keys | Sort-Object)) {
            $vHtmlRelatorio += "<tr><td style='padding:6px 8px;border:1px solid #ddd;'>$key</td><td style='padding:6px 8px;border:1px solid #ddd;text-align:center;font-weight:bold;'>$($vContagemShared[$key])</td></tr>"
        }
        $vHtmlRelatorio += "</table><br>"
    }

    if ($vContagemPessoa.Count -gt 0) {
        $vHtmlRelatorio += "<h3 style='color:#4A5567;margin-top:15px;margin-bottom:10px;font-size:15px;'>👤 Apps por Personal Space (Usuário)</h3>"
        $vHtmlRelatorio += "<table style='width:100%;border-collapse:collapse;font-size:13px;border:1px solid #ddd;'><tr style='background:#f1f3f4;'><th style='padding:7px 8px;border:1px solid #ddd;text-align:left;'>Usuário (Owner)</th><th style='padding:7px 8px;border:1px solid #ddd;width:80px;text-align:center;'>Apps</th></tr>"
        foreach ($key in ($vContagemPessoa.Keys | Sort-Object)) {
            $vHtmlRelatorio += "<tr><td style='padding:6px 8px;border:1px solid #ddd;'>$key</td><td style='padding:6px 8px;border:1px solid #ddd;text-align:center;font-weight:bold;'>$($vContagemPessoa[$key])</td></tr>"
        }
        $vHtmlRelatorio += "</table><br>"
    }

    $vMensagemFinal = "O dump foi concluído em <b>$vDuracaoArredondada minutos</b>. Segue o relatório executivo:" + $vHtmlRelatorio
    Send-CubotimizeEmail -Status $vStatusFinal -Mensagem $vMensagemFinal -Anexo "$vPastaDestino\backup.log" -CorBadge $vCorBadgeFinal
}
