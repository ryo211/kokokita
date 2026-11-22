-- ココキタ サーバー機能 フェーズ1 スキーマ
-- doc/server-feature-design.md 準拠。Supabaseプロジェクトの SQL Editor に貼り付けて実行する。
--
-- 前提: 実行前に Authentication > Sign In / Providers で
-- 「Anonymous Sign-ins」を有効にしておくこと。
--
-- 注意: このSQLは実際のSupabaseプロジェクトに対して未検証（ローカルに検証環境が無いため）。
-- 実行後、record_spot_arrival RPCを一度テスト呼び出しして動作確認すること。
--
-- 設計方針（placesを置かない理由）:
-- 同じ実在の場所（例: 姫路城）が複数コース（100名城／世界遺産）に登場しても、
-- コースごとに到達判定の半径が異なり、写真も「そのコースの文脈に合った写真」
-- （聖地巡礼ならアニメのシーンと同じアングル等）が求められるため、
-- 到達者数・「◯人目」・写真はすべて (course_id, spot_id) 単位で独立に扱う。
-- 場所の実体を正規化する places テーブルは意図的に作らない。
--
-- 簡略化した点（将来の課題）:
-- - courses/course_spots の正式なメタ情報は store_course/sync_courses_to_supabase.py で投入する。
--   未実行の間は、record_spot_arrival RPCが courses に title=course_id のダミー行を
--   source='official' で自動生成してフォールバックする。

-- =========================================
-- 1. users: auth.users を拡張するプロフィール的テーブル
-- =========================================
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  apple_linked boolean not null default false,
  deleted_at timestamptz
);

