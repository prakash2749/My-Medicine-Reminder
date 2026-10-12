-- Notify SIMPLIFIED MVP: 8 public tables + managed auth.users.
-- Fresh-development migration, not a conversion of previously created tables.
-- Scope: each account manages its own medicine routine. Care Circle provides optional support.
-- No passwords stored in application tables.
begin;

-- USE: Personal information for the signed-in user.
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text,
 birth_date date,
 gender text,
 language text not null default 'en',
 timezone text not null default 'Asia/Kolkata',
 onboarding_step text not null default 'personal_info',
 onboarding_completed_at timestamptz,
 created_at timestamptz not null default now()
);
comment on table public.profiles is 'Personal information for the signed-in user.';
comment on column public.profiles.id is 'Same ID as Supabase Auth user.';
comment on column public.profiles.name is 'Name entered during personal-info setup.';
comment on column public.profiles.birth_date is 'Birth date; not a stored age.';
comment on column public.profiles.gender is 'Optional gender.';
comment on column public.profiles.language is 'Preferred app language.';
comment on column public.profiles.timezone is 'IANA timezone; validate in app/backend.';
comment on column public.profiles.onboarding_step is 'Last saved step for resuming setup.';
comment on column public.profiles.onboarding_completed_at is 'Set after successful required setup.';
comment on column public.profiles.created_at is 'Creation t ime.';
alter table public.profiles enable row level security;
revoke all on public.profiles from public,anon,authenticated;
grant select,insert,update,delete on public.profiles to service_role;
grant select,insert,update,delete on public.profiles to authenticated;
create policy profiles_own on public.profiles for all to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));

-- USE: My Day routine times; not confirmed medicine dose times.
create table public.routine_times (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 event_type text not null check(event_type in ('wake_up','breakfast','lunch','dinner','bedtime')),
 local_time time not null,
 created_at timestamptz not null default now(),
 unique(user_id,event_type)
);
comment on table public.routine_times is 'My Day routine times; not confirmed medicine dose times.';
comment on column public.routine_times.id is 'Routine row ID.';
comment on column public.routine_times.user_id is 'Routine owner.';
comment on column public.routine_times.event_type is 'Routine event.';
comment on column public.routine_times.local_time is 'Usual local clock time.';
comment on column public.routine_times.created_at is 'Creation time.';
alter table public.routine_times enable row level security;
revoke all on public.routine_times from public,anon,authenticated;
grant select,insert,update,delete on public.routine_times to service_role;
grant select,insert,update,delete on public.routine_times to authenticated;
create policy routine_times_own on public.routine_times for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create index routine_times_user_id_idx on public.routine_times(user_id);

-- USE: Flat list of selectable purpose items; one row per checkbox.
create table public.onboarding_questions (
 id uuid primary key default gen_random_uuid(),
 code text not null unique,
 question_text text not null check(length(btrim(question_text))>0),
 display_order integer not null default 0,
 is_active boolean not null default true,
 created_at timestamptz not null default now()
);
comment on table public.onboarding_questions is 'Flat list of selectable purpose items; one row per checkbox.';
comment on column public.onboarding_questions.id is 'Referenced by onboarding_answers.question_id.';
comment on column public.onboarding_questions.code is 'Stable item code; never repurpose its meaning.';
comment on column public.onboarding_questions.question_text is 'Checkbox label, e.g. Remember my medicines.';
comment on column public.onboarding_questions.display_order is 'Order in purpose list.';
comment on column public.onboarding_questions.is_active is 'Show for new selections; retain old rows for references.';
comment on column public.onboarding_questions.created_at is 'Creation time.';
alter table public.onboarding_questions enable row level security;
revoke all on public.onboarding_questions from public,anon,authenticated;
grant select,insert,update,delete on public.onboarding_questions to service_role;
grant select on public.onboarding_questions to anon,authenticated;
create policy questions_public_read on public.onboarding_questions for select to anon using(is_active);

