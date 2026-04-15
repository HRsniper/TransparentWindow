#Requires -Version 7.0

# ══════════════════════════════════════════════════════════════════════════════
#  UIMain.psm1
#  Conecta o XAML da MainWindow com os módulos de lógica:
#    - WindowManager.psm1  (Get-VisibleWindows, Get-WindowHandle)
#    - WindowTools.psm1    (Apply-TopMost, Undo-TopMost, etc.)
#    - UIWindowTools.psm1  (Get-WindowState, Set-TransparencyUI, etc.)
#
#  Exporta:
#    Initialize-UI : inicializa controles, eventos e lista de janelas
# ══════════════════════════════════════════════════════════════════════════════

# ── variáveis de módulo ───────────────────────────────────────────────────────
$script:Window = $null
$script:SelectedHandle = $null   # IntPtr da janela selecionada
$script:SelectedTitle = $null   # título da janela selecionada

# referências aos controles XAML
$script:WindowList = $null
$script:SliderLabel = $null
$script:Slider = $null
$script:ToggleFixar = $null
$script:TogglePassivo = $null
$script:StatusDot = $null
$script:StatusLabel = $null
$script:IsUpdatingSlider = $false

# ══════════════════════════════════════════════════════════════════════════════
#  Update-StatusBar
#  Atualiza o dot e o label da status bar.
#  -Color : cor do dot (hex string) — ex: "#50fa7b"
#  -Text  : mensagem de status
# ══════════════════════════════════════════════════════════════════════════════
function Update-StatusBar {
  param(
    [string]$Text,
    [string]$Color = "#6272a4"
  )

  $script:StatusDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
  $script:StatusLabel.Text = $Text
}

# ══════════════════════════════════════════════════════════════════════════════
#  Update-WindowList
#  Limpa e repopula o ListView com as janelas visíveis atuais.
#  Cada ListViewItem tem Tag = processo para recuperar handle no SelectionChanged.
# ══════════════════════════════════════════════════════════════════════════════
function Update-WindowList {
  $script:WindowList.Items.Clear()

  $windows = Get-VisibleWindows
  if ($windows.Count -eq 0) {
    Update-StatusBar -Text "Nenhuma janela visível encontrada." -Color "#ffb86c"
    return
  }

  foreach ($proc in $windows) {
    $title = if ($proc.MainWindowTitle) { $proc.MainWindowTitle } else { "[Sem título]" }
    $process = $proc.ProcessName

    # container do item
    $stack = [System.Windows.Controls.StackPanel]::new()

    $lblTitle = [System.Windows.Controls.TextBlock]::new()
    $lblTitle.Text = $title
    $lblTitle.FontSize = 13
    $lblTitle.FontWeight = [System.Windows.FontWeights]::Medium
    $lblTitle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f8f8f2")

    $lblProcess = [System.Windows.Controls.TextBlock]::new()
    $lblProcess.Text = $process
    $lblProcess.FontSize = 11
    $lblProcess.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#6272a4")
    $lblProcess.Margin = [System.Windows.Thickness]::new(0, 1, 0, 0)

    $stack.Children.Add($lblTitle)   | Out-Null
    $stack.Children.Add($lblProcess) | Out-Null

    # ListViewItem com Tag = processo
    $item = [System.Windows.Controls.ListViewItem]::new()
    $item.Content = $stack
    $item.Tag = $proc

    $script:WindowList.Items.Add($item) | Out-Null
  }

  Update-StatusBar -Text "$($windows.Count) janela(s) encontrada(s)." -Color "#6272a4"
}

# ══════════════════════════════════════════════════════════════════════════════
#  Set-ControlsEnabled
#  Habilita ou desabilita o slider e os toggles.
# ══════════════════════════════════════════════════════════════════════════════
function Set-ControlsEnabled {
  param([bool]$Enabled)

  $script:Slider.IsEnabled = $Enabled
  $script:ToggleFixar.IsEnabled = $Enabled
  $script:TogglePassivo.IsEnabled = $Enabled
}

# ══════════════════════════════════════════════════════════════════════════════
#  Reset-Controls
#  Reseta slider e toggles para estado padrão (sem janela selecionada).
# ══════════════════════════════════════════════════════════════════════════════
function Reset-Controls {
  $script:SelectedHandle = $null
  $script:SelectedTitle = $null

  $script:Slider.Value = 50
  $script:SliderLabel.Text = "50%"
  $script:ToggleFixar.IsChecked = $false
  $script:TogglePassivo.IsChecked = $false

  Set-ControlsEnabled $false
  Update-StatusBar -Text "Nenhuma janela selecionada." -Color "#6272a4"
}

