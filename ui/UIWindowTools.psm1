#Requires -Version 7.0

# ══════════════════════════════════════════════════════════════════════════════
#  UIWindowTools.psm1
#  Funções auxiliares para a interface gráfica:
#    - Leitura de estado atual das janelas (transparência, topmost, passivo)
#    - Versões UI das ações que aceitam valor direto (sem interação CLI)
#
#  Depende de: WinAPI.psm1, WindowTools.psm1
# ══════════════════════════════════════════════════════════════════════════════

# ── P/Invoke adicional — GetLayeredWindowAttributes ───────────────────────────
# Declarado aqui para não modificar o WinAPI.psm1 original
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinAPIEx {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetLayeredWindowAttributes(
        IntPtr hWnd,
        out uint crKey,
        out byte bAlpha,
        out uint dwFlags
    );

    public const int GWL_EXSTYLE    = -20;
    public const int WS_EX_TOPMOST  = 0x00000008;
    public const int WS_EX_TRANSPARENT = 0x00000020;
    public const int WS_EX_LAYERED  = 0x00080000;
    public const int LWA_ALPHA      = 0x2;
}
"@

# ══════════════════════════════════════════════════════════════════════════════
#  Get-WindowTransparency
#  Lê a transparência atual de uma janela.
#  Retorna valor em percentual (10-100) compatível com o slider da UI.
#  Retorna 50 como padrão se a janela não tiver transparência aplicada.
# ══════════════════════════════════════════════════════════════════════════════
function Get-WindowTransparency {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [IntPtr]$WindowHandle
  )

  try {
    $crKey = [uint32]0
    $bAlpha = [byte]0
    $dwFlags = [uint32]0

    $result = [WinAPIEx]::GetLayeredWindowAttributes($WindowHandle, [ref]$crKey, [ref]$bAlpha, [ref]$dwFlags)

    if (-not $result) {
      # janela não tem layered attributes — é 100% opaca
      return 100
    }

    # verifica se o flag LWA_ALPHA está ativo — sem ele o alpha não é usado
    if (($dwFlags -band [WinAPIEx]::LWA_ALPHA) -eq 0) {
      return 100
    }

    # converte byte (0-255) para percentual (10-100) arredondado para múltiplo de 10
    $percent = [Math]::Round(($bAlpha / 255.0) * 100)
    $percent = [Math]::Max(10, [Math]::Min(100, $percent))

    # arredonda para múltiplo de 10 mais próximo (step do slider)
    $percent = [int]([Math]::Round($percent / 10.0) * 10)

    return $percent
  }
  catch {
    return 100
  }
}

# ══════════════════════════════════════════════════════════════════════════════
#  Get-WindowIsTopMost
#  Verifica se a janela está fixada no topo (WS_EX_TOPMOST).
#  Retorna $true ou $false.
# ══════════════════════════════════════════════════════════════════════════════
function Get-WindowIsTopMost {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [IntPtr]$WindowHandle
  )

  try {
    $exStyle = [WinAPI]::GetWindowLong($WindowHandle, [WinAPIEx]::GWL_EXSTYLE)
    return ($exStyle -band [WinAPIEx]::WS_EX_TOPMOST) -ne 0
  }
  catch {
    return $false
  }
}

# ══════════════════════════════════════════════════════════════════════════════
#  Get-WindowIsPassive
#  Verifica se a janela está em modo passivo (WS_EX_TRANSPARENT).
#  Retorna $true ou $false.
# ══════════════════════════════════════════════════════════════════════════════
function Get-WindowIsPassive {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [IntPtr]$WindowHandle
  )

  try {
    $exStyle = [WinAPI]::GetWindowLong($WindowHandle, [WinAPIEx]::GWL_EXSTYLE)
    return ($exStyle -band [WinAPIEx]::WS_EX_TRANSPARENT) -ne 0
  }
  catch {
    return $false
  }
}

# ══════════════════════════════════════════════════════════════════════════════
#  Get-WindowState
#  Retorna um objeto com o estado completo da janela:
#    Transparency : int  (10-100)
#    IsTopMost    : bool
#    IsPassive    : bool
# ══════════════════════════════════════════════════════════════════════════════
function Get-WindowState {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [IntPtr]$WindowHandle
  )

  return [PSCustomObject]@{
    Transparency = Get-WindowTransparency -WindowHandle $WindowHandle
    IsTopMost    = Get-WindowIsTopMost    -WindowHandle $WindowHandle
    IsPassive    = Get-WindowIsPassive    -WindowHandle $WindowHandle
  }
}

# ══════════════════════════════════════════════════════════════════════════════
#  Set-TransparencyUI
#  Versão UI de Apply-Transparency — recebe valor direto do slider (10-100).
#  Converte percentual para byte (0-255) e chama Set-WindowTransparency.
# ══════════════════════════════════════════════════════════════════════════════
function Set-TransparencyUI {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [IntPtr]$WindowHandle,

    [Parameter(Mandatory)]
    [ValidateRange(10, 100)]
    [int]$Percent
  )

  try {
    # converte percentual para byte — ex: 50% → 128, 100% → 255
    $byteValue = [byte][Math]::Round(($Percent / 100.0) * 255)
    return Set-WindowTransparency $WindowHandle $byteValue
  }
  catch {
    return $false
  }
}

# ══════════════════════════════════════════════════════════════════════════════
#  Set-PassiveTopMostUI
#  Versão UI de Apply-PassiveTopMost — recebe valor direto do slider (10-100).
#  Aplica modo passivo (WS_EX_TRANSPARENT + topmost) com opacidade informada.
# ══════════════════════════════════════════════════════════════════════════════
function Set-PassiveTopMostUI {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [IntPtr]$WindowHandle,

    [Parameter(Mandatory)]
    [string]$WindowTitle,

    [Parameter(Mandatory)]
    [ValidateRange(10, 100)]
    [int]$Percent
  )

  try {
    $byteValue = [byte][Math]::Round(($Percent / 100.0) * 255)

    if (-not (Set-WindowTransparency $WindowHandle $byteValue "passive")) {
      return $false
    }

    Apply-TopMost $WindowHandle $WindowTitle
    return $true
  }
  catch {
    return $false
  }
}

# ══════════════════════════════════════════════════════════════════════════════
#  exports
# ══════════════════════════════════════════════════════════════════════════════
Export-ModuleMember -Function @(
  'Get-WindowTransparency',
  'Get-WindowIsTopMost',
  'Get-WindowIsPassive',
  'Get-WindowState',
  'Set-TransparencyUI',
  'Set-PassiveTopMostUI'
)
