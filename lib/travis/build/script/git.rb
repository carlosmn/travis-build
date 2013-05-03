require 'shellwords'

module Travis
  module Build
    class Script
      module Git
        DEFAULTS = {
          git: { depth: 50, submodules: true }
        }

        def checkout
          install_source_key
          init_repo
          ch_dir
          setup_remote
          fetch_ref
          git_checkout
          submodules if submodules?
          rm_key
          sh.to_s
        end

        private

          def install_source_key
            return unless config[:source_key]

            echo "\nInstalling an SSH key\n"
            cmd "echo '#{config[:source_key]}' | base64 --decode > ~/.ssh/id_rsa", echo: false, log: false
            cmd 'chmod 600 ~/.ssh/id_rsa',                echo: false, log: false
            cmd 'eval `ssh-agent` > /dev/null 2>&1',      echo: false, log: false
            cmd 'ssh-add ~/.ssh/id_rsa > /dev/null 2>&1', echo: false, log: false

            # BatchMode - If set to 'yes', passphrase/password querying will be disabled.
            # TODO ... how to solve StrictHostKeyChecking correctly? deploy a knownhosts file?
            cmd 'echo -e "Host github.com\n\tBatchMode yes\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config', echo: false, log: false
          end

          def init_repo
            cmd "git init #{dir}", assert: true
          end

          def setup_remote
            # Don't set up the refspec as we won't be needing it
            cmd "git config remote.origin.url #{data.source_url}"
          end

          def ch_dir
            cmd "cd #{dir}", timeout: false
          end

          def rm_key
            raw 'rm -f ~/.ssh/source_rsa'
          end

          def fetch_ref
             set 'GIT_ASKPASS', 'echo', :echo => false # this makes git interactive auth fail
            ref = data.ref ? "#{data.ref}:" : ""
            cmd "git fetch --depth=#{config[:git][:depth]} origin #{ref}:", assert: true, timeout: :git_fetch_ref, fold: "git.#{next_git_fold_number}"
          end

          def git_checkout
            cmd "git checkout -qf FETCH_HEAD", assert: true, fold: "git.#{next_git_fold_number}"
          end

          def submodules?
            config[:git][:submodules]
          end

          def submodules
            self.if '-f .gitmodules' do
              cmd 'echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config', echo: false
              cmd 'git submodule init', fold: "git.#{next_git_fold_number}"
              cmd 'git submodule update', assert: true, timeout: :git_submodules, fold: "git.#{next_git_fold_number}"
            end
          end

          def clone_args
            args = "--depth=#{config[:git][:depth]}"
            args << " --branch=#{data.branch.shellescape}" unless data.ref
            args
          end

          def dir
            data.slug
          end

          def next_git_fold_number
            @git_fold_number ||= 0
            @git_fold_number  += 1
          end
      end
    end
  end
end
