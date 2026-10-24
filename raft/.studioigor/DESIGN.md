# Design — Плот

A living document. Changes after playtests — with a line in "Changelog".

## Mechanics
<!-- Statuses: idea → spec → gym → playtest → locked, or cut. tier: mvp — needed
for the vertical slice; full — later. Before a mechanic — research research/mech-<id>.md. -->
| id | mechanic | tier | pillar | status | scene | notes |
|---|---|---|---|---|---|---|
| M01 | Крюк: бросок с зарядом, подтягивание мусора | mvp | Океан щедрый | playtest | scenes/main.tscn | 30-сек цикл |
| M02 | Дрейф мусора: доски, пластик, листья, бочки по течению | mvp | Океан щедрый | playtest | scenes/main.tscn | плотность ~1 предмет/10 с в зоне броска |
| M03 | Плот и качка, ходьба от 1-го лица, тач-управление | mvp | Удобно пальцем | playtest | scenes/main.tscn | джойстик + свайп-обзор |
| M04 | Выживание: голод, жажда, здоровье, смерть и возрождение | mvp | Угроза рядом | playtest | scenes/main.tscn | |
| M05 | Инвентарь (хотбар) и крафт | mvp | Плот — мой дом | playtest | scenes/main.tscn | без веса и прочности |
| M06 | Строительство: новые клетки плота по сетке | mvp | Плот — мой дом | playtest | scenes/main.tscn | |
| M07 | Станции: очиститель воды, гриль | mvp | Плот — мой дом | playtest | scenes/main.tscn | |
| M08 | Акула: грызёт клетку, копьё, ремонт | mvp | Угроза рядом | playtest | scenes/main.tscn | кружит, грызёт крайние клетки (3 укуса), копьё: 3 удара — уплывает, 5 — погибает (мясо) |
| M09 | Сохранение и загрузка | mvp | — | playtest | scenes/main.tscn | автосейв |
| M10 | Рыбалка: удочка, мини-игра тайминга | mvp | Океан щедрый | playtest | scenes/main.tscn | v0.4 |
| M11 | Шторм — кульминация сессии | full | Угроза рядом | idea | — | хук G01 |
| M12 | Питомец на плоту | full | Плот — мой дом | idea | — | хук G04 |
| M13 | Ныряние за ресурсами | full | Океан щедрый | idea | — | |
| M14 | Острова | full | Плот — мой дом | idea | — | |
| M15 | День и ночь: солнце, закат, звёзды, костры | mvp | Угроза рядом | playtest | scenes/main.tscn | 7 мин день + 2.5 мин ночь |

## Game designer ideas
<!-- references/gamedesigner.md. Statuses: proposed → approved → M## | rejected (why) | deferred.
Do not propose rejected ideas again. Do not implement unapproved ones. -->
| id | idea | why it's fun | cost S/M/L | point (phase) | status |
|---|---|---|---|---|---|
| G01 | Шторм раз в 10–15 мин: качка, смывает вещи, акула злее, после — редкий мусор | ритм «спокойно → буря → награда» | M | 1 | approved → M11 |
| G02 | Бутылки с записками: история и маршрут к финалу | цель и сюжет | M | 1 | rejected (пользователь не выбрал) |
| G03 | Хитрая акула: выбирает слабую клетку, приманка, возвращается злее, трофей | акула как персонаж | M | 1 | rejected (пользователь не выбрал) |
| G04 | Питомец: подсвечивает ценный мусор, гоняет чаек | компания и уют | M | 1 | approved → M12 |

## Content
<!-- phase 8 (references/production.md): one line per unit. Statuses: sketch → blockout → art → final. -->
| id | new | signature moment | difficulty 1–10 | axes of difference from the neighbor | story beat | status |
|---|---|---|---|---|---|---|

## Progression and meta
- Прорыв 1: верёвка + доски → первая новая клетка плота (≈3 мин).
- Прорыв 2: очиститель и гриль — жажда и голод под контролем (≈8 мин).
- Прорыв 3: копьё — акулу можно прогнать, а не только терпеть (≈12 мин).

## Economy
<!-- resource: sources → sinks, rate (a guess is fine) -->
- доски: мусор → клетки, станции, копьё; ~4/мин
- пластик: мусор → крюк, очиститель; ~2/мин
- листья: мусор → верёвка (2 листа); ~3/мин
- рыба/картошка из бочек → гриль → еда

## Difficulty
- philosophy: спокойное начало, давление растёт через акулу и (позже) шторм
- axes: скорость голода/жажды, частота акулы, плотность мусора

## Mechanic specs
<!-- ### M01 — Name
what · why (pillar) · controls · rules · parameters (in data files) ·
acceptance criteria · "feel" (targets) · research: research/mech-M01.md -->

## Changelog
| date | what | why |
|---|---|---|
| 2026-10-24 | v0.3: волны ещё на треть слабее, мусор всплывает выше; вода полупрозрачная (видно акулу и поплавки); акула, копьё, ремонт молотком, акулий стейк; фикс паузы (тап попадал в «В меню») | фидбек v0.2 + следующий пункт плана |
| 2026-10-24 | v0.2: реалистичная вода и небо, CC0-текстуры, морской UI; очиститель и гриль (топливо горит только при готовке), удочка с поклёвкой, день/ночь; цели расширены до 13 | запрос пользователя после v0.1 |
| 2026-10-24 | v0.1: M01–M06 и M09 собраны сразу в игровой сцене, без отдельных gym-сцен; ручки тюнинга — в паузе | пользователь попросил сразу основу и логику; играет только на телефоне через APK |
