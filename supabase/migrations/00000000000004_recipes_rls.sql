-- Lernkueche :: 004 RLS fuer die Rezept-Domaene
-- Grundsatz: die App darf sich NIE darauf verlassen, nur das Richtige abzufragen.
-- Jede Tabelle mit Nutzerdaten hat RLS. Keine Ausnahme.

create or replace function public.can_read_recipe(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.recipes r
     where r.id = target
       and r.deleted_at is null
       and (
         r.owner_id = auth.uid()
         or (r.visibility = 'team' and r.team_id is not null and public.is_team_member(r.team_id))
       )
  );
$$;

create or replace function public.can_write_recipe(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.recipes r
     where r.id = target
       and r.deleted_at is null
       and (
         r.owner_id = auth.uid()
         or (r.visibility = 'team'
             and r.team_id is not null
             and public.has_team_role(r.team_id, array['owner','admin','ausbilder']::team_role[]))
       )
  );
$$;

revoke execute on function public.can_read_recipe(uuid)  from public;
revoke execute on function public.can_write_recipe(uuid) from public;
grant  execute on function public.can_read_recipe(uuid)  to authenticated;
grant  execute on function public.can_write_recipe(uuid) to authenticated;

alter table public.sources             enable row level security;
alter table public.tags                enable row level security;
alter table public.recipes             enable row level security;
alter table public.recipe_ingredients  enable row level security;
alter table public.recipe_steps        enable row level security;
alter table public.recipe_tags         enable row level security;
alter table public.recipe_free_tags    enable row level security;
alter table public.recipe_allergens    enable row level security;
alter table public.recipe_ratings      enable row level security;
alter table public.external_ratings    enable row level security;
alter table public.collections         enable row level security;
alter table public.collection_recipes  enable row level security;

-- Referenzdaten
create policy sources_read on public.sources for select to authenticated using (true);
create policy tags_read    on public.tags    for select to authenticated using (true);

-- recipes
create policy recipes_select on public.recipes
  for select to authenticated
  using (
    deleted_at is null
    and (
      owner_id = auth.uid()
      or (visibility = 'team' and team_id is not null and public.is_team_member(team_id))
    )
  );

create policy recipes_insert on public.recipes
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and (team_id is null or public.is_team_member(team_id))
  );

create policy recipes_update on public.recipes
  for update to authenticated
  using (
    owner_id = auth.uid()
    or (visibility = 'team' and team_id is not null
        and public.has_team_role(team_id, array['owner','admin','ausbilder']::team_role[]))
  )
  with check (
    owner_id = auth.uid()
    or (team_id is not null and public.is_team_member(team_id))
  );

-- Hartes Loeschen bleibt dem Eigentuemer vorbehalten. Der App-Pfad setzt
-- deleted_at, nicht delete: Familienrezepte werden aus Versehen geloescht.
create policy recipes_delete on public.recipes
  for delete to authenticated
  using (owner_id = auth.uid());

-- Kindtabellen haengen an can_read_recipe / can_write_recipe
create policy recipe_ingredients_select on public.recipe_ingredients
  for select to authenticated using (public.can_read_recipe(recipe_id));
create policy recipe_ingredients_insert on public.recipe_ingredients
  for insert to authenticated with check (public.can_write_recipe(recipe_id));
create policy recipe_ingredients_update on public.recipe_ingredients
  for update to authenticated using (public.can_write_recipe(recipe_id))
                             with check (public.can_write_recipe(recipe_id));
create policy recipe_ingredients_delete on public.recipe_ingredients
  for delete to authenticated using (public.can_write_recipe(recipe_id));

create policy recipe_steps_select on public.recipe_steps
  for select to authenticated using (public.can_read_recipe(recipe_id));
create policy recipe_steps_insert on public.recipe_steps
  for insert to authenticated with check (public.can_write_recipe(recipe_id));
create policy recipe_steps_update on public.recipe_steps
  for update to authenticated using (public.can_write_recipe(recipe_id))
                             with check (public.can_write_recipe(recipe_id));