-- USE: Selection link table; row exists only while item is selected.
create table public.onboarding_answers (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 question_id uuid not null references public.onboarding_questions(id) on delete restrict,
 created_at timestamptz not null default now(),
 unique(user_id,question_id)
);
comment on table public.onboarding_answers is 'Selection link table; row exists only while item is selected.';
comment on column public.onboarding_answers.id is 'Selection row ID.';
comment on column public.onboarding_answers.user_id is 'User selecting the item.';
comment on column public.onboarding_answers.question_id is 'Selected item from master list.';
comment on column public.onboarding_answers.created_at is 'Creation time.';
alter table public.onboarding_answers enable row level security;
revoke all on public.onboarding_answers from public,anon,authenticated;
grant select,insert,update,delete on public.onboarding_answers to service_role;
grant select,insert,update,delete on public.onboarding_answers to authenticated;
create policy onboarding_answers_own on public.onboarding_answers for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create index onboarding_answers_user_id_idx on public.onboarding_answers(user_id);
create index onboarding_answers_question_id_idx on public.onboarding_answers(question_id);

-- USE: One confirmed medication plan; medicine details stored here for MVP.
create table public.medication_schedules (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 medication_name text not null check(length(btrim(medication_name))>0),
 strength text,
 instructions text,
 schedule_type text not null default 'daily' check(schedule_type in ('daily','selected_days')),
 days_of_week smallint[],
 starts_on date not null,
 ends_on date,
 timezone text not null default 'Asia/Kolkata',
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 check(ends_on is null or ends_on>=starts_on),
 check((schedule_type='daily' and days_of_week is null) or (schedule_type='selected_days' and days_of_week is not null and cardinality(days_of_week)>0 and days_of_week <@ array[1,2,3,4,5,6,7]::smallint[] and array_position(days_of_week,null) is null))
);
comment on table public.medication_schedules is 'One confirmed medication plan; medicine details stored here for MVP.';
comment on column public.medication_schedules.id is 'Schedule ID; referenced by schedule_slots.';
comment on column public.medication_schedules.user_id is 'Schedule owner.';
comment on column public.medication_schedules.medication_name is 'User-confirmed medicine name.';
comment on column public.medication_schedules.strength is 'Confirmed medicine strength, e.g. 500 mg.';
comment on column public.medication_schedules.instructions is 'Confirmed prescription instructions.';
comment on column public.medication_schedules.schedule_type is 'MVP supports daily or selected weekdays.';
comment on column public.medication_schedules.days_of_week is 'ISO weekdays 1=Monday to 7=Sunday, for selected_days.';
comment on column public.medication_schedules.starts_on is 'First course date.';
comment on column public.medication_schedules.ends_on is 'Optional last course date.';
comment on column public.medication_schedules.timezone is 'Timezone used to calculate reminder instants.';
comment on column public.medication_schedules.is_active is 'Whether plan produces reminders.';
comment on column public.medication_schedules.created_at is 'Creation time.';
alter table public.medication_schedules enable row level security;
revoke all on public.medication_schedules from public,anon,authenticated;
grant select,insert,update,delete on public.medication_schedules to service_role;
grant select,insert,update,delete on public.medication_schedules to authenticated;
create policy medication_schedules_own on public.medication_schedules for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create index medication_schedules_user_id_idx on public.medication_schedules(user_id);

