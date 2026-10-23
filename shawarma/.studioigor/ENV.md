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
CAPTURE: xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 res://tools/bot.tscn -- --out .studioigor/captures/bot --speed 4
EDITOR: нет (облако без экрана)

## Pitfalls
- github.com releases закрыты прокси: Godot и шаблоны качать с downloads.godotengine.org.
- В --headless кадры не снимаются (dummy renderer) — только xvfb + opengl3.
- data/*.json не ресурсы: в export_presets include_filter="data/*.json", иначе в APK их нет.
- Многострочные лямбды: закрывающую скобку ставить на отдельной строке.
