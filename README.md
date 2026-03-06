# FastVPS Hysteria2 Multi-Agent Skill Pack

Публичный репозиторий со skill pack для агентных CLI, который разворачивает и валидирует `Hysteria2` на `FastVPS`.

Поддерживаемые среды:
- `Codex`
- `Claude Code`
- `OpenCode`
- `Gemini CLI`

Ниже я использую название `Claude Code`. Если под `Cloud Code` вы имели в виду именно его, всё покрыто.

Репозиторий подготовлен для публикации:
- без реальных IP-адресов, доменов, паролей и токенов;
- без клиентских URI и test artifacts;
- с документацией для людей на русском языке;
- с внутренними инструкциями skill для агента в рабочем виде.

## Что умеет skill pack

- подготавливать `Hysteria2` на `Ubuntu 24.04` в `FastVPS`;
- работать в двух режимах:
  - `self-signed`, если у пользователя нет домена;
  - `ACME`, если есть домен и свободен `443`;
- автоматически учитывать типичную ситуацию FastVPS, когда `443` уже занят `nginx`/FastPanel;
- переиспользовать текущий пароль и self-signed сертификат при повторном запуске;
- генерировать клиентские артефакты для импорта в клиенты;
- проверять маршрут, IP, DNS и утечки на `macOS`, `Linux` и `Windows`.
- ставиться как skill в несколько agent CLI;
- добавлять vendor-specific команды для `Claude Code`, `OpenCode` и `Gemini CLI`.

## Структура репозитория

```text
fastvps-hysteria2-codex-skill/
├── README.md
├── LICENSE
├── .gitignore
├── scripts/
├── integrations/
└── fastvps-hysteria2-setup/
    ├── SKILL.md
    ├── agents/openai.yaml
    ├── references/
    └── scripts/
```

`fastvps-hysteria2-setup/` — канонический skill.

`scripts/` — установщики для разных agent CLI.

`integrations/` — vendor-specific command files для `Claude Code`, `OpenCode` и `Gemini CLI`.

## Установка

### Быстрая установка через installer

macOS / Linux:

```bash
git clone git@github.com:alexivengo/fastvps-hysteria2-codex-skill.git
cd fastvps-hysteria2-codex-skill
./scripts/install_skill.sh --target codex
./scripts/install_skill.sh --target claude-code
./scripts/install_skill.sh --target opencode
./scripts/install_skill.sh --target gemini-cli
```

Или сразу всё:

```bash
./scripts/install_skill.sh --target all
```

Windows PowerShell:

```powershell
git clone git@github.com:alexivengo/fastvps-hysteria2-codex-skill.git
cd fastvps-hysteria2-codex-skill
.\scripts\install_skill.ps1 -Target codex
.\scripts\install_skill.ps1 -Target claude-code
.\scripts\install_skill.ps1 -Target opencode
.\scripts\install_skill.ps1 -Target gemini-cli
```

Или сразу всё:

```powershell
.\scripts\install_skill.ps1 -Target all
```

### Ручная установка по средам

#### Codex

macOS / Linux:

```bash
mkdir -p ~/.codex/skills
cp -R ./fastvps-hysteria2-setup ~/.codex/skills/
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\\.codex\\skills" | Out-Null
Copy-Item -Recurse -Force .\\fastvps-hysteria2-setup "$HOME\\.codex\\skills\\"
```

#### Claude Code

macOS / Linux:

```bash
mkdir -p ~/.claude/skills ~/.claude/commands
cp -R ./fastvps-hysteria2-setup ~/.claude/skills/
cp ./integrations/claude-code/commands/fastvps-hysteria2.md ~/.claude/commands/
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\\.claude\\skills" | Out-Null
New-Item -ItemType Directory -Force "$HOME\\.claude\\commands" | Out-Null
Copy-Item -Recurse -Force .\\fastvps-hysteria2-setup "$HOME\\.claude\\skills\\"
Copy-Item -Force .\\integrations\\claude-code\\commands\\fastvps-hysteria2.md "$HOME\\.claude\\commands\\"
```

#### OpenCode

`OpenCode` умеет читать skills из `~/.agents/skills`, поэтому здесь используется shared path.

macOS / Linux:

```bash
mkdir -p ~/.agents/skills ~/.config/opencode/command
cp -R ./fastvps-hysteria2-setup ~/.agents/skills/
cp ./integrations/opencode/command/fastvps-hysteria2.md ~/.config/opencode/command/
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\\.agents\\skills" | Out-Null
New-Item -ItemType Directory -Force "$HOME\\.config\\opencode\\command" | Out-Null
Copy-Item -Recurse -Force .\\fastvps-hysteria2-setup "$HOME\\.agents\\skills\\"
Copy-Item -Force .\\integrations\\opencode\\command\\fastvps-hysteria2.md "$HOME\\.config\\opencode\\command\\"
```

