-- RLS-Tests mit vier Identitaeten: Eigentuemer, Teamkollege, Fremder, Anonym.
-- Das ist der Teil, den fast alle ueberspringen und der spaeter der Grund
-- fuer einen Datenleck-Post ist.
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- Setup als Superuser
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner@test.invalid'),
  ('22222222-2222-2222-2222-222222222222', 'teammate@test.invalid'),
  ('33333333-3333-3333-3333-333333333333', 'stranger@test.invalid');

insert into public.teams (id, name, owner_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Testkueche', '11111111-1111-1111-1111-111111111111');

insert into public.team_members (team_id, user_id, role) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'azubi');

-- ---------------------------------------------------------------------------
-- Eigentuemer legt ein privates und ein Team-Rezept an
-- ---------------------------------------------------------------------------

begin;
  set local role authenticated;
  do $sub$ begin perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true); end $sub$;

  insert into public.recipes (id, owner_id, title, visibility)
  values ('dddddddd-dddd-dddd-dddd-dddddddddddd',
          '11111111-1111-1111-1111-111111111111', 'Privates Familienrezept', 'private');

  insert into public.recipes (id, owner_id, title, visibility, team_id)
  values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
          '11111111-1111-1111-1111-111111111111', 'Betriebsrezeptur Jus', 'team',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

  insert into public.recipe_ingredients (recipe_id, raw_text, sort_order)
  values ('dddddddd-dddd-dddd-dddd-dddddddddddd', '250 g Mehl', 1);

  do $$
  declare n int;
  begin
    select count(*) into n from public.recipes;
    if n <> 2 then raise exception 'Eigentuemer sieht % statt 2 Rezepte', n; end if;
    raise notice '  [ok] Eigentuemer sieht beide eigenen Rezepte';
  end $$;
commit;

-- ---------------------------------------------------------------------------
-- Eigentuemer darf kein Rezept auf fremden Namen anlegen
-- ---------------------------------------------------------------------------

begin;
  set local role authenticated;
  do $sub$ begin perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true); end $sub$;

  do $$
  declare caught boolean := false;
  begin
    begin
      insert into public.recipes (owner_id, title)
      values ('33333333-3333-3333-3333-333333333333', 'Untergeschoben');
    exception when insufficient_privilege then caught := true;
    end;
    if not caught then raise exception 'Fremdes owner_id beim Insert wurde akzeptiert'; end if;
    raise notice '  [ok] Insert auf fremdes owner_id wird abgewiesen';
  end $$;
rollback;

-- ---------------------------------------------------------------------------
-- Teamkollege: sieht das Team-Rezept, nicht das private
-- ---------------------------------------------------------------------------

begin;
  set local role authenticated;
  do $sub$ begin perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true); end $sub$;

  do $$
  declare n int; titles text;
  begin
    select count(*), coalesce(string_agg(title, ', '), '') into n, titles from public.recipes;
    if n <> 1 then raise exception 'Teamkollege sieht % statt 1 Rezept (%)', n, titles; end if;
    if titles <> 'Betriebsrezeptur Jus' then
      raise exception 'Teamkollege sieht das falsche Rezept: %', titles;
    end if;

    -- Zutaten des privaten Rezepts duerfen nicht durchsickern
    select count(*) into n from public.recipe_ingredients;
    if n <> 0 then raise exception 'Teamkollege sieht % fremde Zutatenzeilen', n; end if;

    raise notice '  [ok] Teamkollege sieht nur das Team-Rezept, keine privaten Zutaten';
  end $$;

  -- Azubi darf das Team-Rezept nicht veraendern (nur owner/admin/ausbilder)
  do $$
  declare n int;
  begin
    update public.recipes set title = 'Gekapert'
     where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'Azubi konnte ein Team-Rezept aendern'; end if;
    raise notice '  [ok] Azubi kann Team-Rezepte nicht aendern';
  end $$;
rollback;

-- ---------------------------------------------------------------------------
-- Fremder: sieht gar nichts
-- ---------------------------------------------------------------------------

