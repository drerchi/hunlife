-- ============================================================================
-- HunLife — starter content (optional).
-- Run after schema.sql if you want sample topics/lessons/flashcards and a
-- starter set of citizenship-interview questions already in the app.
-- You can add/edit/delete all of this later from the in-app Admin panel.
-- ============================================================================

-- TOPIC 1: Greetings ---------------------------------------------------------
with t1 as (
  insert into public.topics (title_uk, title_hu, description_uk, icon, order_index)
  values ('Привітання', 'Köszönés', 'Базові фрази привітання та знайомства угорською.', 'waving_hand', 1)
  returning id
)
insert into public.lessons (topic_id, title_uk, title_hu, content_uk, order_index)
select id, 'Як привітатися', 'Köszönés',
  E'У цьому уроці ви вивчите базові привітання угорською мовою.\n\n' ||
  E'• Szia! — Привіт! (неформально, одній людині)\n' ||
  E'• Sziasztok! — Привіт! (неформально, кільком людям)\n' ||
  E'• Jó napot (kívánok)! — Доброго дня! (формально)\n' ||
  E'• Jó reggelt! — Доброго ранку!\n' ||
  E'• Jó estét! — Доброго вечора!\n' ||
  E'• Viszlát! — До побачення!\n' ||
  E'• Hogy vagy? — Як справи? (неформально)\n' ||
  E'• Hogy van? — Як справи? (формально)',
  1
from t1;

insert into public.flashcards (topic_id, front_hu, back_uk, example_hu, example_uk, order_index)
select id, 'Szia!', 'Привіт!', 'Szia, hogy vagy?', 'Привіт, як справи?', 1 from public.topics where title_hu = 'Köszönés'
union all
select id, 'Jó napot!', 'Доброго дня!', 'Jó napot kívánok!', 'Доброго дня вам!', 2 from public.topics where title_hu = 'Köszönés'
union all
select id, 'Viszlát!', 'До побачення!', 'Viszlát, holnap találkozunk!', 'До побачення, побачимось завтра!', 3 from public.topics where title_hu = 'Köszönés'
union all
select id, 'Köszönöm', 'Дякую', 'Köszönöm szépen a segítséget!', 'Щиро дякую за допомогу!', 4 from public.topics where title_hu = 'Köszönés'
union all
select id, 'Kérem', 'Будь ласка', 'Kérem, segítsen!', 'Будь ласка, допоможіть!', 5 from public.topics where title_hu = 'Köszönés';

-- TOPIC 2: Family -------------------------------------------------------------
with t2 as (
  insert into public.topics (title_uk, title_hu, description_uk, icon, order_index)
  values ('Сім''я', 'Család', 'Слова та фрази про членів родини.', 'family_restroom', 2)
  returning id
)
insert into public.lessons (topic_id, title_uk, title_hu, content_uk, order_index)
select id, 'Члени родини', 'A család tagjai',
  E'Основна лексика для опису родини угорською.\n\n' ||
  E'• család — сім''я\n' ||
  E'• anya / édesanya — мама\n' ||
  E'• apa / édesapa — тато\n' ||
  E'• testvér — брат/сестра (загальне слово)\n' ||
  E'• fiú — син / хлопчик\n' ||
  E'• lánya — донька / дівчинка\n' ||
  E'• nagymama — бабуся\n' ||
  E'• nagypapa — дідусь\n' ||
  E'• feleség — дружина\n' ||
  E'• férj — чоловік (у шлюбі)',
  1
from t2;

insert into public.flashcards (topic_id, front_hu, back_uk, example_hu, example_uk, order_index)
select id, 'anya', 'мама', 'Az anyám tanár.', 'Моя мама вчителька.', 1 from public.topics where title_hu = 'Család'
union all
select id, 'apa', 'тато', 'Az apám mérnök.', 'Мій тато інженер.', 2 from public.topics where title_hu = 'Család'
union all
select id, 'testvér', 'брат/сестра', 'Van egy testvérem.', 'У мене є брат/сестра.', 3 from public.topics where title_hu = 'Család'
union all
select id, 'gyerek', 'дитина', 'Két gyerekem van.', 'У мене двоє дітей.', 4 from public.topics where title_hu = 'Család';

