# Assets — Плот

<!-- Phase 5 (references/assets.md). -->

## Inventory
<!-- one line per asset card (references/assets.md): name · category · style · budget · source · status -->
| asset | category | style | budget | source | status |
|---|---|---|---|---|---|
| клетка плота (5 досок, балки, поплавок) | окружение | low-poly vc | 1 draw call | процедурно (raft.gd) | v0.1 |
| вода | окружение | фасетный шейдер | 1 draw call | процедурно (ocean.gdshader) | v0.1 |
| доска, пластик, пальмовый лист, верёвка, крюк | пропсы | low-poly vc | 1 dc | процедурно (view/looks.gd) | v0.1 |
| бочка, молоток, бутылка | пропсы | Kenney | — | Kenney Survival Kit | v0.1 |
| кокос, банан, ананас | еда | Kenney | — | Kenney Food Kit | v0.1 |
| иконки UI | UI | flat | — | процедурно (ui/icons.gd) | v0.1 |
| звуки и шум океана | звук | синтез | — | tools/gen_audio.py | v0.1 |
| иконка приложения | UI | flat | — | tools/make_icon.py | v0.1 |

## Strategy by category
| category | source (pack / Blender / procedural / generation / user) | why | status |
|---|---|---|---|
| плот, вода, мусор | процедурно в Godot | точно под стиль, мало draw calls | v0.1 |
| бочки, инструменты, еда | Kenney CC0 | готово, low-poly, совпадает по стилю | v0.1 |
| акула, рыба (v0.3–0.4) | Kenney fish / процедурно / Quaternius CC0 | решим на шаге стиля | plan |
| звук | синтез numpy | без лицензий; позже можно CC0-паки | v0.1 |

## Conventions
Метры, +Y вверх, течение вдоль +Z; клетка плота 1.5 м; модели Kenney — каждая пачка в своей папке с Textures/colormap.png; числа — data/*.json.

## Requests to the user
- none

## License registry
| asset / pack | source (URL) | license | author | path | attribution |
|---|---|---|---|---|---|
| Survival Kit (бочка, молоток, бутылка и др.) | kenney.nl/assets/survival-kit | CC0 | Kenney | assets/models/survival | не требуется |
| Food Kit (кокос, банан, ананас, рыба) | kenney.nl/assets/food-kit | CC0 | Kenney | assets/models/food | не требуется |
| Nunito 800/900 | fonts.google.com/specimen/Nunito | SIL OFL 1.1 | Vernon Adams, Cyreal, Jacques Le Bailly | assets/fonts | в титрах |
| звуки, иконка, процедурная геометрия | сгенерированы в проекте | собственные | — | assets/sfx, icon.png | — |