begin;
  set local role authenticated;
  do $sub$ begin perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true); end $sub$;

  do $$
  declare n int;
  begin
    select count(*) into n from public.recipes;
    if n <> 0 then raise exception 'Fremder sieht % Rezepte', n; end if;

    select count(*) into n from public.recipe_ingredients;
    if n <> 0 then raise exception 'Fremder sieht % Zutatenzeilen', n; end if;

    select count(*) into n from public.teams;
    if n <> 0 then raise exception 'Fremder sieht % Teams', n; end if;

    select count(*) into n from public.profiles;
    if n <> 1 then raise exception 'Fremder sieht % Profile statt nur sein eigenes', n; end if;

    raise notice '  [ok] Fremder sieht keine Rezepte, keine Teams, nur sein Profil';
  end $$;

  -- Loeschversuch auf fremdes Rezept laeuft ins Leere statt zu loeschen
  do $$
  declare n int;
  begin
    delete from public.recipes where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
    get diagnostics n = row_count;
    if n <> 0 then raise exception 'Fremder konnte ein fremdes Rezept loeschen'; end if;
    raise notice '  [ok] Fremder kann fremde Rezepte nicht loeschen';
  end $$;
rollback;

-- ---------------------------------------------------------------------------
-- Anonym: sieht nichts, auch keine Referenzdaten
-- ---------------------------------------------------------------------------

begin;
  set local role anon;

  do $$
  declare caught boolean := false;
  begin
    begin
      perform count(*) from public.recipes;
    exception when insufficient_privilege then caught := true;
    end;
    if not caught then raise exception 'anon hat Leserechte auf recipes'; end if;
    raise notice '  [ok] anon hat keinen Zugriff auf Rezepte';
  end $$;
rollback;

-- ---------------------------------------------------------------------------
-- Lernfortschritt ist auch fuer Teamkollegen tabu
-- ---------------------------------------------------------------------------

begin;
  set local role authenticated;
  do $sub$ begin perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true); end $sub$;
  insert into public.cook_logs (user_id, recipe_title_cache, note)
  values ('11111111-1111-1111-1111-111111111111', 'Jus', 'Erster Versuch, zu salzig');
commit;

begin;
  set local role authenticated;
  do $sub$ begin perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true); end $sub$;

  do $$
  declare n int;
  begin
    select count(*) into n from public.cook_logs;
    if n <> 0 then raise exception 'Teamkollege sieht % fremde Kochprotokolle', n; end if;
    raise notice '  [ok] Kochprotokolle sind auch im Team privat';
  end $$;
rollback;

-- ---------------------------------------------------------------------------
-- Kontingente darf der Client nicht selbst hochsetzen
-- ---------------------------------------------------------------------------

begin;
  set local role authenticated;
  do $sub$ begin perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true); end $sub$;

  do $$
  declare caught boolean := false;
  begin
    begin
      update public.usage_quota set scans_limit = 999999
       where user_id = '11111111-1111-1111-1111-111111111111';
    exception when insufficient_privilege then caught := true;
    end;
    if not caught then raise exception 'Client konnte sein Scan-Kontingent aendern'; end if;
    raise notice '  [ok] Scan-Kontingent ist fuer den Client schreibgeschuetzt';
  end $$;
rollback;

-- ---------------------------------------------------------------------------
-- Storage: nur der eigene Ordner
-- ---------------------------------------------------------------------------

begin;
  set local role authenticated;
  do $sub$ begin perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true); end $sub$;

  insert into storage.objects (bucket_id, name)
  values ('scans', '11111111-1111-1111-1111-111111111111/scan-1.jpg');

  do $$
  declare caught boolean := false;
  begin
    begin
      insert into storage.objects (bucket_id, name)
      values ('scans', '33333333-3333-3333-3333-333333333333/geklaut.jpg');
    exception when insufficient_privilege then caught := true;
    end;
    if not caught then raise exception 'Upload in fremden Storage-Ordner moeglich'; end if;
    raise notice '  [ok] Storage-Upload nur in den eigenen Ordner';
  end $$;
rollback;

-- ---------------------------------------------------------------------------
-- Kontoloeschung raeumt vollstaendig auf
-- ---------------------------------------------------------------------------