create policy recipe_steps_delete on public.recipe_steps
  for delete to authenticated using (public.can_write_recipe(recipe_id));

create policy recipe_tags_select on public.recipe_tags
  for select to authenticated using (public.can_read_recipe(recipe_id));
create policy recipe_tags_insert on public.recipe_tags
  for insert to authenticated with check (public.can_write_recipe(recipe_id));
create policy recipe_tags_delete on public.recipe_tags
  for delete to authenticated using (public.can_write_recipe(recipe_id));

create policy recipe_free_tags_select on public.recipe_free_tags
  for select to authenticated using (public.can_read_recipe(recipe_id));
create policy recipe_free_tags_insert on public.recipe_free_tags
  for insert to authenticated with check (public.can_write_recipe(recipe_id));
create policy recipe_free_tags_delete on public.recipe_free_tags
  for delete to authenticated using (public.can_write_recipe(recipe_id));

create policy recipe_allergens_select on public.recipe_allergens
  for select to authenticated using (public.can_read_recipe(recipe_id));
create policy recipe_allergens_insert on public.recipe_allergens
  for insert to authenticated with check (public.can_write_recipe(recipe_id));
create policy recipe_allergens_delete on public.recipe_allergens
  for delete to authenticated using (public.can_write_recipe(recipe_id));

-- Bewertungen: lesen wer das Rezept sieht, schreiben nur die eigene.
create policy recipe_ratings_select on public.recipe_ratings
  for select to authenticated using (public.can_read_recipe(recipe_id));
create policy recipe_ratings_insert on public.recipe_ratings
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_read_recipe(recipe_id));
create policy recipe_ratings_update on public.recipe_ratings
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy recipe_ratings_delete on public.recipe_ratings
  for delete to authenticated using (user_id = auth.uid());

create policy external_ratings_select on public.external_ratings
  for select to authenticated using (public.can_read_recipe(recipe_id));

-- collections
create policy collections_select on public.collections
  for select to authenticated
  using (deleted_at is null and (owner_id = auth.uid()
         or (team_id is not null and public.is_team_member(team_id))));
create policy collections_insert on public.collections
  for insert to authenticated with check (owner_id = auth.uid());
create policy collections_update on public.collections
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy collections_delete on public.collections
  for delete to authenticated using (owner_id = auth.uid());

create policy collection_recipes_select on public.collection_recipes
  for select to authenticated
  using (exists (select 1 from public.collections c
                  where c.id = collection_id
                    and (c.owner_id = auth.uid()
                         or (c.team_id is not null and public.is_team_member(c.team_id)))));
create policy collection_recipes_insert on public.collection_recipes
  for insert to authenticated
  with check (exists (select 1 from public.collections c
                       where c.id = collection_id and c.owner_id = auth.uid())
              and public.can_read_recipe(recipe_id));
create policy collection_recipes_delete on public.collection_recipes
  for delete to authenticated
  using (exists (select 1 from public.collections c
                  where c.id = collection_id and c.owner_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- Teamaufloesung
-- recipes.team_id steht auf "on delete set null". Zusammen mit dem Constraint
-- recipes_team_scope (visibility='team' erzwingt team_id) wuerde das Loeschen
-- eines Teams jedes Team-Rezept in einen unerlaubten Zustand ziehen und die
-- Loeschung mit einem Check-Verstoss abbrechen.
-- Loesung: Rezepte fallen auf privat beim bisherigen Eigentuemer zurueck.
-- Nichts geht verloren, eine Betriebsrezeptur ist Arbeit von Wochen.
-- ---------------------------------------------------------------------------

create or replace function public.trg_team_deleted_detach_recipes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.recipes
     set visibility = 'private',
         team_id    = null
   where team_id = old.id;

  update public.collections
     set team_id = null
   where team_id = old.id;

  return old;
end;
$$;

create trigger teams_before_delete_detach
  before delete on public.teams
  for each row execute function public.trg_team_deleted_detach_recipes();
