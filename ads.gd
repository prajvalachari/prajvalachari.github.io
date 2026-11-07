extends Node
## AdMob interstitial ads + internet check for Angry Archers.
## Needs the "AdMob" plugin by Poing Studios (AssetLib) installed and enabled.
## Ads only run on Android; on PC this script just does the internet check.

signal internet_result(ok: bool)

const TEST_MODE := true # TRUE while testing. Set to FALSE for the release build you upload to Google Play.
const TEST_UNIT := "ca-app-pub-3940256099942544/1033173712"   # Google's official test interstitial
const REAL_UNIT := "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"   # <- your own Interstitial ad unit ID from AdMob
const MIN_GAP_MSEC := 60000 # at least 60 seconds between two ads (AdMob does not allow an ad on every tap)
const CHECK_URL := "https://clients3.google.com/generate_204"

var main: Node
var enabled := false
var ad: InterstitialAd = null
var loading := false
var last_shown := -1000000
var fsc := FullScreenContentCallback.new()
var http: HTTPRequest
var checking := false


func setup(m: Node) -> void:
	main = m
	http = HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(_on_check_done)
	enabled = OS.get_name() == "Android"
	if not enabled:
		return
	MobileAds.initialize() # once, at launch
	fsc.on_ad_showed_full_screen_content = func() -> void:
		main.ad_started()
	fsc.on_ad_dismissed_full_screen_content = func() -> void:
		_ad_closed()
	fsc.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		_ad_closed()
	load_ad()


# ---------------------------------------------------------------- internet
## Result comes through the internet_result signal (true = online).
func check_internet() -> void:
	if checking:
		return
	checking = true
	if http.request(CHECK_URL) != OK:
		checking = false
		internet_result.emit(false)


func _on_check_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	checking = false
	internet_result.emit(result == HTTPRequest.RESULT_SUCCESS and (code == 204 or code == 200))


# ---------------------------------------------------------------- ads
func unit_id() -> String:
	return TEST_UNIT if TEST_MODE else REAL_UNIT


func load_ad() -> void:
	if not enabled or loading or ad != null:
		return
	loading = true
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		loading = false
	cb.on_ad_loaded = func(loaded: InterstitialAd) -> void:
		loading = false
		ad = loaded
		ad.full_screen_content_callback = fsc
	InterstitialAdLoader.new().load(unit_id(), AdRequest.new(), cb)


## Shows an ad if one is ready and the minimum gap has passed. Returns true if it was shown.
func show_ad() -> bool:
	if not enabled or ad == null:
		load_ad()
		return false
	var now := Time.get_ticks_msec()
	if now - last_shown < MIN_GAP_MSEC:
		return false
	last_shown = now
	ad.show()
	return true


func _ad_closed() -> void:
	if ad != null:
		ad.destroy() # always free the ad (memory)
		ad = null
	main.ad_finished()
	load_ad() # get the next one ready
