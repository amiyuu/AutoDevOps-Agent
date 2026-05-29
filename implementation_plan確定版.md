# AutoDevOps Agent — 実装計画（確定版）

## 技術スタック

| レイヤー | 技術 |
|----------|------|
| LLM | Google Vertex AI (Gemini 1.5 Pro / 2.0 Flash) |
| Backend | Google Cloud Functions (Node.js / TypeScript) |
| Database | Cloud Firestore |
| Frontend | React + Vite (SPA) |
| GitHub連携 | GitHub App (Octokit) |

---

## プロジェクト構成（モノレポ）

```
AutoDevOps-Agent/
├── scripts/            # Phase 1: ローカル検証スクリプト（Python）
│   ├── sample_error/
│   │   ├── buggy_app.js     # テスト用バグコード
│   │   └── error_log.txt    # サンプルスタックトレース
│   ├── analyze.py           # Vertex AI Gemini呼び出しスクリプト
│   ├── requirements.txt
│   └── .env.example
├── backend/            # Phase 2: Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── index.ts
│   │   ├── parser.ts
│   │   ├── github.ts
│   │   ├── llm.ts
│   │   └── firestore.ts
│   └── package.json
├── frontend/           # Phase 3: React + Vite (SPA)
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── pages/
│   │   └── components/
│   └── package.json
└── firestore.rules
```

---

## Phase 1: ローカル検証（即着手）

### 目標
Vertex AI Gemini に「エラーログ + ソースコード」を渡し、`{ "reason": "...", "fixed_code": "..." }` のJSONが安定して返ることを確認。

### タスク
- [x] `scripts/sample_error/buggy_app.js` — TypeError・ReferenceError・Syntax Errorを含むサンプル
- [x] `scripts/sample_error/error_log.txt` — 対応するスタックトレースログ
- [x] `scripts/analyze.py` — Vertex AI SDK + Structured Output (JSON mode)
- [x] `scripts/requirements.txt` + `scripts/.env.example`

---

## Phase 2: エラー検知とパイプライン構築

> [!IMPORTANT]
> GitHub App の作成手順を先に案内します。

### GitHub App 作成手順（案内済み）
1. GitHub → Settings → Developer Settings → GitHub Apps → New GitHub App
2. 権限: `Contents: Read & Write`, `Pull requests: Read & Write`
3. Private Key をダウンロードして `backend/` に保存（gitignore必須）

### タスク
- [ ] `backend/src/parser.ts` — Regexでファイルパス・行番号を抽出
- [ ] `backend/src/github.ts` — Octokit でファイル取得・ブランチ作成・コミット・PR作成
- [ ] `backend/src/llm.ts` — Vertex AI Gemini API呼び出し
- [ ] `backend/src/firestore.ts` — `/auto_fixes/{fix_id}` CRUD
- [ ] `backend/src/index.ts` — Cloud Functions HTTP/PubSub trigger

---

## Phase 3: フロントエンドUI

### タスク
- [ ] `frontend/` — Vite + React プロジェクト作成
- [ ] ダッシュボード: `status === 'pending'` 一覧（`onSnapshot`）
- [ ] 詳細画面: Diff表示 (`react-diff-viewer-continued`) + 承認/却下ボタン
- [ ] ダークモード + グラスモーフィズムデザイン

---

## Phase 4: 本番品質化

- [ ] サーキットブレーカー（1時間に3件超でシステム停止）
- [ ] Firebase Authentication（管理者のみ承認可能）
- [ ] Slackアラート連携

---

## Firestore スキーマ

```
/auto_fixes/{fix_id}
{
  "id": "string",
  "error_message": "string",
  "target_file": "string",
  "original_code": "string",
  "fixed_code": "string",
  "github_pr_url": "string",
  "status": "'pending' | 'merged' | 'rejected'",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```
