-- Lernkueche :: 005 Lernmodul
-- Grundprinzip: kein separater Lernbereich mit eigenem Content-Zyklus.
-- Das Lernmaterial entsteht aus Rezeptdaten, die ohnehin vorhanden sind.

-- ---------------------------------------------------------------------------
-- Fachbegriffe
-- ---------------------------------------------------------------------------

create table public.techniques (
  id                       uuid primary key default gen_random_uuid(),
  slug                     text not null unique,
  label_de                 text not null,
  label_fr                 text,
  pronunciation_hint       text,
  pronunciation_audio_path text,
  short_definition         text not null,
  long_explanation         text,
  category                 text not null check (category in
                             ('schnittart','garmethode','grundsauce','vorbereitung',
                              'patisserie','warenkunde','hygiene','organisation')),
  exam_relevant            boolean not null default false,
  difficulty               int check (difficulty between 1 and 5),
  image_path               text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create trigger techniques_set_updated_at
  before update on public.techniques
  for each row execute function public.set_updated_at();

-- Beugungsformen und Synonyme: blanchiert / blanchieren / blanchierte
create table public.technique_aliases (
  id            uuid primary key default gen_random_uuid(),
  technique_id  uuid not null references public.techniques (id) on delete cascade,
  alias         text not null,
  normalized    text generated always as (public.normalize_text(alias)) stored,
  unique (technique_id, alias)
);

create index technique_aliases_normalized_idx on public.technique_aliases (normalized);

-- Fehlerbild-Diagnose: was ein Azubi um 18:40 Uhr in der Kueche wirklich braucht.
create table public.technique_faults (
  id            uuid primary key default gen_random_uuid(),
  technique_id  uuid not null references public.techniques (id) on delete cascade,
  symptom       text not null,
  cause         text not null,
  rescue        text,
  prevention    text not null,
  sort_order    int not null default 0
);

create index technique_faults_technique_idx on public.technique_faults (technique_id);

create table public.recipe_techniques (
  recipe_id     uuid not null references public.recipes (id) on delete cascade,
  technique_id  uuid not null references public.techniques (id) on delete cascade,
  step_id       uuid references public.recipe_steps (id) on delete cascade,
  primary key (recipe_id, technique_id, step_id)
);

create index recipe_techniques_technique_idx on public.recipe_techniques (technique_id);

-- ---------------------------------------------------------------------------
-- Spaced Repetition (FSRS)
-- ---------------------------------------------------------------------------

create table public.srs_cards (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  technique_id    uuid references public.techniques (id) on delete cascade,
  fault_id        uuid references public.technique_faults (id) on delete cascade,
  card_type       text not null check (card_type in
                    ('definition','anwendung','fr_de','de_fr','fehlerbild')),

  state           srs_state not null default 'new',
  stability       double precision,
  difficulty      double precision,
  due_at          timestamptz not null default now(),
  last_review_at  timestamptz,
  reps            int not null default 0,
  lapses          int not null default 0,
  elapsed_days    double precision not null default 0,
  scheduled_days  double precision not null default 0,

  suspended       boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint srs_cards_subject check (
    (technique_id is not null and fault_id is null)
    or (technique_id is null and fault_id is not null)
  )
);

create unique index srs_cards_unique_technique
  on public.srs_cards (user_id, technique_id, card_type)
  where technique_id is not null;
create unique index srs_cards_unique_fault
  on public.srs_cards (user_id, fault_id, card_type)
  where fault_id is not null;
create index srs_cards_due_idx on public.srs_cards (user_id, due_at) where suspended = false;

create trigger srs_cards_set_updated_at
  before update on public.srs_cards
  for each row execute function public.set_updated_at();

create table public.srs_reviews (
  id                 uuid primary key default gen_random_uuid(),
  card_id            uuid not null references public.srs_cards (id) on delete cascade,
  user_id            uuid not null references public.profiles (id) on delete cascade,
  -- FSRS Bewertung: 1 again, 2 hard, 3 good, 4 easy
  rating             int not null check (rating between 1 and 4),
  state_before       srs_state not null,
  stability_before   double precision,
  difficulty_before  double precision,
  elapsed_days       double precision not null default 0,
  duration_ms        int,
  reviewed_at        timestamptz not null default now()
);

create index srs_reviews_card_idx on public.srs_reviews (card_id, reviewed_at);
create index srs_reviews_user_idx on public.srs_reviews (user_id, reviewed_at);

-- ---------------------------------------------------------------------------
-- Fachrechnen
-- Aufgaben sind deterministisch aus (recipe_id, kind, seed) reproduzierbar.
-- Die Loesung wird serverseitig geprueft, der Loesungsweg immer schrittweise gezeigt.
-- ---------------------------------------------------------------------------

create table public.calc_exercises (
  id          uuid primary key default gen_random_uuid(),
  recipe_id   uuid references public.recipes (id) on delete cascade,
  kind        text not null check (kind in
                ('portion','ruestverlust','garverlust','wareneinsatz',
                 'kalkulation','zeitplan','einheiten')),
  seed        bigint not null,
  given       jsonb not null,
  solution    jsonb not null,
  difficulty  int not null default 2 check (difficulty between 1 and 5),
  created_at  timestamptz not null default now(),
  unique (recipe_id, kind, seed)
);

create index calc_exercises_kind_idx on public.calc_exercises (kind, difficulty);

create table public.calc_attempts (
  id            uuid primary key default gen_random_uuid(),
  exercise_id   uuid not null references public.calc_exercises (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  answer        jsonb not null,
  is_correct    boolean not null,
  duration_ms   int,
  attempted_at  timestamptz not null default now()
);

create index calc_attempts_user_idx on public.calc_attempts (user_id, attempted_at);

-- ---------------------------------------------------------------------------
-- Kochprotokoll und Berichtsheft
-- ---------------------------------------------------------------------------

create table public.cook_logs (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references public.profiles (id) on delete cascade,
  recipe_id            uuid references public.recipes (id) on delete set null,
  recipe_title_cache   text not null default '',
  cooked_at            timestamptz not null default now(),
  duration_minutes     int check (duration_minutes >= 0),
  servings             int,
  note                 text,
  self_rating          int check (self_rating between 1 and 5),
  photo_paths          jsonb not null default '[]'::jsonb,
  -- HACCP-Uebung: Kerntemperaturen mit Zeitstempel.
  -- Lern- und Uebungswerkzeug, ausdruecklich keine amtstaugliche Dokumentation.
  temperature_readings jsonb not null default '[]'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index cook_logs_user_idx on public.cook_logs (user_id, cooked_at desc);

create trigger cook_logs_set_updated_at
  before update on public.cook_logs
  for each row execute function public.set_updated_at();

create table public.report_entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  week_start    date not null,
  body          text not null default '',
  -- Von der App vorgeschlagener Entwurf, vom Nutzer bearbeitbar.
  is_draft      boolean not null default true,
  source_logs   jsonb not null default '[]'::jsonb,
  exported_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, week_start)
);

comment on table public.report_entries is
  'Entwurf fuer den Ausbildungsnachweis. Ersetzt KEIN Kammerportal und keine '
  'Unterschrift des Ausbilders. Die App exportiert nur, sie beglaubigt nicht.';

create trigger report_entries_set_updated_at
  before update on public.report_entries
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Skill-Tree: Daten werden ab v1 gesammelt, visualisiert wird in v2
-- ---------------------------------------------------------------------------

create table public.skill_nodes (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,
  label_de      text not null,
  parent_id     uuid references public.skill_nodes (id) on delete set null,
  technique_id  uuid references public.techniques (id) on delete set null,
  tier          int not null default 1,
  sort_order    int not null default 0
);

create table public.user_skill_progress (
  user_id        uuid not null references public.profiles (id) on delete cascade,
  skill_node_id  uuid not null references public.skill_nodes (id) on delete cascade,
  cook_count     int not null default 0,
  documented     boolean not null default false,
  first_done_at  timestamptz,
  last_done_at   timestamptz,
  primary key (user_id, skill_node_id)
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.techniques          enable row level security;
alter table public.technique_aliases   enable row level security;
alter table public.technique_faults    enable row level security;
alter table public.recipe_techniques   enable row level security;
alter table public.srs_cards           enable row level security;
alter table public.srs_reviews         enable row level security;
alter table public.calc_exercises      enable row level security;
alter table public.calc_attempts       enable row level security;
alter table public.cook_logs           enable row level security;
alter table public.report_entries      enable row level security;
alter table public.skill_nodes         enable row level security;
alter table public.user_skill_progress enable row level security;

-- Kuratierte Referenzdaten
create policy techniques_read        on public.techniques        for select to authenticated using (true);
create policy technique_aliases_read on public.technique_aliases for select to authenticated using (true);
create policy technique_faults_read  on public.technique_faults  for select to authenticated using (true);
create policy skill_nodes_read       on public.skill_nodes       for select to authenticated using (true);

create policy recipe_techniques_select on public.recipe_techniques
  for select to authenticated using (public.can_read_recipe(recipe_id));
create policy recipe_techniques_insert on public.recipe_techniques
  for insert to authenticated with check (public.can_write_recipe(recipe_id));
create policy recipe_techniques_delete on public.recipe_techniques
  for delete to authenticated using (public.can_write_recipe(recipe_id));

-- Lernfortschritt ist streng privat. Auch ein Ausbilder sieht ihn nicht;
-- geteilt wird ausschliesslich, was der Azubi aktiv einreicht.
create policy srs_cards_all on public.srs_cards
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy srs_reviews_all on public.srs_reviews
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy calc_exercises_select on public.calc_exercises
  for select to authenticated
  using (recipe_id is null or public.can_read_recipe(recipe_id));
create policy calc_exercises_insert on public.calc_exercises
  for insert to authenticated
  with check (recipe_id is null or public.can_read_recipe(recipe_id));

create policy calc_attempts_all on public.calc_attempts
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy cook_logs_all on public.cook_logs
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy report_entries_all on public.report_entries
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy user_skill_progress_all on public.user_skill_progress
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
