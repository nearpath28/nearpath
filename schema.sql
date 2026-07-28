-- NearPath Tutors — database schema for Supabase
-- Run this once in your Supabase project's SQL Editor (see README.md).

-- 1) profiles: one row per signed-up user (student or teacher)
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('student','teacher')),
  full_name text not null,
  created_at timestamptz not null default now()
);

-- 2) teacher_profiles: the public listing data for a teacher
create table teacher_profiles (
  profile_id uuid primary key references profiles(id) on delete cascade,
  initials text,
  color text default '#6C5CE7',
  category text default 'academics',
  subjects text[] default '{}',
  location text default '',
  distance text default '',
  fee_start int default 0,
  fee_unit text default '/month',
  experience text default '',
  bio text default '',
  rating numeric default 5,
  reviews int default 0
);

-- 3) schedule_slots: a teacher's weekly timing slots
create table schedule_slots (
  id bigserial primary key,
  teacher_id uuid not null references teacher_profiles(profile_id) on delete cascade,
  day text not null,
  time text not null,
  subj text not null
);

-- 4) enquiries: messages a student sends to a teacher
create table enquiries (
  id bigserial primary key,
  teacher_id uuid not null references teacher_profiles(profile_id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

-- 5) enrollments: a student enrolled with a teacher for a subject
create table enrollments (
  id bigserial primary key,
  student_id uuid not null references profiles(id) on delete cascade,
  teacher_id uuid not null references teacher_profiles(profile_id) on delete cascade,
  subject text not null,
  schedule text default '',
  fee int default 0,
  status text not null default 'due' check (status in ('due','overdue','paid')),
  due_date date,
  grade text,
  created_at timestamptz not null default now()
);

-- 6) payments: a record each time fees are marked paid
create table payments (
  id bigserial primary key,
  enrollment_id bigint references enrollments(id) on delete set null,
  student_id uuid not null references profiles(id) on delete cascade,
  amount int not null,
  method text default 'UPI',
  paid_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- Row Level Security: lock every table down, then open specific,
-- narrow policies. Without this, the anon key can read/write anything.
-- ---------------------------------------------------------------
alter table profiles enable row level security;
alter table teacher_profiles enable row level security;
alter table schedule_slots enable row level security;
alter table enquiries enable row level security;
alter table enrollments enable row level security;
alter table payments enable row level security;

-- profiles: names are shown publicly (e.g. "with Ritu Sharma"), but only
-- the owner can create/change their own row.
create policy "profiles are publicly readable" on profiles for select using (true);
create policy "users can insert their own profile" on profiles for insert with check (auth.uid() = id);
create policy "users can update their own profile" on profiles for update using (auth.uid() = id);

-- teacher_profiles: the whole point is to be a public directory.
create policy "teacher profiles are publicly readable" on teacher_profiles for select using (true);
create policy "teachers can insert their own listing" on teacher_profiles for insert with check (auth.uid() = profile_id);
create policy "teachers can update their own listing" on teacher_profiles for update using (auth.uid() = profile_id);

-- schedule_slots: public to read (shown on profile pages), owner-only to edit.
create policy "schedule is publicly readable" on schedule_slots for select using (true);
create policy "teachers manage their own schedule" on schedule_slots for all using (auth.uid() = teacher_id) with check (auth.uid() = teacher_id);

-- enquiries: only visible to the two people involved.
create policy "enquiry visible to sender or recipient" on enquiries for select using (auth.uid() = teacher_id or auth.uid() = student_id);
create policy "students can send enquiries" on enquiries for insert with check (auth.uid() = student_id);

-- enrollments: only visible to the student and their teacher.
create policy "enrollment visible to student or teacher" on enrollments for select using (auth.uid() = student_id or auth.uid() = teacher_id);
create policy "students can enroll themselves" on enrollments for insert with check (auth.uid() = student_id);
create policy "student or teacher can update an enrollment" on enrollments for update using (auth.uid() = student_id or auth.uid() = teacher_id);

-- payments: only the paying student can see or create their own payment records.
create policy "payments visible to the paying student" on payments for select using (auth.uid() = student_id);
create policy "students can record their own payments" on payments for insert with check (auth.uid() = student_id);
