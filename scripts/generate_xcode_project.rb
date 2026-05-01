#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'Mirador.xcodeproj')

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.development_region = 'en'
project.root_object.known_regions = %w[en Base]

apps_group = project.main_group.new_group('Apps', 'Apps')
host_group = apps_group.new_group('MiradorHostApp', 'MiradorHostApp')
client_group = apps_group.new_group('MiradorClientApp', 'MiradorClientApp')

host_source = host_group.new_file('MiradorHostApp.swift')
host_group.new_file('Info.plist')
client_source = client_group.new_file('MiradorClientApp.swift')
client_group.new_file('Info.plist')

package_reference = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package_reference.relative_path = '.'
project.root_object.package_references << package_reference

def add_package_product(project, target, package_reference, product_name)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = product_name
  dependency.package = package_reference
  target.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

def configure_app_target(target, settings)
  target.build_configurations.each do |configuration|
    configuration.build_settings.merge!(settings)
  end
end

host_target = project.new_target(:application, 'MiradorHostApp', :osx, '15.0', nil, :swift, 'Mirador Host')
host_target.add_file_references([host_source])
add_package_product(project, host_target, package_reference, 'MiradorHost')
configure_app_target(
  host_target,
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.stevenacz.mirador.host',
  'INFOPLIST_FILE' => 'Apps/MiradorHostApp/Info.plist',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'MARKETING_VERSION' => '0.1.0',
  'CURRENT_PROJECT_VERSION' => '1',
  'SWIFT_VERSION' => '6.0',
  'ENABLE_HARDENED_RUNTIME' => 'YES'
)

client_target = project.new_target(:application, 'MiradorClientApp', :ios, '18.0', nil, :swift, 'Mirador')
client_target.add_file_references([client_source])
add_package_product(project, client_target, package_reference, 'MiradorClient')
configure_app_target(
  client_target,
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.stevenacz.mirador.client',
  'INFOPLIST_FILE' => 'Apps/MiradorClientApp/Info.plist',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'MARKETING_VERSION' => '0.1.0',
  'CURRENT_PROJECT_VERSION' => '1',
  'SWIFT_VERSION' => '6.0',
  'TARGETED_DEVICE_FAMILY' => '1,2',
  'SUPPORTS_MACCATALYST' => 'NO'
)

project.save

[host_target, client_target].each do |target|
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  scheme.save_as(PROJECT_PATH, target.name, true)
end
