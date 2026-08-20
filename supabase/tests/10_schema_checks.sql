-- Strukturprüfungen. Laufen als Superuser, prüfen Metadaten und Constraints.
\set ON_ERROR_STOP on

-- 1. Jede Tabelle in public muss RLS aktiviert haben. Keine Ausnahme.
do $$
declare
  missing text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into missing
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind = 'r'
     and c.relrowsecurity = false;

  if missing is not null then
    raise exception 'RLS fehlt auf: %', missing;
  end if;
  raise notice '  [ok] RLS ist auf allen public-Tabellen aktiv';
end $$;

-- 2. Jede Tabelle mit RLS braucht mindestens eine Policy,
--    sonst ist sie fuer alle Angemeldeten unsichtbar statt geschuetzt.
do $$
declare
  missing text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into missing
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind = 'r'
     and c.relrowsecurity = true
     and not exists (select 1 from pg_policy p where p.polrelid = c.oid);

  if missing is not null then
    raise exception 'RLS aktiv aber keine Policy auf: %', missing;
  end if;
  raise notice '  [ok] jede Tabelle mit RLS hat mindestens eine Policy';
end $$;

-- 3. Jede security-definer-Funktion muss einen fixierten search_path haben,
--    sonst ist sie ein Angriffsvektor.
do $$
declare
  bad text;
begin
  select string_agg(p.proname, ', ' order by p.proname)
    into bad
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.prosecdef = true
     and (p.proconfig is null
          or not exists (select 1 from unnest(p.proconfig) cfg where cfg like 'search_path=%'));

  if bad is not null then
    raise exception 'security definer ohne search_path: %', bad;
  end if;
  raise notice '  [ok] alle security-definer-Funktionen haben einen fixen search_path';
end $$;

-- 4. Constraints muessen greifen, nicht nur dastehen.
do $$
declare
  u uuid;
  t uuid;
  caught boolean;
begin
  insert into auth.users (email) values ('constraint-test@example.invalid') returning id into u;

  -- 4a. visibility='team' ohne team_id muss scheitern
  caught := false;
  begin
    insert into public.recipes (owner_id, title, visibility) values (u, 'X', 'team');
  exception when check_violation then caught := true;
  end;
  if not caught then raise exception 'recipes_team_scope greift nicht (team ohne team_id)'; end if;

  -- 4b. url_import darf nicht auf team stehen
  insert into public.teams (name, owner_id) values ('T', u) returning id into t;
  insert into public.team_members (team_id, user_id, role) values (t, u, 'owner');
  caught := false;
  begin
    insert into public.recipes (owner_id, title, visibility, team_id, source_type)
    values (u, 'X', 'team', t, 'url_import');
  exception when check_violation then caught := true;
  end;
  if not caught then raise exception 'recipes_import_private greift nicht'; end if;

  -- 4c. public ist in v1 gesperrt
  caught := false;
  begin
    insert into public.recipes (owner_id, title, visibility) values (u, 'X', 'public');
  exception when check_violation then caught := true;
  end;
  if not caught then raise exception 'recipes_no_public_v1 greift nicht'; end if;

  -- 4d. srs_cards braucht genau ein Subjekt
  caught := false;
  begin
    insert into public.srs_cards (user_id, card_type) values (u, 'definition');
  exception when check_violation then caught := true;
  end;
  if not caught then raise exception 'srs_cards_subject greift nicht'; end if;

  raise notice '  [ok] Check-Constraints greifen';
  perform public.delete_account(u);
end $$;

-- 5. Volltextsuche muss ueber Zutaten und Schritte hinweg funktionieren.
do $$
declare
  u uuid; r uuid; hits int;
begin
  insert into auth.users (email) values ('fts-test@example.invalid') returning id into u;
  insert into public.recipes (owner_id, title, description)
  values (u, 'Omas Kartoffelsuppe', 'Wie frueher') returning id into r;

  insert into public.recipe_ingredients (recipe_id, raw_text, sort_order)
  values (r, '500 g Kartoffeln', 1), (r, '1 Stange Lauch', 2);

  insert into public.recipe_steps (recipe_id, step_number, body)
  values (r, 1, 'Den Lauch in feine Ringe schneiden und anschwitzen.');

  select count(*) into hits from public.recipes
   where id = r and search_vector @@ plainto_tsquery('german', 'Lauch');
  if hits <> 1 then raise exception 'FTS findet Zutat/Schritt nicht (Lauch)'; end if;

  select count(*) into hits from public.recipes
   where id = r and search_vector @@ plainto_tsquery('german', 'anschwitzen');
  if hits <> 1 then raise exception 'FTS findet Schritttext nicht'; end if;

  raise notice '  [ok] search_vector deckt Titel, Zutaten und Schritte ab';
  delete from auth.users where id = u;
end $$;

-- 6. Seeds sind vollstaendig eingespielt.
do $$
declare n int;
begin
  select count(*) into n from public.allergens;
  if n <> 14 then raise exception 'Allergene: erwartet 14, gefunden %', n; end if;

  select count(distinct axis) into n from public.tags;
  if n <> 7 then raise exception 'Taxonomie-Achsen: erwartet 7, gefunden %', n; end if;

  raise notice '  [ok] Seeds vollstaendig (14 Allergene, 7 Taxonomie-Achsen)';
end $$;
