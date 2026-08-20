-- Lernkueche :: 003 Rezepte

-- ---------------------------------------------------------------------------
-- sources: Herkunft externer Rezepte, inklusive Lizenz- und Attributionstext
-- ---------------------------------------------------------------------------

create table public.sources (
  id             uuid primary key default gen_random_uuid(),
  slug           text not null unique,
  name           text not null,
  homepage_url   text,
  license_note   text not null,
  attribution    text not null,
  allows_body    boolean not null default false,
  created_at     timestamptz not null default now()
);

comment on column public.sources.allows_body is
  'Ob der Zubereitungstext dieser Quelle gespeichert und angezeigt werden darf. '
  'Bei nutzerinitiiertem URL-Import ist das immer eine private Kopie, siehe ADR-6.';

-- ---------------------------------------------------------------------------
-- Taxonomie
-- ---------------------------------------------------------------------------

create table public.tags (
  id           uuid primary key default gen_random_uuid(),
  axis         text not null check (axis in
                 ('course','main_ingredient','cuisine','diet','method','occasion','season')),
  slug         text not null,
  label_de     text not null,
  label_en     text,
  sort_order   int not null default 0,
  taxonomy_version int not null default 1,
  unique (axis, slug)
);

-- ---------------------------------------------------------------------------
-- recipes
-- ---------------------------------------------------------------------------

create table public.recipes (
  id                    uuid primary key default gen_random_uuid(),
  owner_id              uuid not null references public.profiles (id) on delete cascade,
  team_id               uuid references public.teams (id) on delete set null,
  visibility            recipe_visibility not null default 'private',
  source_type           recipe_source_type not null default 'manual',
  source_id             uuid references public.sources (id) on delete set null,
  source_url            text,

  title                 text not null check (length(trim(title)) between 1 and 200),
  subtitle              text,
  description           text,
  servings_base         int not null default 4 check (servings_base between 1 and 500),
  servings_unit         text not null default 'Portionen',

  prep_minutes          int check (prep_minutes >= 0),
  cook_minutes          int check (cook_minutes >= 0),
  rest_minutes          int check (rest_minutes >= 0),
  total_minutes         int generated always as
                          (coalesce(prep_minutes,0) + coalesce(cook_minutes,0) + coalesce(rest_minutes,0)) stored,

  -- Drei getrennte Quellen, niemals vermischt (siehe ARCHITECTURE.md)
  difficulty_heuristic  int check (difficulty_heuristic between 1 and 5),
  difficulty_author     int check (difficulty_author between 1 and 5),
  difficulty_community  numeric(3,2) check (difficulty_community between 1 and 5),
  difficulty_votes      int not null default 0,

  hero_image_path       text,
  -- Originalscan bleibt immer erhalten: Fallback-Wahrheit und emotionaler Wert.
  original_scan_paths   jsonb not null default '[]'::jsonb,

  -- Volltextsuche. search_text wird per Trigger denormalisiert befuellt,
  -- weil eine generated column nur eigene Spalten sehen darf.
  search_text           text,
  search_vector         tsvector generated always as
                          (to_tsvector('german'::regconfig, coalesce(search_text, ''))) stored,

  embedding             vector(1536),
  embedding_model       text,
  embedded_at           timestamptz,

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz,

  -- Sichtbarkeit 'team' braucht ein Team, alles andere darf keines haben.
  constraint recipes_team_scope check (
    (visibility = 'team' and team_id is not null)
    or (visibility <> 'team' and team_id is null)
  ),
  -- Nutzerimport ist immer eine private Kopie. DB-seitig erzwungen, nicht nur im UI.
  constraint recipes_import_private check (
    source_type <> 'url_import' or visibility = 'private'
  ),
  -- v1 kennt keine oeffentlichen Rezepte. Der Enum-Wert bleibt fuer v2 bestehen,
  -- der Constraint faellt dann weg. Bis dahin: keine Moderationspflicht,
  -- keine Meldefunktion, kein Jugendschutzthema.
  constraint recipes_no_public_v1 check (visibility <> 'public')
);

