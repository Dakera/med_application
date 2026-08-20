# med_application

Offline Flutter приложение для проверки взаимодействий лекарств (DDI-checker), русскоязычный рынок. Пользователь вводит два препарата; приложение одновременно (1) ищет пару в SQLite-таблице известных взаимодействий и (2) "минит" русскоязычные инструкции препаратов на предмет упоминаний взаимодействия, после чего объединяет оба сигнала в один результат.

## Архитектура (lib/)

- `main.dart` — точка входа, настраивает sqflite FFI для desktop, запускает `InteractionCheckScreen` напрямую. Внутри всё ещё лежит неиспользуемый Flutter counter-demo boilerplate (`MyHomePage`).
- `data/services/asset_database_opener.dart` — общий helper `openAssetDatabase()`: копирует asset-БД в documents dir (если её там ещё нет) и открывает через sqflite. Используется обоими *DbService, чтобы не дублировать эту логику.
- `data/services/db_service.dart` — синглтон `DatabaseService`, открывает `Interaction_pairs.db` через `openAssetDatabase()` с `forceRecopy: true` (dev-режим — пересоздаёт БД при каждом запуске).
- `data/services/chembl_db_service.dart` — синглтон `ChemblDbService`, открывает `chembl_37.db` через `openAssetDatabase()` с `forceRecopy: false` (read-only справочник, копируется один раз).
- `data/services/text_mining_service.dart` — чистый Dart NLP-слой: загрузка текстов инструкций, транслитерация EN↔RU названий препаратов, русский Porter-стеммер, извлечение раздела "взаимодействие" и evidence-предложений, фильтрация отрицаний ("не выявлено" и т.п.).
- `data/repositories/interaction_repository.dart` — тонкий слой запросов к таблице `PAIRS` (`Drug_A`, `Drug_B`, `Level`) в `Interaction_pairs.db`.
- `data/repositories/atc_repository.dart` — `AtcRepository.findAtcCodes(prefName)` — JOIN `molecule_dictionary` → `molecule_atc_classification` → `atc_classification` в `chembl_37.db`, возвращает `List<AtcCode>` (у препарата может быть несколько ATC-кодов).
- `models/` — `Interaction`, `InteractionResult` (агрегированный результат для UI, включая `atcCodesA`/`atcCodesB`), `Evidence` (предложение+контекст), `TextSearchResult`/`InteractionStatus` (enum: confirmedByText | ddiOnly | textOnly | noData), `AtcCode` (level5/level3/level4 коды + их англ. описания).
- `presentation/screens/interaction_screen.dart` — единственный экран приложения: ввод препаратов чипами, кнопка проверки, карточка результата (включая строки ATC-кодов по каждому препарату).
- `presentation/widgets/interaction_card.dart` — похоже, мёртвый код (экран рендерит результат сам, инлайново).

## Данные (assets/)

- `database/Interaction_pairs.db` — таблица `PAIRS`: Drug_A, Drug_B, Level. Используется через `DatabaseService`/`InteractionRepository`.
- `database/chembl_37.db` — публичная база ChEMBL 37, используется через `ChemblDbService`/`AtcRepository` для получения ATC-кодов препарата по латинскому (канонич.) названию (`molecule_dictionary.pref_name`, регистронезависимо). Схема описана в `chembl_atc_trade_schema.drawio` (в корне проекта). Ключевые таблицы: `atc_classification` (level1..level5 коды + описания), `molecule_dictionary` (molregno, pref_name), `molecule_atc_classification` (связка молекула↔ATC), `molecule_synonyms`/`products`/`formulations` (торговые названия — пока не подключены к UI, следующий шаг).
- `instructions/*.txt` — инструкции по 7 препаратам: carbamazepine, citalopram, digoxin, escitalopram, fluoxetine, ibuprofen, paroxetine, sertraline.
- `data/test_data.json` — legacy, оставшийся после миграции на SQLite (commit `1fc5b1b`), похоже больше не читается.

## Стек

sqflite + sqflite_common_ffi, path_provider. Без state-management пакета — обычный `StatefulWidget`/`setState`. Без сети — всё офлайн (bundled DB + bundled тексты инструкций).

## Известные проблемы / незавершённое

- `DatabaseService` пересоздаёт `Interaction_pairs.db` из asset при **каждом** запуске (`forceRecopy: true`, dev-режим) — нужно поправить перед релизом. `ChemblDbService` так не делает (`forceRecopy: false`).
- Торговые названия из `chembl_37.db` (`molecule_synonyms`/`products`) пока не подключены к UI — только ATC-коды (level5). Русские названия фармгрупп (по `level3`/`level4` кодам) — источник ещё не определён.
- Поле Autocomplete в UI не работает — `optionsBuilder` всегда возвращает пусто, реализовано только ручное добавление.
- Словарь канонизации названий (`substanceCanonical`/`substanceNames`) покрывает только escitalopram и sertraline; остальные 5 препаратов идут через хрупкую эвристическую транслитерацию.
- Список выбранных препаратов не жёстко ограничен двумя (проверка только `>= 2`), при этом код использует `selectedDrugs[0]`/`[1]` — 3-й препарат молча игнорируется.
- Мёртвый/legacy код: `InteractionCard` widget, закомментированные старые методы, debug `print(count)` в `interaction_repository.dart`, неиспользуемый `test_data.json`.
- **Подсвеченная evidence-фраза теряет родительский контекст.** `extractSection` схлопывает все переносы строк в пробелы, из-за чего `extractEvidence` (`text_mining_service.dart`) никогда не видит структуру буллет-списков — вся секция уходит в одну "line", которая режется по `[.!?;]` на клаузы. После фикса разбиения по `;` (было: гигантский блок из десятка категорий склеенных через `;`) каждая клауза стала короткой и точной, но конкретный препарат в списке (например "• антидепрессанты: ..., сертралин, ...;") теперь подсвечивается без заголовка типа "Влияние карбамазепина на концентрацию в плазме препаратов... следующих ЛС:", который лежит на несколько предложений/абзацев выше — пользователю не всегда понятно, к чему относится подсвеченный фрагмент. Простого решения нет: чтобы вернуть заголовок, `extractSection`/`extractEvidence` нужно переработать так, чтобы сохранять структуру строк (не схлопывать `\n`) и корректно матчить заголовок к каждому буллету — не точечная правка.

## История

Развитие: JSON-прототип → SQLite data layer → clean architecture (data/models/presentation) → единая модель `InteractionResult`. На момент написания — незакоммиченный рефакторинг `text_mining_service.dart` и `interaction_screen.dart`.
