if [ -z "$USER" ]; then
  USER=root
fi

git config --global init.defaultBranch main
git config --global user.email "$USER@ibtisam-iq.com"
git config --global user.name "$USER"
