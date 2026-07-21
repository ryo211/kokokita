"""
kokokita コース管理 API Lambda ハンドラー

エンドポイント:
  POST /presigned-url   … S3 アップロード用の presigned URL を生成
  POST /complete-upload … 画像アップロード完了処理（ドラフト JSON を更新）
  POST /get-draft       … ドラフト JSON を取得（なければ null）
  POST /publish         … ドラフトを本番に適用（バージョンインクリメント）

S3 パス構成:
  本番 JSON : course/{courseJsonPath}         例: course/courses/xxx.json
  ドラフト  : course/drafts/{courseJsonPath}  例: course/drafts/courses/xxx.json
  画像      : course/images/{type}/{id}.jpg
"""

import hmac
import json
import os
import uuid
import traceback
from datetime import datetime, timezone

import boto3

# ─────────────────────────────────────────────────────────────────────────────
# 設定
# ─────────────────────────────────────────────────────────────────────────────
BUCKET         = os.environ.get('S3_BUCKET',     'kokokita-resources')
CF_DIST_ID     = os.environ.get('CF_DIST_ID',    '')
BASE_CDN_URL   = os.environ.get('BASE_CDN_URL',  'https://kokokita-app.irodoriq.com/course')
ALLOWED_ORIGIN = os.environ.get('ALLOWED_ORIGIN', '*')
ADMIN_SECRET   = os.environ.get('ADMIN_SECRET',  '')

s3_client = boto3.client('s3')
cf_client = boto3.client('cloudfront')


# ─────────────────────────────────────────────────────────────────────────────
# ヘルパー
# ─────────────────────────────────────────────────────────────────────────────
def resp_headers():
    # CORS ヘッダーは Lambda Function URL が自動付与するため Content-Type のみ
    return {'Content-Type': 'application/json; charset=utf-8'}

def ok(body):
    return {'statusCode': 200, 'headers': resp_headers(),
            'body': json.dumps(body, ensure_ascii=False)}

def err(status, msg):
    return {'statusCode': status, 'headers': resp_headers(),
            'body': json.dumps({'error': msg}, ensure_ascii=False)}

def calc_spot_stats(data):
    """コース JSON からスポット数・画像設定済みスポット数を返す。"""
    secs  = data.get('sections', [])
    spots = (
        [sp for s in secs for sp in s.get('spots', [])]
        if secs else data.get('spots', [])
    )
    spot_count     = len(spots)
    spot_img_count = sum(1 for sp in spots if sp.get('coverImageUrl'))
    return spot_count, spot_img_count

def s3_get_json(key):
    """S3 から JSON を読み込む。存在しなければ None を返す。"""
    try:
        obj = s3_client.get_object(Bucket=BUCKET, Key=key)
        return json.loads(obj['Body'].read().decode('utf-8'))
    except s3_client.exceptions.NoSuchKey:
        return None

def s3_put_json(key, data):
    """S3 に JSON を書き込む。"""
    s3_client.put_object(
        Bucket=BUCKET, Key=key,
        Body=json.dumps(data, ensure_ascii=False, indent=2).encode('utf-8'),
        ContentType='application/json; charset=utf-8',
    )

def cf_invalidate(paths):
    """CloudFront キャッシュを無効化する。失敗しても例外を投げない。"""
    if not CF_DIST_ID or not paths:
        return None
    try:
        resp = cf_client.create_invalidation(
            DistributionId=CF_DIST_ID,
            InvalidationBatch={
                'Paths': {'Quantity': len(paths), 'Items': paths},
                'CallerReference': str(uuid.uuid4()),
            }
        )
        inv_id = resp['Invalidation']['Id']
        print(f'[INFO] CF無効化: {inv_id} {paths}')
        return inv_id
    except Exception as e:
        print(f'[WARN] CF無効化失敗: {e}')
        return None


