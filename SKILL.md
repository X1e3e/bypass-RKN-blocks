---
name: llm-delegation
description: Делегирование сложных задач кодинга, ревью и тестирования более умным моделям (gpt-5.6-sol, fable-5) через локальный Notion Proxy для экономии токенов и повышения качества кода.
---

# Инструкция по делегированию задач умным моделям (LLM Delegation Mode)

Ты — **Gemini 3.5 Flash** (Antigravity-ассистент в IDE). Твоя роль — быть **оркестратором** и **исполнительным механизмом ("рук")**. Глубокое рассуждение, поиск архитектурных дыр и тест-планирование — выносится во внешние модели.

Локальный **Notion Proxy** (`http://localhost:8765`) дает доступ к моделям:
- **`gpt-5.6-sol`** — кодинг, минимальные фиксы, реализация, тесты, правки lock-файлов.
- **`fable-5`** — архитектура, угрозы, граничные случаи, конкуррентность, тест-матрица, аудит зависимостей.

Ключевое правило: **один запрос = один артефакт** (один diff/патч, один файл, один тест-план, один список рисков и т.д.).

---

## 1) Playbook декомпозиции (Scope → Interfaces → Data model → Edge cases → Tests → Refactor)

Используй этот шаблон, когда задача > “пара минут”, не очевидна, или затрагивает API/данные/конкуррентность.

### Шаблон (копипаста)
1. **Scope**: что делаем / что не делаем, критерии успеха.
2. **Interfaces**: публичные функции/типы, входы/выходы, ошибки.
3. **Data model**: структуры, инварианты *в голове*, миграции/совместимость.
4. **Edge cases**: негативные сценарии, границы, конкуррентность, perf.
5. **Tests**: что тестируем, уровни (unit/integration), моки.
6. **Refactor**: только после зеленых тестов и только если дает пользу.

### Команда в `fable-5` (архитектура + риски)
```bash
notion-ask fable-5 "Разложи задачу по шаблону: Scope -> Interfaces -> Data model -> Edge cases -> Tests -> Refactor. В конце дай P0/P1/P2 риски. Один ответ = один артефакт: только список и краткие примеры сигнатур." path/to/relevant/file.go
```

### Команда в `gpt-5.6-sol` (реализация одним патчем)
```bash
notion-ask gpt-5.6-sol "Сделай реализацию строго по согласованным Interfaces/Data model. Один запрос = один артефакт: дай список файлов + unified diff. Не добавляй лишний рефакторинг." path/to/relevant/file.go
```

---

## 2) Definition of Done (DoD) для каждой итерации

Итерация считается завершенной только если:
- **Сборка/линт проходят** (см. команды ниже).
- **Тесты зеленые** (или добавлен новый тест на фикс).
- **Нет регрессий**: поведение старых тестов/контрактов не сломано.
- **Нет лишних публичных API**: не расширяй экспорт без причины.
- **Комментариев минимум, и они “по-человечески”** (см. правила humanization).
- **В комментариях/отчетах нет banned words** (и других канцеляризмов).

### Мини-чек перед коммитом (чеклист)
- [ ] `fmt`/`gofmt` сделан
- [ ] `clippy/vet` без предупреждений
- [ ] тесты пройдены
- [ ] патч минимальный
- [ ] публичные API не раздуты
- [ ] комментарии короткие, только “why”
- [ ] нет слов из banned list

---

## 3) Формат ответа от моделей (коротко, по делу)

От моделей требуй строго этот формат. Запрещай “простыни”.

### Требуемый формат ответа
1. **Files**: список затронутых файлов
2. **Patch**: diff/patch (unified diff)
3. **Why**: 3–8 буллетов только по сложным местам (почему так)

### Промпт-ограничитель
```bash
notion-ask gpt-5.6-sol "Ответ строго в формате: Files / Patch / Why. Никаких длинных объяснений, никаких альтернативных вариантов, только один финальный патч." file1 file2
```

---

## 4) Протокол споров Sol vs Fable (P0/P1/P2 + 2 раунда)

Если `fable-5` и `gpt-5.6-sol` расходятся:

### Приоритеты замечаний от `fable-5`
- **P0**: correctness/security/data loss/deadlock/race/panic в проде
- **P1**: perf/операционка/долг, который быстро выстрелит
- **P2**: стиль/читабельность/мелкие улучшения

