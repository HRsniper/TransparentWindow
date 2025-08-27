# Verifica se o sistema operacional é compatível (Windows 10 ou superior)
function Check-WindowsVersion {
    $version = [System.Environment]::OSVersion.Version
    if ($version.Major -lt 10) {
        Write-Host "`n⚠️  Este script requer Windows 10 ou superior." -ForegroundColor Red
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
        $proc = $windowList[$i]
        $emojiIndex = Convert-ToEmojiNumber $i
        $name = $proc.ProcessName
        $title = $proc.MainWindowTitle
        Write-Host "$emojiIndex  [$name]  #️⃣  $title" -ForegroundColor Gray
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
        Write-Host "`n❌  Erro ao obter HWND: $_" -ForegroundColor Red
        return $null
    }
}

# Aplica transparência à janela selecionada com nível de opacidade definido pelo usuário
function Apply-Transparency($hwnd, $title) {
    $opacity = Read-Host "Digite o nível de opacidade (0 a 255)"
    if ($opacity -notmatch '^\d+$' -or [int]$opacity -lt 0 -or [int]$opacity -gt 255) {
        Write-Host "`n⚠️  Valor inválido. Use um número entre 0 e 255." -ForegroundColor Red
        return
    }
    try {
        $style = [WinAPI]::GetWindowLong($hwnd, $GWL_EXSTYLE)
        [WinAPI]::SetWindowLong($hwnd, $GWL_EXSTYLE, $style -bor $WS_EX_LAYERED) | Out-Null
        [WinAPI]::SetLayeredWindowAttributes($hwnd, 0, [byte]$opacity, $LWA_ALPHA) | Out-Null
        Write-Host "`n✅  Transparência aplicada à janela '$title' com opacidade $opacity." -ForegroundColor Green
    }
    catch {
        Write-Host "`n❌  Falha ao aplicar transparência: $_" -ForegroundColor Red
    }
}

# Define a janela como "sempre no topo" (topmost)
function Apply-TopMost($hwnd, $title) {
    try {
        [WinAPI]::SetWindowPos($hwnd, $HWND_TOPMOST, 0, 0, 0, 0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW)
        Write-Host "`n📌  Janela '$title' fixada no topo." -ForegroundColor Green
    }
    catch {
        Write-Host "`n❌  Falha ao fixar no topo: $_" -ForegroundColor Red
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
$GWL_EXSTYLE = -20        # Índice usado para acessar o estilo estendido da janela (Extended Window Style)
$WS_EX_LAYERED = 0x80000    # Estilo que permite aplicar efeitos visuais como transparência (Layered Window)
$LWA_ALPHA = 0x2        # Flag que indica que a opacidade será definida via canal alpha (transparência)
$HWND_TOPMOST = [IntPtr]::Zero -bor 0xFFFFFFFF  # Handle especial que posiciona a janela sempre no topo (TopMost)
$SWP_NOMOVE = 0x0002     # Flag que indica que a posição da janela não deve ser alterada
$SWP_NOSIZE = 0x0001     # Flag que indica que o tamanho da janela não deve ser alterado
$SWP_SHOWWINDOW = 0x0040     # Flag que garante que a janela será exibida após a alteração de posição

# Executa verificação de compatibilidade do sistema
Check-WindowsVersion

# Loop principal do programa
do {
    $option = Show-MainMenu
    if ($option -eq "0") {
        Write-Host "`n👋  Encerrando o painel. Até a próxima!" -ForegroundColor Cyan
        break
    }

    $windowList = Get-VisibleWindows
    if ($windowList.Count -eq 0) {
        Write-Host "`n⚠️  Nenhuma janela visível encontrada." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    Show-WindowList $windowList
    $selectedIndex = Read-Host "`nDigite o número da janela que deseja manipular"
    if ($selectedIndex -notmatch '^\d+$' -or [int]$selectedIndex -ge $windowList.Count) {
        Write-Host "`n⚠️  Índice inválido. Tente novamente." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    $selectedWindow = $windowList[$selectedIndex]
    $hwnd = Get-WindowHandle $selectedWindow
    if (-not $hwnd -or $hwnd -eq [IntPtr]::Zero) {
        Write-Host "`n❌  Janela inválida ou inacessível." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    switch ($option) {
        "1" { Apply-Transparency $hwnd $selectedWindow.MainWindowTitle }
        "2" { Apply-TopMost $hwnd $selectedWindow.MainWindowTitle }
        default {
            Write-Host "`n⚠️  Opção inválida. Tente novamente." -ForegroundColor Red
        }
    }

    Start-Sleep -Seconds 2
} while ($true)