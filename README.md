transmit.nvim is a neovim lftp wrapper written in Lua that provides SFTP functionality for uploading and removing files from remote servers

## Predefined neovim commands

`TransmitOpenSelectWindow` - Opens a popup buffer to select an sftp server and a remote for the current working directory
`TransmitRemove` - Removes the currently open file from the selected remote
`TransmitUpload` - Uploads the current file to the selected remote
## Dependencies

- https://lftp.yar.ru/
- Neovim 0.8+
## Usage

Transmit stores selected SFTP servers against working directories in a local data file,
whenever you select a sftp server via the [TransmitOpenSelectWindow](#transmit-select-window) command a new entry will be added to this data file, with the current working directory and the server you selected. If you then select a new SFTP server or Remote it will overwrite the currently selected entry with your new one.

Storing entries in a local data file means no SFTP server configurations are required to be stored in your projects repository or directory. It also means no user interaction with the data file is required.

1. Run TransmitOpenSelectWindow
2. Select an SFTP server
3. Select a remote

If you have enabled upload_on_bufwrite then any buffer writes from your current working directory will now be uploaded to your selected SFTP server/remote

Any use of TransmitRemove/TransmitUpload will now use the selected SFTP server/remote.
## Getting Started

Ensure [lftp](https://lftp.yar.ru/) is installed and executable by your PATH

Install transmit using your favorite package manager.

Example using lazy package manager

```console
{'DevDec/transmit.nvim'}
```

### Setup

Call the setup function from transmit:

```console
local transmit = require('transmit')
	transmit.setup({
	config_location = "/home/declanb/transmit_sftp/config.json",
	upload_on_bufwrite = true
})
```

For lazy package manager this can be done in the config callback:

```console
{
	'DevDec/transmit.nvim',
	config = function()
		local transmit = require('transmit')
			transmit.setup({
			config_location = "/home/declanb/transmit_sftp/config.json", 
			upload_on_bufwrite = true
		})
	end
}
```

#### Setup function options

- `config_location` - Path to local json sftp config file (used to define sftp servers) <a name="config-location"></a>
- `upload_on_bufwrite` - boolean, if true writing a file will automatically upload it to the currently selected sftp server/remote

### SFTP Server config <a name="sftp-server-config"></a>

This config file will be used to define your sftp servers, credentials and remote directories you'd like to upload to. The config file can be placed anywhere and must be defined in the setup functions [config_location option](#config-location).

#### Json config file options

Each root key of the json table is a user defined name for the sftp server you are uploading to, these will be used by the select window to pick a server for the current working directory for neovim.

Each SFTP server json table has the following options:

`credentials` - takes a json table with the following options:
	- `host` - sftp server host ip to connect to
	- `username` - sftp username
	- `identity_file` - ssh private key to use as password
`remotes` - takes a json table with user defined keys, these keys will be used by the select window to pick a remote directory to upload to, the values of the remotes should match a directory on the sftp server you want to upload to

Example json config file:

```console
{
	"server_1": {
		"credentials": {
			"host": SERVER_IP_GOES_HERE,
			"username": SFTP_USERNAME_GOES_HERE,
			"identity_file": PATH_TO_SSH_PRIVATE_KEY_GOES_HERE
		},
		"remotes": {
			"remote_1": "/",
			"remote_2": "/remote2"
		}
	},
	"server_2": {
		"credentials": {
			"host": SERVER_IP_GOES_HERE,
			"username": SFTP_USERNAME_GOES_HERE,
			"identity_file": PATH_TO_SSH_PRIVATE_KEY_GOES_HERE
		},
		"remotes": {
			"remote_3": "/remote3",
			"remote_4": "/remote4"
		}
	}
}
```

