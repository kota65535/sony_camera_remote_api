require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

# The available camera models for shooting test
# model_tags = [:HDR_AZ1, :FDR_X1000V, :DSC_RX100M4, :ILCE_QX1]
model_tags = [:DSC_RX100M4, :ILCE_QX1, :FDR_X1000V]

# The available camera models for contents test
model_tags_contents = [:HDR_AZ1]

# The available camera models for contents test
model_tag_reconnection = :HDR_AZ1

# The available camera model for contents preparing
model_tag_prepare = :HDR_AZ1


def define_model_tasks(model_tags, *namespaces)
  namespaces.map! { |n| n.to_s }
  sub_pattern = namespaces.join '/'
  sub_task_name = namespaces.join ':'
  model_tags.each do |m|
    desc "Run #{sub_task_name} test by model '#{m}'"
    RSpec::Core::RakeTask.new(m) do |t|
      t.pattern = "spec/#{sub_pattern}/*_spec.rb"
      t.rspec_opts = "--tag #{m.to_s}"
    end
    RSpec::Core::RakeTask.new("#{m}-of") do |t|
      t.pattern = "spec/#{sub_pattern}/*_spec.rb"
      t.rspec_opts = "--tag #{m.to_s} --only-failures"
    end
  end
  desc "Run #{sub_task_name} test by all models, retrying until all examples passes."
  task :all do
    model_tags.each do |m|
      unless system "rake #{sub_task_name}:#{m}"
        while !system "rake #{sub_task_name}:#{m}-of"
        end
      end
    end
  end
end


#--------------------Rake Tasks--------------------

# rake
task :default => :all


# rake all
task :all do
  ENV['COVERAGE'] = 'true'
  %w(shooting group contents reconnection other).each do |t|
    Rake::Task[t].invoke
  end
end


# rake all_but_group
task :all_but_group do
  ENV['COVERAGE'] = 'true'
  %w(shooting contents reconnection other).each do |t|
    Rake::Task[t].invoke
  end
end


# rake shooting
# rake shooting:lib
# rake shooting:client
# rake shooting:lib:<model>
# rake shooting:client:<model>
desc "Same as 'rake shooting:all'"
task :shooting => ['shooting:all']
namespace :shooting do
  namespace :lib do
    define_model_tasks model_tags, :shooting, :lib
  end
  namespace :client do
    define_model_tasks model_tags, :shooting, :client
  end
  desc "Same as 'rake shooting:lib:all'"
  task :lib => ['lib:all']
  desc "Same as 'rake shooting:client:all'"
  task :client => ['client:all']
  desc "Run shooting test of lib/client for all models"
  task :all => %w(lib client)
end


desc "Same as 'rake group:all'"
task :group => ['group:all']
namespace :group do
  define_model_tasks model_tags, :group
end


# rake contents
# rake contents:lib
# rake contents:client
# rake contents:lib:<model>
# rake contents:client:<model>
# rake contents:prepare
desc "Same as 'rake contents:all'"
task :contents => ['contents:all']
namespace :contents do
  namespace :lib do
    define_model_tasks model_tags_contents, :contents, :lib
  end
  namespace :client do
    define_model_tasks model_tags_contents, :contents, :client
  end

  desc "Same as 'rake contents:lib:all'"
  task :lib => ['lib:all']
  desc "Same as 'rake contents:client:all'"
  task :client => ['client:all']
  desc "Run contents test of lib/client for all camera models"
  task :all => %w(lib client) do
    puts 'About to run CONTENTS TEST! Please insert contents-prepared SD.'
  end

  # rake contents:prepare
  desc "Prepare contents for contents test"
  RSpec::Core::RakeTask.new(:prepare) do |t|
    t.pattern = 'spec/contents/prepare_contents.rb'
    t.rspec_opts = "--tag #{model_tag_prepare}"
  end
end


# rake reconnection
desc "Run reconnection test for lib/client"
RSpec::Core::RakeTask.new(:reconnection) do |t|
  t.pattern = 'spec/reconnection/**/*_spec.rb'
  t.rspec_opts = "--tag #{model_tag_reconnection}"
end


# rake other
desc "Run other test for lib/client"
RSpec::Core::RakeTask.new(:other) do |t|
  t.pattern = 'spec/other/**/*_spec.rb'
end
