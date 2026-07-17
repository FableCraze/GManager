# GManager

Gerenciador de guildas com interface moderna para **World of Warcraft: Wrath of the Lich King 3.3.5a**.

O GManager reúne ferramentas de administração, consulta de membros, convites, recrutamento, organização de raids e remoção em massa em uma única interface. O addon foi desenvolvido usando apenas a API nativa do cliente e **não depende de Ace3, LibDataBroker ou LibDBIcon**.

![WoW](https://img.shields.io/badge/WoW-3.3.5a-9b6a22)
![Interface](https://img.shields.io/badge/Interface-30300-4c8bf5)
![Lua](https://img.shields.io/badge/Lua-nativo-2c2d72)
![Dependências](https://img.shields.io/badge/dependências-nenhuma-2ea44f)

## Recursos

### Visão geral

- Nome da guilda e rank do personagem atual.
- Total de membros.
- Quantidade de membros online.
- Quantidade de personagens nível 80 online.
- Distribuição de membros por classe.
- Atualização manual do roster.

### Lista de membros

- Busca por nome, rank, zona e notas.
- Filtro para mostrar apenas membros online.
- Classe, nível, rank, zona e DKP.
- Convite para grupo diretamente pela lista.
- Atalho para abrir um sussurro.
- Cores de classe e indicador de presença online.
- Lista rolável com atualização automática.

### Convidar e editar membros

- Convite de novos jogadores para a guilda.
- Consulta de personagens já cadastrados.
- Alteração de rank.
- Edição de nota pública.
- Edição de nota de oficial.
- Promoção e rebaixamento gradual usando as APIs nativas do jogo.

### Kickar personagens

- Lista com checkbox para seleção individual.
- Kick em massa com confirmação.
- Busca por nome, rank, classe, zona e notas.
- Coluna com o tempo desde o último login.
- Filtro para mostrar apenas jogadores inativos.
- Seleção do período mínimo de inatividade.
- Seleção de todos os personagens filtrados.
- Proteção contra remoção do Guild Master e do próprio personagem.
- Processamento em fila para evitar várias chamadas simultâneas.

Os períodos disponíveis para o filtro de inatividade incluem:

- 1, 7, 15 e 30 dias.
- 60, 90 e 180 dias.
- 365 dias.

### Montador de grupos e raids

- Convite em massa de membros online.
- Opção para convidar apenas personagens nível 80.
- Atraso configurável antes do início dos convites.
- Palavra-chave para autoconvite pelo chat da guilda ou sussurro.
- Mensagem adicional de anúncio.
- Reanúncio manual.
- Fila gradual de convites.
- Conversão de grupo para raid.
- Seleção de dificuldade:
  - 10 jogadores — Normal.
  - 25 jogadores — Normal.
  - 10 jogadores — Heroico.
  - 25 jogadores — Heroico.
- Opção para desfazer o grupo.

### Recrutamento

- Mensagem configurável para canais públicos.
- Número do canal configurável.
- Envio periódico automático.
- Intervalo mínimo de 68 segundos.
- Indicador de estado e tempo para o próximo envio.
- Botões separados para iniciar e interromper o recrutamento.

> Use os anúncios automáticos de acordo com as regras do servidor e evite mensagens repetitivas em excesso.

### Configurações

- Mostrar ou ocultar o botão do minimapa.
- Arrastar e reposicionar o botão do minimapa.
- Bloquear a posição da janela.
- Centralizar a janela.
- Restaurar a posição do botão do minimapa.
- Atualizar o roster manualmente.
- Restaurar as configurações padrão.
- Configurações persistentes por meio de `GManagerDB`.

## Compatibilidade

| Item | Compatibilidade |
|---|---|
| Cliente | World of Warcraft 3.3.5a |
| Interface | `30300` |
| Linguagem | Lua |
| Dependências externas | Nenhuma |
| Ace3 | Não necessário |
| LibDataBroker | Não necessário |
| LibDBIcon | Não necessário |

O addon foi projetado para o cliente WotLK 3.3.5a. Alguns servidores privados podem modificar APIs, permissões ou comportamentos do cliente.

## Instalação

1. Baixe ou clone este repositório.
2. Coloque a pasta `GManager` em:

```text
World of Warcraft\Interface\AddOns\
```

3. A estrutura deverá ficar assim:

```text
World of Warcraft
└── Interface
    └── AddOns
        └── GManager
            ├── GManager.toc
            └── CORE.lua
```

4. Abra o jogo.
5. Na tela de personagens, clique em **AddOns**.
6. Confirme que o GManager está ativado.
7. Entre no jogo e use `/gmgr`.

Caso o cliente informe que o addon está desatualizado, marque **Load out of date AddOns / Carregar AddOns desatualizados** e confirme que o `.toc` contém `## Interface: 30300`.

## Arquivo `.toc`

Exemplo de `GManager.toc`:

```toc
## Interface: 30300
## Title: GManager
## Notes: Gerenciador de guildas nativo para WoW 3.3.5a
## Author: Valber Lima
## Version: 3.1.0
## SavedVariables: GManagerDB

CORE.lua
```

## Comandos

| Comando | Ação |
|---|---|
| `/gmgr` | Abre ou fecha a interface |
| `/gmanager` | Abre ou fecha a interface |
| `/guildmanager` | Abre ou fecha a interface |
| `/gmgr roster` | Abre diretamente a lista de membros |
| `/gmgr members` | Abre diretamente a lista de membros |
| `/gmgr settings` | Abre diretamente as configurações |
| `/gmgr config` | Abre diretamente as configurações |
| `/gmgr hide` | Fecha a janela |

O addon também pode ser aberto pelo botão do minimapa.

## Permissões da guilda

O GManager não ignora as permissões definidas pelo jogo. Cada ação continua dependendo do rank e das permissões do personagem conectado.

Podem exigir permissões específicas:

- Convidar jogadores.
- Remover membros.
- Promover ou rebaixar.
- Editar nota pública.
- Editar nota de oficial.
- Converter ou controlar uma raid.

Quando uma ação não for permitida pelo servidor, o cliente poderá ignorar a chamada ou apresentar uma mensagem de erro.

## Último login e jogadores inativos

O tempo offline é obtido pela API nativa `GetGuildRosterLastOnline`.

O cliente fornece o período separado em anos, meses, dias e horas. Para permitir o filtro, o addon converte esses valores em uma quantidade aproximada de dias.

Por esse motivo:

- O valor exibido não deve ser interpretado como uma data exata.
- Membros online aparecem como `Online`.
- Quando o servidor não fornece o valor, o addon mostra que a informação está indisponível.
- O filtro considera apenas membros offline com tempo conhecido.

Revise sempre a seleção antes de confirmar um kick em massa.

## Recrutamento automático

O primeiro anúncio é enviado ao iniciar o recrutamento. Os próximos envios respeitam o intervalo configurado.

O intervalo mínimo aplicado pelo addon é:

```text
68 segundos
```

O número do canal corresponde à posição atual do canal na lista de chat do personagem. Por exemplo, o canal Global pode não possuir o mesmo número para todos os personagens ou servidores.

## Autoconvite

O autoconvite funciona somente enquanto a sessão de convite em massa estiver ativa.

Fluxo:

1. Um administrador pressiona **Iniciar**.
2. O addon anuncia a palavra-chave configurada.
3. Um jogador envia a palavra-chave exata no chat da guilda ou por sussurro.
4. O addon envia o convite.
5. Pedidos recebidos durante a contagem regressiva aguardam o atraso configurado.

A função usa apenas eventos e APIs nativas do cliente.

## Dados salvos

As configurações são armazenadas em:

```text
WTF\Account\<CONTA>\SavedVariables\GManager.lua
```

A tabela principal utilizada é:

```lua
GManagerDB
```

Para restaurar tudo manualmente, feche o jogo e remova o arquivo de SavedVariables. Também é possível usar o botão **Restaurar configurações padrão** dentro do addon.

## API pública

Outros addons ou macros Lua podem acessar a tabela global `GManager`.

```lua
GManager:Show()
GManager:Show("roster")
GManager:Show("settings")
GManager:Hide()
GManager:Refresh()
```

Páginas disponíveis:

```text
overview
roster
member
remove
raid
recruit
settings
```

## Segurança

- O addon não executa arquivos externos.
- Não realiza conexões de rede.
- Não exige executável ou launcher.
- Não altera arquivos do cliente.
- Não contém Ace3 nem outras bibliotecas incorporadas.
- Todas as ações são realizadas pelas APIs Lua disponibilizadas pelo WoW.

O usuário continua responsável por seguir as regras do servidor em que estiver jogando.

## Limitações conhecidas

- Servidores privados podem modificar ou desativar APIs.
- Rank e notas dependem das permissões do personagem.
- O último login é um período aproximado, não uma data absoluta.
- O número dos canais públicos pode variar.
- Convites podem falhar quando o grupo ou a raid estiver cheio.
- Algumas ações protegidas podem exigir interação manual dependendo do cliente.
- Alterações no roster podem levar alguns instantes para aparecer.

## Desenvolvimento

O projeto foi escrito para Lua e para a API do WoW 3.3.5a.

Não são necessárias dependências externas para editar o código. Para testar:

1. Copie a pasta para `Interface\AddOns`.
2. Execute `/reload` após alterações.
3. Verifique erros Lua com:

```text
/console scriptErrors 1
/reload
```

Para desativar novamente:

```text
/console scriptErrors 0
/reload
```

## Contribuições

Pull requests e relatórios de problemas são bem-vindos.

Ao abrir uma issue, inclua:

- Descrição do problema.
- Passos para reproduzir.
- Mensagem completa do erro Lua.
- Servidor e versão do cliente.
- Captura de tela, quando aplicável.
- Alterações feitas no `CORE.lua`.

## Changelog

### 3.1.0

- Interface nativa sem Ace3.
- Lista moderna de membros.
- Convite e edição de membros.
- Convite em massa com atraso e fila.
- Autoconvite por palavra-chave.
- Controle de dificuldade de raid.
- Recrutamento automático.
- Kick em massa com checkboxes.
- Filtro de jogadores inativos.
- Coluna de último login.
- Configurações persistentes.
- Botão nativo no minimapa.

## Aviso

GManager é um projeto independente e não possui afiliação oficial com Blizzard Entertainment, Warmane ou outros servidores privados.

World of Warcraft e seus respectivos nomes e marcas pertencem aos seus proprietários.
