Pod::Spec.new do |s|

  s.name         = "iModel"
  s.version      = "0.0.4"
  s.summary      = "Validation, JSON parsing and async remote communication in one bundle."

s.description  = <<-DESC
	iModel was created to provide a simple boilerplate for creating data models. It provides
	data validation and a CRUD over HTTP interface with seamless JSON parsing. 
                   DESC

  s.homepage     = "https://github.com/theddnc/iModel"
  s.license      = { :type => "MIT", :file => "LICENCE" }

  s.author             = { "Jakub Zaczek" => "zaczekjakub@gmail.com" }

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/theddnc/iModel.git", :tag => "0.0.4"}

  s.source_files  = "iModel/*"

  s.dependency "iService", "~> 0.0"
  s.dependency "iPromise", "~> 1.1"

end
