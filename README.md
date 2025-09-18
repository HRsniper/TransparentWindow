# Transparent Window 🎨✨

> **Um utilitário de PowerShell 7 que aplica transparência, top‑most e modo passivo a janelas do Windows.**

| ⭐  | Funcionalidades                         |
| --- | --------------------------------------- |
| 0   | **Sair**                                |
| 1   | **Aplicar transparência**               |
| 2   | **Sempre no topo (topmost)**            |
| 3   | **Desfazer sempre no topo (topmost)**   |
| 4   | **Modo passivo (fixo + click‑through)** |
| 5   | **Desfazer modo passivo**               |

## 💻 Requisitos

| Requisito      | Versão mínima                                    |
| -------------- | ------------------------------------------------ |
| **Windows**    | 10 (1803) ou superior                            |
| **PowerShell** | 7.0+                                             |
| **Console**    | Windows Terminal (recomendado) ou qualquer outro |

## Uso Rápido

#### Execute:

```ps1
./TransparentWindow.ps1
```

#### Fazendo um atalho:

- Se voce ja tem o [PowerShell 7](https://github.com/PowerShell/PowerShell)
- Pegando o caminho `Get-Command pwsh | Select-Object Source`
- Click direito > Novo > Atalho
- Local do item: `"`caminho do powershell 7`"` `"`caminho do TransparentWindow.ps1`"`
- Avançar > Nome do atalho > Concluir

#### O menu aparecerá:

```
╔════════════════════════════╗
║  ◩ Gerenciador de Janelas  ║
╚════════════════════════════╝

[0]  Sair
[1]  Aplicar transparência
[2]  Fixar no topo
[3]  Desafixar do topo
[4]  Fixar no topo (modo passivo)
[5]  Desafixar do topo (modo passivo)

↑ Escolha uma opção:
```

Siga as instruções interativas – o script exibe a lista de janelas visíveis e permite a aplicação em cada uma separadamente.

## 🆘 Problemas Comuns

| Problema             | Causa provável                       | Solução                                                                                                                                |
| -------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Erro “Access denied” | Policy de execução está “Restricted” | Vai no arquivos `TransparentWin.ps1`, `WinAPI.psm1`, `WindowManager.psm1`, `WindowTools.psm1` copia e cola com salvando com mesmo nome |

## 📜 Licença

- [License](LICENSE) – Liberdade total

## 📢 Referência

- [Microsoft Docs](https://learn.microsoft.com/en-us/windows/win32/api/winuser/)
