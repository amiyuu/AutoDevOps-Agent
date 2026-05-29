// ============================================================
// buggy_app.js — AutoDevOps Agent テスト用バグコード
// 意図的に3種類のエラーを含む。analyze.py で修正を試みる。
// ============================================================

// --- Bug 1: TypeError (undefined プロパティへのアクセス) ---
function getUserDisplayName(user) {
  // user が null の場合に TypeError が発生する
  return user.profile.displayName.toUpperCase();
}

// --- Bug 2: ReferenceError (未定義変数の参照) ---
function calculateDiscount(price) {
  // discountRate が定義されていないため ReferenceError が発生する
  const discounted = price * (1 - discountRate);
  return discounted;
}

// --- Bug 3: Logic Error (配列の範囲外アクセス) ---
function getLastItem(arr) {
  // 配列が空の場合 undefined が返り、呼び出し元でエラーになる
  return arr[arr.length]; // 正しくは arr[arr.length - 1]
}

// --- エントリポイント（実行するとエラーが発生する） ---
function main() {
  // Bug 1 を発火させる
  const user = null;
  console.log("Display Name:", getUserDisplayName(user));

  // Bug 2 を発火させる
  const price = 1000;
  console.log("Discounted Price:", calculateDiscount(price));

  // Bug 3 を発火させる
  const items = ["apple", "banana", "cherry"];
  console.log("Last Item:", getLastItem(items).toUpperCase());
}

main();