#### Gemini CLI

`Gemini CLI` тоже может читать skills из `~/.agents/skills`, поэтому используется тот же shared path.

macOS / Linux:

```bash
mkdir -p ~/.agents/skills ~/.gemini/commands
cp -R ./fastvps-hysteria2-setup ~/.agents/skills/
cp ./integrations/gemini-cli/commands/fastvps-hysteria2.toml ~/.gemini/commands/
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\\.agents\\skills" | Out-Null
New-Item -ItemType Directory -Force "$HOME\\.gemini\\commands" | Out-Null
Copy-Item -Recurse -Force .\\fastvps-hysteria2-setup "$HOME\\.agents\\skills\\"
Copy-Item -Force .\\integrations\\gemini-cli\\commands\\fastvps-hysteria2.toml "$HOME\\.gemini\\commands\\"
```

## Как использовать в разных агентах

### Codex

После установки можно просить агента использовать skill по имени:

```text
Используй $fastvps-hysteria2-setup и подними Hysteria2 на моем FastVPS без домена.
```

Или:

```text
Используй $fastvps-hysteria2-setup, разверни Hysteria2 на FastVPS с Let's Encrypt и проверь IP/DNS/WebRTC утечки.
```

### Claude Code

После установки будет доступна команда:

```text
/fastvps-hysteria2
```

Если аргументы команды в вашей версии не подставляются автоматически, просто вызывайте команду и следующей репликой пишите задачу обычным текстом.

### OpenCode

После установки будет доступна команда:

```text
/fastvps-hysteria2
```

`OpenCode` также сможет находить сам skill в `~/.agents/skills`.

### Gemini CLI

После установки будет доступна команда:

```text
/fastvps-hysteria2
```

Если удобнее без команды, можно прямо в запросе писать:

```text
Use the installed fastvps-hysteria2-setup skill and deploy Hysteria2 on FastVPS without a domain.
```

## Быстрый сценарий без домена

Skill поддерживает безопасный базовый вариант:

1. Пользователь сбрасывает root-пароль в панели FastVPS.
2. Агент помогает добавить SSH-ключ.
3. Запускается deploy в режиме `self-signed`.
4. Если `443` занят, skill переводит `Hysteria2` на `8443`.
5. Генерируются клиентские профили.
6. Выполняется проверка сервера и клиента.

Пример локального запуска wrapper-скрипта:

macOS / Linux:

```bash
./fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.sh \
  --host <VPS_IP> \
  --self-signed
```

Windows PowerShell:

```powershell
./fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.ps1 `
  -Host <VPS_IP> `
  -SelfSigned
```

## Сценарий с доменом

Если у пользователя есть домен и `443` свободен, можно использовать `Let's Encrypt`:

macOS / Linux:

```bash
./fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.sh \
  --host <VPS_IP> \
  --domain <hy2.example.com> \
  --email <user@example.com>
```

Windows PowerShell:

```powershell
./fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.ps1 `
  -Host <VPS_IP> `
  -Domain <hy2.example.com> `
  -Email <user@example.com>
```

## Проверка после подключения

После импорта профиля в клиент можно использовать встроенные проверки:

- `fastvps-hysteria2-setup/scripts/check_macos_hysteria2.sh`
- `fastvps-hysteria2-setup/scripts/check_linux_hysteria2.sh`
- `fastvps-hysteria2-setup/scripts/check_windows_hysteria2.ps1`

Также рекомендуется ручная браузерная проверка:

- [BrowserLeaks IP](https://browserleaks.com/ip)
- [BrowserLeaks DNS](https://browserleaks.com/dns)
- [BrowserLeaks WebRTC](https://browserleaks.com/webrtc)

## Что важно не коммитить

В публичный репозиторий нельзя добавлять:

- `artifacts/`
- `tmp-test-artifacts/`
- реальные `connection.env`
- клиентские URI
- реальные `pinSHA256`
- реальные пароли и токены

Для этого в репозитории уже есть `.gitignore`, но перед push всё равно стоит делать `git diff --cached`.

## Примечание

Внутренние инструкции skill (`SKILL.md`, `references/`, `scripts/`) оставлены в техническом виде, удобном для агента. Человеческая документация и способ публикации описаны в этом `README.md`.

Для `Codex` каноническим форматом остаётся `fastvps-hysteria2-setup/SKILL.md`. Для остальных agent CLI поверх него добавлены только тонкие адаптеры установки и вызова.
