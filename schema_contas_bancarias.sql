-- Rode este script no Supabase (SQL Editor > New query > Run).
-- Adiciona as tabelas de Contas Bancárias, sem afetar despesas/recebimentos já existentes.

create table if not exists contas_bancarias (
  id uuid primary key default gen_random_uuid(),
  empresa text not null,
  banco text not null,
  limite numeric(12,2) default 0,
  created_at timestamptz default now()
);

create table if not exists saldos_diarios (
  id uuid primary key default gen_random_uuid(),
  conta_id uuid not null references contas_bancarias(id) on delete cascade,
  data date not null,
  saldo numeric(12,2) not null,
  created_at timestamptz default now()
);

alter table contas_bancarias enable row level security;
alter table saldos_diarios enable row level security;

drop policy if exists "authenticated full access" on contas_bancarias;
create policy "authenticated full access" on contas_bancarias
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on saldos_diarios;
create policy "authenticated full access" on saldos_diarios
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

alter publication supabase_realtime add table contas_bancarias;
alter publication supabase_realtime add table saldos_diarios;
