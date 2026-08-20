-- Lernkueche :: 002 Kanonische Zutaten
-- Warum eine eigene Entitaet und nicht Freitext (siehe DECISIONS.md ADR-4):
--   1. Deutscher FTS zerlegt keine Komposita. "Hackfleisch" findet "Fleisch" nicht.
--   2. Allergene lassen sich nur ueber die kanonische Zutat zuverlaessig ableiten.
--   3. Der Fachrechnen-Generator braucht Ruest- und Garverluste pro Zutat.
--   4. Wareneinsatzkalkulation braucht EK-Preise pro Zutat.
-- recipe_ingredients.raw_text bleibt immer erhalten und wird angezeigt.
-- ingredient_id ist nullable: unaufgeloeste Zutaten degradieren, sie blockieren nicht.

-- ---------------------------------------------------------------------------
-- Allergene nach LMIV Anhang II (14 Hauptallergene)
-- ---------------------------------------------------------------------------

create table public.allergens (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  label_de    text not null,
  label_en    text not null,
  sort_order  int  not null default 0
);

comment on table public.allergens is
  'LMIV Anhang II. Die Zuordnung in der App ist eine automatische Ableitung '
  'und ausdruecklich KEINE rechtsverbindliche Kennzeichnung.';

-- ---------------------------------------------------------------------------
-- ingredients
-- ---------------------------------------------------------------------------

create table public.ingredients (
  id               uuid primary key default gen_random_uuid(),
  canonical_name   text not null unique,
  category         text not null,
  default_unit     text not null default 'g',
  -- Dichte fuer die Umrechnung Volumen <-> Gewicht.
  -- 1 EL Mehl sind nicht 1 EL Oel, das muss der Skalierer wissen.
  density_g_per_ml numeric(6,3),
  -- Durchschnittliches Stueckgewicht, fuer "3 Zwiebeln" -> Gramm.
  piece_weight_g   numeric(8,2),
  is_curated       boolean not null default true,
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index ingredients_name_trgm on public.ingredients using gin (canonical_name gin_trgm_ops);
create index ingredients_category_idx on public.ingredients (category);

create trigger ingredients_set_updated_at
  before update on public.ingredients
  for each row execute function public.set_updated_at();

-- Synonyme, Regionalismen, Beugungsformen: Sahne / Rahm / Schlagobers / Schlagsahne
create table public.ingredient_aliases (
  id             uuid primary key default gen_random_uuid(),
  ingredient_id  uuid not null references public.ingredients (id) on delete cascade,
  alias          text not null,
  normalized     text generated always as (public.normalize_text(alias)) stored,
  created_at     timestamptz not null default now(),
  unique (ingredient_id, alias)
);

create index ingredient_aliases_normalized_idx on public.ingredient_aliases (normalized);
create index ingredient_aliases_trgm on public.ingredient_aliases using gin (alias gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- Verluste: die Datengrundlage des Fachrechnen-Generators
-- ---------------------------------------------------------------------------

create table public.ingredient_yields (
  id             uuid primary key default gen_random_uuid(),
  ingredient_id  uuid not null references public.ingredients (id) on delete cascade,
  process        text not null check (process in ('ruesten', 'garen', 'auftauen', 'entbeinen')),
  loss_percent   numeric(5,2) not null check (loss_percent >= 0 and loss_percent < 100),
  method         text,
  source_note    text,
  created_at     timestamptz not null default now(),
  unique (ingredient_id, process, method)
);

comment on column public.ingredient_yields.loss_percent is
  'Prozentualer Masseverlust. Brutto = Netto / (1 - loss/100).';

-- ---------------------------------------------------------------------------
-- Preise: owner_id null = kuratierter Richtwert, gesetzt = eigener EK
-- ---------------------------------------------------------------------------

create table public.ingredient_prices (
  id               uuid primary key default gen_random_uuid(),
  ingredient_id    uuid not null references public.ingredients (id) on delete cascade,
  owner_id         uuid references public.profiles (id) on delete cascade,
  team_id          uuid references public.teams (id) on delete cascade,
  price_cents      int not null check (price_cents >= 0),
  per_amount       numeric(10,3) not null check (per_amount > 0),
  per_unit         text not null,
  valid_from       date not null default current_date,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  -- Ein Preis gehoert entweder allen (kuratiert), einem Nutzer oder einem Team.
  constraint ingredient_prices_scope check (
    (owner_id is null and team_id is null)
    or (owner_id is not null and team_id is null)
    or (owner_id is null and team_id is not null)
  )
);

create index ingredient_prices_lookup on public.ingredient_prices (ingredient_id, owner_id, team_id);

create trigger ingredient_prices_set_updated_at
  before update on public.ingredient_prices
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Zutat -> Allergen
-- ---------------------------------------------------------------------------

create table public.ingredient_allergens (
  ingredient_id  uuid not null references public.ingredients (id) on delete cascade,
  allergen_id    uuid not null references public.allergens (id) on delete cascade,
  -- 'contains' = sicher enthalten, 'may_contain' = haeufige Spur / Herstellerabhaengig
  certainty      text not null default 'contains' check (certainty in ('contains', 'may_contain')),
  primary key (ingredient_id, allergen_id)
);

-- ---------------------------------------------------------------------------
-- RLS
-- Referenzdaten: alle Angemeldeten lesen, nur service_role schreibt.
-- Ausnahme ingredient_prices: eigene und Team-Preise darf der Nutzer pflegen.
-- ---------------------------------------------------------------------------

alter table public.allergens            enable row level security;
alter table public.ingredients          enable row level security;
alter table public.ingredient_aliases   enable row level security;
alter table public.ingredient_yields    enable row level security;
alter table public.ingredient_allergens enable row level security;
alter table public.ingredient_prices    enable row level security;

create policy allergens_read on public.allergens
  for select to authenticated using (true);

create policy ingredients_read on public.ingredients
  for select to authenticated using (true);

create policy ingredient_aliases_read on public.ingredient_aliases
  for select to authenticated using (true);

create policy ingredient_yields_read on public.ingredient_yields
  for select to authenticated using (true);

create policy ingredient_allergens_read on public.ingredient_allergens
  for select to authenticated using (true);

-- Preise: kuratierte lesen alle, eigene und Team-Preise nur die Berechtigten.
create policy ingredient_prices_read on public.ingredient_prices
  for select to authenticated
  using (
    (owner_id is null and team_id is null)
    or owner_id = auth.uid()
    or (team_id is not null and public.is_team_member(team_id))
  );

create policy ingredient_prices_write_own on public.ingredient_prices
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    or (team_id is not null and public.has_team_role(team_id, array['owner','admin','ausbilder']::team_role[]))
  );

create policy ingredient_prices_update_own on public.ingredient_prices
  for update to authenticated
  using (
    owner_id = auth.uid()
    or (team_id is not null and public.has_team_role(team_id, array['owner','admin','ausbilder']::team_role[]))
  )
  with check (
    owner_id = auth.uid()
    or (team_id is not null and public.has_team_role(team_id, array['owner','admin','ausbilder']::team_role[]))
  );

create policy ingredient_prices_delete_own on public.ingredient_prices
  for delete to authenticated
  using (
    owner_id = auth.uid()
    or (team_id is not null and public.has_team_role(team_id, array['owner','admin']::team_role[]))
  );