-- USE: Each confirmed dose time under a medication schedule.
create table public.schedule_slots (
 id uuid primary key default gen_random_uuid(),
 schedule_id uuid not null references public.medication_schedules(id) on delete cascade,
 local_time time not null,
 dose_amount numeric not null check(dose_amount>0),
 dose_unit text not null check(length(btrim(dose_unit))>0),
 meal_relation text not null default 'none' check(meal_relation in ('none','before','with','after')),
 created_at timestamptz not null default now(),
 unique(schedule_id,local_time)
);
comment on table public.schedule_slots is 'Each confirmed dose time under a medication schedule.';
comment on column public.schedule_slots.id is 'Dose-time row ID.';
comment on column public.schedule_slots.schedule_id is 'Medication plan this time belongs to.';
comment on column public.schedule_slots.local_time is 'Confirmed reminder clock time.';
comment on column public.schedule_slots.dose_amount is 'Confirmed amount per intake.';
comment on column public.schedule_slots.dose_unit is 'Tablet, capsule, mL, etc.';
comment on column public.schedule_slots.meal_relation is 'Only a confirmed prescribed meal instruction.';
comment on column public.schedule_slots.created_at is 'Creation time.';
alter table public.schedule_slots enable row level security;
revoke all on public.schedule_slots from public,anon,authenticated;
grant select,insert,update,delete on public.schedule_slots to service_role;
grant select,insert,update,delete on public.schedule_slots to authenticated;
create policy schedule_slots_own on public.schedule_slots for all to authenticated using(exists(select 1 from public.medication_schedules s where s.id=schedule_slots.schedule_id and s.user_id=(select auth.uid()))) with check(exists(select 1 from public.medication_schedules s where s.id=schedule_slots.schedule_id and s.user_id=(select auth.uid())));
create index schedule_slots_schedule_id_idx on public.schedule_slots(schedule_id);
create policy questions_user_read on public.onboarding_questions for select to authenticated using(is_active or exists(select 1 from public.onboarding_answers a where a.question_id=onboarding_questions.id and a.user_id=(select auth.uid())));


create table public.care_circle_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  contact_name text not null check (length(btrim(contact_name)) between 1 and 100),
  phone_e164 text not null check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  relationship text check (relationship is null or length(btrim(relationship)) between 1 and 50),
  recipient_user_id uuid references auth.users(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'revoked')),
  alert_delay_minutes integer not null default 30
    check (alert_delay_minutes between 5 and 1440),
  alerts_enabled boolean not null default true,
  share_medication_details boolean not null default false,
  owner_consented_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cc_member_lifecycle check (
    (status = 'pending' and recipient_user_id is null and accepted_at is null and revoked_at is null)
    or (status = 'declined' and recipient_user_id is null and accepted_at is null and revoked_at is null)
    or (status = 'accepted' and recipient_user_id is not null and accepted_at is not null and revoked_at is null)
    or (status = 'revoked' and revoked_at is not null
        and ((recipient_user_id is null and accepted_at is null)
             or (recipient_user_id is not null and accepted_at is not null)))
  ),
  constraint cc_member_accept_order check (accepted_at is null or accepted_at >= owner_consented_at),
  constraint cc_member_revoke_order check (
    revoked_at is null or revoked_at >= coalesce(accepted_at, owner_consented_at)
  )
);

-- One current support relationship per user/contact, while keeping old revoked rows.
create unique index cc_member_current_phone
  on public.care_circle_members(user_id, phone_e164)
  where status in ('pending', 'accepted');
create unique index cc_member_current_recipient
  on public.care_circle_members(user_id, recipient_user_id)
  where status = 'accepted';
create index cc_member_profile_idx on public.care_circle_members(user_id);
create index cc_member_recipient_idx on public.care_circle_members(recipient_user_id)
  where recipient_user_id is not null;

