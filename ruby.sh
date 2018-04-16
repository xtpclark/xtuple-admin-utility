#!/bin/bash
sudo apt-get -q -y install rubygems && \
sudo apt-get -q -y install rubygems-integration && \
sudo apt-get -q -y install ruby-dev

# Compass, required for theme CSS generation
sudo gem install compass

# ASCIIDoc, required for documentation generation
sudo gem install asciidoctor && \
sudo gem install coderay
