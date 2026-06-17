import os
import uuid
from dotenv import load_dotenv

# モジュールのインポート
from analyze import analyze_bug, load_file
from github_client import GitHubAppClient
from firestore_client import FirestoreClient

# 環境変数の読み込み
load_dotenv()

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "")
GITHUB_APP_ID = os.getenv("GITHUB_APP_ID", "")
GITHUB_INSTALLATION_ID = os.getenv("GITHUB_INSTALLATION_ID", "")
GITHUB_KEY_PATH = os.getenv("GITHUB_APP_PRIVATE_KEY_PATH", "secrets/private-key.pem")
GITHUB_REPO = os.getenv("GITHUB_REPO", "")
GITHUB_TARGET_FILE = os.getenv("GITHUB_TARGET_FILE", "")
GITHUB_DEFAULT_BRANCH = os.getenv("GITHUB_DEFAULT_BRANCH", "main")

def main():
    print("=" * 60)
    print("  AutoDevOps Agent — Phase 2: Pipeline Execution")
    print("=" * 60)

    # 1. 初期化とバリデーション
    if not all([PROJECT_ID, GITHUB_APP_ID, GITHUB_INSTALLATION_ID, GITHUB_REPO, GITHUB_TARGET_FILE]):
        print("❌ 必要な環境変数が設定されていません。.env を確認してください。")
        return

    print("🔌 初期化中...")
    github = GitHubAppClient(GITHUB_APP_ID, GITHUB_INSTALLATION_ID, GITHUB_KEY_PATH)
    firestore = FirestoreClient(PROJECT_ID)
    
    # 2. エラーログの読み込み (ダミー)
    error_log_path = "sample_error/error_log.txt"
    error_log = load_file(error_log_path)
    
    # 3. サーキットブレーカーの確認
    print(f"🛡️ サーキットブレーカーを確認中: {GITHUB_TARGET_FILE}")
    if firestore.check_circuit_breaker(GITHUB_TARGET_FILE, max_attempts=3, time_window_hours=1):
        print("🚨 サーキットブレーカー発動: 短期間に同一ファイルの修復試行が多すぎます。無限ループを防止するため処理を中断します。")
        return

    # 4. GitHubから対象ファイルの最新コードを取得
    print(f"📥 GitHubからファイルを取得中: {GITHUB_REPO}/{GITHUB_TARGET_FILE} (branch: {GITHUB_DEFAULT_BRANCH})")
    original_code, current_sha = github.get_file_content(GITHUB_REPO, GITHUB_TARGET_FILE, GITHUB_DEFAULT_BRANCH)
    
    # 5. LLM (Gemini) によるバグ解析と修正コード生成
    print("🧠 Geminiにバグ解析を依頼中...")
    result = analyze_bug(error_log, original_code, GITHUB_TARGET_FILE)
    reason = result.get("reason", "No reason provided.")
    fixed_code = result.get("fixed_code", "")
    
    if not fixed_code:
        print("❌ 修正コードの生成に失敗しました。")
        return
        
    print(f"✅ 解析完了: {reason}")
    
    # 6. Firestoreに保存 (pending)
    fix_id = str(uuid.uuid4())
    print(f"💾 Firestoreに保存中... (fix_id: {fix_id})")
    firestore.save_fix(
        fix_id=fix_id,
        error_message=error_log,
        target_file=GITHUB_TARGET_FILE,
        original_code=original_code,
        fixed_code=fixed_code
    )
    
    # 7. GitHub に修正を反映 (ブランチ作成 -> コミット -> PR)
    fix_branch = f"fix/agent-{fix_id}"
    print(f"🌿 GitHubブランチ作成中: {fix_branch}")
    github.create_fix_branch(GITHUB_REPO, GITHUB_DEFAULT_BRANCH, fix_branch)
    
    print("📝 修正コードをコミット中...")
    commit_msg = f"fix: AutoDevOps Agent Fix\n\nReason: {reason}"
    github.commit_file(
        repo_name=GITHUB_REPO,
        branch=fix_branch,
        file_path=GITHUB_TARGET_FILE,
        content=fixed_code,
        commit_message=commit_msg,
        sha=current_sha
    )
    
    print("🚀 Pull Requestを作成中...")
    pr_title = f"[Auto-Fix] 🤖 本番エラーの自動修正 ({fix_id[:8]})"
    pr_body = f"## 🤖 AutoDevOps Agent\n本番エラーを検知し、AIが自動修正を提案しました。\n\n### 原因\n{reason}\n\n### Fix ID\n`{fix_id}`"
    
    pr_url = github.create_pull_request(
        repo_name=GITHUB_REPO,
        branch=fix_branch,
        base_branch=GITHUB_DEFAULT_BRANCH,
        title=pr_title,
        body=pr_body
    )
    
    print(f"✅ PR作成成功: {pr_url}")
    
    # 8. PR URL を Firestore に書き戻す
    print("🔄 FirestoreにPR URLを更新中...")
    firestore.update_pr_url(fix_id, pr_url)
    
    print("=" * 60)
    print("🎉 パイプライン実行完了！")
    print(f"👉 確認1: GitHub - {pr_url}")
    print(f"👉 確認2: Firebase Console - Firestore (auto_fixes/{fix_id})")

if __name__ == "__main__":
    main()