# ─────────────────────────────────────────────────────────────────────────────
# エントリポイント
# ─────────────────────────────────────────────────────────────────────────────
def lambda_handler(event, context):
    method = (
        event.get('httpMethod') or
        event.get('requestContext', {}).get('http', {}).get('method', 'POST')
    )
    path    = event.get('rawPath') or event.get('path', '')
    headers = {k.lower(): v for k, v in (event.get('headers') or {}).items()}

    # 秘密トークン検証（タイミング攻撃対策に hmac.compare_digest を使用）
    if ADMIN_SECRET:
        if not hmac.compare_digest(headers.get('x-admin-secret', ''), ADMIN_SECRET):
            print(f'[WARN] 認証失敗: path={path}')
            return err(403, '認証に失敗しました')

    try:
        body = json.loads(event.get('body') or '{}')
    except json.JSONDecodeError:
        return err(400, 'リクエストボディが不正です')

    try:
        if   '/presigned-url'   in path: return handle_presigned_url(body)
        elif '/complete-upload' in path: return handle_complete_upload(body)
        elif '/upload-json'     in path: return handle_upload_json(body)
        elif '/get-draft'       in path: return handle_get_draft(body)
        elif '/publish'         in path: return handle_publish(body)
        elif '/delete-course'   in path: return handle_delete_course(body)
        elif '/list-drafts'    in path: return handle_list_drafts(body)
        else: return err(404, 'Not found')
    except Exception as e:
        print(f'[ERROR] {e}')
        traceback.print_exc()
        return err(500, str(e))


# ─────────────────────────────────────────────────────────────────────────────
# POST /presigned-url
# S3 直接アップロード用の presigned URL を生成する
# ─────────────────────────────────────────────────────────────────────────────
def handle_presigned_url(body):
    img_type = body.get('type')    # 'course' | 'spot'
    image_id = body.get('imageId') # 拡張子なしファイル名

    if not img_type or not image_id:
        return err(400, 'type と imageId が必要です')
    if img_type not in ('course', 'spot'):
        return err(400, 'type は course か spot である必要があります')

    s3_key     = f'course/images/{img_type}/{image_id}.jpg'
    public_url = f'{BASE_CDN_URL}/images/{img_type}/{image_id}.jpg'

    upload_url = s3_client.generate_presigned_url(
        'put_object',
        Params={'Bucket': BUCKET, 'Key': s3_key, 'ContentType': 'image/jpeg'},
        ExpiresIn=300,
    )
    return ok({'uploadUrl': upload_url, 'publicUrl': public_url,
               'cfPath': f'/course/images/{img_type}/{image_id}.jpg', 's3Key': s3_key})


# ─────────────────────────────────────────────────────────────────────────────
# POST /complete-upload
# S3 画像アップロード完了後の処理。
# 本番 JSON は触らず、ドラフト JSON のみ更新する。
# ─────────────────────────────────────────────────────────────────────────────
def handle_complete_upload(body):
    img_type         = body.get('type')
    image_id         = body.get('imageId')
    course_json_path = body.get('courseJsonPath')
    spot_id          = body.get('spotId')
    image_credit     = body.get('imageCredit')  # Wikimedia クレジット（任意）

    if not img_type or not image_id or not course_json_path:
        return err(400, 'type, imageId, courseJsonPath が必要です')

    public_url = f'{BASE_CDN_URL}/images/{img_type}/{image_id}.jpg'
    draft_key  = f'course/drafts/{course_json_path}'
    live_key   = f'course/{course_json_path}'
    draft_updated = False

    try:
        # ドラフトがあればドラフトを、なければ本番をベースにする
        data = s3_get_json(draft_key) or s3_get_json(live_key)
        if data is None:
            raise FileNotFoundError(f'JSON が見つかりません: {live_key}')

        if img_type == 'course':
            data['coverImageUrl'] = public_url
            if image_credit:
                data['imageCredit'] = image_credit
            elif 'imageCredit' in data:
                del data['imageCredit']  # 手動アップロード時はクレジットをクリア
            draft_updated = True
        elif img_type == 'spot' and spot_id:
            for section in data.get('sections', []):
                for spot in section.get('spots', []):
                    if spot.get('spotId') == spot_id:
                        spot['coverImageUrl'] = public_url
                        if image_credit:
                            spot['imageCredit'] = image_credit
                        elif 'imageCredit' in spot:
                            del spot['imageCredit']  # 手動アップロード時はクレジットをクリア
                        draft_updated = True
            if not draft_updated:
                for spot in data.get('spots', []):
                    if spot.get('spotId') == spot_id:
                        spot['coverImageUrl'] = public_url
                        if image_credit:
                            spot['imageCredit'] = image_credit
                        elif 'imageCredit' in spot:
                            del spot['imageCredit']
                        draft_updated = True

        if draft_updated:
            s3_put_json(draft_key, data)
            print(f'[INFO] ドラフト更新: {draft_key}')

    except Exception as e:
        print(f'[WARN] ドラフト更新スキップ: {e}')

    # 画像の CF キャッシュのみクリア（JSON は本番未更新のためクリア不要）
    cf_paths = [f'/course/images/{img_type}/{image_id}.jpg']
    invalidation_id = cf_invalidate(cf_paths)

    return ok({'success': True, 'publicUrl': public_url,
               'draftUpdated': draft_updated,
               'invalidationId': invalidation_id, 'invalidatedPaths': cf_paths})


