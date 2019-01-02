# API documentation v0.1.0

## Versioning

The API specification follows semantic versioning principles.  
Patch version bumps and minor version bumps should be backwards compatible (1.2.1 to 1.3.1 or 1.3.1 to 1.3.2) while incompatible versions result in a major version change (1.2.1 to 2.0.0).
The current API version can be queried by a GET request to the API root.

## Authentication

At this time, not authentication mechanisms are in place.

## Methods

The API consists of two endpoints, `plasmid` and `print`, as well as the root endpoint.

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

Adds a new plasmid to the database and creates an ID for it. The provided plasmid data should contain values for all fields marked as required in the data format documentation.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| data       | text   | JSON-representation of the plasmid to be added     |

| Property   | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| success    | bool   | Success status of the insert operation             |
| id         | text   | Unique ID of the inserted plasmid, format `pXY0123`  |

### Archiving a plasmid

`DELETE /plasmid/[id]`

Mark a plasmid as archived without actually deleting any information. This frees the plasmid's storage location and prevents it from showing up in search results when not explicitly requested. Viewing the plasmid data using its unique ID will still work as before.

| Parameter  | Format | Description                                        |
| ---------- | ------ | -------------------------------------------------- |
| id         | text   | Unique ID of the requested plasmid, format `pXY0123` |

### Modifying plasmid data

### Setting a plasmid storage location

### Searching plasmids

### Configuring the printer

### Printing stickers