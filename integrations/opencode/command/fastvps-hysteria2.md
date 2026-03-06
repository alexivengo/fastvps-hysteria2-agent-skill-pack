---
description: Развернуть или проверить Hysteria2 на FastVPS через skill fastvps-hysteria2-setup
---

Use the installed `fastvps-hysteria2-setup` skill for this task.

Follow that skill exactly:
- bootstrap non-interactive SSH access first;
- prefer `self-signed` mode when the user has no domain;
- do not rotate the existing password or certificate unless the user explicitly asks for that;
- run validation after deployment.

User request:
$ARGUMENTS