-- TOPIC 3: Numbers --------------------------------------------------------
with t3 as (
  insert into public.topics (title_uk, title_hu, description_uk, icon, order_index)
  values ('Числа', 'Számok', 'Числа від 1 до 20 угорською.', 'onetwothree', 3)
  returning id
)
insert into public.flashcards (topic_id, front_hu, back_uk, order_index)
select id, v.hu, v.uk, v.ord from t3, (values
  ('egy', 'один', 1), ('kettő', 'два', 2), ('három', 'три', 3), ('négy', 'чотири', 4),
  ('öt', 'п''ять', 5), ('hat', 'шість', 6), ('hét', 'сім', 7), ('nyolc', 'вісім', 8),
  ('kilenc', 'дев''ять', 9), ('tíz', 'десять', 10)
) as v(hu, uk, ord);

-- CITIZENSHIP INTERVIEW PREP --------------------------------------------------
insert into public.citizenship_questions (category, question_hu, question_uk, answer_hu, answer_uk, order_index) values
('Особисті дані', 'Mi a neve?', 'Як вас звати?', 'A nevem [teljes név].', 'Мене звати [повне ім''я].', 1),
('Особисті дані', 'Mikor és hol született?', 'Коли і де ви народилися?', 'Én [dátum]-ban/ben születtem, [helyszín]-en/on.', 'Я народився/народилася [дата] у [місце].', 2),
('Особисті дані', 'Hol lakik jelenleg?', 'Де ви зараз проживаєте?', 'Jelenleg [város/cím]-en/on lakom.', 'Наразі я проживаю у [місто/адреса].', 3),
('Особисті дані', 'Mióta él Magyarországon?', 'Відколи ви живете в Угорщині?', '[Év/időszak] óta élek Magyarországon.', 'Я живу в Угорщині з [рік/період].', 4),
('Держава та символи', 'Mi Magyarország fővárosa?', 'Яка столиця Угорщини?', 'Magyarország fővárosa Budapest.', 'Столиця Угорщини — Будапешт.', 5),
('Держава та символи', 'Milyen színű a magyar zászló?', 'Якого кольору угорський прапор?', 'A magyar zászló piros-fehér-zöld színű.', 'Угорський прапор червоно-біло-зелений.', 6),
('Держава та символи', 'Mi Magyarország himnuszának a címe?', 'Як називається гімн Угорщини?', 'A magyar himnusz címe egyszerűen "Himnusz", szerzője Kölcsey Ferenc.', 'Угорський гімн називається "Himnusz" ("Гімн"), автор тексту — Ференц Кьольчеї.', 7),
('Держава та символи', 'Ki Magyarország államfője?', 'Хто є главою держави Угорщини?', 'Magyarország államfője a köztársasági elnök.', 'Главою держави Угорщини є президент республіки.', 8),
('Держава та символи', 'Milyen államforma Magyarország?', 'Яка форма державного устрою в Угорщині?', 'Magyarország parlamentáris köztársaság.', 'Угорщина є парламентською республікою.', 9),
('Мова та культура', 'Milyen nyelvet beszélnek Magyarországon?', 'Якою мовою розмовляють в Угорщині?', 'Magyarországon magyarul beszélnek.', 'В Угорщині розмовляють угорською мовою.', 10),
('Мова та культура', 'Mi a hivatalos pénznem Magyarországon?', 'Яка офіційна валюта в Угорщині?', 'A hivatalos pénznem a forint (HUF).', 'Офіційна валюта — форинт (HUF).', 11),
('Мова та культура', 'Mikor van a nemzeti ünnep Magyarországon?', 'Коли національне свято в Угорщині?', 'Magyarországon több nemzeti ünnep is van: március 15., augusztus 20. és október 23.', 'В Угорщині кілька національних свят: 15 березня, 20 серпня та 23 жовтня.', 12),
('Родина та побут', 'Van családja Magyarországon?', 'Чи є у вас родина в Угорщині?', 'Igen, a családom Magyarországon él velem együtt.', 'Так, моя родина живе разом зі мною в Угорщині.', 13),
('Родина та побут', 'Miért szeretne magyar állampolgár lenni?', 'Чому ви хочете стати громадянином Угорщини?', 'Azért szeretnék magyar állampolgár lenni, mert itt élek, dolgozom, és szorosan kötődöm az országhoz.', 'Я хочу стати громадянином Угорщини, тому що живу і працюю тут і тісно пов''язаний(-а) з країною.', 14);
