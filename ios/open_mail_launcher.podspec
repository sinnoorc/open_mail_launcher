#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint open_mail_launcher.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'open_mail_launcher'
  s.version          = '0.3.1'
  s.summary          = 'Flutter plugin for opening installed mail apps.'
  s.description      = <<-DESC
Open Mail Launcher discovers installed email apps on Android and iOS, opens a
mail app or app picker, and composes emails with pre-filled recipients, subject,
and body while keeping the public Flutter API stable.
                       DESC
  s.homepage         = 'https://github.com/sinnoorc/open_mail_launcher'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'sinnoorc' => 'https://github.com/sinnoorc' }
  s.source           = { :path => '.' }
  s.source_files = 'open_mail_launcher/Sources/open_mail_launcher/**/*.{h,m,swift}'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'open_mail_launcher_privacy' => ['open_mail_launcher/Sources/open_mail_launcher/PrivacyInfo.xcprivacy']}
end
