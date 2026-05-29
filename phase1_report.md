# Walkthrough: Phase 1 (Local Verification & AI Patch Generation)

Phase 1 (ローカル検証) で実施した内容、設定手順、遭遇した問題とその解決方法についてまとめています。後で参照する際のインデックスとして活用してください。

---

## 1. 概要
- **目的**: サーバーやCI/CDなどのインフラを設定する前に、ローカル環境で「エラーログ」と「ソースコード」から、LLMがパッチ（修正コード）を正しく安定して生成できるかを検証する。
- **使用技術**:
  - **ランタイム**: Python 3.14 (仮想環境 `.venv` 内)
  - **SDK**: `google-genai` (Google公式の新しいGenAI SDK)
  - **LLM**: Gemini 2.5 Flash (`gemini-2.5-flash`)
  - **認証**: Vertex AI モード / ADC (Application Default Credentials)

---

## 2. ディレクトリ構成と作成ファイル
`scripts/` ディレクトリ配下に、以下のファイルを整備しました。

- `scripts/`
  - [requirements.txt](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/requirements.txt): 依存ライブラリ（`google-genai`, `python-dotenv`）を定義。
  - [.env](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/.env) / [.env.example](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/.env.example): 環境変数定義ファイル。
  - [analyze.py](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/analyze.py): 本フェーズのコアとなるバグ解析・修正コード生成スクリプト。
  - `sample_error/`
    - [buggy_app.js](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/sample_error/buggy_app.js): わざと3つのバグを含ませたテスト用JavaScriptコード。
    - [error_log.txt](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/sample_error/error_log.txt): Bug 1 の発生を記録したダミーの本番エラーログ。
  - [result.json](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/result.json): LLMがパースした原因と修正コードの出力先。

---

## 3. 認証・環境構築手順

### 3.1. 仮想環境の有効化とパッケージインストール
```bash
# 仮想環境の有効化
source .venv/bin/activate

# 依存関係のインストール
pip install -r requirements.txt
```

### 3.2. Google Cloud (Vertex AI) 認証の設定
Google AI Studio の API キーを使わず、GCP の Vertex AI (クレジットあり) で動かすための設定手順です。

1. **gcloud ログインと ADC 認証情報の保存**
   ```bash
   gcloud auth application-default login
   ```
   ブラウザが起動するので、クレジットのある Google アカウントでログインして認証を完了します。

2. **Google Cloud Model API 用セットアップスクリプトの実行**
   ```bash
   bash <(curl -sSL https://storage.googleapis.com/cloud-samples-data/adc/setup_adc.sh)
   ```
   プロジェクト ID （`project-20179432-3457-4d7f-9c5`）を入力し、必要な API を有効化させます。このスクリプトにより `global` エンドポイントが有効になります。

3. **環境変数ファイル（`.env`）の設定**
   `.env` に以下を設定します。
   ```ini
   # APIキーは無効（コメントアウト）にし、Vertex AIを使用する
   # GEMINI_API_KEY=your_gemini_api_key_here

   GOOGLE_CLOUD_PROJECT=project-20179432-3457-4d7f-9c5
   VERTEX_AI_LOCATION=global
   GEMINI_MODEL=gemini-2.5-flash
   ```

---

## 4. 開発時の主な技術的修正（Structured Outputs の導入）

### 課題: JSONパースエラーの発生
初期の実装では、プロンプトで JSON 形式での回答を指示していましたが、修正コード文字列内に含まれるバックスラッシュ（エスケープ文字や正規表現など）が JSON フォーマットとして不正になり、`json.loads` 時に `json.decoder.JSONDecodeError` が発生する問題に遭遇しました。

### 解決策: Pydantic を用いたスキーマの固定
Google GenAI SDK の **Structured Outputs（`response_schema`）** を利用する形に [analyze.py](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/analyze.py) を改修しました。これにより、Gemini は必ずスキーマを満たす妥当な JSON フォーマットを返し、プログラム的に安全にパースできるようになりました。

```python
from pydantic import BaseModel

# スキーマの定義
class BugAnalysis(BaseModel):
    reason: str
    fixed_code: str

# 呼び出しの設定
response = client.models.generate_content(
    model=MODEL_ID,
    contents=prompt,
    config=types.GenerateContentConfig(
        temperature=0.1,
        max_output_tokens=8192,
        response_mime_type="application/json",
        response_schema=BugAnalysis,  # Pydanticスキーマを渡す
    ),
)
```

---

## 5. 実行結果の確認
スクリプトを実行し、正常に解析が行われたことを検証しました。

```bash
python analyze.py
```

### 出力結果例 ([result.json](file:///Users/yumaamikura/Desktop/AutoDevOps-Agent/scripts/result.json))
- **理由 (`reason`)**: `getUserDisplayName` 関数内で `user` が `null` の場合にオプショナルチェイニング (`user?.profile?.displayName`) を使用して安全にアクセスするように修正した旨、およびコメントアウトされていた Bug 2 と Bug 3 の修正点も詳細に説明されています。
- **修正後コード (`fixed_code`)**: Bug 1〜3 がすべて修正され、オプショナルチェイニング後の文字列に対する null ガードや、配列インデックス (`arr[arr.length - 1]`) の修正が反映された完全な JavaScript コードが取得できました。
