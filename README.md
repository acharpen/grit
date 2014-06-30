# grit

A ruby tool to analyse Git repositories

## Installation

To use grit you need first to install the development version of [rugged](https://github.com/libgit2/rugged) (ruby libgit's bindings).

To ensure having a rugged installation that can clone repositories through SSL, please use the following procedure. First checks if you have cmake and openssl (including development headers) installed on your system. Then, perform the following commands.

```
git clone https://github.com/libgit2/rugged.git
cd rugged
git submodule init
git submodule update
gem build rugged.gemspec
gem install rugged-0.19.0.gem
```

Finally install the following gems.

```
gem install thor
```
You can now clone grit using the following command.

```
git clone https://github.com/jrfaller/grit.git
```

The grit tool is in the lib folder. Don't hesitate to create a link to grit.rb to be able to launch it in any repository.
