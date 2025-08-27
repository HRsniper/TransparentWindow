function Show-Menu {
    Clear-Host
    Write-Host "=== Controle de Janelas ==="
    Write-Host "1. Aplicar transparência"
    Write-Host "2. Fixar no topo"
    Write-Host "0. Sair"
    $choice = Read-Host "Escolha uma opção"
    return $choice
}

function List-Windows {
    $global:windowList = @()
    $index = 0
    Write-Host "`n=== Janelas Visíveis ==="
    Get-Process | Where-Object { $_.MainWindowTitle } | ForEach-Object {
        $global:windowList += $_
        Write-Host "$index. [$($_.ProcessName)] $($_.MainWindowTitle)"
        $index++
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

    if ($option -eq "0") { break }

    List-Windows

    $selectedIndex = Read-Host "`nDigite o número da janela que deseja manipular"
    if ($selectedIndex -notmatch '^\d+$' -or $selectedIndex -ge $windowList.Count) {
        Write-Host "Índice inválido."
        pause
        continue
    }

    $selectedWindow = $windowList[$selectedIndex]
    $hwnd = [IntPtr]$selectedWindow.MainWindowHandle

    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Host "Janela não encontrada ou não possui janela principal."
        pause
        continue
    }

    switch ($option) {
        "1" {
            $opacity = Read-Host "Digite o nível de opacidade (0 a 255)"
            $style = [WinAPI]::GetWindowLong($hwnd, $GWL_EXSTYLE)
            [WinAPI]::SetWindowLong($hwnd, $GWL_EXSTYLE, $style -bor $WS_EX_LAYERED) | Out-Null
            [WinAPI]::SetLayeredWindowAttributes($hwnd, 0, [byte]$opacity, $LWA_ALPHA) | Out-Null
            Write-Host "Transparência aplicada."
        }
        "2" {
            [WinAPI]::SetWindowPos($hwnd, $HWND_TOPMOST, 0, 0, 0, 0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW)
            Write-Host "Janela fixada no topo."
        }
        default {
            Write-Host "Opção inválida."
        }
    }

    pause
} while ($true)