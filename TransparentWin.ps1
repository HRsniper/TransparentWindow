# Verifica se o sistema operacional é compatível (Windows 10 ou superior)
function Check-WindowsVersion {
    $version = [System.Environment]::OSVersion.Version
    if ($version.Major -lt 10) {
        Show-Error "Este script requer Windows 10 ou superior."
        exit
    }
}

# Exibe o menu principal com opções de ação
function Show-MainMenu {
    Clear-Host
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🖥️  Gerenciador de Janelas Windows     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1️⃣  Aplicar transparência" -ForegroundColor White
    Write-Host "2️⃣  Fixar no topo" -ForegroundColor White
    Write-Host "0️⃣  Sair" -ForegroundColor White
    return (Read-Host "`nEscolha uma opção")
}

# Converte um número inteiro em uma sequência de emojis numéricos
function Convert-ToEmojiNumber($number) {
    $digits = $number.ToString().ToCharArray()
    $emojiDigits = @()
    foreach ($digit in $digits) {
        $emojiDigits += switch ($digit) {
            '0' { "0️⃣" }
            '1' { "1️⃣" }
            '2' { "2️⃣" }
            '3' { "3️⃣" }
            '4' { "4️⃣" }
            '5' { "5️⃣" }
            '6' { "6️⃣" }
            '7' { "7️⃣" }
            '8' { "8️⃣" }
            '9' { "9️⃣" }
        }
    }
    return ($emojiDigits -join "")
}

# Obtém a lista de janelas visíveis, excluindo processos críticos do sistema
function Get-VisibleWindows {
    $excluidos = @("System", "Idle", "explorer", "svchost", "wininit", "services", "lsass", "csrss", "smss", "winlogon")
    $windowList = @()
    Get-Process | Where-Object {
        $_.MainWindowTitle -and ($excluidos -notcontains $_.ProcessName)
    } | ForEach-Object {
        $windowList += $_
    }
    return $windowList
}

# Exibe a lista de janelas visíveis com índice em emoji, nome do processo e título
function Show-WindowList($windowList) {
    Write-Host "`n🪟  Janelas Visíveis:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $windowList.Count; $i++) {
        $window = $windowList[$i]
        $emojiIndex = Convert-ToEmojiNumber $i
        $processName = $window.ProcessName
        $windowTitle = $window.MainWindowTitle
        Write-Host "$emojiIndex  [$processName]  #️⃣  $windowTitle" -ForegroundColor Gray
    }
}

# Obtém o identificador da janela (HWND) do processo selecionado
function Get-WindowHandle($process) {
    try {
        $handle = [IntPtr]$process.MainWindowHandle
        if ($handle -eq [IntPtr]::Zero) {
            throw "Janela não possui MainWindowHandle."
        }
        return $handle
    }
    catch {
        Show-Error "Erro ao obter HWND." $_
        return $null
    }
}

# Aplica transparência à janela selecionada com seleção por índice e valores pré-definidos
function Apply-Transparency($selectedWindowHandle, $selectedWindowTitle) {
    $opcoes = @(
        @{ Porcentagem = "10%"; Valor = 26 },
        @{ Porcentagem = "20%"; Valor = 51 },
        @{ Porcentagem = "30%"; Valor = 77 },
        @{ Porcentagem = "40%"; Valor = 102 },
        @{ Porcentagem = "50%"; Valor = 128 },
        @{ Porcentagem = "60%"; Valor = 153 },
        @{ Porcentagem = "70%"; Valor = 179 },
        @{ Porcentagem = "80%"; Valor = 204 },
        @{ Porcentagem = "90%"; Valor = 230 },
        @{ Porcentagem = "100%"; Valor = 255 }
    )

    Write-Host "`n📊  Escolha o nível de opacidade:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $opcoes.Count; $i++) {
        $emojiIndex = Convert-ToEmojiNumber $i
        $porcentagem = $opcoes[$i].Porcentagem
        Write-Host "$emojiIndex  $porcentagem" -ForegroundColor Gray
    }

    $indice = Read-Host "`nDigite o número da opacidade desejada ou pressione Enter para usar padrão (50%)"

    if ([string]::IsNullOrWhiteSpace($indice)) {
        $indice = 4
        Write-Host "🔧  Usando opacidade padrão: 50%" -ForegroundColor Yellow
    }

    if ($indice -notmatch '^\d+$' -or [int]$indice -lt 0 -or [int]$indice -ge $opcoes.Count) {
        Write-Host "`n⚠️  Índice inválido. Tente novamente." -ForegroundColor Red
        return
    }

    $opacityValue = $opcoes[$indice].Valor
    $opacityText = $opcoes[$indice].Porcentagem

    # Aplica transparência via WinAPI
    try {
        $style = [WinAPI]::GetWindowLong($selectedWindowHandle, $GWL_EXSTYLE)
        [WinAPI]::SetWindowLong($selectedWindowHandle, $GWL_EXSTYLE, $style -bor $WS_EX_LAYERED) | Out-Null
        [WinAPI]::SetLayeredWindowAttributes($selectedWindowHandle, 0, [byte]$opacityValue, $LWA_ALPHA) | Out-Null
        Write-Host "`n✅  Transparência aplicada à janela '$selectedWindowTitle' com opacidade $opacityText." -ForegroundColor Green
    }
    catch {
        Show-Error "Falha ao aplicar transparência." $_
    }
}

