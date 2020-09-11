# frozen_string_literal: true

require "active_support/core_ext/class/attribute"

module DeprecationToolkit
  class Collector
    include Comparable
    extend ReadWriteHelper

    class_attribute :deprecations
    self.deprecations = []
    delegate :size, to: :deprecations

    class << self
      def collect(message)
        deprecations << message
      end

      def load(test)
        new(read(test))
      end

      def reset!
        deprecations.clear
      end
    end

    def initialize(deprecations)
      self.deprecations = deprecations
    end

    def <=>(other)
      res = deprecations_without_stacktrace <=> other.deprecations_without_stacktrace
      if res != 0
        $stderr.puts << EOW
uh oh! turns out these deprecations are different!

==== current ?
#{deprecations}

=== recorded ?
#{other.deprecations}

These were normalised to:
=== current
#{deprecations_without_stacktrace}

=== other
#{other.deprecations_without_stacktrace}
EOW
      res
    end

    def deprecations_without_stacktrace
      deprecations.map do |deprecation|
        deprecation = make_paths_relative(deprecation)
        if ActiveSupport.gem_version.to_s < "5.0"
          deprecation.sub(/\W\s\(called from .*\)$/, "")
        else
          deprecation.sub(/ \(called from .*\)$/, "")
        end
      end
    end

    def make_paths_relative(deprecation)
      gem_home = DeprecationToolkit::Configuration.gem_home
$stderr.puts "removing #{gem_home} from\n#{deprecation}"
      deprecation
        .gsub(DeprecationToolkit::Configuration.project_root + '/', '')
        .gsub(gem_home, '~/.gem' + gem_home.split('.gem').last)
    end

    def -(other)
      difference = deprecations.dup
      current = deprecations_without_stacktrace
      other = other.deprecations_without_stacktrace

      other.each do |deprecation|
        index = current.index(deprecation)

        if index
          current.delete_at(index)
          difference.delete_at(index)
        end
      end

      difference
    end

    def flaky?
      size == 1 && deprecations.first['flaky'] == true
    end
  end
end
