# Environment — Плот

<!-- Phase 4 (references/environment.md). Commands verified by a real run.
VERIFIED is switched only by `studio.py verify`. CAPTURE writes images to
.studioigor/captures/. -->
VERIFIED: yes

## Installed
| tool | version | why |
|---|---|---|
| Godot | 4.7.2 stable (/usr/local/bin/godot) | движок, headless-экспорт |
| Export templates | 4.7.2 (~/.local/share/godot/export_templates) | сборка APK |
| Android SDK | build-tools 35.0.0, platform 35 (/opt/android-sdk) | подпись и упаковка APK |
| OpenJDK | 21 | apksigner |
| Xvfb + Mesa | system | кадры без экрана |
| numpy, ffmpeg, Pillow | system | звуки, иконка, атлас (tools/build_atlas.py), UI-кит (tools/build_ui.py), текстуры воды |
| gdtoolkit | 4.x (pip) | gdlint |

## Agent integrations
Без MCP редактора: облако без GUI. Работа через Godot CLI; кадры — бот tools/capture.tscn под xvfb.

## Commands
RUN: пользователь играет на телефоне — BUILD, затем отправка build/plot.apk в чат
TEST: godot --headless --path . -s res://tests/test_logic.gd
BUILD: godot --headless --path . --export-debug "Android" build/plot.apk
CAPTURE: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tools/capture.tscn -- --out .studioigor/captures/v6
EDITOR: нет (облако без экрана)

## Pitfalls
- Контейнер временный: Godot, шаблоны и Android SDK ставятся заново в каждой сессии (Godot и шаблоны — downloads.godotengine.org, SDK — dl.google.com); в editor_settings-4.7.tres поправить android_sdk_path на /opt/android-sdk.
- В -s тестах автолоады (Data) не видны при компиляции: тестируемые классы не должны ссылаться на Data.
- Новый class_name виден только после `godot --headless --path . --import`.
- Compatibility-рендер: освещение ярче, чем в Forward+ — тонмаппинг Linear, солнце ~0.6, ambient цветом; цвета воды в шейдере задаются как есть (без pow).
- set_anchors_and_offsets_preset, а не set_anchors_preset — иначе Control под CanvasLayer остаётся нулевого размера.
- Металл из атласа без отражений неба выходит чёрным: metallic-множитель 0.45.
- Иконки предметов перегенерировать после правок view/looks.gd: xvfb-run … godot --path . --rendering-driver opengl3 res://tools/render_icons.tscn
- Новый экран, открытый по тапу, ловит тот же тап эмуляцией мыши, пока кнопки лежат в (0,0): открывать call_deferred + TapShield.
- Вода полупрозрачная: всё полупрозрачное поверх неё (призраки построек) — render_priority выше, иначе вода их «вуалирует».
- data/*.json не ресурсы: include_filter="data/*.json" в export_presets.cfg.