# Define a janela como "sempre no topo" (topmost)
function Apply-TopMost($selectedWindowHandle, $selectedWindowTitle) {
    try {
        [WinAPI]::SetWindowPos($selectedWindowHandle, $HWND_TOPMOST, 0, 0, 0, 0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW)
        Write-Host "`n📌  Janela '$selectedWindowTitle' fixada no topo." -ForegroundColor Green
    }
    catch {
        Show-Error "Falha ao fixar no topo." $_
    }
}

# Função centralizada para exibir mensagens de erro
function Show-Error($mensagem, $detalhe = $null) {
    Write-Host "`n❌  $mensagem" -ForegroundColor Red
    if ($detalhe) {
        Write-Host "    Detalhe: $detalhe" -ForegroundColor DarkRed
    }
}

# Define as funções da API do Windows necessárias para manipular janelas
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinAPI {
    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    public static extern bool SetLayeredWindowAttributes(IntPtr hwnd, uint crKey, byte bAlpha, uint dwFlags);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

# Constantes utilizadas pelas funções da API do Windows
$GWL_EXSTYLE = -20        # Índice para estilo estendido da janela
$WS_EX_LAYERED = 0x80000    # Permite aplicar efeitos visuais como transparência
$LWA_ALPHA = 0x2        # Define que a opacidade será aplicada via canal alpha

$HWND_TOPMOST = [IntPtr]::Zero -bor 0xFFFFFFFF  # Handle especial para manter janela no topo

$SWP_NOMOVE = 0x0002     # Não altera posição da janela
$SWP_NOSIZE = 0x0001     # Não altera tamanho da janela
$SWP_SHOWWINDOW = 0x0040     # Garante que a janela será exibida após alteração

# Executa verificação de compatibilidade do sistema
Check-WindowsVersion

# Loop principal do programa
do {
    # Exibe o menu e captura a opção do usuário
    $option = Show-MainMenu

    # Encerra o script se o usuário escolher "0"
    if ($option -eq "0") {
        Write-Host "`n👋  Encerrando o painel. Até a próxima!" -ForegroundColor Cyan
        break
    }

    # Obtém a lista de janelas visíveis
    $windowList = Get-VisibleWindows

    # Verifica se há janelas disponíveis
    if ($windowList.Count -eq 0) {
        Show-Error "Nenhuma janela visível encontrada."
        Start-Sleep -Seconds 2
        continue
    }

    # Exibe a lista de janelas para o usuário escolher
    Show-WindowList $windowList

    # Solicita o índice da janela a ser manipulada
    $selectedIndex = Read-Host "`nDigite o número da janela que deseja manipular"

    # Valida o índice informado
    if ($selectedIndex -notmatch '^\d+$' -or [int]$selectedIndex -ge $windowList.Count) {
        Show-Error "Índice inválido. Tente novamente."
        Start-Sleep -Seconds 2
        continue
    }

    # Obtém a janela selecionada e seu identificador
    $selectedWindow = $windowList[$selectedIndex]
    $selectedWindowTitle = $selectedWindow.MainWindowTitle
    $selectedWindowHandle = Get-WindowHandle $selectedWindow

    # Verifica se o handle é válido
    if (-not $selectedWindowHandle -or $selectedWindowHandle -eq [IntPtr]::Zero) {
        Show-Error "Janela inválida ou inacessível."
        Start-Sleep -Seconds 2
        continue
    }

    # Executa a ação escolhida pelo usuário
    switch ($option) {
        "1" { Apply-Transparency $selectedWindowHandle $selectedWindowTitle }
        "2" { Apply-TopMost $selectedWindowHandle $selectedWindowTitle }
        default {
            Show-Error "Opção inválida. Tente novamente."
        }
    }

    # Pausa antes de reiniciar o loop
    Start-Sleep -Seconds 2

} while ($true)