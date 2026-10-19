-- Apply this migration in Supabase before using either mobile app.
-- User rows are linked by ID to the corresponding Supabase Auth user ID.

alter table public.signals
  add column if not exists exchange text not null default 'Binance',
  add column if not exists timeframe text not null default '15m',
  add column if not exists rationale text not null default '',
  add column if not exists strength integer not null default 0,
  add column if not exists is_free boolean not null default false,
  add column if not exists status text not null default 'active',
  add column if not exists result text not null default 'open',
  add column if not exists closed_at timestamptz;

alter table public.notifications
  add column if not exists user_id uuid references public.users(id) on delete cascade,
  add column if not exists signal_id bigint references public.signals(id) on delete set null;

alter table public.payments
  alter column status set default 'pending';

do $$
begin
  if exists (
    select 1
    from auth.users as au
    join public.users as u on lower(u.email) = lower(au.email)
    where u.id <> au.id
  ) then
    raise exception
      'Some public.users IDs do not match their auth.users IDs. Reconcile these accounts before applying this migration.';
  end if;
end;
$$;

create or replace function public.app_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role = 'admin'
  );
$$;

create or replace function public.app_has_signal_access(check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.subscriptions
    where user_id = check_user_id
      and status = 'active'
      and expires_at > now()
  ) or exists (
    select 1
    from public.trial_history
    where user_id = check_user_id
      and is_active
      and end_date > now()
  );
$$;

revoke all on function public.app_has_signal_access(uuid) from public, anon, authenticated;

create or replace function public.handle_new_app_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, name, role)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data ->> 'name', ''),
    'user'
  )
  on conflict (id) do nothing;

  insert into public.trial_history (user_id, start_date, end_date, is_active)
  select new.id, new.created_at, new.created_at + interval '6 days', true
  where not exists (
    select 1
    from public.trial_history
    where user_id = new.id
  );

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_app_profile on auth.users;
create trigger on_auth_user_created_app_profile
  after insert on auth.users
  for each row execute function public.handle_new_app_user();

insert into public.users (id, email, name, role)
select
  au.id,
  au.email,
  nullif(au.raw_user_meta_data ->> 'name', ''),
  'user'
from auth.users as au
on conflict (id) do nothing;

insert into public.trial_history (user_id, start_date, end_date, is_active)
select au.id, au.created_at, au.created_at + interval '6 days', true
from auth.users as au
where not exists (
  select 1 from public.trial_history as th where th.user_id = au.id
);

create or replace function public.distribute_app_signal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.signal_deliveries (signal_id, user_id, status)
  select new.id, u.id, 'sent'
  from public.users as u
  where new.is_free or public.app_has_signal_access(u.id)
  on conflict do nothing;

  insert into public.notifications (user_id, signal_id, title, message)
  select
    u.id,
    new.id,
    'إشارة جديدة: ' || new.pair,
    'إشارة ' || new.type || ' على ' || new.pair
  from public.users as u
  where new.is_free or public.app_has_signal_access(u.id);

  return new;
end;
$$;

drop trigger if exists on_app_signal_published on public.signals;
create trigger on_app_signal_published
  after insert on public.signals
  for each row execute function public.distribute_app_signal();

insert into public.signal_deliveries (signal_id, user_id, status)
select s.id, u.id, 'sent'
from public.signals as s
cross join public.users as u
where (s.is_free or public.app_has_signal_access(u.id))
  and not exists (
  select 1
  from public.signal_deliveries as sd
  where sd.signal_id = s.id
    and sd.user_id = u.id
);

create or replace function public.admin_activate_subscription(
  target_user_id uuid,
  target_plan_name text,
  duration_days integer
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  created_subscription_id bigint;
begin
  if not public.app_is_admin() then
    raise exception 'Admin access required';
  end if;

  if duration_days < 1 or duration_days > 3660 then
    raise exception 'Invalid subscription duration';
  end if;

  update public.subscriptions
  set status = 'expired'
  where user_id = target_user_id
    and status = 'active';

  insert into public.subscriptions (user_id, plan_name, status, expires_at)
  values (
    target_user_id,
    target_plan_name,
    'active',
    now() + make_interval(days => duration_days)
  )
  returning id into created_subscription_id;

  return created_subscription_id;
end;
$$;

create or replace function public.admin_confirm_payment(
  target_payment_id bigint,
  target_plan_name text,
  duration_days integer
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_payment public.payments%rowtype;
  created_subscription_id bigint;
begin
  if not public.app_is_admin() then
    raise exception 'Admin access required';
  end if;

  if duration_days < 1 or duration_days > 3660 then
    raise exception 'Invalid subscription duration';
  end if;

  select *
  into selected_payment
  from public.payments
  where id = target_payment_id
  for update;

  if not found or selected_payment.status <> 'pending' then
    raise exception 'Payment is not pending';
  end if;

  if selected_payment.user_id is null then
    raise exception 'Payment has no user account';
  end if;

  update public.payments
  set status = 'completed'
  where id = selected_payment.id;

  update public.subscriptions
  set status = 'expired'
  where user_id = selected_payment.user_id
    and status = 'active';

  insert into public.subscriptions (user_id, plan_name, status, expires_at)
  values (
    selected_payment.user_id,
    target_plan_name,
    'active',
    now() + make_interval(days => duration_days)
  )
  returning id into created_subscription_id;

  return created_subscription_id;
end;
$$;

alter table public.users enable row level security;
alter table public.subscriptions enable row level security;
alter table public.trial_history enable row level security;
alter table public.signals enable row level security;
alter table public.signal_deliveries enable row level security;
alter table public.payments enable row level security;
alter table public.notifications enable row level security;
alter table public.market_data enable row level security;
alter table public.support_messages enable row level security;
alter table public.admin_settings enable row level security;

drop policy if exists app_users_read_self_or_admin on public.users;
create policy app_users_read_self_or_admin on public.users
  for select to authenticated
  using (id = auth.uid() or public.app_is_admin());

drop policy if exists app_users_update_name on public.users;
create policy app_users_update_name on public.users
  for update to authenticated
  using (id = auth.uid() or public.app_is_admin())
  with check (id = auth.uid() or public.app_is_admin());

revoke all on public.users from anon, authenticated;
grant select on public.users to authenticated;
grant update (name) on public.users to authenticated;

drop policy if exists app_subscriptions_read_self_or_admin on public.subscriptions;
create policy app_subscriptions_read_self_or_admin on public.subscriptions
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());

drop policy if exists app_subscriptions_admin_manage on public.subscriptions;
create policy app_subscriptions_admin_manage on public.subscriptions
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

drop policy if exists app_trials_read_self_or_admin on public.trial_history;
create policy app_trials_read_self_or_admin on public.trial_history
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());

