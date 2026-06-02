import os
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone

class FirestoreClient:
    def __init__(self, project_id: str):
        self.project_id = project_id
        # ADC (Application Default Credentials) を利用して初期化
        try:
            firebase_admin.get_app()
        except ValueError:
            # アプリがまだ初期化されていない場合
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred, {
                'projectId': project_id,
            })
            
        self.db = firestore.client()
        self.collection_name = "auto_fixes"

    def save_fix(self, fix_id: str, error_message: str, target_file: str, original_code: str, fixed_code: str) -> None:
        """
        AIが生成した修正情報をFirestoreに保存する
        初期ステータスは 'pending' とする
        """
        now = datetime.now(timezone.utc)
        doc_ref = self.db.collection(self.collection_name).document(fix_id)
        
        data = {
            "id": fix_id,
            "error_message": error_message,
            "target_file": target_file,
            "original_code": original_code,
            "fixed_code": fixed_code,
            "github_pr_url": None,
            "status": "pending",
            "created_at": now,
            "updated_at": now
        }
        
        doc_ref.set(data)

    def update_pr_url(self, fix_id: str, pr_url: str) -> None:
        """
        作成されたPRのURLをFirestoreに記録する
        """
        now = datetime.now(timezone.utc)
        doc_ref = self.db.collection(self.collection_name).document(fix_id)
        
        doc_ref.update({
            "github_pr_url": pr_url,
            "updated_at": now
        })
        
    def update_status(self, fix_id: str, status: str) -> None:
         """ステータス（merged, rejected）を更新する（Phase 3用）"""
         now = datetime.now(timezone.utc)
         doc_ref = self.db.collection(self.collection_name).document(fix_id)
         doc_ref.update({
             "status": status,
             "updated_at": now
         })
