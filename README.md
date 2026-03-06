# FastVPS Hysteria2 Multi-Agent Skill Pack

Публичный репозиторий со skill pack для агентных CLI, который разворачивает и валидирует `Hysteria2` на `FastVPS`.

Поддерживаемые среды:
- `Codex`
- `Claude Code`
- `OpenCode`
- `Gemini CLI`

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
- безопасно поднимать сервер без локальной записи клиентских секретов по умолчанию;
- экспортировать клиентские артефакты отдельной явной командой;
- проверять маршрут, IP, DNS и утечки на `macOS`, `Linux` и `Windows`;
- ставиться как skill в несколько agent CLI;
- добавлять vendor-specific команды для `Claude Code`, `OpenCode` и `Gemini CLI`.

## Что такое Hysteria2

`Hysteria2` — это прокси-протокол на базе `QUIC`, рассчитанный на высокую скорость, работу поверх `UDP`, шифрование трафика и устойчивость к фильтрации. На уровне сети он старается выглядеть как обычный `HTTP/3` трафик, поэтому его сложнее отличить от нормального веб-трафика и сложнее блокировать без побочных эффектов.

Что это даёт на практике:

- пользователь поднимает свой сервер на VPS и гонит трафик через него;
- домашний провайдер видит соединение с VPS, но не видит содержимое трафика внутри туннеля;
- протокол умеет проксировать и `TCP`, и `UDP`;
- в режиме `self-signed` можно стартовать вообще без домена;
- в режиме `ACME` можно получить обычный TLS через `Let's Encrypt`.

Зачем это нужно:

- для личного зашифрованного выхода в интернет через собственный VPS;
- для обхода нестабильных или фильтруемых маршрутов;
- для сценариев, где нужен свой сервер и предсказуемый контроль над конфигурацией, а не сторонний VPN-сервис.

Что важно понимать:

- это не hosted VPN-сервис и не SaaS-подписка, а свой серверный туннель;
- этот skill pack поднимает именно `Hysteria2`-сервер и генерирует клиентские `hysteria2://...` URI для импорта;
- hosted `https://` subscription URL в текущий workflow не входит.

Официальные ресурсы:

