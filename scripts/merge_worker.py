import os
import time
import threading
from dotenv import load_dotenv
from github_client import GitHubAppClient
from firestore_client import FirestoreClient

load_dotenv()

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "")
GITHUB_APP_ID = os.getenv("GITHUB_APP_ID", "")
GITHUB_INSTALLATION_ID = os.getenv("GITHUB_INSTALLATION_ID", "")
GITHUB_KEY_PATH = os.getenv("GITHUB_APP_PRIVATE_KEY_PATH", "secrets/private-key.pem")
GITHUB_REPO = os.getenv("GITHUB_REPO", "")

def start_worker():
    if not all([PROJECT_ID, GITHUB_APP_ID, GITHUB_INSTALLATION_ID, GITHUB_REPO]):
        print("❌ 必要な環境変数が設定されていません。.env を確認してください。")
        return

    print("🔌 初期化中: Auto-Merge Worker...")
    github = GitHubAppClient(GITHUB_APP_ID, GITHUB_INSTALLATION_ID, GITHUB_KEY_PATH)
    firestore_client = FirestoreClient(PROJECT_ID)

    def on_snapshot(doc_snapshot, changes, read_time):
        for change in changes:
            if change.type.name == 'MODIFIED' or change.type.name == 'ADDED':
                doc = change.document.to_dict()
                fix_id = change.document.id
                
                # 'approved' ステータスを検知したらマージを実行
                if doc.get('status') == 'approved':
                    print(f"🔔 'approved' ステータスを検知しました (fix_id: {fix_id})")
                    pr_url = doc.get('github_pr_url')
                    if pr_url:
                        try:
                            # URLからPR番号を抽出 (例: https://github.com/amiyuu/repo/pull/12 -> 12)
                            pr_number = int(pr_url.split('/')[-1])
                            print(f"🚀 GitHub PR #{pr_number} をマージ中...")
                            
                            success = github.merge_pull_request(GITHUB_REPO, pr_number)
                            if success:
                                print(f"✅ PR #{pr_number} のマージに成功しました！")
                                firestore_client.update_status(fix_id, 'completed')
                                print(f"💾 Firestore のステータスを 'completed' に更新しました。")
                            else:
                                print(f"❌ PR #{pr_number} のマージに失敗しました。")
                        except Exception as e:
                            print(f"❌ PRマージ処理でエラーが発生しました: {e}")

    # incidentsコレクションを監視
    collection_ref = firestore_client.db.collection(firestore_client.collection_name)
    watch = collection_ref.on_snapshot(on_snapshot)
    
    print("👀 Firestore の 'approved' ステータスを監視しています...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("ワーカーを停止します。")

if __name__ == "__main__":
    start_worker()
