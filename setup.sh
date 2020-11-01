if [ "$SHELL" != "/usr/bin/zsh" ]; then
	# Install zsh shell
	sudo apt-get install zsh

	# Install oh-my-zsh
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi;

