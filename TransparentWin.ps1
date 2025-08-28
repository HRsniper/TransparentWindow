Import-Module "$PSScriptRoot\WinAPI.psm1"
Import-Module "$PSScriptRoot\WindowTools.psm1"
Import-Module "$PSScriptRoot\WindowManager.psm1"

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
  $selectedWindowHandle = if ($selectedWindow.MainWindowHandle -eq [IntPtr]::Zero) {
    Get-UWPWindowHandle $selectedWindow
  }
  else {
    Get-WindowHandle $selectedWindow
  }

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
