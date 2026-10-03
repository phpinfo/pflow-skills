# УТР by ГОСТ Р 58049-2017

Simplified Technical Russian (упрощённый технический русский, УТР) is section 8.2 of ГОСТ Р 58049-2017, a controlled language for aviation operating docs. Read it when `SKILL.md` and `ru.md` leave a phrasing or formatting question open; where they differ, they win.

Words. One term per object in the whole text, no synonyms; approved terms and abbreviations go into the glossary. No foreign word when a Russian one exists, no slang, jargon, metaphors or comparisons. Do not drop words if the meaning can suffer. Link text names the target («Настройка прокси»), not «ссылка» or «нажмите здесь».

Sentences. Direct word order and active voice: «Сервис пишет лог», not «Лог пишется сервисом». At most 20 words; a number, abbreviation or identifier counts as one word, a name or quote as one word, text in brackets as a separate sentence. Split a complex sentence into simple ones; join with a conjunction only steps that follow each other. No chains of three or more nouns («проверка корректности заполнения полей»): use a verb («Проверьте, что поля заполнены»). Limit participial and gerund phrases and compound predicates: «ключ в конфиге», not «ключ, указанный в конфиге».

Instructions and descriptions. A step starts with the verb in imperative plural: «Запустите `make build`.», never «Запусти» or «Необходимо запустить». One action per sentence; two only when done at the same time. Name the exact action and object. A description paragraph holds one topic and at most six sentences; a one-sentence paragraph appears at most once per ten. Enumerations in complex text go into a bulleted list. Brackets hold cross-references, callouts and side information; a note holds only additional information.

Warnings. Condition first, then the command, then a short reason: «Если база рабочая, сначала сделайте бэкап: миграция удаляет столбец.»

Apply it at about 80%. Clarity rules apply as written. The formal side relaxes: 20 words and six sentences are targets, not hard caps; no ГОСТ-style abbreviation chains («ТОиР АТ») unless the glossary has them; an imperative or a named subject beats an impersonal «Выполняют контроль»; the bureaucratese bans in `ru.md` still hold.