# ─────────────────────────────────────────────────────────────────────────────
# POST /upload-json
# コース JSON をドラフトとして S3 に保存する。
# 本番 JSON は触らず、ドラフット JSON のみ書き込む。
# ─────────────────────────────────────────────────────────────────────────────
def handle_upload_json(body):
    course_json_path = body.get('courseJsonPath')
    json_data        = body.get('jsonData')

    if not course_json_path or json_data is None:
        return err(400, 'courseJsonPath と jsonData が必要です')
    if not isinstance(json_data, dict):
        return err(400, 'jsonData はオブジェクト型である必要があります')
    if not json_data.get('id') or not json_data.get('title'):
        return err(400, 'jsonData に id と title フィールドが必要です')

    draft_key = f'course/drafts/{course_json_path}'
    s3_put_json(draft_key, json_data)
    print(f'[INFO] JSON ドラフット保存: {draft_key}')

    return ok({'success': True, 'draftKey': draft_key})


# ─────────────────────────────────────────────────────────────────────────────
# POST /get-draft
# ドラフト JSON を返す。存在しなければ { exists: false, draft: null } を返す。
# ─────────────────────────────────────────────────────────────────────────────
def handle_get_draft(body):
    course_json_path = body.get('courseJsonPath')
    if not course_json_path:
        return err(400, 'courseJsonPath が必要です')

    draft = s3_get_json(f'course/drafts/{course_json_path}')
    return ok({'exists': draft is not None, 'draft': draft})


# ─────────────────────────────────────────────────────────────────────────────
# POST /publish
# ドラフトを本番 JSON に上書きし、バージョンをインクリメントする。
# store/index.json も更新し、CF キャッシュをクリアする。
# ─────────────────────────────────────────────────────────────────────────────
def handle_publish(body):
    course_json_path = body.get('courseJsonPath')
    course_id        = body.get('courseId')

    if not course_json_path:
        return err(400, 'courseJsonPath が必要です')

    draft_key = f'course/drafts/{course_json_path}'
    live_key  = f'course/{course_json_path}'

    # ドラフトを読み込む
    draft_data = s3_get_json(draft_key)
    if draft_data is None:
        return err(404, 'ドラフトが存在しません')

    # 本番のバージョンを読んでインクリメント
    live_data   = s3_get_json(live_key) or {}
    new_version = live_data.get('version', 0) + 1
    draft_data['version'] = new_version

    # ドラフトを本番 JSON に上書き
    s3_put_json(live_key, draft_data)
    print(f'[INFO] 本番適用: {live_key} version={new_version}')

    # ドラフトを削除
    s3_client.delete_object(Bucket=BUCKET, Key=draft_key)
    print(f'[INFO] ドラフト削除: {draft_key}')

    cf_paths = [f'/course/{course_json_path}']

    # store/index.json を更新（既存コースは更新、新規コースはエントリを追加）
    try:
        store_key  = 'course/store/index.json'
        store_data = s3_get_json(store_key) or {}
        now        = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        courses    = store_data.setdefault('courses', [])
        spot_count, spot_img_count = calc_spot_stats(draft_data)
        entry_found = False
        for c in courses:
            if c.get('jsonPath') == course_json_path:
                c['version']       = new_version
                c['title']         = draft_data.get('title', c.get('title', ''))
                c['summary']       = draft_data.get('summary', c.get('summary', ''))
                c['categories']    = draft_data.get('categories', c.get('categories', []))
                c['coverImageUrl'] = draft_data.get('coverImageUrl')
                c['spotCount']     = spot_count
                c['spotImgCount']  = spot_img_count
                c['updatedAt']     = now
                entry_found = True
                break
        if not entry_found:
            # 新規コース: store/index.json にエントリを追加
            courses.append({
                'id':           draft_data.get('id', ''),
                'title':        draft_data.get('title', ''),
                'summary':      draft_data.get('summary', ''),
                'categories':   draft_data.get('categories', []),
                'version':      new_version,
                'coverImageUrl': draft_data.get('coverImageUrl'),
                'spotCount':    spot_count,
                'spotImgCount': spot_img_count,
                'jsonPath':     course_json_path,
                'updatedAt':    now,
            })
            print(f'[INFO] store/index.json 新規追加: {course_json_path}')
        store_data['generatedAt'] = now
        s3_put_json(store_key, store_data)
        cf_paths.append('/course/store/index.json')
        print(f'[INFO] store/index.json 更新 version={new_version}')
    except Exception as e:
        print(f'[WARN] store/index.json 更新スキップ: {e}')

    invalidation_id = cf_invalidate(cf_paths)

    return ok({'success': True, 'newVersion': new_version,
               'invalidationId': invalidation_id, 'invalidatedPaths': cf_paths})


