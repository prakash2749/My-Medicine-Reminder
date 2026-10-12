begin;
select plan(19);

-- 1. Test presence of all 8 MVP tables
select has_table('public', 'profiles', 'public.profiles table should exist');
select has_table('public', 'routine_times', 'public.routine_times table should exist');
select has_table('public', 'onboarding_questions', 'public.onboarding_questions table should exist');
select has_table('public', 'onboarding_answers', 'public.onboarding_answers table should exist');
select has_table('public', 'medication_schedules', 'public.medication_schedules table should exist');
select has_table('public', 'schedule_slots', 'public.schedule_slots table should exist');
select has_table('public', 'care_circle_members', 'public.care_circle_members table should exist');
select has_table('public', 'care_circle_invites', 'public.care_circle_invites table should exist');

-- 2. Test Row Level Security (RLS) is enabled on all tables
select results_eq(
    $$select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'profiles'$$,
    ARRAY[true],
    'RLS should be enabled on public.profiles'
);
select results_eq(
    $$select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'routine_times'$$,
    ARRAY[true],
    'RLS should be enabled on public.routine_times'
);
select results_eq(
    $$select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'onboarding_questions'$$,
    ARRAY[true],
    'RLS should be enabled on public.onboarding_questions'
);
select results_eq(
    $$select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'onboarding_answers'$$,
    ARRAY[true],
    'RLS should be enabled on public.onboarding_answers'
);
select results_eq(
    $$select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'medication_schedules'$$,
    ARRAY[true],
    'RLS should be enabled on public.medication_schedules'
);
select results_eq(
    $$select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'schedule_slots'$$,
    ARRAY[true],
    'RLS should be enabled on public.schedule_slots'
);
select results_eq(
    $$select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'care_circle_members'$$,
    ARRAY[true],
    'RLS should be enabled on public.care_circle_members'
);
select results_eq(
    $$select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'care_circle_invites'$$,
    ARRAY[true],
    'RLS should be enabled on public.care_circle_invites'
);

-- 3. Verify onboarding_questions seed rows (5 questions)
select results_eq(
    'select count(*)::integer from public.onboarding_questions',
    ARRAY[5],
    'onboarding_questions should contain 5 seed items'
);

-- 4. Verify trigger exists on care_circle_members
select has_trigger('public', 'care_circle_members', 'cc_member_touch', 'cc_member_touch trigger should exist');

-- 5. Verify function cc_touch_updated_at exists
select has_function('public', 'cc_touch_updated_at', 'cc_touch_updated_at function should exist');

select * from finish();
rollback;
