-- Lernkueche :: 006 Betriebsinfrastruktur
-- Scan-Jobs, Nutzungskontingente, Sync-Zustand, Storage, Kontoloeschung.

-- ---------------------------------------------------------------------------
-- scan_jobs
-- ---------------------------------------------------------------------------

create table public.scan_jobs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  status        scan_status not null default 'queued',
  page_paths    jsonb not null default '[]'::jsonb,
  -- Hash der Seitenbilder: verhindert, dass derselbe Scan doppelt bezahlt wird.
  content_hash  text,
  ocr_text      text,
  llm_result    jsonb,
  recipe_id     uuid references public.recipes (id) on delete set null,
  token_cost    int not null default 0,
  error_code    text,
  error_detail  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index scan_jobs_user_idx on public.scan_jobs (user_id, created_at desc);
create index scan_jobs_hash_idx on public.scan_jobs (user_id, content_hash);

create trigger scan_jobs_set_updated_at
  before update on public.scan_jobs
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- usage_quota
-- Ohne serverseitiges Limit ist jeder LLM-Aufruf eine offene Rechnung,
-- die jemand mit einem Skript trivial hochtreibt. Der Client zaehlt nicht mit,
-- er darf nur lesen.
-- ---------------------------------------------------------------------------

create table public.usage_quota (
  user_id           uuid not null references public.profiles (id) on delete cascade,
  period_start      date not null default date_trunc('month', current_date)::date,
  scans_used        int not null default 0,
  scans_limit       int not null default 30,
  llm_tokens_used   int not null default 0,
  llm_tokens_limit  int not null default 400000,
  updated_at        timestamptz not null default now(),
  primary key (user_id, period_start)
);

create trigger usage_quota_set_updated_at
  before update on public.usage_quota
  for each row execute function public.set_updated_at();

-- Atomarer Verbrauch. Wird ausschliesslich von Edge Functions mit service_role
-- aufgerufen. Gibt false zurueck, wenn das Kontingent erschoepft ist.
create or replace function public.consume_scan_quota(target_user uuid, tokens int default 0)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  period date := date_trunc('month', current_date)::date;
  ok boolean;
begin
  insert into public.usage_quota (user_id, period_start)
  values (target_user, period)
  on conflict (user_id, period_start) do nothing;

  update public.usage_quota q
     set scans_used = q.scans_used + 1,
         llm_tokens_used = q.llm_tokens_used + tokens
   where q.user_id = target_user
     and q.period_start = period
     and q.scans_used < q.scans_limit
     and q.llm_tokens_used < q.llm_tokens_limit
  returning true into ok;

  return coalesce(ok, false);
end;
$$;

revoke execute on function public.consume_scan_quota(uuid, int) from public, authenticated, anon;

-- ---------------------------------------------------------------------------
-- sync_state
-- Cursor je Nutzer und Tabelle fuer den inkrementellen Pull der Sync-Engine.
-- ---------------------------------------------------------------------------

create table public.sync_state (
  user_id         uuid not null references public.profiles (id) on delete cascade,
  table_name      text not null,
  last_pulled_at  timestamptz not null default 'epoch',
  primary key (user_id, table_name)
);

-- ---------------------------------------------------------------------------
-- Tombstones
-- Hartes Loeschen muss ueber Geraete hinweg ankommen, sonst taucht ein
-- geloeschter Datensatz beim naechsten Push wieder auf.
-- ---------------------------------------------------------------------------

create table public.deletions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  table_name  text not null,
  row_id      uuid not null,
  deleted_at  timestamptz not null default now(),
  unique (user_id, table_name, row_id)
);

create index deletions_pull_idx on public.deletions (user_id, deleted_at);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.scan_jobs   enable row level security;
alter table public.usage_quota enable row level security;
alter table public.sync_state  enable row level security;
alter table public.deletions   enable row level security;

create policy scan_jobs_all on public.scan_jobs
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Nur lesen. Schreiben ausschliesslich ueber consume_scan_quota mit service_role.
create policy usage_quota_read on public.usage_quota
  for select to authenticated using (user_id = auth.uid());

create policy sync_state_all on public.sync_state
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy deletions_all on public.deletions
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage
-- Pfadkonvention: <user_id>/<rest>. Die erste Pfadkomponente ist die Nutzer-ID,
-- darauf setzt die Policy auf.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('recipe-images', 'recipe-images', false, 8388608,  array['image/jpeg','image/png','image/webp','image/heic']),
  ('scans',         'scans',         false, 16777216, array['image/jpeg','image/png','image/heic']),
  ('avatars',       'avatars',       false, 2097152,  array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy storage_own_folder_read on storage.objects
  for select to authenticated
  using (
    bucket_id in ('recipe-images','scans','avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_own_folder_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('recipe-images','scans','avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_own_folder_update on storage.objects
  for update to authenticated
  using (
    bucket_id in ('recipe-images','scans','avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_own_folder_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('recipe-images','scans','avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- Kontoloeschung
-- App Store Guideline 5.1.1(v): muss in der App moeglich sein.
-- Wird ab Tag eins gebaut, nicht in Phase 8 nachgeruestet.
-- Aufruf durch eine Edge Function mit service_role.
-- ---------------------------------------------------------------------------

create or replace function public.delete_account(target_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  t record;
  successor uuid;
begin
  -- teams.owner_id steht auf "on delete restrict": ein Team darf nicht
  -- eigentuemerlos zurueckbleiben. Ohne den folgenden Block scheitert die
  -- Kontoloeschung stumm, sobald der Nutzer irgendein Team besitzt.
  for t in
    select id from public.teams where owner_id = target_user
  loop
    select m.user_id
      into successor
      from public.team_members m
     where m.team_id = t.id
       and m.user_id <> target_user
       and m.role in ('owner', 'admin')
     order by m.created_at
     limit 1;

    if successor is null then
      -- Niemand kann uebernehmen: Team mitloeschen.
      delete from public.teams where id = t.id;
    else
      -- Eigentum uebertragen, damit das Team weiterlebt.
      update public.teams set owner_id = successor where id = t.id;
      update public.team_members set role = 'owner'
       where team_id = t.id and user_id = successor;
    end if;
  end loop;

  -- Alles Uebrige haengt per on delete cascade an profiles.
  delete from public.profiles where id = target_user;
  delete from auth.users where id = target_user;
end;
$$;

revoke execute on function public.delete_account(uuid) from public, authenticated, anon;
