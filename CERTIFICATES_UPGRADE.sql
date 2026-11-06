-- VISION XEBER: secure certificate issuance and public verification. Run once after schema.sql.
create table if not exists public.certificates (
 id uuid primary key default gen_random_uuid(),
 code text not null unique default ('VX-CERT-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))),
 volunteer_id uuid references public.volunteers(id) on delete set null,
 recipient_name text not null check(char_length(btrim(recipient_name)) between 2 and 150),
 program text not null check(char_length(btrim(program)) between 3 and 200),
 description text not null default '',
 issued_on date not null default current_date,
 status text not null default 'issued' check(status in ('issued','revoked')),
 issued_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create index if not exists certificates_volunteer_idx on public.certificates(volunteer_id);
alter table public.certificates enable row level security;
drop policy if exists certificates_editor_select on public.certificates;
create policy certificates_editor_select on public.certificates for select to authenticated using(public.is_editor());
drop policy if exists certificates_editor_insert on public.certificates;
create policy certificates_editor_insert on public.certificates for insert to authenticated with check(public.is_editor() and issued_by=(select auth.uid()));
drop policy if exists certificates_head_update on public.certificates;
create policy certificates_head_update on public.certificates for update to authenticated using(public.is_head()) with check(public.is_head());
-- Public verification only discloses certificate attributes; no volunteer email/phone exposed.
create or replace function public.verify_vision_certificate(p_code text)
returns table(code text, recipient_name text, program text, description text, issued_on date, status text)
language sql stable security definer set search_path=public as $$
 select c.code,c.recipient_name,c.program,c.description,c.issued_on,c.status
 from public.certificates c where c.code=p_code and c.status='issued' limit 1
$$;
revoke all on function public.verify_vision_certificate(text) from public;
grant execute on function public.verify_vision_certificate(text) to anon,authenticated;
notify pgrst, 'reload schema';
