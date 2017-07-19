require 'commander'
require 'u3d_core'
require 'u3d/commands'

HighLine.track_eof = false

module U3d
  # CLI using commander gem for u3d
  class CommandsGenerator
    include Commander::Methods
    UI = U3dCore::UI

    def self.start
      # FastlaneCore::UpdateChecker.start_looking_for_update("gym")
      new.run
    ensure
      # FastlaneCore::UpdateChecker.show_update_status("gym", Gym::VERSION)
    end

    def extract_run_args(args = ARGV)
      both_args = [[], []]
      idx = 0
      args.each do |arg|
        if arg == '--'
          idx = 1
          next
        end
        both_args[idx] << arg
      end
      args.replace both_args[0]
      both_args[1]
    end

    def convert_options(options)
      o = options.__hash__.dup
      o.delete(:verbose)
      o
    end

    def run
      program :version, U3d::VERSION
      program :description, U3d::DESCRIPTION
      program :help, 'Author', 'Jerome Lacoste <jerome@wewanttoknow.com>'
      program :help_formatter, :compact

      global_option('--verbose') { $verbose = true }

      command :run do |c|
        # Intended for backward compatibilty purposes for run command
        # Meant to fetch options after '--' unknown by CommandsGenerator
        run_args = extract_run_args

        c.syntax = 'u3d run [-u | --unity_version <version>] [ -- <run_args>]'
        c.description = 'Run unity'
        U3dCore::CommanderGenerator.new.generate(U3d::Options.available_run_options)
        c.action do |_args, options|
          Commands.run(options: convert_options(options), run_args: run_args)
        end
      end

      command :installed do |c|
        c.syntax = 'u3d installed [-p | --packages]'
        c.option '-p', '--packages', 'Lists installed packages as well'
        c.description = 'List installed version of Unity3d'
        c.action do |_args, options|
          Commands.list_installed(options: convert_options(options))
        end
      end

      command :available do |c|
        oses = U3dCore::Helper.operating_systems
        c.syntax = 'u3d available [-r | --release_level <level>] [-o | --operating_system <OS>] [-u | --unity_version <version>] [-p | --packages] [-f | --force]'
        levels = Commands::release_levels
        c.option '-r', '--release_level STRING', String, "Checks for availability on specific release level [#{levels.join(',')}]"
        c.option '-o', '--operating_system STRING', String, "Checks for availability on specific OS [#{oses.join(', ')}]"
        c.option '-u', '--unity_version STRING', String, 'Checks if specified version is available'
        c.option '-p', '--packages', 'Lists available packages as well'
        c.option '-f', '--force', 'Force refresh list of available versions'
        c.description = 'List download-ready versions of Unity3d'
        c.action do |_args, options|
          options.default packages: false
          Commands.list_available(options: convert_options(options))
        end
      end

      command :download do |c|
        c.syntax = 'u3d download <version> [ [-p | --packages <package> ...] | [-a | --all] ] [ [-n | --no_install] [-i | --installation_path <path>] ]'
        c.description = "Download (and install) Unity3D packages.\n\n  The 'version' argument can be a specific version number, such as 5.6.1f1, or an alias in [#{Commands::release_letter_mapping.keys.join(',')}]"
        c.option '-p', '--packages PACKAGES', Array, 'Specifies which packages to download. Overriden by --all'
        c.option '-i', '--installation_path PATH', String, 'Specifies where package(s) will be installed. Overriden by --no_install'
        c.option '-a', '--all', 'Download all available packages'
        c.option '-n', '--no_install', 'No installation after download success'
        c.action do |args, options|
          options.default all: false
          options.default no_install: false
          Commands.download(args: args, options: convert_options(options))
        end
      end

      command :local_install do |c|
        c.syntax = 'u3d local_install <version> [ [-p | --packages <package> ...] | [-a | --all] ] [-i | --installation_path <path>]'
        c.description = 'Install downloaded version of unity'
        c.option '-p', '--packages PACKAGES', Array, 'Specifies which packages to install. Overriden by --all'
        c.option '-i', '--installation_path PATH', String, 'Specifies where package(s) will be installed.'
        c.option '-a', '--all', 'Install all downloaded packages'
        c.action do |args, options|
          Commands.local_install(args: args, options: convert_options(options))
        end
      end

      command :login do |c|
        c.syntax = 'u3d login [-u | --user <username>]'
        c.description = 'Stores credentials for future use'
        c.option '-u', '--user USER', String, 'Specifies wich user will be logged in'
        c.action do |_args, options|
          Commands.login(options: convert_options(options))
        end
      end

      command :analyze_log do |c|
        c.syntax = 'u3d analyze_log <logfile>'
        c.description = 'Run a saved logfile through the log filter'
        c.action do |args, _options|
          Commands.local_analyze(args: args)
        end
      end

      default_command :run

      run!
    end
  end
end
