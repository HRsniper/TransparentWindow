function Show-Menu {
    Clear-Host
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║    🖥️  Gerenciador de Janelas Windows   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1️⃣  Aplicar transparência" -ForegroundColor White
    Write-Host "2️⃣  Fixar no topo" -ForegroundColor White
    Write-Host "0️⃣  Sair" -ForegroundColor White
    return (Read-Host "`nEscolha uma opção")
}

function Get-VisibleWindows {
    $windowList = @()
    Get-Process | Where-Object { $_.MainWindowTitle } | ForEach-Object {
        $windowList += $_
    }
    return $windowList
}

function Convert-ToEmojiNumber($number) {
    $digits = $number.ToString().ToCharArray()
    $emojiDigits = @()
    foreach ($digit in $digits) {
        switch ($digit) {
            '0' { $emojiDigits += "0️⃣" }
            '1' { $emojiDigits += "1️⃣" }
            '2' { $emojiDigits += "2️⃣" }
            '3' { $emojiDigits += "3️⃣" }
            '4' { $emojiDigits += "4️⃣" }
            '5' { $emojiDigits += "5️⃣" }
            '6' { $emojiDigits += "6️⃣" }
            '7' { $emojiDigits += "7️⃣" }
            '8' { $emojiDigits += "8️⃣" }
            '9' { $emojiDigits += "9️⃣" }
        }
    }
    return ($emojiDigits -join "")
}

function Display-Windows($windowList) {
    Write-Host "`n🪟  Janelas Visíveis:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $windowList.Count; $i++) {
        $proc = $windowList[$i]
        $emojiIndex = Convert-ToEmojiNumber $i
        $name = $proc.ProcessName
        $title = $proc.MainWindowTitle
        Write-Host "$emojiIndex  [$name] '$title'" -ForegroundColor Gray
    }
}

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

function Set-Transparency($hwnd, $title) {
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

function Set-TopMost($hwnd, $title) {
    try {
        [WinAPI]::SetWindowPos($hwnd, $HWND_TOPMOST, 0, 0, 0, 0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW)
        Write-Host "`n📌  Janela '$title' fixada no topo." -ForegroundColor Green
    }
    catch {
        Write-Host "`n❌  Falha ao fixar no topo: $_" -ForegroundColor Red
    }
}

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

# Constantes
$GWL_EXSTYLE = -20
$WS_EX_LAYERED = 0x80000
$LWA_ALPHA = 0x2
$HWND_TOPMOST = [IntPtr]::Zero -bor 0xFFFFFFFF
$SWP_NOMOVE = 0x0002
$SWP_NOSIZE = 0x0001
$SWP_SHOWWINDOW = 0x0040

do {
    $option = Show-Menu
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

    Display-Windows $windowList
    $selectedIndex = Read-Host "`nDigite o número da janela que deseja manipular"
    if ($selectedIndex -notmatch '^\d+$' -or [int]$selectedIndex -ge $windowList.Count) {
        Write-Host "`n⚠️  Índice inválido. Tente novamente." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    $selectedWindow = $windowList[$selectedIndex]
    $hwnd = Get-WindowHandle $selectedWindow
    if (-not $hwnd) {
        Start-Sleep -Seconds 2
        continue
    }

    switch ($option) {
        "1" { Set-Transparency $hwnd $selectedWindow.MainWindowTitle }
        "2" { Set-TopMost $hwnd $selectedWindow.MainWindowTitle }
        default {
            Write-Host "`n⚠️  Opção inválida. Tente novamente." -ForegroundColor Red
        }
    }

    Start-Sleep -Seconds 2
} while ($true)