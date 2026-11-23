-- ココキタ コース管理画面 統計表示用RPC
-- doc/features/server/phase1_schema.sql 適用後に、Supabaseプロジェクトの SQL Editor に
-- 追加で貼り付けて実行する（phase1_schema.sqlの一部ではなく、後から追加した関数）。
--
-- 用途: tools/course-admin/lambda/handler.py の /stats エンドポイントが、
-- 管理画面（到達人数・お気に入り数・閲覧数の表示）のために呼び出す。
--
-- compute_course_stats（本番のstats.json用。min_display_countで閾値フィルタあり）とは別に、
-- 管理者だけが見る生の集計値を、閾値なし・全コース・全ステータス（draft/removedも含む）で返す。
-- 件数のみでユーザーの個人情報を含まないが、anon/authenticatedには公開しない
-- （service_roleキーを持つLambda経由でのみ呼び出す）。

create or replace function public.compute_admin_stats()
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
    spot_arrival_counts as (
      select course_id, spot_id, count(distinct user_id) as arrival_count
      from public.spot_arrivals
      where is_valid
      group by course_id, spot_id
    ),
    -- course_eventsはspot_idがnullならコース単位イベント、非nullならスポット単位イベント
    course_view_counts as (
      select course_id, count(*) as view_count
      from public.course_events
      where type = 'view' and spot_id is null
      group by course_id
    ),
    course_favorite_counts as (
      select course_id, count(*) as favorite_count
      from public.course_events
      where type = 'favorite_add' and spot_id is null
      group by course_id
    ),
    spot_favorite_counts as (
      select course_id, spot_id, count(*) as favorite_count
      from public.course_events
      where type = 'favorite_add' and spot_id is not null
      group by course_id, spot_id
    ),
    courses_json as (
      select
        c.id as course_id,
        jsonb_build_object(
          'title',           c.title,
          'status',          c.status,
          'challengerCount', coalesce(cc.challenger_count, 0),
          'completedCount',  coalesce(comp.completed_count, 0),
          'viewCount',       coalesce(cvc.view_count, 0),
          'favoriteCount',   coalesce(cfc.favorite_count, 0),
          'spots', (
            select coalesce(jsonb_object_agg(
              cs.spot_id,
              jsonb_build_object(
                'name',          cs.name,
                'arrivalCount',  coalesce(sac.arrival_count, 0),
                'favoriteCount', coalesce(sfc.favorite_count, 0)
              )
            ), '{}'::jsonb)
            from public.course_spots cs
            left join spot_arrival_counts sac
              on sac.course_id = cs.course_id and sac.spot_id = cs.spot_id
            left join spot_favorite_counts sfc
              on sfc.course_id = cs.course_id and sfc.spot_id = cs.spot_id
            where cs.course_id = c.id
          )
        ) as stats
      from public.courses c
      left join challenger_counts cc     on cc.course_id = c.id
      left join completed_counts comp    on comp.course_id = c.id
      left join course_view_counts cvc   on cvc.course_id = c.id
      left join course_favorite_counts cfc on cfc.course_id = c.id
    )
    select jsonb_build_object(
      'generatedAt', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'courses', coalesce((select jsonb_object_agg(course_id, stats) from courses_json), '{}'::jsonb)
    )
  );
end;
$$;

-- anon/authenticatedには公開しない（他のRPCと異なり管理者専用）。
-- service_roleはRLS同様に関数の実行権限も通常バイパスするが、明示的にも許可しておく
grant execute on function public.compute_admin_stats to service_role;
