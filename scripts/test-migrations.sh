#!/bin/sh
# Faehrt einen wegwerfbaren Postgres-Cluster hoch, laedt die Stubs und spielt
# alle Migrationen der Reihe nach ein. Bricht beim ersten Fehler ab.
# Idempotent: raeumt einen vorhandenen Cluster vorher weg.
#
# Einschraenkung, bewusst und sichtbar:
#   pgvector ist auf diesem Rechner nicht installiert. Der Harness ersetzt
#   deshalb in einer KOPIE der Migration zwei Zeilen:
#     - create extension "vector"   -> uebersprungen
#     - vector(1536)                -> text
#     - using hnsw (...)            -> uebersprungen
#   Diese beiden Konstrukte sind damit NICHT lokal verifiziert und muessen
#   beim ersten Deploy gegen Supabase geprueft werden.

set -e

PGBIN="/opt/homebrew/opt/postgresql@17/bin"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CLUSTER="${TMPDIR:-/tmp}/lernkueche-pgtest"
PORT=54329
export PGHOST="$CLUSTER/sock"
export PGPORT="$PORT"

cleanup() {
  if [ -d "$CLUSTER" ]; then
    "$PGBIN/pg_ctl" -D "$CLUSTER/data" -m immediate stop >/dev/null 2>&1 || true
    rm -rf "$CLUSTER"
  fi
}
trap cleanup EXIT

cleanup
mkdir -p "$CLUSTER/data" "$CLUSTER/sock"

echo "==> Cluster anlegen"
"$PGBIN/initdb" -D "$CLUSTER/data" -U postgres --encoding=UTF8 --locale=C >/dev/null

echo "==> Server starten auf Port $PORT"
"$PGBIN/pg_ctl" -D "$CLUSTER/data" -o "-k $CLUSTER/sock -p $PORT -c listen_addresses=" -w start >/dev/null

"$PGBIN/psql" -U postgres -d postgres -q -c "create database lernkueche;" >/dev/null

PSQL="$PGBIN/psql -U postgres -d lernkueche -v ON_ERROR_STOP=1 -q"

echo "==> Stubs laden"
$PSQL -f "$ROOT/supabase/tests/00_stubs.sql"

WORK="$CLUSTER/migrations"
mkdir -p "$WORK"

echo "==> Migrationen einspielen"
for f in "$ROOT"/supabase/migrations/*.sql; do
  base=$(basename "$f")
  sed -e '/create extension if not exists "vector"/d' \
      -e 's/vector(1536)/text/' \
      -e '/using hnsw (embedding vector_cosine_ops)/d' \
      -e '/^create index recipes_embedding_idx/d' \
      "$f" > "$WORK/$base"
  printf '    %s ... ' "$base"
  $PSQL -f "$WORK/$base"
  printf 'ok\n'
done

echo "==> Seeds einspielen"
for f in "$ROOT"/supabase/seed/*.sql; do
  printf '    %s ... ' "$(basename "$f")"
  $PSQL -f "$f"
  printf 'ok\n'
done

echo "==> Pruefungen"
$PSQL -f "$ROOT/supabase/tests/10_schema_checks.sql"

echo "==> RLS-Tests"
$PSQL -f "$ROOT/supabase/tests/20_rls.sql"

echo ""
echo "Alle Migrationen, Seeds und Tests sind durchgelaufen."
echo "HINWEIS: vector-Spalte und HNSW-Index wurden lokal NICHT geprueft (pgvector fehlt)."
