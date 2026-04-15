#Requires -Version 7.0

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── importa módulos ───────────────────────────────────────────────────────────
Import-Module "$PSScriptRoot\WinAPI.psm1"
Import-Module "$PSScriptRoot\WindowTools.psm1"
Import-Module "$PSScriptRoot\WindowManager.psm1"
Import-Module "$PSScriptRoot\UI\UIWindowTools.psm1"
Import-Module "$PSScriptRoot\UI\UIMain.psm1"
Import-Module "$PSScriptRoot\UI\TrayManager.psm1"

# ── carrega XAML ──────────────────────────────────────────────────────────────
$xamlPath = "$PSScriptRoot\UI\MainWindow.xaml"
$xaml = [System.IO.File]::ReadAllText($xamlPath)
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# ── botões da titlebar ────────────────────────────────────────────────────────
$window.FindName("BtnMinimize").Add_Click({
    $window.WindowState = [System.Windows.WindowState]::Minimized
  })

$window.FindName("BtnClose").Add_Click({
    $window.Close()
  })

# ── intercepta fechamento — esconde pro tray ──────────────────────────────────
$window.Add_Closing({
    param($sender, $e)
    if ($sender.Tag -eq "exit") { return }
    $e.Cancel = $true
    $sender.Visibility = [System.Windows.Visibility]::Hidden
    $sender.ShowInTaskbar = $false
  })

# ── inicializa UI (controles, eventos, lista de janelas) ──────────────────────
Initialize-UI -Window $window

# ── inicializa tray ───────────────────────────────────────────────────────────
Initialize-Tray -IconPath "$PSScriptRoot\assets\icon.ico" -WpfWindow $window

# ── exibe janela ──────────────────────────────────────────────────────────────
$window.Show()

$window.Add_ContentRendered({
    $helper = [System.Windows.Interop.WindowInteropHelper]::new($window)
    $script:AppHwnd = $helper.Handle

    if ($script:AppHwnd -eq [IntPtr]::Zero) { return }

    $window.Topmost = $true

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        if ($null -eq $script:AppHwnd -or $script:AppHwnd -eq [IntPtr]::Zero) { return }
        $window.Topmost = $true
        [WinAPI]::SetWindowPos(
          $script:AppHwnd,
          [IntPtr]::op_Explicit(-1),
          0, 0, 0, 0,
          0x0001 -bor 0x0002
        ) | Out-Null
      })
    $timer.Start()
  })

# ── mantém o processo vivo via Application WPF ───────────────────────────────
try {
  $app = [System.Windows.Application]::new()
}
catch {
  $app = [System.Windows.Application]::Current
}

$app.Run()