-- 匿名サインインを含め、新規ユーザー作成時に自動で public.users に行を作る
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================
-- 2. courses / course_spots
-- id は Course.rawId（例: "course-world-heritage-japan-001"）をそのまま使う
-- =========================================
create table public.courses (
  id text primary key,
  source text not null check (source in ('official', 'community')),
  owner_id uuid references public.users(id),
  title text not null default '',
  summary text,
  categories text[] not null default '{}',
  current_version integer not null default 1,
  status text not null default 'published' check (status in ('draft', 'published', 'unlisted', 'removed')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.course_spots (
  course_id text not null references public.courses(id) on delete cascade,
  spot_id text not null, -- CourseSpot.spotId（コース内で不変）
  name text not null default '',
  lat double precision,
  lng double precision,
  order_index integer not null default 0,
  primary key (course_id, spot_id)
);

-- =========================================
-- 3. spot_arrivals: 到達記録（追記型。端末で記録を削除しても集計からは消さない）
-- id は (visitId, spotId) から端末側で決定論的に導出したUUID。
-- 1件のVisit（GPS記録）が複数のコーススポットに同時該当することがあるため、
-- visitIdをそのままidにはできない（1visit:1spot前提だと取りこぼしが出る）
-- =========================================
create table public.spot_arrivals (
  id uuid primary key,
  visit_id uuid not null, -- 端末側の記録（Visit）のUUID。1つのvisit_idに複数行が対応しうる
  user_id uuid not null references public.users(id) on delete cascade,
  course_id text not null,
  spot_id text not null,
  arrived_at timestamptz not null,
  distance_m double precision,
  app_version text,
  -- 不正チェック（スポットとの距離・時刻・短時間の大量到達）に引っかかった記録はfalseにし、集計から除外する
  is_valid boolean not null default true,
  created_at timestamptz not null default now()
);

-- 到達者数・順位の集計は (course_id, spot_id) 単位で行うため、ここにインデックスを張る
create index spot_arrivals_course_spot_idx on public.spot_arrivals (course_id, spot_id);
create index spot_arrivals_user_idx on public.spot_arrivals (user_id);
create index spot_arrivals_visit_idx on public.spot_arrivals (visit_id);

-- =========================================
-- 4. course_events: コースへの関心度イベント（閲覧・お気に入り追加等。送信は CourseEventSyncService が行う）
-- =========================================
-- idはクライアント側で(courseId, type, eventDay)から決定論的に導出する。
-- 起動時フラッシュの競合で同じイベントが2回送信されても、on_conflict=idで
-- 重複挿入されないようにするための冪等キー（spot_arrivals.idと同じ考え方）
create table public.course_events (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  course_id text not null,
  version integer not null,
  type text not null default 'view',
  at timestamptz not null default now()
);

-- =========================================
-- RLS（Row Level Security）
-- =========================================
alter table public.users enable row level security;
alter table public.courses enable row level security;
alter table public.course_spots enable row level security;
alter table public.spot_arrivals enable row level security;
alter table public.course_events enable row level security;

create policy "本人のみ自分のプロフィールを参照できる"
  on public.users for select using (auth.uid() = id);
create policy "本人のみ自分のプロフィールを更新できる"
  on public.users for update using (auth.uid() = id);

create policy "匿名ユーザーを含め全員が公開コースを参照できる"
  on public.courses for select using (status = 'published');
create policy "匿名ユーザーを含め全員が course_spots を参照できる"
  on public.course_spots for select using (true);

create policy "本人の到達記録のみ参照できる"
  on public.spot_arrivals for select using (auth.uid() = user_id);
create policy "本人の到達記録のみ挿入できる"
  on public.spot_arrivals for insert with check (auth.uid() = user_id);
create policy "本人の到達記録のみ削除できる"
  on public.spot_arrivals for delete using (auth.uid() = user_id);

-- SELECTポリシーが無いと、on_conflict=idでのUPSERT（重複無視）が既存行の有無を
-- 確認できずRLS違反になる（PostgreSQL/PostgRESTの既知の挙動）ため、挿入・削除に加えて必須
create policy "本人の閲覧イベントのみ参照できる"
  on public.course_events for select using (auth.uid() = user_id);
create policy "本人の閲覧イベントのみ挿入できる"
  on public.course_events for insert with check (auth.uid() = user_id);
create policy "本人の閲覧イベントのみ削除できる"
  on public.course_events for delete using (auth.uid() = user_id);

-- =========================================
-- 5. RPC: 到達記録を登録し、その場で「◯人目」の順位を返す
-- クライアントは spot_arrivals へ直接INSERTせず、必ずこのRPCを呼ぶ
-- （courses暫定行の作成・順位計算をアトミックに行うため）
-- =========================================
create or replace function public.record_spot_arrival(
  p_id uuid,
  p_visit_id uuid,
  p_course_id text,
  p_spot_id text,
  p_arrived_at timestamptz,
  p_distance_m double precision,
  p_app_version text
)
returns table (rank bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  -- courses にメタ情報が無い場合の暫定行（ビルドスクリプト未実行時のフォールバック）。
  -- spot_arrivalsはcoursesへの外部キーを持たないため必須ではないが、分析用に行を揃えておく
  insert into public.courses (id, source, title)
  values (p_course_id, 'official', p_course_id)
  on conflict (id) do nothing;

  insert into public.spot_arrivals (id, visit_id, user_id, course_id, spot_id, arrived_at, distance_m, app_version)
  values (p_id, p_visit_id, v_user_id, p_course_id, p_spot_id, p_arrived_at, p_distance_m, p_app_version)
  on conflict (id) do nothing;

  -- 順位 = 同じ(course_id, spot_id)への、このユーザーの最初の到達時刻以前に到達した、重複のないユーザー数
  -- （再訪問しても順位は変わらない。削除された記録も集計からは消さない設計のため参照し続ける）
  return query
  select count(distinct sa.user_id)
  from public.spot_arrivals sa
  where sa.course_id = p_course_id
    and sa.spot_id = p_spot_id
    and sa.is_valid
    and sa.arrived_at <= (
      select min(sa2.arrived_at)
      from public.spot_arrivals sa2
      where sa2.course_id = p_course_id and sa2.spot_id = p_spot_id
        and sa2.user_id = v_user_id and sa2.is_valid
    );
end;
$$;

grant execute on function public.record_spot_arrival to anon, authenticated;

-- =========================================
-- 6. RPC: 設定画面「サーバーのデータを削除」用。
-- 本人の到達記録・閲覧イベントを削除する（アカウント自体は削除しない。P1時点の仕様）
-- =========================================
create or replace function public.delete_my_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  delete from public.spot_arrivals where user_id = v_user_id;
  delete from public.course_events where user_id = v_user_id;
end;
$$;

grant execute on function public.delete_my_data to anon, authenticated;

-- =========================================
-- 8. RPC: 集計バッチ（Lambda）用。コース・スポットごとの集計を
-- doc/server-feature-design.md の stats.json 形式そのままで返す。
-- 全ユーザー横断の集計（RLSで通常は不可能）をsecurity definerで行うが、
-- 返す内容は集計済みの数値のみなので anon キーで呼んで問題ない
-- （service_roleキーをLambdaに持たせる必要が無い）
-- =========================================
create or replace function public.compute_course_stats(p_min_display_count integer default 10)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  return (
    with course_totals as (
      select course_id, count(*) as total_spots
      from public.course_spots
      group by course_id
    ),
    user_spot_counts as (
      select course_id, user_id, count(distinct spot_id) as visited_spots
      from public.spot_arrivals
      where is_valid
      group by course_id, user_id
    ),
    challenger_counts as (
      select course_id, count(distinct user_id) as challenger_count
      from public.spot_arrivals
      where is_valid
      group by course_id
    ),
    completed_counts as (
      select usc.course_id, count(*) as completed_count
      from user_spot_counts usc
      join course_totals ct on ct.course_id = usc.course_id
      where usc.visited_spots >= ct.total_spots
      group by usc.course_id
    ),
    spot_counts as (
      select course_id, spot_id, count(distinct user_id) as arrival_count
      from public.spot_arrivals
      where is_valid
      group by course_id, spot_id
    ),
    course_json as (
      select
        cc.course_id,
        jsonb_build_object(
          'challengerCount', cc.challenger_count,
          'completedCount', coalesce(comp.completed_count, 0),
          'spots', (
            select coalesce(jsonb_object_agg(sc.spot_id, jsonb_build_object('arrivalCount', sc.arrival_count)), '{}'::jsonb)
            from spot_counts sc
            where sc.course_id = cc.course_id and sc.arrival_count >= p_min_display_count
          )
        ) as stats
      from challenger_counts cc
      left join completed_counts comp on comp.course_id = cc.course_id
      where cc.challenger_count >= p_min_display_count
    )
    select jsonb_build_object(
      'schemaVersion', 1,
      'generatedAt', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'minDisplayCount', p_min_display_count,
      'courses', coalesce((select jsonb_object_agg(course_id, stats) from course_json), '{}'::jsonb)
    )
  );
end;
$$;

grant execute on function public.compute_course_stats to anon, authenticated;
