import os
import time
import jwt
import requests
from github import Github
from github import Auth

class GitHubAppClient:
    def __init__(self, app_id: str, installation_id: str, private_key_path: str):
        self.app_id = app_id
        self.installation_id = installation_id
        
        with open(private_key_path, "r") as key_file:
            self.private_key = key_file.read()

        # JWTを生成
        now = int(time.time())
        payload = {
            "iat": now,
            "exp": now + (10 * 60), # 10分間有効
            "iss": self.app_id
        }
        
        self.jwt_token = jwt.encode(payload, self.private_key, algorithm="RS256")
        self.installation_token = self._get_installation_token()
        
        # PyGithub クライアントの初期化
        auth = Auth.Token(self.installation_token)
        self.client = Github(auth=auth)

    def _get_installation_token(self) -> str:
        """JWT を使って Installation Access Token を取得する"""
        headers = {
            "Authorization": f"Bearer {self.jwt_token}",
            "Accept": "application/vnd.github.v3+json"
        }
        url = f"https://api.github.com/app/installations/{self.installation_id}/access_tokens"
        response = requests.post(url, headers=headers)
        response.raise_for_status()
        return response.json()["token"]

    def get_file_content(self, repo_name: str, file_path: str, branch: str = "main") -> tuple[str, str]:
        """指定したファイルのコンテンツとSHAを取得する"""
        repo = self.client.get_repo(repo_name)
        file_content = repo.get_contents(file_path, ref=branch)
        
        # decode the content (base64)
        content_str = file_content.decoded_content.decode("utf-8")
        return content_str, file_content.sha

    def create_fix_branch(self, repo_name: str, base_branch: str, new_branch: str) -> None:
        """ベースブランチから新しいブランチを作成する"""
        repo = self.client.get_repo(repo_name)
        base_ref = repo.get_git_ref(f"heads/{base_branch}")
        repo.create_git_ref(ref=f"refs/heads/{new_branch}", sha=base_ref.object.sha)

    def commit_file(self, repo_name: str, branch: str, file_path: str, content: str, commit_message: str, sha: str) -> None:
        """指定したブランチのファイルを更新（コミット）する"""
        repo = self.client.get_repo(repo_name)
        repo.update_file(
            path=file_path,
            message=commit_message,
            content=content,
            sha=sha,
            branch=branch
        )

    def create_pull_request(self, repo_name: str, branch: str, base_branch: str, title: str, body: str) -> str:
        """プルリクエストを作成し、URLを返す"""
        repo = self.client.get_repo(repo_name)
        pr = repo.create_pull(
            title=title,
            body=body,
            head=branch,
            base=base_branch
        )
        return pr.html_url

    def merge_pull_request(self, repo_name: str, pr_number: int) -> bool:
        """指定したプルリクエストをマージする"""
        repo = self.client.get_repo(repo_name)
        pr = repo.get_pull(pr_number)
        status = pr.merge(commit_message="Auto-merged by AutoDevOps Agent")
        return status.merged
