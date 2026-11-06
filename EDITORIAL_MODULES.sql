-- VISION XEBER / Redaksiya modullari. Onceki melumatlari silmir.
create table if not exists public.editorial_records (
 id uuid primary key default gen_random_uuid(),
 module text not null check(module in ('seo','editorial','government','comments','ads','stream','settings','security')),
 title text not null check(char_length(trim(title)) between 2 and 220),
 body text not null default '',
 status text not null default 'Gözləmədə' check(status in ('Gözləmədə','İcradadır','Tamamlandı','Arxiv')),
 due_on date,
 reference_url text,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create index if not exists editorial_records_mod_idx on public.editorial_records(module,created_at desc);
alter table public.editorial_records enable row level security;
drop policy if exists editorial_read on public.editorial_records;
create policy editorial_read on public.editorial_records for select to authenticated using(public.is_editor());
drop policy if exists editorial_insert on public.editorial_records;
create policy editorial_insert on public.editorial_records for insert to authenticated with check(public.is_editor() and created_by=(select auth.uid()));
drop policy if exists editorial_update on public.editorial_records;
create policy editorial_update on public.editorial_records for update to authenticated using(public.is_editor()) with check(public.is_editor());
drop policy if exists editorial_delete on public.editorial_records;
create policy editorial_delete on public.editorial_records for delete to authenticated using(public.is_editor());
notify pgrst, 'reload schema';
