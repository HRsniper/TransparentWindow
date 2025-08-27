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
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint crKey, byte bAlpha, uint dwFlags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Constantes utilizadas pelas funções da API do Windows
$GWL_EXSTYLE = -20                # Índice para estilo estendido da janela
$WS_EX_LAYERED = 0x80000          # Permite aplicar efeitos visuais como transparência
$LWA_ALPHA = 0x2                  # Define que a opacidade será aplicada via canal alpha

$HWND_TOPMOST = [IntPtr]::op_Explicit(-1)    # Handle especial para manter janela no topo
$HWND_NOTOPMOST = [IntPtr]::op_Explicit(-2)  # Handle para remover "sempre no topo"
$HWND_BOTTOM = [IntPtr]::op_Explicit(1)      # Handle correto para enviar janela para o fundo

$SWP_NOMOVE = 0x0002              # Não altera posição da janela
$SWP_NOSIZE = 0x0001              # Não altera tamanho da janela
$SWP_SHOWWINDOW = 0x0040          # Garante que a janela será exibida após alteração
$WS_EX_TRANSPARENT = 0x20         # Permite que a janela seja clicável através de áreas transparentes

# 🌫️ Opções globais de opacidade
$Global:opacityOptions = @(
    @{ Percentage = "10%"; Value = 26 },
    @{ Percentage = "20%"; Value = 51 },
    @{ Percentage = "30%"; Value = 77 },
    @{ Percentage = "40%"; Value = 102 },
    @{ Percentage = "50%"; Value = 128 },
    @{ Percentage = "60%"; Value = 153 },
    @{ Percentage = "70%"; Value = 179 },
    @{ Percentage = "80%"; Value = 204 },
    @{ Percentage = "90%"; Value = 230 },
    @{ Percentage = "100%"; Value = 255 }
)

