class Specinfra::Helper::DetectOs::Plamo < Specinfra::Helper::DetectOs
  def self.detect
    if run_command('ls /usr/lib/setup/Plamo-*').success?
      { :family => 'plamo', :release => nil }
    end
  end
end