drop policy if exists app_trials_admin_manage on public.trial_history;
create policy app_trials_admin_manage on public.trial_history
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

drop policy if exists app_signals_read_entitled on public.signals;
create policy app_signals_read_entitled on public.signals
  for select to authenticated
  using (
    public.app_is_admin()
    or is_free
    or exists (
      select 1
      from public.subscriptions
      where user_id = auth.uid()
        and status = 'active'
        and expires_at > now()
    )
    or exists (
      select 1
      from public.trial_history
      where user_id = auth.uid()
        and is_active
        and end_date > now()
    )
  );

drop policy if exists app_signals_admin_manage on public.signals;
create policy app_signals_admin_manage on public.signals
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

drop policy if exists app_deliveries_read_self_or_admin on public.signal_deliveries;
create policy app_deliveries_read_self_or_admin on public.signal_deliveries
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());

drop policy if exists app_deliveries_admin_manage on public.signal_deliveries;
create policy app_deliveries_admin_manage on public.signal_deliveries
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

drop policy if exists app_payments_read_self_or_admin on public.payments;
create policy app_payments_read_self_or_admin on public.payments
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());

drop policy if exists app_payments_create_pending_self on public.payments;
create policy app_payments_create_pending_self on public.payments
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');

drop policy if exists app_payments_admin_update on public.payments;
create policy app_payments_admin_update on public.payments
  for update to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

revoke all on public.payments from anon, authenticated;
grant select on public.payments to authenticated;
grant insert (user_id, amount, currency, payment_method, transaction_id)
  on public.payments to authenticated;
grant update (status) on public.payments to authenticated;

drop policy if exists app_notifications_read_visible on public.notifications;
create policy app_notifications_read_visible on public.notifications
  for select to authenticated
  using (user_id is null or user_id = auth.uid() or public.app_is_admin());

drop policy if exists app_notifications_admin_manage on public.notifications;
create policy app_notifications_admin_manage on public.notifications
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

drop policy if exists app_market_data_read on public.market_data;
create policy app_market_data_read on public.market_data
  for select to anon, authenticated
  using (true);

drop policy if exists app_market_data_admin_manage on public.market_data;
create policy app_market_data_admin_manage on public.market_data
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

drop policy if exists app_support_create_self on public.support_messages;
create policy app_support_create_self on public.support_messages
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists app_support_read_self_or_admin on public.support_messages;
create policy app_support_read_self_or_admin on public.support_messages
  for select to authenticated
  using (user_id = auth.uid() or public.app_is_admin());

drop policy if exists app_admin_settings_read on public.admin_settings;
create policy app_admin_settings_read on public.admin_settings
  for select to authenticated
  using (
    public.app_is_admin()
    or key in (
      'monthly_price',
      'annual_price',
      'currency',
      'payment_methods',
      'support_url',
      'support_email'
    )
  );

drop policy if exists app_admin_settings_manage on public.admin_settings;
create policy app_admin_settings_manage on public.admin_settings
  for all to authenticated
  using (public.app_is_admin())
  with check (public.app_is_admin());

revoke all on public.subscriptions from anon, authenticated;
revoke all on public.trial_history from anon, authenticated;
revoke all on public.signals from anon, authenticated;
revoke all on public.signal_deliveries from anon, authenticated;
revoke all on public.notifications from anon, authenticated;
revoke all on public.market_data from anon, authenticated;
revoke all on public.support_messages from anon, authenticated;
revoke all on public.admin_settings from anon, authenticated;

grant select, insert, update, delete on public.subscriptions to authenticated;
grant select on public.trial_history to authenticated;
grant insert, update, delete on public.trial_history to authenticated;
grant select, insert, update, delete on public.signals to authenticated;
grant select, insert, update, delete on public.signal_deliveries to authenticated;
grant select, update on public.payments to authenticated;
grant select, insert, update, delete on public.notifications to authenticated;
grant select on public.market_data to anon, authenticated;
grant insert, update, delete on public.market_data to authenticated;
grant select, insert on public.support_messages to authenticated;
grant select, insert, update, delete on public.admin_settings to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on function public.app_is_admin() to authenticated;
grant execute on function public.admin_activate_subscription(uuid, text, integer)
  to authenticated;
grant execute on function public.admin_confirm_payment(bigint, text, integer)
  to authenticated;
