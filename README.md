# AutoDevOps Agent

本番エラーを自動検知→LLMで修正コード生成→GitHub PRを自動作成→管理画面で承認、の一連パイプラインを実現するシステム。

## 構成

```
AutoDevOps-Agent/
├── scripts/      # Phase 1: ローカル検証スクリプト（Python + Vertex AI）
├── scripts/      # Phase 1 & 2: LLM検証およびGitHub/Firestore連携パイプライン
├── frontend/     # Phase 3: React + Vite 管理UI
└── firestore.rules
```

## クイックスタート（Phase 1: LLM検証）

### 前提条件
- Python 3.10+
- Google Cloud SDK (`gcloud` コマンド) がインストール済み
- GCPプロジェクトで **Vertex AI API** が有効化済み

### 手順

```bash
# 1. GCP認証（Application Default Credentials の設定）
gcloud auth application-default login

# 2. scripts ディレクトリへ移動
cd scripts

# 3. .env を作成して GCP プロジェクトIDを設定
cp .env.example .env
# → .env の GOOGLE_CLOUD_PROJECT をあなたのプロジェクトIDに変更

# 4. 依存パッケージのインストール
pip install -r requirements.txt

# 5. 検証スクリプトの実行
python analyze.py
```

### 出力例

```
============================================================
  AutoDevOps Agent — Phase 1: LLMパッチ生成テスト
============================================================
  プロジェクト : my-gcp-project
  モデル       : gemini-2.0-flash-001
  ロケーション : us-central1
============================================================

📄 対象ファイル: buggy_app.js
🚨 エラーログ冒頭:  2026-05-27T... TypeError: Cannot read properties of null...

🤖 Gemini (gemini-2.0-flash-001) に解析を依頼中...

✅ 解析完了！
------------------------------------------------------------
📝 原因と修正内容:
  user が null の場合に user.profile へのアクセスでエラーが発生しています。
  getUserDisplayName 関数にnullチェックを追加しました。
------------------------------------------------------------
🔧 修正後のコード（先頭30行）:
...

💾 結果を保存: result.json
🎉 Phase 1 検証完了！
```

## クイックスタート（Phase 2: GitHub & Firestore パイプライン連携）

Phase 2 では、Phase 1 で生成した修正コードを GitHub にコミットしてプルリクエストを作成し、Firestore にデータを保存する一連の流れを実行します。

### 前提条件
- GitHub App の作成（`App ID`, `Installation ID`, `private-key.pem` の取得）
- Firestore データベースの有効化（GCP プロジェクト内）
- 修正対象の GitHub リポジトリの準備

### 手順

```bash
# 1. scripts ディレクトリへ移動
cd scripts

# 2. 依存パッケージのインストール
pip install -r requirements.txt

# 3. .env ファイルに GitHub App の情報を追記
# GITHUB_APP_ID, GITHUB_INSTALLATION_ID, GITHUB_REPO 等を設定

# 4. secrets/private-key.pem を配置
# ダウンロードしたプライベートキーを配置（.gitignore に追加済み）

# 5. パイプラインの実行
python pipeline.py
```

### 出力例

```
============================================================
  AutoDevOps Agent — Phase 2: Pipeline Execution
============================================================
🔌 初期化中...
📥 GitHubからファイルを取得中...
🧠 Geminiにバグ解析を依頼中...
✅ 解析完了: ...
💾 Firestoreに保存中... (fix_id: xxxxxxxx)
🌿 GitHubブランチ作成中...
📝 修正コードをコミット中...
🚀 Pull Requestを作成中...
✅ PR作成成功: https://github.com/.../pull/1
🔄 FirestoreにPR URLを更新中...
============================================================
🎉 パイプライン実行完了！
```

## 開発フェーズ

| フェーズ | 内容 | 状態 |
|----------|------|------|
| Phase 1 | LLM検証スクリプト | ✅ 実装済み |
| Phase 2 | GitHub/Firestore連携パイプライン | ✅ 実装済み |
| Phase 3 | Next.js 管理UI（ダッシュボード） | 🔜 実装予定 |
| Phase 4 | 本番品質化 | 🔜 実装予定 |
