# Environment research — 2026-10-24
Sources: ../shawarma/.studioigor/ENV.md (проверено в этом репо), references/environment.md §5, https://80.lv/articles/godot-4-7-has-been-released

- Облачный контейнер без GUI: редактор и godot-ai MCP недоступны (MCP живёт только при открытом редакторе). Работаем через Godot CLI.
- Godot 4.7.2 + шаблоны 4.7.2 с downloads.godotengine.org (github releases закрыты прокси).
- Android: cmdline-tools → platform 35, build-tools 35.0.0; JDK 21 системный; debug keystore генерирует keytool/Godot.
- Кадры: xvfb + opengl3 (в --headless рендера нет). Бот tools/capture.tscn проигрывает сценарий через реальные системы.
- Тесты: свой SceneTree-скрипт без GUT (как в «Шаурмичной»): меньше зависимостей, exit 1 при провале.
- Вывод: тот же стек, что у «Шаурмичной»; пользователь играет на телефоне через APK.
