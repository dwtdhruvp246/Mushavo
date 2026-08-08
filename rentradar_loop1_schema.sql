-- Mushavo Supabase SQL Schema
-- Run this in the Supabase SQL Editor for a fresh project.
-- This script creates the schema, RLS policies, triggers, and RPC functions.

begin;

-- Clean up legacy auth triggers/functions from older RentRadar/Mushavo schema versions.
-- Old projects may still have handle_new_user() attached to auth.users, and that
-- function references obsolete tables such as public.account_invitations.
do $$
declare
  legacy_trigger record;
begin
  for legacy_trigger in
    select t.tgname
    from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace cn on cn.oid = c.relnamespace
    where cn.nspname = 'auth'
      and c.relname = 'users'
      and p.proname = 'handle_new_user'
      and not t.tgisinternal
  loop
    execute format('drop trigger if exists %I on auth.users', legacy_trigger.tgname);
  end loop;

  execute 'drop trigger if exists on_auth_user_created on auth.users';
  execute 'drop trigger if exists handle_new_user on auth.users';
end $$;

drop function if exists public.handle_new_user();
drop function if exists auth.handle_new_user();

create extension if not exists pgcrypto;

create or replace function public.generate_six_digit_code()
returns text
language sql
volatile
as $$
  select lpad(floor(random() * 1000000)::int::text, 6, '0')
$$;

create or replace function public.generate_invite_token(p_bytes integer default 32)
returns text
language sql
volatile
as $$
  select left(
    replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '')
    || md5(clock_timestamp()::text || random()::text),
    greatest(16, p_bytes * 2)
  )
$$;

create table if not exists public.countries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text,
  currency_code text,
  market_enabled_at timestamptz,
  market_enabled_by uuid,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint countries_name_unique unique (name),
  constraint countries_code_unique unique (code)
);

alter table public.countries add column if not exists market_enabled_at timestamptz;
alter table public.countries add column if not exists market_enabled_by uuid;

create index if not exists countries_created_at_idx on public.countries (created_at desc);

insert into public.countries (code, name, currency_code)
values
  ('AF', 'Afghanistan', null),
  ('AL', 'Albania', null),
  ('DZ', 'Algeria', null),
  ('AD', 'Andorra', null),
  ('AO', 'Angola', null),
  ('AG', 'Antigua and Barbuda', null),
  ('AR', 'Argentina', null),
  ('AM', 'Armenia', null),
  ('AU', 'Australia', null),
  ('AT', 'Austria', null),
  ('AZ', 'Azerbaijan', null),
  ('BS', 'Bahamas', null),
  ('BH', 'Bahrain', null),
  ('BD', 'Bangladesh', null),
  ('BB', 'Barbados', null),
  ('BY', 'Belarus', null),
  ('BE', 'Belgium', null),
  ('BZ', 'Belize', null),
  ('BJ', 'Benin', null),
  ('BT', 'Bhutan', null),
  ('BO', 'Bolivia', null),
  ('BA', 'Bosnia and Herzegovina', null),
  ('BW', 'Botswana', null),
  ('BR', 'Brazil', null),
  ('BN', 'Brunei', null),
  ('BG', 'Bulgaria', null),
  ('BF', 'Burkina Faso', null),
  ('BI', 'Burundi', null),
  ('CV', 'Cabo Verde', null),
  ('KH', 'Cambodia', null),
  ('CM', 'Cameroon', null),
  ('CA', 'Canada', null),
  ('CF', 'Central African Republic', null),
  ('TD', 'Chad', null),
  ('CL', 'Chile', null),
  ('CN', 'China', null),
  ('CO', 'Colombia', null),
  ('KM', 'Comoros', null),
  ('CG', 'Congo', null),
  ('CD', 'Congo Democratic Republic', null),
  ('CR', 'Costa Rica', null),
  ('CI', 'Cote d''Ivoire', null),
  ('HR', 'Croatia', null),
  ('CU', 'Cuba', null),
  ('CY', 'Cyprus', null),
  ('CZ', 'Czechia', null),
  ('DK', 'Denmark', null),
  ('DJ', 'Djibouti', null),
  ('DM', 'Dominica', null),
  ('DO', 'Dominican Republic', null),
  ('EC', 'Ecuador', null),
  ('EG', 'Egypt', null),
  ('SV', 'El Salvador', null),
  ('GQ', 'Equatorial Guinea', null),
  ('ER', 'Eritrea', null),
  ('EE', 'Estonia', null),
  ('SZ', 'Eswatini', null),
  ('ET', 'Ethiopia', null),
  ('FJ', 'Fiji', null),
  ('FI', 'Finland', null),
  ('FR', 'France', null),
  ('GA', 'Gabon', null),
  ('GM', 'Gambia', null),
  ('GE', 'Georgia', null),
  ('DE', 'Germany', null),
  ('GH', 'Ghana', null),
  ('GR', 'Greece', null),
  ('GD', 'Grenada', null),
  ('GT', 'Guatemala', null),
  ('GN', 'Guinea', null),
  ('GW', 'Guinea-Bissau', null),
  ('GY', 'Guyana', null),
  ('HT', 'Haiti', null),
  ('HN', 'Honduras', null),
  ('HU', 'Hungary', null),
  ('IS', 'Iceland', null),
  ('IN', 'India', null),
  ('ID', 'Indonesia', null),
  ('IR', 'Iran', null),
  ('IQ', 'Iraq', null),
  ('IE', 'Ireland', null),
  ('IL', 'Israel', null),
  ('IT', 'Italy', null),
  ('JM', 'Jamaica', null),
  ('JP', 'Japan', null),
  ('JO', 'Jordan', null),
  ('KZ', 'Kazakhstan', null),
  ('KE', 'Kenya', null),
  ('KI', 'Kiribati', null),
  ('XK', 'Kosovo', null),
  ('KW', 'Kuwait', null),
  ('KG', 'Kyrgyzstan', null),
  ('LA', 'Laos', null),
  ('LV', 'Latvia', null),
  ('LB', 'Lebanon', null),
  ('LS', 'Lesotho', null),
  ('LR', 'Liberia', null),
  ('LY', 'Libya', null),
  ('LI', 'Liechtenstein', null),
  ('LT', 'Lithuania', null),
  ('LU', 'Luxembourg', null),
  ('MG', 'Madagascar', null),
  ('MW', 'Malawi', null),
  ('MY', 'Malaysia', 'MYR'),
  ('MV', 'Maldives', null),
  ('ML', 'Mali', null),
  ('MT', 'Malta', null),
  ('MH', 'Marshall Islands', null),
  ('MR', 'Mauritania', null),
  ('MU', 'Mauritius', null),
  ('MX', 'Mexico', null),
  ('FM', 'Micronesia', null),
  ('MD', 'Moldova', null),
  ('MC', 'Monaco', null),
  ('MN', 'Mongolia', null),
  ('ME', 'Montenegro', null),
  ('MA', 'Morocco', null),
  ('MZ', 'Mozambique', null),
  ('MM', 'Myanmar', null),
  ('NA', 'Namibia', null),
  ('NR', 'Nauru', null),
  ('NP', 'Nepal', null),
  ('NL', 'Netherlands', null),
  ('NZ', 'New Zealand', null),
  ('NI', 'Nicaragua', null),
  ('NE', 'Niger', null),
  ('NG', 'Nigeria', null),
  ('KP', 'North Korea', null),
  ('MK', 'North Macedonia', null),
  ('NO', 'Norway', null),
  ('OM', 'Oman', null),
  ('PK', 'Pakistan', null),
  ('PW', 'Palau', null),
  ('PS', 'Palestine', null),
  ('PA', 'Panama', null),
  ('PG', 'Papua New Guinea', null),
  ('PY', 'Paraguay', null),
  ('PE', 'Peru', null),
  ('PH', 'Philippines', null),
  ('PL', 'Poland', null),
  ('PT', 'Portugal', null),
  ('QA', 'Qatar', null),
  ('RO', 'Romania', null),
  ('RU', 'Russia', null),
  ('RW', 'Rwanda', null),
  ('KN', 'Saint Kitts and Nevis', null),
  ('LC', 'Saint Lucia', null),
  ('VC', 'Saint Vincent and the Grenadines', null),
  ('WS', 'Samoa', null),
  ('SM', 'San Marino', null),
  ('ST', 'Sao Tome and Principe', null),
  ('SA', 'Saudi Arabia', null),
  ('SN', 'Senegal', null),
  ('RS', 'Serbia', null),
  ('SC', 'Seychelles', null),
  ('SL', 'Sierra Leone', null),
  ('SG', 'Singapore', null),
  ('SK', 'Slovakia', null),
  ('SI', 'Slovenia', null),
  ('SB', 'Solomon Islands', null),
  ('SO', 'Somalia', null),
  ('ZA', 'South Africa', null),
  ('KR', 'South Korea', null),
  ('SS', 'South Sudan', null),
  ('ES', 'Spain', null),
  ('LK', 'Sri Lanka', null),
  ('SD', 'Sudan', null),
  ('SR', 'Suriname', null),
  ('SE', 'Sweden', null),
  ('CH', 'Switzerland', null),
  ('SY', 'Syria', null),
  ('TW', 'Taiwan', null),
  ('TJ', 'Tajikistan', null),
  ('TZ', 'Tanzania', null),
  ('TH', 'Thailand', null),
  ('TL', 'Timor-Leste', null),
  ('TG', 'Togo', null),
  ('TO', 'Tonga', null),
  ('TT', 'Trinidad and Tobago', null),
  ('TN', 'Tunisia', null),
  ('TR', 'Turkiye', null),
  ('TM', 'Turkmenistan', null),
  ('TV', 'Tuvalu', null),
  ('UG', 'Uganda', null),
  ('UA', 'Ukraine', null),
  ('AE', 'United Arab Emirates', null),
  ('GB', 'United Kingdom', null),
  ('US', 'United States', null),
  ('UY', 'Uruguay', null),
  ('UZ', 'Uzbekistan', null),
  ('VU', 'Vanuatu', null),
  ('VA', 'Vatican City', null),
  ('VE', 'Venezuela', null),
  ('VN', 'Vietnam', null),
  ('YE', 'Yemen', null),
  ('ZM', 'Zambia', null),
  ('ZW', 'Zimbabwe', 'USD')
on conflict (code) do update
set name = excluded.name,
    currency_code = coalesce(excluded.currency_code, public.countries.currency_code),
    archived_at = null;

create table if not exists public.pricing_plans (
  id uuid primary key default gen_random_uuid(),
  country_id uuid null references public.countries(id) on delete set null,
  country_code text,
  country_name text,
  currency_code text not null default 'USD',
  account_type text not null check (account_type in ('landlord', 'ipm', 'pmc')),
  plan_key text not null,
  plan_name text not null,
  display_order integer not null default 100,
  monthly_amount numeric(12,2) not null default 0 check (monthly_amount >= 0),
  yearly_amount numeric(12,2) not null default 0 check (yearly_amount >= 0),
  custom_price_label text,
  description text not null default '',
  limits_summary text not null default '',
  property_limit integer not null default 0 check (property_limit >= 0),
  unit_limit integer not null default 0 check (unit_limit >= 0),
  personal_staff_limit integer not null default 0 check (personal_staff_limit >= 0),
  partner_connection_limit integer not null default 0 check (partner_connection_limit >= 0),
  landlord_limit integer not null default 0 check (landlord_limit >= 0),
  properties_per_landlord_limit integer not null default 0 check (properties_per_landlord_limit >= 0),
  staff_limit integer not null default 0 check (staff_limit >= 0),
  cta_label text,
  cta_href text,
  popular boolean not null default false,
  public_active boolean not null default true,
  updated_by uuid null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint pricing_plans_country_account_plan_unique unique (country_code, account_type, plan_key)
);

alter table public.pricing_plans add column if not exists country_id uuid null references public.countries(id) on delete set null;
alter table public.pricing_plans add column if not exists country_code text;
alter table public.pricing_plans add column if not exists country_name text;
alter table public.pricing_plans add column if not exists currency_code text not null default 'USD';
alter table public.pricing_plans add column if not exists account_type text;
alter table public.pricing_plans add column if not exists plan_key text;
alter table public.pricing_plans add column if not exists plan_name text;
alter table public.pricing_plans add column if not exists display_order integer not null default 100;
alter table public.pricing_plans add column if not exists monthly_amount numeric(12,2) not null default 0;
alter table public.pricing_plans add column if not exists yearly_amount numeric(12,2) not null default 0;
alter table public.pricing_plans add column if not exists custom_price_label text;
alter table public.pricing_plans add column if not exists description text not null default '';
alter table public.pricing_plans add column if not exists limits_summary text not null default '';
alter table public.pricing_plans add column if not exists property_limit integer not null default 0;
alter table public.pricing_plans add column if not exists unit_limit integer not null default 0;
alter table public.pricing_plans add column if not exists personal_staff_limit integer not null default 0;
alter table public.pricing_plans add column if not exists partner_connection_limit integer not null default 0;
alter table public.pricing_plans add column if not exists landlord_limit integer not null default 0;
alter table public.pricing_plans add column if not exists properties_per_landlord_limit integer not null default 0;
alter table public.pricing_plans add column if not exists staff_limit integer not null default 0;
alter table public.pricing_plans add column if not exists cta_label text;
alter table public.pricing_plans add column if not exists cta_href text;
alter table public.pricing_plans add column if not exists popular boolean not null default false;
alter table public.pricing_plans add column if not exists public_active boolean not null default true;
alter table public.pricing_plans add column if not exists updated_by uuid null;
alter table public.pricing_plans add column if not exists updated_at timestamptz not null default now();
alter table public.pricing_plans add column if not exists created_at timestamptz not null default now();

create unique index if not exists pricing_plans_country_account_plan_idx on public.pricing_plans (country_code, account_type, plan_key);
create index if not exists pricing_plans_lookup_idx on public.pricing_plans (country_id, account_type, display_order);
create index if not exists pricing_plans_public_idx on public.pricing_plans (public_active, country_code, account_type, display_order);

do $$
begin
  create type public.user_role as enum ('super_admin', 'landlord', 'staff', 'tenant');
exception when duplicate_object then null;
end $$;

do $$
begin
  alter type public.user_role add value if not exists 'management_leader';
  alter type public.user_role add value if not exists 'management_staff';
  alter type public.user_role add value if not exists 'admin_staff';
end $$;

-- PostgreSQL does not allow newly-added enum values to be used in constraints
-- until the transaction that added them has committed.
commit;

begin;

do $$
begin
  create type public.subscription_status as enum ('trial', 'active', 'suspended');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.unit_status as enum ('vacant', 'occupied');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.lease_status as enum ('active', 'expired', 'terminated');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.payment_method as enum ('cash', 'bank_transfer', 'mobile_money', 'other');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.submission_status as enum ('pending', 'approved', 'rejected');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.maintenance_status as enum (
    'open',
    'quote_requested',
    'quote_sent',
    'approved',
    'scheduled',
    'in_progress',
    'completed',
    'resolved',
    'cancelled'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  alter type public.maintenance_status add value if not exists 'quote_requested';
  alter type public.maintenance_status add value if not exists 'quote_sent';
  alter type public.maintenance_status add value if not exists 'approved';
  alter type public.maintenance_status add value if not exists 'scheduled';
  alter type public.maintenance_status add value if not exists 'completed';
  alter type public.maintenance_status add value if not exists 'cancelled';
end $$;

do $$
begin
  create type public.priority_level as enum ('low', 'medium', 'high');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.notification_type as enum (
    'payment_submitted',
    'payment_approved',
    'payment_rejected',
    'lease_expiring',
    'maintenance_new',
    'maintenance_updated',
    'rent_due',
    'tenant_link_request',
    'tenant_reference_request',
    'lease_lifecycle_reminder',
    'tenant_application_update'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  alter type public.notification_type add value if not exists 'tenant_link_request';
  alter type public.notification_type add value if not exists 'staff_landlord_request';
  alter type public.notification_type add value if not exists 'management_landlord_request';
  alter type public.notification_type add value if not exists 'tenant_reference_request';
  alter type public.notification_type add value if not exists 'lease_lifecycle_reminder';
  alter type public.notification_type add value if not exists 'tenant_application_update';
end $$;

-- Commit enum changes before functions use newly-added enum values.
commit;

begin;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  landlord_id uuid null references public.profiles(id) on delete cascade,
  country_id uuid null references public.countries(id) on delete set null,
  landlord_code text,
  staff_type text not null default 'landlord' check (staff_type in ('landlord', 'freelancer')),
  staff_max_landlords integer not null default 2 check (staff_max_landlords >= 0),
  staff_max_properties_per_landlord integer not null default 5 check (staff_max_properties_per_landlord >= 0),
  staff_subscription_status text not null default 'free' check (staff_subscription_status in ('free', 'trial', 'active', 'suspended')),
  staff_subscription_expires_at date,
  email_verified boolean not null default false,
  verified_at timestamptz,
  full_name text not null,
  phone text,
  email text not null,
  role public.user_role not null,
  telegram_chat_id text,
  telegram_connected boolean not null default false,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid null references public.profiles(id) on delete set null,
  access_suspended_at timestamptz,
  access_suspended_by uuid null references public.profiles(id) on delete set null,
  constraint profiles_landlord_role_check check (
    (role in ('super_admin', 'landlord', 'management_leader', 'admin_staff') and landlord_id is null)
    or role in ('staff', 'management_staff')
    or role = 'tenant'
  )
);

create unique index if not exists profiles_email_unique_idx on public.profiles (lower(email));
create index if not exists profiles_landlord_id_idx on public.profiles (landlord_id);
alter table public.profiles add column if not exists country_id uuid null references public.countries(id) on delete set null;
create index if not exists profiles_country_id_idx on public.profiles (country_id);
alter table public.profiles add column if not exists landlord_code text;
alter table public.profiles add column if not exists staff_type text not null default 'landlord';
alter table public.profiles add column if not exists staff_max_landlords integer not null default 2;
alter table public.profiles add column if not exists staff_max_properties_per_landlord integer not null default 5;
alter table public.profiles add column if not exists staff_subscription_status text not null default 'free';
alter table public.profiles add column if not exists staff_subscription_expires_at date;
alter table public.profiles add column if not exists email_verified boolean not null default false;
alter table public.profiles add column if not exists verified_at timestamptz;
alter table public.profiles add column if not exists archived_at timestamptz;
alter table public.profiles add column if not exists archived_by uuid null references public.profiles(id) on delete set null;
alter table public.profiles add column if not exists access_suspended_at timestamptz;
alter table public.profiles add column if not exists access_suspended_by uuid null references public.profiles(id) on delete set null;
create unique index if not exists profiles_landlord_code_unique_idx
  on public.profiles (landlord_code)
  where landlord_code is not null;

do $$
begin
  alter table public.profiles drop constraint if exists profiles_landlord_role_check;
  alter table public.profiles add constraint profiles_landlord_role_check check (
    (role in ('super_admin', 'landlord', 'management_leader', 'admin_staff') and landlord_id is null)
    or role in ('staff', 'management_staff')
    or role = 'tenant'
  );
  alter table public.profiles drop constraint if exists profiles_staff_max_landlords_check;
  alter table public.profiles add constraint profiles_staff_max_landlords_check check (staff_max_landlords >= 0);
  alter table public.profiles drop constraint if exists profiles_staff_max_properties_per_landlord_check;
  alter table public.profiles add constraint profiles_staff_max_properties_per_landlord_check check (staff_max_properties_per_landlord >= 0);
  alter table public.profiles drop constraint if exists profiles_staff_type_check;
  alter table public.profiles add constraint profiles_staff_type_check check (staff_type in ('landlord', 'freelancer'));
  alter table public.profiles drop constraint if exists profiles_staff_subscription_status_check;
  alter table public.profiles add constraint profiles_staff_subscription_status_check check (staff_subscription_status in ('free', 'trial', 'active', 'suspended'));
end $$;

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text not null,
  country_name text not null,
  country_id uuid null references public.countries(id) on delete set null,
  enquiry_type text not null,
  message text not null,
  status text not null default 'new',
  source text not null default 'website',
  handled_by uuid null references public.profiles(id) on delete set null,
  handled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint enquiries_status_check check (status in ('new', 'in_progress', 'resolved', 'archived')),
  constraint enquiries_full_name_not_blank check (length(trim(full_name)) > 0),
  constraint enquiries_email_not_blank check (length(trim(email)) > 0),
  constraint enquiries_country_name_not_blank check (length(trim(country_name)) > 0),
  constraint enquiries_message_not_blank check (length(trim(message)) > 0)
);

create index if not exists enquiries_created_at_idx on public.enquiries (created_at desc);
create index if not exists enquiries_country_id_idx on public.enquiries (country_id);
create index if not exists enquiries_status_idx on public.enquiries (status);

create table if not exists public.invite_tokens (
  id uuid primary key default gen_random_uuid(),
  token text not null unique default public.generate_invite_token(32),
  email text not null,
  role public.user_role not null check (role in ('landlord', 'staff', 'tenant', 'management_leader', 'management_staff', 'admin_staff')),
  landlord_id uuid null references public.profiles(id) on delete cascade,
  country_id uuid null references public.countries(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  used boolean not null default false,
  expires_at timestamptz not null default (now() + interval '48 hours'),
  created_at timestamptz not null default now(),
  constraint invite_landlord_scope_check check (
    (role in ('landlord', 'management_leader', 'admin_staff') and landlord_id is null)
    or (role = 'staff' and (landlord_id is not null or metadata ->> 'staff_type' = 'freelancer'))
    or (role = 'tenant' and landlord_id is not null)
    or (role = 'management_staff' and (landlord_id is not null or metadata ->> 'management_company_id' is not null))
  )
);

do $$
begin
  alter table public.invite_tokens drop constraint if exists invite_tokens_role_check;
  alter table public.invite_tokens add constraint invite_tokens_role_check check (role in ('landlord', 'staff', 'tenant', 'management_leader', 'management_staff', 'admin_staff'));
  alter table public.invite_tokens drop constraint if exists invite_landlord_scope_check;
  alter table public.invite_tokens add constraint invite_landlord_scope_check check (
    (role in ('landlord', 'management_leader', 'admin_staff') and landlord_id is null)
    or (role = 'staff' and (landlord_id is not null or metadata ->> 'staff_type' = 'freelancer'))
    or (role = 'tenant' and landlord_id is not null)
    or (role = 'management_staff' and (landlord_id is not null or metadata ->> 'management_company_id' is not null))
  );
end $$;

create index if not exists invite_tokens_email_idx on public.invite_tokens (lower(email));
create index if not exists invite_tokens_landlord_id_idx on public.invite_tokens (landlord_id);
create index if not exists invite_tokens_valid_idx on public.invite_tokens (token, used, expires_at);
alter table public.invite_tokens add column if not exists country_id uuid null references public.countries(id) on delete set null;
alter table public.invite_tokens alter column token set default public.generate_invite_token(32);
create index if not exists invite_tokens_country_id_idx on public.invite_tokens (country_id);

create table if not exists public.landlord_subscriptions (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid null references public.profiles(id) on delete cascade,
  country_id uuid null references public.countries(id) on delete set null,
  subscription_plan text not null default 'free',
  property_limit integer not null default 1 check (property_limit >= 0),
  unit_limit integer not null default 1 check (unit_limit >= 0),
  personal_staff_limit integer not null default 0 check (personal_staff_limit >= 0),
  partner_connection_limit integer not null default 1 check (partner_connection_limit >= 0),
  status public.subscription_status not null default 'active',
  expires_at timestamptz not null default '2099-12-31 23:59:59+00',
  access_suspended_at timestamptz,
  access_suspended_by uuid null references public.profiles(id) on delete set null,
  notes text,
  invite_token_id uuid null references public.invite_tokens(id) on delete set null,
  updated_by uuid null references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

do $$
begin
  with ranked as (
    select
      id,
      row_number() over (
        partition by landlord_id
        order by coalesce(updated_at, created_at, expires_at) desc, created_at desc, id desc
      ) as rn
    from public.landlord_subscriptions
    where landlord_id is not null
  )
  delete from public.landlord_subscriptions ls
  using ranked r
  where ls.id = r.id
    and r.rn > 1;
end $$;

create unique index if not exists landlord_subscriptions_landlord_unique_idx
  on public.landlord_subscriptions (landlord_id)
  where landlord_id is not null;
create unique index if not exists landlord_subscriptions_invite_unique_idx
  on public.landlord_subscriptions (invite_token_id)
  where invite_token_id is not null;
alter table public.landlord_subscriptions add column if not exists country_id uuid null references public.countries(id) on delete set null;
alter table public.landlord_subscriptions add column if not exists subscription_plan text not null default 'free';
alter table public.landlord_subscriptions add column if not exists property_limit integer not null default 1;
alter table public.landlord_subscriptions add column if not exists unit_limit integer not null default 1;
alter table public.landlord_subscriptions add column if not exists personal_staff_limit integer not null default 0;
alter table public.landlord_subscriptions add column if not exists partner_connection_limit integer not null default 1;
alter table public.landlord_subscriptions add column if not exists access_suspended_at timestamptz;
alter table public.landlord_subscriptions add column if not exists access_suspended_by uuid null references public.profiles(id) on delete set null;
alter table public.landlord_subscriptions alter column subscription_plan set default 'free';
alter table public.landlord_subscriptions alter column property_limit set default 1;
alter table public.landlord_subscriptions alter column unit_limit set default 1;
alter table public.landlord_subscriptions alter column personal_staff_limit set default 0;
alter table public.landlord_subscriptions alter column partner_connection_limit set default 1;
alter table public.landlord_subscriptions alter column status set default 'active';
alter table public.landlord_subscriptions alter column expires_at set default '2099-12-31 23:59:59+00';
do $$
begin
  alter table public.landlord_subscriptions drop constraint if exists landlord_subscriptions_property_limit_check;
  alter table public.landlord_subscriptions add constraint landlord_subscriptions_property_limit_check check (property_limit >= 0);
  alter table public.landlord_subscriptions drop constraint if exists landlord_subscriptions_unit_limit_check;
  alter table public.landlord_subscriptions add constraint landlord_subscriptions_unit_limit_check check (unit_limit >= 0);
  alter table public.landlord_subscriptions drop constraint if exists landlord_subscriptions_personal_staff_limit_check;
  alter table public.landlord_subscriptions add constraint landlord_subscriptions_personal_staff_limit_check check (personal_staff_limit >= 0);
  alter table public.landlord_subscriptions drop constraint if exists landlord_subscriptions_partner_connection_limit_check;
  alter table public.landlord_subscriptions add constraint landlord_subscriptions_partner_connection_limit_check check (partner_connection_limit >= 0);
  alter table public.landlord_subscriptions drop constraint if exists landlord_subscriptions_plan_check;
  alter table public.landlord_subscriptions add constraint landlord_subscriptions_plan_check check (subscription_plan in ('free', 'starter', 'growth', 'portfolio', 'standard', 'custom'));
end $$;
create index if not exists landlord_subscriptions_country_id_idx on public.landlord_subscriptions (country_id);

create table if not exists public.landlord_subscription_admin_notes (
  landlord_id uuid primary key references public.profiles(id) on delete cascade,
  notes text not null default '',
  updated_by uuid null references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.admin_notes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  visibility text not null default 'personal',
  assigned_to uuid null references public.profiles(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'open',
  due_date date,
  completed_at timestamptz,
  completed_by uuid null references public.profiles(id) on delete set null,
  updated_by uuid null references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.admin_notes add column if not exists title text not null default '';
alter table public.admin_notes add column if not exists body text not null default '';
alter table public.admin_notes add column if not exists visibility text not null default 'personal';
alter table public.admin_notes add column if not exists assigned_to uuid null references public.profiles(id) on delete set null;
alter table public.admin_notes add column if not exists created_by uuid references public.profiles(id) on delete cascade;
alter table public.admin_notes add column if not exists status text not null default 'open';
alter table public.admin_notes add column if not exists due_date date;
alter table public.admin_notes add column if not exists completed_at timestamptz;
alter table public.admin_notes add column if not exists completed_by uuid null references public.profiles(id) on delete set null;
alter table public.admin_notes add column if not exists updated_by uuid null references public.profiles(id) on delete set null;
alter table public.admin_notes add column if not exists updated_at timestamptz not null default now();
alter table public.admin_notes add column if not exists created_at timestamptz not null default now();

do $$
begin
  alter table public.admin_notes drop constraint if exists admin_notes_visibility_check;
  alter table public.admin_notes add constraint admin_notes_visibility_check check (visibility in ('personal', 'assigned'));
  alter table public.admin_notes drop constraint if exists admin_notes_status_check;
  alter table public.admin_notes add constraint admin_notes_status_check check (status in ('open', 'done'));
  alter table public.admin_notes drop constraint if exists admin_notes_assigned_visibility_check;
  alter table public.admin_notes add constraint admin_notes_assigned_visibility_check check (
    (visibility = 'personal' and assigned_to is null)
    or (visibility = 'assigned' and assigned_to is not null)
  );
end $$;

create index if not exists admin_notes_created_by_idx on public.admin_notes (created_by);
create index if not exists admin_notes_assigned_to_idx on public.admin_notes (assigned_to);
create index if not exists admin_notes_status_idx on public.admin_notes (status);

create table if not exists public.admin_staff_country_assignments (
  staff_profile_id uuid not null references public.profiles(id) on delete cascade,
  country_id uuid not null references public.countries(id) on delete cascade,
  assigned_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (staff_profile_id, country_id)
);

create index if not exists admin_staff_country_assignments_country_id_idx
  on public.admin_staff_country_assignments (country_id);

create table if not exists public.platform_payments (
  id uuid primary key default gen_random_uuid(),
  payer_type text not null default 'landlord' check (payer_type in ('landlord', 'staff', 'management')),
  landlord_id uuid null references public.profiles(id) on delete set null,
  staff_id uuid null references public.profiles(id) on delete set null,
  management_company_id uuid null,
  country_id uuid null references public.countries(id) on delete set null,
  amount_paid numeric(12,2) not null check (amount_paid > 0),
  paid_at date not null default current_date,
  period_start date not null,
  period_end date not null,
  payment_for text not null default 'subscription',
  pricing_plan_id uuid null references public.pricing_plans(id) on delete set null,
  plan_key text,
  plan_name text,
  billing_cycle text,
  notes text,
  recorded_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint platform_payments_payer_check check (
    (payer_type = 'landlord' and landlord_id is not null and staff_id is null and management_company_id is null)
    or (payer_type = 'staff' and staff_id is not null and landlord_id is null and management_company_id is null)
    or (payer_type = 'management' and management_company_id is not null and landlord_id is null and staff_id is null)
  ),
  constraint platform_payments_period_check check (period_end >= period_start)
);

create index if not exists platform_payments_landlord_id_idx on public.platform_payments (landlord_id);
create index if not exists platform_payments_paid_at_idx on public.platform_payments (paid_at desc);
alter table public.platform_payments add column if not exists payer_type text not null default 'landlord';
alter table public.platform_payments add column if not exists staff_id uuid null references public.profiles(id) on delete set null;
alter table public.platform_payments add column if not exists management_company_id uuid null;
alter table public.platform_payments alter column landlord_id drop not null;
alter table public.platform_payments add column if not exists country_id uuid null references public.countries(id) on delete set null;
alter table public.platform_payments add column if not exists payment_for text not null default 'subscription';
alter table public.platform_payments add column if not exists pricing_plan_id uuid null references public.pricing_plans(id) on delete set null;
alter table public.platform_payments add column if not exists plan_key text;
alter table public.platform_payments add column if not exists plan_name text;
alter table public.platform_payments add column if not exists billing_cycle text;
create index if not exists platform_payments_staff_id_idx on public.platform_payments (staff_id);
create index if not exists platform_payments_management_company_id_idx on public.platform_payments (management_company_id);
create index if not exists platform_payments_pricing_plan_id_idx on public.platform_payments (pricing_plan_id);
do $$
begin
  alter table public.platform_payments drop constraint if exists platform_payments_payer_type_check;
  alter table public.platform_payments add constraint platform_payments_payer_type_check check (payer_type in ('landlord', 'staff', 'management'));
  alter table public.platform_payments drop constraint if exists platform_payments_payment_for_check;
  alter table public.platform_payments add constraint platform_payments_payment_for_check check (payment_for in ('subscription'));
  alter table public.platform_payments drop constraint if exists platform_payments_billing_cycle_check;
  alter table public.platform_payments add constraint platform_payments_billing_cycle_check check (billing_cycle is null or billing_cycle in ('monthly', 'yearly'));
  alter table public.platform_payments drop constraint if exists platform_payments_payer_check;
  alter table public.platform_payments add constraint platform_payments_payer_check check (
    (payer_type = 'landlord' and landlord_id is not null and staff_id is null and management_company_id is null)
    or (payer_type = 'staff' and staff_id is not null and landlord_id is null and management_company_id is null)
    or (payer_type = 'management' and management_company_id is not null and landlord_id is null and staff_id is null)
  );
  alter table public.platform_payments drop constraint if exists platform_payments_landlord_id_fkey;
  alter table public.platform_payments add constraint platform_payments_landlord_id_fkey foreign key (landlord_id) references public.profiles(id) on delete set null;
exception when duplicate_object then null;
end $$;
create index if not exists platform_payments_country_id_idx on public.platform_payments (country_id);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  address text not null,
  city text not null,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid null references public.profiles(id) on delete set null
);

create index if not exists properties_landlord_id_idx on public.properties (landlord_id);
alter table public.properties add column if not exists archived_at timestamptz;
alter table public.properties add column if not exists archived_by uuid null references public.profiles(id) on delete set null;

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  unit_number text not null,
  bedrooms numeric(4,1) not null default 0,
  bathrooms numeric(4,1) not null default 0,
  monthly_rent numeric(12,2) not null check (monthly_rent >= 0),
  status public.unit_status not null default 'vacant',
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid null references public.profiles(id) on delete set null,
  unique (property_id, unit_number)
);

create index if not exists units_property_id_idx on public.units (property_id);
alter table public.units add column if not exists archived_at timestamptz;
alter table public.units add column if not exists archived_by uuid null references public.profiles(id) on delete set null;

create table if not exists public.staff_permissions (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  staff_profile_id uuid not null references public.profiles(id) on delete cascade,
  all_properties boolean not null default false,
  property_ids uuid[] not null default '{}'::uuid[],
  can_view_properties boolean not null default true,
  can_add_properties boolean not null default false,
  can_edit_properties boolean not null default false,
  can_archive_properties boolean not null default false,
  can_view_units boolean not null default false,
  can_add_units boolean not null default false,
  can_edit_units boolean not null default false,
  can_archive_units boolean not null default false,
  can_mark_units_vacant boolean not null default false,
  can_add_tenants boolean not null default false,
  can_edit_tenants boolean not null default false,
  can_archive_tenants boolean not null default false,
  can_view_leases boolean not null default false,
  can_create_leases boolean not null default false,
  can_edit_leases boolean not null default false,
  can_terminate_leases boolean not null default false,
  can_view_lease_documents boolean not null default false,
  can_upload_lease_documents boolean not null default false,
  can_log_payments boolean not null default false,
  can_reject_payments boolean not null default false,
  can_view_payment_proofs boolean not null default false,
  can_create_maintenance boolean not null default false,
  can_assign_maintenance boolean not null default false,
  can_add_resolution_notes boolean not null default false,
  can_manage_staff boolean not null default false,
  can_view_finance boolean not null default false,
  can_view_tenants boolean not null default false,
  can_manage_maintenance boolean not null default false,
  can_view_payments boolean not null default false,
  can_verify_payments boolean not null default false,
  can_manage_leases boolean not null default false,
  invited_at timestamptz not null default now(),
  accepted_at timestamptz,
  contract_start_date date,
  contract_end_date date,
  status text not null default 'approved' check (status in ('pending', 'approved', 'rejected', 'suspended')),
  unique (landlord_id, staff_profile_id)
);

create index if not exists staff_permissions_landlord_id_idx on public.staff_permissions (landlord_id);
create index if not exists staff_permissions_staff_profile_id_idx on public.staff_permissions (staff_profile_id);
alter table public.staff_permissions add column if not exists can_view_properties boolean not null default true;
alter table public.staff_permissions add column if not exists can_add_properties boolean not null default false;
alter table public.staff_permissions add column if not exists can_edit_properties boolean not null default false;
alter table public.staff_permissions add column if not exists can_archive_properties boolean not null default false;
alter table public.staff_permissions add column if not exists can_view_units boolean not null default false;
alter table public.staff_permissions add column if not exists can_add_units boolean not null default false;
alter table public.staff_permissions add column if not exists can_edit_units boolean not null default false;
alter table public.staff_permissions add column if not exists can_archive_units boolean not null default false;
alter table public.staff_permissions add column if not exists can_mark_units_vacant boolean not null default false;
alter table public.staff_permissions alter column can_view_units set default false;
alter table public.staff_permissions add column if not exists can_add_tenants boolean not null default false;
alter table public.staff_permissions add column if not exists can_edit_tenants boolean not null default false;
alter table public.staff_permissions add column if not exists can_archive_tenants boolean not null default false;
alter table public.staff_permissions add column if not exists can_view_leases boolean not null default false;
alter table public.staff_permissions add column if not exists can_create_leases boolean not null default false;
alter table public.staff_permissions add column if not exists can_edit_leases boolean not null default false;
alter table public.staff_permissions add column if not exists can_terminate_leases boolean not null default false;
alter table public.staff_permissions add column if not exists can_view_lease_documents boolean not null default false;
alter table public.staff_permissions add column if not exists can_upload_lease_documents boolean not null default false;
alter table public.staff_permissions add column if not exists can_log_payments boolean not null default false;
alter table public.staff_permissions add column if not exists can_reject_payments boolean not null default false;
alter table public.staff_permissions add column if not exists can_view_payment_proofs boolean not null default false;
alter table public.staff_permissions add column if not exists can_create_maintenance boolean not null default false;
alter table public.staff_permissions add column if not exists can_assign_maintenance boolean not null default false;
alter table public.staff_permissions add column if not exists can_add_resolution_notes boolean not null default false;
alter table public.staff_permissions add column if not exists can_manage_staff boolean not null default false;
alter table public.staff_permissions add column if not exists can_view_finance boolean not null default false;
alter table public.staff_permissions add column if not exists status text not null default 'approved';
alter table public.staff_permissions add column if not exists contract_start_date date;
alter table public.staff_permissions add column if not exists contract_end_date date;
do $$
begin
  alter table public.staff_permissions drop constraint if exists staff_permissions_staff_profile_id_key;
  alter table public.staff_permissions drop constraint if exists staff_permissions_landlord_staff_unique;
  alter table public.staff_permissions add constraint staff_permissions_landlord_staff_unique unique (landlord_id, staff_profile_id);
  alter table public.staff_permissions drop constraint if exists staff_permissions_status_check;
  alter table public.staff_permissions add constraint staff_permissions_status_check check (status in ('pending', 'approved', 'rejected', 'suspended'));
end $$;

create table if not exists public.staff_landlord_requests (
  id uuid primary key default gen_random_uuid(),
  staff_profile_id uuid not null references public.profiles(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  landlord_code text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid null references public.profiles(id) on delete set null,
  notes text,
  unique (staff_profile_id, landlord_id, status)
);

create index if not exists staff_landlord_requests_staff_idx on public.staff_landlord_requests (staff_profile_id);
create index if not exists staff_landlord_requests_landlord_idx on public.staff_landlord_requests (landlord_id);

create table if not exists public.management_companies (
  id uuid primary key default gen_random_uuid(),
  leader_profile_id uuid not null unique references public.profiles(id) on delete cascade,
  country_id uuid null references public.countries(id) on delete set null,
  company_name text not null,
  phone text,
  max_landlords integer not null default 2 check (max_landlords >= 0),
  max_properties integer not null default 10 check (max_properties >= 0),
  max_staff integer not null default 3 check (max_staff >= 0),
  subscription_status text not null default 'trial' check (subscription_status in ('trial', 'active', 'suspended')),
  subscription_expires_at date,
  access_suspended_at timestamptz,
  access_suspended_by uuid null references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid null references public.profiles(id) on delete set null
);

create index if not exists management_companies_country_idx on public.management_companies (country_id);
create index if not exists management_companies_status_idx on public.management_companies (subscription_status);
alter table public.management_companies add column if not exists max_landlords integer not null default 2;
alter table public.management_companies add column if not exists max_properties integer not null default 10;
alter table public.management_companies add column if not exists max_staff integer not null default 3;
alter table public.management_companies add column if not exists subscription_status text not null default 'trial';
alter table public.management_companies add column if not exists subscription_expires_at date;
alter table public.management_companies add column if not exists access_suspended_at timestamptz;
alter table public.management_companies add column if not exists access_suspended_by uuid null references public.profiles(id) on delete set null;
alter table public.management_companies add column if not exists archived_at timestamptz;
alter table public.management_companies add column if not exists archived_by uuid null references public.profiles(id) on delete set null;

do $$
begin
  alter table public.management_companies drop constraint if exists management_companies_max_landlords_check;
  alter table public.management_companies add constraint management_companies_max_landlords_check check (max_landlords >= 0);
  alter table public.management_companies drop constraint if exists management_companies_max_properties_check;
  alter table public.management_companies add constraint management_companies_max_properties_check check (max_properties >= 0);
  alter table public.management_companies drop constraint if exists management_companies_max_staff_check;
  alter table public.management_companies add constraint management_companies_max_staff_check check (max_staff >= 0);
  alter table public.management_companies drop constraint if exists management_companies_subscription_status_check;
  alter table public.management_companies add constraint management_companies_subscription_status_check check (subscription_status in ('trial', 'active', 'suspended'));
end $$;

do $$
begin
  alter table public.platform_payments drop constraint if exists platform_payments_management_company_id_fkey;
  alter table public.platform_payments add constraint platform_payments_management_company_id_fkey foreign key (management_company_id) references public.management_companies(id) on delete set null;
exception when duplicate_object then null;
end $$;

create table if not exists public.management_landlord_requests (
  id uuid primary key default gen_random_uuid(),
  management_company_id uuid not null references public.management_companies(id) on delete cascade,
  leader_profile_id uuid not null references public.profiles(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  landlord_code text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid null references public.profiles(id) on delete set null,
  notes text
);

create index if not exists management_landlord_requests_company_idx on public.management_landlord_requests (management_company_id);
create index if not exists management_landlord_requests_leader_idx on public.management_landlord_requests (leader_profile_id);
create index if not exists management_landlord_requests_landlord_idx on public.management_landlord_requests (landlord_id);
do $$
begin
  alter table public.management_landlord_requests drop constraint if exists management_landlord_requests_management_company_id_landlord_key;
  alter table public.management_landlord_requests drop constraint if exists management_landlord_requests_management_company_id_landlord_id_key;
  alter table public.management_landlord_requests drop constraint if exists management_landlord_requests_management_company_id_landlord_id_status_key;
end $$;
drop index if exists public.management_landlord_requests_management_company_id_landlord_key;
drop index if exists public.management_landlord_requests_management_company_id_landlord_id_key;
drop index if exists public.management_landlord_requests_management_company_id_landlord_id_status_key;
create unique index if not exists management_landlord_requests_pending_unique
on public.management_landlord_requests (management_company_id, landlord_id)
where status = 'pending';

create table if not exists public.management_landlord_permissions (
  id uuid primary key default gen_random_uuid(),
  management_company_id uuid not null references public.management_companies(id) on delete cascade,
  leader_profile_id uuid not null references public.profiles(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  all_properties boolean not null default false,
  property_ids uuid[] not null default '{}'::uuid[],
  can_view_properties boolean not null default true,
  can_add_properties boolean not null default false,
  can_edit_properties boolean not null default false,
  can_archive_properties boolean not null default false,
  can_view_units boolean not null default false,
  can_add_units boolean not null default false,
  can_edit_units boolean not null default false,
  can_archive_units boolean not null default false,
  can_mark_units_vacant boolean not null default false,
  can_view_tenants boolean not null default false,
  can_add_tenants boolean not null default false,
  can_edit_tenants boolean not null default false,
  can_archive_tenants boolean not null default false,
  can_view_leases boolean not null default false,
  can_create_leases boolean not null default false,
  can_edit_leases boolean not null default false,
  can_terminate_leases boolean not null default false,
  can_view_lease_documents boolean not null default false,
  can_upload_lease_documents boolean not null default false,
  can_manage_leases boolean not null default false,
  can_view_payments boolean not null default false,
  can_log_payments boolean not null default false,
  can_reject_payments boolean not null default false,
  can_view_payment_proofs boolean not null default false,
  can_verify_payments boolean not null default false,
  can_manage_maintenance boolean not null default false,
  can_create_maintenance boolean not null default false,
  can_assign_maintenance boolean not null default false,
  can_add_resolution_notes boolean not null default false,
  can_manage_staff boolean not null default true,
  can_view_finance boolean not null default false,
  contract_start_date date,
  contract_end_date date,
  accepted_at timestamptz not null default now(),
  status text not null default 'approved' check (status in ('approved', 'suspended')),
  unique (management_company_id, landlord_id)
);

create index if not exists management_permissions_company_idx on public.management_landlord_permissions (management_company_id);
create index if not exists management_permissions_leader_idx on public.management_landlord_permissions (leader_profile_id);
create index if not exists management_permissions_landlord_idx on public.management_landlord_permissions (landlord_id);
alter table public.management_landlord_permissions add column if not exists contract_start_date date;
alter table public.management_landlord_permissions add column if not exists contract_end_date date;

create table if not exists public.partner_payments (
  id uuid primary key default gen_random_uuid(),
  partner_type text not null check (partner_type in ('ipm', 'pmc')),
  partner_staff_id uuid null references public.profiles(id) on delete set null,
  management_company_id uuid null references public.management_companies(id) on delete set null,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  amount_paid numeric(12,2) not null check (amount_paid > 0),
  paid_at date not null default current_date,
  period_start date not null,
  period_end date not null,
  notes text,
  recorded_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint partner_payments_partner_check check (
    (partner_type = 'ipm' and partner_staff_id is not null and management_company_id is null)
    or (partner_type = 'pmc' and management_company_id is not null and partner_staff_id is null)
  ),
  constraint partner_payments_period_check check (period_end >= period_start)
);

create index if not exists partner_payments_partner_staff_idx on public.partner_payments (partner_staff_id);
create index if not exists partner_payments_management_company_idx on public.partner_payments (management_company_id);
create index if not exists partner_payments_landlord_idx on public.partner_payments (landlord_id);
create index if not exists partner_payments_paid_at_idx on public.partner_payments (paid_at desc);

create table if not exists public.partner_reconciliations (
  id uuid primary key default gen_random_uuid(),
  partner_type text not null check (partner_type in ('ipm', 'pmc')),
  partner_staff_id uuid null references public.profiles(id) on delete set null,
  management_company_id uuid null references public.management_companies(id) on delete set null,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  gross_collected numeric(12,2) not null default 0 check (gross_collected >= 0),
  management_fee numeric(12,2) not null default 0 check (management_fee >= 0),
  expenses numeric(12,2) not null default 0 check (expenses >= 0),
  owner_distribution numeric(12,2) not null default 0 check (owner_distribution >= 0),
  status text not null default 'sent_for_approval' check (status in ('draft', 'sent_for_approval', 'approved', 'rejected', 'paid')),
  notes text,
  submitted_by uuid null references public.profiles(id) on delete set null,
  reviewed_by uuid null references public.profiles(id) on delete set null,
  submitted_at timestamptz not null default now(),
  approved_at timestamptz,
  rejected_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint partner_reconciliations_partner_check check (
    (partner_type = 'ipm' and partner_staff_id is not null and management_company_id is null)
    or (partner_type = 'pmc' and management_company_id is not null and partner_staff_id is null)
  ),
  constraint partner_reconciliations_period_check check (period_end >= period_start)
);

create index if not exists partner_reconciliations_partner_staff_idx on public.partner_reconciliations (partner_staff_id);
create index if not exists partner_reconciliations_management_company_idx on public.partner_reconciliations (management_company_id);
create index if not exists partner_reconciliations_landlord_idx on public.partner_reconciliations (landlord_id);
create index if not exists partner_reconciliations_status_idx on public.partner_reconciliations (status);
create index if not exists partner_reconciliations_period_idx on public.partner_reconciliations (period_end desc);

create table if not exists public.management_staff_permissions (
  id uuid primary key default gen_random_uuid(),
  management_company_id uuid not null references public.management_companies(id) on delete cascade,
  staff_profile_id uuid not null references public.profiles(id) on delete cascade,
  all_properties boolean not null default false,
  property_ids uuid[] not null default '{}'::uuid[],
  can_view_properties boolean not null default true,
  can_add_properties boolean not null default false,
  can_edit_properties boolean not null default false,
  can_archive_properties boolean not null default false,
  can_view_units boolean not null default false,
  can_add_units boolean not null default false,
  can_edit_units boolean not null default false,
  can_archive_units boolean not null default false,
  can_mark_units_vacant boolean not null default false,
  can_view_tenants boolean not null default false,
  can_add_tenants boolean not null default false,
  can_edit_tenants boolean not null default false,
  can_archive_tenants boolean not null default false,
  can_view_leases boolean not null default false,
  can_create_leases boolean not null default false,
  can_edit_leases boolean not null default false,
  can_terminate_leases boolean not null default false,
  can_view_lease_documents boolean not null default false,
  can_upload_lease_documents boolean not null default false,
  can_manage_leases boolean not null default false,
  can_view_payments boolean not null default false,
  can_log_payments boolean not null default false,
  can_reject_payments boolean not null default false,
  can_view_payment_proofs boolean not null default false,
  can_verify_payments boolean not null default false,
  can_manage_maintenance boolean not null default false,
  can_create_maintenance boolean not null default false,
  can_assign_maintenance boolean not null default false,
  can_add_resolution_notes boolean not null default false,
  can_manage_staff boolean not null default false,
  can_view_finance boolean not null default false,
  invited_at timestamptz not null default now(),
  accepted_at timestamptz,
  status text not null default 'approved' check (status in ('pending', 'approved', 'rejected', 'suspended')),
  unique (management_company_id, staff_profile_id)
);

create index if not exists management_staff_permissions_company_idx on public.management_staff_permissions (management_company_id);
create index if not exists management_staff_permissions_staff_idx on public.management_staff_permissions (staff_profile_id);
alter table public.management_staff_permissions add column if not exists can_manage_staff boolean not null default false;
alter table public.management_staff_permissions add column if not exists can_manage_leases boolean not null default false;
alter table public.management_landlord_permissions add column if not exists can_archive_units boolean not null default false;
alter table public.management_landlord_permissions alter column can_view_units set default false;
alter table public.management_staff_permissions add column if not exists can_archive_units boolean not null default false;
alter table public.management_staff_permissions alter column can_view_units set default false;

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid null references public.profiles(id) on delete cascade,
  profile_id uuid null references public.profiles(id) on delete set null,
  country_id uuid null references public.countries(id) on delete set null,
  full_name text not null,
  phone text,
  email text not null,
  id_number text,
  invite_token text,
  invite_accepted boolean not null default false,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid null references public.profiles(id) on delete set null
);

create index if not exists tenants_landlord_id_idx on public.tenants (landlord_id);
create index if not exists tenants_profile_id_idx on public.tenants (profile_id);
create index if not exists tenants_email_idx on public.tenants (lower(email));
alter table public.tenants alter column landlord_id drop not null;
alter table public.tenants add column if not exists country_id uuid null references public.countries(id) on delete set null;
alter table public.tenants add column if not exists archived_at timestamptz;
alter table public.tenants add column if not exists archived_by uuid null references public.profiles(id) on delete set null;
create index if not exists tenants_country_id_idx on public.tenants (country_id);

create or replace function public.signup_identity_exists(
  p_email text default '',
  p_phone text default ''
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  normalized_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if normalized_email <> '' and exists (
    select 1
    from auth.users u
    where lower(coalesce(u.email, '')) = normalized_email
  ) then
    return true;
  end if;

  if normalized_email <> '' and exists (
    select 1
    from public.profiles p
    where lower(coalesce(p.email, '')) = normalized_email
  ) then
    return true;
  end if;

  if normalized_email <> '' and exists (
    select 1
    from public.tenants t
    where lower(coalesce(t.email, '')) = normalized_email
  ) then
    return true;
  end if;

  if normalized_email <> '' and exists (
    select 1
    from public.invite_tokens it
    where lower(it.email) = normalized_email
      and it.used = false
      and it.expires_at > now()
  ) then
    return true;
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from auth.users u
    where regexp_replace(coalesce(u.raw_user_meta_data ->> 'phone', ''), '\D', '', 'g') = normalized_phone
  ) then
    return true;
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from public.profiles p
    where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') = normalized_phone
  ) then
    return true;
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from public.tenants t
    where regexp_replace(coalesce(t.phone, ''), '\D', '', 'g') = normalized_phone
  ) then
    return true;
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from public.invite_tokens it
    where regexp_replace(coalesce(it.metadata ->> 'phone', ''), '\D', '', 'g') = normalized_phone
      and it.used = false
      and it.expires_at > now()
  ) then
    return true;
  end if;

  return false;
end;
$$;

drop function if exists public.tenant_signup_identity_exists(text, text, text);

create or replace function public.tenant_signup_identity_exists(
  p_email text default '',
  p_phone text default '',
  p_id_number text default ''
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  normalized_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  normalized_id text := lower(trim(coalesce(p_id_number, '')));
begin
  if normalized_email <> '' and exists (
    select 1
    from auth.users u
    where lower(coalesce(u.email, '')) = normalized_email
  ) then
    return true;
  end if;

  if normalized_email <> '' and exists (
    select 1
    from public.profiles p
    where lower(coalesce(p.email, '')) = normalized_email
  ) then
    return true;
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from auth.users u
    where regexp_replace(coalesce(u.raw_user_meta_data ->> 'phone', ''), '\D', '', 'g') = normalized_phone
  ) then
    return true;
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from public.profiles p
    where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') = normalized_phone
  ) then
    return true;
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from public.tenants t
    where t.profile_id is not null
      and regexp_replace(coalesce(t.phone, ''), '\D', '', 'g') = normalized_phone
  ) then
    return true;
  end if;

  if normalized_id <> '' and exists (
    select 1
    from public.tenants t
    where t.profile_id is not null
      and lower(trim(coalesce(t.id_number, ''))) = normalized_id
  ) then
    return true;
  end if;

  return false;
end;
$$;

drop function if exists public.register_tenant_account(text, text, text);
drop function if exists public.register_tenant_account(text, text, text, uuid);

create or replace function public.register_tenant_account(
  p_full_name text,
  p_phone text,
  p_id_number text,
  p_country_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  user_id uuid := auth.uid();
  user_email text;
  normalized_email text;
  normalized_name text := trim(coalesce(p_full_name, ''));
  normalized_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  raw_phone text := trim(coalesce(p_phone, ''));
  normalized_id text := lower(trim(coalesce(p_id_number, '')));
  tenant_id uuid;
begin
  if user_id is null then
    raise exception 'You must be signed in to create a tenant account.';
  end if;

  select lower(coalesce(u.email, ''))
  into user_email
  from auth.users u
  where u.id = user_id;

  normalized_email := lower(trim(coalesce(user_email, '')));

  if normalized_name = '' or normalized_email = '' or length(normalized_phone) < 6 or normalized_id = '' or p_country_id is null then
    raise exception 'Name, country, email, phone number, and national ID number are required.';
  end if;

  if not exists (
    select 1
    from public.countries c
    where c.id = p_country_id
      and c.archived_at is null
  ) then
    raise exception 'Select a valid country before creating the tenant account.';
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id <> user_id
      and lower(coalesce(p.email, '')) = normalized_email
  ) then
    raise exception 'Your account already exists. Please contact Mushavo support.';
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id <> user_id
      and regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') = normalized_phone
  ) then
    raise exception 'Your account already exists. Please contact Mushavo support.';
  end if;

  if exists (
    select 1
    from public.tenants t
    where t.profile_id is not null
      and t.profile_id <> user_id
      and lower(coalesce(t.email, '')) = normalized_email
  ) then
    raise exception 'Your account already exists. Please contact Mushavo support.';
  end if;

  if exists (
    select 1
    from public.tenants t
    where t.profile_id is not null
      and t.profile_id <> user_id
      and regexp_replace(coalesce(t.phone, ''), '\D', '', 'g') = normalized_phone
  ) then
    raise exception 'Your account already exists. Please contact Mushavo support.';
  end if;

  if exists (
    select 1
    from public.tenants t
    where t.profile_id is not null
      and t.profile_id <> user_id
      and lower(trim(coalesce(t.id_number, ''))) = normalized_id
  ) then
    raise exception 'Your account already exists. Please contact Mushavo support.';
  end if;

  insert into public.profiles (
    id,
    landlord_id,
    full_name,
    phone,
    email,
    role,
    country_id
  )
  values (
    user_id,
    null,
    normalized_name,
    raw_phone,
    normalized_email,
    'tenant',
    p_country_id
  )
  on conflict (id) do update
  set full_name = excluded.full_name,
      phone = excluded.phone,
      email = excluded.email,
      role = 'tenant',
      country_id = excluded.country_id,
      landlord_id = null,
      archived_at = null,
      archived_by = null;

  perform set_config('request.mushavo_tenant_self_write', 'true', true);

  select t.id
  into tenant_id
  from public.tenants t
  where t.profile_id = user_id
    and t.landlord_id is null
    and t.archived_at is null
  order by t.created_at desc
  limit 1;

  if tenant_id is null then
    insert into public.tenants (
      landlord_id,
      profile_id,
      full_name,
      phone,
      email,
      id_number,
      country_id,
      invite_accepted
    )
    values (
      null,
      user_id,
      normalized_name,
      raw_phone,
      normalized_email,
      p_id_number,
      p_country_id,
      true
    )
    returning id into tenant_id;
  else
    update public.tenants
    set full_name = normalized_name,
        phone = raw_phone,
        email = normalized_email,
        id_number = p_id_number,
        country_id = p_country_id,
        invite_accepted = true
    where id = tenant_id;
  end if;

  return tenant_id;
end;
$$;

create or replace function public.enforce_active_tenant_relationship_unique()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.landlord_id is not null and new.archived_at is null and exists (
    select 1
    from public.tenants t
    where t.landlord_id = new.landlord_id
      and lower(t.email) = lower(new.email)
      and t.archived_at is null
      and t.id <> new.id
  ) then
    raise exception 'This tenant already has an active record with this landlord.';
  end if;

  return new;
end;
$$;

drop trigger if exists tenants_enforce_active_relationship_unique on public.tenants;
create trigger tenants_enforce_active_relationship_unique
before insert or update of landlord_id, email, archived_at on public.tenants
for each row execute function public.enforce_active_tenant_relationship_unique();

create table if not exists public.leases (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  monthly_rent numeric(12,2) not null check (monthly_rent >= 0),
  deposit_amount numeric(12,2) not null default 0 check (deposit_amount >= 0),
  deposit_paid boolean not null default false,
  lease_document_url text,
  lease_document_path text,
  lease_document_name text,
  lease_document_size integer,
  lease_document_uploaded_by uuid null references public.profiles(id) on delete set null,
  lease_document_uploaded_at timestamptz,
  status public.lease_status not null default 'active',
  created_at timestamptz not null default now(),
  constraint leases_date_check check (end_date >= start_date)
);

create index if not exists leases_landlord_id_idx on public.leases (landlord_id);
create index if not exists leases_unit_id_idx on public.leases (unit_id);
create index if not exists leases_tenant_id_idx on public.leases (tenant_id);
create unique index if not exists leases_one_active_per_unit_idx
  on public.leases (unit_id)
  where status = 'active';

alter table public.leases add column if not exists lease_document_path text;
alter table public.leases add column if not exists lease_document_name text;
alter table public.leases add column if not exists lease_document_size integer;
alter table public.leases add column if not exists lease_document_uploaded_by uuid null references public.profiles(id) on delete set null;
alter table public.leases add column if not exists lease_document_uploaded_at timestamptz;
do $$
begin
  alter table public.leases
    add constraint leases_document_size_check
    check (lease_document_size is null or lease_document_size > 0);
exception when duplicate_object then null;
end $$;

create table if not exists public.payment_submissions (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references public.leases(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  amount_claimed numeric(12,2) not null check (amount_claimed > 0),
  payment_date date not null,
  payment_method public.payment_method not null,
  rent_period_start date,
  rent_period_end date,
  rent_period_label text,
  payment_purpose text not null default 'rent',
  purpose_description text,
  is_historical boolean not null default false,
  reference_note text,
  proof_image_url text,
  proof_image_path text,
  proof_image_name text,
  proof_image_size integer,
  proof_image_uploaded_by uuid null references public.profiles(id) on delete set null,
  proof_image_uploaded_at timestamptz,
  status public.submission_status not null default 'pending',
  rejection_reason text,
  reviewed_by uuid null references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists payment_submissions_lease_id_idx on public.payment_submissions (lease_id);
create index if not exists payment_submissions_tenant_id_idx on public.payment_submissions (tenant_id);
create index if not exists payment_submissions_status_idx on public.payment_submissions (status);

alter table public.payment_submissions add column if not exists proof_image_path text;
alter table public.payment_submissions add column if not exists proof_image_name text;
alter table public.payment_submissions add column if not exists proof_image_size integer;
alter table public.payment_submissions add column if not exists proof_image_uploaded_by uuid null references public.profiles(id) on delete set null;
alter table public.payment_submissions add column if not exists proof_image_uploaded_at timestamptz;
alter table public.payment_submissions add column if not exists rent_period_start date;
alter table public.payment_submissions add column if not exists rent_period_end date;
alter table public.payment_submissions add column if not exists rent_period_label text;
alter table public.payment_submissions add column if not exists payment_purpose text not null default 'rent';
alter table public.payment_submissions add column if not exists purpose_description text;
alter table public.payment_submissions add column if not exists is_historical boolean not null default false;
do $$
begin
  alter table public.payment_submissions
    add constraint payment_submissions_proof_image_size_check
    check (proof_image_size is null or proof_image_size > 0);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table public.payment_submissions
    add constraint payment_submissions_rent_period_check
    check (rent_period_end is null or rent_period_start is null or rent_period_end >= rent_period_start);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table public.payment_submissions
    add constraint payment_submissions_payment_purpose_check
    check (payment_purpose in ('rent', 'deposit', 'maintenance', 'other'));
exception when duplicate_object then null;
end $$;

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references public.leases(id) on delete cascade,
  submission_id uuid null references public.payment_submissions(id) on delete set null,
  amount_paid numeric(12,2) not null check (amount_paid > 0),
  payment_date date not null,
  payment_method public.payment_method not null,
  rent_period_start date,
  rent_period_end date,
  rent_period_label text,
  payment_purpose text not null default 'rent',
  purpose_description text,
  is_historical boolean not null default false,
  notes text,
  receipt_number text unique,
  proof_file_path text,
  proof_file_name text,
  proof_file_size integer,
  proof_file_uploaded_by uuid null references public.profiles(id) on delete set null,
  proof_file_uploaded_at timestamptz,
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create index if not exists payments_lease_id_idx on public.payments (lease_id);
create index if not exists payments_submission_id_idx on public.payments (submission_id);
alter table public.payments add column if not exists proof_file_path text;
alter table public.payments add column if not exists proof_file_name text;
alter table public.payments add column if not exists proof_file_size integer;
alter table public.payments add column if not exists proof_file_uploaded_by uuid null references public.profiles(id) on delete set null;
alter table public.payments add column if not exists proof_file_uploaded_at timestamptz;
alter table public.payments add column if not exists rent_period_start date;
alter table public.payments add column if not exists rent_period_end date;
alter table public.payments add column if not exists rent_period_label text;
alter table public.payments add column if not exists payment_purpose text not null default 'rent';
alter table public.payments add column if not exists purpose_description text;
alter table public.payments add column if not exists is_historical boolean not null default false;
do $$
begin
  alter table public.payments
    add constraint payments_proof_file_size_check
    check (proof_file_size is null or proof_file_size > 0);
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table public.payments
    add constraint payments_payment_purpose_check
    check (payment_purpose in ('rent', 'deposit', 'maintenance', 'other'));
exception when duplicate_object then null;
end $$;
do $$
begin
  alter table public.payments
    add constraint payments_rent_period_check
    check (rent_period_end is null or rent_period_start is null or rent_period_end >= rent_period_start);
exception when duplicate_object then null;
end $$;

create table if not exists public.lease_charges (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references public.leases(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  charge_type text not null default 'rent',
  charge_status text not null default 'open',
  due_date date not null,
  period_start date,
  period_end date,
  description text,
  amount numeric(12,2) not null check (amount > 0),
  amount_paid numeric(12,2) not null default 0 check (amount_paid >= 0),
  created_by uuid null references public.profiles(id) on delete set null,
  voided_by uuid null references public.profiles(id) on delete set null,
  voided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lease_charges_type_check check (charge_type in ('rent', 'deposit', 'maintenance', 'late_fee', 'other')),
  constraint lease_charges_status_check check (charge_status in ('open', 'partially_paid', 'paid', 'void')),
  constraint lease_charges_period_check check (period_end is null or period_start is null or period_end >= period_start),
  constraint lease_charges_paid_not_over_amount check (amount_paid <= amount)
);

create index if not exists lease_charges_lease_id_idx on public.lease_charges (lease_id);
create index if not exists lease_charges_landlord_id_idx on public.lease_charges (landlord_id);
create index if not exists lease_charges_tenant_id_idx on public.lease_charges (tenant_id);
create index if not exists lease_charges_status_due_idx on public.lease_charges (charge_status, due_date);
create unique index if not exists lease_charges_one_rent_period_idx
  on public.lease_charges (lease_id, period_start)
  where charge_type = 'rent' and voided_at is null;
create unique index if not exists lease_charges_one_deposit_idx
  on public.lease_charges (lease_id)
  where charge_type = 'deposit' and voided_at is null;

create table if not exists public.payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  charge_id uuid not null references public.lease_charges(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  constraint payment_allocations_payment_charge_unique unique (payment_id, charge_id)
);

create index if not exists payment_allocations_payment_id_idx on public.payment_allocations (payment_id);
create index if not exists payment_allocations_charge_id_idx on public.payment_allocations (charge_id);

create table if not exists public.lease_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid null references public.tenants(id) on delete set null,
  lease_id uuid null references public.leases(id) on delete set null,
  unit_id uuid null references public.units(id) on delete set null,
  property_id uuid null references public.properties(id) on delete set null,
  entry_type text not null,
  entry_purpose text not null,
  debit numeric(12,2) not null default 0 check (debit >= 0),
  credit numeric(12,2) not null default 0 check (credit >= 0),
  entry_date date not null default current_date,
  source_table text,
  source_id uuid,
  description text,
  created_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint lease_ledger_entries_type_check check (entry_type in ('charge', 'payment', 'allocation', 'deposit_liability', 'adjustment', 'reversal')),
  constraint lease_ledger_entries_purpose_check check (entry_purpose in ('rent', 'deposit', 'maintenance', 'late_fee', 'other')),
  constraint lease_ledger_entries_amount_check check (debit > 0 or credit > 0)
);

create index if not exists lease_ledger_entries_landlord_id_idx on public.lease_ledger_entries (landlord_id);
create index if not exists lease_ledger_entries_tenant_id_idx on public.lease_ledger_entries (tenant_id);
create index if not exists lease_ledger_entries_lease_id_idx on public.lease_ledger_entries (lease_id);
create index if not exists lease_ledger_entries_entry_date_idx on public.lease_ledger_entries (entry_date);
create index if not exists lease_ledger_entries_source_idx on public.lease_ledger_entries (source_table, source_id);
create unique index if not exists lease_ledger_entries_one_source_entry_idx
  on public.lease_ledger_entries (source_table, source_id, entry_type)
  where source_table is not null and source_id is not null;

create table if not exists public.finance_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid null references public.profiles(id) on delete set null,
  landlord_id uuid null references public.profiles(id) on delete set null,
  lease_id uuid null references public.leases(id) on delete set null,
  target_table text not null,
  target_id uuid,
  action text not null,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now(),
  constraint finance_audit_events_action_check check (action in ('insert', 'update', 'delete', 'approve', 'void', 'allocate', 'reconcile'))
);

create index if not exists finance_audit_events_landlord_id_idx on public.finance_audit_events (landlord_id);
create index if not exists finance_audit_events_lease_id_idx on public.finance_audit_events (lease_id);
create index if not exists finance_audit_events_target_idx on public.finance_audit_events (target_table, target_id);

drop trigger if exists lease_charges_touch_updated_at on public.lease_charges;
create trigger lease_charges_touch_updated_at
before update on public.lease_charges
for each row execute function public.touch_updated_at();

create table if not exists public.receipt_counters (
  receipt_year integer primary key,
  last_number integer not null default 0
);

create table if not exists public.maintenance_requests (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete cascade,
  lease_id uuid null references public.leases(id) on delete set null,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  submitted_by_profile_id uuid not null references public.profiles(id) on delete cascade,
  assigned_to_staff_id uuid null references public.profiles(id) on delete set null,
  description text not null,
  photo_url text,
  photo_path text,
  photo_name text,
  photo_size integer,
  photo_uploaded_by uuid null references public.profiles(id) on delete set null,
  photo_uploaded_at timestamptz,
  status public.maintenance_status not null default 'open',
  priority public.priority_level not null default 'medium',
  resolution_notes text,
  workflow_notes text,
  scheduled_for timestamptz,
  final_cost numeric(12,2),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  completed_at timestamptz,
  completed_by uuid null references public.profiles(id) on delete set null,
  cancelled_at timestamptz,
  cancellation_reason text,
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid null references public.profiles(id) on delete set null
);

alter table public.maintenance_requests add column if not exists photo_path text;
alter table public.maintenance_requests add column if not exists photo_name text;
alter table public.maintenance_requests add column if not exists photo_size integer;
alter table public.maintenance_requests add column if not exists photo_uploaded_by uuid null references public.profiles(id) on delete set null;
alter table public.maintenance_requests add column if not exists photo_uploaded_at timestamptz;
alter table public.maintenance_requests add column if not exists workflow_notes text;
alter table public.maintenance_requests add column if not exists scheduled_for timestamptz;
alter table public.maintenance_requests add column if not exists final_cost numeric(12,2);
alter table public.maintenance_requests add column if not exists completed_at timestamptz;
alter table public.maintenance_requests add column if not exists completed_by uuid null references public.profiles(id) on delete set null;
alter table public.maintenance_requests add column if not exists cancelled_at timestamptz;
alter table public.maintenance_requests add column if not exists cancellation_reason text;
alter table public.maintenance_requests add column if not exists updated_at timestamptz not null default now();
alter table public.maintenance_requests add column if not exists archived_at timestamptz;
alter table public.maintenance_requests add column if not exists archived_by uuid null references public.profiles(id) on delete set null;

create index if not exists maintenance_requests_landlord_id_idx on public.maintenance_requests (landlord_id);
create index if not exists maintenance_requests_unit_id_idx on public.maintenance_requests (unit_id);
create index if not exists maintenance_requests_submitted_by_idx on public.maintenance_requests (submitted_by_profile_id);
create index if not exists maintenance_requests_status_idx on public.maintenance_requests (status);
create index if not exists maintenance_requests_scheduled_for_idx on public.maintenance_requests (scheduled_for);

do $$
begin
  alter table public.maintenance_requests
    add constraint maintenance_requests_photo_size_check
    check (photo_size is null or photo_size > 0);
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table public.maintenance_requests
    add constraint maintenance_requests_final_cost_check
    check (final_cost is null or final_cost >= 0);
exception when duplicate_object then null;
end $$;

create table if not exists public.maintenance_quotes (
  id uuid primary key default gen_random_uuid(),
  maintenance_request_id uuid not null references public.maintenance_requests(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  vendor_name text not null,
  vendor_phone text,
  vendor_email text,
  amount numeric(12,2) not null check (amount > 0),
  currency_code text not null default 'USD',
  notes text,
  status text not null default 'sent_for_approval' check (status in ('sent_for_approval', 'approved', 'rejected', 'cancelled')),
  requested_by uuid null references public.profiles(id) on delete set null,
  reviewed_by uuid null references public.profiles(id) on delete set null,
  submitted_at timestamptz not null default now(),
  approved_at timestamptz,
  rejected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists maintenance_quotes_request_idx on public.maintenance_quotes (maintenance_request_id);
create index if not exists maintenance_quotes_landlord_idx on public.maintenance_quotes (landlord_id);
create index if not exists maintenance_quotes_unit_idx on public.maintenance_quotes (unit_id);
create index if not exists maintenance_quotes_status_idx on public.maintenance_quotes (status);
create index if not exists maintenance_quotes_submitted_idx on public.maintenance_quotes (submitted_at desc);

create table if not exists public.maintenance_activity (
  id uuid primary key default gen_random_uuid(),
  maintenance_request_id uuid not null references public.maintenance_requests(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  actor_profile_id uuid null references public.profiles(id) on delete set null,
  activity_type text not null,
  title text not null,
  body text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists maintenance_activity_request_idx on public.maintenance_activity (maintenance_request_id);
create index if not exists maintenance_activity_landlord_idx on public.maintenance_activity (landlord_id);
create index if not exists maintenance_activity_created_idx on public.maintenance_activity (created_at desc);

create table if not exists public.property_inspections (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  lease_id uuid null references public.leases(id) on delete set null,
  tenant_id uuid null references public.tenants(id) on delete set null,
  maintenance_request_id uuid null references public.maintenance_requests(id) on delete set null,
  inspection_type text not null default 'routine',
  status text not null default 'draft',
  scheduled_for date,
  inspected_at timestamptz,
  inspector_profile_id uuid null references public.profiles(id) on delete set null,
  tenant_signature_name text,
  tenant_signed_at timestamptz,
  meter_readings jsonb not null default '{}'::jsonb,
  room_conditions jsonb not null default '[]'::jsonb,
  summary_notes text,
  deposit_deduction_amount numeric(12,2) not null default 0,
  deposit_deduction_notes text,
  compared_to_inspection_id uuid null references public.property_inspections(id) on delete set null,
  locked_at timestamptz,
  locked_by uuid null references public.profiles(id) on delete set null,
  created_by uuid null references public.profiles(id) on delete set null,
  updated_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint property_inspections_type_check check (inspection_type in ('move_in', 'routine', 'move_out')),
  constraint property_inspections_status_check check (status in ('draft', 'completed', 'locked')),
  constraint property_inspections_deduction_check check (deposit_deduction_amount >= 0)
);

create index if not exists property_inspections_landlord_idx on public.property_inspections (landlord_id);
create index if not exists property_inspections_property_idx on public.property_inspections (property_id);
create index if not exists property_inspections_unit_idx on public.property_inspections (unit_id);
create index if not exists property_inspections_lease_idx on public.property_inspections (lease_id);
create index if not exists property_inspections_tenant_idx on public.property_inspections (tenant_id);
create index if not exists property_inspections_type_idx on public.property_inspections (inspection_type);
create index if not exists property_inspections_status_idx on public.property_inspections (status);
create index if not exists property_inspections_scheduled_idx on public.property_inspections (scheduled_for);

create table if not exists public.inspection_files (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.property_inspections(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  lease_id uuid null references public.leases(id) on delete set null,
  tenant_id uuid null references public.tenants(id) on delete set null,
  file_kind text not null default 'photo',
  room_name text,
  caption text,
  object_path text not null unique,
  mime_type text,
  file_size bigint,
  uploaded_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint inspection_files_kind_check check (file_kind in ('photo', 'video', 'document', 'signature', 'deduction_evidence')),
  constraint inspection_files_size_check check (file_size is null or file_size > 0)
);

create index if not exists inspection_files_inspection_idx on public.inspection_files (inspection_id);
create index if not exists inspection_files_landlord_idx on public.inspection_files (landlord_id);
create index if not exists inspection_files_unit_idx on public.inspection_files (unit_id);
create index if not exists inspection_files_tenant_idx on public.inspection_files (tenant_id);
create index if not exists inspection_files_created_idx on public.inspection_files (created_at desc);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  landlord_id uuid null references public.profiles(id) on delete cascade,
  type public.notification_type not null,
  message text not null,
  related_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.notifications add column if not exists response_status text;

do $$
begin
  alter table public.notifications
    add constraint notifications_response_status_check
    check (response_status is null or response_status in ('pending', 'accepted', 'rejected'));
exception when duplicate_object then null;
end $$;

create index if not exists notifications_profile_id_idx on public.notifications (profile_id, is_read, created_at desc);
create index if not exists notifications_landlord_id_idx on public.notifications (landlord_id);
create index if not exists notifications_related_idx on public.notifications (type, related_id);

create table if not exists public.tenant_applications (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  property_id uuid null references public.properties(id) on delete set null,
  unit_id uuid null references public.units(id) on delete set null,
  tenant_id uuid null references public.tenants(id) on delete set null,
  applicant_name text not null,
  applicant_email text not null,
  applicant_phone text,
  applicant_id_number text,
  status text not null default 'submitted',
  notes text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_applications_status_check check (status in ('submitted', 'reviewing', 'approved', 'rejected', 'withdrawn'))
);

create index if not exists tenant_applications_landlord_idx on public.tenant_applications (landlord_id, status, created_at desc);
create index if not exists tenant_applications_tenant_idx on public.tenant_applications (tenant_id);
create index if not exists tenant_applications_email_idx on public.tenant_applications (lower(applicant_email));

create table if not exists public.tenant_documents (
  id uuid primary key default gen_random_uuid(),
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  lease_id uuid null references public.leases(id) on delete cascade,
  document_type text not null default 'other',
  title text not null,
  file_path text not null,
  file_name text not null,
  file_size integer,
  notes text,
  uploaded_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_documents_type_check check (document_type in ('identity', 'proof_of_income', 'lease_support', 'move_in', 'move_out', 'reference', 'other')),
  constraint tenant_documents_file_size_check check (file_size is null or file_size > 0)
);

create index if not exists tenant_documents_landlord_idx on public.tenant_documents (landlord_id, created_at desc);
create index if not exists tenant_documents_tenant_idx on public.tenant_documents (tenant_id, created_at desc);
create index if not exists tenant_documents_lease_idx on public.tenant_documents (lease_id);

create table if not exists public.lease_lifecycle_items (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references public.leases(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  category text not null,
  title text not null,
  notes text,
  due_date date,
  is_done boolean not null default false,
  completed_at timestamptz,
  completed_by uuid null references public.profiles(id) on delete set null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lease_lifecycle_items_category_check check (category in ('lease_generation', 'move_in', 'renewal', 'expiry', 'move_out'))
);

create index if not exists lease_lifecycle_items_lease_idx on public.lease_lifecycle_items (lease_id, category, sort_order);
create index if not exists lease_lifecycle_items_landlord_idx on public.lease_lifecycle_items (landlord_id, due_date);
create unique index if not exists lease_lifecycle_items_unique_template_idx
  on public.lease_lifecycle_items (lease_id, category, title);

create table if not exists public.deposit_settlements (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null unique references public.leases(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  deposit_amount numeric(12,2) not null default 0 check (deposit_amount >= 0),
  deductions_amount numeric(12,2) not null default 0 check (deductions_amount >= 0),
  refund_amount numeric(12,2) not null default 0 check (refund_amount >= 0),
  status text not null default 'not_started',
  notes text,
  tenant_notes text,
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint deposit_settlements_status_check check (status in ('not_started', 'draft', 'tenant_review', 'approved', 'paid', 'disputed'))
);

create index if not exists deposit_settlements_landlord_idx on public.deposit_settlements (landlord_id, status);
create index if not exists deposit_settlements_tenant_idx on public.deposit_settlements (tenant_id);
create unique index if not exists deposit_settlements_lease_unique_idx on public.deposit_settlements (lease_id);

create table if not exists public.tenant_reference_requests (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid not null references public.leases(id) on delete cascade,
  landlord_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  requester_name text not null,
  requester_email text not null,
  purpose text,
  consent_status text not null default 'pending',
  response_notes text,
  requested_at timestamptz not null default now(),
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_reference_requests_consent_check check (consent_status in ('pending', 'approved', 'rejected', 'withdrawn'))
);

create index if not exists tenant_reference_requests_landlord_idx on public.tenant_reference_requests (landlord_id, consent_status, requested_at desc);
create index if not exists tenant_reference_requests_tenant_idx on public.tenant_reference_requests (tenant_id, requested_at desc);
create index if not exists tenant_reference_requests_lease_idx on public.tenant_reference_requests (lease_id);

create table if not exists public.telegram_link_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique default public.generate_invite_token(32),
  used boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '48 hours')
);

alter table public.telegram_link_tokens alter column token set default public.generate_invite_token(32);
create index if not exists telegram_link_tokens_profile_id_idx on public.telegram_link_tokens (profile_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.assign_landlord_code()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  next_code text;
  attempts integer := 0;
begin
  if new.role <> 'landlord' or new.landlord_code is not null then
    return new;
  end if;

  loop
    next_code := public.generate_six_digit_code();
    exit when not exists (
      select 1 from public.profiles p where p.landlord_code = next_code
    );
    attempts := attempts + 1;
    if attempts > 25 then
      raise exception 'Could not generate a unique landlord code.';
    end if;
  end loop;

  new.landlord_code := next_code;
  return new;
end;
$$;

drop trigger if exists landlord_subscriptions_touch_updated_at on public.landlord_subscriptions;
create trigger landlord_subscriptions_touch_updated_at
before update on public.landlord_subscriptions
for each row execute function public.touch_updated_at();

drop trigger if exists partner_reconciliations_touch_updated_at on public.partner_reconciliations;
create trigger partner_reconciliations_touch_updated_at
before update on public.partner_reconciliations
for each row execute function public.touch_updated_at();

drop trigger if exists maintenance_quotes_touch_updated_at on public.maintenance_quotes;
create trigger maintenance_quotes_touch_updated_at
before update on public.maintenance_quotes
for each row execute function public.touch_updated_at();

drop trigger if exists maintenance_requests_touch_updated_at on public.maintenance_requests;
create trigger maintenance_requests_touch_updated_at
before update on public.maintenance_requests
for each row execute function public.touch_updated_at();

create or replace function public.prevent_locked_inspection_changes()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.status = 'locked' then
      raise exception 'Locked inspection records cannot be deleted.';
    end if;
    return old;
  end if;

  if old.status = 'locked' then
    raise exception 'Locked inspection records cannot be changed.';
  end if;

  if new.status = 'locked' and old.status <> 'locked' then
    new.locked_at := coalesce(new.locked_at, now());
    new.locked_by := coalesce(new.locked_by, auth.uid());
  end if;

  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

drop trigger if exists property_inspections_lock_guard on public.property_inspections;
create trigger property_inspections_lock_guard
before update or delete on public.property_inspections
for each row execute function public.prevent_locked_inspection_changes();

create or replace function public.assign_enquiry_country_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.full_name := trim(new.full_name);
  new.email := trim(new.email);
  new.country_name := trim(new.country_name);
  new.enquiry_type := trim(new.enquiry_type);
  new.message := trim(new.message);

  select c.id
  into new.country_id
  from public.countries c
  where lower(c.name) = lower(new.country_name)
    and c.archived_at is null
  limit 1;

  return new;
end;
$$;

drop trigger if exists enquiries_assign_country on public.enquiries;
create trigger enquiries_assign_country
before insert or update of country_name on public.enquiries
for each row execute function public.assign_enquiry_country_id();

drop trigger if exists enquiries_touch_updated_at on public.enquiries;
create trigger enquiries_touch_updated_at
before update on public.enquiries
for each row execute function public.touch_updated_at();

drop trigger if exists pricing_plans_touch_updated_at on public.pricing_plans;
create trigger pricing_plans_touch_updated_at
before update on public.pricing_plans
for each row execute function public.touch_updated_at();

drop trigger if exists admin_notes_touch_updated_at on public.admin_notes;
create trigger admin_notes_touch_updated_at
before update on public.admin_notes
for each row execute function public.touch_updated_at();

drop trigger if exists tenant_applications_touch_updated_at on public.tenant_applications;
create trigger tenant_applications_touch_updated_at
before update on public.tenant_applications
for each row execute function public.touch_updated_at();

drop trigger if exists tenant_documents_touch_updated_at on public.tenant_documents;
create trigger tenant_documents_touch_updated_at
before update on public.tenant_documents
for each row execute function public.touch_updated_at();

drop trigger if exists lease_lifecycle_items_touch_updated_at on public.lease_lifecycle_items;
create trigger lease_lifecycle_items_touch_updated_at
before update on public.lease_lifecycle_items
for each row execute function public.touch_updated_at();

drop trigger if exists deposit_settlements_touch_updated_at on public.deposit_settlements;
create trigger deposit_settlements_touch_updated_at
before update on public.deposit_settlements
for each row execute function public.touch_updated_at();

drop trigger if exists tenant_reference_requests_touch_updated_at on public.tenant_reference_requests;
create trigger tenant_reference_requests_touch_updated_at
before update on public.tenant_reference_requests
for each row execute function public.touch_updated_at();

drop trigger if exists profiles_assign_landlord_code on public.profiles;
create trigger profiles_assign_landlord_code
before insert or update on public.profiles
for each row execute function public.assign_landlord_code();

create or replace function public.current_profile_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select p.role from public.profiles p where p.id = auth.uid()
$$;

create or replace function public.current_landlord_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p.role = 'landlord' then p.id
    when p.role = 'staff' then p.landlord_id
    else null
  end
  from public.profiles p
  where p.id = auth.uid()
$$;

create or replace function public.landlord_can_add_property(p_landlord_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with limit_row as (
    select coalesce(ls.property_limit, 1) as property_limit
    from public.landlord_subscriptions ls
    where ls.landlord_id = p_landlord_id
    order by ls.created_at desc
    limit 1
  )
  select (
    select count(*)
    from public.properties p
    where p.landlord_id = p_landlord_id
      and p.archived_at is null
  ) < coalesce((select property_limit from limit_row), 1)
$$;

create or replace function public.landlord_can_add_unit(p_landlord_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with limit_row as (
    select coalesce(ls.unit_limit, 1) as unit_limit
    from public.landlord_subscriptions ls
    where ls.landlord_id = p_landlord_id
    order by ls.created_at desc
    limit 1
  )
  select (
    select count(*)
    from public.units u
    join public.properties p on p.id = u.property_id
    where p.landlord_id = p_landlord_id
      and p.archived_at is null
      and u.archived_at is null
  ) < coalesce((select unit_limit from limit_row), 1)
$$;

create or replace function public.landlord_can_invite_personal_staff(p_landlord_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with limit_row as (
    select coalesce(ls.personal_staff_limit, 0) as personal_staff_limit
    from public.landlord_subscriptions ls
    where ls.landlord_id = p_landlord_id
    order by ls.created_at desc
    limit 1
  )
  select (
    (
      select count(distinct sp.staff_profile_id)
      from public.staff_permissions sp
      join public.profiles p on p.id = sp.staff_profile_id
      where sp.landlord_id = p_landlord_id
        and sp.status = 'approved'
        and p.role = 'staff'
        and coalesce(p.staff_type, 'landlord') = 'landlord'
        and p.archived_at is null
    ) + (
      select count(*)
      from public.invite_tokens it
      where it.landlord_id = p_landlord_id
        and it.role = 'staff'
        and it.used = false
        and it.expires_at > now()
        and coalesce(it.metadata ->> 'staff_type', 'landlord') = 'landlord'
        and not exists (
          select 1
          from public.staff_permissions sp
          join public.profiles p on p.id = sp.staff_profile_id
          where sp.landlord_id = p_landlord_id
            and sp.status = 'approved'
            and p.role = 'staff'
            and coalesce(p.staff_type, 'landlord') = 'landlord'
            and p.archived_at is null
            and lower(p.email) = lower(it.email)
        )
    )
  ) < coalesce((select personal_staff_limit from limit_row), 0)
$$;

create or replace function public.landlord_can_accept_partner_connection(p_landlord_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with limit_row as (
    select coalesce(ls.partner_connection_limit, 1) as partner_connection_limit
    from public.landlord_subscriptions ls
    where ls.landlord_id = p_landlord_id
    order by ls.created_at desc
    limit 1
  )
  select (
    (
      select count(*)
      from public.staff_permissions sp
      join public.profiles p on p.id = sp.staff_profile_id
      where sp.landlord_id = p_landlord_id
        and sp.status = 'approved'
        and p.role = 'staff'
        and p.staff_type = 'freelancer'
        and p.archived_at is null
    ) + (
      select count(*)
      from public.management_landlord_permissions mlp
      join public.management_companies mc on mc.id = mlp.management_company_id
      where mlp.landlord_id = p_landlord_id
        and mlp.status = 'approved'
        and mc.archived_at is null
    )
  ) < coalesce((select partner_connection_limit from limit_row), 1)
$$;

create or replace function public.enforce_unit_subscription_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_landlord_id uuid;
begin
  select p.landlord_id
  into owner_landlord_id
  from public.properties p
  where p.id = new.property_id
    and p.archived_at is null;

  if owner_landlord_id is null then
    raise exception 'Property not found for this unit.';
  end if;

  if not public.landlord_can_add_unit(owner_landlord_id) then
    raise exception 'This landlord has reached the unit limit for their subscription.';
  end if;

  return new;
end;
$$;

drop trigger if exists units_enforce_subscription_limit on public.units;
create trigger units_enforce_subscription_limit
before insert on public.units
for each row execute function public.enforce_unit_subscription_limit();

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'super_admin'
  )
$$;

create or replace function public.is_super_admin_profile(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_profile_id
      and p.role = 'super_admin'
      and p.archived_at is null
  )
$$;

create or replace function public.admin_note_assignees()
returns table (
  id uuid,
  full_name text,
  email text,
  role public.user_role
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  caller_role public.user_role;
begin
  select p.role
    into caller_role
  from public.profiles p
  where p.id = auth.uid()
    and p.archived_at is null;

  if caller_role = 'super_admin' then
    return query
    select p.id, p.full_name, p.email, p.role
    from public.profiles p
    where p.role in ('super_admin', 'admin_staff')
      and p.archived_at is null
      and coalesce(p.staff_subscription_status, 'active') <> 'suspended'
    order by
      case when p.role = 'super_admin' then 0 else 1 end,
      nullif(trim(p.full_name), '') nulls last,
      p.email;
    return;
  end if;

  if caller_role = 'admin_staff' then
    return query
    select p.id, p.full_name, p.email, p.role
    from public.profiles p
    where p.archived_at is null
      and (
        p.role = 'super_admin'
        or p.id = auth.uid()
      )
      and coalesce(p.staff_subscription_status, 'active') <> 'suspended'
    order by
      case when p.role = 'super_admin' then 0 else 1 end,
      nullif(trim(p.full_name), '') nulls last,
      p.email;
  end if;
end;
$$;

create or replace function public.current_admin_staff_country_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.country_id
  from public.profiles p
  where p.id = auth.uid()
    and p.role = 'admin_staff'
    and p.archived_at is null
$$;

create or replace function public.is_admin_staff_for_country(p_country_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_country_id is not null
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin_staff'
        and p.archived_at is null
        and (
          p.country_id = p_country_id
          or exists (
            select 1
            from public.admin_staff_country_assignments asca
            where asca.staff_profile_id = p.id
              and asca.country_id = p_country_id
          )
        )
    )
$$;

create or replace function public.can_access_enquiry(p_country_id uuid, p_country_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or exists (
      select 1
      from public.profiles staff
      left join public.admin_staff_country_assignments asca on asca.staff_profile_id = staff.id
      left join public.countries c on c.id = coalesce(asca.country_id, staff.country_id)
      where staff.id = auth.uid()
        and staff.role = 'admin_staff'
        and staff.archived_at is null
        and (
          staff.country_id = p_country_id
          or asca.country_id = p_country_id
          or lower(coalesce(c.name, '')) = lower(coalesce(p_country_name, ''))
        )
    )
$$;

create or replace function public.admin_staff_can_access_landlord(p_landlord_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles landlord
    where landlord.id = p_landlord_id
      and landlord.role = 'landlord'
      and public.is_admin_staff_for_country(landlord.country_id)
  )
$$;

create or replace function public.admin_staff_can_access_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.properties p
    where p.id = p_property_id
      and public.admin_staff_can_access_landlord(p.landlord_id)
  )
$$;

create or replace function public.admin_staff_can_access_unit(p_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.units u
    where u.id = p_unit_id
      and public.admin_staff_can_access_property(u.property_id)
  )
$$;

create or replace function public.admin_staff_can_access_tenant(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tenants t
    where t.id = p_tenant_id
      and public.admin_staff_can_access_landlord(t.landlord_id)
  )
$$;

create or replace function public.admin_staff_can_access_lease(p_lease_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    where l.id = p_lease_id
      and public.admin_staff_can_access_landlord(l.landlord_id)
  )
$$;

create or replace function public.is_landlord()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'landlord'
  )
$$;

create or replace function public.get_current_profile()
returns public.profiles
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.profiles p
  where p.id = auth.uid()
$$;

create or replace function public.staff_permission_flag(flag_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  allowed boolean;
begin
  select case flag_name
    when 'can_view_properties' then sp.can_view_properties
    when 'can_add_properties' then sp.can_add_properties
    when 'can_edit_properties' then sp.can_edit_properties
    when 'can_archive_properties' then sp.can_archive_properties
    when 'can_view_units' then sp.can_view_units
    when 'can_add_units' then sp.can_add_units
    when 'can_edit_units' then sp.can_edit_units
    when 'can_archive_units' then sp.can_archive_units
    when 'can_mark_units_vacant' then sp.can_mark_units_vacant
    when 'can_view_tenants' then sp.can_view_tenants
    when 'can_add_tenants' then sp.can_add_tenants
    when 'can_edit_tenants' then sp.can_edit_tenants
    when 'can_archive_tenants' then sp.can_archive_tenants
    when 'can_view_leases' then sp.can_view_leases or sp.can_manage_leases
    when 'can_create_leases' then sp.can_create_leases or sp.can_manage_leases
    when 'can_edit_leases' then sp.can_edit_leases or sp.can_manage_leases
    when 'can_terminate_leases' then sp.can_terminate_leases or sp.can_manage_leases
    when 'can_view_lease_documents' then sp.can_view_lease_documents or sp.can_manage_leases
    when 'can_upload_lease_documents' then sp.can_upload_lease_documents or sp.can_manage_leases
    when 'can_log_payments' then sp.can_log_payments
    when 'can_reject_payments' then sp.can_reject_payments
    when 'can_view_payment_proofs' then sp.can_view_payment_proofs
    when 'can_manage_maintenance' then sp.can_manage_maintenance
    when 'can_create_maintenance' then sp.can_create_maintenance
    when 'can_assign_maintenance' then sp.can_assign_maintenance
    when 'can_add_resolution_notes' then sp.can_add_resolution_notes
    when 'can_view_payments' then sp.can_view_payments
    when 'can_verify_payments' then sp.can_verify_payments
    when 'can_manage_leases' then sp.can_manage_leases
    when 'can_manage_staff' then sp.can_manage_staff
    when 'can_view_finance' then sp.can_view_finance
    else false
  end
  into allowed
  from public.staff_permissions sp
  where sp.staff_profile_id = auth.uid()
    and sp.landlord_id = public.current_landlord_id()
    and sp.status = 'approved';

  if not coalesce(allowed, false) then
    return false;
  end if;

  if flag_name in ('can_add_properties', 'can_edit_properties', 'can_archive_properties') then
    return public.staff_permission_flag('can_view_properties');
  end if;

  if flag_name = 'can_view_units' then
    return public.staff_permission_flag('can_view_properties');
  end if;

  if flag_name in ('can_add_units', 'can_edit_units', 'can_archive_units', 'can_mark_units_vacant') then
    return public.staff_permission_flag('can_view_properties') and public.staff_permission_flag('can_view_units');
  end if;

  if flag_name in ('can_add_tenants', 'can_edit_tenants', 'can_archive_tenants') then
    return public.staff_permission_flag('can_view_tenants');
  end if;

  if flag_name = 'can_view_leases' then
    return public.staff_permission_flag('can_view_units');
  end if;

  if flag_name = 'can_create_leases' then
    return public.staff_permission_flag('can_view_units') and public.staff_permission_flag('can_view_tenants');
  end if;

  if flag_name in ('can_edit_leases', 'can_terminate_leases', 'can_view_lease_documents', 'can_upload_lease_documents', 'can_manage_leases') then
    return public.staff_permission_flag('can_view_units');
  end if;

  return true;
end;
$$;

-- Fresh database bootstrap placeholder.
-- Some RLS policies below reference management_permission_flag(text) before the
-- full implementation is declared later in the file. On an existing database
-- this already existed, but after wiping Supabase the policy creation fails.
-- The real function body later replaces this placeholder with CREATE OR REPLACE.
create or replace function public.management_permission_flag(flag_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select false
$$;

create or replace function public.management_can_access_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select false
$$;

create or replace function public.management_can_access_unit(p_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select false
$$;

create or replace function public.management_can_access_lease(p_lease_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select false
$$;

create or replace function public.management_can_access_tenant(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select false
$$;

create or replace function public.tenant_link_allowed(
  p_tenant_id uuid,
  p_landlord_id uuid,
  p_email text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select false
$$;

create or replace function public.staff_can_access_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.staff_permissions sp
    where sp.staff_profile_id = auth.uid()
      and sp.landlord_id = public.current_landlord_id()
      and sp.status = 'approved'
      and (sp.all_properties or p_property_id = any(sp.property_ids))
  )
$$;

create or replace function public.tenant_can_access_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.units u
    join public.leases l on l.unit_id = u.id
    join public.tenants t on t.id = l.tenant_id
    where u.property_id = p_property_id
      and t.profile_id = auth.uid()
  )
$$;

create or replace function public.staff_can_access_unit(p_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.units u
    where u.id = p_unit_id
      and public.staff_can_access_property(u.property_id)
  )
$$;

create or replace function public.staff_can_access_lease(p_lease_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    where l.id = p_lease_id
      and public.staff_can_access_unit(l.unit_id)
  )
$$;

create or replace function public.staff_can_access_tenant(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tenants t
    where t.id = p_tenant_id
      and t.landlord_id = public.current_landlord_id()
  )
  or exists (
    select 1
    from public.leases l
    where l.tenant_id = p_tenant_id
      and public.staff_can_access_unit(l.unit_id)
  )
$$;

create or replace function public.lease_document_lease_id(p_object_name text)
returns uuid
language plpgsql
immutable
as $$
declare
  lease_uuid uuid;
begin
  lease_uuid := nullif(split_part(p_object_name, '/', 2), '')::uuid;
  return lease_uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.can_read_lease_document(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    where l.id = public.lease_document_lease_id(p_object_name)
      and split_part(p_object_name, '/', 1) = l.landlord_id::text
      and (
        l.landlord_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and public.staff_permission_flag('can_view_lease_documents')
          and public.staff_can_access_lease(l.id)
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and public.management_permission_flag('can_view_lease_documents')
          and public.management_can_access_lease(l.id)
        )
        or t.profile_id = auth.uid()
      )
  )
$$;

create or replace function public.can_manage_lease_document(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    where l.id = public.lease_document_lease_id(p_object_name)
      and split_part(p_object_name, '/', 1) = l.landlord_id::text
      and (
        l.landlord_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and public.staff_permission_flag('can_upload_lease_documents')
          and public.staff_can_access_lease(l.id)
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and public.management_permission_flag('can_upload_lease_documents')
          and public.management_can_access_lease(l.id)
        )
      )
  )
$$;

create or replace function public.tenant_document_tenant_id(p_object_name text)
returns uuid
language plpgsql
immutable
as $$
declare
  tenant_uuid uuid;
begin
  tenant_uuid := nullif(split_part(p_object_name, '/', 1), '')::uuid;
  return tenant_uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.tenant_document_lease_id(p_object_name text)
returns uuid
language plpgsql
immutable
as $$
declare
  lease_uuid uuid;
begin
  lease_uuid := nullif(split_part(p_object_name, '/', 2), '')::uuid;
  return lease_uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.can_read_tenant_document(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    where l.id = public.tenant_document_lease_id(p_object_name)
      and t.id = public.tenant_document_tenant_id(p_object_name)
      and (
        l.landlord_id = auth.uid()
        or public.is_super_admin()
        or public.admin_staff_can_access_landlord(l.landlord_id)
        or t.profile_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and public.staff_permission_flag('can_view_lease_documents')
          and public.staff_can_access_lease(l.id)
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and public.management_permission_flag('can_view_lease_documents')
          and public.management_can_access_lease(l.id)
        )
      )
  )
$$;

create or replace function public.can_manage_tenant_document(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    where l.id = public.tenant_document_lease_id(p_object_name)
      and t.id = public.tenant_document_tenant_id(p_object_name)
      and (
        l.landlord_id = auth.uid()
        or public.is_super_admin()
        or public.admin_staff_can_access_landlord(l.landlord_id)
        or t.profile_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and public.staff_permission_flag('can_upload_lease_documents')
          and public.staff_can_access_lease(l.id)
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and public.management_permission_flag('can_upload_lease_documents')
          and public.management_can_access_lease(l.id)
        )
      )
  )
$$;

create or replace function public.media_object_row_id(p_object_name text)
returns uuid
language plpgsql
immutable
as $$
declare
  row_uuid uuid;
begin
  row_uuid := nullif(split_part(p_object_name, '/', 2), '')::uuid;
  return row_uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.can_read_payment_proof(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.payment_submissions ps
      join public.leases l on l.id = ps.lease_id
      join public.tenants t on t.id = ps.tenant_id
      where ps.id = public.media_object_row_id(p_object_name)
        and split_part(p_object_name, '/', 1) = l.landlord_id::text
        and (
          l.landlord_id = auth.uid()
          or (
            public.current_profile_role() = 'staff'
            and (public.staff_permission_flag('can_view_payments') or public.staff_permission_flag('can_verify_payments'))
            and public.staff_can_access_lease(l.id)
          )
          or (
            public.current_profile_role() in ('management_leader', 'management_staff')
            and (public.management_permission_flag('can_view_payments') or public.management_permission_flag('can_verify_payments'))
            and public.management_can_access_lease(l.id)
          )
          or t.profile_id = auth.uid()
        )
    )
    or exists (
      select 1
      from public.payments p
      join public.leases l on l.id = p.lease_id
      join public.tenants t on t.id = l.tenant_id
      where p.id = public.media_object_row_id(p_object_name)
        and split_part(p_object_name, '/', 1) = l.landlord_id::text
        and (
          l.landlord_id = auth.uid()
          or (
            public.current_profile_role() = 'staff'
            and (public.staff_permission_flag('can_view_payments') or public.staff_permission_flag('can_verify_payments'))
            and public.staff_can_access_lease(l.id)
          )
          or (
            public.current_profile_role() in ('management_leader', 'management_staff')
            and (public.management_permission_flag('can_view_payments') or public.management_permission_flag('can_verify_payments'))
            and public.management_can_access_lease(l.id)
          )
          or t.profile_id = auth.uid()
        )
    )
$$;

create or replace function public.can_manage_payment_proof(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.payment_submissions ps
      join public.leases l on l.id = ps.lease_id
      join public.tenants t on t.id = ps.tenant_id
      where ps.id = public.media_object_row_id(p_object_name)
        and split_part(p_object_name, '/', 1) = l.landlord_id::text
        and (
          l.landlord_id = auth.uid()
          or (
            public.current_profile_role() = 'staff'
            and public.staff_permission_flag('can_verify_payments')
            and public.staff_can_access_lease(l.id)
          )
          or (
            public.current_profile_role() in ('management_leader', 'management_staff')
            and public.management_permission_flag('can_verify_payments')
            and public.management_can_access_lease(l.id)
          )
          or (t.profile_id = auth.uid() and ps.status = 'pending')
        )
    )
    or exists (
      select 1
      from public.payments p
      join public.leases l on l.id = p.lease_id
      where p.id = public.media_object_row_id(p_object_name)
        and split_part(p_object_name, '/', 1) = l.landlord_id::text
        and (
          l.landlord_id = auth.uid()
          or (
            public.current_profile_role() = 'staff'
            and public.staff_permission_flag('can_verify_payments')
            and public.staff_can_access_lease(l.id)
          )
          or (
            public.current_profile_role() in ('management_leader', 'management_staff')
            and public.management_permission_flag('can_verify_payments')
            and public.management_can_access_lease(l.id)
          )
        )
    )
$$;

create or replace function public.can_read_maintenance_photo(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.maintenance_requests mr
    where mr.id = public.media_object_row_id(p_object_name)
      and split_part(p_object_name, '/', 1) = mr.landlord_id::text
      and (
        mr.landlord_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and (
            public.staff_permission_flag('can_manage_maintenance')
            or public.staff_permission_flag('can_create_maintenance')
            or public.staff_permission_flag('can_assign_maintenance')
            or public.staff_permission_flag('can_add_resolution_notes')
          )
          and public.staff_can_access_unit(mr.unit_id)
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and (
            public.management_permission_flag('can_manage_maintenance')
            or public.management_permission_flag('can_create_maintenance')
            or public.management_permission_flag('can_assign_maintenance')
            or public.management_permission_flag('can_add_resolution_notes')
          )
          and public.management_can_access_unit(mr.unit_id)
        )
        or mr.submitted_by_profile_id = auth.uid()
      )
  )
$$;

create or replace function public.can_manage_maintenance_photo(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.maintenance_requests mr
    where mr.id = public.media_object_row_id(p_object_name)
      and split_part(p_object_name, '/', 1) = mr.landlord_id::text
      and (
        mr.landlord_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and public.staff_permission_flag('can_manage_maintenance')
          and public.staff_can_access_unit(mr.unit_id)
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and public.management_permission_flag('can_manage_maintenance')
          and public.management_can_access_unit(mr.unit_id)
        )
        or mr.submitted_by_profile_id = auth.uid()
      )
  )
$$;

create or replace function public.inspection_file_inspection_id(p_object_name text)
returns uuid
language plpgsql
immutable
as $$
declare
  inspection_uuid uuid;
begin
  inspection_uuid := nullif(split_part(p_object_name, '/', 2), '')::uuid;
  return inspection_uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.can_access_inspection(p_inspection_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  inspection_row public.property_inspections%rowtype;
begin
  select *
  into inspection_row
  from public.property_inspections
  where id = p_inspection_id;

  if not found then
    return false;
  end if;

  if public.is_super_admin()
     or public.admin_staff_can_access_unit(inspection_row.unit_id)
     or inspection_row.landlord_id = auth.uid()
     or public.staff_can_access_unit(inspection_row.unit_id)
     or public.management_can_access_unit(inspection_row.unit_id) then
    return true;
  end if;

  return exists (
    select 1
    from public.tenants t
    where t.id = inspection_row.tenant_id
      and t.profile_id = auth.uid()
      and coalesce(t.archived, false) = false
  );
end;
$$;

create or replace function public.can_manage_inspection(p_inspection_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  inspection_row public.property_inspections%rowtype;
begin
  select *
  into inspection_row
  from public.property_inspections
  where id = p_inspection_id;

  if not found then
    return false;
  end if;

  return (
    public.is_super_admin()
    or public.admin_staff_can_access_unit(inspection_row.unit_id)
    or inspection_row.landlord_id = auth.uid()
    or (
      public.current_profile_role() = 'staff'
      and public.staff_can_access_unit(inspection_row.unit_id)
      and (
        public.staff_permission_flag('can_manage_maintenance')
        or public.staff_permission_flag('can_create_maintenance')
        or public.staff_permission_flag('can_add_resolution_notes')
      )
    )
    or (
      public.current_profile_role() in ('management_leader', 'management_staff')
      and public.management_can_access_unit(inspection_row.unit_id)
      and (
        public.management_permission_flag('can_manage_maintenance')
        or public.management_permission_flag('can_create_maintenance')
        or public.management_permission_flag('can_add_resolution_notes')
      )
    )
  );
end;
$$;

create or replace function public.can_read_inspection_file(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.property_inspections pi
    where pi.id = public.inspection_file_inspection_id(p_object_name)
      and split_part(p_object_name, '/', 1) = pi.landlord_id::text
      and public.can_access_inspection(pi.id)
  )
$$;

create or replace function public.can_manage_inspection_file(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.property_inspections pi
    where pi.id = public.inspection_file_inspection_id(p_object_name)
      and split_part(p_object_name, '/', 1) = pi.landlord_id::text
      and pi.status <> 'locked'
      and public.can_manage_inspection(pi.id)
  )
$$;

create or replace function public.tenant_sign_inspection(
  p_inspection_id uuid,
  p_signature_name text
)
returns public.property_inspections
language plpgsql
security definer
set search_path = public
as $$
declare
  signed_row public.property_inspections%rowtype;
begin
  if nullif(trim(p_signature_name), '') is null then
    raise exception 'Please enter the tenant signature name.';
  end if;

  update public.property_inspections pi
  set tenant_signature_name = trim(p_signature_name),
      tenant_signed_at = now(),
      updated_at = now(),
      updated_by = auth.uid()
  where pi.id = p_inspection_id
    and pi.status <> 'locked'
    and exists (
      select 1
      from public.tenants t
      where t.id = pi.tenant_id
        and t.profile_id = auth.uid()
        and coalesce(t.archived, false) = false
    )
  returning * into signed_row;

  if not found then
    raise exception 'Inspection could not be signed.';
  end if;

  return signed_row;
end;
$$;

create or replace function public.profile_insert_allowed(
  p_email text,
  p_role public.user_role,
  p_landlord_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.invite_tokens it
    where lower(it.email) = lower(p_email)
      and it.role = p_role
      and it.used = false
      and it.expires_at > now()
      and (
        (p_role in ('landlord', 'management_leader', 'admin_staff') and p_landlord_id is null and it.landlord_id is null)
        or (p_role = 'staff' and (
          it.landlord_id = p_landlord_id
          or (p_landlord_id is null and it.landlord_id is null and it.metadata ->> 'staff_type' = 'freelancer')
        ))
        or (p_role = 'management_staff' and (
          it.landlord_id = p_landlord_id
          or (p_landlord_id is null and it.landlord_id is null and it.metadata ->> 'management_company_id' is not null)
        ))
        or (p_role = 'tenant' and (p_landlord_id is null or it.landlord_id = p_landlord_id))
      )
  )
$$;

create or replace function public.current_management_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p.role = 'management_leader' then mc.id
    when p.role = 'management_staff' then msp.management_company_id
    else null
  end
  from public.profiles p
  left join public.management_companies mc on mc.leader_profile_id = p.id and mc.archived_at is null
  left join public.management_staff_permissions msp on msp.staff_profile_id = p.id and msp.status = 'approved'
  where p.id = auth.uid()
  limit 1
$$;

create or replace function public.is_management_leader_for_company(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.management_companies mc
    where mc.id = p_company_id
      and mc.leader_profile_id = auth.uid()
      and mc.archived_at is null
  )
$$;

create or replace function public.is_management_staff_for_company(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.management_staff_permissions msp
    where msp.management_company_id = p_company_id
      and msp.staff_profile_id = auth.uid()
      and msp.status = 'approved'
  )
$$;

create or replace function public.management_permission_flag(flag_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  allowed boolean;
  profile_role public.user_role;
begin
  profile_role := public.current_profile_role();

  select bool_or((
    case flag_name
    when 'can_view_properties' then mlp.can_view_properties
    when 'can_add_properties' then mlp.can_add_properties
    when 'can_edit_properties' then mlp.can_edit_properties
    when 'can_archive_properties' then mlp.can_archive_properties
    when 'can_view_units' then mlp.can_view_units
    when 'can_add_units' then mlp.can_add_units
    when 'can_edit_units' then mlp.can_edit_units
    when 'can_archive_units' then mlp.can_archive_units
    when 'can_mark_units_vacant' then mlp.can_mark_units_vacant
    when 'can_view_tenants' then mlp.can_view_tenants
    when 'can_add_tenants' then mlp.can_add_tenants
    when 'can_edit_tenants' then mlp.can_edit_tenants
    when 'can_archive_tenants' then mlp.can_archive_tenants
    when 'can_view_leases' then mlp.can_view_leases or mlp.can_manage_leases
    when 'can_create_leases' then mlp.can_create_leases or mlp.can_manage_leases
    when 'can_edit_leases' then mlp.can_edit_leases or mlp.can_manage_leases
    when 'can_terminate_leases' then mlp.can_terminate_leases or mlp.can_manage_leases
    when 'can_view_lease_documents' then mlp.can_view_lease_documents or mlp.can_manage_leases
    when 'can_upload_lease_documents' then mlp.can_upload_lease_documents or mlp.can_manage_leases
    when 'can_log_payments' then mlp.can_log_payments
    when 'can_reject_payments' then mlp.can_reject_payments
    when 'can_view_payment_proofs' then mlp.can_view_payment_proofs
    when 'can_manage_maintenance' then mlp.can_manage_maintenance
    when 'can_create_maintenance' then mlp.can_create_maintenance
    when 'can_assign_maintenance' then mlp.can_assign_maintenance
    when 'can_add_resolution_notes' then mlp.can_add_resolution_notes
    when 'can_view_payments' then mlp.can_view_payments
    when 'can_verify_payments' then mlp.can_verify_payments
    when 'can_manage_staff' then mlp.can_manage_staff
    when 'can_view_finance' then mlp.can_view_finance
    else false
    end
  )
  and (
    profile_role <> 'management_staff'
    or case flag_name
      when 'can_view_properties' then msp.can_view_properties
      when 'can_add_properties' then msp.can_add_properties
      when 'can_edit_properties' then msp.can_edit_properties
      when 'can_archive_properties' then msp.can_archive_properties
      when 'can_view_units' then msp.can_view_units
      when 'can_add_units' then msp.can_add_units
      when 'can_edit_units' then msp.can_edit_units
      when 'can_archive_units' then msp.can_archive_units
      when 'can_mark_units_vacant' then msp.can_mark_units_vacant
      when 'can_view_tenants' then msp.can_view_tenants
      when 'can_add_tenants' then msp.can_add_tenants
      when 'can_edit_tenants' then msp.can_edit_tenants
      when 'can_archive_tenants' then msp.can_archive_tenants
      when 'can_view_leases' then msp.can_view_leases or msp.can_manage_leases
      when 'can_create_leases' then msp.can_create_leases or msp.can_manage_leases
      when 'can_edit_leases' then msp.can_edit_leases or msp.can_manage_leases
      when 'can_terminate_leases' then msp.can_terminate_leases or msp.can_manage_leases
      when 'can_view_lease_documents' then msp.can_view_lease_documents or msp.can_manage_leases
      when 'can_upload_lease_documents' then msp.can_upload_lease_documents or msp.can_manage_leases
      when 'can_log_payments' then msp.can_log_payments
      when 'can_reject_payments' then msp.can_reject_payments
      when 'can_view_payment_proofs' then msp.can_view_payment_proofs
      when 'can_manage_maintenance' then msp.can_manage_maintenance
      when 'can_create_maintenance' then msp.can_create_maintenance
      when 'can_assign_maintenance' then msp.can_assign_maintenance
      when 'can_add_resolution_notes' then msp.can_add_resolution_notes
      when 'can_view_payments' then msp.can_view_payments
      when 'can_verify_payments' then msp.can_verify_payments
      when 'can_manage_staff' then msp.can_manage_staff
      when 'can_view_finance' then msp.can_view_finance
      else false
    end
  ))
  into allowed
  from public.management_landlord_permissions mlp
  left join public.management_staff_permissions msp
    on msp.management_company_id = mlp.management_company_id
    and msp.staff_profile_id = auth.uid()
    and msp.status = 'approved'
  where mlp.management_company_id = public.current_management_company_id()
    and mlp.status = 'approved'
    and (
      profile_role <> 'management_staff'
      or mlp.landlord_id = (select p.landlord_id from public.profiles p where p.id = auth.uid())
    )
  ;

  if not coalesce(allowed, false) then
    return false;
  end if;

  if flag_name in ('can_add_properties', 'can_edit_properties', 'can_archive_properties') then
    return public.management_permission_flag('can_view_properties');
  end if;

  if flag_name = 'can_view_units' then
    return public.management_permission_flag('can_view_properties');
  end if;

  if flag_name in ('can_add_units', 'can_edit_units', 'can_archive_units', 'can_mark_units_vacant') then
    return public.management_permission_flag('can_view_properties') and public.management_permission_flag('can_view_units');
  end if;

  if flag_name in ('can_add_tenants', 'can_edit_tenants', 'can_archive_tenants') then
    return public.management_permission_flag('can_view_tenants');
  end if;

  if flag_name = 'can_view_leases' then
    return public.management_permission_flag('can_view_units');
  end if;

  if flag_name = 'can_create_leases' then
    return public.management_permission_flag('can_view_units') and public.management_permission_flag('can_view_tenants');
  end if;

  if flag_name in ('can_edit_leases', 'can_terminate_leases', 'can_view_lease_documents', 'can_upload_lease_documents', 'can_manage_leases') then
    return public.management_permission_flag('can_view_units');
  end if;

  return true;
end;
$$;

create or replace function public.property_unit_permission_allowed(flag_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile_role public.user_role;
begin
  profile_role := public.current_profile_role();

  if profile_role = 'landlord' then
    return true;
  end if;

  if profile_role = 'staff' then
    return public.staff_permission_flag(flag_name);
  end if;

  if profile_role in ('management_leader', 'management_staff') then
    return public.management_permission_flag(flag_name);
  end if;

  return false;
end;
$$;

create or replace function public.enforce_property_update_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_profile_role() = 'landlord' then
    return new;
  end if;

  if (
    old.name is distinct from new.name
    or old.address is distinct from new.address
    or old.city is distinct from new.city
  ) and not public.property_unit_permission_allowed('can_edit_properties') then
    raise exception 'Missing permission: edit properties.';
  end if;

  if (
    old.archived_at is distinct from new.archived_at
    or old.archived_by is distinct from new.archived_by
  ) and not public.property_unit_permission_allowed('can_archive_properties') then
    raise exception 'Missing permission: archive properties.';
  end if;

  return new;
end;
$$;

create or replace function public.enforce_unit_update_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_profile_role() = 'landlord' then
    return new;
  end if;

  if (
    old.unit_number is distinct from new.unit_number
    or old.bedrooms is distinct from new.bedrooms
    or old.bathrooms is distinct from new.bathrooms
    or old.monthly_rent is distinct from new.monthly_rent
    or old.property_id is distinct from new.property_id
  ) and not public.property_unit_permission_allowed('can_edit_units') then
    raise exception 'Missing permission: edit units.';
  end if;

  if (
    old.status is distinct from new.status
    and new.status = 'vacant'
  ) and not public.property_unit_permission_allowed('can_mark_units_vacant') then
    raise exception 'Missing permission: mark units vacant.';
  end if;

  if (
    old.archived_at is distinct from new.archived_at
    or old.archived_by is distinct from new.archived_by
  ) and not public.property_unit_permission_allowed('can_archive_units') then
    raise exception 'Missing permission: archive units.';
  end if;

  return new;
end;
$$;

create or replace function public.enforce_lease_update_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_profile_role() = 'landlord' then
    return new;
  end if;

  if (
    old.unit_id is distinct from new.unit_id
    or old.tenant_id is distinct from new.tenant_id
    or old.start_date is distinct from new.start_date
    or old.end_date is distinct from new.end_date
    or old.monthly_rent is distinct from new.monthly_rent
    or old.deposit_amount is distinct from new.deposit_amount
    or old.deposit_paid is distinct from new.deposit_paid
  ) and not public.property_unit_permission_allowed('can_edit_leases') then
    raise exception 'Missing permission: edit leases.';
  end if;

  if old.status is distinct from new.status then
    if new.status = 'terminated' then
      if not (
        public.property_unit_permission_allowed('can_terminate_leases')
        or public.property_unit_permission_allowed('can_mark_units_vacant')
      ) then
        raise exception 'Missing permission: terminate leases.';
      end if;
    elsif not public.property_unit_permission_allowed('can_edit_leases') then
      raise exception 'Missing permission: edit leases.';
    end if;
  end if;

  if (
    old.lease_document_url is distinct from new.lease_document_url
    or old.lease_document_path is distinct from new.lease_document_path
    or old.lease_document_name is distinct from new.lease_document_name
    or old.lease_document_size is distinct from new.lease_document_size
    or old.lease_document_uploaded_by is distinct from new.lease_document_uploaded_by
    or old.lease_document_uploaded_at is distinct from new.lease_document_uploaded_at
  ) and not public.property_unit_permission_allowed('can_upload_lease_documents') then
    raise exception 'Missing permission: upload lease PDFs.';
  end if;

  return new;
end;
$$;

create or replace function public.enforce_tenant_update_permissions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_role public.user_role;
begin
  profile_role := public.current_profile_role();

  if current_setting('request.mushavo_tenant_self_write', true) = 'true' then
    return new;
  end if;

  if profile_role in ('super_admin', 'landlord') then
    return new;
  end if;

  if (
    lower(old.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    and public.tenant_link_allowed(old.id, old.landlord_id, old.email)
  ) then
    if (
      old.profile_id is distinct from new.profile_id
      or old.invite_accepted is distinct from new.invite_accepted
    )
    and old.landlord_id is not distinct from new.landlord_id
    and old.full_name is not distinct from new.full_name
    and old.phone is not distinct from new.phone
    and old.email is not distinct from new.email
    and old.id_number is not distinct from new.id_number
    and old.archived_at is not distinct from new.archived_at
    and old.archived_by is not distinct from new.archived_by then
      return new;
    end if;
  end if;

  if (
    old.full_name is distinct from new.full_name
    or old.phone is distinct from new.phone
    or old.email is distinct from new.email
    or old.id_number is distinct from new.id_number
  ) and not public.property_unit_permission_allowed('can_edit_tenants') then
    raise exception 'Missing permission: edit tenants.';
  end if;

  if (
    old.archived_at is distinct from new.archived_at
    or old.archived_by is distinct from new.archived_by
  ) and not public.property_unit_permission_allowed('can_archive_tenants') then
    raise exception 'Missing permission: archive tenants.';
  end if;

  if (
    old.landlord_id is distinct from new.landlord_id
    or old.profile_id is distinct from new.profile_id
    or old.invite_token is distinct from new.invite_token
    or old.invite_accepted is distinct from new.invite_accepted
  ) then
    raise exception 'Missing permission: update tenant system fields.';
  end if;

  return new;
end;
$$;

drop trigger if exists properties_enforce_update_permissions on public.properties;
create trigger properties_enforce_update_permissions
before update on public.properties
for each row execute function public.enforce_property_update_permissions();

drop trigger if exists units_enforce_update_permissions on public.units;
create trigger units_enforce_update_permissions
before update on public.units
for each row execute function public.enforce_unit_update_permissions();

drop trigger if exists leases_enforce_update_permissions on public.leases;
create trigger leases_enforce_update_permissions
before update on public.leases
for each row execute function public.enforce_lease_update_permissions();

drop trigger if exists tenants_enforce_update_permissions on public.tenants;
create trigger tenants_enforce_update_permissions
before update on public.tenants
for each row execute function public.enforce_tenant_update_permissions();

create or replace function public.management_can_access_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.management_landlord_permissions mlp
    where mlp.management_company_id = public.current_management_company_id()
      and mlp.status = 'approved'
      and (
        public.current_profile_role() <> 'management_staff'
        or mlp.landlord_id = (select p.landlord_id from public.profiles p where p.id = auth.uid())
      )
      and (mlp.all_properties or p_property_id = any(mlp.property_ids))
  )
$$;

create or replace function public.management_can_access_unit(p_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.units u
    where u.id = p_unit_id
      and public.management_can_access_property(u.property_id)
  )
$$;

create or replace function public.management_can_access_lease(p_lease_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    where l.id = p_lease_id
      and public.management_can_access_unit(l.unit_id)
  )
$$;

create or replace function public.management_can_access_tenant(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tenants t
    join public.management_landlord_permissions mlp on mlp.landlord_id = t.landlord_id
    where t.id = p_tenant_id
      and mlp.management_company_id = public.current_management_company_id()
      and mlp.status = 'approved'
      and (
        public.current_profile_role() <> 'management_staff'
        or mlp.landlord_id = (select p.landlord_id from public.profiles p where p.id = auth.uid())
      )
  )
  or exists (
    select 1
    from public.leases l
    where l.tenant_id = p_tenant_id
      and public.management_can_access_unit(l.unit_id)
  )
$$;

create or replace function public.uuid_array_from_jsonb(p_json jsonb)
returns uuid[]
language sql
immutable
as $$
  select coalesce(array_agg(value::uuid order by value), '{}'::uuid[])
  from jsonb_array_elements_text(coalesce(p_json, '[]'::jsonb)) as value
$$;

create or replace function public.sorted_uuid_array(p_values uuid[])
returns uuid[]
language sql
immutable
as $$
  select coalesce(array_agg(value order by value), '{}'::uuid[])
  from unnest(coalesce(p_values, '{}'::uuid[])) as value
$$;

create or replace function public.staff_permission_insert_allowed(
  p_landlord_id uuid,
  p_all_properties boolean,
  p_property_ids uuid[],
  p_can_view_tenants boolean,
  p_can_manage_maintenance boolean,
  p_can_view_payments boolean,
  p_can_verify_payments boolean,
  p_can_manage_leases boolean
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.invite_tokens it
    where lower(it.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and it.role = 'staff'
      and it.landlord_id = p_landlord_id
      and it.used = false
      and it.expires_at > now()
      and coalesce((it.metadata ->> 'all_properties')::boolean, false) = p_all_properties
      and public.uuid_array_from_jsonb(it.metadata -> 'property_ids') = public.sorted_uuid_array(p_property_ids)
      and coalesce((it.metadata ->> 'can_view_tenants')::boolean, false) = p_can_view_tenants
      and coalesce((it.metadata ->> 'can_manage_maintenance')::boolean, false) = p_can_manage_maintenance
      and coalesce((it.metadata ->> 'can_view_payments')::boolean, false) = p_can_view_payments
      and coalesce((it.metadata ->> 'can_verify_payments')::boolean, false) = p_can_verify_payments
      and coalesce((it.metadata ->> 'can_manage_leases')::boolean, false) = p_can_manage_leases
  )
$$;

create or replace function public.management_staff_permission_insert_allowed(
  p_management_company_id uuid,
  p_landlord_id uuid,
  p_all_properties boolean,
  p_property_ids uuid[],
  p_can_view_tenants boolean,
  p_can_manage_maintenance boolean,
  p_can_view_payments boolean,
  p_can_verify_payments boolean,
  p_can_manage_leases boolean
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.invite_tokens it
    where lower(it.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and it.role = 'management_staff'
      and (
        it.landlord_id = p_landlord_id
        or (p_landlord_id is null and it.landlord_id is null)
      )
      and it.used = false
      and it.expires_at > now()
      and it.metadata ->> 'management_company_id' = p_management_company_id::text
      and coalesce((it.metadata ->> 'all_properties')::boolean, false) = p_all_properties
      and public.uuid_array_from_jsonb(it.metadata -> 'property_ids') = public.sorted_uuid_array(p_property_ids)
      and coalesce((it.metadata ->> 'can_view_tenants')::boolean, false) = p_can_view_tenants
      and coalesce((it.metadata ->> 'can_manage_maintenance')::boolean, false) = p_can_manage_maintenance
      and coalesce((it.metadata ->> 'can_view_payments')::boolean, false) = p_can_view_payments
      and coalesce((it.metadata ->> 'can_verify_payments')::boolean, false) = p_can_verify_payments
      and coalesce((it.metadata ->> 'can_manage_leases')::boolean, false) = p_can_manage_leases
  )
$$;

create or replace function public.tenant_link_allowed(
  p_tenant_id uuid,
  p_landlord_id uuid,
  p_email text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.invite_tokens it
    where lower(it.email) = lower(p_email)
      and lower(it.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and it.role = 'tenant'
      and it.landlord_id = p_landlord_id
      and it.used = false
      and it.expires_at > now()
      and (
        it.metadata ->> 'tenant_id' = p_tenant_id::text
        or (it.metadata ? 'tenant_id') = false
      )
  )
$$;

create or replace function public.create_super_admin(email text, password text)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  new_user_id uuid := gen_random_uuid();
  normalized_email text := lower(trim(email));
begin
  if normalized_email = '' or password = '' then
    raise exception 'Email and password are required.';
  end if;

  if exists (select 1 from auth.users u where lower(u.email) = normalized_email) then
    raise exception 'A user with email % already exists.', normalized_email;
  end if;

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    new_user_id,
    'authenticated',
    'authenticated',
    normalized_email,
    crypt(password, gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

  insert into auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  )
  values (
    gen_random_uuid(),
    new_user_id,
    new_user_id::text,
    jsonb_build_object(
      'sub', new_user_id::text,
      'email', normalized_email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    now(),
    now(),
    now()
  );

  insert into public.profiles (id, landlord_id, full_name, phone, email, role)
  values (new_user_id, null, 'Mushavo Super Admin', null, normalized_email, 'super_admin');

  return new_user_id;
end;
$$;

drop function if exists public.validate_invite_token(text);

create or replace function public.validate_invite_token(p_token text)
returns table (
  id uuid,
  token text,
  email text,
  role public.user_role,
  landlord_id uuid,
  metadata jsonb,
  used boolean,
  expires_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select it.id, it.token, it.email, it.role, it.landlord_id, it.metadata, it.used, it.expires_at, it.created_at
  from public.invite_tokens it
  where it.token = p_token
    and it.used = false
    and it.expires_at > now();

  if not found then
    if not exists (select 1 from public.invite_tokens it where it.token = p_token) then
      raise exception 'Invite token not found.';
    elsif exists (select 1 from public.invite_tokens it where it.token = p_token and it.used = true) then
      raise exception 'Invite token has already been used.';
    else
      raise exception 'Invite token has expired.';
    end if;
  end if;
end;
$$;

create or replace function public.register_staff_with_landlord_code(
  p_full_name text,
  p_phone text,
  p_landlord_code text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  staff_id uuid := auth.uid();
  staff_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  landlord_record public.profiles%rowtype;
  existing_profile public.profiles%rowtype;
  request_id uuid;
begin
  if staff_id is null or staff_email = '' then
    raise exception 'You must be signed in to register as staff.';
  end if;

  select *
  into landlord_record
  from public.profiles
  where landlord_code = trim(p_landlord_code)
    and role = 'landlord'
    and archived_at is null;

  if not found then
    raise exception 'Landlord code not found.';
  end if;

  select *
  into existing_profile
  from public.profiles
  where id = staff_id;

  if found and existing_profile.role <> 'staff' then
    raise exception 'This login is already used by another Mushavo account type.';
  end if;

  if not found then
    raise exception 'Freelancer staff accounts must be created by admin invite before requesting landlord access.';
  end if;

  if existing_profile.staff_type <> 'freelancer' then
    raise exception 'This staff account can only work for its original landlord.';
  end if;

  if (
    select count(*)
    from public.staff_permissions sp
    where sp.staff_profile_id = staff_id
      and sp.status = 'approved'
  ) >= coalesce((select p.staff_max_landlords from public.profiles p where p.id = staff_id), 2) then
    raise exception 'You have reached your landlord limit. Contact support to add more.';
  end if;

  if exists (
    select 1 from public.staff_permissions sp
    where sp.staff_profile_id = staff_id
      and sp.landlord_id = landlord_record.id
      and sp.status = 'approved'
  ) then
    raise exception 'You already have access to this landlord.';
  end if;

  insert into public.staff_landlord_requests (
    staff_profile_id,
    landlord_id,
    landlord_code,
    status
  )
  values (
    staff_id,
    landlord_record.id,
    trim(p_landlord_code),
    'pending'
  )
  on conflict (staff_profile_id, landlord_id, status)
  do update set requested_at = now()
  returning id into request_id;

  return request_id;
end;
$$;

drop function if exists public.register_free_landlord(text, text);
drop function if exists public.register_free_landlord(text, text, uuid);

create or replace function public.register_free_landlord(
  p_full_name text,
  p_phone text default '',
  p_country_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  user_email text;
  normalized_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to create a landlord account.';
  end if;

  user_email := lower(coalesce(auth.jwt() ->> 'email', ''));

  if trim(coalesce(p_full_name, '')) = '' then
    raise exception 'Full name is required.';
  end if;

  if p_country_id is null then
    raise exception 'Country is required.';
  end if;

  if not exists (
    select 1
    from public.countries c
    where c.id = p_country_id
      and c.archived_at is null
  ) then
    raise exception 'Select a valid country before creating the landlord account.';
  end if;

  if user_email = '' then
    raise exception 'Email could not be read from the signed in user.';
  end if;

  if exists (select 1 from public.profiles p where p.id = auth.uid()) then
    raise exception 'This login already has a Mushavo profile.';
  end if;

  if exists (select 1 from public.profiles p where lower(p.email) = user_email and p.archived_at is null) then
    raise exception 'A Mushavo account already exists for this email.';
  end if;

  if exists (select 1 from public.tenants t where lower(t.email) = user_email and t.archived_at is null) then
    raise exception 'A Mushavo account already exists for this email.';
  end if;

  if exists (
    select 1
    from public.invite_tokens it
    where lower(it.email) = user_email
      and it.used = false
      and it.expires_at > now()
  ) then
    raise exception 'A Mushavo account already exists for this email.';
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from public.profiles p
    where regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') = normalized_phone
      and p.archived_at is null
  ) then
    raise exception 'A Mushavo account already exists for this phone number.';
  end if;

  if length(normalized_phone) >= 6 and exists (
    select 1
    from public.tenants t
    where regexp_replace(coalesce(t.phone, ''), '\D', '', 'g') = normalized_phone
      and t.archived_at is null
  ) then
    raise exception 'A Mushavo account already exists for this phone number.';
  end if;

  insert into public.profiles (
    id,
    landlord_id,
    full_name,
    phone,
    email,
    role,
    country_id,
    email_verified,
    verified_at
  )
  values (
    auth.uid(),
    null,
    trim(p_full_name),
    coalesce(trim(p_phone), ''),
    user_email,
    'landlord',
    p_country_id,
    true,
    now()
  );

  update public.landlord_subscriptions
  set
    subscription_plan = 'free',
    property_limit = 1,
    unit_limit = 1,
    personal_staff_limit = 0,
    partner_connection_limit = 1,
    status = 'active',
    expires_at = '2099-12-31 23:59:59+00',
    country_id = p_country_id,
    notes = 'Free landlord plan: 1 property, 1 unit, 0 personal staff, and 1 IPM or PMC connection.',
    updated_at = now()
  where landlord_id = auth.uid();

  if not found then
    insert into public.landlord_subscriptions (
      landlord_id,
      subscription_plan,
      property_limit,
      unit_limit,
      personal_staff_limit,
      partner_connection_limit,
      status,
      expires_at,
      country_id,
      notes
    )
    values (
      auth.uid(),
      'free',
      1,
      1,
      0,
      1,
      'active',
      '2099-12-31 23:59:59+00',
      p_country_id,
      'Free landlord plan: 1 property, 1 unit, 0 personal staff, and 1 IPM or PMC connection.'
    );
  end if;

  return auth.uid();
end;
$$;

drop function if exists public.search_landlord_by_email(text);

create or replace function public.search_landlord_by_email(p_email text)
returns table (
  landlord_id uuid,
  full_name text,
  email text,
  phone text,
  account_found boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester public.profiles%rowtype;
begin
  select *
  into requester
  from public.profiles
  where id = auth.uid()
    and archived_at is null;

  if not found or not (
    requester.role = 'management_leader'
    or (requester.role = 'staff' and requester.staff_type = 'freelancer')
  ) then
    raise exception 'Only IPMs and PMC leaders can search landlord accounts.';
  end if;

  return query
  select p.id, p.full_name, p.email, p.phone, true
  from public.profiles p
  where p.role = 'landlord'
    and p.archived_at is null
    and lower(p.email) = lower(trim(p_email))
  limit 1;

  if not found then
    return query select null::uuid, null::text, lower(trim(p_email)), null::text, false;
  end if;
end;
$$;

drop function if exists public.search_tenant_by_email(text);

create or replace function public.search_tenant_by_email(p_email text)
returns table (
  tenant_profile_id uuid,
  full_name text,
  email text,
  phone text,
  account_found boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester public.profiles%rowtype;
  normalized_email text := lower(trim(coalesce(p_email, '')));
  tenant_found boolean := false;
begin
  select *
  into requester
  from public.profiles
  where id = auth.uid()
    and archived_at is null;

  if not found then
    raise exception 'Profile not found.';
  end if;

  if normalized_email = '' then
    raise exception 'Tenant email is required.';
  end if;

  if not (
    requester.role = 'landlord'
    or (
      requester.role = 'staff'
      and public.current_landlord_id() is not null
      and (
        public.staff_permission_flag('can_add_tenants')
        or public.staff_permission_flag('can_create_leases')
        or public.staff_permission_flag('can_manage_leases')
      )
    )
    or (
      requester.role in ('management_leader', 'management_staff')
      and public.current_landlord_id() is not null
      and (
        public.management_permission_flag('can_add_tenants')
        or public.management_permission_flag('can_create_leases')
        or public.management_permission_flag('can_manage_leases')
      )
    )
  ) then
    raise exception 'You do not have permission to search tenant accounts.';
  end if;

  select exists (
    select 1
    from public.profiles p
    where p.role = 'tenant'
      and p.archived_at is null
      and lower(p.email) = normalized_email
  )
  into tenant_found;

  if tenant_found then
    return query
    select p.id, p.full_name, p.email, p.phone, true
    from public.profiles p
    where p.role = 'tenant'
      and p.archived_at is null
      and lower(p.email) = normalized_email
    limit 1;
  else
    return query select null::uuid, null::text, normalized_email, null::text, false;
  end if;
end;
$$;

drop function if exists public.validate_landlord_code(text);

create or replace function public.validate_landlord_code(p_landlord_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.role = 'landlord'
      and p.archived_at is null
      and p.landlord_code = trim(p_landlord_code)
  )
$$;

drop function if exists public.request_staff_landlord_access(text);

create or replace function public.request_staff_landlord_access(p_landlord_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_record public.profiles%rowtype;
begin
  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found or profile_record.role <> 'staff' then
    raise exception 'Only staff accounts can request landlord access.';
  end if;

  return public.register_staff_with_landlord_code(profile_record.full_name, profile_record.phone, p_landlord_code);
end;
$$;

drop function if exists public.request_staff_landlord_access_by_email(text);

create or replace function public.request_staff_landlord_access_by_email(p_landlord_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_record public.profiles%rowtype;
  landlord_record public.profiles%rowtype;
begin
  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found or profile_record.role <> 'staff' or profile_record.staff_type <> 'freelancer' then
    raise exception 'Only IPM accounts can request landlord access by email.';
  end if;

  select *
  into landlord_record
  from public.profiles
  where role = 'landlord'
    and archived_at is null
    and lower(email) = lower(trim(p_landlord_email));

  if not found then
    raise exception 'Landlord account not found.';
  end if;

  return public.register_staff_with_landlord_code(profile_record.full_name, profile_record.phone, landlord_record.landlord_code);
end;
$$;

drop function if exists public.invite_landlord_from_ipm(text);

create or replace function public.invite_landlord_from_ipm(p_landlord_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_record public.profiles%rowtype;
  new_token text := public.generate_invite_token(32);
begin
  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found or profile_record.role <> 'staff' or profile_record.staff_type <> 'freelancer' then
    raise exception 'Only IPMs can invite landlords.';
  end if;

  if trim(coalesce(p_landlord_email, '')) = '' then
    raise exception 'Landlord email is required.';
  end if;

  if exists (
    select 1 from public.profiles p
    where lower(p.email) = lower(trim(p_landlord_email))
      and p.archived_at is null
  ) then
    raise exception 'This landlord is already on Mushavo. Send an access request instead.';
  end if;

  insert into public.invite_tokens (token, email, role, expires_at, metadata, country_id)
  values (
    new_token,
    lower(trim(p_landlord_email)),
    'landlord',
    now() + interval '14 days',
    jsonb_build_object(
      'source', 'ipm_landlord_invite',
      'requested_by_type', 'ipm',
      'staff_profile_id', auth.uid(),
      'subscription_plan', 'free',
      'subscription_status', 'active',
      'subscription_expires_at', '2099-12-31 23:59:59+00',
      'property_limit', 1,
      'unit_limit', 1,
      'personal_staff_limit', 0,
      'partner_connection_limit', 1
    ),
    profile_record.country_id
  );

  return new_token;
end;
$$;

create or replace function public.approve_staff_landlord_request(p_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  request_record public.staff_landlord_requests%rowtype;
  staff_record public.profiles%rowtype;
  permission_id uuid;
begin
  select *
  into request_record
  from public.staff_landlord_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Staff request not found.';
  end if;

  if request_record.landlord_id <> auth.uid() then
    raise exception 'Only this landlord can approve the request.';
  end if;

  if request_record.status <> 'pending' then
    raise exception 'This request has already been reviewed.';
  end if;

  select *
  into staff_record
  from public.profiles
  where id = request_record.staff_profile_id
    and role = 'staff'
    and archived_at is null;

  if not found then
    raise exception 'Staff profile not found.';
  end if;

  if staff_record.staff_type = 'freelancer' and not public.landlord_can_accept_partner_connection(request_record.landlord_id) then
    raise exception 'This landlord has reached the IPM/PMC connection limit for their subscription.';
  end if;

  if staff_record.staff_type <> 'freelancer' and (
    select count(*)
    from public.staff_permissions sp
    join public.profiles p on p.id = sp.staff_profile_id
    where sp.landlord_id = request_record.landlord_id
      and sp.status = 'approved'
      and p.role = 'staff'
      and coalesce(p.staff_type, 'landlord') <> 'freelancer'
      and p.archived_at is null
  ) >= coalesce((
    select ls.personal_staff_limit
    from public.landlord_subscriptions ls
    where ls.landlord_id = request_record.landlord_id
    order by ls.created_at desc
    limit 1
  ), 1) then
    raise exception 'This landlord has reached the personal staff limit for their subscription.';
  end if;

  if (
    select count(*)
    from public.staff_permissions sp
    where sp.staff_profile_id = request_record.staff_profile_id
      and sp.status = 'approved'
  ) >= coalesce((select p.staff_max_landlords from public.profiles p where p.id = request_record.staff_profile_id), 2) then
    raise exception 'This staff member has reached their landlord limit.';
  end if;

  insert into public.staff_permissions (
    landlord_id,
    staff_profile_id,
    all_properties,
    property_ids,
    status,
    accepted_at
  )
  values (
    request_record.landlord_id,
    request_record.staff_profile_id,
    true,
    '{}'::uuid[],
    'approved',
    now()
  )
  on conflict (landlord_id, staff_profile_id)
  do update set status = 'approved', accepted_at = now()
  returning id into permission_id;

  update public.staff_landlord_requests
  set status = 'approved',
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where id = p_request_id;

  update public.profiles p
  set landlord_id = coalesce(p.landlord_id, request_record.landlord_id)
  where p.id = request_record.staff_profile_id
    and p.role = 'staff';

  return permission_id;
end;
$$;

create or replace function public.approve_staff_landlord_request_with_permissions(
  p_request_id uuid,
  p_permissions jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  request_record public.staff_landlord_requests%rowtype;
  staff_record public.profiles%rowtype;
  permission_id uuid;
  selected_property_ids uuid[];
  all_properties_value boolean;
begin
  select *
  into request_record
  from public.staff_landlord_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Staff request not found.';
  end if;

  if request_record.landlord_id <> auth.uid() then
    raise exception 'Only this landlord can approve the request.';
  end if;

  if request_record.status <> 'pending' then
    raise exception 'This request has already been reviewed.';
  end if;

  select *
  into staff_record
  from public.profiles
  where id = request_record.staff_profile_id
    and role = 'staff'
    and archived_at is null;

  if not found then
    raise exception 'Staff profile not found.';
  end if;

  if staff_record.staff_type = 'freelancer' and not public.landlord_can_accept_partner_connection(request_record.landlord_id) then
    raise exception 'This landlord has reached the IPM/PMC connection limit for their subscription.';
  end if;

  if staff_record.staff_type <> 'freelancer' and (
    select count(*)
    from public.staff_permissions sp
    join public.profiles p on p.id = sp.staff_profile_id
    where sp.landlord_id = request_record.landlord_id
      and sp.status = 'approved'
      and p.role = 'staff'
      and coalesce(p.staff_type, 'landlord') <> 'freelancer'
      and p.archived_at is null
  ) >= coalesce((
    select ls.personal_staff_limit
    from public.landlord_subscriptions ls
    where ls.landlord_id = request_record.landlord_id
    order by ls.created_at desc
    limit 1
  ), 1) then
    raise exception 'This landlord has reached the personal staff limit for their subscription.';
  end if;

  if (
    select count(*)
    from public.staff_permissions sp
    where sp.staff_profile_id = request_record.staff_profile_id
      and sp.status = 'approved'
  ) >= coalesce((select p.staff_max_landlords from public.profiles p where p.id = request_record.staff_profile_id), 2) then
    raise exception 'This staff member has reached their landlord limit.';
  end if;

  all_properties_value := coalesce((p_permissions ->> 'all_properties')::boolean, false);
  selected_property_ids := case
    when all_properties_value then '{}'::uuid[]
    else public.uuid_array_from_jsonb(p_permissions -> 'property_ids')
  end;

  if not all_properties_value and coalesce(array_length(selected_property_ids, 1), 0) = 0 then
    raise exception 'Select at least one property, or choose All properties.';
  end if;

  if exists (
    select 1
    from unnest(selected_property_ids) selected_property(property_id)
    where not exists (
      select 1
      from public.properties p
      where p.id = selected_property.property_id
        and p.landlord_id = request_record.landlord_id
        and p.archived_at is null
    )
  ) then
    raise exception 'Selected properties must belong to this landlord.';
  end if;

  insert into public.staff_permissions (
    landlord_id,
    staff_profile_id,
    all_properties,
    property_ids,
    can_view_properties,
    can_add_properties,
    can_edit_properties,
    can_archive_properties,
    can_view_units,
    can_add_units,
    can_edit_units,
    can_archive_units,
    can_mark_units_vacant,
    can_view_tenants,
    can_add_tenants,
    can_edit_tenants,
    can_archive_tenants,
    can_view_leases,
    can_create_leases,
    can_edit_leases,
    can_terminate_leases,
    can_view_lease_documents,
    can_upload_lease_documents,
    can_manage_leases,
    can_view_payments,
    can_log_payments,
    can_reject_payments,
    can_view_payment_proofs,
    can_verify_payments,
    can_manage_maintenance,
    can_create_maintenance,
    can_assign_maintenance,
    can_add_resolution_notes,
    can_manage_staff,
    can_view_finance,
    status,
    accepted_at
  )
  values (
    request_record.landlord_id,
    request_record.staff_profile_id,
    all_properties_value,
    selected_property_ids,
    coalesce((p_permissions ->> 'can_view_properties')::boolean, true),
    coalesce((p_permissions ->> 'can_add_properties')::boolean, false),
    coalesce((p_permissions ->> 'can_edit_properties')::boolean, false),
    coalesce((p_permissions ->> 'can_archive_properties')::boolean, false),
    coalesce((p_permissions ->> 'can_view_units')::boolean, false),
    coalesce((p_permissions ->> 'can_add_units')::boolean, false),
    coalesce((p_permissions ->> 'can_edit_units')::boolean, false),
    coalesce((p_permissions ->> 'can_archive_units')::boolean, false),
    coalesce((p_permissions ->> 'can_mark_units_vacant')::boolean, false),
    coalesce((p_permissions ->> 'can_view_tenants')::boolean, false),
    coalesce((p_permissions ->> 'can_add_tenants')::boolean, false),
    coalesce((p_permissions ->> 'can_edit_tenants')::boolean, false),
    coalesce((p_permissions ->> 'can_archive_tenants')::boolean, false),
    coalesce((p_permissions ->> 'can_view_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_create_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_edit_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_terminate_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_view_lease_documents')::boolean, false),
    coalesce((p_permissions ->> 'can_upload_lease_documents')::boolean, false),
    coalesce((p_permissions ->> 'can_manage_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_view_payments')::boolean, false),
    coalesce((p_permissions ->> 'can_log_payments')::boolean, false),
    coalesce((p_permissions ->> 'can_reject_payments')::boolean, false),
    coalesce((p_permissions ->> 'can_view_payment_proofs')::boolean, false),
    coalesce((p_permissions ->> 'can_verify_payments')::boolean, false),
    coalesce((p_permissions ->> 'can_manage_maintenance')::boolean, false),
    coalesce((p_permissions ->> 'can_create_maintenance')::boolean, false),
    coalesce((p_permissions ->> 'can_assign_maintenance')::boolean, false),
    coalesce((p_permissions ->> 'can_add_resolution_notes')::boolean, false),
    coalesce((p_permissions ->> 'can_manage_staff')::boolean, false),
    coalesce((p_permissions ->> 'can_view_finance')::boolean, false),
    'approved',
    now()
  )
  on conflict (landlord_id, staff_profile_id)
  do update set
    all_properties = excluded.all_properties,
    property_ids = excluded.property_ids,
    can_view_properties = excluded.can_view_properties,
    can_add_properties = excluded.can_add_properties,
    can_edit_properties = excluded.can_edit_properties,
    can_archive_properties = excluded.can_archive_properties,
    can_view_units = excluded.can_view_units,
    can_add_units = excluded.can_add_units,
    can_edit_units = excluded.can_edit_units,
    can_archive_units = excluded.can_archive_units,
    can_mark_units_vacant = excluded.can_mark_units_vacant,
    can_view_tenants = excluded.can_view_tenants,
    can_add_tenants = excluded.can_add_tenants,
    can_edit_tenants = excluded.can_edit_tenants,
    can_archive_tenants = excluded.can_archive_tenants,
    can_view_leases = excluded.can_view_leases,
    can_create_leases = excluded.can_create_leases,
    can_edit_leases = excluded.can_edit_leases,
    can_terminate_leases = excluded.can_terminate_leases,
    can_view_lease_documents = excluded.can_view_lease_documents,
    can_upload_lease_documents = excluded.can_upload_lease_documents,
    can_manage_leases = excluded.can_manage_leases,
    can_view_payments = excluded.can_view_payments,
    can_log_payments = excluded.can_log_payments,
    can_reject_payments = excluded.can_reject_payments,
    can_view_payment_proofs = excluded.can_view_payment_proofs,
    can_verify_payments = excluded.can_verify_payments,
    can_manage_maintenance = excluded.can_manage_maintenance,
    can_create_maintenance = excluded.can_create_maintenance,
    can_assign_maintenance = excluded.can_assign_maintenance,
    can_add_resolution_notes = excluded.can_add_resolution_notes,
    can_manage_staff = excluded.can_manage_staff,
    can_view_finance = excluded.can_view_finance,
    status = 'approved',
    accepted_at = now()
  returning id into permission_id;

  update public.staff_landlord_requests
  set status = 'approved',
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where id = p_request_id;

  update public.profiles p
  set landlord_id = coalesce(p.landlord_id, request_record.landlord_id)
  where p.id = request_record.staff_profile_id
    and p.role = 'staff';

  return permission_id;
end;
$$;

create or replace function public.reject_staff_landlord_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.staff_landlord_requests
  set status = 'rejected',
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where id = p_request_id
    and landlord_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'Pending staff request not found for this landlord.';
  end if;
end;
$$;

create or replace function public.switch_staff_landlord(p_landlord_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.staff_permissions sp
    where sp.staff_profile_id = auth.uid()
      and sp.landlord_id = p_landlord_id
      and sp.status = 'approved'
  ) then
    raise exception 'You do not have approved access to this landlord.';
  end if;

  update public.profiles
  set landlord_id = p_landlord_id
  where id = auth.uid()
    and role = 'staff';
end;
$$;

drop function if exists public.request_management_landlord_access(text);

create or replace function public.request_management_landlord_access(p_landlord_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_record public.profiles%rowtype;
  company_record public.management_companies%rowtype;
  landlord_record public.profiles%rowtype;
  request_id uuid;
begin
  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found or profile_record.role <> 'management_leader' then
    raise exception 'Only management leaders can request landlord access.';
  end if;

  select *
  into company_record
  from public.management_companies
  where leader_profile_id = auth.uid()
    and archived_at is null;

  if not found then
    raise exception 'Management company record not found.';
  end if;

  if company_record.access_suspended_at is not null or company_record.subscription_status = 'suspended' then
    raise exception 'This management company account is suspended.';
  end if;

  if company_record.subscription_expires_at is not null and company_record.subscription_expires_at < current_date then
    raise exception 'This management company subscription has expired.';
  end if;

  select *
  into landlord_record
  from public.profiles
  where role = 'landlord'
    and archived_at is null
    and landlord_code = trim(p_landlord_code);

  if not found then
    raise exception 'Landlord code not found.';
  end if;

  if (
    select count(*)
    from public.management_landlord_permissions mlp
    where mlp.management_company_id = company_record.id
      and mlp.status = 'approved'
  ) >= company_record.max_landlords then
    raise exception 'This management company has reached its landlord limit.';
  end if;

  if exists (
    select 1
    from public.management_landlord_permissions mlp
    where mlp.management_company_id = company_record.id
      and mlp.landlord_id = landlord_record.id
      and mlp.status = 'approved'
  ) then
    raise exception 'This management company already has access to this landlord.';
  end if;

  update public.management_landlord_requests
  set
    leader_profile_id = auth.uid(),
    landlord_code = trim(p_landlord_code),
    requested_at = now(),
    reviewed_at = null,
    reviewed_by = null,
    notes = null
  where management_company_id = company_record.id
    and landlord_id = landlord_record.id
    and status = 'pending'
  returning id into request_id;

  if request_id is null then
    insert into public.management_landlord_requests (
      management_company_id,
      leader_profile_id,
      landlord_id,
      landlord_code,
      status
    )
    values (
      company_record.id,
      auth.uid(),
      landlord_record.id,
      trim(p_landlord_code),
      'pending'
    )
    returning id into request_id;
  end if;

  return request_id;
end;
$$;

drop function if exists public.request_management_landlord_access_by_email(text);

create or replace function public.request_management_landlord_access_by_email(p_landlord_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  landlord_record public.profiles%rowtype;
begin
  select *
  into landlord_record
  from public.profiles
  where role = 'landlord'
    and archived_at is null
    and lower(email) = lower(trim(p_landlord_email));

  if not found then
    raise exception 'Landlord account not found.';
  end if;

  return public.request_management_landlord_access(landlord_record.landlord_code);
end;
$$;

drop function if exists public.invite_landlord_from_management(text);

create or replace function public.invite_landlord_from_management(p_landlord_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_record public.profiles%rowtype;
  company_record public.management_companies%rowtype;
  new_token text := public.generate_invite_token(32);
begin
  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found or profile_record.role <> 'management_leader' then
    raise exception 'Only PMC leaders can invite landlords.';
  end if;

  select *
  into company_record
  from public.management_companies
  where leader_profile_id = auth.uid()
    and archived_at is null;

  if not found then
    raise exception 'PMC account not found.';
  end if;

  if trim(coalesce(p_landlord_email, '')) = '' then
    raise exception 'Landlord email is required.';
  end if;

  if exists (
    select 1 from public.profiles p
    where lower(p.email) = lower(trim(p_landlord_email))
      and p.archived_at is null
  ) then
    raise exception 'This landlord is already on Mushavo. Send an access request instead.';
  end if;

  insert into public.invite_tokens (token, email, role, expires_at, metadata, country_id)
  values (
    new_token,
    lower(trim(p_landlord_email)),
    'landlord',
    now() + interval '14 days',
    jsonb_build_object(
      'source', 'pmc_landlord_invite',
      'requested_by_type', 'management',
      'management_company_id', company_record.id,
      'leader_profile_id', auth.uid(),
      'subscription_plan', 'free',
      'subscription_status', 'active',
      'subscription_expires_at', '2099-12-31 23:59:59+00',
      'property_limit', 1,
      'unit_limit', 1,
      'personal_staff_limit', 0,
      'partner_connection_limit', 1
    ),
    company_record.country_id
  );

  return new_token;
end;
$$;

create or replace function public.approve_management_landlord_request(p_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  request_record public.management_landlord_requests%rowtype;
  company_record public.management_companies%rowtype;
  permission_id uuid;
begin
  select *
  into request_record
  from public.management_landlord_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Management request not found.';
  end if;

  if request_record.landlord_id <> auth.uid() then
    raise exception 'Only this landlord can approve the request.';
  end if;

  if request_record.status <> 'pending' then
    raise exception 'This request has already been reviewed.';
  end if;

  if not public.landlord_can_accept_partner_connection(request_record.landlord_id) then
    raise exception 'This landlord has reached the IPM/PMC connection limit for their subscription.';
  end if;

  select *
  into company_record
  from public.management_companies
  where id = request_record.management_company_id
    and archived_at is null;

  if not found then
    raise exception 'Management company record not found.';
  end if;

  if (
    select count(*)
    from public.management_landlord_permissions mlp
    where mlp.management_company_id = company_record.id
      and mlp.status = 'approved'
  ) >= company_record.max_landlords then
    raise exception 'This management company has reached its landlord limit.';
  end if;

  insert into public.management_landlord_permissions (
    management_company_id,
    leader_profile_id,
    landlord_id,
    all_properties,
    property_ids,
    can_view_properties,
    can_view_units,
    can_archive_units,
    can_view_tenants,
    can_view_leases,
    can_manage_maintenance,
    can_create_maintenance,
    can_assign_maintenance,
    can_add_resolution_notes,
    can_view_payments,
    can_view_payment_proofs,
    can_manage_staff,
    status,
    accepted_at
  )
  values (
    request_record.management_company_id,
    request_record.leader_profile_id,
    request_record.landlord_id,
    true,
    '{}'::uuid[],
    true,
    false,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    'approved',
    now()
  )
  on conflict (management_company_id, landlord_id)
  do update set status = 'approved', accepted_at = now()
  returning id into permission_id;

  update public.management_landlord_requests
  set status = 'approved',
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where id = p_request_id;

  return permission_id;
end;
$$;

create or replace function public.approve_management_landlord_request_with_permissions(
  p_request_id uuid,
  p_permissions jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  request_record public.management_landlord_requests%rowtype;
  company_record public.management_companies%rowtype;
  permission_id uuid;
  selected_property_ids uuid[];
  all_properties_value boolean;
begin
  select *
  into request_record
  from public.management_landlord_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Management request not found.';
  end if;

  if request_record.landlord_id <> auth.uid() then
    raise exception 'Only this landlord can approve the request.';
  end if;

  if request_record.status <> 'pending' then
    raise exception 'This request has already been reviewed.';
  end if;

  if not public.landlord_can_accept_partner_connection(request_record.landlord_id) then
    raise exception 'This landlord has reached the IPM/PMC connection limit for their subscription.';
  end if;

  select *
  into company_record
  from public.management_companies
  where id = request_record.management_company_id
    and archived_at is null;

  if not found then
    raise exception 'Management company record not found.';
  end if;

  if (
    select count(*)
    from public.management_landlord_permissions mlp
    where mlp.management_company_id = company_record.id
      and mlp.status = 'approved'
      and mlp.landlord_id <> request_record.landlord_id
  ) >= company_record.max_landlords then
    raise exception 'This management company has reached its landlord limit.';
  end if;

  all_properties_value := coalesce((p_permissions ->> 'all_properties')::boolean, false);
  selected_property_ids := case
    when all_properties_value then '{}'::uuid[]
    else public.uuid_array_from_jsonb(p_permissions -> 'property_ids')
  end;

  if not all_properties_value and coalesce(array_length(selected_property_ids, 1), 0) = 0 then
    raise exception 'Select at least one property, or choose All properties.';
  end if;

  if exists (
    select 1
    from unnest(selected_property_ids) selected_property(property_id)
    where not exists (
      select 1
      from public.properties p
      where p.id = selected_property.property_id
        and p.landlord_id = request_record.landlord_id
        and p.archived_at is null
    )
  ) then
    raise exception 'Selected properties must belong to this landlord.';
  end if;

  insert into public.management_landlord_permissions (
    management_company_id,
    leader_profile_id,
    landlord_id,
    all_properties,
    property_ids,
    can_view_properties,
    can_add_properties,
    can_edit_properties,
    can_archive_properties,
    can_view_units,
    can_add_units,
    can_edit_units,
    can_archive_units,
    can_mark_units_vacant,
    can_view_tenants,
    can_add_tenants,
    can_edit_tenants,
    can_archive_tenants,
    can_view_leases,
    can_create_leases,
    can_edit_leases,
    can_terminate_leases,
    can_view_lease_documents,
    can_upload_lease_documents,
    can_manage_leases,
    can_view_payments,
    can_log_payments,
    can_reject_payments,
    can_view_payment_proofs,
    can_verify_payments,
    can_manage_maintenance,
    can_create_maintenance,
    can_assign_maintenance,
    can_add_resolution_notes,
    can_manage_staff,
    can_view_finance,
    status,
    accepted_at
  )
  values (
    request_record.management_company_id,
    request_record.leader_profile_id,
    request_record.landlord_id,
    all_properties_value,
    selected_property_ids,
    coalesce((p_permissions ->> 'can_view_properties')::boolean, true),
    coalesce((p_permissions ->> 'can_add_properties')::boolean, false),
    coalesce((p_permissions ->> 'can_edit_properties')::boolean, false),
    coalesce((p_permissions ->> 'can_archive_properties')::boolean, false),
    coalesce((p_permissions ->> 'can_view_units')::boolean, false),
    coalesce((p_permissions ->> 'can_add_units')::boolean, false),
    coalesce((p_permissions ->> 'can_edit_units')::boolean, false),
    coalesce((p_permissions ->> 'can_archive_units')::boolean, false),
    coalesce((p_permissions ->> 'can_mark_units_vacant')::boolean, false),
    coalesce((p_permissions ->> 'can_view_tenants')::boolean, false),
    coalesce((p_permissions ->> 'can_add_tenants')::boolean, false),
    coalesce((p_permissions ->> 'can_edit_tenants')::boolean, false),
    coalesce((p_permissions ->> 'can_archive_tenants')::boolean, false),
    coalesce((p_permissions ->> 'can_view_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_create_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_edit_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_terminate_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_view_lease_documents')::boolean, false),
    coalesce((p_permissions ->> 'can_upload_lease_documents')::boolean, false),
    coalesce((p_permissions ->> 'can_manage_leases')::boolean, false),
    coalesce((p_permissions ->> 'can_view_payments')::boolean, false),
    coalesce((p_permissions ->> 'can_log_payments')::boolean, false),
    coalesce((p_permissions ->> 'can_reject_payments')::boolean, false),
    coalesce((p_permissions ->> 'can_view_payment_proofs')::boolean, false),
    coalesce((p_permissions ->> 'can_verify_payments')::boolean, false),
    coalesce((p_permissions ->> 'can_manage_maintenance')::boolean, false),
    coalesce((p_permissions ->> 'can_create_maintenance')::boolean, false),
    coalesce((p_permissions ->> 'can_assign_maintenance')::boolean, false),
    coalesce((p_permissions ->> 'can_add_resolution_notes')::boolean, false),
    coalesce((p_permissions ->> 'can_manage_staff')::boolean, true),
    coalesce((p_permissions ->> 'can_view_finance')::boolean, false),
    'approved',
    now()
  )
  on conflict (management_company_id, landlord_id)
  do update set
    leader_profile_id = excluded.leader_profile_id,
    all_properties = excluded.all_properties,
    property_ids = excluded.property_ids,
    can_view_properties = excluded.can_view_properties,
    can_add_properties = excluded.can_add_properties,
    can_edit_properties = excluded.can_edit_properties,
    can_archive_properties = excluded.can_archive_properties,
    can_view_units = excluded.can_view_units,
    can_add_units = excluded.can_add_units,
    can_edit_units = excluded.can_edit_units,
    can_archive_units = excluded.can_archive_units,
    can_mark_units_vacant = excluded.can_mark_units_vacant,
    can_view_tenants = excluded.can_view_tenants,
    can_add_tenants = excluded.can_add_tenants,
    can_edit_tenants = excluded.can_edit_tenants,
    can_archive_tenants = excluded.can_archive_tenants,
    can_view_leases = excluded.can_view_leases,
    can_create_leases = excluded.can_create_leases,
    can_edit_leases = excluded.can_edit_leases,
    can_terminate_leases = excluded.can_terminate_leases,
    can_view_lease_documents = excluded.can_view_lease_documents,
    can_upload_lease_documents = excluded.can_upload_lease_documents,
    can_manage_leases = excluded.can_manage_leases,
    can_view_payments = excluded.can_view_payments,
    can_log_payments = excluded.can_log_payments,
    can_reject_payments = excluded.can_reject_payments,
    can_view_payment_proofs = excluded.can_view_payment_proofs,
    can_verify_payments = excluded.can_verify_payments,
    can_manage_maintenance = excluded.can_manage_maintenance,
    can_create_maintenance = excluded.can_create_maintenance,
    can_assign_maintenance = excluded.can_assign_maintenance,
    can_add_resolution_notes = excluded.can_add_resolution_notes,
    can_manage_staff = excluded.can_manage_staff,
    can_view_finance = excluded.can_view_finance,
    status = 'approved',
    accepted_at = now()
  returning id into permission_id;

  update public.management_landlord_requests
  set status = 'approved',
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where id = p_request_id;

  return permission_id;
end;
$$;

create or replace function public.unassign_management_landlord_permission(p_permission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.management_landlord_permissions
  set status = 'suspended'
  where id = p_permission_id
    and landlord_id = auth.uid()
    and status = 'approved';

  if not found then
    raise exception 'Approved management company assignment not found for this landlord.';
  end if;
end;
$$;

create or replace function public.drop_partner_landlord(p_partner_type text, p_permission_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_partner_type = 'pmc' then
    update public.management_landlord_permissions mlp
    set status = 'suspended'
    where mlp.id = p_permission_id
      and mlp.status = 'approved'
      and exists (
        select 1 from public.management_companies mc
        where mc.id = mlp.management_company_id
          and mc.leader_profile_id = auth.uid()
      );
  elsif p_partner_type = 'ipm' then
    update public.staff_permissions sp
    set status = 'suspended'
    where sp.id = p_permission_id
      and sp.status = 'approved'
      and sp.staff_profile_id = auth.uid();
  else
    raise exception 'Unknown partner type.';
  end if;

  if not found then
    raise exception 'Approved landlord assignment was not found for this account.';
  end if;
end;
$$;

drop function if exists public.update_partner_landlord_contract(text, uuid, date);

create or replace function public.update_partner_landlord_contract(
  p_partner_type text,
  p_permission_id uuid,
  p_contract_start_date date,
  p_contract_end_date date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_partner_type = 'pmc' then
    update public.management_landlord_permissions mlp
    set contract_start_date = p_contract_start_date,
        contract_end_date = p_contract_end_date
    where mlp.id = p_permission_id
      and mlp.status = 'approved'
      and exists (
        select 1 from public.management_companies mc
        where mc.id = mlp.management_company_id
          and mc.leader_profile_id = auth.uid()
      );
  elsif p_partner_type = 'ipm' then
    update public.staff_permissions sp
    set contract_start_date = p_contract_start_date,
        contract_end_date = p_contract_end_date
    where sp.id = p_permission_id
      and sp.status = 'approved'
      and sp.staff_profile_id = auth.uid();
  else
    raise exception 'Unknown partner type.';
  end if;

  if not found then
    raise exception 'Approved landlord assignment was not found for this account.';
  end if;
end;
$$;

create or replace function public.reject_management_landlord_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.management_landlord_requests
  set status = 'rejected',
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where id = p_request_id
    and landlord_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'Pending management request not found for this landlord.';
  end if;
end;
$$;

create or replace function public.regenerate_landlord_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  next_code text;
  attempts integer := 0;
begin
  if not public.is_landlord() then
    raise exception 'Only landlords can regenerate their code.';
  end if;

  loop
    next_code := public.generate_six_digit_code();
    exit when not exists (select 1 from public.profiles p where p.landlord_code = next_code);
    attempts := attempts + 1;
    if attempts > 25 then
      raise exception 'Could not generate a unique landlord code.';
    end if;
  end loop;

  update public.profiles
  set landlord_code = next_code
  where id = auth.uid()
    and role = 'landlord';

  return next_code;
end;
$$;

create or replace function public.handle_landlord_subscription_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  matching_invite public.invite_tokens%rowtype;
  requester_type text;
  staff_request_id uuid;
begin
  if new.role <> 'landlord' then
    return new;
  end if;

  select *
  into matching_invite
  from public.invite_tokens it
  where lower(it.email) = lower(new.email)
    and it.role = 'landlord'
  order by it.created_at desc
  limit 1;

  if matching_invite.id is not null then
    update public.profiles p
    set country_id = coalesce(p.country_id, matching_invite.country_id, nullif(matching_invite.metadata ->> 'country_id', '')::uuid)
    where p.id = new.id
      and p.country_id is null;

    if exists (select 1 from public.landlord_subscriptions ls where ls.invite_token_id = matching_invite.id) then
      update public.landlord_subscriptions ls
      set landlord_id = new.id,
          country_id = coalesce(ls.country_id, new.country_id, matching_invite.country_id, nullif(matching_invite.metadata ->> 'country_id', '')::uuid),
          subscription_plan = coalesce(nullif(matching_invite.metadata ->> 'subscription_plan', ''), ls.subscription_plan, 'free'),
          property_limit = coalesce(nullif(matching_invite.metadata ->> 'property_limit', '')::integer, ls.property_limit, 1),
          unit_limit = coalesce(nullif(matching_invite.metadata ->> 'unit_limit', '')::integer, ls.unit_limit, 1),
          personal_staff_limit = coalesce(nullif(matching_invite.metadata ->> 'personal_staff_limit', '')::integer, ls.personal_staff_limit, 0),
          partner_connection_limit = coalesce(nullif(matching_invite.metadata ->> 'partner_connection_limit', '')::integer, ls.partner_connection_limit, 1),
          status = coalesce(nullif(matching_invite.metadata ->> 'subscription_status', '')::public.subscription_status, ls.status, 'active'),
          expires_at = coalesce(nullif(matching_invite.metadata ->> 'subscription_expires_at', '')::timestamptz, ls.expires_at, '2099-12-31 23:59:59+00'),
          updated_at = now()
      where ls.invite_token_id = matching_invite.id
        and ls.landlord_id is null;
    else
      update public.landlord_subscriptions ls
      set country_id = coalesce(ls.country_id, new.country_id, matching_invite.country_id, nullif(matching_invite.metadata ->> 'country_id', '')::uuid),
          subscription_plan = coalesce(nullif(matching_invite.metadata ->> 'subscription_plan', ''), ls.subscription_plan, 'free'),
          property_limit = coalesce(nullif(matching_invite.metadata ->> 'property_limit', '')::integer, ls.property_limit, 1),
          unit_limit = coalesce(nullif(matching_invite.metadata ->> 'unit_limit', '')::integer, ls.unit_limit, 1),
          personal_staff_limit = coalesce(nullif(matching_invite.metadata ->> 'personal_staff_limit', '')::integer, ls.personal_staff_limit, 0),
          partner_connection_limit = coalesce(nullif(matching_invite.metadata ->> 'partner_connection_limit', '')::integer, ls.partner_connection_limit, 1),
          status = coalesce(nullif(matching_invite.metadata ->> 'subscription_status', '')::public.subscription_status, ls.status, 'active'),
          expires_at = coalesce(nullif(matching_invite.metadata ->> 'subscription_expires_at', '')::timestamptz, ls.expires_at, '2099-12-31 23:59:59+00'),
          invite_token_id = coalesce(ls.invite_token_id, matching_invite.id),
          updated_at = now()
      where ls.landlord_id = new.id;

      if not found then
        insert into public.landlord_subscriptions (
          landlord_id,
          country_id,
          subscription_plan,
          property_limit,
          unit_limit,
          personal_staff_limit,
          partner_connection_limit,
          status,
          expires_at,
          invite_token_id,
          notes
        )
        values (
          new.id,
          coalesce(new.country_id, matching_invite.country_id, nullif(matching_invite.metadata ->> 'country_id', '')::uuid),
          coalesce(nullif(matching_invite.metadata ->> 'subscription_plan', ''), 'free'),
          coalesce(nullif(matching_invite.metadata ->> 'property_limit', '')::integer, 1),
          coalesce(nullif(matching_invite.metadata ->> 'unit_limit', '')::integer, 1),
          coalesce(nullif(matching_invite.metadata ->> 'personal_staff_limit', '')::integer, 0),
          coalesce(nullif(matching_invite.metadata ->> 'partner_connection_limit', '')::integer, 1),
          coalesce(nullif(matching_invite.metadata ->> 'subscription_status', '')::public.subscription_status, 'active'),
          coalesce(nullif(matching_invite.metadata ->> 'subscription_expires_at', '')::timestamptz, '2099-12-31 23:59:59+00'),
          matching_invite.id,
          'Free landlord plan created from partner invitation.'
        );
      end if;
    end if;

    requester_type := matching_invite.metadata ->> 'requested_by_type';

    if requester_type = 'ipm' and nullif(matching_invite.metadata ->> 'staff_profile_id', '') is not null then
      update public.staff_landlord_requests
      set requested_at = now(),
          landlord_code = new.landlord_code
      where staff_profile_id = (matching_invite.metadata ->> 'staff_profile_id')::uuid
        and landlord_id = new.id
        and status = 'pending'
      returning id into staff_request_id;

      if staff_request_id is null then
        insert into public.staff_landlord_requests (staff_profile_id, landlord_id, landlord_code, status)
        values ((matching_invite.metadata ->> 'staff_profile_id')::uuid, new.id, new.landlord_code, 'pending')
        returning id into staff_request_id;
      end if;
    elsif requester_type = 'management' and nullif(matching_invite.metadata ->> 'management_company_id', '') is not null then
      update public.management_landlord_requests
      set requested_at = now(),
          landlord_code = new.landlord_code,
          reviewed_at = null,
          reviewed_by = null
      where management_company_id = (matching_invite.metadata ->> 'management_company_id')::uuid
        and landlord_id = new.id
        and status = 'pending';

      if not found then
        insert into public.management_landlord_requests (
          management_company_id,
          leader_profile_id,
          landlord_id,
          landlord_code,
          status
        )
        values (
          (matching_invite.metadata ->> 'management_company_id')::uuid,
          (matching_invite.metadata ->> 'leader_profile_id')::uuid,
          new.id,
          new.landlord_code,
          'pending'
        );
      end if;
    end if;

    update public.invite_tokens
    set used = true
    where id = matching_invite.id;
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_link_landlord_subscription on public.profiles;
create trigger profiles_link_landlord_subscription
after insert on public.profiles
for each row execute function public.handle_landlord_subscription_link();

create or replace function public.handle_admin_staff_country_assignments()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  matching_invite public.invite_tokens%rowtype;
  country_text text;
  country_uuid uuid;
begin
  if new.role <> 'admin_staff' then
    return new;
  end if;

  select *
  into matching_invite
  from public.invite_tokens it
  where lower(it.email) = lower(new.email)
    and it.role = 'admin_staff'
  order by it.created_at desc
  limit 1;

  if new.country_id is not null then
    insert into public.admin_staff_country_assignments (staff_profile_id, country_id)
    values (new.id, new.country_id)
    on conflict do nothing;
  end if;

  if matching_invite.id is not null and jsonb_typeof(matching_invite.metadata -> 'country_ids') = 'array' then
    for country_text in
      select jsonb_array_elements_text(matching_invite.metadata -> 'country_ids')
    loop
      begin
        country_uuid := nullif(country_text, '')::uuid;
        insert into public.admin_staff_country_assignments (staff_profile_id, country_id)
        values (new.id, country_uuid)
        on conflict do nothing;
      exception when invalid_text_representation then
        country_uuid := null;
      end;
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_link_admin_staff_countries on public.profiles;
create trigger profiles_link_admin_staff_countries
after insert on public.profiles
for each row execute function public.handle_admin_staff_country_assignments();

create or replace function public.handle_management_company_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  matching_invite public.invite_tokens%rowtype;
begin
  if new.role <> 'management_leader' then
    return new;
  end if;

  select *
  into matching_invite
  from public.invite_tokens it
  where lower(it.email) = lower(new.email)
    and it.role = 'management_leader'
  order by it.created_at desc
  limit 1;

  insert into public.management_companies (
    leader_profile_id,
    country_id,
    company_name,
    phone,
    max_landlords,
    max_properties,
    max_staff,
    subscription_status,
    subscription_expires_at,
    notes
  )
  values (
    new.id,
    coalesce(new.country_id, matching_invite.country_id, nullif(matching_invite.metadata ->> 'country_id', '')::uuid),
    coalesce(nullif(matching_invite.metadata ->> 'company_name', ''), new.full_name),
    coalesce(new.phone, matching_invite.metadata ->> 'phone'),
    coalesce((matching_invite.metadata ->> 'max_landlords')::integer, 2),
    coalesce((matching_invite.metadata ->> 'max_properties')::integer, 10),
    coalesce((matching_invite.metadata ->> 'max_staff')::integer, 3),
    coalesce(nullif(matching_invite.metadata ->> 'subscription_status', ''), 'trial'),
    nullif(matching_invite.metadata ->> 'subscription_expires_at', '')::date,
    coalesce(matching_invite.metadata ->> 'notes', '')
  )
  on conflict (leader_profile_id)
  do update set
    country_id = coalesce(excluded.country_id, public.management_companies.country_id),
    company_name = excluded.company_name,
    phone = excluded.phone,
    max_landlords = excluded.max_landlords,
    max_properties = excluded.max_properties,
    max_staff = excluded.max_staff,
    subscription_status = excluded.subscription_status,
    subscription_expires_at = excluded.subscription_expires_at,
    notes = excluded.notes;

  update public.profiles p
  set country_id = coalesce(p.country_id, matching_invite.country_id, nullif(matching_invite.metadata ->> 'country_id', '')::uuid)
  where p.id = new.id
    and p.country_id is null;

  return new;
end;
$$;

drop trigger if exists profiles_link_management_company on public.profiles;
create trigger profiles_link_management_company
after insert on public.profiles
for each row execute function public.handle_management_company_link();

create or replace function public.handle_unit_status_from_lease()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'active' then
      update public.units set status = 'occupied' where id = new.unit_id;
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.status = 'active' then
      update public.units set status = 'occupied' where id = new.unit_id;
    end if;

    if old.status = 'active' and (new.status in ('terminated', 'expired') or new.unit_id <> old.unit_id) then
      update public.units u
      set status = 'vacant'
      where u.id = old.unit_id
        and not exists (
          select 1 from public.leases l
          where l.unit_id = old.unit_id
            and l.status = 'active'
            and l.id <> new.id
        );
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.status = 'active' then
      update public.units u
      set status = 'vacant'
      where u.id = old.unit_id
        and not exists (
          select 1 from public.leases l
          where l.unit_id = old.unit_id
            and l.status = 'active'
            and l.id <> old.id
        );
    end if;

    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists leases_update_unit_status on public.leases;
create trigger leases_update_unit_status
after insert or update of status, unit_id on public.leases
for each row execute function public.handle_unit_status_from_lease();

drop trigger if exists leases_delete_update_unit_status on public.leases;
create trigger leases_delete_update_unit_status
after delete on public.leases
for each row execute function public.handle_unit_status_from_lease();

create or replace function public.generate_receipt_number()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_receipt_year integer := extract(year from coalesce(new.payment_date, current_date))::integer;
  next_number integer;
begin
  if new.receipt_number is not null then
    return new;
  end if;

  insert into public.receipt_counters (receipt_year, last_number)
  values (v_receipt_year, 1)
  on conflict (receipt_year)
  do update set last_number = public.receipt_counters.last_number + 1
  returning last_number into next_number;

  new.receipt_number := 'RR-' || v_receipt_year::text || '-' || lpad(next_number::text, 4, '0');
  return new;
end;
$$;

drop trigger if exists payments_generate_receipt_number on public.payments;
create trigger payments_generate_receipt_number
before insert on public.payments
for each row execute function public.generate_receipt_number();

create or replace function public.mark_lease_deposit_paid_from_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.lease_id is not null and new.payment_purpose = 'deposit' then
    update public.leases
    set deposit_paid = true
    where id = new.lease_id
      and deposit_paid = false;
  end if;

  return new;
end;
$$;

drop trigger if exists payments_mark_lease_deposit_paid on public.payments;
create trigger payments_mark_lease_deposit_paid
after insert or update of lease_id, payment_purpose on public.payments
for each row execute function public.mark_lease_deposit_paid_from_payment();

create or replace function public.current_user_can_access_lease_finance(p_lease_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    where l.id = p_lease_id
      and (
        public.is_super_admin()
        or public.admin_staff_can_access_lease(l.id)
        or l.landlord_id = auth.uid()
        or t.profile_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and (public.staff_permission_flag('can_view_payments') or public.staff_permission_flag('can_verify_payments') or public.staff_permission_flag('can_view_finance'))
          and public.staff_can_access_lease(l.id)
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and (public.management_permission_flag('can_view_payments') or public.management_permission_flag('can_verify_payments') or public.management_permission_flag('can_view_finance'))
          and public.management_can_access_lease(l.id)
        )
      )
  )
$$;

create or replace function public.current_user_can_manage_lease_finance(p_lease_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.leases l
    where l.id = p_lease_id
      and (
        public.is_super_admin()
        or public.admin_staff_can_access_lease(l.id)
        or l.landlord_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and (public.staff_permission_flag('can_log_payments') or public.staff_permission_flag('can_verify_payments'))
          and public.staff_can_access_lease(l.id)
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and (public.management_permission_flag('can_log_payments') or public.management_permission_flag('can_verify_payments'))
          and public.management_can_access_lease(l.id)
        )
      )
  )
$$;

create or replace function public.recalculate_charge_paid(p_charge_id uuid)
returns public.lease_charges
language plpgsql
security definer
set search_path = public
as $$
declare
  total_paid numeric(12,2);
  updated_charge public.lease_charges;
begin
  select coalesce(sum(pa.amount), 0)
  into total_paid
  from public.payment_allocations pa
  where pa.charge_id = p_charge_id;

  update public.lease_charges lc
  set
    amount_paid = least(total_paid, lc.amount),
    charge_status = case
      when lc.voided_at is not null then 'void'
      when least(total_paid, lc.amount) <= 0 then 'open'
      when least(total_paid, lc.amount) >= lc.amount then 'paid'
      else 'partially_paid'
    end,
    updated_at = now()
  where lc.id = p_charge_id
  returning * into updated_charge;

  return updated_charge;
end;
$$;

create or replace function public.ensure_rent_charges_for_lease(
  p_lease_id uuid,
  p_through_date date default current_date
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  lease_row public.leases;
  month_start date;
  target_month date;
  inserted_count integer := 0;
begin
  select * into lease_row
  from public.leases
  where id = p_lease_id;

  if lease_row.id is null then
    raise exception 'Lease was not found.';
  end if;

  if not public.current_user_can_manage_lease_finance(p_lease_id) then
    raise exception 'You do not have permission to prepare rent charges for this lease.';
  end if;

  month_start := date_trunc('month', lease_row.start_date)::date;
  target_month := date_trunc('month', least(lease_row.end_date, coalesce(p_through_date, current_date)))::date;

  if target_month < month_start then
    return 0;
  end if;

  insert into public.lease_charges (
    lease_id,
    landlord_id,
    tenant_id,
    charge_type,
    charge_status,
    due_date,
    period_start,
    period_end,
    description,
    amount,
    created_by
  )
  select
    lease_row.id,
    lease_row.landlord_id,
    lease_row.tenant_id,
    'rent',
    'open',
    greatest(gs.month_date::date, lease_row.start_date),
    greatest(gs.month_date::date, lease_row.start_date),
    least((gs.month_date + interval '1 month - 1 day')::date, lease_row.end_date),
    to_char(gs.month_date, 'Mon YYYY') || ' rent',
    lease_row.monthly_rent,
    auth.uid()
  from generate_series(month_start, target_month, interval '1 month') as gs(month_date)
  where lease_row.monthly_rent > 0
  on conflict do nothing;

  get diagnostics inserted_count = row_count;

  insert into public.lease_ledger_entries (
    landlord_id,
    tenant_id,
    lease_id,
    unit_id,
    property_id,
    entry_type,
    entry_purpose,
    debit,
    entry_date,
    source_table,
    source_id,
    description,
    created_by
  )
  select
    lc.landlord_id,
    lc.tenant_id,
    lc.lease_id,
    l.unit_id,
    u.property_id,
    'charge',
    'rent',
    lc.amount,
    lc.due_date,
    'lease_charges',
    lc.id,
    lc.description,
    lc.created_by
  from public.lease_charges lc
  join public.leases l on l.id = lc.lease_id
  join public.units u on u.id = l.unit_id
  where lc.lease_id = lease_row.id
    and lc.charge_type = 'rent'
    and not exists (
      select 1
      from public.lease_ledger_entries e
      where e.source_table = 'lease_charges'
        and e.source_id = lc.id
        and e.entry_type = 'charge'
    );

  return inserted_count;
end;
$$;

create or replace function public.ensure_deposit_charge_for_lease(p_lease_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  lease_row public.leases;
  charge_id uuid;
begin
  if not public.current_user_can_manage_lease_finance(p_lease_id) then
    raise exception 'You do not have permission to prepare deposit charges for this lease.';
  end if;

  select * into lease_row
  from public.leases
  where id = p_lease_id;

  if lease_row.id is null or coalesce(lease_row.deposit_amount, 0) <= 0 then
    return null;
  end if;

  select id into charge_id
  from public.lease_charges
  where lease_id = p_lease_id
    and charge_type = 'deposit'
    and voided_at is null
  limit 1;

  if charge_id is null then
    insert into public.lease_charges (
      lease_id,
      landlord_id,
      tenant_id,
      charge_type,
      charge_status,
      due_date,
      description,
      amount,
      created_by
    )
    values (
      lease_row.id,
      lease_row.landlord_id,
      lease_row.tenant_id,
      'deposit',
      'open',
      lease_row.start_date,
      'Refundable security deposit',
      lease_row.deposit_amount,
      auth.uid()
    )
    returning id into charge_id;
  end if;

  insert into public.lease_ledger_entries (
    landlord_id,
    tenant_id,
    lease_id,
    unit_id,
    property_id,
    entry_type,
    entry_purpose,
    debit,
    entry_date,
    source_table,
    source_id,
    description,
    created_by
  )
  select
    lc.landlord_id,
    lc.tenant_id,
    lc.lease_id,
    l.unit_id,
    u.property_id,
    'charge',
    'deposit',
    lc.amount,
    lc.due_date,
    'lease_charges',
    lc.id,
    lc.description,
    lc.created_by
  from public.lease_charges lc
  join public.leases l on l.id = lc.lease_id
  join public.units u on u.id = l.unit_id
  where lc.id = charge_id
  on conflict do nothing;

  return charge_id;
end;
$$;

create or replace function public.allocate_payment_to_charge(
  p_payment_id uuid,
  p_charge_id uuid,
  p_amount numeric default null
)
returns public.payment_allocations
language plpgsql
security definer
set search_path = public
as $$
declare
  payment_row public.payments;
  charge_row public.lease_charges;
  already_allocated numeric(12,2);
  amount_to_allocate numeric(12,2);
  allocation_row public.payment_allocations;
begin
  select * into payment_row
  from public.payments
  where id = p_payment_id;

  select * into charge_row
  from public.lease_charges
  where id = p_charge_id;

  if payment_row.id is null or charge_row.id is null then
    raise exception 'Payment or charge was not found.';
  end if;

  if payment_row.lease_id <> charge_row.lease_id then
    raise exception 'Payment and charge belong to different leases.';
  end if;

  if not public.current_user_can_manage_lease_finance(payment_row.lease_id) then
    raise exception 'You do not have permission to allocate this payment.';
  end if;

  select coalesce(sum(amount), 0)
  into already_allocated
  from public.payment_allocations
  where payment_id = payment_row.id
    and charge_id <> charge_row.id;

  amount_to_allocate := coalesce(
    p_amount,
    least(payment_row.amount_paid - already_allocated, charge_row.amount - charge_row.amount_paid)
  );

  if amount_to_allocate <= 0 then
    raise exception 'There is no remaining amount to allocate.';
  end if;

  if amount_to_allocate > payment_row.amount_paid - already_allocated then
    raise exception 'Allocation is higher than the remaining payment amount.';
  end if;

  if amount_to_allocate > charge_row.amount - charge_row.amount_paid then
    raise exception 'Allocation is higher than the remaining charge amount.';
  end if;

  insert into public.payment_allocations (payment_id, charge_id, amount)
  values (payment_row.id, charge_row.id, amount_to_allocate)
  on conflict (payment_id, charge_id)
  do update set amount = excluded.amount
  returning * into allocation_row;

  perform public.recalculate_charge_paid(charge_row.id);

  insert into public.lease_ledger_entries (
    landlord_id,
    tenant_id,
    lease_id,
    unit_id,
    property_id,
    entry_type,
    entry_purpose,
    credit,
    entry_date,
    source_table,
    source_id,
    description,
    created_by
  )
  select
    charge_row.landlord_id,
    charge_row.tenant_id,
    charge_row.lease_id,
    l.unit_id,
    u.property_id,
    'allocation',
    charge_row.charge_type,
    amount_to_allocate,
    payment_row.payment_date,
    'payment_allocations',
    allocation_row.id,
    'Payment allocated to ' || charge_row.charge_type,
    auth.uid()
  from public.leases l
  join public.units u on u.id = l.unit_id
  where l.id = charge_row.lease_id
  on conflict do nothing;

  insert into public.finance_audit_events (
    actor_profile_id,
    landlord_id,
    lease_id,
    target_table,
    target_id,
    action,
    after_data
  )
  values (
    auth.uid(),
    charge_row.landlord_id,
    charge_row.lease_id,
    'payment_allocations',
    allocation_row.id,
    'allocate',
    to_jsonb(allocation_row)
  );

  return allocation_row;
end;
$$;

create or replace function public.sync_payment_finance_entries()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lease_row record;
  matching_charge_id uuid;
  remaining_charge_amount numeric(12,2);
begin
  select
    l.id,
    l.landlord_id,
    l.tenant_id,
    l.unit_id,
    u.property_id,
    l.deposit_amount
  into lease_row
  from public.leases l
  join public.units u on u.id = l.unit_id
  where l.id = new.lease_id;

  if lease_row.id is null then
    return new;
  end if;

  insert into public.lease_ledger_entries (
    landlord_id,
    tenant_id,
    lease_id,
    unit_id,
    property_id,
    entry_type,
    entry_purpose,
    credit,
    entry_date,
    source_table,
    source_id,
    description,
    created_by
  )
  values (
    lease_row.landlord_id,
    lease_row.tenant_id,
    new.lease_id,
    lease_row.unit_id,
    lease_row.property_id,
    case when new.payment_purpose = 'deposit' then 'deposit_liability' else 'payment' end,
    new.payment_purpose,
    new.amount_paid,
    new.payment_date,
    'payments',
    new.id,
    coalesce(new.purpose_description, new.rent_period_label, new.notes, new.payment_purpose),
    new.recorded_by
  )
  on conflict do nothing;

  if new.payment_purpose = 'rent' and new.rent_period_start is not null then
    perform public.ensure_rent_charges_for_lease(new.lease_id, new.rent_period_start);

    select lc.id into matching_charge_id
    from public.lease_charges lc
    where lc.lease_id = new.lease_id
      and lc.charge_type = 'rent'
      and lc.voided_at is null
      and date_trunc('month', lc.period_start)::date = date_trunc('month', new.rent_period_start)::date
    order by lc.period_start desc
    limit 1;

    if matching_charge_id is not null then
      select amount - amount_paid
      into remaining_charge_amount
      from public.lease_charges
      where id = matching_charge_id;

      if coalesce(remaining_charge_amount, 0) > 0 then
        perform public.allocate_payment_to_charge(new.id, matching_charge_id, least(new.amount_paid, remaining_charge_amount));
      end if;
    end if;
  elsif new.payment_purpose = 'deposit' then
    matching_charge_id := public.ensure_deposit_charge_for_lease(new.lease_id);

    if matching_charge_id is not null then
      select amount - amount_paid
      into remaining_charge_amount
      from public.lease_charges
      where id = matching_charge_id;

      if coalesce(remaining_charge_amount, 0) > 0 then
        perform public.allocate_payment_to_charge(new.id, matching_charge_id, least(new.amount_paid, remaining_charge_amount));
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists payments_sync_finance_entries on public.payments;
create trigger payments_sync_finance_entries
after insert on public.payments
for each row execute function public.sync_payment_finance_entries();

create or replace function public.audit_finance_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_landlord_id uuid;
  target_lease_id uuid;
  target_id uuid;
begin
  if tg_table_name = 'lease_charges' then
    target_landlord_id := coalesce(new.landlord_id, old.landlord_id);
    target_lease_id := coalesce(new.lease_id, old.lease_id);
    target_id := coalesce(new.id, old.id);
  elsif tg_table_name = 'payments' then
    select l.landlord_id, l.id
    into target_landlord_id, target_lease_id
    from public.leases l
    where l.id = coalesce(new.lease_id, old.lease_id);
    target_id := coalesce(new.id, old.id);
  elsif tg_table_name = 'payment_submissions' then
    select l.landlord_id, l.id
    into target_landlord_id, target_lease_id
    from public.leases l
    where l.id = coalesce(new.lease_id, old.lease_id);
    target_id := coalesce(new.id, old.id);
  elsif tg_table_name = 'payment_allocations' then
    select lc.landlord_id, lc.lease_id
    into target_landlord_id, target_lease_id
    from public.lease_charges lc
    where lc.id = coalesce(new.charge_id, old.charge_id);
    target_id := coalesce(new.id, old.id);
  end if;

  insert into public.finance_audit_events (
    actor_profile_id,
    landlord_id,
    lease_id,
    target_table,
    target_id,
    action,
    before_data,
    after_data
  )
  values (
    auth.uid(),
    target_landlord_id,
    target_lease_id,
    tg_table_name,
    target_id,
    lower(tg_op),
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists payments_audit_finance_change on public.payments;
create trigger payments_audit_finance_change
after insert or update or delete on public.payments
for each row execute function public.audit_finance_change();

drop trigger if exists payment_submissions_audit_finance_change on public.payment_submissions;
create trigger payment_submissions_audit_finance_change
after insert or update or delete on public.payment_submissions
for each row execute function public.audit_finance_change();

drop trigger if exists lease_charges_audit_finance_change on public.lease_charges;
create trigger lease_charges_audit_finance_change
after insert or update or delete on public.lease_charges
for each row execute function public.audit_finance_change();

drop trigger if exists payment_allocations_audit_finance_change on public.payment_allocations;
create trigger payment_allocations_audit_finance_change
after insert or update or delete on public.payment_allocations
for each row execute function public.audit_finance_change();

create or replace function public.notify_payment_submission_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_landlord_id uuid;
begin
  select l.landlord_id into target_landlord_id
  from public.leases l
  where l.id = new.lease_id;

  insert into public.notifications (profile_id, landlord_id, type, message, related_id)
  values (
    target_landlord_id,
    target_landlord_id,
    'payment_submitted',
    'A tenant submitted a payment for review.',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists payment_submissions_notify_created on public.payment_submissions;
create trigger payment_submissions_notify_created
after insert on public.payment_submissions
for each row execute function public.notify_payment_submission_created();

create or replace function public.notify_payment_submission_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tenant_profile_id uuid;
  target_landlord_id uuid;
  notification_kind public.notification_type;
  notification_message text;
begin
  if old.status = new.status or new.status not in ('approved', 'rejected') then
    return new;
  end if;

  select t.profile_id, t.landlord_id
  into tenant_profile_id, target_landlord_id
  from public.tenants t
  where t.id = new.tenant_id;

  if tenant_profile_id is null then
    return new;
  end if;

  if new.status = 'approved' then
    notification_kind := 'payment_approved';
    notification_message := 'Your payment submission was approved.';
  else
    notification_kind := 'payment_rejected';
    notification_message := 'Your payment submission was rejected.';
  end if;

  insert into public.notifications (profile_id, landlord_id, type, message, related_id)
  values (tenant_profile_id, target_landlord_id, notification_kind, notification_message, new.id);

  return new;
end;
$$;

drop trigger if exists payment_submissions_notify_reviewed on public.payment_submissions;
create trigger payment_submissions_notify_reviewed
after update of status on public.payment_submissions
for each row execute function public.notify_payment_submission_reviewed();

create or replace function public.notify_maintenance_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (profile_id, landlord_id, type, message, related_id)
  values (
    new.landlord_id,
    new.landlord_id,
    'maintenance_new',
    'A new maintenance request was submitted.',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists maintenance_requests_notify_created on public.maintenance_requests;
create trigger maintenance_requests_notify_created
after insert on public.maintenance_requests
for each row execute function public.notify_maintenance_created();

create or replace function public.notify_maintenance_status_updated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = new.status then
    return new;
  end if;

  if new.status = 'resolved' and new.resolved_at is null then
    new.resolved_at := now();
  end if;

  if new.status = 'completed' then
    if new.completed_at is null then
      new.completed_at := now();
    end if;
    if new.completed_by is null then
      new.completed_by := auth.uid();
    end if;
  end if;

  if new.status = 'cancelled' and new.cancelled_at is null then
    new.cancelled_at := now();
  end if;

  insert into public.notifications (profile_id, landlord_id, type, message, related_id)
  values (
    new.submitted_by_profile_id,
    new.landlord_id,
    'maintenance_updated',
    'Your maintenance request status was updated to ' || replace(new.status::text, '_', ' ') || '.',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists maintenance_requests_notify_status_updated on public.maintenance_requests;
create trigger maintenance_requests_notify_status_updated
before update of status on public.maintenance_requests
for each row execute function public.notify_maintenance_status_updated();

create or replace function public.record_maintenance_request_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title,
      body
    )
    values (
      new.id,
      new.landlord_id,
      new.submitted_by_profile_id,
      'created',
      'Maintenance request created',
      new.description
    );
    return new;
  end if;

  if old.status is distinct from new.status then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title,
      body,
      metadata
    )
    values (
      new.id,
      new.landlord_id,
      auth.uid(),
      'status_changed',
      'Status changed to ' || replace(new.status::text, '_', ' '),
      null,
      jsonb_build_object('from', old.status::text, 'to', new.status::text)
    );
  end if;

  if old.assigned_to_staff_id is distinct from new.assigned_to_staff_id then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title,
      metadata
    )
    values (
      new.id,
      new.landlord_id,
      auth.uid(),
      'assigned',
      case when new.assigned_to_staff_id is null then 'Staff assignment removed' else 'Staff assigned' end,
      jsonb_build_object('assigned_to_staff_id', new.assigned_to_staff_id)
    );
  end if;

  if old.scheduled_for is distinct from new.scheduled_for and new.scheduled_for is not null then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title,
      metadata
    )
    values (
      new.id,
      new.landlord_id,
      auth.uid(),
      'scheduled',
      'Maintenance scheduled',
      jsonb_build_object('scheduled_for', new.scheduled_for)
    );
  end if;

  if old.final_cost is distinct from new.final_cost and new.final_cost is not null then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title,
      metadata
    )
    values (
      new.id,
      new.landlord_id,
      auth.uid(),
      'final_cost_updated',
      'Final cost updated',
      jsonb_build_object('final_cost', new.final_cost)
    );
  end if;

  if old.completed_at is distinct from new.completed_at and new.completed_at is not null then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title
    )
    values (
      new.id,
      new.landlord_id,
      coalesce(new.completed_by, auth.uid()),
      'completed',
      'Maintenance completed'
    );
  end if;

  if old.cancelled_at is distinct from new.cancelled_at and new.cancelled_at is not null then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title,
      body
    )
    values (
      new.id,
      new.landlord_id,
      auth.uid(),
      'cancelled',
      'Maintenance cancelled',
      new.cancellation_reason
    );
  end if;

  if old.resolution_notes is distinct from new.resolution_notes and new.resolution_notes is not null then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title,
      body
    )
    values (
      new.id,
      new.landlord_id,
      auth.uid(),
      'notes_updated',
      'Resolution notes updated',
      new.resolution_notes
    );
  end if;

  if old.workflow_notes is distinct from new.workflow_notes and new.workflow_notes is not null then
    insert into public.maintenance_activity (
      maintenance_request_id,
      landlord_id,
      actor_profile_id,
      activity_type,
      title,
      body
    )
    values (
      new.id,
      new.landlord_id,
      auth.uid(),
      'workflow_notes_updated',
      'Work notes updated',
      new.workflow_notes
    );
  end if;

  return new;
end;
$$;

drop trigger if exists maintenance_requests_record_activity on public.maintenance_requests;
create trigger maintenance_requests_record_activity
after insert or update on public.maintenance_requests
for each row execute function public.record_maintenance_request_activity();

create or replace function public.sync_maintenance_quote_workflow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  next_status public.maintenance_status;
  activity_title text;
begin
  if tg_op = 'INSERT' then
    next_status := 'quote_sent';
    activity_title := 'Vendor quote sent for approval';
  elsif old.status is distinct from new.status and new.status = 'approved' then
    next_status := 'approved';
    activity_title := 'Vendor quote approved';
  elsif old.status is distinct from new.status and new.status = 'rejected' then
    next_status := 'quote_requested';
    activity_title := 'Vendor quote rejected';
  else
    return new;
  end if;

  update public.maintenance_requests
  set status = next_status
  where id = new.maintenance_request_id
    and status not in ('completed', 'resolved', 'cancelled');

  insert into public.maintenance_activity (
    maintenance_request_id,
    landlord_id,
    actor_profile_id,
    activity_type,
    title,
    body,
    metadata
  )
  values (
    new.maintenance_request_id,
    new.landlord_id,
    coalesce(new.reviewed_by, new.requested_by),
    'quote_' || new.status,
    activity_title,
    new.notes,
    jsonb_build_object(
      'quote_id', new.id,
      'vendor_name', new.vendor_name,
      'amount', new.amount,
      'currency_code', new.currency_code
    )
  );

  return new;
end;
$$;

drop trigger if exists maintenance_quotes_sync_workflow on public.maintenance_quotes;
create trigger maintenance_quotes_sync_workflow
after insert or update of status on public.maintenance_quotes
for each row execute function public.sync_maintenance_quote_workflow();

create or replace function public.check_lease_expiries()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
  lease_record record;
  days_left integer;
  message_text text;
begin
  for lease_record in
    select l.id, l.landlord_id, l.end_date, t.full_name, u.unit_number
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    join public.units u on u.id = l.unit_id
    where l.status = 'active'
      and (l.end_date - current_date) in (60, 30, 7)
  loop
    days_left := lease_record.end_date - current_date;
    message_text := 'Lease for ' || lease_record.full_name || ' in unit ' || lease_record.unit_number ||
      ' expires in ' || days_left::text || ' days.';

    if not exists (
      select 1
      from public.notifications n
      where n.type = 'lease_expiring'
        and n.related_id = lease_record.id
        and n.message = message_text
    ) then
      insert into public.notifications (profile_id, landlord_id, type, message, related_id)
      values (lease_record.landlord_id, lease_record.landlord_id, 'lease_expiring', message_text, lease_record.id);
      inserted_count := inserted_count + 1;
    end if;
  end loop;

  return inserted_count;
end;
$$;

create or replace function public.notify_staff_landlord_request_pending()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  staff_name text;
  notification_message text;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  select coalesce(nullif(trim(p.full_name), ''), p.email, 'An IPM')
  into staff_name
  from public.profiles p
  where p.id = new.staff_profile_id;

  notification_message := staff_name || ' requested access to manage your landlord account. Review the request from Staff.';

  if exists (
    select 1
    from public.notifications n
    where n.profile_id = new.landlord_id
      and n.type = 'staff_landlord_request'
      and n.related_id = new.id
  ) then
    update public.notifications
    set
      message = notification_message,
      is_read = false,
      response_status = 'pending',
      created_at = now()
    where profile_id = new.landlord_id
      and type = 'staff_landlord_request'
      and related_id = new.id;
  else
    insert into public.notifications (profile_id, landlord_id, type, message, related_id, response_status)
    values (
      new.landlord_id,
      new.landlord_id,
      'staff_landlord_request',
      notification_message,
      new.id,
      'pending'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists staff_landlord_requests_notify_pending on public.staff_landlord_requests;
create trigger staff_landlord_requests_notify_pending
after insert or update of status, requested_at on public.staff_landlord_requests
for each row execute function public.notify_staff_landlord_request_pending();

create or replace function public.notify_management_landlord_request_pending()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  company_name text;
  notification_message text;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  select coalesce(nullif(trim(mc.company_name), ''), 'A Property Management Company')
  into company_name
  from public.management_companies mc
  where mc.id = new.management_company_id;

  notification_message := company_name || ' requested access to manage your landlord account. Review the request from Staff.';

  if exists (
    select 1
    from public.notifications n
    where n.profile_id = new.landlord_id
      and n.type = 'management_landlord_request'
      and n.related_id = new.id
  ) then
    update public.notifications
    set
      message = notification_message,
      is_read = false,
      response_status = 'pending',
      created_at = now()
    where profile_id = new.landlord_id
      and type = 'management_landlord_request'
      and related_id = new.id;
  else
    insert into public.notifications (profile_id, landlord_id, type, message, related_id, response_status)
    values (
      new.landlord_id,
      new.landlord_id,
      'management_landlord_request',
      notification_message,
      new.id,
      'pending'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists management_landlord_requests_notify_pending on public.management_landlord_requests;
create trigger management_landlord_requests_notify_pending
after insert or update of status, requested_at on public.management_landlord_requests
for each row execute function public.notify_management_landlord_request_pending();

alter table public.countries enable row level security;
alter table public.pricing_plans enable row level security;
alter table public.profiles enable row level security;
alter table public.enquiries enable row level security;
alter table public.landlord_subscriptions enable row level security;
alter table public.landlord_subscription_admin_notes enable row level security;
alter table public.admin_notes enable row level security;
alter table public.admin_staff_country_assignments enable row level security;
alter table public.platform_payments enable row level security;
alter table public.invite_tokens enable row level security;
alter table public.properties enable row level security;
alter table public.units enable row level security;
alter table public.staff_permissions enable row level security;
alter table public.staff_landlord_requests enable row level security;
alter table public.management_companies enable row level security;
alter table public.management_landlord_requests enable row level security;
alter table public.management_landlord_permissions enable row level security;
alter table public.management_staff_permissions enable row level security;
alter table public.tenants enable row level security;
alter table public.leases enable row level security;
alter table public.payment_submissions enable row level security;
alter table public.payments enable row level security;
alter table public.lease_charges enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.lease_ledger_entries enable row level security;
alter table public.finance_audit_events enable row level security;
alter table public.partner_payments enable row level security;
alter table public.partner_reconciliations enable row level security;
alter table public.receipt_counters enable row level security;
alter table public.maintenance_requests enable row level security;
alter table public.maintenance_quotes enable row level security;
alter table public.maintenance_activity enable row level security;
alter table public.property_inspections enable row level security;
alter table public.inspection_files enable row level security;
alter table public.notifications enable row level security;
alter table public.tenant_applications enable row level security;
alter table public.tenant_documents enable row level security;
alter table public.lease_lifecycle_items enable row level security;
alter table public.deposit_settlements enable row level security;
alter table public.tenant_reference_requests enable row level security;
alter table public.telegram_link_tokens enable row level security;

drop policy if exists "countries super admin all" on public.countries;
create policy "countries super admin all"
on public.countries for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "countries admin staff assigned read" on public.countries;
create policy "countries admin staff assigned read"
on public.countries for select to authenticated
using (public.is_admin_staff_for_country(id));

drop policy if exists "countries public signup read" on public.countries;
create policy "countries public signup read"
on public.countries for select to anon, authenticated
using (archived_at is null);

drop policy if exists "pricing plans public read" on public.pricing_plans;
create policy "pricing plans public read"
on public.pricing_plans for select to anon, authenticated
using (
  public_active
  or public.is_super_admin()
  or public.current_profile_role() = 'admin_staff'
);

drop policy if exists "pricing plans super admin all" on public.pricing_plans;
create policy "pricing plans super admin all"
on public.pricing_plans for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "admin staff country assignments super admin all" on public.admin_staff_country_assignments;
create policy "admin staff country assignments super admin all"
on public.admin_staff_country_assignments for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "admin staff country assignments own read" on public.admin_staff_country_assignments;
create policy "admin staff country assignments own read"
on public.admin_staff_country_assignments for select to authenticated
using (staff_profile_id = auth.uid());

drop policy if exists "landlord subscription admin notes super admin all" on public.landlord_subscription_admin_notes;
create policy "landlord subscription admin notes super admin all"
on public.landlord_subscription_admin_notes for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "landlord subscription admin notes admin staff all" on public.landlord_subscription_admin_notes;
create policy "landlord subscription admin notes admin staff all"
on public.landlord_subscription_admin_notes for all to authenticated
using (public.admin_staff_can_access_landlord(landlord_id))
with check (public.admin_staff_can_access_landlord(landlord_id));

drop policy if exists "admin notes super admin all" on public.admin_notes;
create policy "admin notes super admin all"
on public.admin_notes for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "admin notes admin staff read" on public.admin_notes;
create policy "admin notes admin staff read"
on public.admin_notes for select to authenticated
using (
  public.current_profile_role() = 'admin_staff'
  and (created_by = auth.uid() or assigned_to = auth.uid())
);

drop policy if exists "admin notes admin staff insert" on public.admin_notes;
create policy "admin notes admin staff insert"
on public.admin_notes for insert to authenticated
with check (
  public.current_profile_role() = 'admin_staff'
  and created_by = auth.uid()
  and (
    (visibility = 'personal' and assigned_to is null)
    or (
      visibility = 'assigned'
      and (
        assigned_to = auth.uid()
        or public.is_super_admin_profile(assigned_to)
      )
    )
  )
);

drop policy if exists "admin notes admin staff update" on public.admin_notes;
create policy "admin notes admin staff update"
on public.admin_notes for update to authenticated
using (
  public.current_profile_role() = 'admin_staff'
  and (created_by = auth.uid() or assigned_to = auth.uid())
)
with check (
  public.current_profile_role() = 'admin_staff'
  and (
    created_by = auth.uid()
    or assigned_to = auth.uid()
    or public.is_super_admin_profile(assigned_to)
  )
  and (
    (visibility = 'personal' and assigned_to is null)
    or (
      visibility = 'assigned'
      and (
        assigned_to = auth.uid()
        or public.is_super_admin_profile(assigned_to)
      )
    )
  )
);

drop policy if exists "admin notes admin staff delete own" on public.admin_notes;
create policy "admin notes admin staff delete own"
on public.admin_notes for delete to authenticated
using (
  public.current_profile_role() = 'admin_staff'
  and created_by = auth.uid()
);

drop policy if exists "enquiries public insert" on public.enquiries;
create policy "enquiries public insert"
on public.enquiries for insert to anon, authenticated
with check (
  length(trim(full_name)) > 0
  and length(trim(email)) > 0
  and length(trim(country_name)) > 0
  and length(trim(message)) > 0
  and coalesce(status, 'new') = 'new'
  and coalesce(source, 'website') = 'website'
  and handled_by is null
  and handled_at is null
);

drop policy if exists "enquiries admin read" on public.enquiries;
create policy "enquiries admin read"
on public.enquiries for select to authenticated
using (public.can_access_enquiry(country_id, country_name));

drop policy if exists "enquiries admin update" on public.enquiries;
create policy "enquiries admin update"
on public.enquiries for update to authenticated
using (public.can_access_enquiry(country_id, country_name))
with check (public.can_access_enquiry(country_id, country_name));

drop policy if exists "enquiries super admin delete" on public.enquiries;
create policy "enquiries super admin delete"
on public.enquiries for delete to authenticated
using (public.is_super_admin());

drop policy if exists "profiles super admin all" on public.profiles;
create policy "profiles super admin all"
on public.profiles for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "profiles admin staff country read" on public.profiles;
create policy "profiles admin staff country read"
on public.profiles for select to authenticated
using (
  public.is_admin_staff_for_country(country_id)
  or (role = 'tenant' and public.admin_staff_can_access_landlord(landlord_id))
);

drop policy if exists "profiles admin staff country update" on public.profiles;
create policy "profiles admin staff country update"
on public.profiles for update to authenticated
using (
  role in ('landlord', 'staff', 'tenant', 'management_leader')
  and (
    public.is_admin_staff_for_country(country_id)
    or public.admin_staff_can_access_landlord(landlord_id)
  )
)
with check (
  role in ('landlord', 'staff', 'tenant', 'management_leader')
  and (
    public.is_admin_staff_for_country(country_id)
    or public.admin_staff_can_access_landlord(landlord_id)
  )
);

drop policy if exists "profiles own read" on public.profiles;
create policy "profiles own read"
on public.profiles for select to authenticated
using (id = auth.uid());

drop policy if exists "profiles own update" on public.profiles;
create policy "profiles own update"
on public.profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid() and role = public.current_profile_role());

drop policy if exists "profiles landlord manages owned users" on public.profiles;
create policy "profiles landlord manages owned users"
on public.profiles for all to authenticated
using (landlord_id = auth.uid() and public.is_landlord())
with check (landlord_id = auth.uid() and public.is_landlord() and role in ('staff', 'tenant'));

drop policy if exists "profiles landlord reads related staff" on public.profiles;
create policy "profiles landlord reads related staff"
on public.profiles for select to authenticated
using (
  role = 'staff'
  and public.is_landlord()
  and (
    exists (
      select 1 from public.staff_permissions sp
      where sp.staff_profile_id = profiles.id
        and sp.landlord_id = auth.uid()
    )
    or exists (
      select 1 from public.staff_landlord_requests slr
      where slr.staff_profile_id = profiles.id
        and slr.landlord_id = auth.uid()
    )
  )
);

drop policy if exists "profiles staff reads approved landlords" on public.profiles;
create policy "profiles staff reads approved landlords"
on public.profiles for select to authenticated
using (
  role = 'landlord'
  and exists (
    select 1 from public.staff_permissions sp
    where sp.landlord_id = profiles.id
      and sp.staff_profile_id = auth.uid()
      and sp.status = 'approved'
  )
);

drop policy if exists "profiles landlord reads related management" on public.profiles;
create policy "profiles landlord reads related management"
on public.profiles for select to authenticated
using (
  role = 'management_leader'
  and public.is_landlord()
  and (
    exists (
      select 1 from public.management_landlord_permissions mlp
      where mlp.leader_profile_id = profiles.id
        and mlp.landlord_id = auth.uid()
    )
    or exists (
      select 1 from public.management_landlord_requests mlr
      where mlr.leader_profile_id = profiles.id
        and mlr.landlord_id = auth.uid()
    )
  )
);

drop policy if exists "profiles management reads approved landlords" on public.profiles;
create policy "profiles management reads approved landlords"
on public.profiles for select to authenticated
using (
  role = 'landlord'
  and exists (
    select 1 from public.management_landlord_permissions mlp
    where mlp.landlord_id = profiles.id
      and mlp.management_company_id = public.current_management_company_id()
      and mlp.status = 'approved'
  )
);

drop policy if exists "profiles management leader reads own staff" on public.profiles;
create policy "profiles management leader reads own staff"
on public.profiles for select to authenticated
using (
  role = 'management_staff'
  and exists (
    select 1
    from public.management_staff_permissions msp
    join public.management_companies mc on mc.id = msp.management_company_id
    where msp.staff_profile_id = profiles.id
      and mc.leader_profile_id = auth.uid()
      and mc.archived_at is null
  )
);

drop policy if exists "profiles invited users insert own profile" on public.profiles;
create policy "profiles invited users insert own profile"
on public.profiles for insert to authenticated
with check (
  id = auth.uid()
  and role in ('landlord', 'staff', 'tenant', 'management_leader', 'management_staff', 'admin_staff')
  and lower(email) = lower(coalesce(auth.jwt() ->> 'email', email))
  and public.profile_insert_allowed(email, role, landlord_id)
);

drop policy if exists "landlord subscriptions super admin all" on public.landlord_subscriptions;
create policy "landlord subscriptions super admin all"
on public.landlord_subscriptions for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "landlord subscriptions admin staff country all" on public.landlord_subscriptions;
create policy "landlord subscriptions admin staff country all"
on public.landlord_subscriptions for all to authenticated
using (
  public.is_admin_staff_for_country(country_id)
  or public.admin_staff_can_access_landlord(landlord_id)
)
with check (
  public.is_admin_staff_for_country(country_id)
  or public.admin_staff_can_access_landlord(landlord_id)
);

drop policy if exists "landlord subscriptions landlord read own" on public.landlord_subscriptions;
create policy "landlord subscriptions landlord read own"
on public.landlord_subscriptions for select to authenticated
using (landlord_id = auth.uid());

drop policy if exists "landlord subscriptions approved staff read assigned landlord" on public.landlord_subscriptions;
create policy "landlord subscriptions approved staff read assigned landlord"
on public.landlord_subscriptions for select to authenticated
using (
  exists (
    select 1
    from public.staff_permissions sp
    where sp.landlord_id = landlord_subscriptions.landlord_id
      and sp.staff_profile_id = auth.uid()
      and sp.status = 'approved'
  )
);

drop policy if exists "platform payments super admin all" on public.platform_payments;
create policy "platform payments super admin all"
on public.platform_payments for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "platform payments admin staff country all" on public.platform_payments;
drop policy if exists "platform payments admin staff country select" on public.platform_payments;
create policy "platform payments admin staff country select"
on public.platform_payments for select to authenticated
using (
  public.is_admin_staff_for_country(country_id)
  or public.admin_staff_can_access_landlord(landlord_id)
);

drop policy if exists "platform payments admin staff country insert" on public.platform_payments;
create policy "platform payments admin staff country insert"
on public.platform_payments for insert to authenticated
with check (
  public.is_admin_staff_for_country(country_id)
  or public.admin_staff_can_access_landlord(landlord_id)
);

drop policy if exists "partner payments super admin all" on public.partner_payments;
create policy "partner payments super admin all"
on public.partner_payments for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "partner payments ipm own" on public.partner_payments;
create policy "partner payments ipm own"
on public.partner_payments for all to authenticated
using (
  partner_type = 'ipm'
  and partner_staff_id = auth.uid()
  and exists (
    select 1 from public.staff_permissions sp
    where sp.staff_profile_id = auth.uid()
      and sp.landlord_id = partner_payments.landlord_id
      and sp.status = 'approved'
  )
)
with check (
  partner_type = 'ipm'
  and partner_staff_id = auth.uid()
  and recorded_by = auth.uid()
  and exists (
    select 1 from public.staff_permissions sp
    where sp.staff_profile_id = auth.uid()
      and sp.landlord_id = partner_payments.landlord_id
      and sp.status = 'approved'
  )
);

drop policy if exists "partner payments pmc own" on public.partner_payments;
create policy "partner payments pmc own"
on public.partner_payments for all to authenticated
using (
  partner_type = 'pmc'
  and (
    exists (
      select 1 from public.management_companies mc
      where mc.id = partner_payments.management_company_id
        and mc.leader_profile_id = auth.uid()
    )
    or exists (
      select 1 from public.management_staff_permissions msp
      where msp.management_company_id = partner_payments.management_company_id
        and msp.staff_profile_id = auth.uid()
        and msp.status = 'approved'
        and (msp.can_view_finance = true or msp.can_log_payments = true or msp.can_view_payments = true)
    )
  )
)
with check (
  partner_type = 'pmc'
  and recorded_by = auth.uid()
  and exists (
    select 1 from public.management_landlord_permissions mlp
    where mlp.management_company_id = partner_payments.management_company_id
      and mlp.landlord_id = partner_payments.landlord_id
      and mlp.status = 'approved'
  )
  and (
    exists (
      select 1 from public.management_companies mc
      where mc.id = partner_payments.management_company_id
        and mc.leader_profile_id = auth.uid()
    )
    or exists (
      select 1 from public.management_staff_permissions msp
      where msp.management_company_id = partner_payments.management_company_id
        and msp.staff_profile_id = auth.uid()
        and msp.status = 'approved'
        and (msp.can_view_finance = true or msp.can_log_payments = true or msp.can_view_payments = true)
    )
  )
);

drop policy if exists "partner reconciliations super admin all" on public.partner_reconciliations;
create policy "partner reconciliations super admin all"
on public.partner_reconciliations for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "partner reconciliations landlord read" on public.partner_reconciliations;
create policy "partner reconciliations landlord read"
on public.partner_reconciliations for select to authenticated
using (landlord_id = auth.uid());

drop policy if exists "partner reconciliations landlord review" on public.partner_reconciliations;
create policy "partner reconciliations landlord review"
on public.partner_reconciliations for update to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "partner reconciliations ipm own" on public.partner_reconciliations;
create policy "partner reconciliations ipm own"
on public.partner_reconciliations for all to authenticated
using (
  partner_type = 'ipm'
  and partner_staff_id = auth.uid()
  and exists (
    select 1 from public.staff_permissions sp
    where sp.staff_profile_id = auth.uid()
      and sp.landlord_id = partner_reconciliations.landlord_id
      and sp.status = 'approved'
  )
)
with check (
  partner_type = 'ipm'
  and partner_staff_id = auth.uid()
  and submitted_by = auth.uid()
  and exists (
    select 1 from public.staff_permissions sp
    where sp.staff_profile_id = auth.uid()
      and sp.landlord_id = partner_reconciliations.landlord_id
      and sp.status = 'approved'
  )
);

drop policy if exists "partner reconciliations pmc own" on public.partner_reconciliations;
create policy "partner reconciliations pmc own"
on public.partner_reconciliations for all to authenticated
using (
  partner_type = 'pmc'
  and exists (
    select 1 from public.management_landlord_permissions mlp
    where mlp.management_company_id = partner_reconciliations.management_company_id
      and mlp.landlord_id = partner_reconciliations.landlord_id
      and mlp.status = 'approved'
  )
  and (
    exists (
      select 1 from public.management_companies mc
      where mc.id = partner_reconciliations.management_company_id
        and mc.leader_profile_id = auth.uid()
    )
    or exists (
      select 1 from public.management_staff_permissions msp
      where msp.management_company_id = partner_reconciliations.management_company_id
        and msp.staff_profile_id = auth.uid()
        and msp.status = 'approved'
        and (msp.can_view_finance = true or msp.can_log_payments = true or msp.can_view_payments = true)
    )
  )
)
with check (
  partner_type = 'pmc'
  and submitted_by = auth.uid()
  and exists (
    select 1 from public.management_landlord_permissions mlp
    where mlp.management_company_id = partner_reconciliations.management_company_id
      and mlp.landlord_id = partner_reconciliations.landlord_id
      and mlp.status = 'approved'
  )
  and (
    exists (
      select 1 from public.management_companies mc
      where mc.id = partner_reconciliations.management_company_id
        and mc.leader_profile_id = auth.uid()
    )
    or exists (
      select 1 from public.management_staff_permissions msp
      where msp.management_company_id = partner_reconciliations.management_company_id
        and msp.staff_profile_id = auth.uid()
        and msp.status = 'approved'
        and (msp.can_view_finance = true or msp.can_log_payments = true or msp.can_view_payments = true)
    )
  )
);

drop policy if exists "invite tokens super admin manage landlord invites" on public.invite_tokens;
create policy "invite tokens super admin manage landlord invites"
on public.invite_tokens for all to authenticated
using (public.is_super_admin() and role = 'landlord')
with check (public.is_super_admin() and role = 'landlord' and landlord_id is null);

drop policy if exists "invite tokens super admin manage management invites" on public.invite_tokens;
create policy "invite tokens super admin manage management invites"
on public.invite_tokens for all to authenticated
using (public.is_super_admin() and role = 'management_leader')
with check (public.is_super_admin() and role = 'management_leader' and landlord_id is null);

drop policy if exists "invite tokens super admin manage freelancer staff invites" on public.invite_tokens;
create policy "invite tokens super admin manage freelancer staff invites"
on public.invite_tokens for all to authenticated
using (
  public.is_super_admin()
  and role = 'staff'
  and landlord_id is null
  and metadata ->> 'staff_type' = 'freelancer'
)
with check (
  public.is_super_admin()
  and role = 'staff'
  and landlord_id is null
  and metadata ->> 'staff_type' = 'freelancer'
  and country_id is not null
);

drop policy if exists "invite tokens super admin manage admin staff invites" on public.invite_tokens;
create policy "invite tokens super admin manage admin staff invites"
on public.invite_tokens for all to authenticated
using (public.is_super_admin() and role = 'admin_staff')
with check (public.is_super_admin() and role = 'admin_staff' and landlord_id is null and country_id is not null);

drop policy if exists "invite tokens admin staff manage country invites" on public.invite_tokens;
create policy "invite tokens admin staff manage country invites"
on public.invite_tokens for all to authenticated
using (
  public.is_admin_staff_for_country(country_id)
  and role in ('landlord', 'management_leader', 'staff')
  and (
    role <> 'staff'
    or (landlord_id is null and metadata ->> 'staff_type' = 'freelancer')
  )
)
with check (
  public.is_admin_staff_for_country(country_id)
  and landlord_id is null
  and role in ('landlord', 'management_leader', 'staff')
  and (
    role <> 'staff'
    or metadata ->> 'staff_type' = 'freelancer'
  )
);

drop policy if exists "invite tokens landlord manage owned invites" on public.invite_tokens;
create policy "invite tokens landlord manage owned invites"
on public.invite_tokens for all to authenticated
using (landlord_id = auth.uid() and public.is_landlord())
with check (
  landlord_id = auth.uid()
  and public.is_landlord()
  and (
    role = 'tenant'
    or (
      role = 'staff'
      and coalesce(metadata ->> 'staff_type', 'landlord') = 'landlord'
      and public.landlord_can_invite_personal_staff(auth.uid())
    )
  )
);

drop policy if exists "invite tokens management leader manage staff invites" on public.invite_tokens;
create policy "invite tokens management leader manage staff invites"
on public.invite_tokens for all to authenticated
using (
  role = 'management_staff'
  and exists (
    select 1
    from public.management_companies mc
    where mc.id::text = invite_tokens.metadata ->> 'management_company_id'
      and mc.leader_profile_id = auth.uid()
      and mc.archived_at is null
  )
)
with check (
  role = 'management_staff'
  and exists (
    select 1
    from public.management_companies mc
    where mc.id::text = invite_tokens.metadata ->> 'management_company_id'
      and mc.leader_profile_id = auth.uid()
      and mc.archived_at is null
  )
);

drop policy if exists "invite tokens invited user mark used" on public.invite_tokens;
create policy "invite tokens invited user mark used"
on public.invite_tokens for update to authenticated
using (
  lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  and used = false
  and expires_at > now()
)
with check (
  lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  and used = true
);

drop policy if exists "properties landlord all" on public.properties;
drop policy if exists "properties super admin read" on public.properties;
drop policy if exists "properties landlord select" on public.properties;
drop policy if exists "properties landlord insert" on public.properties;
drop policy if exists "properties landlord update" on public.properties;
drop policy if exists "properties landlord delete" on public.properties;
create policy "properties super admin read"
on public.properties for select to authenticated
using (public.current_profile_role() = 'super_admin');

drop policy if exists "properties admin staff country read" on public.properties;
create policy "properties admin staff country read"
on public.properties for select to authenticated
using (public.admin_staff_can_access_landlord(landlord_id));

create policy "properties landlord select"
on public.properties for select to authenticated
using (landlord_id = auth.uid());

create policy "properties landlord insert"
on public.properties for insert to authenticated
with check (landlord_id = auth.uid() and public.landlord_can_add_property(auth.uid()));

create policy "properties landlord update"
on public.properties for update to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

create policy "properties landlord delete"
on public.properties for delete to authenticated
using (landlord_id = auth.uid());

drop policy if exists "properties staff read scoped" on public.properties;
create policy "properties staff read scoped"
on public.properties for select to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_view_properties')
  and public.staff_can_access_property(id)
);

drop policy if exists "properties staff insert scoped" on public.properties;
create policy "properties staff insert scoped"
on public.properties for insert to authenticated
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_add_properties')
  and landlord_id = public.current_landlord_id()
  and public.landlord_can_add_property(landlord_id)
);

drop policy if exists "properties staff edit scoped" on public.properties;
create policy "properties staff edit scoped"
on public.properties for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_edit_properties')
  and public.staff_can_access_property(id)
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_edit_properties')
  and landlord_id = public.current_landlord_id()
  and archived_at is null
);

drop policy if exists "properties staff archive scoped" on public.properties;
create policy "properties staff archive scoped"
on public.properties for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_archive_properties')
  and public.staff_can_access_property(id)
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_archive_properties')
  and landlord_id = public.current_landlord_id()
  and archived_at is not null
);

drop policy if exists "properties management read scoped" on public.properties;
create policy "properties management read scoped"
on public.properties for select to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_view_properties')
  and public.management_can_access_property(id)
);

drop policy if exists "properties management insert scoped" on public.properties;
create policy "properties management insert scoped"
on public.properties for insert to authenticated
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_add_properties')
  and public.landlord_can_add_property(landlord_id)
  and exists (
    select 1
    from public.management_landlord_permissions mlp
    where mlp.management_company_id = public.current_management_company_id()
      and mlp.landlord_id = properties.landlord_id
      and mlp.status = 'approved'
      and (
        public.current_profile_role() <> 'management_staff'
        or mlp.landlord_id = (select p.landlord_id from public.profiles p where p.id = auth.uid())
      )
  )
);

drop policy if exists "properties management edit scoped" on public.properties;
create policy "properties management edit scoped"
on public.properties for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_edit_properties')
  and public.management_can_access_property(id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_edit_properties')
  and public.management_can_access_property(id)
  and archived_at is null
);

drop policy if exists "properties management archive scoped" on public.properties;
create policy "properties management archive scoped"
on public.properties for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_archive_properties')
  and public.management_can_access_property(id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_archive_properties')
  and public.management_can_access_property(id)
  and archived_at is not null
);

drop policy if exists "properties tenant read own" on public.properties;
create policy "properties tenant read own"
on public.properties for select to authenticated
using (public.tenant_can_access_property(id));

drop policy if exists "units landlord all" on public.units;
drop policy if exists "units super admin read" on public.units;
create policy "units super admin read"
on public.units for select to authenticated
using (public.is_super_admin());

drop policy if exists "units admin staff country read" on public.units;
create policy "units admin staff country read"
on public.units for select to authenticated
using (public.admin_staff_can_access_unit(id));

create policy "units landlord all"
on public.units for all to authenticated
using (
  exists (select 1 from public.properties p where p.id = property_id and p.landlord_id = auth.uid())
)
with check (
  exists (select 1 from public.properties p where p.id = property_id and p.landlord_id = auth.uid())
);

drop policy if exists "units staff read scoped" on public.units;
create policy "units staff read scoped"
on public.units for select to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_view_units')
  and public.staff_can_access_unit(id)
);

drop policy if exists "units staff insert scoped" on public.units;
create policy "units staff insert scoped"
on public.units for insert to authenticated
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_add_units')
  and public.staff_can_access_property(property_id)
);

drop policy if exists "units staff edit scoped" on public.units;
create policy "units staff edit scoped"
on public.units for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_edit_units')
  and public.staff_can_access_unit(id)
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_edit_units')
  and public.staff_can_access_property(property_id)
  and archived_at is null
);

drop policy if exists "units staff mark vacant scoped" on public.units;
create policy "units staff mark vacant scoped"
on public.units for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_mark_units_vacant')
  and public.staff_can_access_unit(id)
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_mark_units_vacant')
  and public.staff_can_access_property(property_id)
  and status = 'vacant'
  and archived_at is null
);

drop policy if exists "units staff archive scoped" on public.units;
create policy "units staff archive scoped"
on public.units for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_archive_units')
  and public.staff_can_access_unit(id)
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_archive_units')
  and public.staff_can_access_property(property_id)
  and archived_at is not null
);

drop policy if exists "units management read scoped" on public.units;
create policy "units management read scoped"
on public.units for select to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_view_units')
  and public.management_can_access_unit(id)
);

drop policy if exists "units management insert scoped" on public.units;
create policy "units management insert scoped"
on public.units for insert to authenticated
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_add_units')
  and public.management_can_access_property(property_id)
);

drop policy if exists "units management edit scoped" on public.units;
create policy "units management edit scoped"
on public.units for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_edit_units')
  and public.management_can_access_unit(id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_edit_units')
  and public.management_can_access_property(property_id)
  and archived_at is null
);

drop policy if exists "units management mark vacant scoped" on public.units;
create policy "units management mark vacant scoped"
on public.units for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_mark_units_vacant')
  and public.management_can_access_unit(id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_mark_units_vacant')
  and public.management_can_access_property(property_id)
  and status = 'vacant'
  and archived_at is null
);

drop policy if exists "units management archive scoped" on public.units;
create policy "units management archive scoped"
on public.units for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_archive_units')
  and public.management_can_access_unit(id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_archive_units')
  and public.management_can_access_property(property_id)
  and archived_at is not null
);

drop policy if exists "units tenant read own" on public.units;
create policy "units tenant read own"
on public.units for select to authenticated
using (
  exists (
    select 1
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    where l.unit_id = units.id
      and t.profile_id = auth.uid()
  )
);

drop policy if exists "staff permissions landlord all" on public.staff_permissions;
create policy "staff permissions landlord all"
on public.staff_permissions for all to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "staff permissions super admin all" on public.staff_permissions;
create policy "staff permissions super admin all"
on public.staff_permissions for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "staff permissions admin staff country read" on public.staff_permissions;
create policy "staff permissions admin staff country read"
on public.staff_permissions for select to authenticated
using (public.admin_staff_can_access_landlord(landlord_id));

drop policy if exists "staff permissions staff read own" on public.staff_permissions;
create policy "staff permissions staff read own"
on public.staff_permissions for select to authenticated
using (staff_profile_id = auth.uid());

drop policy if exists "staff requests landlord all" on public.staff_landlord_requests;
create policy "staff requests landlord all"
on public.staff_landlord_requests for all to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "staff requests staff read own" on public.staff_landlord_requests;
create policy "staff requests staff read own"
on public.staff_landlord_requests for select to authenticated
using (staff_profile_id = auth.uid());

drop policy if exists "staff requests staff insert own" on public.staff_landlord_requests;
create policy "staff requests staff insert own"
on public.staff_landlord_requests for insert to authenticated
with check (staff_profile_id = auth.uid());

drop policy if exists "staff requests super admin all" on public.staff_landlord_requests;
create policy "staff requests super admin all"
on public.staff_landlord_requests for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "staff requests admin staff country read" on public.staff_landlord_requests;
create policy "staff requests admin staff country read"
on public.staff_landlord_requests for select to authenticated
using (public.admin_staff_can_access_landlord(landlord_id));

drop policy if exists "staff permissions invited staff insert own" on public.staff_permissions;
create policy "staff permissions invited staff insert own"
on public.staff_permissions for insert to authenticated
with check (
  staff_profile_id = auth.uid()
  and landlord_id = public.current_landlord_id()
  and public.staff_permission_insert_allowed(
    landlord_id,
    all_properties,
    property_ids,
    can_view_tenants,
    can_manage_maintenance,
    can_view_payments,
    can_verify_payments,
    can_manage_leases
  )
);

drop policy if exists "management companies super admin all" on public.management_companies;
create policy "management companies super admin all"
on public.management_companies for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "management companies admin staff country all" on public.management_companies;
create policy "management companies admin staff country all"
on public.management_companies for all to authenticated
using (public.is_admin_staff_for_country(country_id))
with check (public.is_admin_staff_for_country(country_id));

drop policy if exists "management companies leader read own" on public.management_companies;
create policy "management companies leader read own"
on public.management_companies for select to authenticated
using (leader_profile_id = auth.uid());

drop policy if exists "management companies landlord read related" on public.management_companies;
create policy "management companies landlord read related"
on public.management_companies for select to authenticated
using (
  public.is_landlord()
  and (
    exists (
      select 1 from public.management_landlord_permissions mlp
      where mlp.management_company_id = management_companies.id
        and mlp.landlord_id = auth.uid()
    )
    or exists (
      select 1 from public.management_landlord_requests mlr
      where mlr.management_company_id = management_companies.id
        and mlr.landlord_id = auth.uid()
    )
  )
);

drop policy if exists "management companies staff read own" on public.management_companies;
create policy "management companies staff read own"
on public.management_companies for select to authenticated
using (public.is_management_staff_for_company(id));

drop policy if exists "management requests leader all own" on public.management_landlord_requests;
create policy "management requests leader all own"
on public.management_landlord_requests for all to authenticated
using (leader_profile_id = auth.uid())
with check (leader_profile_id = auth.uid());

drop policy if exists "management requests landlord all own" on public.management_landlord_requests;
create policy "management requests landlord all own"
on public.management_landlord_requests for all to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "management requests super admin all" on public.management_landlord_requests;
create policy "management requests super admin all"
on public.management_landlord_requests for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "management requests admin staff country read" on public.management_landlord_requests;
create policy "management requests admin staff country read"
on public.management_landlord_requests for select to authenticated
using (public.admin_staff_can_access_landlord(landlord_id));

drop policy if exists "management permissions landlord all own" on public.management_landlord_permissions;
create policy "management permissions landlord all own"
on public.management_landlord_permissions for all to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "management permissions leader read own" on public.management_landlord_permissions;
create policy "management permissions leader read own"
on public.management_landlord_permissions for select to authenticated
using (leader_profile_id = auth.uid() or management_company_id = public.current_management_company_id());

drop policy if exists "management permissions super admin all" on public.management_landlord_permissions;
create policy "management permissions super admin all"
on public.management_landlord_permissions for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "management permissions admin staff country read" on public.management_landlord_permissions;
create policy "management permissions admin staff country read"
on public.management_landlord_permissions for select to authenticated
using (public.admin_staff_can_access_landlord(landlord_id));

drop policy if exists "management staff permissions leader all own" on public.management_staff_permissions;
create policy "management staff permissions leader all own"
on public.management_staff_permissions for all to authenticated
using (public.is_management_leader_for_company(management_company_id))
with check (public.is_management_leader_for_company(management_company_id));

drop policy if exists "management staff permissions staff read own" on public.management_staff_permissions;
create policy "management staff permissions staff read own"
on public.management_staff_permissions for select to authenticated
using (staff_profile_id = auth.uid());

drop policy if exists "management staff permissions invited staff insert own" on public.management_staff_permissions;
create policy "management staff permissions invited staff insert own"
on public.management_staff_permissions for insert to authenticated
with check (
  staff_profile_id = auth.uid()
  and public.current_profile_role() = 'management_staff'
  and public.management_staff_permission_insert_allowed(
    management_company_id,
    (select p.landlord_id from public.profiles p where p.id = auth.uid()),
    all_properties,
    property_ids,
    can_view_tenants,
    can_manage_maintenance,
    can_view_payments,
    can_verify_payments,
    can_manage_leases
  )
);

drop policy if exists "management staff permissions super admin read" on public.management_staff_permissions;
create policy "management staff permissions super admin read"
on public.management_staff_permissions for select to authenticated
using (public.is_super_admin());

drop policy if exists "management staff permissions admin staff country read" on public.management_staff_permissions;
create policy "management staff permissions admin staff country read"
on public.management_staff_permissions for select to authenticated
using (
  exists (
    select 1
    from public.management_companies mc
    where mc.id = management_staff_permissions.management_company_id
      and public.is_admin_staff_for_country(mc.country_id)
  )
);

drop policy if exists "tenants landlord all" on public.tenants;
create policy "tenants landlord all"
on public.tenants for all to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "tenants super admin read" on public.tenants;
drop policy if exists "tenants super admin all" on public.tenants;
create policy "tenants super admin all"
on public.tenants for all to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

drop policy if exists "tenants admin staff country read" on public.tenants;
drop policy if exists "tenants admin staff country all" on public.tenants;
create policy "tenants admin staff country all"
on public.tenants for all to authenticated
using (public.admin_staff_can_access_landlord(landlord_id))
with check (public.admin_staff_can_access_landlord(landlord_id));

drop policy if exists "tenants staff read scoped" on public.tenants;
create policy "tenants staff read scoped"
on public.tenants for select to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_view_tenants')
  and public.staff_can_access_tenant(id)
);

drop policy if exists "tenants management read scoped" on public.tenants;
create policy "tenants management read scoped"
on public.tenants for select to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_view_tenants')
  and public.management_can_access_tenant(id)
);

drop policy if exists "tenants staff edit scoped" on public.tenants;
create policy "tenants staff edit scoped"
on public.tenants for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_edit_tenants')
  and landlord_id = public.current_landlord_id()
  and public.staff_can_access_tenant(id)
  and archived_at is null
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_edit_tenants')
  and landlord_id = public.current_landlord_id()
  and public.staff_can_access_tenant(id)
  and archived_at is null
);

drop policy if exists "tenants management edit scoped" on public.tenants;
create policy "tenants management edit scoped"
on public.tenants for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_edit_tenants')
  and public.management_can_access_tenant(id)
  and archived_at is null
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_edit_tenants')
  and public.management_can_access_tenant(id)
  and archived_at is null
);

drop policy if exists "tenants tenant read own" on public.tenants;
create policy "tenants tenant read own"
on public.tenants for select to authenticated
using (
  profile_id = auth.uid()
  and invite_accepted = true
  and archived_at is null
);

drop policy if exists "tenants invited tenant link own row" on public.tenants;
create policy "tenants invited tenant link own row"
on public.tenants for update to authenticated
using (
  lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  and public.tenant_link_allowed(id, landlord_id, email)
)
with check (
  profile_id = auth.uid()
  and invite_accepted = true
  and public.tenant_link_allowed(id, landlord_id, email)
);

drop policy if exists "leases landlord all" on public.leases;
drop policy if exists "leases super admin read" on public.leases;
create policy "leases super admin read"
on public.leases for select to authenticated
using (public.is_super_admin());

drop policy if exists "leases admin staff country read" on public.leases;
create policy "leases admin staff country read"
on public.leases for select to authenticated
using (public.admin_staff_can_access_landlord(landlord_id));

create policy "leases landlord all"
on public.leases for all to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "leases staff read scoped" on public.leases;
create policy "leases staff read scoped"
on public.leases for select to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_can_access_lease(id)
  and (
    public.staff_permission_flag('can_view_leases')
    or public.staff_permission_flag('can_manage_leases')
    or public.staff_permission_flag('can_view_tenants')
    or public.staff_permission_flag('can_view_payments')
  )
);

drop policy if exists "leases management read scoped" on public.leases;
create policy "leases management read scoped"
on public.leases for select to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_can_access_lease(id)
  and (
    public.management_permission_flag('can_view_leases')
    or public.management_permission_flag('can_view_tenants')
    or public.management_permission_flag('can_view_payments')
  )
);

drop policy if exists "leases staff manage scoped" on public.leases;
drop policy if exists "leases staff insert scoped" on public.leases;
drop policy if exists "leases staff update scoped" on public.leases;
create policy "leases staff insert scoped"
on public.leases for insert to authenticated
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_create_leases')
  and public.staff_can_access_unit(unit_id)
  and landlord_id = public.current_landlord_id()
);

drop policy if exists "leases management insert scoped" on public.leases;
create policy "leases management insert scoped"
on public.leases for insert to authenticated
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_create_leases')
  and public.management_can_access_unit(unit_id)
);

drop policy if exists "leases management update scoped" on public.leases;
create policy "leases management update scoped"
on public.leases for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and (
    public.management_permission_flag('can_edit_leases')
    or public.management_permission_flag('can_terminate_leases')
    or public.management_permission_flag('can_upload_lease_documents')
    or public.management_permission_flag('can_mark_units_vacant')
  )
  and public.management_can_access_lease(id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and (
    public.management_permission_flag('can_edit_leases')
    or public.management_permission_flag('can_terminate_leases')
    or public.management_permission_flag('can_upload_lease_documents')
    or public.management_permission_flag('can_mark_units_vacant')
  )
  and public.management_can_access_unit(unit_id)
);

drop policy if exists "leases management mark unit vacant scoped" on public.leases;
create policy "leases management mark unit vacant scoped"
on public.leases for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_mark_units_vacant')
  and public.management_can_access_lease(id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_mark_units_vacant')
  and public.management_can_access_unit(unit_id)
  and status = 'terminated'
);

create policy "leases staff update scoped"
on public.leases for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and (
    public.staff_permission_flag('can_edit_leases')
    or public.staff_permission_flag('can_terminate_leases')
    or public.staff_permission_flag('can_upload_lease_documents')
    or public.staff_permission_flag('can_mark_units_vacant')
  )
  and public.staff_can_access_lease(id)
)
with check (
  public.current_profile_role() = 'staff'
  and (
    public.staff_permission_flag('can_edit_leases')
    or public.staff_permission_flag('can_terminate_leases')
    or public.staff_permission_flag('can_upload_lease_documents')
    or public.staff_permission_flag('can_mark_units_vacant')
  )
  and public.staff_can_access_unit(unit_id)
  and landlord_id = public.current_landlord_id()
);

drop policy if exists "leases staff mark unit vacant scoped" on public.leases;
create policy "leases staff mark unit vacant scoped"
on public.leases for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_mark_units_vacant')
  and public.staff_can_access_lease(id)
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_mark_units_vacant')
  and public.staff_can_access_unit(unit_id)
  and landlord_id = public.current_landlord_id()
  and status = 'terminated'
);

drop policy if exists "leases tenant read own" on public.leases;
create policy "leases tenant read own"
on public.leases for select to authenticated
using (
  exists (
    select 1 from public.tenants t
    where t.id = tenant_id and t.profile_id = auth.uid()
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lease-documents', 'lease-documents', false, 20971520, array['application/pdf']::text[])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tenant-documents',
  'tenant-documents',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs',
  'payment-proofs',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'maintenance-photos',
  'maintenance-photos',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'inspection-files',
  'inspection-files',
  false,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm', 'application/pdf']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "lease documents read scoped" on storage.objects;
create policy "lease documents read scoped"
on storage.objects for select to authenticated
using (
  bucket_id = 'lease-documents'
  and public.can_read_lease_document(name)
);

drop policy if exists "lease documents insert scoped" on storage.objects;
create policy "lease documents insert scoped"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'lease-documents'
  and public.can_manage_lease_document(name)
);

drop policy if exists "lease documents update scoped" on storage.objects;
create policy "lease documents update scoped"
on storage.objects for update to authenticated
using (
  bucket_id = 'lease-documents'
  and public.can_manage_lease_document(name)
)
with check (
  bucket_id = 'lease-documents'
  and public.can_manage_lease_document(name)
);

drop policy if exists "lease documents delete scoped" on storage.objects;
create policy "lease documents delete scoped"
on storage.objects for delete to authenticated
using (
  bucket_id = 'lease-documents'
  and public.can_manage_lease_document(name)
);

drop policy if exists "tenant documents files read scoped" on storage.objects;
create policy "tenant documents files read scoped"
on storage.objects for select to authenticated
using (
  bucket_id = 'tenant-documents'
  and public.can_read_tenant_document(name)
);

drop policy if exists "tenant documents files insert scoped" on storage.objects;
create policy "tenant documents files insert scoped"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'tenant-documents'
  and public.can_manage_tenant_document(name)
);

drop policy if exists "tenant documents files update scoped" on storage.objects;
create policy "tenant documents files update scoped"
on storage.objects for update to authenticated
using (
  bucket_id = 'tenant-documents'
  and public.can_manage_tenant_document(name)
)
with check (
  bucket_id = 'tenant-documents'
  and public.can_manage_tenant_document(name)
);

drop policy if exists "tenant documents files delete scoped" on storage.objects;
create policy "tenant documents files delete scoped"
on storage.objects for delete to authenticated
using (
  bucket_id = 'tenant-documents'
  and public.can_manage_tenant_document(name)
);

drop policy if exists "payment proofs read scoped" on storage.objects;
create policy "payment proofs read scoped"
on storage.objects for select to authenticated
using (
  bucket_id = 'payment-proofs'
  and public.can_read_payment_proof(name)
);

drop policy if exists "payment proofs insert scoped" on storage.objects;
create policy "payment proofs insert scoped"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'payment-proofs'
  and public.can_manage_payment_proof(name)
);

drop policy if exists "payment proofs update scoped" on storage.objects;
create policy "payment proofs update scoped"
on storage.objects for update to authenticated
using (
  bucket_id = 'payment-proofs'
  and public.can_manage_payment_proof(name)
)
with check (
  bucket_id = 'payment-proofs'
  and public.can_manage_payment_proof(name)
);

drop policy if exists "payment proofs delete scoped" on storage.objects;
create policy "payment proofs delete scoped"
on storage.objects for delete to authenticated
using (
  bucket_id = 'payment-proofs'
  and public.can_manage_payment_proof(name)
);

drop policy if exists "maintenance photos read scoped" on storage.objects;
create policy "maintenance photos read scoped"
on storage.objects for select to authenticated
using (
  bucket_id = 'maintenance-photos'
  and public.can_read_maintenance_photo(name)
);

drop policy if exists "maintenance photos insert scoped" on storage.objects;
create policy "maintenance photos insert scoped"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'maintenance-photos'
  and public.can_manage_maintenance_photo(name)
);

drop policy if exists "maintenance photos update scoped" on storage.objects;
create policy "maintenance photos update scoped"
on storage.objects for update to authenticated
using (
  bucket_id = 'maintenance-photos'
  and public.can_manage_maintenance_photo(name)
)
with check (
  bucket_id = 'maintenance-photos'
  and public.can_manage_maintenance_photo(name)
);

drop policy if exists "maintenance photos delete scoped" on storage.objects;
create policy "maintenance photos delete scoped"
on storage.objects for delete to authenticated
using (
  bucket_id = 'maintenance-photos'
  and public.can_manage_maintenance_photo(name)
);

drop policy if exists "inspection files read scoped" on storage.objects;
create policy "inspection files read scoped"
on storage.objects for select to authenticated
using (
  bucket_id = 'inspection-files'
  and public.can_read_inspection_file(name)
);

drop policy if exists "inspection files insert scoped" on storage.objects;
create policy "inspection files insert scoped"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'inspection-files'
  and public.can_manage_inspection_file(name)
);

drop policy if exists "inspection files update scoped" on storage.objects;
create policy "inspection files update scoped"
on storage.objects for update to authenticated
using (
  bucket_id = 'inspection-files'
  and public.can_manage_inspection_file(name)
)
with check (
  bucket_id = 'inspection-files'
  and public.can_manage_inspection_file(name)
);

drop policy if exists "inspection files delete scoped" on storage.objects;
create policy "inspection files delete scoped"
on storage.objects for delete to authenticated
using (
  bucket_id = 'inspection-files'
  and public.can_manage_inspection_file(name)
);

drop policy if exists "payment submissions landlord all" on public.payment_submissions;
create policy "payment submissions landlord all"
on public.payment_submissions for all to authenticated
using (
  exists (select 1 from public.leases l where l.id = lease_id and l.landlord_id = auth.uid())
)
with check (
  exists (select 1 from public.leases l where l.id = lease_id and l.landlord_id = auth.uid())
);

drop policy if exists "payment submissions staff read scoped" on public.payment_submissions;
create policy "payment submissions staff read scoped"
on public.payment_submissions for select to authenticated
using (
  public.current_profile_role() = 'staff'
  and (public.staff_permission_flag('can_view_payments') or public.staff_permission_flag('can_verify_payments'))
  and public.staff_can_access_lease(lease_id)
);

drop policy if exists "payment submissions staff verify scoped" on public.payment_submissions;
create policy "payment submissions staff verify scoped"
on public.payment_submissions for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_verify_payments')
  and public.staff_can_access_lease(lease_id)
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_verify_payments')
  and public.staff_can_access_lease(lease_id)
);

drop policy if exists "payment submissions management read scoped" on public.payment_submissions;
create policy "payment submissions management read scoped"
on public.payment_submissions for select to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and (public.management_permission_flag('can_view_payments') or public.management_permission_flag('can_verify_payments'))
  and public.management_can_access_lease(lease_id)
);

drop policy if exists "payment submissions management verify scoped" on public.payment_submissions;
create policy "payment submissions management verify scoped"
on public.payment_submissions for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_verify_payments')
  and public.management_can_access_lease(lease_id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_verify_payments')
  and public.management_can_access_lease(lease_id)
);

drop policy if exists "payment submissions tenant own" on public.payment_submissions;
create policy "payment submissions tenant own"
on public.payment_submissions for select to authenticated
using (
  exists (select 1 from public.tenants t where t.id = tenant_id and t.profile_id = auth.uid())
);

drop policy if exists "payment submissions tenant insert own" on public.payment_submissions;
create policy "payment submissions tenant insert own"
on public.payment_submissions for insert to authenticated
with check (
  status = 'pending'
  and exists (select 1 from public.tenants t where t.id = tenant_id and t.profile_id = auth.uid())
  and exists (
    select 1 from public.leases l
    where l.id = lease_id and l.tenant_id = tenant_id and l.status = 'active'
  )
);

drop policy if exists "payments landlord all" on public.payments;
create policy "payments landlord all"
on public.payments for all to authenticated
using (
  exists (select 1 from public.leases l where l.id = lease_id and l.landlord_id = auth.uid())
)
with check (
  recorded_by = auth.uid()
  and exists (select 1 from public.leases l where l.id = lease_id and l.landlord_id = auth.uid())
);

drop policy if exists "payments staff read scoped" on public.payments;
create policy "payments staff read scoped"
on public.payments for select to authenticated
using (
  public.current_profile_role() = 'staff'
  and (public.staff_permission_flag('can_view_payments') or public.staff_permission_flag('can_verify_payments'))
  and public.staff_can_access_lease(lease_id)
);

drop policy if exists "payments staff insert scoped" on public.payments;
create policy "payments staff insert scoped"
on public.payments for insert to authenticated
with check (
  recorded_by = auth.uid()
  and public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_verify_payments')
  and public.staff_can_access_lease(lease_id)
);

drop policy if exists "payments management read scoped" on public.payments;
create policy "payments management read scoped"
on public.payments for select to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and (public.management_permission_flag('can_view_payments') or public.management_permission_flag('can_verify_payments'))
  and public.management_can_access_lease(lease_id)
);

drop policy if exists "payments management insert scoped" on public.payments;
create policy "payments management insert scoped"
on public.payments for insert to authenticated
with check (
  recorded_by = auth.uid()
  and public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_verify_payments')
  and public.management_can_access_lease(lease_id)
);

drop policy if exists "payments tenant read own" on public.payments;
create policy "payments tenant read own"
on public.payments for select to authenticated
using (
  exists (
    select 1
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    where l.id = lease_id
      and t.profile_id = auth.uid()
  )
);

drop policy if exists "lease charges read scoped" on public.lease_charges;
create policy "lease charges read scoped"
on public.lease_charges for select to authenticated
using (public.current_user_can_access_lease_finance(lease_id));

drop policy if exists "lease charges manage scoped" on public.lease_charges;
create policy "lease charges manage scoped"
on public.lease_charges for all to authenticated
using (public.current_user_can_manage_lease_finance(lease_id))
with check (public.current_user_can_manage_lease_finance(lease_id));

drop policy if exists "payment allocations read scoped" on public.payment_allocations;
create policy "payment allocations read scoped"
on public.payment_allocations for select to authenticated
using (
  exists (
    select 1
    from public.lease_charges lc
    where lc.id = charge_id
      and public.current_user_can_access_lease_finance(lc.lease_id)
  )
);

drop policy if exists "payment allocations manage scoped" on public.payment_allocations;
create policy "payment allocations manage scoped"
on public.payment_allocations for all to authenticated
using (
  exists (
    select 1
    from public.lease_charges lc
    where lc.id = charge_id
      and public.current_user_can_manage_lease_finance(lc.lease_id)
  )
)
with check (
  exists (
    select 1
    from public.lease_charges lc
    where lc.id = charge_id
      and public.current_user_can_manage_lease_finance(lc.lease_id)
  )
);

drop policy if exists "lease ledger entries read scoped" on public.lease_ledger_entries;
create policy "lease ledger entries read scoped"
on public.lease_ledger_entries for select to authenticated
using (
  public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or landlord_id = auth.uid()
  or (lease_id is not null and public.current_user_can_access_lease_finance(lease_id))
);

drop policy if exists "lease ledger entries insert scoped" on public.lease_ledger_entries;
create policy "lease ledger entries insert scoped"
on public.lease_ledger_entries for insert to authenticated
with check (
  public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or landlord_id = auth.uid()
  or (lease_id is not null and public.current_user_can_manage_lease_finance(lease_id))
);

drop policy if exists "finance audit events read scoped" on public.finance_audit_events;
create policy "finance audit events read scoped"
on public.finance_audit_events for select to authenticated
using (
  public.is_super_admin()
  or (landlord_id is not null and public.admin_staff_can_access_landlord(landlord_id))
  or landlord_id = auth.uid()
  or (lease_id is not null and public.current_user_can_access_lease_finance(lease_id))
);

drop policy if exists "maintenance landlord all" on public.maintenance_requests;
create policy "maintenance landlord all"
on public.maintenance_requests for all to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "maintenance staff manage scoped" on public.maintenance_requests;
drop policy if exists "maintenance staff read scoped" on public.maintenance_requests;
drop policy if exists "maintenance staff insert scoped" on public.maintenance_requests;
drop policy if exists "maintenance staff update scoped" on public.maintenance_requests;
create policy "maintenance staff read scoped"
on public.maintenance_requests for select to authenticated
using (
  public.current_profile_role() = 'staff'
  and (
    public.staff_permission_flag('can_manage_maintenance')
    or public.staff_permission_flag('can_create_maintenance')
    or public.staff_permission_flag('can_assign_maintenance')
    or public.staff_permission_flag('can_add_resolution_notes')
  )
  and public.staff_can_access_unit(unit_id)
);

create policy "maintenance staff insert scoped"
on public.maintenance_requests for insert to authenticated
with check (
  public.current_profile_role() = 'staff'
  and public.staff_permission_flag('can_create_maintenance')
  and public.staff_can_access_unit(unit_id)
  and landlord_id = public.current_landlord_id()
);

create policy "maintenance staff update scoped"
on public.maintenance_requests for update to authenticated
using (
  public.current_profile_role() = 'staff'
  and (
    public.staff_permission_flag('can_assign_maintenance')
    or public.staff_permission_flag('can_add_resolution_notes')
  )
  and public.staff_can_access_unit(unit_id)
)
with check (
  public.current_profile_role() = 'staff'
  and (
    public.staff_permission_flag('can_assign_maintenance')
    or public.staff_permission_flag('can_add_resolution_notes')
  )
  and public.staff_can_access_unit(unit_id)
  and landlord_id = public.current_landlord_id()
);

drop policy if exists "maintenance management read scoped" on public.maintenance_requests;
create policy "maintenance management read scoped"
on public.maintenance_requests for select to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and (
    public.management_permission_flag('can_manage_maintenance')
    or public.management_permission_flag('can_create_maintenance')
    or public.management_permission_flag('can_assign_maintenance')
    or public.management_permission_flag('can_add_resolution_notes')
  )
  and public.management_can_access_unit(unit_id)
);

drop policy if exists "maintenance management insert scoped" on public.maintenance_requests;
create policy "maintenance management insert scoped"
on public.maintenance_requests for insert to authenticated
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_permission_flag('can_create_maintenance')
  and public.management_can_access_unit(unit_id)
);

drop policy if exists "maintenance management update scoped" on public.maintenance_requests;
create policy "maintenance management update scoped"
on public.maintenance_requests for update to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and (
    public.management_permission_flag('can_assign_maintenance')
    or public.management_permission_flag('can_add_resolution_notes')
  )
  and public.management_can_access_unit(unit_id)
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and (
    public.management_permission_flag('can_assign_maintenance')
    or public.management_permission_flag('can_add_resolution_notes')
  )
  and public.management_can_access_unit(unit_id)
);

drop policy if exists "maintenance tenant read own" on public.maintenance_requests;
create policy "maintenance tenant read own"
on public.maintenance_requests for select to authenticated
using (submitted_by_profile_id = auth.uid());

drop policy if exists "maintenance tenant insert own" on public.maintenance_requests;
create policy "maintenance tenant insert own"
on public.maintenance_requests for insert to authenticated
with check (
  submitted_by_profile_id = auth.uid()
  and exists (
    select 1
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    where l.id = lease_id
      and l.unit_id = unit_id
      and t.profile_id = auth.uid()
      and l.status = 'active'
      and l.landlord_id = maintenance_requests.landlord_id
  )
);

drop policy if exists "maintenance quotes landlord all" on public.maintenance_quotes;
create policy "maintenance quotes landlord all"
on public.maintenance_quotes for all to authenticated
using (landlord_id = auth.uid())
with check (landlord_id = auth.uid());

drop policy if exists "maintenance quotes staff scoped" on public.maintenance_quotes;
create policy "maintenance quotes staff scoped"
on public.maintenance_quotes for all to authenticated
using (
  public.current_profile_role() = 'staff'
  and public.staff_can_access_unit(unit_id)
  and (
    public.staff_permission_flag('can_create_maintenance')
    or public.staff_permission_flag('can_assign_maintenance')
    or public.staff_permission_flag('can_add_resolution_notes')
  )
)
with check (
  public.current_profile_role() = 'staff'
  and public.staff_can_access_unit(unit_id)
  and landlord_id = public.current_landlord_id()
  and (
    public.staff_permission_flag('can_create_maintenance')
    or public.staff_permission_flag('can_assign_maintenance')
    or public.staff_permission_flag('can_add_resolution_notes')
  )
);

drop policy if exists "maintenance quotes management scoped" on public.maintenance_quotes;
create policy "maintenance quotes management scoped"
on public.maintenance_quotes for all to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_can_access_unit(unit_id)
  and (
    public.management_permission_flag('can_create_maintenance')
    or public.management_permission_flag('can_assign_maintenance')
    or public.management_permission_flag('can_add_resolution_notes')
  )
)
with check (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and public.management_can_access_unit(unit_id)
  and (
    public.management_permission_flag('can_create_maintenance')
    or public.management_permission_flag('can_assign_maintenance')
    or public.management_permission_flag('can_add_resolution_notes')
  )
);

drop policy if exists "maintenance quotes tenant read own" on public.maintenance_quotes;
create policy "maintenance quotes tenant read own"
on public.maintenance_quotes for select to authenticated
using (
  exists (
    select 1
    from public.maintenance_requests mr
    where mr.id = maintenance_quotes.maintenance_request_id
      and mr.submitted_by_profile_id = auth.uid()
  )
);

drop policy if exists "maintenance activity landlord read" on public.maintenance_activity;
create policy "maintenance activity landlord read"
on public.maintenance_activity for select to authenticated
using (landlord_id = auth.uid());

drop policy if exists "maintenance activity staff read scoped" on public.maintenance_activity;
create policy "maintenance activity staff read scoped"
on public.maintenance_activity for select to authenticated
using (
  public.current_profile_role() = 'staff'
  and exists (
    select 1
    from public.maintenance_requests mr
    where mr.id = maintenance_activity.maintenance_request_id
      and public.staff_can_access_unit(mr.unit_id)
      and (
        public.staff_permission_flag('can_manage_maintenance')
        or public.staff_permission_flag('can_create_maintenance')
        or public.staff_permission_flag('can_assign_maintenance')
        or public.staff_permission_flag('can_add_resolution_notes')
      )
  )
);

drop policy if exists "maintenance activity management read scoped" on public.maintenance_activity;
create policy "maintenance activity management read scoped"
on public.maintenance_activity for select to authenticated
using (
  public.current_profile_role() in ('management_leader', 'management_staff')
  and exists (
    select 1
    from public.maintenance_requests mr
    where mr.id = maintenance_activity.maintenance_request_id
      and public.management_can_access_unit(mr.unit_id)
      and (
        public.management_permission_flag('can_manage_maintenance')
        or public.management_permission_flag('can_create_maintenance')
        or public.management_permission_flag('can_assign_maintenance')
        or public.management_permission_flag('can_add_resolution_notes')
      )
  )
);

drop policy if exists "maintenance activity tenant read own" on public.maintenance_activity;
create policy "maintenance activity tenant read own"
on public.maintenance_activity for select to authenticated
using (
  exists (
    select 1
    from public.maintenance_requests mr
    where mr.id = maintenance_activity.maintenance_request_id
      and mr.submitted_by_profile_id = auth.uid()
  )
);

drop policy if exists "maintenance activity insert for scoped request" on public.maintenance_activity;
create policy "maintenance activity insert for scoped request"
on public.maintenance_activity for insert to authenticated
with check (
  exists (
    select 1
    from public.maintenance_requests mr
    where mr.id = maintenance_activity.maintenance_request_id
      and (
        mr.landlord_id = auth.uid()
        or mr.submitted_by_profile_id = auth.uid()
        or (
          public.current_profile_role() = 'staff'
          and public.staff_can_access_unit(mr.unit_id)
          and (
            public.staff_permission_flag('can_manage_maintenance')
            or public.staff_permission_flag('can_create_maintenance')
            or public.staff_permission_flag('can_assign_maintenance')
            or public.staff_permission_flag('can_add_resolution_notes')
          )
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and public.management_can_access_unit(mr.unit_id)
          and (
            public.management_permission_flag('can_manage_maintenance')
            or public.management_permission_flag('can_create_maintenance')
            or public.management_permission_flag('can_assign_maintenance')
            or public.management_permission_flag('can_add_resolution_notes')
          )
        )
      )
  )
);

drop policy if exists "property inspections read scoped" on public.property_inspections;
create policy "property inspections read scoped"
on public.property_inspections for select to authenticated
using (public.can_access_inspection(id));

drop policy if exists "property inspections insert scoped" on public.property_inspections;
create policy "property inspections insert scoped"
on public.property_inspections for insert to authenticated
with check (
  status in ('draft', 'completed')
  and (
    public.is_super_admin()
    or public.admin_staff_can_access_unit(unit_id)
    or landlord_id = auth.uid()
    or (
      public.current_profile_role() = 'staff'
      and public.staff_can_access_unit(unit_id)
      and (
        public.staff_permission_flag('can_manage_maintenance')
        or public.staff_permission_flag('can_create_maintenance')
        or public.staff_permission_flag('can_add_resolution_notes')
      )
    )
    or (
      public.current_profile_role() in ('management_leader', 'management_staff')
      and public.management_can_access_unit(unit_id)
      and (
        public.management_permission_flag('can_manage_maintenance')
        or public.management_permission_flag('can_create_maintenance')
        or public.management_permission_flag('can_add_resolution_notes')
      )
    )
  )
);

drop policy if exists "property inspections update scoped" on public.property_inspections;
create policy "property inspections update scoped"
on public.property_inspections for update to authenticated
using (
  status <> 'locked'
  and public.can_manage_inspection(id)
)
with check (
  public.can_manage_inspection(id)
);

drop policy if exists "property inspections delete scoped" on public.property_inspections;
create policy "property inspections delete scoped"
on public.property_inspections for delete to authenticated
using (
  status <> 'locked'
  and public.can_manage_inspection(id)
);

drop policy if exists "inspection files read scoped" on public.inspection_files;
create policy "inspection files read scoped"
on public.inspection_files for select to authenticated
using (public.can_access_inspection(inspection_id));

drop policy if exists "inspection files insert scoped" on public.inspection_files;
create policy "inspection files insert scoped"
on public.inspection_files for insert to authenticated
with check (public.can_manage_inspection(inspection_id));

drop policy if exists "inspection files update scoped" on public.inspection_files;
create policy "inspection files update scoped"
on public.inspection_files for update to authenticated
using (public.can_manage_inspection(inspection_id))
with check (public.can_manage_inspection(inspection_id));

drop policy if exists "inspection files delete scoped" on public.inspection_files;
create policy "inspection files delete scoped"
on public.inspection_files for delete to authenticated
using (public.can_manage_inspection(inspection_id));

drop policy if exists "tenant applications read scoped" on public.tenant_applications;
create policy "tenant applications read scoped"
on public.tenant_applications for select to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = tenant_applications.tenant_id
      and t.profile_id = auth.uid()
  )
  or (property_id is not null and public.staff_can_access_property(property_id))
  or (property_id is not null and public.management_can_access_property(property_id))
);

drop policy if exists "tenant applications manage scoped" on public.tenant_applications;
create policy "tenant applications manage scoped"
on public.tenant_applications for all to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or (property_id is not null and public.staff_can_access_property(property_id) and public.staff_permission_flag('can_add_tenants'))
  or (property_id is not null and public.management_can_access_property(property_id) and public.management_permission_flag('can_add_tenants'))
)
with check (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or (property_id is not null and public.staff_can_access_property(property_id) and public.staff_permission_flag('can_add_tenants'))
  or (property_id is not null and public.management_can_access_property(property_id) and public.management_permission_flag('can_add_tenants'))
);

drop policy if exists "tenant documents read scoped" on public.tenant_documents;
create policy "tenant documents read scoped"
on public.tenant_documents for select to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = tenant_documents.tenant_id
      and t.profile_id = auth.uid()
  )
  or (lease_id is not null and public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_view_leases'))
  or (lease_id is not null and public.management_can_access_lease(lease_id) and public.management_permission_flag('can_view_leases'))
);

drop policy if exists "tenant documents manage scoped" on public.tenant_documents;
create policy "tenant documents manage scoped"
on public.tenant_documents for all to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = tenant_documents.tenant_id
      and t.profile_id = auth.uid()
  )
  or (lease_id is not null and public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_upload_lease_documents'))
  or (lease_id is not null and public.management_can_access_lease(lease_id) and public.management_permission_flag('can_upload_lease_documents'))
)
with check (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = tenant_documents.tenant_id
      and t.profile_id = auth.uid()
  )
  or (lease_id is not null and public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_upload_lease_documents'))
  or (lease_id is not null and public.management_can_access_lease(lease_id) and public.management_permission_flag('can_upload_lease_documents'))
);

drop policy if exists "lease lifecycle read scoped" on public.lease_lifecycle_items;
create policy "lease lifecycle read scoped"
on public.lease_lifecycle_items for select to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = lease_lifecycle_items.tenant_id
      and t.profile_id = auth.uid()
  )
  or public.staff_can_access_lease(lease_id)
  or public.management_can_access_lease(lease_id)
);

drop policy if exists "lease lifecycle manage scoped" on public.lease_lifecycle_items;
create policy "lease lifecycle manage scoped"
on public.lease_lifecycle_items for all to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or (public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_edit_leases'))
  or (public.management_can_access_lease(lease_id) and public.management_permission_flag('can_edit_leases'))
)
with check (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or (public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_edit_leases'))
  or (public.management_can_access_lease(lease_id) and public.management_permission_flag('can_edit_leases'))
);

drop policy if exists "deposit settlements read scoped" on public.deposit_settlements;
create policy "deposit settlements read scoped"
on public.deposit_settlements for select to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = deposit_settlements.tenant_id
      and t.profile_id = auth.uid()
  )
  or public.staff_can_access_lease(lease_id)
  or public.management_can_access_lease(lease_id)
);

drop policy if exists "deposit settlements manage scoped" on public.deposit_settlements;
create policy "deposit settlements manage scoped"
on public.deposit_settlements for all to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or (public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_edit_leases'))
  or (public.management_can_access_lease(lease_id) and public.management_permission_flag('can_edit_leases'))
)
with check (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or (public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_edit_leases'))
  or (public.management_can_access_lease(lease_id) and public.management_permission_flag('can_edit_leases'))
);

drop policy if exists "tenant reference requests read scoped" on public.tenant_reference_requests;
create policy "tenant reference requests read scoped"
on public.tenant_reference_requests for select to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = tenant_reference_requests.tenant_id
      and t.profile_id = auth.uid()
  )
  or public.staff_can_access_lease(lease_id)
  or public.management_can_access_lease(lease_id)
);

drop policy if exists "tenant reference requests manage scoped" on public.tenant_reference_requests;
create policy "tenant reference requests manage scoped"
on public.tenant_reference_requests for all to authenticated
using (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = tenant_reference_requests.tenant_id
      and t.profile_id = auth.uid()
  )
  or (public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_edit_leases'))
  or (public.management_can_access_lease(lease_id) and public.management_permission_flag('can_edit_leases'))
)
with check (
  landlord_id = auth.uid()
  or public.is_super_admin()
  or public.admin_staff_can_access_landlord(landlord_id)
  or exists (
    select 1 from public.tenants t
    where t.id = tenant_reference_requests.tenant_id
      and t.profile_id = auth.uid()
  )
  or (public.staff_can_access_lease(lease_id) and public.staff_permission_flag('can_edit_leases'))
  or (public.management_can_access_lease(lease_id) and public.management_permission_flag('can_edit_leases'))
);

drop policy if exists "notifications profile owner" on public.notifications;
create policy "notifications profile owner"
on public.notifications for all to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "telegram tokens profile owner" on public.telegram_link_tokens;
create policy "telegram tokens profile owner"
on public.telegram_link_tokens for all to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create or replace function public.accept_payment_submission(p_submission_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  submission_record public.payment_submissions%rowtype;
  new_payment_id uuid;
begin
  select * into submission_record
  from public.payment_submissions
  where id = p_submission_id
  for update;

  if not found then
    raise exception 'Payment submission not found.';
  end if;

  if submission_record.status <> 'pending' then
    raise exception 'Only pending payment submissions can be approved.';
  end if;

  if not (
    exists (select 1 from public.leases l where l.id = submission_record.lease_id and l.landlord_id = auth.uid())
    or (
      public.current_profile_role() = 'staff'
      and public.staff_permission_flag('can_verify_payments')
      and public.staff_can_access_lease(submission_record.lease_id)
    )
    or (
      public.current_profile_role() in ('management_leader', 'management_staff')
      and public.management_permission_flag('can_verify_payments')
      and public.management_can_access_lease(submission_record.lease_id)
    )
  ) then
    raise exception 'You are not allowed to approve this payment submission.';
  end if;

  insert into public.payments (
    lease_id,
    submission_id,
    amount_paid,
    payment_date,
    payment_method,
    rent_period_start,
    rent_period_end,
    rent_period_label,
    payment_purpose,
    purpose_description,
    is_historical,
    notes,
    recorded_by
  )
  values (
    submission_record.lease_id,
    submission_record.id,
    submission_record.amount_claimed,
    submission_record.payment_date,
    submission_record.payment_method,
    submission_record.rent_period_start,
    submission_record.rent_period_end,
    submission_record.rent_period_label,
    submission_record.payment_purpose,
    submission_record.purpose_description,
    submission_record.is_historical,
    submission_record.reference_note,
    auth.uid()
  )
  returning id into new_payment_id;

  update public.payment_submissions
  set status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      rejection_reason = null
  where id = submission_record.id;

  return new_payment_id;
end;
$$;

create or replace function public.link_current_tenant_account()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_record public.profiles%rowtype;
  linked_tenant_id uuid;
begin
  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found or profile_record.role <> 'tenant' then
    return null;
  end if;

  perform set_config('request.mushavo_tenant_self_write', 'true', true);

  with existing_tenant as (
    select t.id
    from public.tenants t
    where t.profile_id = profile_record.id
      and t.archived_at is null
    order by t.created_at desc
    limit 1
  )
  update public.tenants t
  set invite_accepted = true
  from existing_tenant
  where t.id = existing_tenant.id
  returning t.id into linked_tenant_id;

  if linked_tenant_id is not null then
    return linked_tenant_id;
  end if;

  return null;
end;
$$;

drop function if exists public.accept_tenant_invite(uuid);
drop function if exists public.accept_tenant_invite(uuid, text, text, text);

create or replace function public.accept_tenant_invite(
  p_invite_id uuid,
  p_full_name text default null,
  p_phone text default null,
  p_id_number text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  token_record public.invite_tokens%rowtype;
  profile_record public.profiles%rowtype;
  metadata_tenant_id uuid;
  linked_tenant_id uuid;
  normalized_name text := nullif(trim(coalesce(p_full_name, '')), '');
  normalized_phone text := nullif(trim(coalesce(p_phone, '')), '');
  normalized_id_number text := nullif(trim(coalesce(p_id_number, '')), '');
begin
  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found or profile_record.role <> 'tenant' then
    raise exception 'Tenant profile not found for this account.';
  end if;

  select *
  into token_record
  from public.invite_tokens
  where id = p_invite_id
  for update;

  if not found then
    raise exception 'Invite token not found.';
  end if;

  if token_record.role <> 'tenant'
    or token_record.used = true
    or token_record.expires_at <= now()
    or lower(token_record.email) <> lower(profile_record.email) then
    raise exception 'This tenant invite is invalid, expired, or already used.';
  end if;

  if token_record.metadata ? 'tenant_id' then
    metadata_tenant_id := nullif(token_record.metadata ->> 'tenant_id', '')::uuid;
  end if;

  perform set_config('request.mushavo_tenant_self_write', 'true', true);

  with tenant_to_link as (
    select t.id
    from public.tenants t
    where t.landlord_id = token_record.landlord_id
      and lower(t.email) = lower(token_record.email)
      and (t.profile_id is null or t.profile_id = profile_record.id)
      and (metadata_tenant_id is null or t.id = metadata_tenant_id)
      and t.archived_at is null
    order by case when t.id = metadata_tenant_id then 0 else 1 end, t.created_at desc
    limit 1
  )
  update public.tenants t
  set full_name = coalesce(normalized_name, t.full_name),
      phone = coalesce(normalized_phone, t.phone),
      id_number = coalesce(normalized_id_number, t.id_number),
      profile_id = profile_record.id,
      invite_accepted = true,
      invite_token = token_record.token
  from tenant_to_link
  where t.id = tenant_to_link.id
  returning t.id into linked_tenant_id;

  if linked_tenant_id is null then
    insert into public.tenants (
      landlord_id,
      profile_id,
      full_name,
      phone,
      email,
      id_number,
      invite_token,
      invite_accepted
    )
    values (
      token_record.landlord_id,
      profile_record.id,
      coalesce(normalized_name, nullif(trim(profile_record.full_name), ''), token_record.metadata ->> 'full_name', token_record.email),
      coalesce(normalized_phone, nullif(trim(profile_record.phone), ''), nullif(trim(coalesce(token_record.metadata ->> 'phone', '')), '')),
      token_record.email,
      coalesce(normalized_id_number, nullif(trim(coalesce(token_record.metadata ->> 'id_number', '')), '')),
      token_record.token,
      true
    )
    returning id into linked_tenant_id;
  end if;

  update public.profiles
  set full_name = coalesce(normalized_name, full_name),
      phone = coalesce(normalized_phone, phone),
      landlord_id = null,
      archived_at = null,
      archived_by = null
  where id = profile_record.id;

  update public.invite_tokens
  set used = true
  where id = token_record.id;

  return linked_tenant_id;
end;
$$;

create or replace function public.accept_tenant_invite(p_invite_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.accept_tenant_invite(p_invite_id, null, null, null);
end;
$$;

drop function if exists public.create_tenant_invite(uuid, text, text, text, text);

create or replace function public.create_tenant_invite(
  p_landlord_id uuid,
  p_full_name text,
  p_phone text,
  p_email text,
  p_id_number text
)
returns table (
  tenant_id uuid,
  invite_token text,
  tenant_email text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  normalized_name text := trim(coalesce(p_full_name, ''));
  new_token text := public.generate_invite_token(24);
  caller_role public.user_role;
  existing_tenant_profile_id uuid;
  existing_tenant_name text;
  landlord_name text;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to invite tenants.';
  end if;

  if p_landlord_id is null then
    raise exception 'Landlord is required before inviting a tenant.';
  end if;

  caller_role := public.current_profile_role();

  if not (
    (caller_role = 'landlord' and p_landlord_id = auth.uid())
    or (
      caller_role = 'staff'
      and p_landlord_id = public.current_landlord_id()
      and (
        public.staff_permission_flag('can_add_tenants')
        or public.staff_permission_flag('can_create_leases')
        or public.staff_permission_flag('can_manage_leases')
      )
    )
    or (
      caller_role in ('management_leader', 'management_staff')
      and (
        public.management_permission_flag('can_add_tenants')
        or public.management_permission_flag('can_create_leases')
        or public.management_permission_flag('can_manage_leases')
      )
      and exists (
        select 1
        from public.management_landlord_permissions mlp
        where mlp.management_company_id = public.current_management_company_id()
          and mlp.landlord_id = p_landlord_id
          and mlp.status = 'approved'
          and (
            caller_role <> 'management_staff'
            or p_landlord_id = (select p.landlord_id from public.profiles p where p.id = auth.uid())
          )
      )
    )
  ) then
    raise exception 'You do not have permission to invite tenants for this landlord.';
  end if;

  if normalized_name = '' or normalized_email = '' then
    raise exception 'Tenant name and email are required.';
  end if;

  select p.id, nullif(trim(p.full_name), '')
  into existing_tenant_profile_id, existing_tenant_name
  from public.profiles p
  where p.role = 'tenant'
    and p.archived_at is null
    and lower(p.email) = normalized_email
  limit 1;

  normalized_name := coalesce(existing_tenant_name, normalized_name);

  if exists (
    select 1
    from public.tenants t
    where t.landlord_id = p_landlord_id
      and lower(t.email) = normalized_email
      and t.archived_at is null
  ) then
    raise exception 'This tenant already has an active record with this landlord.';
  end if;

  insert into public.tenants (
    landlord_id,
    profile_id,
    full_name,
    phone,
    email,
    id_number,
    invite_token,
    invite_accepted
  )
  values (
    p_landlord_id,
    null,
    normalized_name,
    nullif(trim(coalesce(p_phone, '')), ''),
    normalized_email,
    nullif(trim(coalesce(p_id_number, '')), ''),
    case when existing_tenant_profile_id is null then new_token else null end,
    false
  )
  returning id into tenant_id;

  if existing_tenant_profile_id is null then
    insert into public.invite_tokens (
      token,
      email,
      role,
      landlord_id,
      metadata,
      expires_at
    )
    values (
      new_token,
      normalized_email,
      'tenant',
      p_landlord_id,
      jsonb_build_object(
        'tenant_id', tenant_id,
        'full_name', normalized_name,
        'phone', coalesce(p_phone, ''),
        'id_number', coalesce(p_id_number, '')
      ),
      now() + interval '48 hours'
    );
  end if;

  if existing_tenant_profile_id is not null then
    select coalesce(nullif(trim(full_name), ''), email)
    into landlord_name
    from public.profiles
    where id = p_landlord_id;

    insert into public.notifications (profile_id, landlord_id, type, message, related_id, response_status)
    values (
      existing_tenant_profile_id,
      p_landlord_id,
      'tenant_link_request',
      coalesce(landlord_name, 'A landlord') || ' requested to link your tenant account to their property. Accept or reject this request from Notifications.',
      tenant_id,
      'pending'
    );
  end if;

  invite_token := case when existing_tenant_profile_id is null then new_token else null end;
  tenant_email := normalized_email;
  return next;
end;
$$;

do $$
begin
  perform set_config('request.mushavo_tenant_self_write', 'true', true);

  update public.tenants
  set profile_id = null
  where invite_accepted = false
    and profile_id is not null
    and archived_at is null;

  update public.tenants t
  set profile_id = null,
      invite_accepted = false
  where t.invite_accepted = true
    and t.profile_id is not null
    and t.invite_token is not null
    and t.archived_at is null
    and exists (
      select 1
      from public.notifications n
      where n.related_id = t.id
        and n.type = 'tenant_link_request'
    );
end;
$$;

drop function if exists public.respond_tenant_link_request(uuid, boolean);

create or replace function public.respond_tenant_link_request(
  p_tenant_id uuid,
  p_accept boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  tenant_record public.tenants%rowtype;
  tenant_email text;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to respond to this request.';
  end if;

  select lower(email)
  into tenant_email
  from public.profiles
  where id = auth.uid()
    and role = 'tenant'
    and archived_at is null;

  if tenant_email is null then
    raise exception 'Only tenant accounts can respond to tenant link requests.';
  end if;

  select *
  into tenant_record
  from public.tenants
  where id = p_tenant_id
    and landlord_id is not null
    and archived_at is null
    and invite_accepted = false
    and lower(email) = tenant_email
  for update;

  if not found then
    raise exception 'This tenant request is no longer available.';
  end if;

  perform set_config('request.mushavo_tenant_self_write', 'true', true);

  if coalesce(p_accept, false) then
    update public.tenants
    set profile_id = auth.uid(),
        invite_accepted = true,
        invite_token = null
    where id = tenant_record.id;
  else
    update public.tenants
    set archived_at = now(),
        archived_by = auth.uid()
    where id = tenant_record.id;
  end if;

  update public.invite_tokens
  set used = true
  where role = 'tenant'
    and used = false
    and (
      token = tenant_record.invite_token
      or (metadata ->> 'tenant_id')::uuid = tenant_record.id
    );

  update public.notifications
  set is_read = true,
      response_status = case when coalesce(p_accept, false) then 'accepted' else 'rejected' end
  where profile_id = auth.uid()
    and type = 'tenant_link_request'
    and related_id = tenant_record.id;

  return tenant_record.id;
end;
$$;

drop function if exists public.create_tenant_reference_request(uuid, text, text, text);

create or replace function public.create_tenant_reference_request(
  p_lease_id uuid,
  p_requester_name text,
  p_requester_email text,
  p_purpose text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  lease_record record;
  request_id uuid;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to create a reference request.';
  end if;

  if nullif(trim(coalesce(p_requester_name, '')), '') is null
    or nullif(trim(coalesce(p_requester_email, '')), '') is null
    or nullif(trim(coalesce(p_purpose, '')), '') is null then
    raise exception 'Requester name, email, and purpose are required.';
  end if;

  select
    l.id,
    l.landlord_id,
    l.tenant_id,
    t.profile_id as tenant_profile_id
  into lease_record
  from public.leases l
  join public.tenants t on t.id = l.tenant_id
  where l.id = p_lease_id
    and l.archived_at is null
    and t.archived_at is null;

  if not found then
    raise exception 'Lease not found.';
  end if;

  if not (
    lease_record.landlord_id = auth.uid()
    or public.is_super_admin()
    or public.admin_staff_can_access_landlord(lease_record.landlord_id)
    or (public.staff_can_access_lease(lease_record.id) and public.staff_permission_flag('can_edit_leases'))
    or (public.management_can_access_lease(lease_record.id) and public.management_permission_flag('can_edit_leases'))
  ) then
    raise exception 'Missing permission: edit leases.';
  end if;

  insert into public.tenant_reference_requests (
    lease_id,
    landlord_id,
    tenant_id,
    requester_name,
    requester_email,
    purpose,
    consent_status
  )
  values (
    lease_record.id,
    lease_record.landlord_id,
    lease_record.tenant_id,
    trim(p_requester_name),
    lower(trim(p_requester_email)),
    trim(p_purpose),
    'pending'
  )
  returning id into request_id;

  if lease_record.tenant_profile_id is not null then
    insert into public.notifications (
      profile_id,
      landlord_id,
      type,
      title,
      message,
      related_id,
      response_status
    )
    values (
      lease_record.tenant_profile_id,
      lease_record.landlord_id,
      'tenant_reference_request',
      'Tenant reference request',
      'A rental reference request needs your consent before any details are shared.',
      request_id,
      'pending'
    );
  end if;

  return request_id;
end;
$$;

drop function if exists public.respond_tenant_reference_request(uuid, boolean);

create or replace function public.respond_tenant_reference_request(
  p_request_id uuid,
  p_accept boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  request_record record;
  next_status text;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to respond to this request.';
  end if;

  select r.id, r.consent_status
  into request_record
  from public.tenant_reference_requests r
  join public.tenants t on t.id = r.tenant_id
  where r.id = p_request_id
    and t.profile_id = auth.uid()
    and t.archived_at is null
  for update;

  if not found then
    raise exception 'This reference request is no longer available.';
  end if;

  if request_record.consent_status is distinct from 'pending' then
    raise exception 'This reference request has already been responded to.';
  end if;

  next_status := case when coalesce(p_accept, false) then 'approved' else 'rejected' end;

  update public.tenant_reference_requests
  set consent_status = next_status,
      responded_at = now()
  where id = request_record.id;

  update public.notifications
  set is_read = true,
      response_status = next_status
  where profile_id = auth.uid()
    and type = 'tenant_reference_request'
    and related_id = request_record.id;

  return request_record.id;
end;
$$;

update public.notifications n
set response_status = case
  when t.invite_accepted = true and t.profile_id is not null and t.archived_at is null then 'accepted'
  when t.archived_at is not null then 'rejected'
  else 'pending'
end
from public.tenants t
where n.type = 'tenant_link_request'
  and n.related_id = t.id
  and n.response_status is distinct from case
    when t.invite_accepted = true and t.profile_id is not null and t.archived_at is null then 'accepted'
    when t.archived_at is not null then 'rejected'
    else 'pending'
  end;

create or replace function public.attach_payment_proof(
  p_submission_id uuid,
  p_path text,
  p_name text,
  p_size integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_size is null or p_size <= 0 then
    raise exception 'Invalid payment proof file size.';
  end if;

  if public.media_object_row_id(p_path) is distinct from p_submission_id then
    raise exception 'Payment proof file path does not match the payment submission.';
  end if;

  if not public.can_manage_payment_proof(p_path) then
    raise exception 'You are not allowed to attach this payment proof file.';
  end if;

  update public.payment_submissions
  set proof_image_url = p_path,
      proof_image_path = p_path,
      proof_image_name = p_name,
      proof_image_size = p_size,
      proof_image_uploaded_by = auth.uid(),
      proof_image_uploaded_at = now()
  where id = p_submission_id;
end;
$$;

create or replace function public.attach_payment_record_proof(
  p_payment_id uuid,
  p_path text,
  p_name text,
  p_size integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_size is null or p_size <= 0 then
    raise exception 'Invalid payment proof file size.';
  end if;

  if public.media_object_row_id(p_path) is distinct from p_payment_id then
    raise exception 'Payment proof file path does not match the payment.';
  end if;

  if not public.can_manage_payment_proof(p_path) then
    raise exception 'You are not allowed to attach this payment proof file.';
  end if;

  update public.payments
  set proof_file_path = p_path,
      proof_file_name = p_name,
      proof_file_size = p_size,
      proof_file_uploaded_by = auth.uid(),
      proof_file_uploaded_at = now()
  where id = p_payment_id;
end;
$$;

create or replace function public.attach_maintenance_photo(
  p_request_id uuid,
  p_path text,
  p_name text,
  p_size integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_size is null or p_size <= 0 then
    raise exception 'Invalid maintenance photo size.';
  end if;

  if public.media_object_row_id(p_path) is distinct from p_request_id then
    raise exception 'Maintenance photo path does not match the request.';
  end if;

  if not public.can_manage_maintenance_photo(p_path) then
    raise exception 'You are not allowed to attach this maintenance photo.';
  end if;

  update public.maintenance_requests
  set photo_url = p_path,
      photo_path = p_path,
      photo_name = p_name,
      photo_size = p_size,
      photo_uploaded_by = auth.uid(),
      photo_uploaded_at = now()
  where id = p_request_id;
end;
$$;

create or replace function public.delete_landlord_account(
  p_profile_id uuid,
  p_invite_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_country_id uuid;
begin
  if p_profile_id is not null then
    select p.country_id
    into target_country_id
    from public.profiles p
    where p.id = p_profile_id
      and p.role = 'landlord';
  elsif p_invite_id is not null then
    select it.country_id
    into target_country_id
    from public.invite_tokens it
    where it.id = p_invite_id
      and it.role = 'landlord';
  end if;

  if not (public.is_super_admin() or public.is_admin_staff_for_country(target_country_id)) then
    raise exception 'You are not allowed to manage landlord accounts outside your assigned country.';
  end if;

  if p_profile_id is not null then
    if not exists (
      select 1 from public.profiles p
      where p.id = p_profile_id and p.role = 'landlord'
    ) then
      raise exception 'Landlord profile not found.';
    end if;

    update public.units u
    set status = 'vacant',
        archived_at = coalesce(u.archived_at, now()),
        archived_by = auth.uid()
    where exists (
      select 1
      from public.properties p
      where p.id = u.property_id
        and p.landlord_id = p_profile_id
    );

    update public.properties p
    set archived_at = coalesce(p.archived_at, now()),
        archived_by = auth.uid()
    where p.landlord_id = p_profile_id
      and p.archived_at is null;

    update public.leases l
    set status = 'terminated'
    where l.landlord_id = p_profile_id
      and l.status = 'active';

    update public.tenants t
    set archived_at = coalesce(t.archived_at, now()),
        archived_by = auth.uid(),
        invite_accepted = false
    where t.landlord_id = p_profile_id
      and t.archived_at is null;

    update public.profiles p
    set archived_at = coalesce(p.archived_at, now()),
        archived_by = auth.uid()
    where (
        (p.id = p_profile_id and p.role = 'landlord')
        or (p.landlord_id = p_profile_id and p.role = 'staff')
      )
      and p.archived_at is null;

    update public.landlord_subscriptions ls
    set status = 'suspended',
        updated_by = auth.uid(),
        updated_at = now(),
        notes = trim(both from concat_ws(E'\n', nullif(ls.notes, ''), 'Archived by admin on ' || now()::date::text))
    where ls.landlord_id = p_profile_id;

    update public.invite_tokens it
    set used = true,
        expires_at = least(it.expires_at, now())
    where it.landlord_id = p_profile_id
      and it.used = false;
  end if;

  if p_invite_id is not null then
    delete from public.landlord_subscriptions ls
    where ls.invite_token_id = p_invite_id;

    delete from public.invite_tokens it
    where it.id = p_invite_id and it.role = 'landlord';
  end if;
end;
$$;

create or replace function public.delete_tenant_account(
  p_tenant_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  tenant_record public.tenants%rowtype;
  caller_role public.user_role;
begin
  select *
  into tenant_record
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'Tenant not found.';
  end if;

  caller_role := public.current_profile_role();

  if not (
    (caller_role = 'landlord' and tenant_record.landlord_id = auth.uid())
    or (
      caller_role = 'staff'
      and tenant_record.landlord_id = public.current_landlord_id()
      and public.staff_permission_flag('can_archive_tenants')
    )
    or (
      caller_role in ('management_leader', 'management_staff')
      and public.management_permission_flag('can_archive_tenants')
      and exists (
        select 1
        from public.management_landlord_permissions mlp
        where mlp.management_company_id = public.current_management_company_id()
          and mlp.landlord_id = tenant_record.landlord_id
          and mlp.status = 'approved'
          and (
            caller_role <> 'management_staff'
            or tenant_record.landlord_id = (select p.landlord_id from public.profiles p where p.id = auth.uid())
          )
      )
    )
  ) then
    raise exception 'You do not have permission to archive this tenant.';
  end if;

  update public.units u
  set status = 'vacant'
  where u.id in (
    select l.unit_id
    from public.leases l
    where l.tenant_id = p_tenant_id
      and l.status = 'active'
  );

  update public.leases l
  set status = 'terminated'
  where l.tenant_id = p_tenant_id
    and l.status = 'active';

  update public.tenants t
  set archived_at = coalesce(t.archived_at, now()),
      archived_by = auth.uid(),
      profile_id = null,
      invite_accepted = false
  where t.id = p_tenant_id;

  update public.invite_tokens it
  set used = true,
      expires_at = least(it.expires_at, now())
  where it.role = 'tenant'
    and it.landlord_id = tenant_record.landlord_id
    and (
      it.metadata ->> 'tenant_id' = p_tenant_id::text
      or it.token = tenant_record.invite_token
    )
    and it.used = false;
end;
$$;

create or replace function public.delete_staff_account(
  p_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  staff_record public.profiles%rowtype;
begin
  select p.*
  into staff_record
  from public.profiles p
  join public.staff_permissions sp on sp.staff_profile_id = p.id
  where p.id = p_profile_id
    and p.role = 'staff'
    and sp.landlord_id = auth.uid()
  limit 1;

  if staff_record.id is null then
    raise exception 'Staff account not found for this landlord.';
  end if;

  delete from public.staff_permissions sp
  where sp.staff_profile_id = p_profile_id
    and sp.landlord_id = auth.uid();

  update public.staff_landlord_requests slr
  set status = 'cancelled',
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where slr.staff_profile_id = p_profile_id
    and slr.landlord_id = auth.uid()
    and slr.status = 'pending';

  delete from public.invite_tokens it
  where it.landlord_id = auth.uid()
    and it.role = 'staff'
    and lower(it.email) = lower(staff_record.email);

  if coalesce(staff_record.staff_type, 'landlord') <> 'freelancer' then
    delete from auth.users u
    where u.id = p_profile_id;
    return;
  end if;

  update public.profiles p
  set landlord_id = null
  where p.id = p_profile_id
    and p.role = 'staff'
    and p.landlord_id = auth.uid()
    and not exists (
      select 1
      from public.staff_permissions sp
      where sp.staff_profile_id = p_profile_id
        and sp.status = 'approved'
    );
end;
$$;

create or replace function public.unarchive_landlord_account(
  p_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not (public.is_super_admin() or public.admin_staff_can_access_landlord(p_profile_id)) then
    raise exception 'You are not allowed to restore landlord accounts outside your assigned country.';
  end if;

  update public.profiles p
  set archived_at = null,
      archived_by = null
  where p.id = p_profile_id
    and p.role = 'landlord';

  if not found then
    raise exception 'Landlord profile not found.';
  end if;
end;
$$;

create or replace function public.unarchive_staff_account(
  p_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not (
    public.is_super_admin()
    or exists (
      select 1
      from public.profiles p
      where p.id = p_profile_id
        and p.role = 'staff'
        and (
          public.is_admin_staff_for_country(p.country_id)
          or public.admin_staff_can_access_landlord(p.landlord_id)
        )
    )
  ) then
    raise exception 'You are not allowed to restore IPM accounts outside your assigned country.';
  end if;

  update public.profiles p
  set archived_at = null,
      archived_by = null
  where p.id = p_profile_id
    and p.role = 'staff';

  if not found then
    raise exception 'Staff profile not found.';
  end if;
end;
$$;

create or replace function public.unarchive_management_company(
  p_management_company_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  company_record public.management_companies%rowtype;
begin
  select *
  into company_record
  from public.management_companies
  where id = p_management_company_id;

  if not found then
    raise exception 'Management company not found.';
  end if;

  if not (public.is_super_admin() or public.is_admin_staff_for_country(company_record.country_id)) then
    raise exception 'You are not allowed to restore PMC accounts outside your assigned country.';
  end if;

  update public.management_companies mc
  set archived_at = null,
      archived_by = null
  where mc.id = p_management_company_id;

  update public.profiles p
  set archived_at = null,
      archived_by = null
  where p.id = company_record.leader_profile_id
    and p.role = 'management_leader';
end;
$$;

create or replace function public.permanently_delete_landlord_account(
  p_profile_id uuid,
  p_invite_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_country_id uuid;
begin
  if p_profile_id is not null then
    select p.country_id
    into target_country_id
    from public.profiles p
    where p.id = p_profile_id
      and p.role = 'landlord';
  elsif p_invite_id is not null then
    select it.country_id
    into target_country_id
    from public.invite_tokens it
    where it.id = p_invite_id
      and it.role = 'landlord';
  end if;

  if not (public.is_super_admin() or public.is_admin_staff_for_country(target_country_id)) then
    raise exception 'You are not allowed to permanently delete landlord accounts outside your assigned country.';
  end if;

  if p_profile_id is not null then
    if not exists (
      select 1 from public.profiles p
      where p.id = p_profile_id and p.role = 'landlord'
    ) then
      raise exception 'Landlord profile not found.';
    end if;

    delete from auth.users u
    where exists (
      select 1
      from public.tenants t
      where t.landlord_id = p_profile_id
        and t.profile_id = u.id
    );

    update public.profiles p
    set landlord_id = null
    where p.role = 'staff'
      and p.landlord_id = p_profile_id
      and exists (
        select 1
        from public.staff_permissions sp
        where sp.staff_profile_id = p.id
          and sp.landlord_id <> p_profile_id
      );

    delete from auth.users u
    where exists (
      select 1
      from public.profiles p
      where p.id = u.id
        and p.role = 'staff'
        and p.landlord_id = p_profile_id
    );

    delete from auth.users u
    where u.id = p_profile_id;
  end if;

  if p_invite_id is not null then
    delete from public.landlord_subscriptions ls
    where ls.invite_token_id = p_invite_id;

    delete from public.invite_tokens it
    where it.id = p_invite_id
      and it.role = 'landlord';
  end if;
end;
$$;

create or replace function public.permanently_delete_tenant_account(
  p_tenant_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  tenant_record public.tenants%rowtype;
begin
  select *
  into tenant_record
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'Tenant not found.';
  end if;

  if not (public.is_super_admin() or public.admin_staff_can_access_landlord(tenant_record.landlord_id)) then
    raise exception 'You are not allowed to permanently delete tenant accounts outside your assigned country.';
  end if;

  delete from public.tenants t
  where t.id = p_tenant_id;

  delete from public.invite_tokens it
  where it.role = 'tenant'
    and it.landlord_id = tenant_record.landlord_id
    and (
      it.metadata ->> 'tenant_id' = p_tenant_id::text
      or it.token = tenant_record.invite_token
    );

  if tenant_record.profile_id is not null
    and not exists (
      select 1
      from public.tenants other_tenant
      where other_tenant.profile_id = tenant_record.profile_id
        and other_tenant.id <> p_tenant_id
    ) then
    delete from auth.users u
    where u.id = tenant_record.profile_id;
  end if;
end;
$$;

create or replace function public.permanently_delete_staff_account(
  p_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not (
    public.is_super_admin()
    or exists (
      select 1
      from public.profiles p
      where p.id = p_profile_id
        and p.role = 'staff'
        and (
          public.is_admin_staff_for_country(p.country_id)
          or public.admin_staff_can_access_landlord(p.landlord_id)
        )
    )
  ) then
    raise exception 'You are not allowed to permanently delete IPM accounts outside your assigned country.';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_profile_id and p.role = 'staff'
  ) then
    raise exception 'Staff profile not found.';
  end if;

  delete from auth.users u
  where u.id = p_profile_id;
end;
$$;

create or replace function public.permanently_delete_management_company(
  p_management_company_id uuid,
  p_invite_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  company_record public.management_companies%rowtype;
  target_country_id uuid;
begin
  if p_management_company_id is not null then
    select *
    into company_record
    from public.management_companies
    where id = p_management_company_id;

    if not found then
      raise exception 'Management company not found.';
    end if;

    target_country_id := company_record.country_id;

    if not (public.is_super_admin() or public.is_admin_staff_for_country(target_country_id)) then
      raise exception 'You are not allowed to permanently delete PMC accounts outside your assigned country.';
    end if;

    delete from auth.users u
    where exists (
      select 1
      from public.management_staff_permissions msp
      join public.profiles p on p.id = msp.staff_profile_id
      where msp.management_company_id = p_management_company_id
        and p.id = u.id
        and p.role = 'management_staff'
    );

    delete from auth.users u
    where u.id = company_record.leader_profile_id;
  end if;

  if p_invite_id is not null then
    if p_management_company_id is null then
      select it.country_id
      into target_country_id
      from public.invite_tokens it
      where it.id = p_invite_id
        and it.role = 'management_leader';

      if not (public.is_super_admin() or public.is_admin_staff_for_country(target_country_id)) then
        raise exception 'You are not allowed to permanently delete PMC accounts outside your assigned country.';
      end if;
    end if;

    delete from public.invite_tokens it
    where it.id = p_invite_id
      and it.role = 'management_leader';
  end if;
end;
$$;

create or replace function public.permanently_delete_management_staff_account(
  p_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not exists (
    select 1
    from public.management_staff_permissions msp
    join public.management_companies mc on mc.id = msp.management_company_id
    join public.profiles p on p.id = msp.staff_profile_id
    where msp.staff_profile_id = p_profile_id
      and mc.leader_profile_id = auth.uid()
      and p.role = 'management_staff'
  ) then
    raise exception 'Management staff account not found for this company.';
  end if;

  delete from auth.users u
  where u.id = p_profile_id;
end;
$$;

create or replace function public.external_assignment_scopes_overlap(
  p_left_all_properties boolean,
  p_left_property_ids uuid[],
  p_right_all_properties boolean,
  p_right_property_ids uuid[]
)
returns boolean
language sql
immutable
as $$
  select
    coalesce(p_left_all_properties, false)
    or coalesce(p_right_all_properties, false)
    or coalesce(p_left_property_ids, '{}'::uuid[]) && coalesce(p_right_property_ids, '{}'::uuid[])
$$;

create or replace function public.prevent_external_assignment_overlap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  subject_staff_type text;
begin
  if TG_TABLE_NAME = 'staff_permissions' then
    if new.status <> 'approved' then
      return new;
    end if;

    select coalesce(p.staff_type, 'landlord')
    into subject_staff_type
    from public.profiles p
    where p.id = new.staff_profile_id;

    if subject_staff_type <> 'freelancer' then
      return new;
    end if;

    if exists (
      select 1
      from public.staff_permissions sp
      join public.profiles p on p.id = sp.staff_profile_id
      where sp.landlord_id = new.landlord_id
        and sp.id is distinct from new.id
        and sp.status = 'approved'
        and coalesce(p.staff_type, 'landlord') = 'freelancer'
        and public.external_assignment_scopes_overlap(new.all_properties, new.property_ids, sp.all_properties, sp.property_ids)
    ) then
      raise exception 'This property is already assigned to another freelancer staff member.';
    end if;

    if exists (
      select 1
      from public.management_landlord_permissions mlp
      where mlp.landlord_id = new.landlord_id
        and mlp.status = 'approved'
        and public.external_assignment_scopes_overlap(new.all_properties, new.property_ids, mlp.all_properties, mlp.property_ids)
    ) then
      raise exception 'This property is already assigned to a management company.';
    end if;

    return new;
  end if;

  if TG_TABLE_NAME = 'management_landlord_permissions' then
    if new.status <> 'approved' then
      return new;
    end if;

    if exists (
      select 1
      from public.staff_permissions sp
      join public.profiles p on p.id = sp.staff_profile_id
      where sp.landlord_id = new.landlord_id
        and sp.status = 'approved'
        and coalesce(p.staff_type, 'landlord') = 'freelancer'
        and public.external_assignment_scopes_overlap(new.all_properties, new.property_ids, sp.all_properties, sp.property_ids)
    ) then
      raise exception 'This property is already assigned to a freelancer staff member.';
    end if;

    if exists (
      select 1
      from public.management_landlord_permissions mlp
      where mlp.landlord_id = new.landlord_id
        and mlp.id is distinct from new.id
        and mlp.status = 'approved'
        and public.external_assignment_scopes_overlap(new.all_properties, new.property_ids, mlp.all_properties, mlp.property_ids)
    ) then
      raise exception 'This property is already assigned to another management company.';
    end if;

    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists staff_permissions_external_assignment_overlap on public.staff_permissions;
create trigger staff_permissions_external_assignment_overlap
before insert or update of landlord_id, staff_profile_id, all_properties, property_ids, status
on public.staff_permissions
for each row
execute function public.prevent_external_assignment_overlap();

create or replace function public.staff_property_assignment_count(
  p_landlord_id uuid,
  p_all_properties boolean,
  p_property_ids uuid[]
)
returns integer
language sql
stable
as $$
  select case
    when coalesce(p_all_properties, false) then (
      select count(*)::integer
      from public.properties p
      where p.landlord_id = p_landlord_id
        and p.archived_at is null
    )
    else coalesce(array_length(coalesce(p_property_ids, '{}'::uuid[]), 1), 0)
  end
$$;

create or replace function public.enforce_ipm_property_assignment_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  subject_staff_type text;
  max_properties integer;
  assigned_properties integer;
begin
  if new.status <> 'approved' then
    return new;
  end if;

  select coalesce(p.staff_type, 'landlord'), coalesce(p.staff_max_properties_per_landlord, 0)
  into subject_staff_type, max_properties
  from public.profiles p
  where p.id = new.staff_profile_id;

  if subject_staff_type <> 'freelancer' then
    return new;
  end if;

  assigned_properties := public.staff_property_assignment_count(new.landlord_id, new.all_properties, new.property_ids);

  if assigned_properties > max_properties then
    raise exception 'This IPM can only be assigned % properties per landlord. You selected %.', max_properties, assigned_properties;
  end if;

  return new;
end;
$$;

drop trigger if exists staff_permissions_ipm_property_assignment_limit on public.staff_permissions;
create trigger staff_permissions_ipm_property_assignment_limit
before insert or update of landlord_id, staff_profile_id, all_properties, property_ids, status
on public.staff_permissions
for each row
execute function public.enforce_ipm_property_assignment_limit();

drop trigger if exists management_permissions_external_assignment_overlap on public.management_landlord_permissions;
create trigger management_permissions_external_assignment_overlap
before insert or update of landlord_id, all_properties, property_ids, status
on public.management_landlord_permissions
for each row
execute function public.prevent_external_assignment_overlap();

create or replace function public.prevent_management_staff_permission_overreach()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  staff_landlord_id uuid;
begin
  select p.landlord_id
  into staff_landlord_id
  from public.profiles p
  where p.id = new.staff_profile_id
    and p.role = 'management_staff'
    and p.archived_at is null;

  if staff_landlord_id is null then
    if new.all_properties = false and coalesce(array_length(new.property_ids, 1), 0) = 0 then
      return new;
    end if;

    raise exception 'Management staff must be linked to one landlord before property access is assigned.';
  end if;

  if new.all_properties then
    if not exists (
      select 1
      from public.management_landlord_permissions mlp
      where mlp.management_company_id = new.management_company_id
        and mlp.landlord_id = staff_landlord_id
        and mlp.status = 'approved'
        and mlp.all_properties = true
    ) then
      raise exception 'This staff member cannot be assigned to all properties because the landlord did not grant all-property access.';
    end if;

    return new;
  end if;

  if exists (
    select 1
    from unnest(coalesce(new.property_ids, '{}'::uuid[])) as selected_property(selected_property_id)
    where not exists (
      select 1
      from public.management_landlord_permissions mlp
      left join public.properties pr on pr.id = selected_property_id
      where mlp.management_company_id = new.management_company_id
        and mlp.landlord_id = staff_landlord_id
        and mlp.status = 'approved'
        and (
          (mlp.all_properties = true and pr.landlord_id = staff_landlord_id and pr.archived_at is null)
          or selected_property_id = any(mlp.property_ids)
        )
    )
  ) then
    raise exception 'This staff member can only be assigned to properties the landlord granted to this management company.';
  end if;

  return new;
end;
$$;

drop trigger if exists management_staff_permission_scope_check on public.management_staff_permissions;
create trigger management_staff_permission_scope_check
before insert or update of management_company_id, staff_profile_id, all_properties, property_ids
on public.management_staff_permissions
for each row
execute function public.prevent_management_staff_permission_overreach();

drop function if exists public.current_tenant_landlord();

create or replace function public.current_tenant_landlord()
returns table (
  id uuid,
  full_name text,
  phone text,
  email text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.full_name, p.phone, p.email
  from public.tenants t
  join public.leases l on l.tenant_id = t.id
  join public.profiles p on p.id = l.landlord_id
  where t.profile_id = auth.uid()
    and t.archived_at is null
    and l.status = 'active'
    and p.archived_at is null
  order by l.created_at desc
  limit 1
$$;

drop function if exists public.tenant_landlord_relationships();

create or replace function public.tenant_landlord_relationships()
returns table (
  tenant_id uuid,
  landlord_id uuid,
  landlord_name text,
  landlord_email text,
  landlord_phone text,
  property_name text,
  unit_number text,
  lease_status text,
  unit_status text,
  can_drop boolean,
  accepted_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to view accepted landlords.';
  end if;

  if public.current_profile_role() <> 'tenant' then
    raise exception 'Only tenant accounts can view accepted landlords.';
  end if;

  return query
  select
    t.id as tenant_id,
    t.landlord_id,
    coalesce(nullif(trim(landlord.full_name), ''), landlord.email) as landlord_name,
    landlord.email as landlord_email,
    landlord.phone as landlord_phone,
    prop.name as property_name,
    u.unit_number as unit_number,
    le.status::text as lease_status,
    u.status::text as unit_status,
    not exists (
      select 1
      from public.leases active_lease
      where active_lease.tenant_id = t.id
        and active_lease.status = 'active'
    ) as can_drop,
    t.created_at as accepted_at
  from public.tenants t
  join public.profiles landlord on landlord.id = t.landlord_id and landlord.archived_at is null
  left join lateral (
    select lease_row.*
    from public.leases lease_row
    where lease_row.tenant_id = t.id
    order by
      case when lease_row.status = 'active' then 0 else 1 end,
      lease_row.created_at desc
    limit 1
  ) le on true
  left join public.units u on u.id = le.unit_id
  left join public.properties prop on prop.id = u.property_id
  where t.profile_id = auth.uid()
    and t.invite_accepted = true
    and t.archived_at is null
  order by t.created_at desc;
end;
$$;

drop function if exists public.drop_tenant_landlord(uuid);

create or replace function public.drop_tenant_landlord(
  p_tenant_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  tenant_record public.tenants%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to drop a landlord.';
  end if;

  if public.current_profile_role() <> 'tenant' then
    raise exception 'Only tenant accounts can drop landlords.';
  end if;

  select *
  into tenant_record
  from public.tenants
  where id = p_tenant_id
    and profile_id = auth.uid()
    and invite_accepted = true
    and archived_at is null
  for update;

  if not found then
    raise exception 'This landlord connection is no longer available.';
  end if;

  if exists (
    select 1
    from public.leases lease_row
    where lease_row.tenant_id = tenant_record.id
      and lease_row.status = 'active'
  ) then
    raise exception 'You can drop this landlord after the unit is marked vacant.';
  end if;

  perform set_config('request.mushavo_tenant_self_write', 'true', true);

  update public.tenants
  set archived_at = now(),
      archived_by = auth.uid()
  where id = tenant_record.id;

  return tenant_record.id;
end;
$$;

drop function if exists public.tenant_unit_contacts(uuid);

create or replace function public.tenant_unit_contacts(
  p_unit_id uuid
)
returns table (
  contact_type text,
  full_name text,
  phone text,
  email text
)
language sql
stable
security definer
set search_path = public
as $$
  with tenant_access as (
    select l.unit_id, l.landlord_id, u.property_id
    from public.leases l
    join public.tenants t on t.id = l.tenant_id
    join public.units u on u.id = l.unit_id
    where l.unit_id = p_unit_id
      and l.status = 'active'
      and t.profile_id = auth.uid()
      and t.archived_at is null
    limit 1
  ),
  landlord_staff as (
    select
      case when p.staff_type = 'freelancer' then 'Freelancer staff' else 'Landlord staff' end as contact_type,
      p.full_name,
      p.phone,
      p.email
    from tenant_access ta
    join public.staff_permissions sp on sp.landlord_id = ta.landlord_id and sp.status = 'approved'
    join public.profiles p on p.id = sp.staff_profile_id and p.role = 'staff' and p.archived_at is null
    where sp.all_properties or ta.property_id = any(sp.property_ids)
  ),
  management_leaders as (
    select
      'Management company'::text as contact_type,
      leader.full_name,
      coalesce(leader.phone, mc.phone) as phone,
      leader.email
    from tenant_access ta
    join public.management_landlord_permissions mlp on mlp.landlord_id = ta.landlord_id and mlp.status = 'approved'
    join public.management_companies mc on mc.id = mlp.management_company_id and mc.archived_at is null
    join public.profiles leader on leader.id = mc.leader_profile_id and leader.archived_at is null
    where mlp.all_properties or ta.property_id = any(mlp.property_ids)
  ),
  management_staff as (
    select
      'Management staff'::text as contact_type,
      staff.full_name,
      staff.phone,
      staff.email
    from tenant_access ta
    join public.management_landlord_permissions mlp on mlp.landlord_id = ta.landlord_id and mlp.status = 'approved'
    join public.management_staff_permissions msp on msp.management_company_id = mlp.management_company_id and msp.status = 'approved'
    join public.profiles staff on staff.id = msp.staff_profile_id and staff.landlord_id = ta.landlord_id and staff.archived_at is null
    where (mlp.all_properties or ta.property_id = any(mlp.property_ids))
      and (msp.all_properties or ta.property_id = any(msp.property_ids))
  )
  select distinct contact_type, full_name, phone, email
  from (
    select * from landlord_staff
    union all
    select * from management_leaders
    union all
    select * from management_staff
  ) contacts
  where full_name is not null or email is not null
  order by contact_type, full_name
$$;

create or replace function public.current_user_can_assign_maintenance_unit(
  p_unit_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.units u
    join public.properties pr on pr.id = u.property_id
    where u.id = p_unit_id
      and u.archived_at is null
      and pr.archived_at is null
      and (
        (
          public.current_profile_role() = 'landlord'
          and pr.landlord_id = auth.uid()
        )
        or (
          public.current_profile_role() = 'staff'
          and exists (
            select 1
            from public.staff_permissions sp
            where sp.staff_profile_id = auth.uid()
              and sp.landlord_id = pr.landlord_id
              and sp.status = 'approved'
              and sp.can_assign_maintenance
              and (sp.all_properties or pr.id = any(sp.property_ids))
          )
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and exists (
            select 1
            from public.management_landlord_permissions mlp
            where mlp.management_company_id = public.current_management_company_id()
              and mlp.landlord_id = pr.landlord_id
              and mlp.status = 'approved'
              and mlp.can_assign_maintenance
              and (mlp.all_properties or pr.id = any(mlp.property_ids))
              and (
                public.current_profile_role() = 'management_leader'
                or exists (
                  select 1
                  from public.management_staff_permissions msp
                  join public.profiles caller on caller.id = msp.staff_profile_id
                  where msp.management_company_id = mlp.management_company_id
                    and msp.staff_profile_id = auth.uid()
                    and msp.status = 'approved'
                    and msp.can_assign_maintenance
                    and caller.landlord_id = pr.landlord_id
                    and (msp.all_properties or pr.id = any(msp.property_ids))
                )
              )
          )
        )
      )
  )
$$;

create or replace function public.maintenance_assignee_allowed(
  p_staff_profile_id uuid,
  p_landlord_id uuid,
  p_unit_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_staff_profile_id is null or exists (
    select 1
    from public.units u
    join public.properties pr on pr.id = u.property_id
    where u.id = p_unit_id
      and pr.landlord_id = p_landlord_id
      and u.archived_at is null
      and pr.archived_at is null
      and (
        (
          public.current_profile_role() in ('landlord', 'staff')
          and exists (
            select 1
            from public.staff_permissions sp
            join public.profiles staff on staff.id = sp.staff_profile_id
            where sp.staff_profile_id = p_staff_profile_id
              and sp.landlord_id = p_landlord_id
              and sp.status = 'approved'
              and staff.role = 'staff'
              and staff.archived_at is null
              and (sp.all_properties or pr.id = any(sp.property_ids))
              and (
                sp.can_manage_maintenance
                or sp.can_create_maintenance
                or sp.can_assign_maintenance
                or sp.can_add_resolution_notes
              )
          )
        )
        or (
          public.current_profile_role() = 'landlord'
          and exists (
            select 1
            from public.management_landlord_permissions mlp
            join public.management_staff_permissions msp on msp.management_company_id = mlp.management_company_id
            join public.profiles staff on staff.id = msp.staff_profile_id
            where mlp.landlord_id = p_landlord_id
              and mlp.status = 'approved'
              and (mlp.all_properties or pr.id = any(mlp.property_ids))
              and (
                mlp.can_manage_maintenance
                or mlp.can_create_maintenance
                or mlp.can_assign_maintenance
                or mlp.can_add_resolution_notes
              )
              and msp.staff_profile_id = p_staff_profile_id
              and msp.status = 'approved'
              and (msp.all_properties or pr.id = any(msp.property_ids))
              and (
                msp.can_manage_maintenance
                or msp.can_create_maintenance
                or msp.can_assign_maintenance
                or msp.can_add_resolution_notes
              )
              and staff.role = 'management_staff'
              and staff.landlord_id = p_landlord_id
              and staff.archived_at is null
          )
        )
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and exists (
            select 1
            from public.management_landlord_permissions mlp
            join public.management_staff_permissions msp on msp.management_company_id = mlp.management_company_id
            join public.profiles staff on staff.id = msp.staff_profile_id
            where mlp.management_company_id = public.current_management_company_id()
              and mlp.landlord_id = p_landlord_id
              and mlp.status = 'approved'
              and (mlp.all_properties or pr.id = any(mlp.property_ids))
              and (
                mlp.can_manage_maintenance
                or mlp.can_create_maintenance
                or mlp.can_assign_maintenance
                or mlp.can_add_resolution_notes
              )
              and msp.staff_profile_id = p_staff_profile_id
              and msp.status = 'approved'
              and (msp.all_properties or pr.id = any(msp.property_ids))
              and (
                msp.can_manage_maintenance
                or msp.can_create_maintenance
                or msp.can_assign_maintenance
                or msp.can_add_resolution_notes
              )
              and staff.role = 'management_staff'
              and staff.landlord_id = p_landlord_id
              and staff.archived_at is null
          )
        )
      )
  )
$$;

create or replace function public.enforce_maintenance_assignment_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and (
    new.unit_id is distinct from old.unit_id
    or new.landlord_id is distinct from old.landlord_id
    or new.submitted_by_profile_id is distinct from old.submitted_by_profile_id
  ) then
    raise exception 'The maintenance request unit, landlord, and submitter cannot be changed.';
  end if;

  if (tg_op = 'INSERT' and new.assigned_to_staff_id is not null)
    or (tg_op = 'UPDATE' and new.assigned_to_staff_id is distinct from old.assigned_to_staff_id)
  then
    if not public.current_user_can_assign_maintenance_unit(new.unit_id) then
      raise exception 'You do not have permission to assign maintenance for this unit.';
    end if;

    if new.assigned_to_staff_id is not null
      and not public.maintenance_assignee_allowed(new.assigned_to_staff_id, new.landlord_id, new.unit_id)
    then
      raise exception 'That staff member is not assigned to this landlord and unit.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists maintenance_assignment_scope_check on public.maintenance_requests;
create trigger maintenance_assignment_scope_check
before insert or update of unit_id, landlord_id, submitted_by_profile_id, assigned_to_staff_id
on public.maintenance_requests
for each row
execute function public.enforce_maintenance_assignment_scope();

drop function if exists public.maintenance_assignable_units();

create or replace function public.maintenance_assignable_units()
returns table (unit_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select u.id as unit_id
  from public.units u
  join public.properties pr on pr.id = u.property_id
  where u.archived_at is null
    and pr.archived_at is null
    and public.current_user_can_assign_maintenance_unit(u.id)
  order by u.id
$$;

drop function if exists public.maintenance_assignable_staff(uuid);

create or replace function public.maintenance_assignable_staff(
  p_unit_id uuid default null
)
returns table (
  unit_id uuid,
  profile_id uuid,
  full_name text,
  email text,
  phone text,
  staff_source text
)
language sql
stable
security definer
set search_path = public
as $$
  with eligible_units as (
    select u.id as unit_id, u.property_id, pr.landlord_id
    from public.units u
    join public.properties pr on pr.id = u.property_id
    where (p_unit_id is null or u.id = p_unit_id)
      and u.archived_at is null
      and pr.archived_at is null
      and public.current_user_can_assign_maintenance_unit(u.id)
  ),
  direct_staff as (
    select
      eu.unit_id,
      staff.id as profile_id,
      staff.full_name,
      staff.email,
      staff.phone,
      case when staff.staff_type = 'freelancer' then 'IPM' else 'Landlord staff' end::text as staff_source
    from eligible_units eu
    join public.staff_permissions sp on sp.landlord_id = eu.landlord_id
    join public.profiles staff on staff.id = sp.staff_profile_id
    where public.current_profile_role() in ('landlord', 'staff')
      and sp.status = 'approved'
      and (sp.all_properties or eu.property_id = any(sp.property_ids))
      and (
        sp.can_manage_maintenance
        or sp.can_create_maintenance
        or sp.can_assign_maintenance
        or sp.can_add_resolution_notes
      )
      and staff.role = 'staff'
      and staff.archived_at is null
  ),
  company_staff as (
    select
      eu.unit_id,
      staff.id as profile_id,
      staff.full_name,
      staff.email,
      staff.phone,
      'PMC staff'::text as staff_source
    from eligible_units eu
    join public.management_landlord_permissions mlp on mlp.landlord_id = eu.landlord_id
    join public.management_staff_permissions msp on msp.management_company_id = mlp.management_company_id
    join public.profiles staff on staff.id = msp.staff_profile_id
    where (
        public.current_profile_role() = 'landlord'
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and mlp.management_company_id = public.current_management_company_id()
        )
      )
      and mlp.status = 'approved'
      and (mlp.all_properties or eu.property_id = any(mlp.property_ids))
      and (
        mlp.can_manage_maintenance
        or mlp.can_create_maintenance
        or mlp.can_assign_maintenance
        or mlp.can_add_resolution_notes
      )
      and msp.status = 'approved'
      and (msp.all_properties or eu.property_id = any(msp.property_ids))
      and (
        msp.can_manage_maintenance
        or msp.can_create_maintenance
        or msp.can_assign_maintenance
        or msp.can_add_resolution_notes
      )
      and staff.role = 'management_staff'
      and staff.landlord_id = eu.landlord_id
      and staff.archived_at is null
  )
  select distinct assignments.unit_id, assignments.profile_id, assignments.full_name,
    assignments.email, assignments.phone, assignments.staff_source
  from (
    select * from direct_staff
    union all
    select * from company_staff
  ) assignments
  order by assignments.full_name, assignments.email, assignments.unit_id
$$;

drop function if exists public.unit_assigned_staff(uuid);

create or replace function public.unit_assigned_staff(
  p_unit_id uuid
)
returns table (
  profile_id uuid,
  full_name text,
  email text,
  phone text,
  assignment_type text
)
language sql
stable
security definer
set search_path = public
as $$
  with requested_unit as (
    select u.id as unit_id, u.property_id, pr.landlord_id
    from public.units u
    join public.properties pr on pr.id = u.property_id
    where u.id = p_unit_id
      and u.archived_at is null
      and pr.archived_at is null
      and (
        (public.current_profile_role() = 'landlord' and pr.landlord_id = auth.uid())
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and public.management_can_access_unit(u.id)
        )
      )
  ),
  direct_staff as (
    select
      staff.id as profile_id,
      staff.full_name,
      staff.email,
      staff.phone,
      case when staff.staff_type = 'freelancer' then 'IPM' else 'Landlord staff' end::text as assignment_type
    from requested_unit ru
    join public.staff_permissions sp on sp.landlord_id = ru.landlord_id
    join public.profiles staff on staff.id = sp.staff_profile_id
    where public.current_profile_role() = 'landlord'
      and sp.status = 'approved'
      and (sp.all_properties or ru.property_id = any(sp.property_ids))
      and staff.role = 'staff'
      and staff.archived_at is null
  ),
  company_staff as (
    select
      staff.id as profile_id,
      staff.full_name,
      staff.email,
      staff.phone,
      'PMC staff'::text as assignment_type
    from requested_unit ru
    join public.management_landlord_permissions mlp on mlp.landlord_id = ru.landlord_id
    join public.management_staff_permissions msp on msp.management_company_id = mlp.management_company_id
    join public.profiles staff on staff.id = msp.staff_profile_id
    where (
        public.current_profile_role() = 'landlord'
        or (
          public.current_profile_role() in ('management_leader', 'management_staff')
          and mlp.management_company_id = public.current_management_company_id()
        )
      )
      and mlp.status = 'approved'
      and (mlp.all_properties or ru.property_id = any(mlp.property_ids))
      and msp.status = 'approved'
      and (msp.all_properties or ru.property_id = any(msp.property_ids))
      and staff.role = 'management_staff'
      and staff.landlord_id = ru.landlord_id
      and staff.archived_at is null
  )
  select distinct assignments.profile_id, assignments.full_name, assignments.email,
    assignments.phone, assignments.assignment_type
  from (
    select * from direct_staff
    union all
    select * from company_staff
  ) assignments
  order by assignments.full_name, assignments.email
$$;

insert into public.pricing_plans (
  country_id,
  country_code,
  country_name,
  currency_code,
  account_type,
  plan_key,
  plan_name,
  display_order,
  monthly_amount,
  yearly_amount,
  custom_price_label,
  description,
  limits_summary,
  property_limit,
  unit_limit,
  personal_staff_limit,
  partner_connection_limit,
  landlord_limit,
  properties_per_landlord_limit,
  staff_limit,
  cta_label,
  cta_href,
  popular,
  public_active
)
select
  c.id,
  seed.country_code,
  seed.country_name,
  seed.currency_code,
  seed.account_type,
  seed.plan_key,
  seed.plan_name,
  seed.display_order,
  seed.monthly_amount,
  seed.yearly_amount,
  seed.custom_price_label,
  seed.description,
  seed.limits_summary,
  seed.property_limit,
  seed.unit_limit,
  seed.personal_staff_limit,
  seed.partner_connection_limit,
  seed.landlord_limit,
  seed.properties_per_landlord_limit,
  seed.staff_limit,
  seed.cta_label,
  seed.cta_href,
  seed.popular,
  true
from (
  values
    ('ZW', 'Zimbabwe', 'USD', 'landlord', 'free', 'Free', 10, 0::numeric, 0::numeric, null::text, 'For one-unit landlords and landlords invited by an IPM or PMC.', '1 property, 1 unit, Finance page, 0 personal staff, 1 IPM or PMC connection', 1, 1, 0, 1, 0, 0, 0, 'Sign up for free', 'landlord-signup.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'landlord', 'starter', 'Starter', 20, 4::numeric, 44::numeric, null::text, 'For a small landlord who needs more than the free single-unit account.', '2 properties, 8 units, 1 staff, 1 IPM or PMC connection', 2, 8, 1, 1, 0, 0, 0, 'Enquire', 'contact.html', true),
    ('ZW', 'Zimbabwe', 'USD', 'landlord', 'growth', 'Growth', 30, 10::numeric, 110::numeric, null::text, 'For growing owners with multiple units.', '6 properties, 35 units, 3 staff, 2 IPM or PMC connections', 6, 35, 3, 2, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'landlord', 'portfolio', 'Portfolio', 40, 22::numeric, 242::numeric, null::text, 'For larger landlords with more staff and partner access.', '20 properties, 120 units, 8 staff, 5 IPM or PMC connections', 20, 120, 8, 5, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'landlord', 'custom', 'Custom', 50, 0::numeric, 0::numeric, 'From $50', 'For landlords who need custom limits and support.', 'Custom properties, units, staff, and partner connections', 0, 0, 0, 0, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'ipm', 'pro', 'Pro', 10, 15::numeric, 165::numeric, null::text, 'For Individual Portfolio Managers serving multiple landlords.', '5 landlords, 5 properties per landlord', 0, 0, 0, 0, 5, 5, 0, 'Enquire', 'contact.html', true),
    ('ZW', 'Zimbabwe', 'USD', 'ipm', 'growth', 'Growth', 20, 35::numeric, 385::numeric, null::text, 'For IPMs growing their landlord portfolio.', '15 landlords, 12 properties per landlord', 0, 0, 0, 0, 15, 12, 0, 'Enquire', 'contact.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'ipm', 'portfolio', 'Portfolio', 30, 70::numeric, 770::numeric, null::text, 'For established IPMs managing many landlords.', '40 landlords, 30 properties per landlord', 0, 0, 0, 0, 40, 30, 0, 'Enquire', 'contact.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'ipm', 'custom', 'Custom', 40, 0::numeric, 0::numeric, 'From $100', 'For IPMs who need custom landlord and property limits.', 'Custom landlord and property limits', 0, 0, 0, 0, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'pmc', 'starter', 'Starter', 10, 30::numeric, 330::numeric, null::text, 'For Property Management Companies starting on Mushavo.', '3 landlords, 15 properties, 75 units, 5 staff', 15, 75, 0, 0, 3, 0, 5, 'Enquire', 'contact.html', true),
    ('ZW', 'Zimbabwe', 'USD', 'pmc', 'growth', 'Growth', 20, 75::numeric, 825::numeric, null::text, 'For PMCs managing a growing portfolio.', '12 landlords, 75 properties, 400 units, 15 staff', 75, 400, 0, 0, 12, 0, 15, 'Enquire', 'contact.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'pmc', 'business', 'Business', 30, 150::numeric, 1650::numeric, null::text, 'For larger PMCs with bigger teams and portfolios.', '35 landlords, 250 properties, 1500 units, 40 staff', 250, 1500, 0, 0, 35, 0, 40, 'Enquire', 'contact.html', false),
    ('ZW', 'Zimbabwe', 'USD', 'pmc', 'custom', 'Custom', 40, 0::numeric, 0::numeric, 'From $250', 'For PMCs that need custom limits and onboarding.', 'Custom landlords, properties, units, and staff', 0, 0, 0, 0, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'landlord', 'free', 'Free', 10, 0::numeric, 0::numeric, null::text, 'For one-unit landlords and landlords invited by an IPM or PMC.', '1 property, 1 unit, Finance page, 0 personal staff, 1 IPM or PMC connection', 1, 1, 0, 1, 0, 0, 0, 'Sign up for free', 'landlord-signup.html', false),
    ('MY', 'Malaysia', 'MYR', 'landlord', 'starter', 'Starter', 20, 19::numeric, 209::numeric, null::text, 'For a small landlord who needs more than the free single-unit account.', '2 properties, 8 units, 1 staff, 1 IPM or PMC connection', 2, 8, 1, 1, 0, 0, 0, 'Enquire', 'contact.html', true),
    ('MY', 'Malaysia', 'MYR', 'landlord', 'growth', 'Growth', 30, 59::numeric, 649::numeric, null::text, 'For growing owners with multiple units.', '6 properties, 35 units, 3 staff, 2 IPM or PMC connections', 6, 35, 3, 2, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'landlord', 'portfolio', 'Portfolio', 40, 149::numeric, 1639::numeric, null::text, 'For larger landlords with more staff and partner access.', '20 properties, 120 units, 8 staff, 5 IPM or PMC connections', 20, 120, 8, 5, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'landlord', 'custom', 'Custom', 50, 0::numeric, 0::numeric, 'From RM349', 'For landlords who need custom limits and support.', 'Custom properties, units, staff, and partner connections', 0, 0, 0, 0, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'ipm', 'pro', 'Pro', 10, 129::numeric, 1419::numeric, null::text, 'For Individual Portfolio Managers serving multiple landlords.', '5 landlords, 5 properties per landlord', 0, 0, 0, 0, 5, 5, 0, 'Enquire', 'contact.html', true),
    ('MY', 'Malaysia', 'MYR', 'ipm', 'growth', 'Growth', 20, 299::numeric, 3289::numeric, null::text, 'For IPMs growing their landlord portfolio.', '15 landlords, 12 properties per landlord', 0, 0, 0, 0, 15, 12, 0, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'ipm', 'portfolio', 'Portfolio', 30, 599::numeric, 6589::numeric, null::text, 'For established IPMs managing many landlords.', '40 landlords, 30 properties per landlord', 0, 0, 0, 0, 40, 30, 0, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'ipm', 'custom', 'Custom', 40, 0::numeric, 0::numeric, 'From RM899', 'For IPMs who need custom landlord and property limits.', 'Custom landlord and property limits', 0, 0, 0, 0, 0, 0, 0, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'pmc', 'starter', 'Starter', 10, 249::numeric, 2739::numeric, null::text, 'For Property Management Companies starting on Mushavo.', '3 landlords, 15 properties, 75 units, 5 staff', 15, 75, 0, 0, 3, 0, 5, 'Enquire', 'contact.html', true),
    ('MY', 'Malaysia', 'MYR', 'pmc', 'growth', 'Growth', 20, 649::numeric, 7139::numeric, null::text, 'For PMCs managing a growing portfolio.', '12 landlords, 75 properties, 400 units, 15 staff', 75, 400, 0, 0, 12, 0, 15, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'pmc', 'business', 'Business', 30, 1299::numeric, 14289::numeric, null::text, 'For larger PMCs with bigger teams and portfolios.', '35 landlords, 250 properties, 1500 units, 40 staff', 250, 1500, 0, 0, 35, 0, 40, 'Enquire', 'contact.html', false),
    ('MY', 'Malaysia', 'MYR', 'pmc', 'custom', 'Custom', 40, 0::numeric, 0::numeric, 'From RM1,999', 'For PMCs that need custom limits and onboarding.', 'Custom landlords, properties, units, and staff', 0, 0, 0, 0, 0, 0, 0, 'Enquire', 'contact.html', false)
) as seed(
  country_code,
  country_name,
  currency_code,
  account_type,
  plan_key,
  plan_name,
  display_order,
  monthly_amount,
  yearly_amount,
  custom_price_label,
  description,
  limits_summary,
  property_limit,
  unit_limit,
  personal_staff_limit,
  partner_connection_limit,
  landlord_limit,
  properties_per_landlord_limit,
  staff_limit,
  cta_label,
  cta_href,
  popular
)
left join public.countries c
  on upper(coalesce(c.code, '')) = seed.country_code
  and c.archived_at is null
on conflict (country_code, account_type, plan_key) do update set
  country_id = coalesce(excluded.country_id, public.pricing_plans.country_id),
  country_name = excluded.country_name,
  currency_code = excluded.currency_code,
  plan_name = excluded.plan_name,
  display_order = excluded.display_order,
  monthly_amount = excluded.monthly_amount,
  yearly_amount = excluded.yearly_amount,
  custom_price_label = excluded.custom_price_label,
  description = excluded.description,
  limits_summary = excluded.limits_summary,
  property_limit = excluded.property_limit,
  unit_limit = excluded.unit_limit,
  personal_staff_limit = excluded.personal_staff_limit,
  partner_connection_limit = excluded.partner_connection_limit,
  landlord_limit = excluded.landlord_limit,
  properties_per_landlord_limit = excluded.properties_per_landlord_limit,
  staff_limit = excluded.staff_limit,
  cta_label = excluded.cta_label,
  cta_href = excluded.cta_href,
  popular = excluded.popular,
  public_active = excluded.public_active,
  updated_at = now();

grant usage on schema public to anon, authenticated;
grant usage on type
  public.user_role,
  public.subscription_status,
  public.unit_status,
  public.lease_status,
  public.payment_method,
  public.submission_status,
  public.maintenance_status,
  public.priority_level,
  public.notification_type
to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant insert on public.enquiries to anon;
grant select, update, delete on public.enquiries to authenticated;
grant select on public.pricing_plans to anon, authenticated;
grant insert, update, delete on public.pricing_plans to authenticated;
revoke execute on function public.create_super_admin(text, text) from public, anon, authenticated;
grant execute on function public.get_current_profile() to authenticated;
grant execute on function public.is_super_admin_profile(uuid) to authenticated;
grant execute on function public.admin_note_assignees() to authenticated;
grant execute on function public.is_management_leader_for_company(uuid) to authenticated;
grant execute on function public.is_management_staff_for_company(uuid) to authenticated;
grant execute on function public.validate_invite_token(text) to anon, authenticated;
grant execute on function public.register_free_landlord(text, text, uuid) to authenticated;
grant execute on function public.signup_identity_exists(text, text) to anon, authenticated;
grant execute on function public.tenant_signup_identity_exists(text, text, text) to anon, authenticated;
grant execute on function public.register_tenant_account(text, text, text, uuid) to authenticated;
grant execute on function public.search_landlord_by_email(text) to authenticated;
grant execute on function public.search_tenant_by_email(text) to authenticated;
grant execute on function public.validate_landlord_code(text) to anon, authenticated;
grant execute on function public.register_staff_with_landlord_code(text, text, text) to authenticated;
grant execute on function public.request_staff_landlord_access(text) to authenticated;
grant execute on function public.request_staff_landlord_access_by_email(text) to authenticated;
grant execute on function public.invite_landlord_from_ipm(text) to authenticated;
grant execute on function public.approve_staff_landlord_request(uuid) to authenticated;
grant execute on function public.approve_staff_landlord_request_with_permissions(uuid, jsonb) to authenticated;
grant execute on function public.reject_staff_landlord_request(uuid) to authenticated;
grant execute on function public.switch_staff_landlord(uuid) to authenticated;
grant execute on function public.request_management_landlord_access(text) to authenticated;
grant execute on function public.request_management_landlord_access_by_email(text) to authenticated;
grant execute on function public.invite_landlord_from_management(text) to authenticated;
grant execute on function public.approve_management_landlord_request(uuid) to authenticated;
grant execute on function public.approve_management_landlord_request_with_permissions(uuid, jsonb) to authenticated;
grant execute on function public.unassign_management_landlord_permission(uuid) to authenticated;
grant execute on function public.drop_partner_landlord(text, uuid) to authenticated;
grant execute on function public.update_partner_landlord_contract(text, uuid, date, date) to authenticated;
grant execute on function public.reject_management_landlord_request(uuid) to authenticated;
grant execute on function public.regenerate_landlord_code() to authenticated;
grant execute on function public.check_lease_expiries() to authenticated;
grant execute on function public.accept_payment_submission(uuid) to authenticated;
grant execute on function public.current_user_can_access_lease_finance(uuid) to authenticated;
grant execute on function public.current_user_can_manage_lease_finance(uuid) to authenticated;
grant execute on function public.ensure_rent_charges_for_lease(uuid, date) to authenticated;
grant execute on function public.ensure_deposit_charge_for_lease(uuid) to authenticated;
grant execute on function public.recalculate_charge_paid(uuid) to authenticated;
grant execute on function public.allocate_payment_to_charge(uuid, uuid, numeric) to authenticated;
grant execute on function public.link_current_tenant_account() to authenticated;
grant execute on function public.accept_tenant_invite(uuid) to authenticated;
grant execute on function public.accept_tenant_invite(uuid, text, text, text) to authenticated;
grant execute on function public.respond_tenant_link_request(uuid, boolean) to authenticated;
grant execute on function public.create_tenant_reference_request(uuid, text, text, text) to authenticated;
grant execute on function public.respond_tenant_reference_request(uuid, boolean) to authenticated;
grant execute on function public.current_tenant_landlord() to authenticated;
grant execute on function public.tenant_landlord_relationships() to authenticated;
grant execute on function public.drop_tenant_landlord(uuid) to authenticated;
grant execute on function public.tenant_unit_contacts(uuid) to authenticated;
grant execute on function public.maintenance_assignable_units() to authenticated;
grant execute on function public.maintenance_assignable_staff(uuid) to authenticated;
grant execute on function public.unit_assigned_staff(uuid) to authenticated;
grant execute on function public.lease_document_lease_id(text) to authenticated;
grant execute on function public.can_read_lease_document(text) to authenticated;
grant execute on function public.can_manage_lease_document(text) to authenticated;
grant execute on function public.media_object_row_id(text) to authenticated;
grant execute on function public.can_read_payment_proof(text) to authenticated;
grant execute on function public.can_manage_payment_proof(text) to authenticated;
grant execute on function public.can_read_maintenance_photo(text) to authenticated;
grant execute on function public.can_manage_maintenance_photo(text) to authenticated;
grant all on public.property_inspections to authenticated;
grant all on public.inspection_files to authenticated;
grant execute on function public.inspection_file_inspection_id(text) to authenticated;
grant execute on function public.can_access_inspection(uuid) to authenticated;
grant execute on function public.can_manage_inspection(uuid) to authenticated;
grant execute on function public.can_read_inspection_file(text) to authenticated;
grant execute on function public.can_manage_inspection_file(text) to authenticated;
grant execute on function public.tenant_sign_inspection(uuid, text) to authenticated;
revoke execute on function public.attach_payment_proof(uuid, text, text, integer) from public, anon;
revoke execute on function public.attach_payment_record_proof(uuid, text, text, integer) from public, anon;
revoke execute on function public.attach_maintenance_photo(uuid, text, text, integer) from public, anon;
revoke execute on function public.tenant_signup_identity_exists(text, text, text) from public;
revoke execute on function public.register_tenant_account(text, text, text, uuid) from public, anon;
revoke execute on function public.link_current_tenant_account() from public, anon;
revoke execute on function public.accept_tenant_invite(uuid) from public, anon;
revoke execute on function public.accept_tenant_invite(uuid, text, text, text) from public, anon;
revoke execute on function public.respond_tenant_link_request(uuid, boolean) from public, anon;
revoke execute on function public.create_tenant_reference_request(uuid, text, text, text) from public, anon;
revoke execute on function public.respond_tenant_reference_request(uuid, boolean) from public, anon;
revoke execute on function public.current_tenant_landlord() from public, anon;
revoke execute on function public.tenant_landlord_relationships() from public, anon;
revoke execute on function public.drop_tenant_landlord(uuid) from public, anon;
revoke execute on function public.create_tenant_invite(uuid, text, text, text, text) from public, anon;
revoke execute on function public.tenant_unit_contacts(uuid) from public, anon;
revoke execute on function public.delete_landlord_account(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.delete_tenant_account(uuid) from public, anon, authenticated;
revoke execute on function public.delete_staff_account(uuid) from public, anon, authenticated;
revoke execute on function public.unarchive_landlord_account(uuid) from public, anon, authenticated;
revoke execute on function public.unarchive_staff_account(uuid) from public, anon, authenticated;
revoke execute on function public.unarchive_management_company(uuid) from public, anon, authenticated;
revoke execute on function public.permanently_delete_landlord_account(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.permanently_delete_tenant_account(uuid) from public, anon, authenticated;
revoke execute on function public.permanently_delete_staff_account(uuid) from public, anon, authenticated;
revoke execute on function public.permanently_delete_management_company(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.permanently_delete_management_staff_account(uuid) from public, anon, authenticated;
grant execute on function public.attach_payment_proof(uuid, text, text, integer) to authenticated;
grant execute on function public.attach_payment_record_proof(uuid, text, text, integer) to authenticated;
grant execute on function public.attach_maintenance_photo(uuid, text, text, integer) to authenticated;
grant execute on function public.delete_landlord_account(uuid, uuid) to authenticated;
grant execute on function public.delete_tenant_account(uuid) to authenticated;
grant execute on function public.delete_staff_account(uuid) to authenticated;
grant execute on function public.create_tenant_invite(uuid, text, text, text, text) to authenticated;
grant execute on function public.respond_tenant_link_request(uuid, boolean) to authenticated;
grant execute on function public.create_tenant_reference_request(uuid, text, text, text) to authenticated;
grant execute on function public.respond_tenant_reference_request(uuid, boolean) to authenticated;
grant execute on function public.current_tenant_landlord() to authenticated;
grant execute on function public.tenant_landlord_relationships() to authenticated;
grant execute on function public.drop_tenant_landlord(uuid) to authenticated;
grant execute on function public.tenant_unit_contacts(uuid) to authenticated;
grant execute on function public.unarchive_landlord_account(uuid) to authenticated;
grant execute on function public.unarchive_staff_account(uuid) to authenticated;
grant execute on function public.unarchive_management_company(uuid) to authenticated;
grant execute on function public.permanently_delete_landlord_account(uuid, uuid) to authenticated;
grant execute on function public.permanently_delete_tenant_account(uuid) to authenticated;
grant execute on function public.permanently_delete_staff_account(uuid) to authenticated;
grant execute on function public.permanently_delete_management_company(uuid, uuid) to authenticated;
grant execute on function public.permanently_delete_management_staff_account(uuid) to authenticated;

-- Realtime: allow the client to receive live insert/update/delete events.
-- RLS still controls which rows each signed-in account can read after a refresh.
do $$
declare
  realtime_table text;
begin
  foreach realtime_table in array array[
    'profiles',
    'countries',
    'pricing_plans',
    'landlord_subscriptions',
    'landlord_subscription_admin_notes',
    'properties',
    'units',
    'tenants',
    'leases',
    'payments',
    'payment_submissions',
    'lease_charges',
    'payment_allocations',
    'lease_ledger_entries',
    'finance_audit_events',
    'platform_payments',
    'partner_payments',
    'partner_reconciliations',
    'maintenance_requests',
    'maintenance_quotes',
    'maintenance_activity',
    'property_inspections',
    'inspection_files',
    'notifications',
    'staff_permissions',
    'staff_landlord_requests',
    'management_companies',
    'management_landlord_permissions',
    'management_landlord_requests',
    'management_staff_permissions',
    'invite_tokens',
    'admin_notes',
    'enquiries',
    'admin_staff_country_assignments'
  ]
  loop
    if to_regclass(format('public.%I', realtime_table)) is not null then
      begin
        execute format('alter publication supabase_realtime add table public.%I', realtime_table);
      exception
        when duplicate_object then null;
        when undefined_object then null;
      end;
    end if;
  end loop;
end $$;

commit;

-- USAGE BLOCK - CREATE THE ONE SUPER ADMIN ACCOUNT
--
-- Replace the email and password below with your own, then run this SELECT once
-- in the Supabase SQL Editor. After running, delete or comment out the SELECT
-- line for security.
--
SELECT public.create_super_admin(
  'dhruvp246@gmail.com',
  'Admin@123'
);
