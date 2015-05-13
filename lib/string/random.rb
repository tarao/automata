class String
  def randomize(len=128)
    return Array.new(len).map{ self[rand(self.length)].chr }.join
  end

  # Returns a random string
  def self.random(len=128, src=nil)
    src ||=
      [
       'a'..'z',
       'A'..'Z',
       0..9,
      ].map{|v| v.to_a}.join + '!@#$%^&*()_-=,./'
    return src.randomize(len)
  end
end
