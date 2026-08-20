-- LMIV Anhang II, 14 Hauptallergene
insert into public.allergens (code, label_de, label_en, sort_order) values
  ('gluten',     'Glutenhaltiges Getreide',        'Cereals containing gluten', 1),
  ('crustacean', 'Krebstiere',                     'Crustaceans',               2),
  ('egg',        'Eier',                           'Eggs',                      3),
  ('fish',       'Fische',                         'Fish',                      4),
  ('peanut',     'Erdnuesse',                      'Peanuts',                   5),
  ('soy',        'Soja',                           'Soybeans',                  6),
  ('milk',       'Milch und Laktose',              'Milk',                      7),
  ('nuts',       'Schalenfruechte',                'Tree nuts',                 8),
  ('celery',     'Sellerie',                       'Celery',                    9),
  ('mustard',    'Senf',                           'Mustard',                  10),
  ('sesame',     'Sesamsamen',                     'Sesame',                   11),
  ('sulphite',   'Schwefeldioxid und Sulphite',    'Sulphur dioxide',          12),
  ('lupin',      'Lupinen',                        'Lupin',                    13),
  ('mollusc',    'Weichtiere',                     'Molluscs',                 14)
on conflict (code) do nothing;
