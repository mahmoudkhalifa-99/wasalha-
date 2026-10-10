# يربط GoogleService-Info.plist و Runner.entitlements ويضبط الـ Bundle ID
# في مشروع Xcode. بيشتغل على macOS (gem xcodeproj بييجي مع CocoaPods).
require 'xcodeproj'

bundle_id = ENV['BUNDLE_ID'] || 'com.wasalah.app'
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
target = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless target

group = project.main_group.find_subpath('Runner', true)

unless group.files.any? { |f| f.path == 'GoogleService-Info.plist' }
  ref = group.new_file('GoogleService-Info.plist')
  target.resources_build_phase.add_file_reference(ref, true)
end

unless group.files.any? { |f| f.path == 'Runner.entitlements' }
  group.new_file('Runner.entitlements')
end

target.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
end

project.save
puts "Xcode project patched (#{bundle_id})"
