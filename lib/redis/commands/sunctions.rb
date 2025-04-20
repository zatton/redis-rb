# frozen_string_literal: true

class Redis
  module Commands
    module Functions
      def function(subcommand, *args)
        subcommand = subcommand.to_s.downcase

        send_command([:function, subcommand] + args)
      end

      def fcall(*args)
        _fcall(:fcall, args)
      end

      def evalsha(*args)
        _eval(:evalsha, args)
      end

      private

      def _fcall(cmd, args)
        script = args.shift
        options = args.pop if args.last.is_a?(Hash)
        options ||= {}

        keys = args.shift || options[:keys] || []
        argv = args.shift || options[:argv] || []

        send_command([cmd, script, keys.length] + keys + argv)
      end
    end
  end
end
