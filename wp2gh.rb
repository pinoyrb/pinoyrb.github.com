require 'rubygems'
require 'hpricot'
require 'time'
require 'yaml'
require 'ruby-debug'

class Blog
  attr_accessor :title, :description, :posts

  def initialize
    @posts = []
   end
end

class Post
  attr_accessor :title, :filename, :content, :published_at, :author
end


def load_wp(wpfile)
  blog = Blog.new
  
  doc = open(wpfile) { |f| Hpricot(f) }
  (doc/:channel).each do |info|
    blog.title = (info/:title).first.inner_html
  
    (info/:item).each do |item|
      post = Post.new
      post.title = (item/:title).inner_html
  
      pubdate = Time.parse((item/'wp:post_date').inner_html).strftime('%Y-%m-%d')
      post.published_at = pubdate
  
      titleize = post.title.strip.downcase.
                   gsub(/\s+/, '-').
                   gsub(/\//, '-').
                   gsub(/[:,\"\'\?]+/, '').
                   gsub(/&#?\S+;/, '').     # html entity codes
                   gsub(/\342\200\231/, '') # right single quote
  
      post.filename = "#{pubdate}-#{titleize}"
      post.content  = (item/'content:encoded').inner_text.gsub(/\015/, '') # remove ^M
      post.author   = (item/'dc:creator').inner_text

      blog.posts << post
    end
  end

  blog
end

def save_to_jekyll(blog)
  blog.posts.each do |p|
    File.open("./_posts/#{p.filename}.textile", 'w') do |f|
      f.puts "---"
      f.puts "layout: post"
      f.puts "title:        '#{p.title}'"
      f.puts "author:       '#{p.author}'"
      f.puts "published_at: #{p.published_at}"
      f.puts "---"
    
      f.puts
      f.puts "<h1> {{ page.title }} </h1>"
      f.puts
      f.puts "<p class='meta'>by {{ page.author }} &middot; {{ page.published_at }} </p>"
    
      f.puts
      f.puts p.content
    end
  end
end

def save_to_yaml(blog)
  blog.posts.each do |p|
    File.open("_raw/#{p.filename}.yaml", "w") do |f|
      f.puts "title:        '#{p.title}'"
      f.puts "author:       '#{p.author}'"
      f.puts "published_at: '#{p.published_at}'"
      f.puts "filename:     '#{p.filename}'"
      f.puts "content: |-"
      f.puts p.content.gsub(/^/, '  ')
    end 
  end
end


def load_raw
  blog = Blog.new

  Dir["_raw/*"].each do |f|
    y = YAML.load_file(f)
  
    p = Post.new
    p.title        = y['title']
    p.published_at = y['published_at']
    p.content      = y['content']
    p.filename     = y['filename'] 
  
    blog.posts << p
  end

  blog
end

save_to_yaml(load_wp(ARGV[0]))
save_to_jekyll(load_raw)
