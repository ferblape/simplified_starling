RAILS_ENV = 'test'

require 'test/unit'
require 'rubygems'
require 'active_record'
require 'mocha'
require 'ruby-debug'

# Logger mock
class Logger
  def initialize(file); end
  def warn(s); end
  def info(s); end
  def error(s); end    
end

# Starling mock
class Starling
  def initialize(address)
    @queues = {}
  end
  
  def get(queue)
    @queues[queue] ||= []
    YAML.load(@queues[queue].pop)
  end
  
  def set(queue, job)
    @queues[queue] ||= []
    @queues[queue] << job.to_yaml    
  end
  
  def sizeof(queue)
    @queues[queue] ||= []
    @queues[queue].size
  end
end

# Mocking stuff
STARLING_CONFIG = {}
STARLING_LOG = Logger.new('wadus')
STARLING = Starling.new('wadus.host:11211')

require 'simplified_starling'

# Mocked configuration with multiple queues
module SimplifiedStarling
  def self.config(queue = nil)
    config = {
      'queue_1' => {
        'queue_pid_file' => 'pid_queue_1.pid',
        'queue_path' => 'queue_path_1'
      },
      'queue_2' => {
        'queue_pid_file' => 'pid_queue_2.pid',
        'queue_path' => 'queue_path_2'      
      }
    }
    queue ? config[queue] : config
  end
end

require 'simplified_starling/active_record'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

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
    queue = SimplifiedStarling.default_queue
    post = Post.find(:first)
    assert !post.status
    Post.push('publish_all')
    Simplified::Starling.pop(queue)
    post = Post.find(:first)
    assert post.status
    Post.push('unpublish_all')
    post = Post.find(:first)
    assert post.status
    Simplified::Starling.pop(queue)
    post = Post.find(:first)
    assert !post.status
  end
  
  def test_should_push_an_instance_method_on_post
    queue = SimplifiedStarling.default_queue
    post = Post.find(:first)
    assert !post.status
    Post.find(:first).push('rebuild')
    Simplified::Starling.pop(queue)
    post = Post.find(:first)
    assert post.status
  end
  
  def test_should_insert_100_items_and_count
    Post.destroy_all
    assert_equal Post.count, 0
    queue = SimplifiedStarling.default_queue
    100.times { Post.push('generate') }
    assert_equal 100, Simplified::Starling.stats(queue).last
    100.times { Simplified::Starling.pop(queue) }
    sleep 10
    assert_equal 0, Simplified::Starling.stats(queue).last
    assert_equal 100, Post.count
  end
  
  def test_options_queue
    default_queue = SimplifiedStarling.default_queue
    queue = SimplifiedStarling.queues.last
    assert default_queue != queue
    Post.push(:generate, { :title => "Joe", :queue => queue })
    Simplified::Starling.pop(default_queue)
    assert_nil Post.find_by_title("Joe")
    Simplified::Starling.pop(queue)
    assert Post.find_by_title("Joe")
  end
  
  def test_class_methods_support_options
    queue = SimplifiedStarling.default_queue
    Post.push(:generate, { :title => "Joe" })
    Simplified::Starling.pop(queue)
    assert Post.find_by_title("Joe")
  end
  
  def test_instance_methods_support_options
    queue = SimplifiedStarling.default_queue
    post = Post.find(:first)
    assert post.reload.title != "Joe"
    post.push(:update_title, { :title => "Joe" })
    Simplified::Starling.pop(queue)
    assert post.reload.title == "Joe"
  end
  
  def test_customized_push_methods_for_each_queue
    post = Post.find(:first)
    SimplifiedStarling.queues.each do |queue|
      post.send("push_in_#{queue}".to_sym, :update_title, { :title => "Joe_#{queue}" })
      Simplified::Starling.pop(queue)
      assert post.reload.title == "Joe_#{queue}"
    end
  end

end