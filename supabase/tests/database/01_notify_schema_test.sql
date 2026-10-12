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
select tests.rls_enabled('public', 'profiles');
select tests.rls_enabled('public', 'routine_times');
select tests.rls_enabled('public', 'onboarding_questions');
select tests.rls_enabled('public', 'onboarding_answers');
select tests.rls_enabled('public', 'medication_schedules');
select tests.rls_enabled('public', 'schedule_slots');
select tests.rls_enabled('public', 'care_circle_members');
select tests.rls_enabled('public', 'care_circle_invites');

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
