#!/usr/bin/env bash
# Regenerates the Pigeon bridge from pigeons/hybrid_nav.dart.
#
# Pigeon emits internal Swift, but these types live inside the hybrid_router
# plugin framework, so the host app can't see them. After generating, we mark
# only the app-facing API public: NavRoute, ToNative, ToNativeSetup.setUp,
# ToFlutter (+ its protocol) and PigeonError.
set -euo pipefail
cd "$(dirname "$0")/.."

dart run pigeon --input pigeons/hybrid_nav.dart

SWIFT=ios/Classes/HybridNav.g.swift
perl -0pi -e '
  s/^final class PigeonError: Error \{/public final class PigeonError: Error {/m;
  s/^struct NavRoute: Hashable, CustomStringConvertible \{\n  var path: String\n/public struct NavRoute: Hashable, CustomStringConvertible {\n  public var path: String\n\n  public init(path: String) { self.path = path }\n/m;
  s/^  static func == \(lhs: NavRoute/  public static func == (lhs: NavRoute/m;
  s/^  func hash\(into hasher: inout Hasher\) \{/  public func hash(into hasher: inout Hasher) {/m;
  s/^protocol ToNative \{/public protocol ToNative {/m;
  s/^class ToNativeSetup \{/public class ToNativeSetup {/m;
  s/^  static func setUp\(binaryMessenger: FlutterBinaryMessenger, api: ToNative\?/  public static func setUp(binaryMessenger: FlutterBinaryMessenger, api: ToNative?/m;
  s/^protocol ToFlutterProtocol \{/public protocol ToFlutterProtocol {/m;
  s/^class ToFlutter: ToFlutterProtocol \{/public class ToFlutter: ToFlutterProtocol {/m;
  s/^  init\(binaryMessenger: FlutterBinaryMessenger, messageChannelSuffix: String = ""\) \{/  public init(binaryMessenger: FlutterBinaryMessenger, messageChannelSuffix: String = "") {/m;
  s/^  func pushFlutterRoute\((.*)\) \{$/  public func pushFlutterRoute($1) {/m;
  s/^  func handleBack\((.*)\) \{$/  public func handleBack($1) {/m;
' "$SWIFT"

# Fail loudly if Pigeon's output format changed and a substitution missed.
for sig in "public struct NavRoute" "public init(path: String)" "public protocol ToNative" \
           "public static func setUp" "public class ToFlutter" "public init(binaryMessenger" \
           "public func pushFlutterRoute" "public func handleBack" "public final class PigeonError" \
           "public func hash(into" "public static func =="; do
  grep -q "$sig" "$SWIFT" || { echo "generate.sh: expected '$sig' in $SWIFT" >&2; exit 1; }
done
echo "Generated lib/src/hybrid_nav.g.dart and $SWIFT (public API)."
