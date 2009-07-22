RAILS_ENV = 'test'

require 'test/unit'
require 'rubygems'
require 'active_record'
require 'mocha'
require 'ruby-debug'

# Mocking stuff
STARLING_CONFIG = {}
STARLING_CONFIG['queue'] = 'test'

class Logger
  def initialize(file); end
  def warn(s); end
  def info(s); end
  def error(s); end    
end

class Starling
  def initialize(address)
    @memory = {}
  end
  
  def get(queue)
    @memory[queue] ||= []
    YAML.load(@memory[queue].pop)
  end
  
  def set(queue, job)
    @memory[queue] ||= []
    @memory[queue] << job.to_yaml    
  end
  
  def sizeof(queue)
    @memory[queue] ||= []
    @memory[queue].size
  end
end

require 'simplified_starling'
require 'simplified_starling/active_record'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :posts do |t|
      t.string :title, :nil => false
      t.boolean :status, :default => false
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Post < ActiveRecord::Base

  def rebuild
    self.update_attributes :status => true
  end

  def self.publish_all
    update_all :status => true
  end

  def self.unpublish_all
    update_all :status => false
  end

  def self.generate(options = {})
    create :title => options[:title], :status => false
  end

  def update_title(options = {})
    update_attribute :title, options[:title]
  end

end

class SimplifiedStarlingTest < Test::Unit::TestCase

  def setup
    setup_db
    Post.create(:title => "First Post")
  end

  def teardown
    teardown_db
  end

  def test_array_class_is_not_affected_by_method_overwrite
    a = [ "a", "b", "c" ]
    a.push("d", "e", "f")
    assert_equal a, ["a", "b", "c", "d", "e", "f"]
  end
  
  def test_should_push_a_class_method_on_post
    post = Post.find(:first)
    assert !post.status
    Post.push('publish_all')
    Simplified::Starling.pop('test')
    post = Post.find(:first)
    assert post.status
    Post.push('unpublish_all')
    post = Post.find(:first)
    assert post.status
    Simplified::Starling.pop(STARLING_CONFIG['queue'])
    post = Post.find(:first)
    assert !post.status
  end
  
  def test_should_push_an_instance_method_on_post
    post = Post.find(:first)
    assert !post.status
    Post.find(:first).push('rebuild')
    Simplified::Starling.pop(STARLING_CONFIG['queue'])
    post = Post.find(:first)
    assert post.status
  end
  
  def test_should_insert_100_items_and_count
    Post.destroy_all
    assert_equal Post.count, 0
    100.times { Post.push('generate') }
    assert_equal 100, Simplified::Starling.stats.last
    100.times { Simplified::Starling.pop(STARLING_CONFIG['queue']) }
    sleep 10
    assert_equal 0, Simplified::Starling.stats.last
    assert_equal 100, Post.count
  end
  
  def test_class_methods_support_options
    Post.push(:generate, { :title => "Joe" })
    Simplified::Starling.pop(STARLING_CONFIG['queue'])
    assert Post.find_by_title("Joe")
  end
  
  def test_instance_methods_support_options
    post = Post.find(:first)
    assert post.reload.title != "Joe"
    post.push(:update_title, { :title => "Joe" })
    Simplified::Starling.pop(STARLING_CONFIG['queue'])
    assert post.reload.title == "Joe"
  end

  def test_when_raises_active_record_statement_invalid_exception_job_does_not_get_lost    
    post = Post.find(:first)
    assert post.reload.title != "Joe"
    post.push(:update_title, { :title => "Joe" })
    ActiveRecord::Base.connection.disconnect!
    Simplified::Starling.pop(STARLING_CONFIG['queue'])
    assert post.reload.title == "Joe"
  end

end