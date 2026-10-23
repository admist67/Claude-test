# Environment research — 2026-10-23
- Godot 4.7.2 в /usr/local/bin/godot; шаблоны в ~/.local/share/godot/export_templates/4.7.2.stable.
- Android SDK /opt/android-sdk (build-tools 35.0.0, platforms android-35); путь прописан в ~/.config/godot/editor_settings-4.7.tres.
- Скачивание Godot: github releases закрыт прокси → использовать downloads.godotengine.org (редирект на objectstorage).
- Кадры без человека: xvfb-run + --rendering-driver opengl3 + --write-movie (проверено).
- MCP редактора Godot не нужен: облако без GUI, работаем через headless CLI.
- Контейнер временный: при новой сессии окружение ставится заново по этим шагам.
