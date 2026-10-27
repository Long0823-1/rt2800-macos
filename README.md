# RT2800 Wi-Fi for macOS(実験的)

日本語 | [English](README.en.md)

Ralink **RT5592** を搭載した USB Wi-Fi 子機(例: Buffalo、USB `0411:0253`。802.11a/b/g/n、2.4GHz / 5GHz)を macOS で使うための、ユーザー空間ドライバです。
Linux 本家の `rt2x00` / `rt2800usb` ドライバを、Linux カーネル API の互換層の上で、ほぼ無改変のまま動かしています
([mt7601u-macos](https://github.com/Long0823-1/mt7601u-macos)、[rtw89-macos](https://github.com/Long0823-1/rtw89-macos) と同じ方式です)。

- 対応: 2.4GHz / 5GHz、WPA2-PSK とオープンのネットワーク、DHCP と IPv6、メニューバーアプリ、`rt2800-wifi` コマンド、自動接続
- 速度(子機経由で実測。5GHz、40MHz 幅の AP): 下り約 58 Mbit/s、上り約 24 Mbit/s
- 非対応: WPA3、スリープ復帰、macOS 標準の Wi-Fi 設定への統合(通信は専用の `utun` インターフェース経由です)
- 動作確認は Intel Mac / macOS 26 の 1 台のみ。**実験的なソフトウェアです。**

## インストール(GUI)

1. [Releases](../../releases) から `RT2800-WiFi-x.y.pkg` をダウンロード
2. 右クリック →「開く」(署名のないパッケージです)で、案内に従ってインストール
3. 子機を挿す → メニューバーの Wi-Fi アイコンからネットワークを選ぶ

インストーラーとメニューバーアプリは、システムの言語(日本語 / 英語)に合わせて表示されます。

アンインストール: `sudo /usr/local/libexec/rt2800/uninstall.sh`

## ソースからビルド

```bash
scripts/fetch-firmware.sh      # linux-firmware から rt2870.bin を取得
installer/build-pkg.sh         # dist/RT2800-WiFi-0.1.pkg を作成(Xcode Command Line Tools が必要)
```

デーモンだけ試す場合:

```bash
cd port && make
RTW89_FW_DIR=../rt2x00 ./rt2800d scan
```

## 使い方

メニューバーのアイコン: 接続状況(電波の強さ)、ネットワーク一覧(鍵のマーク = パスワード必要、2.4G / 5G)、接続 / 切断、
**自動接続**、**この Wi-Fi を既定の経路にする**、保存済みネットワークの削除、**ログイン時に起動**。

コマンド:

```
rt2800-wifi scan | list | status
rt2800-wifi connect "SSID"       # パスワードを聞き、保存して、次回から自動接続
rt2800-wifi disconnect | forget "SSID" | log | start | stop | restart
```

「既定の経路にする」をオンにしない限り、デフォルトの経路は変わりません。特定の宛先だけ試すには、
`sudo route add -host <IP> -interface utun4` を使います。ログ: `/var/log/rt2800d.log`。
コマンドのメッセージの言語は、`RT2800_LANG=en` または `ja` で固定できます。

## 調整と計測

実行中の設定変更(保存はされません): `echo "tune ba|ampdu|mcs|bw40 <値>" | sudo nc -U /var/run/rt2800d.sock`
既定値: HT MCS5、AP が 40MHz 幅のときだけ 40MHz で送信、受信ブロックACKを承諾、送信 A-MPDU はオフ、
ACK が返らないフレームが 8% を超えたら 6Mbps へ自動で落とす。

`scripts/` に、ボトルネックを探すために使った道具があります: `speedtest.sh`、`txdiag.sh`、`captup.sh`、`badiag.sh`、`profile.sh`。

## 仕組み

デーモン `rt2800d`(`port/host/`)が、IOKit で USB デバイスを開き、`rt2x00` / `rt2800usb` を、自前の
mac80211 / MLME / WPA2 の実装とあわせて動かします。メニューバーアプリ(`menubar/`、Swift)は、`/var/run/rt2800d.sock` でデーモンと話します。

## 既知の問題

- 子機が USB から落ちた場合(送信 A-MPDU と 40MHz 送信の併用時や、異常終了の後に起きました)は、抜き差ししてください。
- 送信は 1 チェーンだけ使います(5GHz で 2 チェーンにすると、USB ポートの給電を超えて切断されます)。`RT_TWO_TX=1` で 2 チェーンに戻せます。
- 送信完了の確認を、1 フレームごとの USB コントロール転送で読むため、速度が頭打ちになります(58 Mbit/s 付近で、このスレッドが約 83% 稼働)。
- 本格的なレート制御はなく、固定の MCS と簡単なフォールバックだけです。
- ハンドシェイクに失敗するときは、まずパスワードの打ち間違いを確認してください。

## Support / 開発支援

開発・保守活動をKo-fiで支援できます。

[Ko-fiで支援する](https://ko-fi.com/long0823)
