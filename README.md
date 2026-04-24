# ☁️ Cubotimize — Backup de Aplicações e Dados Qlik Cloud Data Analytics

[![Versão](https://img.shields.io/badge/Versão-3.7.0-2E63E6?style=for-the-badge)](.)
[![Licença](https://img.shields.io/badge/Licença-MIT-3BE854?style=for-the-badge)](.)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell)](.)
[![Qlik Cloud](https://img.shields.io/badge/Qlik-Cloud_Data_Analytics-009845?style=for-the-badge)](.)

Script em PowerShell para automação de dumps/backups de **Aplicativos (.qvf)** e **Arquivos de Dados** (QVD, CSV, XLSX, etc.) do **Qlik Cloud Data Analytics (SaaS)**.

A solução realiza a extração dos ativos de todos os tipos de Space (Managed, Shared, Personal e Data Space), organiza em pastas por tipo e usuário, gerencia a retenção automática de backups antigos e envia um relatório executivo em HTML por e-mail ao final de cada execução.

---

## ⚠️ AVISO IMPORTANTE — Licença por Capacidade (Capacity-Based)

> **Se o seu contrato Qlik Cloud for baseado em Capacidade (Capacity-Based Subscription), leia este aviso com atenção antes de configurar o script.**

O Qlik Cloud mede e limita a movimentação de dados dentro do ciclo de cobrança. A exportação em massa de aplicativos e arquivos de dados **consome cota de capacidade**, podendo impactar o limite do seu plano contratado.

**Recomendações antes de ativar:**

* ✅ Consulte o painel de consumo em `Administração > Monitoramento de Uso` no seu tenant.
* ✅ Planeje a execução em horários de baixo uso (ex: madrugada/final de semana).
* ✅ Use os filtros de inclusão/exclusão disponíveis no script para exportar apenas o que for crítico para DR.
* ✅ Avalie reduzir a frequência do backup (ex: semanal em vez de diário) se a cota for limitada.
* ✅ Certifique-se de ter aprovação da área responsável pelo contrato antes de executar em escala.
* ✅ Monitore o consumo após as primeiras execuções.

---

## 🛡️ Por que este backup é essencial?

> **A Qlik não realiza backup dos seus aplicativos e dados para fins de Disaster Recovery (DR).**

A Qlik Cloud é uma plataforma SaaS gerenciada pela Qlik, porém a **responsabilidade pela cópia de segurança dos ativos analíticos é do cliente**. Em caso de exclusão acidental, corrupção de dados ou qualquer outro incidente, não há garantia de recuperação pela Qlik sem um backup próprio.

Este script resolve justamente essa lacuna, permitindo que sua equipe tenha cópias locais dos aplicativos e arquivos de dados do ambiente Qlik Cloud Data Analytics, prontas para um processo de restauração quando necessário.

---

## ✨ Principais Funcionalidades

* **Exportação de Apps (.qvf):** Faz o dump de todos os aplicativos acessíveis pelo usuário, organizados por tipo de Space (Managed, Shared, Personal).
* **Exportação de Dados:** Baixa arquivos de dados soltos nos spaces (QVD, CSV, XLSX, etc.).
* **Modo Flexível (NoData):** Escolha entre exportar COM dados de carga ou apenas o layout/script do app (`NoData`), reduzindo drasticamente o tamanho dos arquivos.
* **Bypass de SSL Inspection:** Utiliza `curl.exe` nativo para contornar políticas de inspeção SSL em redes corporativas.
* **Mapeamento de Usuários:** Identifica dinamicamente os owners dos Personal Spaces pelo nome do usuário.
* **Filtros Avançados:** Filtre por nome do item, tipo de Space e nome do Space.
* **Exclusões Avançadas:** Exclua por nome, tipo de Space, nome do Space e extensões de arquivo.
* **Gestão de Retenção:** Exclui automaticamente pastas de backup mais antigas que o limite configurado (ex: D-30).
* **Paginação Automática:** Navega por todas as páginas da API, sem limite de itens.
* **Relatório Executivo HTML:** Envia e-mails com design profissional ao iniciar e ao concluir, com resumo por tipo de Space e lista de falhas.
* **Transparência de Privacidade e Filtros:** Contabiliza e exibe na métrica de e-mail os "Apps Ignorados" que não puderam ser baixados devido a regras de privacidade ou filtros ativos.

---

## 🔒 Segurança e Responsabilidade

> **Use este script com responsabilidade.**

Este projeto é disponibilizado sob licença MIT, **sem qualquer garantia expressa ou implícita**. Os autores e a Cubotimize **não se responsabilizam por quaisquer danos, perdas, cobranças excessivas de capacidade ou prejuízos** decorrentes do uso deste script, seja em ambientes de produção, homologação ou desenvolvimento.

Recomendações de segurança:

* 🔐 **Nunca compartilhe sua API Key.** Ela possui as exatas permissões do usuário que a gerou.
* 🔄 **Acompanhe as notas de atualização da Qlik** para mudanças nas APIs utilizadas: [Qlik Cloud Release Notes](https://help.qlik.com/en-US/cloud-services/Subsystems/Hub/Content/Sense_Hub/Introduction/saas-release-notes.htm).
* 🔄 **Acompanhe as atualizações deste script** para incorporar eventuais ajustes de compatibilidade e segurança.
* 🛡️ **Proteja o arquivo `.ps1`** com permissões de leitura restritas ao usuário de serviço que executa o script.
* 🗂️ **Proteja a pasta de backup** com permissões de rede adequadas, evitando acesso não autorizado.

---

## 📋 Pré-requisitos

| Requisito | Detalhe |
|-----------|---------|
| PowerShell | Versão 5.1 ou superior |
| curl.exe | Nativo no Windows 10/Server 2019 ou superior |
| Qlik Cloud | Acesso ativo ao tenant com permissão de geração de API Key. O nível de acesso (ex: Tenant Admin ou Desenvolvedor) definirá o alcance do backup. |
| API Key | Gerada conforme instruções abaixo |
| Rede | Acesso de saída HTTPS (porta 443) ao tenant |

---

## 🔑 Gerando a API Key corretamente

> **Atenção: O escopo do backup depende do criador da chave.**

O script não exige, obrigatoriamente, que o usuário seja um `Tenant Admin`. No entanto, a API Key herda **exatamente as mesmas permissões** do usuário no momento de sua criação. 
* Se você usar a chave de um **Tenant Admin**, fará o backup de praticamente todo o ambiente corporativo. 
* Se usar a chave de um usuário comum (ex: Desenvolvedor), o script fará o backup apenas dos Spaces e Apps que aquele usuário específico tem acesso.

### Passo a passo:

1. Certifique-se de que o usuário possui a permissão adequada para o nível de backup desejado e que tenha a role **Manage API keys** atribuída.
2. Verifique se a geração de API Keys está habilitada no tenant em `Administração > Configurações > Geração de API Key`.
3. No canto superior direito, clique no seu avatar → **Perfil**.
4. Vá até a aba **Tokens de API** e clique em **Gerar novo token**.
5. Dê um nome descritivo (ex: `Cubotimize-Backup`) e defina a validade.

> 💡 **Dica sobre validade do token:** Por padrão, o Qlik Cloud pode definir expiração curta para tokens. Acesse `Administração > Configurações de Segurança > Tokens de API` e **aumente o tempo máximo de vida do token** para reduzir a frequência de renovações (ex: 1 ano). Lembre-se de criar um lembrete para renovação antes do vencimento.

6. Copie a chave gerada e cole na variável `$vApiKey` do script. **Ela só é exibida uma vez.**

---

## ⚙️ Configuração do Script

Abra o arquivo `.ps1` em um editor de texto e ajuste as variáveis na seção de configurações:

### Seção 1 — Autenticação

```powershell
$vTenantUrl = "https://sua-empresa.us.qlikcloud.com"  # Sem barra no final
$vApiKey    = "SUA_APIKEY_AQUI"
```

### Seção 2 — O que exportar

```powershell
$vDumparApps         = $true   # $true para exportar Apps (.qvf)
$vDumparDados        = $false  # $true para exportar Arquivos de Dados
$vDumparAppsSemDados = $true   # $true = layout/script apenas (NoData) — arquivos menores
```

### Seção 3 — Filtros de Inclusão (opcional)

```powershell
$vFiltroNome       = ""          # Ex: "Producao" — exporta só apps com esta palavra no nome
$vFiltroTipoEspaco = ""          # "managed", "shared" ou "personal"
$vFiltroNomeEspaco = ""          # Ex: "Vendas" — exporta só spaces com esta palavra no nome
$vFiltroExtensoes  = @()         # Ex: @(".qvd", ".csv") — aplicado apenas aos Dados
```

### Seção 4 — Exclusões (opcional)

```powershell
$vExcluirNome       = ""         # Ex: "Teste" — ignora apps com esta palavra no nome
$vExcluirTipoEspaco = ""         # Ex: "personal" — ignora todo o Personal Space
$vExcluirNomeEspaco = ""         # Ex: "Homologacao"
$vExcluirExtensoes  = @()        # Ex: @(".tmp", ".log")
```

### Seção 5 — Destino e Retenção

```powershell
$vPastaBackup = "\\SERVIDOR\BACKUP\QLIK\QLIK_CLOUD\$vServidorNome\Dumps\"
$vDiasBackup  = 30    # Backups com mais de 30 dias serão excluídos automaticamente
```

### Seção 6 — E-mail

```powershell
$vEnviarEmail    = $true
$vSmtpServer     = "smtp.gmail.com"
$vSmtpPort       = 587
$vEmailRemetente = "robô@gmail.com"
$vSenhaAppGmail  = "xxxx xxxx xxxx xxxx"   # Senha de Aplicativo de 16 dígitos
$vEmailDestino   = "equipe@empresa.com", "backup@empresa.com"
```

> **Como gerar a Senha de Aplicativo no Google:**
> 1. Acesse [myaccount.google.com](https://myaccount.google.com) → **Segurança**.
> 2. Confirme que a **Verificação em duas etapas** está ativa.
> 3. Pesquise por **"Senhas de app"** e clique na opção.
> 4. Crie um nome (ex: `Script Qlik Backup`) e clique em **Gerar**.
> 5. Cole a senha de 16 caracteres (sem espaços) em `$vSenhaAppGmail`.

---

## 👤 Comportamento nos Personal Spaces — Política de Privacidade

> O Qlik Cloud **restringe o acesso** a apps de Personal Spaces de terceiros por questões de privacidade, mesmo para contas com perfil de Tenant Admin. 

O script trata essa situação de forma elegante e transparente, atuando da seguinte maneira:

* **Espaço "Personal" do gerador da Chave:** Como a API Key atua em nome de quem a criou, **os únicos aplicativos exportados com sucesso do tipo "Personal Space" serão os que pertencem exclusivamente a este usuário** (o dono do token).
* **Espaço "Personal" de Terceiros:** Apps de espaços pessoais de outros usuários não serão baixados. No entanto, o script mapeará o nome do usuário "owner" e o nome do app, registrando a restrição no log de execução para fins de auditoria (`⚠️ IGNORADO`).
* Esse comportamento **não gera erro no processo**, e os itens pulados alimentam de forma automática a métrica **"Apps Ignorados"** no relatório executivo final.

---

## 🗂️ Estrutura de Pastas Gerada

```text
\\SERVIDOR\BACKUP\QLIK\QLIK_CLOUD\NOME-SERVIDOR\Dumps\
└── 2025-07-15\
    ├── __Managed\
    │   └── Nome do Managed Space\
    │       ├── App Financeiro.qvf
    │       └── App RH.qvf
    ├── __Shared\
    │   └── Nome do Shared Space\
    │       └── Dashboard Vendas.qvf
    ├── __Personal\
    │   ├── Mario Sergio Soares\
    │   │   └── Meu App Pessoal.qvf
    │   └── Outro Usuario\
    │       └── (vazio — privacidade)
    ├── __Dados\
    │   └── Nome do Space\
    │       ├── vendas_2025.qvd
    │       └── clientes.csv
    └── backup.log
```

---

## 🚀 Como Agendar no Windows (Task Scheduler)

1. Abra o **Agendador de Tarefas** → **Criar Tarefa...**
2. Na aba **Geral:**
   * Nome: `Backup Qlik Cloud`
   * Clique em **Alterar Usuário ou Grupo** e insira o usuário de serviço com acesso à rede de backup.
   * Marque **"Executar estando o usuário logado ou não"**.
   * Marque **"Executar com privilégios mais altos"**.
3. Na aba **Gatilhos:** configure a recorrência desejada (ex: diariamente às 01:00).
4. Na aba **Ações:**
   * Programa: `powershell.exe`
   * Argumentos: `-ExecutionPolicy Bypass -File "C:\Scripts\Cubotimize_QlikCloud_Backup.ps1"`
5. Salve e informe a senha do usuário de serviço quando solicitado.

---

## 📧 Exemplos de Notificações por E-mail

O script envia dois e-mails automáticos: um ao **iniciar** e outro ao **concluir** o processo.

### ▶️ E-mail de Início

> *[Imagem a ser inserida: screenshot do e-mail de início com badge azul "INICIADO"]*

```text
[Cubotimize] ▶️ INICIADO - Dump Qlik Cloud (NOME-SERVIDOR)
```

### ✅ E-mail de Conclusão com Sucesso

> *[Imagem a ser inserida: screenshot do e-mail de conclusão com badge verde "CONCLUÍDO COM SUCESSO", tabela de resumo e seções por tipo de Space]*

```text
[Cubotimize] ✅ CONCLUÍDO COM SUCESSO - Dump Qlik Cloud (NOME-SERVIDOR)
```

### ⚠️ E-mail de Conclusão com Falhas

> *[Imagem a ser inserida: screenshot do e-mail de conclusão com badge vermelho "CONCLUÍDO COM FALHAS", seção de alertas e lista de itens que falharam]*

```text
[Cubotimize] ⚠️ CONCLUÍDO COM FALHAS - Dump Qlik Cloud (NOME-SERVIDOR)
```

O relatório final inclui:
* Resumo executivo com contadores totais
* Métrica de **⚠️ Apps Ignorados (Filtros + Privacidade)**
* Seção 🔴 Apps por Managed Space
* Seção 🔵 Apps por Shared Space
* Seção 👤 Apps por Personal Space (usuário owner)
* Seção 🟣 Arquivos de Dados por Space
* Lista detalhada de falhas com nome do item, ID e descrição técnica do erro
* Log completo em anexo (`backup.log`)

---

## 👨‍💻 Autor e Contatos

**Mario Sergio Soares**

* 🌐 **Bio Page & Projetos:** [cubo.plus/mariosergioti](https://cubo.plus/mariosergioti)
* 💼 **LinkedIn:** [linkedin.com/in/mariosergioti](https://linkedin.com/in/mariosergioti)
* 🏢 **Empresa:** [Cubotimize](https://cubotimize.com)
* 📸 **Instagram:** [https://www.instagram.com/mariosoares_ti/](https://www.instagram.com/mariosoares_ti/)
* 📊 **Mais Materiais Qlik:** [Publicações na Qlik Community](https://community.qlik.com/t5/Brasil/Publica%C3%A7%C3%B5es-de-MARIO-SOARES-Documentos-Aplicativos-e-Arquivos/td-p/1464214)