# ─────────────────────────────────────────────────────────────────────────────
# POST /delete-course
# 本番 JSON・ドラフット JSON を削除し、store/index.json のエントリを除去する。
# ─────────────────────────────────────────────────────────────────────────────
def handle_delete_course(body):
    course_json_path = body.get('courseJsonPath')
    if not course_json_path:
        return err(400, 'courseJsonPath が必要です')

    live_key  = f'course/{course_json_path}'
    draft_key = f'course/drafts/{course_json_path}'

    # 本番 JSON 削除
    try:
        s3_client.delete_object(Bucket=BUCKET, Key=live_key)
        print(f'[INFO] 本番 JSON 削除: {live_key}')
    except Exception as e:
        print(f'[WARN] 本番 JSON 削除スキップ: {e}')

    # ドラフット JSON 削除（存在すれば）
    try:
        s3_client.delete_object(Bucket=BUCKET, Key=draft_key)
        print(f'[INFO] ドラフット JSON 削除: {draft_key}')
    except Exception as e:
        print(f'[WARN] ドラフット JSON 削除スキップ: {e}')

    # store/index.json からエントリを削除
    cf_paths = [f'/course/{course_json_path}']
    try:
        store_key  = 'course/store/index.json'
        store_data = s3_get_json(store_key) or {}
        before     = len(store_data.get('courses', []))
        store_data['courses'] = [
            c for c in store_data.get('courses', [])
            if c.get('jsonPath') != course_json_path
        ]
        store_data['generatedAt'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        s3_put_json(store_key, store_data)
        cf_paths.append('/course/store/index.json')
        print(f'[INFO] store/index.json からコース削除: {course_json_path} ({before}→{len(store_data["courses"])}件)')
    except Exception as e:
        print(f'[WARN] store/index.json 更新スキップ: {e}')

    invalidation_id = cf_invalidate(cf_paths)

    return ok({'success': True, 'invalidationId': invalidation_id, 'invalidatedPaths': cf_paths})


# ─────────────────────────────────────────────────────────────────────────────
# POST /list-drafts
# course/drafts/ 以下のすべてのドラフット JSON を列挙し、メタデータを返す。
# store/index.json に存在しないドラフットには isNew: true を付ける。
# ─────────────────────────────────────────────────────────────────────────────
def handle_list_drafts(body):
    prefix = 'course/drafts/'

    # store/index.json から既存コースのパスセットを取得
    store_data     = s3_get_json('course/store/index.json') or {}
    existing_paths = {c.get('jsonPath') for c in store_data.get('courses', [])}

    try:
        resp = s3_client.list_objects_v2(Bucket=BUCKET, Prefix=prefix)
    except Exception as e:
        print(f'[WARN] ドラフット一覧取得失敗: {e}')
        return ok({'drafts': []})

    drafts = []
    for obj in resp.get('Contents', []):
        key              = obj['Key']
        course_json_path = key[len(prefix):]
        if not course_json_path.endswith('.json'):
            continue
        try:
            data = s3_get_json(key)
            if not data:
                continue
            spot_count, spot_img_count = calc_spot_stats(data)
            drafts.append({
                'courseJsonPath': course_json_path,
                'id':            data.get('id', ''),
                'title':         data.get('title', ''),
                'summary':       data.get('summary', ''),
                'categories':    data.get('categories', []),
                'version':       data.get('version', 0),
                'coverImageUrl': data.get('coverImageUrl'),
                'spotCount':     spot_count,
                'spotImgCount':  spot_img_count,
                'isNew':         course_json_path not in existing_paths,
            })
        except Exception as e:
            print(f'[WARN] ドラフット読み込みスキップ: {key}: {e}')

    return ok({'drafts': drafts})
