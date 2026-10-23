# Environment — Шаурмичная

<!-- Phase 4 (references/environment.md). Commands verified by a real run.
VERIFIED is switched only by `studio.py verify`. CAPTURE writes images to
.studioigor/captures/. -->
VERIFIED: yes

## Installed
| tool | version | why |
|---|---|---|
| Godot | 4.7.2 stable (/usr/local/bin/godot) | движок, headless-экспорт |
| Export templates | 4.7.2 | сборка APK |
| Android SDK | build-tools 35.0.0, platform 35 (/opt/android-sdk) | подпись и упаковка APK |
| OpenJDK | 21 | apksigner |
| Xvfb + Mesa | system | кадры без экрана |
| numpy, ffmpeg | system | генерация звуков (tools/gen_audio.py) |

## Agent integrations
Без MCP редактора: облако без GUI. Работа через Godot CLI; кадры — бот tools/bot.tscn под xvfb.

## Commands
RUN: пользователь играет только на телефоне — BUILD, затем отправка .apk в чат
TEST: godot --headless --path . -s res://tests/test_order.gd
BUILD: godot --headless --path . --export-debug "Android" build/shawarma-chef.apk
CAPTURE: xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tools/bot3d.tscn -- --out .studioigor/captures/bot3d --speed 3
EDITOR: нет (облако без экрана)

## Pitfalls
- github.com releases закрыты прокси: Godot и шаблоны качать с downloads.godotengine.org.
- В --headless кадры не снимаются (dummy renderer) — только xvfb + opengl3.
- data/*.json не ресурсы: в export_presets include_filter="data/*.json", иначе в APK их нет.
- Многострочные лямбды: закрывающую скобку ставить на отдельной строке.
- 2D-бот (tools/bot.tscn) рассчитан на вертикальный экран 720x1280; проект теперь альбомный (3D).
- Персонажи Kenney смотрят в +Z; паки Kenney делят имя Textures/colormap.png — у каждого пака своя папка.