create table public.care_circle_invites (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.care_circle_members(id) on delete cascade,
  invited_by_user_id uuid not null references auth.users(id) on delete restrict,
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  delivery_channel text not null default 'share_link'
    check (delivery_channel in ('sms', 'share_link')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  cancelled_at timestamptz,
  constraint cc_invite_expiry check (expires_at > created_at),
  constraint cc_invite_terminal check (not (used_at is not null and cancelled_at is not null)),
  constraint cc_invite_used_time check (used_at is null or (used_at >= created_at and used_at < expires_at)),
  constraint cc_invite_cancel_time check (cancelled_at is null or cancelled_at >= created_at)
);

-- Before resend, cancel any unconsumed invitation, including an expired one.
-- Cannot put a moving now() expiry test into this unique partial index.
create unique index cc_invite_one_unconsumed
  on public.care_circle_invites(member_id)
  where used_at is null and cancelled_at is null;
create index cc_invite_creator_idx on public.care_circle_invites(invited_by_user_id);

create function public.cc_touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
revoke all on function public.cc_touch_updated_at() from public, anon, authenticated;
create trigger cc_member_touch before update on public.care_circle_members
for each row execute function public.cc_touch_updated_at();

alter table public.care_circle_members enable row level security;
alter table public.care_circle_invites enable row level security;

-- Revoke default grants explicitly. Client mutations use authenticated backend endpoints.
revoke all on public.care_circle_members from public, anon, authenticated;
revoke all on public.care_circle_invites from public, anon, authenticated;
grant select on public.care_circle_members to authenticated;
grant select, insert, update, delete on public.care_circle_members to service_role;
grant select, insert, update, delete on public.care_circle_invites to service_role;

create policy cc_member_owner_read on public.care_circle_members
for select to authenticated using (
  exists (
    select 1 from public.profiles p
    where p.id = care_circle_members.user_id
      and p.id = (select auth.uid())
  )
);
create policy cc_member_recipient_read on public.care_circle_members
for select to authenticated using (
  recipient_user_id = (select auth.uid()) and status = 'accepted'
);
-- No client policy or grant for invites; token hashes never go to Flutter.
-- Recipients have no read access to owner profiles or medication schedules.


comment on table public.care_circle_members is 'Ongoing support relationship.';
comment on column public.care_circle_members.id is 'Relationship identity.';
comment on column public.care_circle_members.user_id is 'User whose unconfirmed doses may be shared.';
comment on column public.care_circle_members.contact_name is 'Support-person label.';
comment on column public.care_circle_members.phone_e164 is 'Invitation destination; format check does not verify ownership.';
comment on column public.care_circle_members.relationship is 'Optional relationship label.';
comment on column public.care_circle_members.recipient_user_id is 'Verified accepting account, null while pending.';
comment on column public.care_circle_members.status is 'Pending, accepted, declined or revoked.';
comment on column public.care_circle_members.alert_delay_minutes is 'Alert preference, not medical advice.';
comment on column public.care_circle_members.alerts_enabled is 'Pause support alerts; pending still cannot receive alerts.';
comment on column public.care_circle_members.share_medication_details is 'Explicit optional detail-sharing permission, default off.';
comment on column public.care_circle_members.owner_consented_at is 'Explicit owner sharing authorization timestamp.';
comment on column public.care_circle_members.accepted_at is 'Verified recipient acceptance timestamp.';
comment on column public.care_circle_members.revoked_at is 'Disconnection timestamp.';
comment on column public.care_circle_members.created_at is 'Creation time.';
comment on column public.care_circle_members.updated_at is 'Last modification, maintained by trigger.';
comment on table public.care_circle_invites is 'Temporary backend-only invitation attempts.';
comment on column public.care_circle_invites.id is 'Invitation-attempt identity.';
comment on column public.care_circle_invites.member_id is 'Pending relationship being invited.';
comment on column public.care_circle_invites.invited_by_user_id is 'Authenticated sender; backend verifies owner matches membership.';
comment on column public.care_circle_invites.token_hash is 'SHA-256 hash of a random secret; never raw token.';
comment on column public.care_circle_invites.delivery_channel is 'SMS or shared-link invitation, not alert delivery status.';
comment on column public.care_circle_invites.created_at is 'Invitation creation time.';
comment on column public.care_circle_invites.expires_at is 'Expiry; backend checks before accepting.';
comment on column public.care_circle_invites.used_at is 'Consumed once by acceptance.';
comment on column public.care_circle_invites.cancelled_at is 'Invalidated by resend, decline or revocation.';
insert into public.onboarding_questions(code,question_text,display_order) values ('medicine_reminders','Remember my medicines',1),('dose_history','Track doses I have taken',2),('refill_reminders','Know when to refill',3),('prescription_organization','Organize prescriptions',4),('family_support','Get family support',5);
commit;
