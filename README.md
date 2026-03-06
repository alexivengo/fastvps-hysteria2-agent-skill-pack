# FastVPS Hysteria2 Codex Skill

Публичный репозиторий со skill для Codex, который разворачивает и валидирует `Hysteria2` на `FastVPS`.

Репозиторий подготовлен для публикации:
- без реальных IP-адресов, доменов, паролей и токенов;
- без клиентских URI и test artifacts;
- с документацией для людей на русском языке;
- с внутренними инструкциями skill для агента в рабочем виде.

## Что умеет skill

- подготавливать `Hysteria2` на `Ubuntu 24.04` в `FastVPS`;
- работать в двух режимах:
  - `self-signed`, если у пользователя нет домена;
  - `ACME`, если есть домен и свободен `443`;
- автоматически учитывать типичную ситуацию FastVPS, когда `443` уже занят `nginx`/FastPanel;
- переиспользовать текущий пароль и self-signed сертификат при повторном запуске;
- генерировать клиентские артефакты для импорта в клиенты;
- проверять маршрут, IP, DNS и утечки на `macOS`, `Linux` и `Windows`.

## Структура репозитория

```text
fastvps-hysteria2-codex-skill/
├── README.md
├── LICENSE
├── .gitignore
└── fastvps-hysteria2-setup/
    ├── SKILL.md
    ├── agents/openai.yaml
    ├── references/
    └── scripts/
```

`fastvps-hysteria2-setup/` — это сам skill. Его можно копировать в каталог skills вашего Codex.

## Установка

### Вариант 1. Ручная установка

Скопируйте каталог `fastvps-hysteria2-setup` в локальный каталог skills:

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

### Вариант 2. Через Git clone

```bash
git clone git@github.com:alexivengo/fastvps-hysteria2-codex-skill.git
cd fastvps-hysteria2-codex-skill
cp -R ./fastvps-hysteria2-setup ~/.codex/skills/
```

## Как использовать

После установки можно просить агента использовать skill по имени:

```text
Используй $fastvps-hysteria2-setup и подними Hysteria2 на моем FastVPS без домена.
```

Или:

```text
Используй $fastvps-hysteria2-setup, разверни Hysteria2 на FastVPS с Let's Encrypt и проверь IP/DNS/WebRTC утечки.
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
