-- Lernkueche :: 007 Explizite Rechtevergabe
-- Supabase vergibt Default Privileges automatisch. Wir verlassen uns nicht
-- darauf: bei einer Migration auf eigene Postgres-Infrastruktur (ADR-3)
-- waere das Schema sonst ohne Rechte und die App stumm.
-- RLS bleibt die eigentliche Zugriffskontrolle, GRANT ist nur die Vorstufe.

grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;

-- Kuratierte Referenzdaten sind fuer Angemeldete strikt lesbar.
revoke insert, update, delete on
  public.allergens,
  public.tags,
  public.sources,
  public.techniques,
  public.technique_aliases,
  public.technique_faults,
  public.skill_nodes,
  public.ingredients,
  public.ingredient_aliases,
  public.ingredient_yields,
  public.ingredient_allergens
from authenticated;

-- Kontingente zaehlt ausschliesslich der Server hoch.
revoke insert, update, delete on public.usage_quota from authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant all on tables to service_role;