# Verifica se o sistema operacional é compatível (Windows 10 ou superior)
function Check-WindowsVersion {
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
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
    Write-Host "3️⃣  Desfazer topo" -ForegroundColor White
    Write-Host "4️⃣  Fixar no topo (modo passivo)" -ForegroundColor White
    Write-Host "5️⃣  Desfazer topo passivo" -ForegroundColor White
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
    $excludedProcesses = @("System", "Idle", "explorer", "svchost", "wininit", "services", "lsass", "csrss", "smss", "winlogon")
    $windowList = @()
    Get-Process | Where-Object {
        $_.MainWindowTitle -and ($excludedProcesses -notcontains $_.ProcessName)
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
        Write-Host "$emojiIndex  [$processName]#️⃣  $windowTitle" -ForegroundColor Gray
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
function Set-WindowTransparency ($windowHandle, [byte]$opacityValue, [string]$Mode = "normal") {
    try {
        # Obtém os estilos estendidos atuais da janela
        $style = [WinAPI]::GetWindowLong($windowHandle, $GWL_EXSTYLE)

        # Adiciona o estilo WS_EX_LAYERED para permitir transparência
        $newStyle = $style -bor $WS_EX_LAYERED

        # Se o modo for "passive", adiciona WS_EX_TRANSPARENT para ignorar cliques
        if ($Mode -eq "passive") {
            $newStyle = $newStyle -bor $WS_EX_TRANSPARENT
        }

        # Remove o estilo WS_EX_TRANSPARENT se estiver presente
        if ($Mode -eq "removeTransparent") {
            $newStyle = $style -band (-bnot $WS_EX_TRANSPARENT)
        }

        # Aplica os estilos atualizados
        [WinAPI]::SetWindowLong($windowHandle, $GWL_EXSTYLE, $newStyle) | Out-Null

        # Aplica o nível de opacidade usando canal alpha
        [WinAPI]::SetLayeredWindowAttributes($windowHandle, 0, $opacityValue, $LWA_ALPHA) | Out-Null

        return $true
    }
    catch {
        Show-Error "Erro ao aplicar transparência via WinAPI." $_
        return $false
    }
}

function Select-OpacityLevel {
    # Usa a variável global de opacidade
    $options = $Global:opacityOptions

    # Exibe opções para o usuário
    Write-Host "`n📊  Escolha o nível de opacidade:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $options.Count; $i++) {
        $emojiIndex = Convert-ToEmojiNumber $i
        $percentage = $options[$i].Percentage
        Write-Host "$emojiIndex  $percentage" -ForegroundColor Gray
    }

    # Captura entrada do usuário
    $selectedOpacityIndex = Read-Host "`nDigite o número da opacidade desejada ou pressione Enter para usar padrão (50%)"

    # Define índice padrão se vazio
    if ([string]::IsNullOrWhiteSpace($selectedOpacityIndex)) {
        $selectedOpacityIndex = 4
        Write-Host "🔧  Usando opacidade padrão: 50%" -ForegroundColor Yellow
    }

    # Valida entrada
    if ($selectedOpacityIndex -notmatch '^\d+$' -or [int]$selectedOpacityIndex -lt 0 -or [int]$selectedOpacityIndex -ge $options.Count) {
        Show-Error "Índice inválido. Tente novamente."
        return $null
    }

    # Retorna objeto com valor e texto
    return $options[$selectedOpacityIndex]
}

# Aplica transparência à janela selecionada com seleção por índice e valores pré-definidos
function Apply-Transparency($windowHandle, $windowTitle) {
    $opacityChoice = Select-OpacityLevel
    if (-not $opacityChoice) { return }

    $opacityValue = $opacityChoice.Value
    $opacityText = $opacityChoice.Percentage

    # Aplica transparência via WinAPI
    try {
        Set-WindowTransparency $windowHandle $opacityValue
        Write-Host "`n✅  Transparência aplicada à janela '$windowTitle' com opacidade $opacityText." -ForegroundColor Green
    }
    catch {
        Show-Error "Falha ao aplicar transparência." $_
    }
}

# Define a janela como "sempre no topo" (topmost)
function Apply-TopMost($windowHandle, $windowTitle) {
    try {
        [WinAPI]::SetWindowPos($windowHandle, $HWND_TOPMOST, 0, 0, 0, 0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW) | Out-Null
        [WinAPI]::ShowWindow($windowHandle, 5) | Out-Null  # SW_SHOW = 5
        Write-Host "`n📌  Janela '$windowTitle' fixada no topo." -ForegroundColor Green
    }
    catch {
        Show-Error "Falha ao fixar no topo com transparência interativa." $_
    }
}

function Apply-PassiveTopMost($windowHandle, $windowTitle) {
    try {
        $opacityChoice = Select-OpacityLevel
        if (-not $opacityChoice) { return }

        $opacityValue = $opacityChoice.Value
        $opacityText = $opacityChoice.Percentage

        if (-not (Set-WindowTransparency $windowHandle $opacityValue "passive")) {
            return
        }

        Apply-TopMost $windowHandle $windowTitle

        # Exibe mensagem adicional sobre o modo passivo
        Write-Host "🫥  Modo passivo ativado: janela '$windowTitle' não captura cliques." -ForegroundColor DarkGray
    }
    catch {
        Show-Error "Erro ao aplicar modo passivo no topo." $_
    }
}

# Função para desfazer "sempre no topo"
function Undo-TopMost($windowHandle, $windowTitle) {
    try {
        # Remove o estilo topmost
        [WinAPI]::SetWindowPos($windowHandle, $HWND_NOTOPMOST, 0, 0, 0, 0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW) | Out-Null
        # Envia a janela para o fundo
        [WinAPI]::SetWindowPos($windowHandle, $HWND_BOTTOM, 0, 0, 0, 0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW) | Out-Null
        # Minimiza a janela após enviá-la para o fundo
        [WinAPI]::ShowWindow($windowHandle, 6) | Out-Null  # SW_MINIMIZE = 6
        Write-Host "`n↩️  'Sempre no topo' desfeito, janela enviada para baixo e minimizada: '$windowTitle'." -ForegroundColor Green
    }
    catch {
        Show-Error "Falha ao desfazer 'sempre no topo'." $_
    }
}

function Undo-PassiveTopMost($windowHandle, $windowTitle) {
    try {
        $windowOpacity = $Global:opacityOptions[4].Value
        Set-WindowTransparency $windowHandle $windowOpacity "removeTransparent"

        # Remove o estilo "sempre no topo", sem alterar posição ou tamanho
        [WinAPI]::SetWindowPos($windowHandle, $HWND_NOTOPMOST, 0, 0, 0, 0,
            $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW) | Out-Null

        # Exibe mensagem de sucesso
        Write-Host "`n↩️  Modo passivo desfeito. Janela '$windowTitle' voltou ao comportamento normal." -ForegroundColor Green
    }
    catch {
        # Exibe mensagem de erro em caso de falha
        Show-Error "Erro ao desfazer modo passivo." $_
    }
}
# Função centralizada para exibir mensagens de erro
function Show-Error($message, $detail = $null) {
    Write-Host "`n❌  $message" -ForegroundColor Red
    if ($detail) {
        Write-Host "    Detalhe: $detail" -ForegroundColor DarkRed
    }
}

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
    $selectedWindowIndex = Read-Host "`nDigite o número da janela que deseja manipular"

    # Valida o índice informado
    if ($selectedWindowIndex -notmatch '^\d+$' -or [int]$selectedWindowIndex -ge $windowList.Count) {
        Show-Error "Índice inválido. Tente novamente."
        Start-Sleep -Seconds 2
        continue
    }

    # Obtém a janela selecionada e seu identificador
    $selectedWindow = $windowList[$selectedWindowIndex]
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
        "3" { Undo-TopMost $selectedWindowHandle $selectedWindowTitle }
        "4" { Apply-PassiveTopMost $selectedWindowHandle $selectedWindowTitle }
        "5" { Undo-PassiveTopMost $selectedWindowHandle $selectedWindowTitle }
        default {
            Show-Error "Opção inválida. Tente novamente."
        }
    }

    # Pausa antes de reiniciar o loop
    Start-Sleep -Seconds 2

} while ($true)