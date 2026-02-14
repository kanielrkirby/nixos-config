{ pkgs, ... }:

pkgs.writers.writePython3Bin "," {
  libraries = [ ];
} /* python */ ''
  import sys
  import os
  import subprocess


  def show_help():
      help_text = """Usage: , [options] <package>[,package2,...] [-- <cmd>]

  Run commands from Nix packages without permanently installing them.

  Examples:
    , tealdeer                    # run tealdeer binary
    , tealdeer --help             # run tealdeer with args
    , -s tealdeer                 # spawn shell with tealdeer available
    , tealdeer -- tldr --help     # run tldr from tealdeer package
    , ripgrep,fd                  # spawn shell with rg and fd available
    , ripgrep,fd -- rg foo        # run rg with ripgrep and fd in scope

  Options:
    -h, --help                    # show this help message
    -s, --shell                   # spawn shell instead of running binary

  The comma operator automatically allows unfree/insecure packages.
  """
      print(help_text)


  def main():
      args = sys.argv[1:]

      # Handle help flags
      if not args or args[0] in ['-h', '--help']:
          show_help()
          sys.exit(0)

      # Handle shell flag
      shell_mode = False
      if args[0] in ['-s', '--shell']:
          shell_mode = True
          args = args[1:]
          if not args:
              print("Error: No package specified after -s flag",
                    file=sys.stderr)
              print("Run ', --help' for usage information.", file=sys.stderr)
              sys.exit(1)

      # Parse packages and command
      packages_arg = args[0]
      remaining_args = args[1:]

      # Validate package argument
      if packages_arg.startswith('-'):
          print(f"Error: Invalid package name '{packages_arg}'",
                file=sys.stderr)
          print("Run ', --help' for usage information.", file=sys.stderr)
          sys.exit(1)

      # Count commas to determine number of packages
      package_count = packages_arg.count(',') + 1
      packages = packages_arg.split(',')

      # Validate package names
      for pkg in packages:
          if not pkg.strip():
              msg = f"Error: Empty package name in '{packages_arg}'"
              print(msg, file=sys.stderr)
              print("Run ', --help' for usage information.",
                    file=sys.stderr)
              sys.exit(1)

      # Build nixpkgs references
      nixpkgs_refs = [f"nixpkgs#{pkg}" for pkg in packages]

      # Set up environment with NIXPKGS_ALLOW flags
      env = os.environ.copy()
      env['NIXPKGS_ALLOW_UNFREE'] = '1'
      env['NIXPKGS_ALLOW_INSECURE'] = '1'
      env['NIXPKGS_ALLOW_BROKEN'] = '1'
      env['NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM'] = '1'

      # Determine command to run
      if shell_mode:
          # Explicit shell mode: , -s tealdeer
          if remaining_args and remaining_args[0] == '--':
              # , -s tealdeer -- rg foo
              if len(remaining_args) < 2:
                  # , -s tealdeer -- (just spawn shell)
                  cmd = ['nix', 'shell'] + nixpkgs_refs
              else:
                  cmd = (['nix', 'shell'] + nixpkgs_refs +
                         ['--command'] + remaining_args[1:])
          else:
              # , -s tealdear (spawn shell)
              cmd = ['nix', 'shell'] + nixpkgs_refs
      elif package_count == 1:
          # Single package
          if remaining_args and remaining_args[0] == '--':
              # , tealdeer -- tldr --help
              if len(remaining_args) < 2:
                  msg = "Error: No command specified after '--'"
                  print(msg, file=sys.stderr)
                  print("Run ', --help' for usage information.",
                        file=sys.stderr)
                  sys.exit(1)
              cmd = (['nix', 'shell', nixpkgs_refs[0], '--command'] +
                     remaining_args[1:])
          elif not remaining_args:
              # , tealdeer (run the package binary directly)
              cmd = ['nix', 'run', nixpkgs_refs[0]]
          else:
              # , tealdeer --help (run with args)
              cmd = ['nix', 'run', nixpkgs_refs[0], '--'] + remaining_args
      else:
          # Multiple packages
          if remaining_args and remaining_args[0] == '--':
              # , ripgrep,fd -- rg foo
              if len(remaining_args) < 2:
                  # , ripgrep,fd -- (just spawn shell)
                  cmd = ['nix', 'shell'] + nixpkgs_refs
              else:
                  cmd = (['nix', 'shell'] + nixpkgs_refs +
                         ['--command'] + remaining_args[1:])
          else:
              # , ripgrep,fd (spawn shell with packages)
              cmd = ['nix', 'shell'] + nixpkgs_refs

      # Execute the nix command
      try:
          result = subprocess.run(cmd, env=env)
          sys.exit(result.returncode)
      except FileNotFoundError:
          print("Error: 'nix' command not found", file=sys.stderr)
          sys.exit(1)
      except KeyboardInterrupt:
          sys.exit(130)


  if __name__ == '__main__':
      main()
''
