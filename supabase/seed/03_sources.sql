insert into public.sources (slug, name, homepage_url, license_note, attribution, allows_body) values
  ('user_url_import', 'Nutzerimport per URL', null,
   'Nutzerinitiierter Import in das eigene, private Kochbuch. Keine Weitergabe, '
   'keine oeffentliche Anzeige, DB-seitig per Constraint erzwungen (ADR-6).',
   'Quelle: siehe source_url', true),
  ('themealdb', 'TheMealDB', 'https://www.themealdb.com',
   'Freie API, Attribution erwuenscht. Lizenzbedingungen vor Nutzung pruefen.',
   'Rezeptdaten von TheMealDB', true),
  ('openfoodfacts', 'Open Food Facts', 'https://world.openfoodfacts.org',
   'ODbL. Attribution und Share-Alike fuer abgeleitete Datenbanken verpflichtend.',
   'Zutatendaten von Open Food Facts, ODbL', false)
on conflict (slug) do nothing;
