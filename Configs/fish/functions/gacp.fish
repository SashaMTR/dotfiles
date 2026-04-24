function gacp --description "Git add, commit, push dotfiles"
    if test (count $argv) -eq 0
        echo "Usage: gacp <commit message>"
        return 1
    end

    set dotfiles_dir "${DOTFILES_DIR:-$HOME/dotfiles}"

    if not test -d "$dotfiles_dir"
        echo "Error: dotfiles directory '$dotfiles_dir' not found"
        return 1
    end

    cd $dotfiles_dir
    git add .

    if git commit -m (string join " " $argv)
        git push
    end

    cd ~
end
