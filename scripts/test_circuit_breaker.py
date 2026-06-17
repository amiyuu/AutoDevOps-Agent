import os
import time
from dotenv import load_dotenv
from firestore_client import FirestoreClient

load_dotenv()
project_id = os.getenv("GOOGLE_CLOUD_PROJECT")

firestore = FirestoreClient(project_id)
target_file = "src/app.js"

print("--- Testing Circuit Breaker ---")
is_tripped = firestore.check_circuit_breaker(target_file, max_attempts=3, time_window_hours=1)
print(f"[{target_file}] 過去1時間の履歴なし。サーキットブレーカー発動？ -> {is_tripped}")

if not is_tripped:
    print(f"\n{target_file} に対して意図的に3件のエラー履歴（修正試行）を追加します...")
    for i in range(3):
        fix_id = f"test-fix-{int(time.time())}-{i}"
        firestore.save_fix(fix_id, "error_log", target_file, "original code", "fixed code")
        print(f"  -> 保存完了: {fix_id}")
    
    print("\n再度サーキットブレーカーをチェックします...")
    is_tripped_now = firestore.check_circuit_breaker(target_file, max_attempts=3, time_window_hours=1)
    print(f"[{target_file}] 3件の履歴あり。サーキットブレーカー発動？ -> {is_tripped_now}")
    
    if is_tripped_now:
        print("✅ 成功！ サーキットブレーカーが正しく機能して無限ループを防止しました。")
    else:
        print("❌ 失敗！ サーキットブレーカーが発動しませんでした。")
