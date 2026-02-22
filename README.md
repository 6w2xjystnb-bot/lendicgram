# lendicgram

**Anti-Delete** твик для Telegram iOS — удалённые собеседником сообщения **не исчезают**, а становятся полупрозрачными (α 0.45) с красным крестиком ✕, как в Ayugram.

---

## Возможности

- Перехват удаления сообщений на стороне клиента (удалённые контактом сообщения остаются в чате)
- Визуальная индикация: полупрозрачность + красный бейдж ✕ в углу
- Сохранение состояния между перезапусками Telegram (NSUserDefaults)
- Поддержка нескольких чатов (messageId привязан к chatId)

---

## Сборка

### Требования

- macOS / Linux (или WSL на Windows)
- [Theos](https://theos.dev/docs/installation) — установленный и настроенный
- iOS SDK (скачивается автоматически через Theos)

### Шаги

```bash
# 1. Клонировать / скопировать проект
cd lendicgram/

# 2. Скомпилировать
make

# 3. Собрать .deb пакет
make package

# 4. Установить на устройство (SSH)
export THEOS_DEVICE_IP=<ip-вашего-устройства>
make install
```

Dylib будет собран в `.theos/obj/debug/lendicgram.dylib`.

---

## Установка без Theos

Если вы хотите использовать готовый `.dylib`:

1. Скопируйте `lendicgram.dylib` в `/Library/MobileSubstrate/DynamicLibraries/`
2. Скопируйте `lendicgram.plist` туда же
3. Перезапустите Telegram: `killall -9 Telegram`

> **TrollStore / Dopamine / Palera1n** — поддерживаются. Для rootless jailbreak путь будет `/var/jb/Library/MobileSubstrate/DynamicLibraries/`.

---

## Совместимость

| Telegram iOS | Статус |
|:-------------|:-------|
| 10.x – 11.x | ✅ Поддерживается |
| 9.x          | ⚠️ Частичная поддержка (legacy hooks) |
| < 9.0        | ❌ Не поддерживается |

> **Примечание:** Telegram iOS периодически меняет внутренние классы. Если после обновления Telegram твик перестал работать — проверьте логи (`[lendicgram]` в Console/syslog) и обновите имена классов в `Tweak.xm`.

---

## Структура проекта

```
lendicgram/
├── Makefile              # Theos build config
├── control               # Debian package metadata
├── lendicgram.plist      # CydiaSubstrate filter (Telegram only)
├── Tweak.xm              # Logos hooks (main tweak logic)
├── LendicgramManager.h   # Singleton header
├── LendicgramManager.m   # Persistence layer (NSUserDefaults)
└── README.md
```

---

## Лицензия

MIT