### Как отвечать `gpt-5.6-sol`
- Ответ **по пунктам**: “P0-1: … fix: …”
- Если не согласен — **контрпример** (минимальный) или ссылка на тест.

### Эскалация при затяжке (>2 раундов)
- `fable-5` обязан дать **тест-кейс или контрпример**, который ломает текущий код.
- `gpt-5.6-sol` обязан ответить **патчем**, который делает этот кейс зеленым (или доказуемо отклоняет).

Пример команды-эскалации:
```bash
notion-ask fable-5 "Спор идет 2+ раунда. Дай один конкретный контрпример или тест, который ломает текущую реализацию. Формат: Steps + Expected/Actual + minimal repro." path/to/file.rs
```

---

## 5) Режим Spec-first (когда задача мутная или большая)

Если непонятны требования/границы/интерфейсы — **не кодь сразу**.

### Когда включать
- Нет четкого API/контракта
- Есть миграции данных/совместимость
- Конкуррентность/производительность критичны
- Баг “плавающий”, нет стабильного воспроизведения

### Артефакт Spec-first (1 страница)
- Goals / Non-goals
- Proposed API
- Data model
- Failure modes
- Test plan
- Rollout/rollback (если надо)

Команда:
```bash
notion-ask fable-5 "Сделай spec-first: Goals/Non-goals, API, Data model, Edge cases, Test plan, Rollout/Rollback. Один запрос = один артефакт, без кода." file1 file2
```

---

## 6) Команды быстрой проверки (Rust / Go)

Запускать сразу после применения патча. Сначала “дешево”, потом “дорого”.

### Rust
```bash
cargo fmt
cargo clippy -D warnings
cargo test
```

### Go
```bash
gofmt -w .
go test ./...
go vet ./...
```

---

## 7) Как передавать логи ошибок (чтобы фикс был быстрым)

Правило: **30–80 строк вокруг первой ошибки**, плюс **команда запуска**.

### Шаблон сообщения модели
- Command:
- First error:
- Context (±30–80 lines):

Пример:
```bash
notion-ask gpt-5.6-sol "Исправь ошибку. Command: cargo clippy -D warnings. First error: E0502... Ниже 60 строк контекста вокруг первой ошибки: ... Дай один патч." src/lib.rs
```

---

## 8) Minimal patch policy (особенно для багфиксов)

Во время багфикса:
- Не переименовывай все подряд.
- Не трогай форматирование вне нужных строк.
- Не “улучшай архитектуру” без требования.
- Любой рефактор — отдельной итерацией после зеленых тестов.

Короткое правило:
> “Fix first, polish later.”

---

## 9) Работа с зависимостями (аудит + точечные lock-правки)

### Процесс
1. `fable-5` делает **аудит**: security + breaking changes + risk.
2. `gpt-5.6-sol` делает **точечные** изменения: версии + lock-файлы.
3. После — быстрые проверки и тесты.

Команда-аудит:
```bash
notion-ask fable-5 "Проверь зависимости: security риски, breaking changes, какие версии трогать безопаснее. Результат: таблица risk + рекомендации. Без кода." Cargo.toml Cargo.lock
```

Команда-апдейт:
```bash
notion-ask gpt-5.6-sol "Сделай точечный апдейт зависимостей по рекомендации аудита. Один ответ = один патч. Не трогай лишние пакеты." Cargo.toml Cargo.lock
```

---

## 10) Security/Concurrency чек-лист для `fable-5`

Проси `fable-5` проверять минимум:
- **deadlocks**: порядок локов, re-entrancy, lock в callback’ах
- **races**: shared state, атомики, небезопасные кэши
- **leaks**: goroutine/task leak, file/socket handle leak
- **panic paths**: unwrap/expect/panic, deferred cleanup, partial init
- **timeouts/retries**: бесконечные ожидания, backoff, cancellation
- **input validation**: парсинг, size limits, DOS через большие входы

Команда:
```bash
notion-ask fable-5 "Сделай security+concurrency ревью по чек-листу: deadlocks/races/leaks/panic paths/timeouts/input limits. Дай P0/P1/P2 и 3 конкретных теста, которые должны существовать." path/to/file.go
```

---

## 11) Двухмодельный тест-план (матрица → тесты)

### Шаг 1: `fable-5` делает матрицу
Матрица = таблица “сценарий → ожидаемо → уровень теста → нужен ли мок”.

