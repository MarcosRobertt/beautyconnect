# BeautyConnect — Sprint 1 (Flutter Web)

MVP para uma única manicure: Dashboard, Cadastro de Clientes e Agenda, 100% local
(sem servidor, sem login), com persistência em IndexedDB via Hive e backup/restauração
manual em JSON.

## 🚀 Deployment Rápido (GitHub Pages)

**Apenas 3 passos:**

1. Criar repositório no GitHub
2. Fazer push do código
3. Ativar GitHub Pages nas configurações do repositório

Seu app estará ao vivo em: `https://seu-usuario.github.io/beautyconnect/`

👉 [Ver instruções completas em DEPLOY.md](./DEPLOY.md)

---

## Arquitetura

Clean Architecture, em camadas: `Tela → Controller → Repository → Storage → IndexedDB`.
Nenhuma tela acessa o banco diretamente.

```
lib/
  core/            # config, constantes, tema, rotas, storage/backup
  shared/widgets/  # widgets reaproveitados entre telas
  features/
    clientes/      # model, repository, controller, screens, widgets
    agenda/        # model, repository, controller, screens, widgets
    dashboard/     # controller (métricas), screen
    configuracoes/ # screen de backup/restauração
  main.dart
```

## Como executar

```bash
flutter pub get
flutter run -d chrome
```

(ou `flutter run -d edge`)

## Build de produção

```bash
flutter build web
```

O resultado fica em `build/web`, pronto para publicar em GitHub Pages ou Firebase Hosting.

## Persistência

- Os dados são gravados automaticamente no Hive a cada ação (salvar cliente, criar
  agendamento, mudar status, etc.) — no navegador, o Hive usa IndexedDB por baixo dos panos.
- Não existe servidor, banco remoto, login ou autenticação nesta fase.
- Em **Configurações**, é possível exportar um arquivo `backup.json` (cópia de segurança
  manual) e importá-lo de volta para restaurar ou migrar os dados para outro computador.

## Escopo desta sprint

✅ **Implementado:**
- Dashboard (atendimentos de hoje, próximo atendimento, horários vagos, aniversariante do mês)
- Cadastro de Clientes (nome, WhatsApp, data de nascimento, observações)
- Histórico do Cliente (todos os atendimentos, quantidade de visitas, valor total gasto, serviços realizados)
- Serviços (catálogo com nome, duração, valor, cor utilizada na agenda)
- Agenda (visualização por dia com seleção de serviço do catálogo)
- Agenda Inteligente (clientes atrasados para retornar, horários livres entre atendimentos)
- Persistência local (IndexedDB via Hive)
- Backup/restauração (export/import JSON)

❌ **Fora do escopo:** Login/autenticação, backend, múltiplas manicures, relatórios avançados.
