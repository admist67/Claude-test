# Scope — the contract in numbers

## Reference inventory
Good Pizza Great Pizza: десятки дней, ~10 ингредиентов, много персонажей. Мы — маленькая игра.

## Contract
- [ ] дни кампании: 15 days — count: grep -c '"day"' shawarma/data/days.json 2>/dev/null || echo 0
- [ ] ингредиенты: 10 pcs — count: grep -c '"id"' shawarma/data/ingredients.json 2>/dev/null || echo 0
- [ ] типы клиентов: 6 types — count: grep -c '"type_id"' shawarma/data/customers.json 2>/dev/null || echo 0
- [ ] уровни точки: 3 levels — count: echo 0
