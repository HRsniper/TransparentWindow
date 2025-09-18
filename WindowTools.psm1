# Constantes utilizadas pelas funções da API do Windows
$GWL_EXSTYLE = -20                # Índice para estilo estendido da janela
$WS_EX_LAYERED = 0x80000          # Permite aplicar efeitos visuais como transparência
$WS_EX_TRANSPARENT = 0x20         # Permite que a janela seja clicável através de áreas transparentes (modo passivo)
$LWA_ALPHA = 0x2                  # Define que a opacidade será aplicada via canal alpha

$HWND_TOPMOST = [IntPtr]::op_Explicit(-1)    # Handle especial para manter janela no topo
$HWND_NOTOPMOST = [IntPtr]::op_Explicit(-2)  # Handle para remover "sempre no topo"
$HWND_BOTTOM = [IntPtr]::op_Explicit(1)      # Handle correto para enviar janela para o fundo
$HWND_NORMAL = [IntPtr]::Zero

$SWP_NOMOVE = 0x0002              # Não altera posição da janela
$SWP_NOSIZE = 0x0001              # Não altera tamanho da janela
$SWP_SHOWWINDOW = 0x0040          # Garante que a janela será exibida após alteração
$SWP_NOZORDER = 0x0004            # Não altera ordem Z (adicionado para fix)
$SWP_FRAMECHANGED = 0x0020        # Notifica mudança de frame/estilo (NOVO: essencial para DWM)

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

function Get-UWPWindowHandle($process) {
  $processId = $process.Id
  $handles = [WinAPI]::GetWindowsByProcessId($processId)
  if ($handles.Count -eq 0) {
    Show-Error "⨉ Nenhuma janela visível encontrada para o processo UWP"
    return $null
  }

  # Retorna o primeiro handle com título válido
  foreach ($hWnd in $handles) {
    if ([WinAPI]::IsWindow($hWnd)) {
      # NOVO: Verifica se o handle é válido
      $title = [WinAPI]::GetWindowTitle($hWnd)
      if (-not [string]::IsNullOrWhiteSpace($title)) {
        Write-Host "◧ Janela detectada: '$title'" -ForegroundColor DarkGray
        return $hWnd
      }
    }
  }

  Show-Error "⨉ Não foi possível identificar uma janela com título válido."
  return $null
}

# Obtém o identificador da janela (HWND) do processo selecionado
function Get-WindowHandle($process) {
  try {
    $handle = [IntPtr]$process.MainWindowHandle
    if ($handle -eq [IntPtr]::Zero) {
      throw "⨉ Janela não possui MainWindowHandle."
    }
    # NOVO: Verifica validade
    if (-not [WinAPI]::IsWindow($handle)) {
      throw "⨉ Handle inválido ou janela não existe mais."
    }
    Write-Host "◧ Handle obtido: '$($process.ProcessName)'" -ForegroundColor DarkGray
    return $handle
  }
  catch {
    Show-Error "⨉ Erro ao obter HWND." $_
    return $null
  }
}

function Set-WindowTransparency ($windowHandle, [byte]$opacityValue, [string]$Mode = "normal") {
  try {
    # NOVO: Verifica se o handle é válido
    if (-not [WinAPI]::IsWindow($windowHandle)) {
      throw "⨉ Handle de janela inválido ou não existe."
    }

       # Obtém os estilos estendidos atuais da janela
    $style = [WinAPI]::GetWindowLongPtr($windowHandle, $GWL_EXSTYLE)

    # Se o modo for "passive", adiciona WS_EX_TRANSPARENT para ignorar cliques
    if ($Mode -eq "passive") {
      $newStyle = $style -bor $WS_EX_TRANSPARENT
    }
    # Remove o estilo WS_EX_TRANSPARENT se estiver presente
    elseif ($Mode -eq "removeTransparent") {
      $newStyle = $style -band (-bnot $WS_EX_TRANSPARENT)
    }
    else {
      $newStyle = $style
    }

    # Aplica transparência apenas se a janela já for camada (layered) ou se não for modo de remoção
    if (($newStyle -band $WS_EX_LAYERED) -ne 0 -or $Mode -eq "removeTransparent") {
      [WinAPI]::SetWindowLongPtr($windowHandle, $GWL_EXSTYLE, $newStyle) | Out-Null
    }
    else {
      # Se não for layered, adiciona o estilo apenas para aplicar transparência
      $newStyle = $newStyle -bor $WS_EX_LAYERED
      [WinAPI]::SetWindowLongPtr($windowHandle, $GWL_EXSTYLE, $newStyle) | Out-Null
    }

    # Aplica o nível de opacidade usando canal alpha
    [WinAPI]::SetLayeredWindowAttributes($windowHandle, 0, $opacityValue, $LWA_ALPHA) | Out-Null

    # NOVO: Notifica DWM da mudança de estilo com FRAMECHANGED (corrige propagação global)
    $windowFlags = $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_NOZORDER -bor $SWP_FRAMECHANGED
    [WinAPI]::SetWindowPos($windowHandle, $HWND_NORMAL, 0, 0, 0, 0, $windowFlags) | Out-Null

    # NOVO: Força atualização visual da janela (evita artefatos)
    [WinAPI]::UpdateWindow($windowHandle) | Out-Null

    return $true
  }
  catch {
    Show-Error "⨉ Erro ao aplicar transparência via WinAPI." $_
    return $false
  }
}

