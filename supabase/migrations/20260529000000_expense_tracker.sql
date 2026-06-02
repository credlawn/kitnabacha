-- Create expense_categories table
create table public.expense_categories (
  id uuid primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  icon text not null,
  color text not null,
  sub_categories text[] default '{}'::text[] not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_deleted boolean default false not null
);

-- Create expenses table
create table public.expenses (
  id uuid primary key,
  user_id uuid references auth.users on delete cascade not null,
  category_id uuid references public.expense_categories on delete cascade not null,
  sub_category text not null default 'General',
  amount numeric(12, 2) not null,
  remarks text,
  date timestamp with time zone not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_deleted boolean default false not null
);

-- Indexes for performance
create index if not exists idx_expense_categories_user_id on public.expense_categories (user_id);
create index if not exists idx_expenses_user_id on public.expenses (user_id);
create index if not exists idx_expenses_category_id on public.expenses (category_id);

-- Enable Row Level Security (RLS)
alter table public.expense_categories enable row level security;
alter table public.expenses enable row level security;

-- Setup RLS Policies for expense_categories
create policy "Users can view their own expense categories" on public.expense_categories
  for select using ((select auth.uid()) = user_id);

create policy "Users can insert their own expense categories" on public.expense_categories
  for insert with check ((select auth.uid()) = user_id);

create policy "Users can update their own expense categories" on public.expense_categories
  for update using ((select auth.uid()) = user_id);

create policy "Users can delete their own expense categories" on public.expense_categories
  for delete using ((select auth.uid()) = user_id);

-- Setup RLS Policies for expenses
create policy "Users can view their own expenses" on public.expenses
  for select using ((select auth.uid()) = user_id);

create policy "Users can insert their own expenses" on public.expenses
  for insert with check ((select auth.uid()) = user_id);

create policy "Users can update their own expenses" on public.expenses
  for update using ((select auth.uid()) = user_id);

create policy "Users can delete their own expenses" on public.expenses
  for delete using ((select auth.uid()) = user_id);

-- Setup Triggers for updated_at
create trigger update_expense_categories_updated_at
  before update on public.expense_categories
  for each row execute procedure public.update_updated_at_column();

create trigger update_expenses_updated_at
  before update on public.expenses
  for each row execute procedure public.update_updated_at_column();

-- Revoke default public privileges on tables (security best practices)
revoke all on table public.expense_categories from public, anon;
revoke all on table public.expenses from public, anon;

-- Grant explicit access to authenticated and service_role
grant all on table public.expense_categories to authenticated, service_role;
grant all on table public.expenses to authenticated, service_role;

-- Disable GraphQL for these tables
comment on table public.expense_categories is '@graphql(disable)';
comment on table public.expenses is '@graphql(disable)';
