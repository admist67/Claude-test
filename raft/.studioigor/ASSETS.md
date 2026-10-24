# Assets — Плот

<!-- Phase 5 (references/assets.md). -->

## Inventory
<!-- one line per asset card (references/assets.md): name · category · style · budget · source · status -->
| asset | category | style | budget | source | status |
|---|---|---|---|---|---|
| клетка плота (доски с гвоздями, балки, обвязки, бочки-поплавки) | окружение | low-poly + атлас CC0 | 1 draw call | процедурно (raft.gd) | v0.2 |
| вода и небо | окружение | шейдеры: нормали, рябь, Френель, облака, звёзды | 1 dc + небо | ocean.gdshader, sky.gdshader | v0.2 |
| доска, бутылка-пластик, пальмовая ветка, верёвка, крюк | пропсы | low-poly + атлас CC0 | 1 dc | процедурно (view/looks.gd) | v0.2 |
| бочка, молоток, бутылка, удочка, рыба, станции | пропсы | low-poly + атлас CC0 | 1 dc | процедурно (view/looks.gd) | v0.2 |
| атлас текстур | материалы | CC0 PBR | 1 материал | tools/build_atlas.py (ambientCG) | v0.2 |
| вода: рябь и шум | материалы | процедурно | — | tools/gen_textures.py | v0.2 |
| UI-кит: кнопки, панели, кольца, значки | UI | морской | — | tools/build_ui.py (+ Kenney Game Icons) | v0.2 |
| 3D-иконки предметов | UI | рендер | — | tools/render_icons.tscn | v0.2 |
| кокос, банан, ананас | еда | Kenney | — | Kenney Food Kit | v0.1 |
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
| Food Kit (кокос, банан, ананас) | kenney.nl/assets/food-kit | CC0 | Kenney | assets/models/food | не требуется |
| Nunito 800/900 | fonts.google.com/specimen/Nunito | SIL OFL 1.1 | Vernon Adams, Cyreal, Jacques Le Bailly | assets/fonts | в титрах |
| Wood049, Wood051, Wood092, Rope001, Plastic010, Metal021, Clay005, Bricks105, Fabric030 | ambientcg.com | CC0 | ambientCG (Lennart Demes) | assets/textures/atlas_* | не требуется |
| Game Icons (pause, cross, exclamation…) | kenney.nl/assets/game-icons | CC0 | Kenney | assets/ui/glyphs | не требуется |
| Kelly Slab | fonts.google.com/specimen/Kelly+Slab | SIL OFL 1.1 | Denis Masharov | assets/fonts | в титрах |
| звуки, иконка, процедурная геометрия, UI-кит | сгенерированы в проекте | собственные | — | assets/sfx, assets/ui, icon.png | — |
