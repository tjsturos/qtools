# quilibrium-node-setup

To init:
```bash
git clone https://github.com/tjsturos/qtools.git
cd qtools
./qtools.sh init
source ~/.bashrc # to get autocompete working
```

Then you can run the command from anywhere on your system:
```bash
qtools <command>
```

For a complete list of available commands and their usage, see the [Commands Documentation](docs/Commands.md).

## Config & Initialization
There are quite a few settings in the [config file](qtools/config.sample.yml).

Upon initializing, the init script will create the `config.yml` script as copy of the sample file, and then update some of the config to reflect the current user (who will be running the service).

## Install the node
As your current user, run:
```bash
qtools complete-install
```

This may prompt you for your user password, but should complete the install after that.

## Backups
Backups can be enabled if you have a server that you want to back up to.
Modify the qtools config file to reflect this.  You will need to import the private key to your server and reference it in the config.

## Remote setup
Remote setup/automation isn't quite possible due to the incomplete tool set that is designed for that.

There are also other shortcomings, i.e. needing to connect to your hosting provider to automate getting your IP addresses to connect to and install this tool on without you needing to actually do this one-by-one.

Qtools is mostly designed for installing and managing your node in a terminal.

Rest assured, there will be some tool to aid in this, but it will likely target large providers rather than many small ones.

Currently, there is the referenced incomplete set that does work (mostly) but due to the following limitation, it isn't possible to actually complete the setup without manually SSH'ing in to each server and typing `qtools/qtools.sh complete-install`.


### Known Issues
If you run these commands via ssh rather than in the node's terminal, `yq` commands that read/modify the config file hang and will not terminate.

I've filed [a bug report here](https://github.com/mikefarah/yq/issues/2103).

If you ssh in to the server and run these commands manually or with cron tasks, they work as expected.


