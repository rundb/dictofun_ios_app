# Dictofun iOS App

[Dictofun](https://github.com/rundb/dictofun) is a portable device that has one task and one task only - start recording of voice ASAP after the record button is presse, and after the button release it attempts to send the data to the paired device (phone or laptop).

This application is the iPhone counterpart of the communication system.

From here on this iPhone application shall be referred to as `application`, Dictofun shall be referred to as `device`.

## High-level requirements

### 1. Communication

#### 1.1. Communication establishment.

`Application` should provide convenient and clear way of connecting to Dictofun, disconnecting from it, pairing with it and removing the pairing.

1.1.1. Multiple `devices` can be close to phone with `application`. `Application` should provide a way to distinguish a particular device out of multiple.

**NB**. Req. 1.1.1 might need design changes in the `device` software.

1.1.2. `Application` should store the connection status and display it to the user.

1.1.3. `Application` can connect and pair with only one `device`.

#### 1.2. File transfer communication

`Application` should provide seemless operation of files' transfer from a paired `device` to the phone.

1.2.1. `Application` should implement BLE Central funcions for [BLE File Transfer Service](https://github.com/rundb/dictofun/blob/master/firmware/src/lib/ble_fts/README.md)

1.2.2 `Application` should be capable of performing FTS functions in both background and foreground mode.

1.2.2.1. Background operation. `Application` should connect to an active paired `device` close by and download all new records that have not yet been downloaded to the phone. 

1.2.2.2. Foreground operation. `Application` should implement similar behavior to p.2.2.1, and additionally display the connection status, current FTS operation status, amount of newly discovered records and a download progress.

1.2.2.3. If application went from background operation to a foreground operation, FTS operations should continue uninterrupted, and interface of application should update according to p.2.2.2.

#### 1.3. Additional communication functions.

`Application` should provide additional communication methods in order to provide a better user experience during the usage of `device`.

1.3.1. `Application` should periodically request `device`-es battery level and display it in the UI.

1.3.1.1. Battery level should be requested at least once per every connection.

1.3.1.2. Low battery level should be reported to the user.

1.3.1.3. Any other communication functions should be prohibited in the event of low battery level.

1.3.2. `Application` should provide correct current time to the `device`.

1.3.2.1. `Device`'es time should be different from current phone 5 seconds or less.

1.3.2.2. Current phone time should be used, independent from the current time zone.

#### 1.4. Firmware update functions.

`Application` should provide DFU (`Distant Firmware Update`) functionality. 

1.4.1. `Application` should provide BLE-Central side of DFU protocol.

1.4.2. `Application` should periodically check if newer firmware version has been released. If the newer firmware has been released, `Application` should suggest user to trigger an update, and, if user agrees, update `device`'es firmware to the latest version.

1.4.2.1. Firmware update progress should be displayed in the application UI.

1.4.2.2. Current firmware update status should be displayed in the application UI (connected/disconnected, is bootloader or application active, etc.).

1.4.3. `Application` should provide a menu entry, where the current hardware and firmware versioning information of the `device` is displayed.

### 2. Sound data operations

`Application` should provide a sufficient set of functions to manipulate the voice records, transferred from the `device`.

2.1. `Application` should display list of all records in a reversed chronological order (latest one shown first).

2.2. Each entry in the list should display: record date and time, playback symbols (play/pause, duration and playback progress), part or the whole transcribed text.

2.3. `Application` should be capable of removing the records.

2.3.1. If a record is removed, it shouldn't trigger a download from the device at the next communication session. 