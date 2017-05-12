# coding: utf-8
require_relative 'report/counter'

# Report objects are used to get hash of a report status by to_hash().
# @example
#   src = Report::Source::Post.new( ... )
#   hash = Report::Record.new(src, ...).to_hash()
module Report
  class Source
    class Manual
      attr_reader :data
      alias_method :solved, :data

      # Report object that can be manually created.
      # It can be used as dummy report by substituting [] to data.
      # @param [Array<String>] the list of solved reports.
      # @param [Array<Symbol>] optional keys appear in the report log file.
      # @param [Time] timestamp that will be hashed
      # @example
      #   manual = Report::Source::Manual.new(["Ex.1.2"], [:log], time)
      #   dummy = Report::Source::Manual.new([], [], time)
      def initialize(data, optional, timestamp)
        @data = data || []
        @optional = optional
        @timestamp = timestamp
      end

      # Queries whether the status of the report is valid or not.
      # @return [Boolean] false if data is empty
      def status?() return !@data.empty? end

      # Dummy function.
      # @param [key]
      # @return [nil]
      def optional(key) return nil end

      # Returns the minimum hash.
      # @return [Hash{Symbol => Value}]
      def to_hash()
        hash = { 'status' => status?, 'timestamp' => @timestamp }
        @optional.each{|k| hash[k.to_s] = optional(k)}
        return hash
      end
    end

    class Post
      attr_reader :data

      # Report object that is posted by a user.
      # It doesn't include reports list.
      # @param [Hash{Symbol => String}] data entry of the report log file
      # @param [Array<Symbol>] optional keys appear in the report log file
      def initialize(data, optional)
        @data = data
        @optional = optional
      end

      # Queries whether the status of the report is valid or not.
      # @return [String,Nil] return nil if the status is invalid
      def status?() @data['status'] end

      # Returns the list of solved reports.
      # @return [Array<String>] the list of solved reports
      def solved() @data['report'] || [] end

      # Query a value by the key in the log file.
      # @param [Symbol] a key in log file.
      # @return [Value] the value corresponding to the key.
      def optional(key) return @data[key.to_s] end

      # Returns the hash of the report.
      # @return [Hash{Symbol => Value}] hash.
      def to_hash()
        hash = {
          'status'         => status?,
          'timestamp'      => @data['timestamp'],
          'submit'         => @data['id'],
          'initial_submit' => @data['initial_submit'],
          'delay'          => @data['delay'],
        }
        @optional.each{|k| hash[k.to_s] = optional(k)}
        return hash
      end
    end
  end

  # Wrapper class for Source objects for the purpose of getting solved
  # reports list.
  class Solved
    # @param [Source::Manual, Source::Post] Source object.
    def initialize(src)
      @src = src
    end

    # Add 'solved' key and corresponding value to the original hash.
    # @return [Hash{Symbol => Value}] hash includes following key and value.
    # - solved: the sorted list of solved exercises.
    def to_hash()
      hash = @src.to_hash
      solved = @src.solved.map(&:to_ex)
      hash['solved'] = solved.sort
      return hash
    end
  end

  # Wrapper class for Source objects for the purpose of getting
  # unsolved and optional reports list
  class Record
    # @param [Source::Manual, Source::Post] Source object.
    # @scheme [Hash{Symbol => Hash{Symbol => Int}}] report list of scheme file.
    def initialize(src, scheme)
      @src = src
      @scheme = scheme
    end

    # If the status is null, return the original hash; otherwise, add
    # 'unsolved' and 'optional+level' keys and corresponding values to
    # the original hash.
    # @return [Hash{Symbol => Value}] hash includes following keys and values.
    # - unsolved: the sorted list of unsolved exercises.
    # - optional+level: the sorted list of solved optional exercises according to each level.
    def to_hash()
      hash = @src.to_hash
      return hash unless @src.status?

      solved = @src.solved.map(&:to_ex)
      counter = Counter.new(@scheme)
      solved.each{|ex| counter.vote(ex)}

      insuf = counter.insufficient
      hash['unsolved'] = insuf.sort{|a,b| a[0] <=> b[0]}.map{|x,y| [x.to_s,y]}
      counter.overflow.each do |level, solved|
        hash['optional'+level] = solved.sort{|a,b| a <=> b}.map(&:to_s)
      end

      return hash
    end
  end

  # May be unused.
  class Log
    def initialize(src)
      @src = src
    end

    def to_hash() return @src.log end
  end
end