do $$
declare n int;
begin
  perform public.delete_account('11111111-1111-1111-1111-111111111111');

  select count(*) into n from public.recipes
   where owner_id = '11111111-1111-1111-1111-111111111111';
  if n <> 0 then raise exception 'Nach Kontoloeschung bleiben % Rezepte', n; end if;

  select count(*) into n from public.cook_logs
   where user_id = '11111111-1111-1111-1111-111111111111';
  if n <> 0 then raise exception 'Nach Kontoloeschung bleiben % Kochprotokolle', n; end if;

  select count(*) into n from auth.users
   where id = '11111111-1111-1111-1111-111111111111';
  if n <> 0 then raise exception 'Nach Kontoloeschung bleibt der auth-Nutzer bestehen'; end if;

  raise notice '  [ok] Kontoloeschung raeumt Rezepte, Protokolle und Auth-Nutzer ab';
end $$;

-- Teamaufloesung darf Rezepte nicht in einen unerlaubten Zustand ziehen
do $$
declare u uuid; t uuid; r uuid; vis recipe_visibility; tid uuid;
begin
  insert into auth.users (email) values ('detach@test.invalid') returning id into u;
  insert into public.teams (name, owner_id) values ('Aufloesung', u) returning id into t;
  insert into public.team_members (team_id, user_id, role) values (t, u, 'owner');
  insert into public.recipes (owner_id, title, visibility, team_id)
  values (u, 'Betriebsrezeptur', 'team', t) returning id into r;

  delete from public.teams where id = t;

  select visibility, team_id into vis, tid from public.recipes where id = r;
  if vis <> 'private' then raise exception 'Rezept blieb nach Teamaufloesung auf %', vis; end if;
  if tid is not null then raise exception 'team_id blieb nach Teamaufloesung gesetzt'; end if;

  raise notice '  [ok] Teamaufloesung stellt Rezepte auf privat statt zu scheitern';
  perform public.delete_account(u);
end $$;


-- ---------------------------------------------------------------------------
-- Kontoloeschung bei geteiltem Team: Eigentum muss uebergehen, nicht blockieren
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('44444444-4444-4444-4444-444444444444', 'chef@test.invalid'),
  ('55555555-5555-5555-5555-555555555555', 'sous@test.invalid');

insert into public.teams (id, name, owner_id) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Geteilte Kueche',
   '44444444-4444-4444-4444-444444444444');

insert into public.team_members (team_id, user_id, role) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '44444444-4444-4444-4444-444444444444', 'owner'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '55555555-5555-5555-5555-555555555555', 'admin');

do $$
declare new_owner uuid; n int;
begin
  perform public.delete_account('44444444-4444-4444-4444-444444444444');

  select owner_id into new_owner from public.teams
   where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  if new_owner is null then
    raise exception 'Team wurde geloescht, obwohl ein Admin uebernehmen konnte';
  end if;
  if new_owner <> '55555555-5555-5555-5555-555555555555' then
    raise exception 'Eigentum ging an % statt an den verbliebenen Admin', new_owner;
  end if;

  select count(*) into n from public.team_members
   where team_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
     and user_id = '55555555-5555-5555-5555-555555555555'
     and role = 'owner';
  if n <> 1 then raise exception 'Nachfolger wurde nicht auf owner hochgestuft'; end if;

  raise notice '  [ok] Kontoloeschung uebertraegt Team-Eigentum statt zu blockieren';
end $$;

-- Und der Gegenfall: einziger Eigentuemer, Team wird mitgeloescht
insert into auth.users (id, email) values
  ('66666666-6666-6666-6666-666666666666', 'solo@test.invalid');
insert into public.teams (id, name, owner_id) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Solo', '66666666-6666-6666-6666-666666666666');
insert into public.team_members (team_id, user_id, role) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '66666666-6666-6666-6666-666666666666', 'owner');

do $$
declare n int;
begin
  perform public.delete_account('66666666-6666-6666-6666-666666666666');
  select count(*) into n from public.teams where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  if n <> 0 then raise exception 'Verwaistes Team blieb zurueck'; end if;
  raise notice '  [ok] Team ohne moeglichen Nachfolger wird mitgeloescht';
end $$;

-- Aufraeumen: ueber delete_account, weil ein direktes Loeschen an
-- teams_owner_id_fkey scheitert. Genau das soll der Constraint auch tun.
do $$
declare u uuid;
begin
  for u in select id from auth.users where email like '%@test.invalid' loop
    perform public.delete_account(u);
  end loop;
end $$;
