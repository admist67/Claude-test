# Assets — Шаурмичная

## Inventory
- Вся графика процедурная в коде (scripts/du.gd, станции, клиенты) — без текстур.
- Звуки и музыка сгенерированы tools/gen_audio.py → assets/sfx/*.wav, assets/music/night_loop.ogg.
- Иконка — tools/icon.tscn рисует тем же кодом → icon.png.

## Strategy by category
- персонажи, окружение, еда, UI: процедурно в Godot (_draw), стиль из ART_BIBLE.
- звук/музыка: процедурный синтез numpy; позже можно заменить на CC0-паки.
- шрифт: Nunito (Google Fonts).

## Conventions
- Цвета — константы в DU; числа — data/*.json.

## Requests to the user
- нет

## License registry
| asset | source | license | credit |
|---|---|---|---|
| Nunito 800/900 | fonts.google.com/specimen/Nunito | SIL OFL 1.1 | Vernon Adams, Cyreal, Jacques Le Bailly |
| звуки, музыка, графика | сгенерированы в проекте | собственные | — |
