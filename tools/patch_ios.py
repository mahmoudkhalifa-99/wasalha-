#!/usr/bin/env python3
"""يطبّق إعدادات وصلها على مشروع iOS اللي بيولّده `flutter create --platforms=ios`.

بيعمل: Info.plist (صلاحيات + Google Sign-In + إشعارات) + Podfile (صلاحيات
permission_handler) + Runner.entitlements (Push). وبعده patch_ios_project.rb
بيربط GoogleService-Info.plist والـ entitlements والـ Bundle ID في مشروع Xcode.
"""
import os
import plistlib
import re
import sys

BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.wasalah.app")
IOS = "ios"
INFO = f"{IOS}/Runner/Info.plist"
GSI = f"{IOS}/Runner/GoogleService-Info.plist"
PODFILE = f"{IOS}/Podfile"
ENTITLEMENTS = f"{IOS}/Runner/Runner.entitlements"

if not os.path.isfile(INFO):
    sys.exit("ios/Runner/Info.plist مش موجود — شغّل flutter create --platforms=ios الأول")

if not os.path.isfile(GSI):
    sys.exit(
        "ios/Runner/GoogleService-Info.plist مش موجود. حمّله من Firebase "
        "(تطبيق iOS بنفس الـ Bundle ID: %s) وحطه في متغير GOOGLE_SERVICE_INFO_PLIST "
        "(base64) في Codemagic." % BUNDLE_ID
    )

with open(GSI, "rb") as f:
    gsi = plistlib.load(f)
reversed_client = gsi.get("REVERSED_CLIENT_ID")
if not reversed_client:
    sys.exit(
        "GoogleService-Info.plist ملوش REVERSED_CLIENT_ID — فعّل Google Sign-In "
        "في Firebase Authentication ونزّل الملف تاني."
    )
if gsi.get("BUNDLE_ID") and gsi["BUNDLE_ID"] != BUNDLE_ID:
    sys.exit("BUNDLE_ID في GoogleService-Info.plist (%s) مختلف عن %s" % (gsi["BUNDLE_ID"], BUNDLE_ID))

with open(INFO, "rb") as f:
    info = plistlib.load(f)

info["CFBundleDisplayName"] = "وصلها"
info["ITSAppUsesNonExemptEncryption"] = False  # تشفير HTTPS العادي بس
info["NSLocationWhenInUseUsageDescription"] = (
    "وصلها بيستخدم موقعك لتحديد مكان الاستلام والتوصيل وتتبع المشوار."
)
info["NSCameraUsageDescription"] = (
    "وصلها بيستخدم الكاميرا لتصوير مستندات التوثيق (البطاقة والرخصة)."
)
info["NSPhotoLibraryUsageDescription"] = (
    "وصلها بيحتاج الوصول للصور لرفع صورة الإعلان أو المستند."
)

# Google Sign-In: الـ URL scheme لازم يكون REVERSED_CLIENT_ID
urls = info.setdefault("CFBundleURLTypes", [])
if not any(reversed_client in u.get("CFBundleURLSchemes", []) for u in urls):
    urls.append({"CFBundleTypeRole": "Editor", "CFBundleURLSchemes": [reversed_client]})

# إشعارات FCM في الخلفية
modes = info.setdefault("UIBackgroundModes", [])
if "remote-notification" not in modes:
    modes.append("remote-notification")

# url_launcher (واتساب / اتصال)
queries = info.setdefault("LSApplicationQueriesSchemes", [])
for scheme in ("https", "http", "tel", "whatsapp"):
    if scheme not in queries:
        queries.append(scheme)

with open(INFO, "wb") as f:
    plistlib.dump(info, f)

# Push Notifications entitlement
with open(ENTITLEMENTS, "wb") as f:
    plistlib.dump({"aps-environment": "production"}, f)

# Podfile: iOS 13 + صلاحيات permission_handler (من غيرها بتتشال من الـ build)
with open(PODFILE, encoding="utf-8") as f:
    pod = f.read()

pod = re.sub(r"^\s*#\s*platform :ios,.*$", "platform :ios, '13.0'", pod, count=1, flags=re.M)
if not re.search(r"^\s*platform :ios", pod, flags=re.M):
    pod = "platform :ios, '13.0'\n" + pod

if "PERMISSION_LOCATION=1" not in pod:
    hook = "    flutter_additional_ios_build_settings(target)\n"
    block = (
        hook
        + "    target.build_configurations.each do |config|\n"
        + "      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)',\n"
        + "        'PERMISSION_LOCATION=1', 'PERMISSION_CAMERA=1', 'PERMISSION_NOTIFICATIONS=1']\n"
        + "    end\n"
    )
    if hook not in pod:
        sys.exit("مش لاقي flutter_additional_ios_build_settings في Podfile")
    pod = pod.replace(hook, block, 1)

with open(PODFILE, "w", encoding="utf-8") as f:
    f.write(pod)

print("تم تطبيق إعدادات iOS (Bundle ID: %s)" % BUNDLE_ID)
