#Requires -Version 7.0

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ══════════════════════════════════════════════════════════════════════════════
#  variáveis de módulo
# ══════════════════════════════════════════════════════════════════════════════
$script:TrayIcon = $null
$script:TrayThread = $null
$script:WpfWindow = $null   # referência à janela WPF — preenchida pelo caller

# ══════════════════════════════════════════════════════════════════════════════
#  Initialize-Tray
#  Cria o NotifyIcon e inicia o message loop em thread STA separada.
#
#  Parâmetros:
#    -IconPath   : caminho para o .ico (relativo ou absoluto)
#    -WpfWindow  : objeto [System.Windows.Window] da janela WPF
# ══════════════════════════════════════════════════════════════════════════════
function Initialize-Tray {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$IconPath,

    [Parameter(Mandatory)]
    [System.Windows.Window]$WpfWindow
  )

  # guarda referência à janela WPF para uso nos eventos
  $script:WpfWindow = $WpfWindow

  # resolve caminho absoluto do ícone
  $resolvedIcon = Resolve-Path $IconPath -ErrorAction SilentlyContinue
  if (-not $resolvedIcon) {
    Write-Warning "TrayManager: ícone não encontrado em '$IconPath'. Usando ícone padrão."
    $resolvedIcon = $null
  }

  # captura variáveis para passar ao Runspace
  $iconPathResolved = if ($resolvedIcon) { $resolvedIcon.Path } else { $null }
  $wpfRef = $script:WpfWindow

  # scriptblock que roda dentro do Runspace dedicado
  $trayScript = {
    param($iconPath, $wpfWindow, $dispatcher)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName WindowsBase

    # ── TrayController em C# ──────────────────────────────────────────────
    # Todos os event handlers são delegates C# puros — sem scriptblock PS,
    # sem dependência de Runspace na thread do evento.
    # Referencia assemblies pelos paths absolutos para evitar conflito de versão
    # entre WindowsBase 4.0 (padrão do Add-Type) e 10.0 (PS 7.6)
    $refAssemblies = @(
      [System.Windows.Forms.Form].Assembly.Location,
      [System.Drawing.Color].Assembly.Location,
      [System.Windows.Window].Assembly.Location,
      [System.Windows.UIElement].Assembly.Location,
      [System.Windows.DependencyObject].Assembly.Location,
      [System.ComponentModel.CancelEventArgs].Assembly.Location,
      [System.Windows.Forms.ToolStripMenuItem].Assembly.Location,
      [System.ComponentModel.TypeConverter].Assembly.Location,
      [System.ComponentModel.Component].Assembly.Location,
      [System.Windows.Threading.Dispatcher].Assembly.Location
    )

    Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Windows;
using System.Windows.Forms;
using System.Windows.Threading;

public class TrayController {
    private readonly NotifyIcon        _notify;
    private readonly Window            _window;
    private readonly ToolStripMenuItem _itemAbrir;
    private readonly ToolStripMenuItem _itemSair;
    private readonly Dispatcher        _dispatcher;

    public TrayController(NotifyIcon notify, Window window,
                          ToolStripMenuItem itemAbrir,
                          ToolStripMenuItem itemSair,
                          Dispatcher dispatcher) {
        _notify     = notify;
        _window     = window;
        _itemAbrir  = itemAbrir;
        _itemSair   = itemSair;
        _dispatcher = dispatcher;

        // registra todos os eventos direto em C# — zero scriptblock PS
        _notify.MouseClick += OnMouseClick;
        _itemAbrir.Click   += OnAbrir;
        _itemSair.Click    += OnSair;
    }

    private void OnMouseClick(object sender, MouseEventArgs e) {
        if (e.Button == MouseButtons.Left)
            ShowWindow();
    }

    private void OnAbrir(object sender, EventArgs e) {
        ShowWindow();
    }

    private void OnSair(object sender, EventArgs e) {
        _notify.Visible = false;
        ((System.IDisposable)_notify).Dispose();
        _dispatcher.BeginInvoke(new Action(() => {
            _window.Tag = "exit";
            _window.Close();
        }));
        System.Windows.Forms.Application.Exit();
    }

    private void ShowWindow() {
        _dispatcher.BeginInvoke(new Action(() => {
            _window.Visibility    = Visibility.Visible;
            _window.WindowState   = WindowState.Normal;
            _window.ShowInTaskbar = true;
            _window.Activate();
            _window.Focus();
        }));
    }
}
"@ -ReferencedAssemblies $refAssemblies

    # ── NotifyIcon ────────────────────────────────────────────────────────
    $notify = [System.Windows.Forms.NotifyIcon]::new()
    $notify.Text = "Transparent Window — Clique para abrir"
    $notify.Visible = $true

    if ($iconPath -and (Test-Path $iconPath)) {
      $notify.Icon = [System.Drawing.Icon]::new($iconPath)
    }
    else {
      $notify.Icon = [System.Drawing.SystemIcons]::Application
    }

    # ── Context Menu ──────────────────────────────────────────────────────
    $menu = [System.Windows.Forms.ContextMenuStrip]::new()
    $menu.BackColor = [System.Drawing.Color]::FromArgb(40, 42, 54)
    $menu.ForeColor = [System.Drawing.Color]::FromArgb(248, 248, 242)
    $menu.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System
    $menu.ShowImageMargin = $false

    $itemAbrir = [System.Windows.Forms.ToolStripMenuItem]::new()
    $itemAbrir.Text = "🗔  Abrir"
    $itemAbrir.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $itemAbrir.BackColor = [System.Drawing.Color]::FromArgb(40, 42, 54)
    $itemAbrir.ForeColor = [System.Drawing.Color]::FromArgb(189, 147, 249)

    $separator = [System.Windows.Forms.ToolStripSeparator]::new()

    $itemSair = [System.Windows.Forms.ToolStripMenuItem]::new()
    $itemSair.Text = "✕  Sair"
    $itemSair.Font = [System.Drawing.Font]::new("Segoe UI", 9)
    $itemSair.BackColor = [System.Drawing.Color]::FromArgb(40, 42, 54)
    $itemSair.ForeColor = [System.Drawing.Color]::FromArgb(255, 85, 85)

    $menu.Items.Add($itemAbrir) | Out-Null
    $menu.Items.Add($separator) | Out-Null
    $menu.Items.Add($itemSair)  | Out-Null
    $notify.ContextMenuStrip = $menu

    # ── Instancia TrayController — todos os eventos registrados em C# ───────
    $controller = [TrayController]::new($notify, $wpfWindow, $itemAbrir, $itemSair, $dispatcher)

    # guarda referência global para o Remove-Tray
    $global:_TrayIconRef = $notify

    # inicia message loop
    [System.Windows.Forms.Application]::Run()
  }

  # cria Runspace STA dedicado com contexto PS completo
  $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
  $runspace.ApartmentState = [System.Threading.ApartmentState]::STA
  $runspace.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
  $runspace.Open()

  $ps = [System.Management.Automation.PowerShell]::Create()
  $ps.Runspace = $runspace
  $ps.AddScript($trayScript).AddArgument($iconPathResolved).AddArgument($wpfRef).AddArgument($wpfRef.Dispatcher) | Out-Null

  # BeginInvoke — roda async, não bloqueia a thread principal
  $script:TrayAsync = $ps.BeginInvoke()
  $script:TrayPS = $ps
  $script:TrayRunspace = $runspace

  Write-Verbose "TrayManager: tray iniciado via Runspace STA."
}

# ══════════════════════════════════════════════════════════════════════════════
#  Remove-Tray
#  Encerra o tray e o message loop de forma limpa.
# ══════════════════════════════════════════════════════════════════════════════
function Remove-Tray {
  if ($global:_TrayIconRef) {
    try {
      $global:_TrayIconRef.Visible = $false
      $global:_TrayIconRef.Dispose()
    }
    catch { }
    $global:_TrayIconRef = $null
  }

  try { [System.Windows.Forms.Application]::Exit() } catch { }

  if ($script:TrayPS) {
    try { $script:TrayPS.Stop() } catch { }
    try { $script:TrayPS.Dispose() } catch { }
    $script:TrayPS = $null
  }

  if ($script:TrayRunspace) {
    try { $script:TrayRunspace.Close() } catch { }
    try { $script:TrayRunspace.Dispose() } catch { }
    $script:TrayRunspace = $null
  }

  Write-Verbose "TrayManager: tray encerrado."
}

# ══════════════════════════════════════════════════════════════════════════════
#  exports
# ══════════════════════════════════════════════════════════════════════════════
Export-ModuleMember -Function Initialize-Tray, Remove-Tray