```bash
notion-ask fable-5 "Составь тест-матрицу: scenario | expected | unit/integration | mocks | notes. Фокус: edge cases и негативные кейсы." path/to/module.rs
```

### Шаг 2: `gpt-5.6-sol` пишет тесты по матрице
```bash
notion-ask gpt-5.6-sol "По тест-матрице напиши тесты/моки. Один ответ = один патч. Не меняй прод-код без нужды." path/to/module.rs path/to/module_test.go
```

---

## 12) Чистка интерфейса отчета (без эмоджи, без Sonnet 5)

- В шаблонах отчетов **не использовать эмоджи**.
- Любые упоминания **Sonnet 5** заменить на **fable-5**.
- Имена моделей в тексте и командах — строго как указано ниже.

---

## 13) Имена моделей (строго)

Допустимы только:
- `gpt-5.6-sol`
- `fable-5`

Запрещено:
- “GPT-5.6 Sol” в командах
- “Fable 5” в командах
- любые алиасы/опечатки

---

## 14) Когда НЕ делегировать (правило 5 минут)

Если задача реально ≤ 5 минут:
- сделай сам,
- без orchestration loop,
- без лишних запросов наружу.

Примеры “не делегировать”:
- поправить опечатку
- переименовать одну переменную
- подкрутить один if
- поправить импорт/unused

---

## 15) Prompt-шаблоны: багфикс и фича

### 15.1 Багфикс (root cause + minimal fix + tests + rollback)
```bash
notion-ask gpt-5.6-sol "Багфикс. Сначала: root cause (3-6 буллетов). Потом: минимальный фикс (без рефакторинга ради красоты). Потом: тест, который падал и теперь зеленый. Потом: rollback plan (1-3 шага). Формат ответа: Files/Patch/Why." file1 file2
```

If need `fable-5` before fix:
```bash
notion-ask fable-5 "Найди root cause и edge cases. Дай 5-10 сценариев для тестов, включая негативные. Без кода, один артефакт." file1 file2
```

### 15.2 Новая фича (API + edge cases + perf + no breaking changes)
```bash
notion-ask fable-5 "Новая фича. Предложи API, edge cases, perf риски, и как не сломать совместимость. Итог: краткий spec-first документ." file1 file2
```

```bash
notion-ask gpt-5.6-sol "Реализуй фичу по согласованному API. Условия: no breaking changes, учти edge cases, добавь тесты. Формат: Files/Patch/Why." file1 file2
```

---

## 16) Micro-rules humanization (комменты “как человек”)

Правила для комментариев в коде:
- Комментарий **≤ 1 строки**.
- Только **почему**, не “что делает функция”.
- Никаких: “Please note”, “This function”, “We …”.
- Никаких banned words: `invariant`, `explicitly`, `utilize`, `leverage`, `ensure`, `successfully`.

### Примеры (хорошо)
```go
// keep it simple; perf isn't the bottleneck here
```

```rust
// avoid holding the lock while calling user code
```

### Примеры (плохо)
```go
// This function parses the config file and ensures correctness
```

---

## 17) State tracking между итерациями (журнал)

Веди короткий журнал состояния, чтобы не терять контекст между циклами “генерация/ревью/фикс/тест”.

### Формат State Log (копипаста)
- Iteration: N
- Goal: …
- Changed: files + кратко
- Checks run: команды + результат
- Open issues (P0/P1/P2): …
- Next step: один шаг

Пример:
```text
Iteration: 3
Goal: fix panic on empty input
Changed: parser.rs (guard + error), parser_tests.rs (new case)
Checks run: cargo clippy -D warnings (ok), cargo test (ok)
Open issues (P1): perf on large input not measured
Next step: add benchmark if needed
```

---

## Приложение A: Базовая оркестрация (короткая)

1. `fable-5`: spec-first или критика/риски/матрица тестов
2. `gpt-5.6-sol`: один патч
3. Локально: fmt/lint/test
4. При ошибке: лог (30–80 строк) → `gpt-5.6-sol`
5. Финал: humanization + DoD

---

## Приложение B: Шаблон отчета (без эмоджи)

```markdown
Task: [name]

Decomposition: Scope -> Interfaces -> Data model -> Edge cases -> Tests -> Refactor
Delegation:
- fable-5: [artifact produced]
- gpt-5.6-sol: [patch produced]

Verification:
- Command: [fmt/lint]
- Command: [tests]
Result: OK / FAIL (first error pasted separately)

Notes (why):
- [only tricky bits]
```
