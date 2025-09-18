# Verifica se o sistema operacional é compatível (Windows 10 ou superior)
function Check-WindowsVersion {
  $osVersion = [System.Environment]::OSVersion.Version
  if ($osVersion.Major -lt 10) {
    Show-Error "Este script requer Windows 10 ou superior."
    exit
  }
}


# Obtém a lista de janelas visíveis, excluindo processos críticos do sistema
function Get-VisibleWindows {
  $excludedProcesses = @("System", "Idle", "explorer", "svchost", "wininit", "services", "lsass", "csrss", "smss", "winlogon", "TextInputHost")
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
  # lista de janelas visíveis, percorre cada janela e extrai o comprimento do nome do processo ou do título da janela,
  # calcula o maior valor entre esses comprimentos e extrai o número final
  $maxProcessLength = ($windowList | ForEach-Object { $_.ProcessName.Length } | Measure-Object -Maximum).Maximum
  $maxTitleLength = ($windowList | ForEach-Object { $_.MainWindowTitle.Length } | Measure-Object -Maximum).Maximum

  $formatMask = "{0,-4} {1,-$maxProcessLength} {2,-$maxTitleLength}"

  Write-Host "`n🪟  Janelas Visíveis:" -ForegroundColor Yellow

  for ($i = 0; $i -lt $windowList.Count; $i++) {
    $window = $windowList[$i]
    $emojiIndex = Convert-ToEmojiNumber $i
    $processName = $window.ProcessName
    $windowTitle = if ($window.MainWindowTitle) { $window.MainWindowTitle } else { "[Sem título]" }

    Write-Host ($formatMask -f "$emojiIndex", "$processName", "$windowTitle") -ForegroundColor Gray
  }

  Write-Host "`n🔢  Total de janelas visíveis: $($windowList.Count)" -ForegroundColor DarkGray
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

# Exibe o menu principal com opções de ação
function Show-MainMenu {
  # Clear-Host
  $title = "🖥️  Gerenciador de Janelas Windows"
  $border = "═" * ($title.Length + 4)
  $padding = (($border.Length - $title.Length) / 2) + 1
  $titleLine = (" " * [Math]::Floor($padding)) + $title + (" " * [Math]::Ceiling($padding))

  Write-Host "╔$border╗" -ForegroundColor Cyan
  Write-Host "║$titleLine║" -ForegroundColor Cyan
  Write-Host "╚$border╝" -ForegroundColor Cyan
  Write-Host ""

  $menuItems = @(
    @{ Key = "0"; Label = "Sair" },
    @{ Key = "1"; Label = "Aplicar transparência" },
    @{ Key = "2"; Label = "Fixar no topo" },
    @{ Key = "3"; Label = "Desafixar do topo" },
    @{ Key = "4"; Label = "Fixar no topo (modo passivo)" },
    @{ Key = "5"; Label = "Desafixar do topo (modo passivo)" }
  )

  foreach ($item in $menuItems) {
    $emojiKey = Convert-ToEmojiNumber $item.Key
    Write-Host "$emojiKey  $($item.Label)" -ForegroundColor White
  }

  # Captura e valida entrada do usuário
  $validOptions = $menuItems.Key
  do {
    $option = Read-Host "`n⬆️  Escolha uma opção"
    if ($validOptions -notcontains $option) {
      Show-Error "Opção inválida. Digite um número entre 0 e 5."
    }
  } while ($validOptions -notcontains $option)

  return $option
}
