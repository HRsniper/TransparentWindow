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

| Requisito      | Versão mínima                                                     |
| -------------- | ----------------------------------------------------------------- |
| **Windows**    | 10 (1803) ou superior                                             |
| **PowerShell** | 7.0+                                                              |
| **Console**    | Windows Terminal (recomendado) ou outro que suporte emoji Unicode |

## Uso Rápido

#### Execute:

```ps1
./TransparentWindow.ps1
```

#### O menu aparecerá:

```
╔════════════════════════════════════════╗
║   🖥️ Gerenciador de Janelas Windows    ║
╚════════════════════════════════════════╝

0️⃣  Sair
1️⃣  Aplicar transparência
2️⃣  Fixar no topo
3️⃣  Desafixar do topo
4️⃣  Fixar no topo (modo passivo)
5️⃣  Desafixar do topo (modo passivo)

⬆️  Escolha uma opção:
```

Siga as instruções interativas – o script exibe a lista de janelas visíveis e permite a aplicação em cada uma separadamente.

> **Dica**: Se estiver usando _Windows Terminal_, e se quiser ver os emoji, habilite o conjunto de fontes recomendado (`Segoe UI`). A ordem dos números caso queria usar como esta é `0 1 2 3 4 5 6 7 8 9`.

## 🆘 Problemas Comuns

| Problema             | Causa provável                       | Solução                                                                                                                                |
| -------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Erro “Access denied” | Policy de execução está “Restricted” | Vai no arquivos `TransparentWin.ps1`, `WinAPI.psm1`, `WindowManager.psm1`, `WindowTools.psm1` copia e cola com salvando com mesmo nome |

## 📜 Licença

- [License](LICENSE) – Liberdade total

## 📢 Referência

- [Microsoft Docs](https://learn.microsoft.com/en-us/windows/win32/api/winuser/)