# ══════════════════════════════════════════════════════════════════════════════
#  Initialize-UI
#  Ponto de entrada principal — obtém controles, registra eventos, popula lista.
# ══════════════════════════════════════════════════════════════════════════════
function Initialize-UI {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [System.Windows.Window]$Window
  )

  $script:Window = $Window

  # ── obtém referências aos controles ───────────────────────────────────────
  $script:WindowList = $Window.FindName("WindowList")
  $script:SliderLabel = $Window.FindName("SliderValueLabel")
  $script:Slider = $Window.FindName("TransparencySlider")
  $script:ToggleFixar = $Window.FindName("ToggleFixar")
  $script:TogglePassivo = $Window.FindName("TogglePassivo")
  $script:StatusDot = $Window.FindName("StatusDot")
  $script:StatusLabel = $Window.FindName("StatusLabel")

  # ── estado inicial ────────────────────────────────────────────────────────
  Reset-Controls

  # ── eventos ───────────────────────────────────────────────────────────────

  # drag da titlebar
  $Window.FindName("TitleBar").Add_MouseDown({
      param($s, $e)
      if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
        $script:Window.DragMove()
      }
    })

  # botão refresh
  $Window.FindName("BtnRefresh").Add_Click({
      Update-WindowList
      Reset-Controls
    })

  # seleção de janela na lista
  $script:WindowList.Add_SelectionChanged({
      param($s, $e)

      $item = $script:WindowList.SelectedItem
      if ($null -eq $item) {
        Reset-Controls
        return
      }

      $proc = $item.Tag

      # obtém handle
      $handle = $null
      if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
        $handle = Get-WindowHandle $proc
      }
      else {
        $handle = Get-UWPWindowHandle $proc
      }

      if ($null -eq $handle -or $handle -eq [IntPtr]::Zero) {
        Update-StatusBar -Text "Janela inacessível." -Color "#ff5555"
        Set-ControlsEnabled $false
        return
      }

      $script:SelectedHandle = $handle
      $script:SelectedTitle = if ($proc.MainWindowTitle) { $proc.MainWindowTitle } else { $proc.ProcessName }

      # lê estado atual da janela
      $state = Get-WindowState -WindowHandle $handle

      # atualiza slider sem disparar ValueChanged
      $script:Slider.IsEnabled = $false
      $script:Slider.Value = $state.Transparency
      $script:SliderLabel.Text = "$($state.Transparency)%"
      $script:Slider.IsEnabled = $true

      # atualiza toggles
      $script:ToggleFixar.IsChecked = $state.IsTopMost
      $script:TogglePassivo.IsChecked = $state.IsPassive

      Set-ControlsEnabled $true
      Update-StatusBar -Text "Selecionado: $($script:SelectedTitle)" -Color "#6272a4"
    })

  # slider de transparência — tempo real
  # ValueChanged — atualiza label com valor arredondado, sem aplicar
  $script:Slider.Add_ValueChanged({
      param($s, $e)
      if ($script:IsUpdatingSlider) { return } # <── ignora updates programáticos
      $raw = [int]$e.NewValue
      $rounded = [int]([Math]::Round($raw / 10.0) * 10)
      $rounded = [Math]::Max(10, [Math]::Min(100, $rounded))
      $script:SliderLabel.Text = "$rounded%"
    })

  # Aplica só quando soltar — valor arredondado para múltiplo de 10
  $script:Slider.Add_PreviewMouseLeftButtonUp({
      if ($null -eq $script:SelectedHandle) { return }
      $raw = [int]$script:Slider.Value
      $rounded = [int]([Math]::Round($raw / 10.0) * 10)
      $rounded = [Math]::Max(10, [Math]::Min(100, $rounded))
      Set-TransparencyUI -WindowHandle $script:SelectedHandle -Percent $rounded | Out-Null
      Update-StatusBar -Text "Transparência: $rounded% — $($script:SelectedTitle)" -Color "#bd93f9"
    })

  # toggle Fixar
  $script:ToggleFixar.Add_Click({
      if ($null -eq $script:SelectedHandle) { return }

      if ($script:ToggleFixar.IsChecked) {
        Apply-TopMost $script:SelectedHandle $script:SelectedTitle
        Update-StatusBar -Text "Fixado no topo: $($script:SelectedTitle)" -Color "#50fa7b"
      }
      else {
        Undo-TopMost $script:SelectedHandle $script:SelectedTitle
        Update-StatusBar -Text "Desafixado: $($script:SelectedTitle)" -Color "#ff5555"
      }
    })

  # toggle Passivo
  $script:TogglePassivo.Add_Click({
      if ($null -eq $script:SelectedHandle) { return }

      if ($script:TogglePassivo.IsChecked) {
        $percent = [int]$script:Slider.Value
        Set-PassiveTopMostUI -WindowHandle $script:SelectedHandle -WindowTitle $script:SelectedTitle -Percent $percent | Out-Null
        Update-StatusBar -Text "Modo passivo ativo: $($script:SelectedTitle)" -Color "#8be9fd"
      }
      else {
        Undo-PassiveTopMost $script:SelectedHandle $script:SelectedTitle
        Update-StatusBar -Text "Modo passivo desfeito: $($script:SelectedTitle)" -Color "#ff5555"
      }
    })

  # popula lista na inicialização
  Update-WindowList
}

# ══════════════════════════════════════════════════════════════════════════════
#  exports
# ══════════════════════════════════════════════════════════════════════════════
Export-ModuleMember -Function Initialize-UI, Update-WindowList, Update-StatusBar
