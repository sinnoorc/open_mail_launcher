#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint open_mail_launcher.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'open_mail_launcher'
  s.version          = '0.4.0-beta.1'
  s.summary          = 'Flutter plugin for opening installed mail apps.'
  s.description      = <<-DESC
Open Mail Launcher discovers installed email apps, opens a mail app or app
picker, and composes emails with pre-filled recipients, subject, and body
while keeping the public Flutter API stable.
                       DESC
  s.homepage         = 'https://github.com/sinnoorc/open_mail_launcher'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'sinnoorc' => 'https://github.com/sinnoorc' }
  s.source           = { :path => '.' }
  s.source_files = 'open_mail_launcher/Sources/open_mail_launcher/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.resource_bundles = {'open_mail_launcher_privacy' => ['open_mail_launcher/Sources/open_mail_launcher/PrivacyInfo.xcprivacy']}
end
