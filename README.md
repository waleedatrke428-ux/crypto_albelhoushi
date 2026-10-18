# دليل مشروع منصة التوصيات الذكية 🚀

هذا المستند يمثل المرجع الكامل لأكواد وإعدادات مشروعك الموزع بين قاعدة بيانات Supabase وواجهات المستخدم والمدير على GitHub Pages.

---

## 1. هيكل قاعدة البيانات (Supabase - SQL)
تم إنشاء جدول `profiles` لتتبع بيانات المستخدمين وفترتهم التجريبية والاشتراكات، إلى جانب جدول `trades` الخاص بالتوصيات:

```sql
-- جدول المستخدمين والاشتراكات
create table public.profiles (
  id uuid not null references auth.users on delete cascade primary key,
  email text not null,
  country text default 'غير محدد',
  trial_ends_at timestamp with time zone default (now() + interval '5 days'),
  is_subscribed boolean default false,
  created_at timestamp with time zone default now()
);

-- سياسات الأمان
alter table public.profiles enable row level security;
create policy "Enable insert for users based on user_id" on public.profiles for insert with check (true);
create policy "Enable select for users" on public.profiles for select using (true);
create policy "Enable update for users" on public.profiles for update using (true);