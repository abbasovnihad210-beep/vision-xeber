-- Run in Supabase SQL Editor. All data access is protected by RLS.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '',
 role text not null default 'pending' check(role in ('pending','admin','head','volunteer')),
 status text not null default 'pending' check(status in ('active','pending','blocked')),
 created_at timestamptz not null default now()
);
create or replace function public.create_profile_on_signup() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,display_name,role,status) values(new.id,coalesce(new.raw_user_meta_data->>'name',''),'pending','pending') on conflict do nothing; return new; end $$;
drop trigger if exists create_profile_after_signup on auth.users;
create trigger create_profile_after_signup after insert on auth.users for each row execute function public.create_profile_on_signup();
create or replace function public.is_editor() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=(select auth.uid()) and role in ('admin','head') and status='active')
$$;
create or replace function public.is_head() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=(select auth.uid()) and role='head' and status='active')
$$;
create table if not exists public.news (
 id uuid primary key default gen_random_uuid(), title text not null check(length(title) between 5 and 240),
 summary text not null default '', body text not null default '', category text not null default 'Cəmiyyət',
 image_url text, tags text not null default '', status text not null default 'draft' check(status in ('draft','published','archived')),
 breaking boolean not null default false, featured boolean not null default false,
 author_id uuid references auth.users(id), created_at timestamptz not null default now(), published_at timestamptz
);
create index if not exists news_published_idx on public.news(status,published_at desc);
create table if not exists public.appeals (
 id uuid primary key default gen_random_uuid(), tracking_code text not null unique default ('VX-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
 name text, email text, subject text not null, message text not null, attachment_path text,
 status text not null default 'Gözləmədə', created_at timestamptz not null default now()
);
create table if not exists public.volunteers (
 id uuid primary key default gen_random_uuid(), tracking_code text not null unique default ('K-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
 name text not null, email text not null, phone text, field text, bio text,
 status text not null default 'Gözləmədə', created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
alter table public.news enable row level security;
alter table public.appeals enable row level security;
alter table public.volunteers enable row level security;
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using(id=(select auth.uid()) or public.is_head());
drop policy if exists profiles_head_update on public.profiles;
create policy profiles_head_update on public.profiles for update to authenticated using(public.is_head()) with check(public.is_head());
drop policy if exists news_public_read on public.news;
create policy news_public_read on public.news for select to anon, authenticated using(status='published' or public.is_editor());
drop policy if exists news_editor_insert on public.news;
create policy news_editor_insert on public.news for insert to authenticated with check(public.is_editor() and author_id=(select auth.uid()));
drop policy if exists news_editor_update on public.news;
create policy news_editor_update on public.news for update to authenticated using(public.is_editor()) with check(public.is_editor());
drop policy if exists news_editor_delete on public.news;
create policy news_editor_delete on public.news for delete to authenticated using(public.is_editor());
drop policy if exists appeals_public_insert on public.appeals;
create policy appeals_public_insert on public.appeals for insert to anon,authenticated with check(length(message) between 10 and 10000);
drop policy if exists appeals_editor_read on public.appeals;
create policy appeals_editor_read on public.appeals for select to authenticated using(public.is_editor());
drop policy if exists appeals_editor_update on public.appeals;
create policy appeals_editor_update on public.appeals for update to authenticated using(public.is_editor()) with check(public.is_editor());
drop policy if exists volunteers_public_insert on public.volunteers;
create policy volunteers_public_insert on public.volunteers for insert to anon,authenticated with check(length(name)>1 and length(email)>3);
drop policy if exists volunteers_editor_read on public.volunteers;
create policy volunteers_editor_read on public.volunteers for select to authenticated using(public.is_editor());
drop policy if exists volunteers_editor_update on public.volunteers;
create policy volunteers_editor_update on public.volunteers for update to authenticated using(public.is_editor()) with check(public.is_editor());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('news-images','news-images',true,5242880,array['image/jpeg','image/png','image/webp']),
 ('appeal-attachments','appeal-attachments',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do nothing;
drop policy if exists news_image_public on storage.objects;
create policy news_image_public on storage.objects for select to anon,authenticated using(bucket_id='news-images');
drop policy if exists news_image_editor on storage.objects;
create policy news_image_editor on storage.objects for insert to authenticated with check(bucket_id='news-images' and public.is_editor());
drop policy if exists news_image_editor_delete on storage.objects;
create policy news_image_editor_delete on storage.objects for delete to authenticated using(bucket_id='news-images' and public.is_editor());
-- Appeals attachments: public-upload bucket restricted to insert only; readers must be editors.
drop policy if exists appeal_attach_insert on storage.objects;
create policy appeal_attach_insert on storage.objects for insert to anon,authenticated with check(bucket_id='appeal-attachments' and (storage.foldername(name))[1]='public');
drop policy if exists appeal_attach_editor_read on storage.objects;
create policy appeal_attach_editor_read on storage.objects for select to authenticated using(bucket_id='appeal-attachments' and public.is_editor());
-- IMPORTANT: The first head admin must be promoted MANUALLY in SQL Editor after signing up:
-- update public.profiles set role='head',status='active' where id=(select id from auth.users where email='YOUR_EMAIL@example.com');
-- Never enable open head-admin signup or expose any service-role key in website code.
-- Secure, limited anonymous submissions return tracking codes without exposing private rows.
create or replace function public.submit_appeal(p_name text,p_email text,p_subject text,p_message text,p_attachment_path text default null)
returns text language plpgsql security definer set search_path=public as $$
declare result text;
begin
 if length(trim(p_message)) not between 10 and 10000 then raise exception 'Müraciət 10–10000 simvol olmalıdır'; end if;
 if length(coalesce(p_name,''))>150 or length(coalesce(p_email,''))>200 or length(coalesce(p_subject,''))>100 then raise exception 'Sahə çox uzundur'; end if;
 if p_attachment_path is not null and p_attachment_path not like 'public/%' then raise exception 'Yalnış fayl yolu';end if;
 insert into public.appeals(name,email,subject,message,attachment_path) values(p_name,p_email,p_subject,p_message,p_attachment_path) returning tracking_code into result;
 return result;
end $$;
create or replace function public.submit_volunteer(p_name text,p_email text,p_phone text,p_field text,p_bio text)
returns text language plpgsql security definer set search_path=public as $$
declare result text;
begin
 if length(trim(p_name)) not between 2 and 150 or length(trim(p_email)) not between 5 and 200 then raise exception 'Ad və e-poçt tələb olunur'; end if;
 if length(coalesce(p_phone,''))>60 or length(coalesce(p_field,''))>100 or length(coalesce(p_bio,''))>3000 then raise exception 'Sahə çox uzundur'; end if;
 insert into public.volunteers(name,email,phone,field,bio) values(p_name,p_email,p_phone,p_field,p_bio) returning tracking_code into result;
 return result;
end $$;
revoke all on function public.submit_appeal(text,text,text,text,text) from public;
revoke all on function public.submit_volunteer(text,text,text,text,text) from public;
grant execute on function public.submit_appeal(text,text,text,text,text) to anon,authenticated;
grant execute on function public.submit_volunteer(text,text,text,text,text) to anon,authenticated;
-- Abuse prevention for public uploads and RPC endpoints requires rate limits/CAPTCHA before high-traffic launch.
