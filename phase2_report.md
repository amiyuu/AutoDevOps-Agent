# Walkthrough: Phase 2 (エラー検知 & GitHub/Firebase パイプライン構築)

Phase 2 では、Phase 1 の「ローカルでのLLMパッチ生成」を拡張し、実際にクラウドデータベース（Firestore）への保存と、GitHub リポジトリへのプルリクエスト（PR）自動作成を連携させるパイプラインを構築しました。

---

## 1. 概要
- **目的**: LLMによる修正コードの生成結果をデータベースに保存し、自動的にGitHubにブランチ・コミット・PRを作成する。
- **使用技術**:
  - **ランタイム**: Python 3.10+ (仮想環境 `.venv` 内)
  - **SDK**: `PyGithub` (GitHub API), `firebase-admin` (Firestore), `PyJWT` (GitHub App 認証)
  - **認証**: GitHub App (JWT/Installation Token), GCP Application Default Credentials
  - **インフラ**: Firestore (Native Mode), GitHub

---

## 2. ディレクトリ構成と作成ファイル
`scripts/` ディレクトリ配下に、以下のファイルを整備・追加しました。

- `scripts/`
  - `secrets/`
    - `private-key.pem`: [NEW] GitHub Appのプライベートキー（`.gitignore` に指定しコミット対象外）
  - [github_client.py](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/github_client.py): [NEW] GitHub App認証およびブランチ作成・コミット・PR作成を行うモジュール
  - [firestore_client.py](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/firestore_client.py): [NEW] Firestoreへの修正データ保存とPRリンクの更新を行うモジュール
  - [pipeline.py](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/pipeline.py): [NEW] Phase 1 の `analyze.py` と上記2つのクライアントを統合するメインスクリプト
  - [requirements.txt](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/requirements.txt): [UPDATE] 必要なライブラリ（`PyJWT`, `PyGithub`, `firebase-admin`, `cryptography`）を追記
  - [.env](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/.env): [UPDATE] GitHub App IDや対象リポジトリ等の環境変数を追加

---

## 3. アーキテクチャとデータフロー

本フェーズで完成したローカルスクリプト (`pipeline.py`) のフローは以下の通りです。

1. **エラー取得**: ダミーのエラーログと対象コードを読み込む
2. **LLM解析**: `analyze.py` (Gemini) を呼び出し、エラー原因と修正後コードを取得
3. **DB保存 (Pending)**: Firestoreの `auto_fixes` コレクションにステータス `pending` で保存し、`fix_id` を発行
4. **GitHub ブランチ作成**: 対象リポジトリに `fix/agent-{fix_id}` というブランチを作成
5. **GitHub コミット**: 修正後コードをコミット
6. **GitHub PR作成**: PRを作成し、PRのURLを取得
7. **DB更新 (PR URL)**: Firestoreの該当ドキュメントに作成したPRのURLを追記

---

## 4. 認証・環境構築で実施したこと

### 4.1 GitHub 認証 (GitHub App)
セキュリティベストプラクティスに従い、個人アカウントの PAT (Personal Access Token) ではなく **GitHub App** を作成し、対象リポジトリのみにインストールする最小権限アクセスを実装しました。
- **権限**: `Contents: Read & Write`, `Pull requests: Read & Write`
- 実行時に `.pem` ファイルから JWT を生成し、Installation Access Token を動的に取得する仕組みを `github_client.py` に実装しました。

### 4.2 Firestore データベース連携
生成された修正コードとメタデータを保存するための Firestore インスタンス (`asia-northeast1`) を作成し、連携を実装しました。
- `gcloud firestore databases create` コマンドを使用して default データベースを初期化。
- `firestore_client.py` では `credentials.ApplicationDefault()` を利用し、ローカルの gcloud 認証情報をそのまま流用することでキー管理を不要にしました。

---

## 5. 遭遇した問題とその解決方法

### 課題1: Firestore API が有効化されていない
- **現象**: スクリプト実行時に `google.api_core.exceptions.PermissionDenied: 403 Cloud Firestore API has not been used...` エラーが発生。
- **解決**: ターミナルから `gcloud services enable firestore.googleapis.com` を実行し、APIを有効化。

### 課題2: Firestore データベースが存在しない
- **現象**: API有効化後に `google.api_core.exceptions.NotFound: 404 The database (default) does not exist...` エラーが発生。
- **解決**: ターミナルから `gcloud firestore databases create --location=asia-northeast1 --type=firestore-native` を実行し、データベース本体を初期化。

### 課題3: 認証情報の意図しないコミット
- **現象**: 途中、`APP ID` などを記載したメモファイル (`id_etc.md`) が誤って Git にコミットされてしまった。
- **解決**: `git rm --cached id_etc.md` を実行して追跡から外し、`.gitignore` に追記。その後 `git commit --amend` して `git push -f` することで、リモートのコミット履歴からも完全に抹消しました。

---

## 6. 次のステップ (Phase 3)

インフラとバックエンドの連携が完了したため、Phase 3 では **フロントエンドUIの構築** に進みます。
管理者が Firestore のデータを一覧表示し、修正前後のコード（Diff）をブラウザ上で確認して、「承認」または「却下」ボタンを押せるダッシュボード（Next.js または React）を開発します。
