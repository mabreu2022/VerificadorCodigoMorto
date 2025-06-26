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

📁 Exemplo básico
VerificadorCodigoMorto.exe .\src\



⚙️ Opções disponíveis
| Parâmetro | Exemplo | Descrição | 
| --only= | --only=private,function | Analisa apenas tipos/visibilidades específicos | 
| --ignore= | --ignore=public | Ignora símbolos com visibilidades específicas | 
| --exclude= | --exclude=Test,Mock,On | Ignora nomes que contenham essas palavras | 


Todos os filtros são opcionais e combináveis.


🧪 Exemplo com filtros
VerificadorCodigoMorto.exe .\source\ --only=private,function --ignore=public --exclude=On,Test,dm



📝 Saída
- Console mostra símbolos órfãos: unit, linha e nome
- Gera o arquivo: relatorio_codigo_morto.html
- Relatório HTML é aberto automaticamente se forem encontrados problemas
- Código de saída 1 é retornado para falhar o build se desejado

🤖 Uso com Jenkins
bat 'VerificadorCodigoMorto.exe .\\source\\ > analise.log'

script {
    def log = readFile('analise.log')
    if (log.contains("⚠️")) {
        error('❌ Código morto detectado! Corrija os símbolos antes de continuar.')
    }
}



📁 Arquivos gerados
| Arquivo | Descrição | 
| relatorio_codigo_morto.html | Relatório navegável com todos os símbolos não utilizados | 



🧰 Requisitos
- Delphi (qualquer versão com suporte a SysUtils, IOUtils, ShellAPI)
- Arquivos .pas no diretório informado

Feito com ❤️ para manter seu código limpo, saudável e sem fantasmas esquecidos na arquitetura.

