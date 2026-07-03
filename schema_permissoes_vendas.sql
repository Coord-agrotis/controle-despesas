-- Rode este script no Supabase (SQL Editor > New query > Run).
-- Adiciona: Venda Diária (CONFI/FLH/GODINES) e controle de acesso restrito por e-mail.
-- Também ATUALIZA as políticas das 4 tabelas já existentes (despesas, recebimentos,
-- contas_bancarias, saldos_diarios) para que um usuário restrito não consiga lê-las.

create table if not exists vendas_diarias (
  id uuid primary key default gen_random_uuid(),
  empresa text not null,
  data date not null,
  total_credito numeric(12,2) default 0,
  total_debito numeric(12,2) default 0,
  total_refeicao numeric(12,2) default 0,
  total_dinheiro numeric(12,2) default 0,
  total_pix numeric(12,2) default 0,
  fiado numeric(12,2) default 0,
  ifood numeric(12,2) default 0,
  caixa_inicial numeric(12,2) default 0,
  retirada_caixa numeric(12,2) default 0,
  caixa numeric(12,2) default 0,
  total_vendas numeric(12,2) default 0,
  total_pessoas integer default 0,
  total_fichas integer default 0,
  created_at timestamptz default now()
);

create table if not exists perfis (
  email text primary key,
  empresa_liberada text,
  created_at timestamptz default now()
);

alter table vendas_diarias enable row level security;
alter table perfis enable row level security;

-- Funções auxiliares (security definer = ignoram RLS ao consultar "perfis", evitando recursão)
create or replace function is_full_access() returns boolean
language sql security definer stable as $$
  select not exists (
    select 1 from perfis where email = auth.jwt()->>'email' and empresa_liberada is not null
  );
$$;

create or replace function minha_empresa_liberada() returns text
language sql security definer stable as $$
  select empresa_liberada from perfis where email = auth.jwt()->>'email';
$$;

-- perfis: qualquer autenticado lê a própria linha; só quem tem acesso completo gerencia
drop policy if exists "perfis select" on perfis;
create policy "perfis select" on perfis for select
  using (email = auth.jwt()->>'email' or is_full_access());

drop policy if exists "perfis insert" on perfis;
create policy "perfis insert" on perfis for insert
  with check (is_full_access());

drop policy if exists "perfis update" on perfis;
create policy "perfis update" on perfis for update
  using (is_full_access()) with check (is_full_access());

drop policy if exists "perfis delete" on perfis;
create policy "perfis delete" on perfis for delete
  using (is_full_access());

-- vendas_diarias: acesso completo vê tudo; usuário restrito só vê/grava a própria empresa
drop policy if exists "vendas access" on vendas_diarias;
create policy "vendas access" on vendas_diarias for all
  using (auth.role() = 'authenticated' and (is_full_access() or empresa = minha_empresa_liberada()))
  with check (auth.role() = 'authenticated' and (is_full_access() or empresa = minha_empresa_liberada()));

-- Tabelas existentes: agora só quem tem acesso completo pode ler/gravar
drop policy if exists "authenticated full access" on despesas;
create policy "authenticated full access" on despesas for all
  using (auth.role() = 'authenticated' and is_full_access())
  with check (auth.role() = 'authenticated' and is_full_access());

drop policy if exists "authenticated full access" on recebimentos;
create policy "authenticated full access" on recebimentos for all
  using (auth.role() = 'authenticated' and is_full_access())
  with check (auth.role() = 'authenticated' and is_full_access());

drop policy if exists "authenticated full access" on contas_bancarias;
create policy "authenticated full access" on contas_bancarias for all
  using (auth.role() = 'authenticated' and is_full_access())
  with check (auth.role() = 'authenticated' and is_full_access());

drop policy if exists "authenticated full access" on saldos_diarios;
create policy "authenticated full access" on saldos_diarios for all
  using (auth.role() = 'authenticated' and is_full_access())
  with check (auth.role() = 'authenticated' and is_full_access());

-- Tempo real (idempotente, seguro rodar de novo)
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'vendas_diarias') then
    alter publication supabase_realtime add table vendas_diarias;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'perfis') then
    alter publication supabase_realtime add table perfis;
  end if;
end $$;