create index recipes_owner_idx    on public.recipes (owner_id) where deleted_at is null;
create index recipes_team_idx     on public.recipes (team_id)  where deleted_at is null;
create index recipes_search_idx   on public.recipes using gin (search_vector);
create index recipes_embedding_idx on public.recipes using hnsw (embedding vector_cosine_ops);
create index recipes_updated_idx  on public.recipes (updated_at);

create trigger recipes_set_updated_at
  before update on public.recipes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- recipe_ingredients
-- ---------------------------------------------------------------------------

create table public.recipe_ingredients (
  id               uuid primary key default gen_random_uuid(),
  recipe_id        uuid not null references public.recipes (id) on delete cascade,
  ingredient_id    uuid references public.ingredients (id) on delete set null,

  group_label      text,
  -- Originaltext aus Scan oder Eingabe. Wird IMMER angezeigt, nie ueberschrieben.
  raw_text         text not null,

  quantity_min     numeric(10,3),
  quantity_max     numeric(10,3),
  unit             text,
  -- geh. / gestr. / n. B. / etwas / nach Geschmack
  qualifier        text,
  note             text,
  optional         boolean not null default false,

  -- 0..1, aus dem deterministischen Parser. < 0.7 wird im Review markiert.
  parse_confidence numeric(3,2) check (parse_confidence between 0 and 1),
  sort_order       int not null default 0,

  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  constraint recipe_ingredients_range check (
    quantity_max is null or quantity_min is null or quantity_max >= quantity_min
  )
);

create index recipe_ingredients_recipe_idx     on public.recipe_ingredients (recipe_id, sort_order);
create index recipe_ingredients_ingredient_idx on public.recipe_ingredients (ingredient_id);

create trigger recipe_ingredients_set_updated_at
  before update on public.recipe_ingredients
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- recipe_steps
-- ---------------------------------------------------------------------------

create table public.recipe_steps (
  id                uuid primary key default gen_random_uuid(),
  recipe_id         uuid not null references public.recipes (id) on delete cascade,
  step_number       int not null check (step_number > 0),
  body              text not null,
  -- Aus dem Schritttext erkannte Dauer, Grundlage fuer Timer und Zeitplan-Trainer.
  duration_seconds  int check (duration_seconds >= 0),
  temperature_c     int check (temperature_c between -40 and 400),
  -- Ressource fuer den Menue-Zeitplan-Trainer: ofen | herd | kuehlung | arbeitsflaeche
  resource          text check (resource in ('ofen','herd','kuehlung','arbeitsflaeche','sonstige')),
  image_path        text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (recipe_id, step_number)
);

create index recipe_steps_recipe_idx on public.recipe_steps (recipe_id, step_number);

create trigger recipe_steps_set_updated_at
  before update on public.recipe_steps
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Verknuepfungen
-- ---------------------------------------------------------------------------

create table public.recipe_tags (
  recipe_id        uuid not null references public.recipes (id) on delete cascade,
  tag_id           uuid not null references public.tags (id) on delete cascade,
  -- 'auto' = LLM-Klassifikation, 'user' = manuell gesetzt
  origin           text not null default 'auto' check (origin in ('auto','user')),
  confidence       numeric(3,2),
  taxonomy_version int not null default 1,
  primary key (recipe_id, tag_id)
);

create index recipe_tags_tag_idx on public.recipe_tags (tag_id);

-- Freie Tags getrennt: in der Suche schwaecher gewichtet, driften nicht in die Taxonomie.
create table public.recipe_free_tags (
  recipe_id  uuid not null references public.recipes (id) on delete cascade,
  label      text not null,
  primary key (recipe_id, label)
);

