# 🧼 Verificador de Código Morto

Utilitário console em Delphi para detectar funções e procedures não utilizadas em arquivos `.pas`. Ele gera um relatório HTML e pode ser integrado ao seu processo de build contínuo (CI) com ferramentas como o Jenkins.

---

## 🚀 Funcionalidades

- Detecta `procedure` e `function` não utilizadas
- Filtros personalizáveis via linha de comando
- Gera relatório completo em HTML
- Abre o relatório automaticamente no navegador se erros forem encontrados
- Retorna `ExitCode = 1` para integração com CI/CD
- Simples, rápido e leve

---

## 📥 Como usar

```bash
VerificadorCodigoMorto.exe <diretório> [opções]
