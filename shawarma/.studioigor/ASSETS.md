# Assets — Шаурмичная

## Inventory
- 2D: вся графика процедурная (scripts/du.gd). 3D: модели Kenney (assets/models/*) + процедурные вертел, гриль, лаваш, начинка, ларёк.
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
| звуки, музыка, графика 2D, вертел/гриль/лаваш 3D | сгенерированы в проекте | собственные | — |
| Mini Characters (12 персонажей) | kenney.nl/assets/mini-characters | CC0 | Kenney |
| Food Kit (томат, лук, капуста, сыр, картошка, бутылки, доска) | kenney.nl/assets/food-kit | CC0 | Kenney |
| Furniture Kit (лампа, вытяжка, урна, холодильник, радио) | kenney.nl/assets/furniture-kit | CC0 | Kenney |
| City Kit Commercial (здания) | kenney.nl/assets/city-kit-commercial | CC0 | Kenney |
| City Kit Roads (фонари, конусы) | kenney.nl/assets/city-kit-roads | CC0 | Kenney |
| Mini Market (касса) | kenney.nl/assets/mini-market | CC0 | Kenney |
