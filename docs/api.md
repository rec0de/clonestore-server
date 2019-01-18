# API documentation v0.1.0

## Versioning

The API specification follows semantic versioning principles.  
Patch version bumps and minor version bumps should be backwards compatible (1.2.1 to 1.3.1 or 1.3.1 to 1.3.2) while incompatible versions result in a major version change (1.2.1 to 2.0.0).
The current API version can be queried by a GET request to the API root.

## Authentication

At this time, not authentication mechanisms are in place.

## Methods

The API consists of three endpoints, `plasmid`, `storage` and `print`, as well as the root endpoint.

### Server info

`GET /`

Returns a JSON Object including the server version.

| Property   | Format | Description                                |
| ---------- | ------ | ------------------------------------------ |
| type       | text   | Constant string `clonestore-server`        |
| version    | text   | Current version of the server              |

### Viewing a plasmid

`GET /plasmid/[id]`

Returns a JSON representation of the requested plasmid if found, or a 404 error otherwise.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the requested plasmid, format `pXY0123` |

### Creating a plasmid

`POST /plasmid`

Adds a new plasmid to the database. If the plasmid supplied does not have an ID, a new one will be generated using sequential numbering. The provided plasmid data should contain values for all fields marked as required in the data format documentation.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| data       | text   | JSON-representation of the plasmid to be added     |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `plasmidID`                        |
| id         | text   | Unique ID of the inserted plasmid, format `pXY123`  |

### Archiving a plasmid

`DELETE /plasmid/[id]`

Mark a plasmid as archived without actually deleting any information. This frees the plasmid's storage location and prevents it from showing up in search results when not explicitly requested. Viewing the plasmid data using its unique ID will still work as before.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the requested plasmid, format `pXY123` |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Modifying plasmid data

### Setting a plasmid storage location

`PUT /storage/[location]`

Marks the given storage slot as occupied by the given plasmid. The location has to be free for the request to succeed. Storage locations can be arbitrary strings, so care should be taken (on the client side) that location formatting is uniform. Otherwise two locations referring to the same physical location may store different plasmids, creating inconsistencies.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| location   | text   | Canonical name of the storage slot, must be unique |
| entry      | text   | Unique ID of the plasmid to be stored              |
| host       | text   | Bacterial host of the sample to be stored          |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Querying a storage location

`GET /storage/loc/[location]`

Retrieves the ID of the plasmid stored in the given location. Returns a 404 Error if the storage slot is empty.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| location   | text   | Canonical name of the storage slot                 |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `storageLocationContent`           |
| id         | text   | Unique ID of the stored plasmid, format `pXY123`   |
| host       | text   | Bacterial host of the stored plasmid               |

### Freeing a plasmid storage location

`DELETE /storage/[location]`

Marks the given storage slot as empty and available for new plasmids.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| location   | text   | Canonical name of the storage slot                 |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Searching plasmids

### Configuring the printer

`PUT /print`

Updates or creates the printer used to print labels. In the process, any printer that is already connected will be removed. While only the printer URL and the shared secret are required, a name and location can be set as well.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| url        | text   | URL the printer API can be reached at              |
| authKey    | text   | Shared secret used to authenticate to the printer  |
| name       | text   | Human-readable name of the printer, optional       |
| location   | text   | Human-readable location of the printer, optional   |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |

### Querying printer status

`GET /print`

Checks if the currently connected printer (not the device hosting the print server) is turned on and ready to print.

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `printerStatus`                    |
| online     | bool   | `true` if the printer is online and ready, `false` otherwise  |

### Printing stickers

`POST /print/[id]`

Sends a print request for the selected plasmid to the printer. This request may take a long time to complete.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the requested plasmid, format `pXY123` |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| type       | text   | Constant string `success`                          |
| details    | text   | Human-readable status information                  |