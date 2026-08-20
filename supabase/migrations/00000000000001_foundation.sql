-- Lernkueche :: 001 Foundation
-- Extensions, Enums, gemeinsame Trigger, Profile, Teams.
-- Teams sind in v1 ohne UI, das Schema traegt sie aber von Anfang an,
-- damit spaeter kein Rewrite der RLS-Policies noetig ist (siehe DECISIONS.md ADR-3).

create extension if not exists "pgcrypto";
create extension if not exists "vector";
create extension if not exists "pg_trgm";
create extension if not exists "unaccent";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type recipe_visibility as enum ('private', 'team', 'public');
create type recipe_source_type as enum ('manual', 'scan', 'url_import', 'seed');
create type team_role as enum ('owner', 'admin', 'member', 'ausbilder', 'azubi');
create type scan_status as enum ('queued', 'ocr', 'llm', 'review', 'done', 'failed');
create type srs_state as enum ('new', 'learning', 'review', 'relearning');
create type difficulty_source as enum ('heuristic', 'author', 'community');

-- ---------------------------------------------------------------------------
-- Gemeinsame Trigger-Funktion
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Textnormalisierung
-- unaccent() ist NICHT immutable und taugt damit nicht fuer eine generated
-- column. Diese Funktion ist echt immutable, auf Deutsch zugeschnitten und
-- wird zeichengleich in Swift gespiegelt (DomainKit/TextNormalizer), damit
-- lokale Offline-Suche und Serversuche dieselben Treffer liefern.
-- ---------------------------------------------------------------------------

create or replace function public.normalize_text(input text)
returns text
language sql
immutable
strict
parallel safe
as $$
  select btrim(
           regexp_replace(
             translate(
               replace(lower(input), 'ß', 'ss'),
               'äöüàáâãåéèêëíìîïóòôõøúùûýñç',
               'aouaaaaaeeeeiiiiooooouuuync'
             ),
             '\s+', ' ', 'g'
           )
         );
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- Kein Geburtsdatum, keine Altersabfrage: v1 hat keine oeffentlichen Inhalte
-- und keine Fremdkontakte, damit entfaellt die Rechtsgrundlage, das zu erheben.
-- Datenminimierung nach Art. 5 Abs. 1 lit. c DSGVO.
-- ---------------------------------------------------------------------------

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null default '',
  locale        text not null default 'de',
  avatar_path   text,
  -- Ausbildungskontext, alles freiwillig und rein lokal genutzt
  training_role text check (training_role in ('azubi', 'ausbilder', 'privat')),
  exam_date     date,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Profil automatisch beim Signup anlegen.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- teams
-- ---------------------------------------------------------------------------

create table public.teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(trim(name)) between 1 and 120),
  owner_id    uuid not null references public.profiles (id) on delete restrict,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create trigger teams_set_updated_at
  before update on public.teams
  for each row execute function public.set_updated_at();

create table public.team_members (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid not null references public.teams (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  role        team_role not null default 'member',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (team_id, user_id)
);

create index team_members_user_idx on public.team_members (user_id);
create index team_members_team_idx on public.team_members (team_id);

create trigger team_members_set_updated_at
  before update on public.team_members
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS-Helfer
-- security definer, damit die Policy auf team_members nicht rekursiv
-- gegen sich selbst laeuft. Das ist der klassische Supabase-Fallstrick.
-- search_path fix, sonst ist die Funktion ein Angriffsvektor.
-- ---------------------------------------------------------------------------

create or replace function public.is_team_member(target_team uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.team_members tm
     where tm.team_id = target_team
       and tm.user_id = auth.uid()
  );
$$;

create or replace function public.has_team_role(target_team uuid, roles team_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.team_members tm
     where tm.team_id = target_team
       and tm.user_id = auth.uid()
       and tm.role = any(roles)
  );
$$;

revoke execute on function public.is_team_member(uuid) from public;
revoke execute on function public.has_team_role(uuid, team_role[]) from public;
grant execute on function public.is_team_member(uuid) to authenticated;
grant execute on function public.has_team_role(uuid, team_role[]) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.profiles      enable row level security;
alter table public.teams         enable row level security;
alter table public.team_members  enable row level security;

-- profiles: eigenes Profil voll, Profile von Teamkollegen lesbar.
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
        from public.team_members mine
        join public.team_members theirs on theirs.team_id = mine.team_id
       where mine.user_id = auth.uid()
         and theirs.user_id = profiles.id
    )
  );

create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_delete_own on public.profiles
  for delete to authenticated
  using (id = auth.uid());

-- teams
create policy teams_select_member on public.teams
  for select to authenticated
  using (deleted_at is null and public.is_team_member(id));

create policy teams_insert_own on public.teams
  for insert to authenticated
  with check (owner_id = auth.uid());

create policy teams_update_admin on public.teams
  for update to authenticated
  using (public.has_team_role(id, array['owner', 'admin']::team_role[]))
  with check (public.has_team_role(id, array['owner', 'admin']::team_role[]));

create policy teams_delete_owner on public.teams
  for delete to authenticated
  using (owner_id = auth.uid());

-- team_members
create policy team_members_select on public.team_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_team_member(team_id));

create policy team_members_insert_admin on public.team_members
  for insert to authenticated
  with check (
    public.has_team_role(team_id, array['owner', 'admin']::team_role[])
    or exists (select 1 from public.teams t where t.id = team_id and t.owner_id = auth.uid())
  );

create policy team_members_update_admin on public.team_members
  for update to authenticated
  using (public.has_team_role(team_id, array['owner', 'admin']::team_role[]))
  with check (public.has_team_role(team_id, array['owner', 'admin']::team_role[]));

create policy team_members_delete on public.team_members
  for delete to authenticated
  using (
    user_id = auth.uid()
    or public.has_team_role(team_id, array['owner', 'admin']::team_role[])
  );