create table public.recipe_allergens (
  recipe_id     uuid not null references public.recipes (id) on delete cascade,
  allergen_id   uuid not null references public.allergens (id) on delete cascade,
  certainty     text not null default 'contains' check (certainty in ('contains','may_contain')),
  derived_from  jsonb not null default '[]'::jsonb,
  primary key (recipe_id, allergen_id)
);

-- ---------------------------------------------------------------------------
-- Bewertungen: intern und extern strikt getrennt, nie ein gemeinsamer Schnitt
-- ---------------------------------------------------------------------------

create table public.recipe_ratings (
  id          uuid primary key default gen_random_uuid(),
  recipe_id   uuid not null references public.recipes (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  stars       int not null check (stars between 1 and 5),
  difficulty  int check (difficulty between 1 and 5),
  body        text check (length(body) <= 1000),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (recipe_id, user_id)
);

create index recipe_ratings_recipe_idx on public.recipe_ratings (recipe_id);

create trigger recipe_ratings_set_updated_at
  before update on public.recipe_ratings
  for each row execute function public.set_updated_at();

create table public.external_ratings (
  id          uuid primary key default gen_random_uuid(),
  recipe_id   uuid not null references public.recipes (id) on delete cascade,
  source_id   uuid not null references public.sources (id) on delete cascade,
  value       numeric(4,2) not null,
  scale       numeric(4,2) not null default 5,
  count       int,
  source_url  text,
  fetched_at  timestamptz not null default now(),
  unique (recipe_id, source_id)
);

-- ---------------------------------------------------------------------------
-- Sammlungen
-- ---------------------------------------------------------------------------

create table public.collections (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles (id) on delete cascade,
  team_id     uuid references public.teams (id) on delete set null,
  name        text not null check (length(trim(name)) between 1 and 120),
  icon        text,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create trigger collections_set_updated_at
  before update on public.collections
  for each row execute function public.set_updated_at();

create table public.collection_recipes (
  collection_id uuid not null references public.collections (id) on delete cascade,
  recipe_id     uuid not null references public.recipes (id) on delete cascade,
  sort_order    int not null default 0,
  added_at      timestamptz not null default now(),
  primary key (collection_id, recipe_id)
);

-- ---------------------------------------------------------------------------
-- search_text denormalisieren
-- ---------------------------------------------------------------------------

create or replace function public.refresh_recipe_search_text(target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.recipes r
     set search_text = concat_ws(' ',
           r.title,
           coalesce(r.subtitle, ''),
           coalesce(r.description, ''),
           (select string_agg(coalesce(i.canonical_name, ri.raw_text), ' ')
              from public.recipe_ingredients ri
              left join public.ingredients i on i.id = ri.ingredient_id
             where ri.recipe_id = r.id),
           (select string_agg(s.body, ' ')
              from public.recipe_steps s
             where s.recipe_id = r.id)
         )
   where r.id = target;
end;
$$;

create or replace function public.trg_refresh_recipe_search()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  target := coalesce(new.recipe_id, old.recipe_id);
  perform public.refresh_recipe_search_text(target);
  return coalesce(new, old);
end;
$$;

create or replace function public.trg_refresh_recipe_search_self()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Nur wenn sich relevante Felder geaendert haben, sonst Endlosschleife.
  if tg_op = 'INSERT'
     or new.title is distinct from old.title
     or new.subtitle is distinct from old.subtitle
     or new.description is distinct from old.description then
    perform public.refresh_recipe_search_text(new.id);
  end if;
  return new;
end;
$$;

create trigger recipes_refresh_search
  after insert or update on public.recipes
  for each row execute function public.trg_refresh_recipe_search_self();

create trigger recipe_ingredients_refresh_search
  after insert or update or delete on public.recipe_ingredients
  for each row execute function public.trg_refresh_recipe_search();

create trigger recipe_steps_refresh_search
  after insert or update or delete on public.recipe_steps
  for each row execute function public.trg_refresh_recipe_search();