function Select-OpacityLevel {
  # Usa a variável global de opacidade
  $options = $Global:opacityOptions

  # Exibe opções para o usuário
  Write-Host "`n◐ Escolha o nível de opacidade:" -ForegroundColor Cyan
  for ($i = 0; $i -lt $options.Count; $i++) {
    $emojiIndex = Convert-ToEmojiNumber $i
    $percentage = $options[$i].Percentage
    Write-Host "$emojiIndex  $percentage" -ForegroundColor Gray
  }

  # Captura entrada do usuário
  $selectedOpacityIndex = Read-Host "`n⫻ Digite o número da opacidade desejada ou pressione Enter para usar padrão (50%)"

  # Se vazio, retorna diretamente o objeto padrão (50%)
  if ([string]::IsNullOrWhiteSpace($selectedOpacityIndex)) {
    Write-Host "⫻ Usando opacidade padrão: 50%" -ForegroundColor Yellow
    return $Global:opacityOptions[4]
  }

  # Valida entrada
  if ($selectedOpacityIndex -notmatch '^\d+$' -or [int]$selectedOpacityIndex -lt 0 -or [int]$selectedOpacityIndex -ge $options.Count) {
    Show-Error "⨉ Índice inválido. Tente novamente."
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
    if (Set-WindowTransparency $windowHandle $opacityValue) {
      Write-Host "`n✓ Transparência aplicada à janela '$windowTitle' com opacidade $opacityText." -ForegroundColor Green
    }
  }
  catch {
    Show-Error "⨉ Falha ao aplicar transparência." $_
  }
}

# Define a janela como "sempre no topo" (topmost)
function Apply-TopMost($windowHandle, $windowTitle) {
  try {
    # NOVO: Adiciona FRAMECHANGED para consistência
    $topMostFlags = $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW -bor $SWP_FRAMECHANGED
    [WinAPI]::SetWindowPos($windowHandle, $HWND_TOPMOST, 0, 0, 0, 0, $topMostFlags) | Out-Null
    [WinAPI]::ShowWindow($windowHandle, 5) | Out-Null  # SW_SHOW = 5
    Write-Host "`n↪ Janela '$windowTitle' fixada no topo." -ForegroundColor Green
  }
  catch {
    Show-Error "⨉ Falha ao fixar no topo com transparência interativa." $_
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
    Write-Host "◯ Modo passivo ativado: janela '$windowTitle' não captura cliques." -ForegroundColor DarkGray
  }
  catch {
    Show-Error "⨉ Erro ao aplicar modo passivo no topo." $_
  }
}

# Função para desfazer "sempre no topo"
function Undo-TopMost($windowHandle, $windowTitle) {
  try {
    # Remove o estilo "sempre no topo", sem alterar posição ou tamanho
    $undoTopMostFlags = $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW -bor $SWP_FRAMECHANGED  # NOVO: Adiciona FRAMECHANGED
    [WinAPI]::SetWindowPos($windowHandle, $HWND_NOTOPMOST, 0, 0, 0, 0, $undoTopMostFlags) | Out-Null
    # Envia a janela para o fundo
    [WinAPI]::SetWindowPos($windowHandle, $HWND_BOTTOM, 0, 0, 0, 0, $undoTopMostFlags) | Out-Null
    # Minimiza a janela após enviá-la para o fundo
    [WinAPI]::ShowWindow($windowHandle, 6) | Out-Null  # SW_MINIMIZE = 6
    Write-Host "`n↩ 'Sempre no topo' desfeito, janela enviada para baixo e minimizada: '$windowTitle'." -ForegroundColor Green
  }
  catch {
    Show-Error "⨉ Falha ao desfazer 'sempre no topo'." $_
  }
}

function Undo-PassiveTopMost($windowHandle, $windowTitle) {
  try {
    # Remove WS_EX_TRANSPARENT e restaura opacidade total
    $opacityIn100Percent = $Global:opacityOptions[9].Value
    Set-WindowTransparency $windowHandle $opacityIn100Percent "removeTransparent"

    Undo-TopMost $windowHandle $windowTitle

    # Exibe mensagem de sucesso
    Write-Host "`n◯ Modo passivo desfeito. Janela '$windowTitle' voltou ao comportamento normal." -ForegroundColor DarkGray
  }
  catch {
    # Exibe mensagem de erro em caso de falha
    Show-Error "⨉ Erro ao desfazer modo passivo." $_
  }
}

# Função centralizada para exibir mensagens de erro
function Show-Error($message, $detail = $null) {
  Write-Host "`n⨉ $message" -ForegroundColor Red
  if ($detail) {
    Write-Host "    Detalhe: $detail" -ForegroundColor DarkRed
  }
}
