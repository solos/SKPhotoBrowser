Pod::Spec.new do |s|
  s.name                = "SKPhotoBrowser"
  s.version             = "7.1.0"
  s.summary             = "Simple PhotoBrowser/Viewer with Live Photo support written by pure swift. inspired by facebook, twitter photo browsers."
  s.homepage            = "https://github.com/suzuki-0000/SKPhotoBrowser"
  s.license             = { :type => "MIT", :file => "LICENSE" }
  s.author              = { "suzuki_keishi" => "keishi.1983@gmail.com" }
  s.source              = { :git => "https://github.com/suzuki-0000/SKPhotoBrowser.git", :tag => s.version }
  s.platform            = :ios, "9.1"
  s.source_files        = "SKPhotoBrowser/**/*.{h,m,swift}"
  s.resources           = "SKPhotoBrowser/SKPhotoBrowser.bundle"
  s.requires_arc        = true
  s.frameworks          = ["UIKit", "PhotosUI"]
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  s.swift_version = "5.4"
  s.swift_versions = ['4.0', '4.2', '5.0', '5.1', '5.2', '5.3', '5.4']
end