- сайт: [v2.hysteria.network](https://v2.hysteria.network/)
- документация: [Hysteria 2 Docs](https://v2.hysteria.network/docs/)
- спецификация протокола: [Protocol](https://v2.hysteria.network/docs/developers/Protocol/)
- репозиторий: [apernet/hysteria](https://github.com/apernet/hysteria)

## Структура репозитория

```text
fastvps-hysteria2-agent-skill-pack/
├── README.md
├── LICENSE
├── .env.example
├── .gitignore
├── scripts/
├── templates/
├── integrations/
└── fastvps-hysteria2-setup/
    ├── SKILL.md
    ├── agents/openai.yaml
    ├── references/
    └── scripts/
```

`fastvps-hysteria2-setup/` — канонический skill.

`scripts/` — установщики для разных agent CLI.

`templates/` — безопасные шаблоны, которые показывают формат секретных файлов без реальных значений.

`integrations/` — vendor-specific command files для `Claude Code`, `OpenCode` и `Gemini CLI`.

`scripts/uninstall_skill.*` — удаление установленных адаптеров и skill-копий из пользовательских каталогов.

## Установка

### Быстрая установка через installer

macOS / Linux:

```bash
git clone git@github.com:alexivengo/fastvps-hysteria2-agent-skill-pack.git
cd fastvps-hysteria2-agent-skill-pack
./scripts/install_skill.sh --target codex
./scripts/install_skill.sh --target claude-code
./scripts/install_skill.sh --target opencode
./scripts/install_skill.sh --target gemini-cli
```

Или сразу всё:

```bash
./scripts/install_skill.sh --target all
```

Deploy wrapper уже безопасен по умолчанию: локальные `connection.env`, URI и `sing-box` snippet не создаются, пока вы явно не запросите это через `--write-local-secrets` или отдельную команду `export-client-secrets`.

Windows PowerShell:

```powershell
git clone git@github.com:alexivengo/fastvps-hysteria2-agent-skill-pack.git
cd fastvps-hysteria2-agent-skill-pack
.\scripts\install_skill.ps1 -Target codex
.\scripts\install_skill.ps1 -Target claude-code
.\scripts\install_skill.ps1 -Target opencode
.\scripts\install_skill.ps1 -Target gemini-cli
```

Или сразу всё:

```powershell
.\scripts\install_skill.ps1 -Target all
```

В PowerShell действует тот же принцип: deploy сам по себе не пишет локальные секреты. Для явного opt-in используйте `-WriteLocalSecrets` или `export-client-secrets.ps1`.

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

## Удаление

Если нужно убрать установленный skill pack из пользовательских каталогов:

macOS / Linux:

```bash
./scripts/uninstall_skill.sh --target claude-code
./scripts/uninstall_skill.sh --target opencode
./scripts/uninstall_skill.sh --target gemini-cli
```

Или сразу удалить только побочные установки вне `Codex`:

```bash
./scripts/uninstall_skill.sh --target non-codex
```

Windows PowerShell:

```powershell
.\scripts\uninstall_skill.ps1 -Target claude-code
.\scripts\uninstall_skill.ps1 -Target opencode
.\scripts\uninstall_skill.ps1 -Target gemini-cli
```

Или:

```powershell
.\scripts\uninstall_skill.ps1 -Target non-codex
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

## Как работает

Ниже последовательный workflow, по которому работает skill pack.

1. Пользователь устанавливает skill pack в нужный agent CLI.
2. Пользователь даёт минимальные входные данные:
- `host`
- `ssh user`
- `ssh port`
- если нужен `ACME`, ещё `domain` и `email`
3. Если у пользователя нет неинтерактивного SSH-доступа, агент не просит писать пароль в чат.
- Пользователь один раз сбрасывает root-пароль в панели FastVPS.
- Пользователь добавляет свой публичный SSH-ключ на VPS.
- После этого агент работает по ключу.
4. Агент определяет режим развертывания:
- `self-signed`, если домена нет
- `acme`, если есть домен и свободен `443`
5. Агент запускает `deploy`.
- Используются wrapper-скрипты:
  - [deploy_fastvps_hysteria2.sh](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.sh)
  - [deploy_fastvps_hysteria2.ps1](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.ps1)
6. Локальный wrapper идёт по SSH на VPS и отправляет общий remote script:
- [remote_deploy_fastvps_hysteria2.sh](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/remote_deploy_fastvps_hysteria2.sh)
7. На сервере remote script делает полный deploy:
- показывает preflight
- проверяет занятые порты
- устанавливает `hysteria2` и зависимости
- выбирает рабочий порт
- переиспользует текущий пароль и self-signed сертификат, если они уже есть
- пишет `/etc/hysteria/config.yaml`
- включает `systemd` сервис
- настраивает `ufw`
- проверяет `systemctl`, `ss`, `journalctl`
8. После deploy агент показывает только redacted summary:
- `endpoint`
- `port`
- статус сервиса
- без пароля и без `pinSHA256`
9. Это поведение по умолчанию.
- Локальные `connection.env`, URI и `sing-box` snippet не создаются.
- Для одношагового opt-in есть `--write-local-secrets` или `-WriteLocalSecrets`.
10. Если пользователь явно хочет клиентские артефакты, агент запускает отдельный export:
- [export-client-secrets.sh](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/export-client-secrets.sh)
- [export-client-secrets.ps1](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/export-client-secrets.ps1)
11. Export wrapper снова идёт по SSH и читает текущую серверную конфигурацию через:
- [remote_export_fastvps_hysteria2.sh](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/remote_export_fastvps_hysteria2.sh)
12. Export получает:
- `TLS mode`
- `endpoint`
- `listen port`
- `auth password`
- `pinSHA256`, если режим `self-signed`
- `domain/email`, если режим `acme`
13. После этого локально создаются клиентские артефакты:
- `server/connection.env`
- `client/mobile/profile.txt`
- `client/desktop/profile.txt`
- `client/manual/hysteria2-uri.txt`
- `client/sing-box/hy2-outbound-snippet.json`
14. Для `Hiddify`, `Shadowrocket` и похожих клиентов агент генерирует именно импортируемый URI вида `hysteria2://...`.
- `client/mobile/profile.txt` содержит готовый URI для мобильных клиентов
- `client/desktop/profile.txt` содержит готовый URI для desktop-клиентов
- `client/manual/hysteria2-uri.txt` содержит резервный URI для ручного импорта
- в `self-signed` режиме URI включает `insecure=1` и `pinSHA256`
- в `acme` режиме URI включает `sni=<domain>` и `insecure=0`
15. Это не `https://` subscription URL и не удалённый config endpoint.
- Skill в текущем виде генерирует локальные импортируемые URI и `sing-box` snippet.
- Если нужен именно subscription URL, его нужно строить отдельным сервисом поверх этого workflow.
16. Локальную генерацию делают helper-скрипты:
- [client_artifacts_fastvps_hysteria2.sh](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/client_artifacts_fastvps_hysteria2.sh)
- [client_artifacts_fastvps_hysteria2.ps1](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/client_artifacts_fastvps_hysteria2.ps1)
17. Пользователь импортирует профиль в клиент и подключается.
18. После подключения агент или пользователь запускает проверки:
- macOS: [check_macos_hysteria2.sh](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/check_macos_hysteria2.sh)
- Linux: [check_linux_hysteria2.sh](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/check_linux_hysteria2.sh)
- Windows: [check_windows_hysteria2.ps1](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/scripts/check_windows_hysteria2.ps1)
19. Дополнительно можно пройти BrowserLeaks-проверки из:
- [validation.md](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/fastvps-hysteria2-setup/references/validation.md)

## Быстрый сценарий без домена

Skill поддерживает безопасный базовый вариант:

1. Пользователь сбрасывает root-пароль в панели FastVPS.
2. Агент помогает добавить SSH-ключ.
3. Запускается deploy в режиме `self-signed`.
4. Если `443` занят, skill переводит `Hysteria2` на `8443`.
5. Выполняется проверка сервера и клиента.
6. Клиентские профили экспортируются только отдельной явной командой.

Пример локального запуска wrapper-скрипта:

macOS / Linux:

```bash
./fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.sh \
  --host <VPS_IP> \
  --self-signed
```

Явный opt-in, если нужно записать локальные клиентские секреты в тот же запуск:

```bash
./fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.sh \
  --host <VPS_IP> \
  --self-signed \
  --write-local-secrets
```

Windows PowerShell:

```powershell
./fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.ps1 `
  -Host <VPS_IP> `
  -SelfSigned
```

Явный opt-in, если нужно записать локальные клиентские секреты в тот же запуск:

```powershell
./fastvps-hysteria2-setup/scripts/deploy_fastvps_hysteria2.ps1 `
  -Host <VPS_IP> `
  -SelfSigned `
  -WriteLocalSecrets
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

## Экспорт клиентских секретов

После того как deploy завершён и сервер уже работает, клиентские данные экспортируются отдельной командой.

macOS / Linux:

```bash
./fastvps-hysteria2-setup/scripts/export-client-secrets.sh \
  --host <VPS_IP>
```

Windows PowerShell:

```powershell
./fastvps-hysteria2-setup/scripts/export-client-secrets.ps1 `
  -Host <VPS_IP>
```

Если SSH host и клиентский endpoint различаются, задайте его явно:

macOS / Linux:

```bash
./fastvps-hysteria2-setup/scripts/export-client-secrets.sh \
  --host <VPS_IP> \
  --client-endpoint <CLIENT_ENDPOINT>
```

Windows PowerShell:

```powershell
./fastvps-hysteria2-setup/scripts/export-client-secrets.ps1 `
  -Host <VPS_IP> `
  -ClientEndpoint <CLIENT_ENDPOINT>
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

## Как безопасно передавать и хранить секреты

### Что считается секретом

- root-пароль от VPS
- приватный SSH-ключ
- `HY2_AUTH_PASSWORD`
- `connection.env`
- клиентские URI
- `pinSHA256` для self-signed профиля

### Как передавать секреты правильно

Лучший рабочий вариант:

1. Пользователь не пишет root-пароль в чат.
2. Пользователь вручную добавляет публичный SSH-ключ на VPS.
3. Агент дальше работает только по SSH-ключу.
4. Deploy выполняется в безопасном режиме по умолчанию, без локального хранения клиентских секретов.
5. Когда пользователь явно готов материализовать клиентские данные, агент использует `export-client-secrets` или `--write-local-secrets` / `-WriteLocalSecrets`.

В таком режиме:

- сервер настраивается полностью;
- сервис запускается;
- локальные `connection.env`, URI и `sing-box` snippet не создаются;
- в консоль выводится только redacted summary без пароля и pin.

### Где секреты хранятся

На VPS:

- `/etc/hysteria/config.yaml`
- `/etc/hysteria/server.key`
- `/etc/hysteria/server.crt`

Локально у оператора, только если был сделан явный export секретов:

- `artifacts/.../server/connection.env`
- `artifacts/.../client/mobile/profile.txt`
- `artifacts/.../client/desktop/profile.txt`
- `artifacts/.../client/manual/hysteria2-uri.txt`
- `artifacts/.../client/sing-box/hy2-outbound-snippet.json`

### Что использовать как безопасные шаблоны

В репозитории для этого есть:

- [`.env.example`](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/.env.example)
- [`connection.env.example`](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/templates/connection.env.example)
- [`.gitignore`](/Users/a.burlakov/VibeCoding/vpn/fastvps-hysteria2-agent-skill-pack/.gitignore)

### Практический безопасный режим

Если пользователь ещё не готов хранить клиентские секреты локально:

1. Делаете обычный deploy без дополнительных флагов.
2. Проверяете, что сервис на VPS поднялся.
3. Когда готовы сохранить клиентские данные осознанно, запускаете `export-client-secrets`.

Если нужен одношаговый сценарий, используйте явный opt-in:

- `--write-local-secrets` в bash
- `-WriteLocalSecrets` в PowerShell

## Примечание

Внутренние инструкции skill (`SKILL.md`, `references/`, `scripts/`) оставлены в техническом виде, удобном для агента. Человеческая документация и способ публикации описаны в этом `README.md`.

Для `Codex` каноническим форматом остаётся `fastvps-hysteria2-setup/SKILL.md`. Для остальных agent CLI поверх него добавлены только тонкие адаптеры установки и вызова.
