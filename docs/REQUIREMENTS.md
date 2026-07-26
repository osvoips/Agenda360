# Requisitos — Agenda360 (MVP)

Este documento formaliza os requisitos funcionais e não funcionais da
primeira versão (MVP) do Agenda360, com o piloto Carioca Barbearia como
referência. Requisitos são descritos por ator. IDs seguem o padrão
`RF-<ATOR>-NN` (requisito funcional) e `RNF-NN` (não funcional).

## 1. Ator: Cliente Final

Acesso via aplicativo White Label do tenant, **sem cadastro e sem senha**.

| ID | Requisito |
|---|---|
| RF-CLI-01 | O sistema deve permitir que o cliente informe nome e telefone para iniciar um agendamento. |
| RF-CLI-02 | O sistema deve permitir que o cliente escolha um serviço dentre os cadastrados pelo tenant. |
| RF-CLI-03 | O sistema deve permitir que o cliente escolha um profissional (barbeiro) dentre os disponíveis para o serviço escolhido. |
| RF-CLI-04 | O sistema deve exibir apenas horários realmente disponíveis, considerando duração do serviço, agenda do profissional e horário de funcionamento do tenant. |
| RF-CLI-05 | O sistema deve permitir que o cliente confirme o agendamento após escolher serviço, profissional e horário. |
| RF-CLI-06 | O sistema deve permitir que o cliente cancele um agendamento, desde que dentro do prazo mínimo definido pelo tenant (ex.: até 2h antes). |
| RF-CLI-07 | O sistema não deve exigir criação de conta, senha ou verificação por e-mail para agendar. |
| RF-CLI-08 | O fluxo completo de agendamento (do início à confirmação) deve ser executável em até 30 segundos em condições normais de uso. |

## 2. Ator: Barbearia (operação do dia a dia)

Acesso autenticado, escopado ao próprio tenant.

| ID | Requisito |
|---|---|
| RF-BAR-01 | O sistema deve exibir a agenda do dia, com todos os agendamentos, horários, clientes e profissionais envolvidos. |
| RF-BAR-02 | O sistema deve exibir a agenda semanal, permitindo navegação entre dias. |
| RF-BAR-03 | O sistema deve permitir confirmar a presença do cliente em um agendamento. |
| RF-BAR-04 | O sistema deve permitir cancelar um atendimento, com registro do motivo (opcional). |
| RF-BAR-05 | O sistema deve permitir bloquear horários específicos (ex.: almoço, folga, imprevisto) para um ou mais profissionais. |
| RF-BAR-06 | O sistema deve permitir configurar os dias e horários de funcionamento do tenant. |

## 3. Ator: Administrador

Acesso autenticado com permissões de gestão sobre o tenant.

| ID | Requisito |
|---|---|
| RF-ADM-01 | O sistema deve permitir cadastrar, editar e desativar profissionais (barbeiros). |
| RF-ADM-02 | O sistema deve permitir cadastrar, editar e desativar serviços, incluindo nome e duração (tempo em minutos). |
| RF-ADM-03 | O sistema deve permitir cadastrar horários de funcionamento por dia da semana. |
| RF-ADM-04 | O sistema deve permitir cadastrar promoções associadas a serviços. |
| RF-ADM-05 | O sistema deve permitir visualizar a agenda completa do tenant (todos os profissionais, todos os horários). |
| RF-ADM-06 | Toda ação de cadastro/edição deve ficar restrita aos dados do próprio tenant do administrador logado. |

## 4. Requisitos Não Funcionais

| ID | Requisito |
|---|---|
| RNF-01 | **Multi-tenancy:** nenhum dado de um tenant pode ser acessível, direta ou indiretamente, por outro tenant. |
| RNF-02 | **White Label:** nenhuma tela do app do cliente final pode exibir a marca "Agenda360" — apenas a marca do tenant. |
| RNF-03 | **Desempenho:** listagem de horários disponíveis deve responder em até 1s sob carga normal. |
| RNF-04 | **Disponibilidade:** o fluxo de agendamento do cliente é a funcionalidade crítica do sistema — deve ter a maior prioridade de disponibilidade entre todos os módulos. |
| RNF-05 | **Plataformas:** o app do cliente e o painel administrativo devem funcionar em Android, iOS e Web a partir da mesma base de código (Flutter). |
| RNF-06 | **Extensibilidade de domínio:** o modelo de dados não deve conter conceitos exclusivos de barbearia em nível de schema (ex.: usar `professional`/`service` genéricos), permitindo reuso direto para outros segmentos. |
| RNF-07 | **Idioma:** interfaces em português (pt-BR) na v1. |

## 5. Fora de Escopo no MVP

Explicitamente adiado para versões futuras (ver [ROADMAP.md](ROADMAP.md)):

- Pagamento via PIX, cartão ou dentro do aplicativo.
- Verificação de telefone via SMS/WhatsApp.
- Notificações push/SMS automáticas de lembrete.
- Módulo de IA (sugestão de horários, previsão de no-show, chatbot).
- Multi-idioma.
- Métricas/relatórios avançados para o administrador.
