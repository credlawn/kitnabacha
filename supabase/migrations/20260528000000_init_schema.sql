-- 1. Create a profiles table for user metadata
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Trigger to automatically create a profile entry when a user signs up via auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer set search_path = public, auth;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 3. Create contacts table
create table public.contacts (
  id uuid primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  phone text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_deleted boolean default false not null
);

-- 4. Create transactions table
create table public.transactions (
  id uuid primary key,
  contact_id uuid references public.contacts on delete cascade not null,
  user_id uuid references auth.users on delete cascade not null,
  amount numeric(12, 2) not null,
  type text not null check (type in ('give', 'take', 'receive', 'pay')),
  description text,
  date timestamp with time zone not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_deleted boolean default false not null
);

-- 4b. Create indexes on foreign keys for performance
create index if not exists idx_contacts_user_id on public.contacts (user_id);
create index if not exists idx_transactions_user_id on public.transactions (user_id);
create index if not exists idx_transactions_contact_id on public.transactions (contact_id);

-- 5. Enable Row Level Security (RLS) to keep data secure per user
alter table public.profiles enable row level security;
alter table public.contacts enable row level security;
alter table public.transactions enable row level security;

-- 6. Setup RLS Policies (Ensure users can only access their own data)

-- Profiles policies
create policy "Users can view their own profile" on public.profiles
  for select using ((select auth.uid()) = id);

create policy "Users can update their own profile" on public.profiles
  for update using ((select auth.uid()) = id);

-- Contacts policies
create policy "Users can view their own contacts" on public.contacts
  for select using ((select auth.uid()) = user_id);

create policy "Users can insert their own contacts" on public.contacts
  for insert with check ((select auth.uid()) = user_id);

create policy "Users can update their own contacts" on public.contacts
  for update using ((select auth.uid()) = user_id);

create policy "Users can delete their own contacts" on public.contacts
  for delete using ((select auth.uid()) = user_id);

-- Transactions policies
create policy "Users can view their own transactions" on public.transactions
  for select using ((select auth.uid()) = user_id);

create policy "Users can insert their own transactions" on public.transactions
  for insert with check ((select auth.uid()) = user_id);

create policy "Users can update their own transactions" on public.transactions
  for update using ((select auth.uid()) = user_id);

create policy "Users can delete their own transactions" on public.transactions
  for delete using ((select auth.uid()) = user_id);

-- 7. Trigger to automatically keep updated_at columns up to date on modification
create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql set search_path = public;

create or replace trigger update_contacts_updated_at
  before update on public.contacts
  for each row execute procedure public.update_updated_at_column();


create or replace trigger update_transactions_updated_at
  before update on public.transactions
  for each row execute procedure public.update_updated_at_column();

-- 8. Revoke execute on public functions from public, anon, and authenticated roles (API/RPC security)
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.update_updated_at_column() from public, anon, authenticated;

-- 9. Revoke default public privileges on tables (GraphQL / API discovery security)
revoke all on table public.profiles from public, anon;
revoke all on table public.contacts from public, anon;
revoke all on table public.transactions from public, anon;

-- 10. Grant explicit access to authenticated and service_role
grant all on table public.profiles to authenticated, service_role;
grant all on table public.contacts to authenticated, service_role;
grant all on table public.transactions to authenticated, service_role;

-- 11. Disable GraphQL completely for our tables (since we use REST API in Flutter, this is 100% safe and removes GraphQL visibility warnings)
comment on table public.profiles is '@graphql(disable)';
comment on table public.contacts is '@graphql(disable)';
comment on table public.transactions is '@graphql(disable)';
