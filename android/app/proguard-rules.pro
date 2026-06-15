# R8/ProGuard keep rules for the release build.

# google_mlkit_text_recognition pulls in references to the optional, script-
# specific recognizers (Chinese, Devanagari, Japanese, Korean). Those live in
# separate Play artifacts that this app does not bundle — only the default
# (Latin) recognizer ships. Suppress R8's "missing class" errors for the absent
# ones. NOTE: the whole on-device ML Kit pipeline is the retired fallback;
# Gemini (Firebase AI Logic) is the live tile detector.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
