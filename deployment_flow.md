# AutoDevOps-Agent デプロイ及びシステム連携フロー

このドキュメントは、バックエンド（Python）とフロントエンド（Flutter）をクラウド環境に統合・デプロイするためのロードマップをまとめています。

---

## 🛠️ デプロイ前の事前準備（ローカルでのすり合わせ）

実際にデプロイする前に、バックエンドとフロントエンドが正しく疎通できるよう、以下の2点をローカルで修正・準備します。

### 1. Firestore コレクション・スキーマの統一
現在、バックエンドとフロントエンドで参照しているコレクション名とフィールド名にズレがあります。これを統一します。

* **推奨方針**: コレクション名を `auto_fixes` に統一し、以下の共通スキーマを使用します。
```json
{
  "id": "string (自動生成UUID)",
  "status": "'pending' | 'analyzing' | 'fixing' | 'waiting_approval' | 'approved' | 'completed' | 'failed'",
  "error_message": "string (検知したエラーログ)",
  "trigger_source": "string ('cloud_logging' | 'github_actions'など)",
  "repository": "string (リポジトリ名)",
  "base_branch": "string (対象ブランチ, e.g., 'main')",
  "bug_branch": "string (AIが切った修正ブランチ名)",
  "pr_url": "string (作成されたPRのURL)",
  "diff": "string (AIが生成したコード差分)",
  "thoughts": "array [string] (AIの思考ログ履歴)",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

### 2. Firebase 構成ファイルの配置
Flutterアプリを実際のGCP/Firebaseプロジェクト（`project-20179432-3457-4d7f-9c5`）に接続するため、Firebaseコンソールからダウンロードした設定ファイルを指定のパスに配置します。
* **Android**: `frontend_flutter/android/app/google-services.json`
* **macOS**: `frontend_flutter/macos/Runner/GoogleService-Info.plist`
* **iOS**: `frontend_flutter/ios/Runner/GoogleService-Info.plist`

---

## 🚀 クラウド環境へのデプロイ手順

### ステップ 1: Firestore セキュリティルールの適用
プロジェクトのルートにある `firestore.rules` をFirebase上にデプロイします。
```bash
# ルールのデプロイ
npx -y firebase-tools@latest deploy --only firestore:rules
```

### ステップ 2: バックエンド（Cloud Functions）のデプロイ
現在ローカルで動いている `pipeline.py` を Cloud Functions (HTTPトリガー、またはログ検知用Pub/Subトリガー) にデプロイし、GCP上で自律動作させます。
```bash
# gcloudコマンド等によるCloud Functionsデプロイ
gcloud functions deploy autodevops-pipeline \
  --runtime=python310 \
  --trigger-http \
  --entry-point=main \
  --region=asia-northeast1
```

### ステップ 3: フロントエンド（Flutter）のビルド・デプロイ
ダッシュボード画面（Flutter Web）を Firebase Hosting 等にホストし、ブラウザからアクセスできるようにします。
```bash
# Web用にビルド
cd frontend_flutter
flutter build web

# Firebase Hostingへのデプロイ（設定を追加した場合）
npx -y firebase-tools@latest deploy --only hosting
```

---

## 🔒 本番環境（Production）公開前の必須タスク（Phase 4）

検証環境での疎通確認が完了した後、本番運用のために以下の「本番品質化」タスクを行い、再度デプロイします。
1. **サーキットブレーカーの実装**:
   - AIがバグの自動修正ループに入り、API課金や大量PR作成が止まらなくなるのを防ぐ制御ロジック。
2. **ユーザー認証（Firebase Auth）の有効化**:
   - マージ承認ボタンを特定の管理者のみが押せるよう制限。
3. **Firestore ルールの制限**:
   - `firestore.rules` を書き換え、未認証ユーザーによる書き込みを禁止。
