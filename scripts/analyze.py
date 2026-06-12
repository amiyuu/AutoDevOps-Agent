"""
analyze.py — AutoDevOps Agent Phase 1: ローカル検証スクリプト

使用方法:
  1. .env.example を .env にコピーして GOOGLE_CLOUD_PROJECT を設定
  2. `gcloud auth application-default login` で認証
  3. 仮想環境を有効化: source .venv/bin/activate
  4. パッケージインストール: pip install -r requirements.txt
  5. 実行: python analyze.py

出力:
  - AIが解析した原因（reason）
  - 修正後のコード全体（fixed_code）
  - JSON形式で result.json にも保存
"""

import os
import json
import re
from pathlib import Path

from dotenv import load_dotenv
from google import genai
from google.genai import types
from pydantic import BaseModel

# --- 環境変数の読み込み ---
load_dotenv()

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "")
LOCATION = os.getenv("VERTEX_AI_LOCATION", "us-central1")
MODEL_ID = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

# --- google-genai SDK の初期化 ---
# GEMINI_API_KEY があれば AI Studio モード（無料枠あり）
# なければ Vertex AI モード（GCP課金必要）


class BugAnalysis(BaseModel):
    reason: str
    fixed_code: str

if GEMINI_API_KEY:
    client = genai.Client(api_key=GEMINI_API_KEY)
    print(f"  認証方式   : Google AI Studio (APIキー)")
elif PROJECT_ID:
    client = genai.Client(
        vertexai=True,
        project=PROJECT_ID,
        location=LOCATION,
    )
    print(f"  認証方式   : Vertex AI")
else:
    raise ValueError(
        "GEMINI_API_KEY または GOOGLE_CLOUD_PROJECT を .env に設定してください。"
    )


def load_file(path: str | Path) -> str:
    """ファイルを読み込んで文字列で返す"""
    return Path(path).read_text(encoding="utf-8")


def build_prompt(error_log: str, source_code: str, file_name: str) -> str:
    """LLMに渡すプロンプトを構築する"""
    return f"""
あなたは優秀なソフトウェアエンジニアです。
以下の本番エラーログとソースコードを分析し、バグを修正してください。

## エラーログ
```
{error_log}
```

## 対象ファイル: {file_name}
```javascript
{source_code}
```

## 指示
1. エラーの根本原因を特定してください。
2. バグを修正した「ファイル全体のコード」を出力してください。
   - git diff 形式ではなく、修正後のファイル全体を出力すること。
   - コードのインデントや構造を変更しないこと。
3. 必ず以下のJSON形式のみで回答してください。余分なテキストは一切含めないこと。

{{
  "reason": "エラーの原因と修正内容の説明（日本語）",
  "fixed_code": "修正後のJavaScriptコード全体（文字列）"
}}
""".strip()


def analyze_bug(error_log: str, source_code: str, file_name: str) -> dict:
    """Vertex AI Gemini でバグを解析し、修正コードを返す"""
    prompt = build_prompt(error_log, source_code, file_name)

    print(f"🤖 Gemini ({MODEL_ID}) に解析を依頼中...")

    response = client.models.generate_content(
        model=MODEL_ID,
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.1,
            max_output_tokens=8192,
            response_mime_type="application/json",  # JSON モード（Structured Output）
            response_schema=BugAnalysis,
        ),
    )

    if response.text is None:
        raise ValueError("Gemini からの応答が空でした。")
    raw_text = response.text.strip()
    result = json.loads(raw_text)
    return result


def main():
    # ファイルパスの定義
    script_dir = Path(__file__).parent
    error_log_path = script_dir / "sample_error" / "error_log.txt"
    source_code_path = script_dir / "sample_error" / "buggy_app.js"

    print("=" * 60)
    print("  AutoDevOps Agent — Phase 1: LLMパッチ生成テスト")
    print("=" * 60)
    print(f"  プロジェクト : {PROJECT_ID}")
    print(f"  モデル       : {MODEL_ID}")
    print(f"  ロケーション : {LOCATION}")
    print("=" * 60)

    # ファイルの読み込み
    error_log = load_file(error_log_path)
    source_code = load_file(source_code_path)
    file_name = source_code_path.name

    print(f"\n📄 対象ファイル: {file_name}")
    print(f"🚨 エラーログ冒頭:\n  {error_log.splitlines()[0]}\n")

    # LLM 解析の実行
    result = analyze_bug(error_log, source_code, file_name)

    # 結果の表示
    print("\n✅ 解析完了！")
    print("-" * 60)
    print(f"📝 原因と修正内容:\n{result.get('reason', 'N/A')}")
    print("-" * 60)
    print("🔧 修正後のコード（先頭30行）:")
    fixed_lines = result.get("fixed_code", "").splitlines()
    for i, line in enumerate(fixed_lines[:30], 1):
        print(f"  {i:3d} | {line}")
    if len(fixed_lines) > 30:
        print(f"  ... （残り {len(fixed_lines) - 30} 行）")

    # JSON ファイルとして保存
    output_path = script_dir / "result.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"\n💾 結果を保存: {output_path}")
    print("\n🎉 Phase 1 検証完了！result.json を確認してください。")


if __name__ == "__main__":
    main()
